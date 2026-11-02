// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';

/// Production-ready Sentry integration service for Haipee.
///
/// Features:
/// 1. Zero-leakage secure initialization (reads DSN via compile-time `--dart-define=SENTRY_DSN=...` or settings).
/// 2. Graceful no-op fallback when Sentry DSN is empty (offline & private builds remain 100% functional).
/// 3. Firebase Test Lab awareness (tags environment as 'testlab' and elevates sample rates to 100%).
/// 4. Bi-directional log bridging from Haipee's [Talker] logger into Sentry Breadcrumbs and Events.
/// 5. Visual crash analytics (screenshots & view hierarchy on supported mobile platforms).
class SentryService {
  SentryService._internal();

  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;

  static const String _envDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const bool _isExplicitTestLab = bool.fromEnvironment('FIREBASE_TEST_LAB', defaultValue: false);

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Whether current execution is detected as running within Google Cloud Firebase Test Lab
  static bool get isFirebaseTestLab {
    if (_isExplicitTestLab) return true;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        if (Platform.environment.containsKey('FIREBASE_TEST_LAB') ||
            Platform.environment['FIREBASE_TEST_LAB'] == 'true') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Global navigator observer for route transition telemetry
  static SentryNavigatorObserver get navigatorObserver => SentryNavigatorObserver();

  /// Initialize Sentry and execute the application runner.
  ///
  /// If [customDsn] is provided or [SENTRY_DSN] compile-time define is present, Sentry
  /// activates full error tracking. If both are absent or empty, the app executes normally
  /// with Sentry in disabled no-op mode.
  static Future<void> init({
    required AppRunner appRunner,
    String? customDsn,
  }) async {
    final dsn = (customDsn?.isNotEmpty ?? false) ? customDsn! : _envDsn;

    if (dsn.isEmpty) {
      // No Sentry DSN configured: run app directly without Sentry overhead
      _initialized = false;
      await appRunner();
      return;
    }

    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.debug = kDebugMode;
          options.environment = isFirebaseTestLab
              ? 'testlab'
              : (kReleaseMode ? 'production' : 'development');

          // Sampling rates: 100% in Firebase Test Lab to catch all Robo findings; 20% in production
          options.tracesSampleRate = isFirebaseTestLab ? 1.0 : (kReleaseMode ? 0.2 : 1.0);

          // Rich diagnostic attachments for UI bug discovery
          options.attachScreenshot = true;
          // ignore: experimental_member_use
          options.attachViewHierarchy = true;
          options.autoAppStart = true;
          options.enableAutoSessionTracking = true;

          // Privacy: Do not send Personally Identifiable Information
          options.sendDefaultPii = false;

          // Diagnostic tags
          options.beforeSend = (event, hint) {
            if (isFirebaseTestLab) {
              return event.copyWith(
                tags: {
                  ...?event.tags,
                  'runner': 'firebase_test_lab',
                  'automated_test': 'true',
                },
              );
            }
            return event;
          };
        },
        appRunner: () async {
          _initialized = true;
          _attachTalkerBridge();
          await appRunner();
        },
      );
    } catch (e, stack) {
      // In the catastrophic event that Sentry initialization throws, fail open and run the app
      _initialized = false;
      debugPrint('[SentryService] Initialization fallback: $e\n$stack');
      await appRunner();
    }
  }

  /// Attach Talker observer to mirror application logs and exceptions into Sentry
  static void _attachTalkerBridge() {
    try {
      AppLog.addObserver(SentryTalkerObserver());
    } catch (e) {
      debugPrint('[SentryService] Failed to attach Talker bridge: $e');
    }
  }

  /// Manually capture a handled exception to Sentry
  static Future<void> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    String? reason,
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) return;
    try {
      if (reason != null) {
        Sentry.addBreadcrumb(Breadcrumb(
          message: reason,
          category: 'manual_capture',
          level: SentryLevel.warning,
        ));
      }
      await Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (extra != null) {
            extra.forEach((key, value) {
              scope.setExtra(key, value);
            });
          }
        },
      );
    } catch (_) {}
  }
}

/// Observer bridging Talker logs and errors into Sentry telemetry
class SentryTalkerObserver extends TalkerObserver {
  @override
  void onError(TalkerError err) {
    if (!SentryService.isInitialized) return;
    try {
      final msg = err.message ?? err.error.toString();
      final moduleStr = LogModule.detect(msg).tag;

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: '[$moduleStr] $msg',
          category: 'talker.error',
          level: SentryLevel.error,
          timestamp: err.time,
        ),
      );

      Sentry.captureException(
        err.error,
        stackTrace: err.stackTrace,
        withScope: (scope) {
          scope.setTag('module', moduleStr);
          scope.setExtra('talker_message', msg);
        },
      );
    } catch (_) {}
  }

  @override
  void onException(TalkerException err) {
    if (!SentryService.isInitialized) return;
    try {
      final msg = err.message ?? err.exception.toString();
      final moduleStr = LogModule.detect(msg).tag;

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: '[$moduleStr] $msg',
          category: 'talker.exception',
          level: SentryLevel.error,
          timestamp: err.time,
        ),
      );

      Sentry.captureException(
        err.exception,
        stackTrace: err.stackTrace,
        withScope: (scope) {
          scope.setTag('module', moduleStr);
          scope.setExtra('talker_message', msg);
        },
      );
    } catch (_) {}
  }

  @override
  void onLog(TalkerData log) {
    if (!SentryService.isInitialized) return;
    try {
      final level = log.logLevel;
      // Skip debug and verbose noise unless in debug mode or test lab
      final isDebug = level == LogLevel.debug || level == LogLevel.verbose;
      if (isDebug && !kDebugMode && !SentryService.isFirebaseTestLab) {
        return;
      }

      final msg = log.message ?? '';
      if (msg.isEmpty) return;

      final moduleStr = LogModule.detect(msg).tag;

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: '[$moduleStr] $msg',
          category: 'talker.log',
          level: _mapLogLevel(level),
          timestamp: log.time,
        ),
      );
    } catch (_) {}
  }

  SentryLevel _mapLogLevel(LogLevel? level) {
    if (level == null) return SentryLevel.info;
    switch (level) {
      case LogLevel.error:
      case LogLevel.critical:
        return SentryLevel.error;
      case LogLevel.warning:
        return SentryLevel.warning;
      case LogLevel.debug:
      case LogLevel.verbose:
        return SentryLevel.debug;
      case LogLevel.info:
        return SentryLevel.info;
    }
  }
}
