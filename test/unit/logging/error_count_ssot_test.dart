import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Regression guard for "HUD badge shows 16 errors, LogsPage `error` chip shows 6".
///
/// The HUD error badge ([AppLog.errorCount]) must always equal the number of
/// error-keyed records rendered by LogsPage (TalkerScreen groups chips and
/// filters purely by `TalkerData.key`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int chipCount(String key) =>
      AppLog.talker.history.where((e) => e.key == key).length;

  int errorChipsTotal() =>
      AppLog.errorKeys.map(chipCount).fold(0, (a, b) => a + b);

  setUp(AppLog.resetErrorCount);

  group('AppLog error count is derived from Talker history (SSOT)', () {
    test('every AppLog level carries the matching TalkerKey', () {
      AppLog.d(LogModule.ui, 'd');
      AppLog.i(LogModule.ui, 'i');
      AppLog.w(LogModule.ui, 'w');
      AppLog.e(LogModule.ui, 'e');
      AppLog.f(LogModule.ui, 'f');
      AppLog.t(LogModule.ui, 't');

      final keys = AppLog.talker.history.map((e) => e.key).toList();
      expect(keys, [
        TalkerKey.debug,
        TalkerKey.info,
        TalkerKey.warning,
        TalkerKey.error,
        TalkerKey.critical,
        TalkerKey.verbose,
      ]);
      expect(keys.contains(null), isFalse,
          reason: 'null keys are invisible under every LogsPage filter chip');
    });

    test('TalkerFilter on `error` chip matches every AppLog.e record', () {
      AppLog.e(LogModule.player, 'boom 1');
      AppLog.error('boom 2');
      AppLog.handle(StateError('boom 3'), StackTrace.current);
      AppLog.handle(const FormatException('boom 4'));

      final filter = TalkerFilter(enabledKeys: const [TalkerKey.error]);
      final visible = AppLog.talker.history.where(filter.filter).length;
      expect(visible, 4);
      expect(AppLog.errorCount, 4);
      expect(AppLog.errorCount, errorChipsTotal());
    });

    test('RenderFlex overflow is counted exactly once', () {
      AppLog.recordRenderFlexOverflow(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 16 pixels on the right.'),
        ),
      );
      expect(AppLog.errorCount, 1);
      expect(chipCount(TalkerKey.error), 1);
    });

    test('warnings and info never inflate the error badge', () {
      AppLog.w(LogModule.network, 'timeout');
      AppLog.i(LogModule.network, 'ok');
      expect(AppLog.errorCount, 0);
    });

    test('"Clean history" inside LogsPage resets the badge', () {
      AppLog.e(LogModule.ui, 'x');
      AppLog.e(LogModule.ui, 'y');
      expect(AppLog.errorCount, 2);

      AppLog.talker.cleanHistory(); // what TalkerScreen's action calls
      expect(AppLog.errorCount, 0);
      expect(AppLog.errorCountNotifier.value, 0);
    });

    test('ring-buffer eviction decrements the badge', () {
      AppLog.e(LogModule.ui, 'oldest error');
      final max = AppLog.talker.settings.maxHistoryItems;
      for (var i = 0; i < max; i++) {
        AppLog.i(LogModule.ui, 'filler $i');
      }
      expect(AppLog.talker.history.length, max);
      expect(AppLog.errorCount, 0);
      expect(AppLog.errorCount, errorChipsTotal());
    });

    test('notifier mirrors errorCount when idle', () {
      AppLog.e(LogModule.ui, 'z');
      expect(AppLog.errorCountNotifier.value, AppLog.errorCount);
    });
  });

  group('Architecture: one log entry per error', () {
    test('lib/ never bypasses AppLog with raw talker error APIs', () {
      final offenders = <String>[];
      final pattern = RegExp(r'talker\.(handle|error|critical)\(');
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('app_log.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Use AppLog.e / AppLog.handle so each error is logged once '
              'with key `error` (HUD badge == LogsPage chip).');
    });
  });
}
