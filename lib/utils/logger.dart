import 'dart:io';

import 'package:logger/logger.dart' show Level;
import 'package:talker_flutter/talker_flutter.dart';
import 'package:kazumi/services/logging/app_log.dart';

/// Global talker logger singleton for Kazumi, backed by modern [AppLog.talker].
class KazumiLogger {
  KazumiLogger._internal();

  static final KazumiLogger _instance = KazumiLogger._internal();
  factory KazumiLogger() => _instance;

  Talker get talker => AppLog.talker;

  /// Log with traditional [Level] for 100% backward compatibility
  void log(
    Level level,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    switch (level) {
      case Level.trace:
        talker.verbose(message);
        break;
      case Level.debug:
        talker.debug(message);
        break;
      case Level.info:
        talker.info(message);
        break;
      case Level.warning:
        talker.warning(message, error, stackTrace);
        break;
      case Level.error:
        talker.error(message, error, stackTrace);
        break;
      case Level.fatal:
        talker.critical(message, error, stackTrace);
        break;
      default:
        talker.log(message.toString());
        break;
    }
  }

  /// Simple log (verbose trace)
  void simpleLog(dynamic message) {
    talker.verbose(message);
  }

  /// Verbose log
  void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.verbose(message);

  /// Debug log
  void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.debug(message);

  /// Info log
  void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.info(message);

  /// Warning log
  void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.warning(message, error, stackTrace);

  /// Error log
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.error(message, error, stackTrace);

  /// Fatal / Critical log
  void f(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      talker.critical(message, error, stackTrace);

  /// Handle exception with optional stack trace
  void handle(Object exception, [StackTrace? stackTrace, dynamic message]) =>
      talker.handle(exception, stackTrace, message);
}

Future<File> getLogsPath() async {
  return AppLog.fileSink.getPrimaryFile();
}

Future<bool> clearLogs() async {
  return AppLog.clearLogs();
}
