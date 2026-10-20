import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart' show Level;
import 'package:kazumi/services/logging/app_log.dart';
import 'package:kazumi/services/logging/log_module.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLog Facade Tests', () {
    test('formatLogEntry formats according to AI and standard schema', () {
      final now = DateTime(2026, 10, 13, 18, 30, 45, 123);
      final entry = AppLog.formatLogEntry(
        time: now,
        level: 'INFO',
        module: 'STREAM',
        message: 'Engine started',
      );

      expect(entry, equals('[2026-10-13 18:30:45.123] [INFO] [STREAM] Engine started'));
    });

    test('formatLogEntry includes error and stackTrace if provided', () {
      final now = DateTime(2026, 10, 13, 18, 30, 45, 123);
      final entry = AppLog.formatLogEntry(
        time: now,
        level: 'ERROR',
        module: 'NETWORK',
        message: 'Request failed',
        error: 'Connection timed out',
        stackTrace: StackTrace.fromString('#0 main() in test.dart'),
      );

      expect(entry, contains('[2026-10-13 18:30:45.123] [ERROR] [NETWORK] Request failed'));
      expect(entry, contains('Error: Connection timed out'));
      expect(entry, contains('StackTrace:'));
      expect(entry, contains('#0 main() in test.dart'));
    });

    test('AppLog static methods record entries to Talker and count errors', () {
      AppLog.resetErrorCount();
      expect(AppLog.errorCount, equals(0));

      AppLog.i(LogModule.aria2, 'Aria2 initialized');
      AppLog.d(LogModule.player, 'Player frame updated');
      AppLog.w(LogModule.indexer, 'Indexer returned empty');

      expect(AppLog.talker.history.length, greaterThan(0));

      // e and f should increment errorCount
      AppLog.e(LogModule.network, 'Network connection lost');
      AppLog.f(LogModule.system, 'Fatal database corruption');

      expect(AppLog.errorCount, equals(2));
    });

    test('KazumiLogger backward-compatible bridge works seamlessly', () {
      AppLog.resetErrorCount();
      final logger = KazumiLogger();

      logger.log(Level.info, '[Aria2] Task added');
      logger.log(Level.warning, '[TorrentStreamService] Torrent slow');
      logger.log(Level.error, 'Sync failed');

      expect(AppLog.errorCount, equals(1));
    });

    test('exportDiagnostics generates structured diagnosis report', () async {
      final report = await AppLog.exportDiagnostics();

      expect(report, contains('KAZUMI SYSTEM DIAGNOSTICS REPORT'));
      expect(report, contains('App Version:'));
      expect(report, contains('Timestamp:'));
      expect(report, contains('Platform:'));
      expect(report, contains('Debug Mode:'));
    });

    test('AppLog.listenable notifies listeners on state changes', () {
      int notifications = 0;
      void listener() {
        notifications++;
      }

      AppLog.listenable.addListener(listener);

      AppLog.recordError();
      expect(notifications, equals(1));

      AppLog.setDebugMode(!AppLog.isDebugMode);
      expect(notifications, equals(2));

      AppLog.setLogScreenVisible(true);
      expect(notifications, equals(3));

      AppLog.resetErrorCount();
      expect(notifications, equals(4));

      AppLog.listenable.removeListener(listener);
      // Clean up state
      AppLog.setLogScreenVisible(false);
    });

    test('AppLog.notifyError suppresses notifications when debug mode is disabled', () {
      AppLog.setDebugMode(false);
      // Should cleanly return without crashing or trying to show toast
      AppLog.notifyError('Test background network warning');
      // Re-enable debug mode
      AppLog.setDebugMode(true);
    });

    test('AppLog.loadSavedSettings restores persisted setting from Hive and handles defaults', () async {
      final tempDir = await Directory.systemTemp.createTemp('app_log_storage_test');
      Hive.init(tempDir.path);
      final box = await Hive.openBox('setting');
      GStorage.setting = box;

      try {
        await box.put(SettingBoxKey.diagnosticLogsEnabled, false);
        AppLog.loadSavedSettings();
        expect(AppLog.isDebugMode, isFalse);

        await box.put(SettingBoxKey.diagnosticLogsEnabled, true);
        AppLog.loadSavedSettings();
        expect(AppLog.isDebugMode, isTrue);

        await box.delete(SettingBoxKey.diagnosticLogsEnabled);
        AppLog.loadSavedSettings();
        expect(AppLog.isDebugMode, equals(kDebugMode));
      } finally {
        await box.close();
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
