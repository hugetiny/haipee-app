import 'dart:io';

import 'package:logger/logger.dart' show Level;
import 'package:talker_flutter/talker_flutter.dart';
import 'package:haipee/services/logging/app_log.dart';

import 'package:haipee/services/logging/log_module.dart';

/// Global talker logger singleton for Haipee, backed by modern [AppLog.talker].
class HaipeeLogger {
  HaipeeLogger._internal();

  static final HaipeeLogger _instance = HaipeeLogger._internal();
  factory HaipeeLogger() => _instance;

  Talker get talker => AppLog.talker;

  /// Log with traditional [Level] for 100% backward compatibility
  void log(
    Level level,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    final module = LogModule.detect(message);
    switch (level) {
      case Level.trace:
        AppLog.t(module, message, error: error, stackTrace: stackTrace);
        break;
      case Level.debug:
        AppLog.d(module, message, error: error, stackTrace: stackTrace);
        break;
      case Level.info:
        AppLog.i(module, message, error: error, stackTrace: stackTrace);
        break;
      case Level.warning:
        AppLog.w(module, message, error: error, stackTrace: stackTrace);
        break;
      case Level.error:
        AppLog.e(module, message, error: error, stackTrace: stackTrace);
        break;
      case Level.fatal:
        AppLog.f(module, message, error: error, stackTrace: stackTrace);
        break;
      default:
        AppLog.i(module, message, error: error, stackTrace: stackTrace);
        break;
    }
  }

  /// Simple log (verbose trace)
  void simpleLog(dynamic message) {
    AppLog.t(LogModule.detect(message), message);
  }

  /// Verbose log
  void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.t(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Debug log
  void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.d(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Info log
  void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.i(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Warning log
  void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.w(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Error log
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.e(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Fatal / Critical log
  void f(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      AppLog.f(LogModule.detect(message), message,
          error: error, stackTrace: stackTrace);

  /// Handle exception with optional stack trace
  void handle(Object exception, [StackTrace? stackTrace, dynamic message]) =>
      AppLog.handle(exception, stackTrace, message);
}

Future<File> getLogsPath() async {
  return AppLog.fileSink.getPrimaryFile();
}

Future<bool> clearLogs() async {
  return AppLog.clearLogs();
}
