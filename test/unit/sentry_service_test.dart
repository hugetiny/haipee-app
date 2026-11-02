import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/services/sentry/sentry_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SentryService Architecture & Telemetry Tests', () {
    test('SentryService initializes as singleton', () {
      final s1 = SentryService();
      final s2 = SentryService();
      expect(identical(s1, s2), isTrue);
    });

    test('SentryService gracefully falls back when DSN is empty', () async {
      bool appRunnerExecuted = false;

      await SentryService.init(
        customDsn: '',
        appRunner: () async {
          appRunnerExecuted = true;
        },
      );

      expect(appRunnerExecuted, isTrue);
      expect(SentryService.isInitialized, isFalse);
    });

    test('SentryNavigatorObserver is exposed and non-null', () {
      final observer = SentryService.navigatorObserver;
      expect(observer, isNotNull);
    });

    test('SentryService.captureException does not throw when uninitialized', () async {
      expect(
        () async => await SentryService.captureException(
          Exception('Test unhandled crash'),
          reason: 'Test reasoning',
          extra: {'test_key': 'test_value'},
        ),
        returnsNormally,
      );
    });

    test('SentryTalkerObserver safely processes errors, exceptions and logs without throwing', () {
      final observer = SentryTalkerObserver();

      // Test TalkerError handling
      expect(
        () => observer.onError(
          TalkerError(
            ArgumentError('Sample database error'),
            message: 'Database query failed',
          ),
        ),
        returnsNormally,
      );

      // Test TalkerException handling
      expect(
        () => observer.onException(
          TalkerException(
            Exception('Network timed out'),
            message: 'Network request timed out',
          ),
        ),
        returnsNormally,
      );

      // Test TalkerData log handling
      expect(
        () => observer.onLog(
          TalkerData(
            'Aria2 daemon started on port 6800',
            logLevel: LogLevel.info,
          ),
        ),
        returnsNormally,
      );
    });
  });
}
