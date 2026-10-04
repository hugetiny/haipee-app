import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' show Level;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Global talker logger singleton for Kazumi, backed by modern [TalkerFlutter].
class KazumiLogger {
  KazumiLogger._internal() {
    _talker = TalkerFlutter.init(
      observer: _KazumiTalkerFileObserver(),
      settings: TalkerSettings(
        maxHistoryItems: 1000,
        useConsoleLogs: !kReleaseMode,
      ),
    );
  }

  static final KazumiLogger _instance = KazumiLogger._internal();
  factory KazumiLogger() => _instance;

  late final Talker _talker;
  Talker get talker => _talker;

  static final Lock _fileLock = Lock();
  static File? _cachedLogFile;

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
        _talker.verbose(message);
        break;
      case Level.debug:
        _talker.debug(message);
        break;
      case Level.info:
        _talker.info(message);
        break;
      case Level.warning:
        _talker.warning(message, error, stackTrace);
        break;
      case Level.error:
        _talker.error(message, error, stackTrace);
        break;
      case Level.fatal:
        _talker.critical(message, error, stackTrace);
        break;
      default:
        _talker.log(message.toString());
        break;
    }
  }

  /// Simple log (verbose trace)
  void simpleLog(dynamic message) {
    _talker.verbose(message);
  }

  /// Verbose log
  void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.verbose(message);

  /// Debug log
  void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.debug(message);

  /// Info log
  void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.info(message);

  /// Warning log
  void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.warning(message, error, stackTrace);

  /// Error log
  void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.error(message, error, stackTrace);

  /// Fatal / Critical log
  void f(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _talker.critical(message, error, stackTrace);

  /// Handle exception with optional stack trace
  void handle(Object exception, [StackTrace? stackTrace, dynamic message]) =>
      _talker.handle(exception, stackTrace, message);
}

class _KazumiTalkerFileObserver extends TalkerObserver {
  static const int _maxFileSize = 2 * 1024 * 1024; // 2MB max file size

  @override
  void onError(TalkerError err) {
    _appendToFile(
      level: 'ERROR',
      message: err.message,
      error: err.error,
      stackTrace: err.stackTrace,
      time: err.time,
    );
  }

  @override
  void onException(TalkerException err) {
    _appendToFile(
      level: 'EXCEPTION',
      message: err.message,
      error: err.exception,
      stackTrace: err.stackTrace,
      time: err.time,
    );
  }

  @override
  void onLog(TalkerData log) {
    final level = log.logLevel;
    if (level == LogLevel.error ||
        level == LogLevel.critical ||
        level == LogLevel.warning) {
      _appendToFile(
        level: level?.name.toUpperCase() ?? 'LOG',
        message: log.message,
        error: log.error ?? log.exception,
        stackTrace: log.stackTrace,
        time: log.time,
      );
    }
  }

  static void _appendToFile({
    required String level,
    dynamic message,
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) async {
    try {
      final file = await getLogsPath();
      final timestamp = time ?? DateTime.now();
      final buffer = StringBuffer();
      buffer.writeln('**$timestamp** [$level]');
      if (message != null) buffer.writeln('$message');
      if (error != null) buffer.writeln('Error: $error');
      if (stackTrace != null && stackTrace != StackTrace.empty) {
        buffer.writeln('$stackTrace');
      }
      buffer.writeln();

      await KazumiLogger._fileLock.synchronized(() async {
        if (await file.exists()) {
          final length = await file.length();
          if (length > _maxFileSize) {
            try {
              final content = await file.readAsString();
              final keepFrom = content.length > 500 * 1024
                  ? content.length - 500 * 1024
                  : 0;
              final truncated = content.substring(keepFrom);
              await file.writeAsString('[--- LOG ROTATED ---]\n$truncated');
            } catch (_) {}
          }
        }
        await file.writeAsString(buffer.toString(),
            mode: FileMode.writeOnlyAppend);
      });
    } catch (_) {
      // Silently ignore write failures to prevent crash in logging
    }
  }
}

Future<File> getLogsPath() async {
  if (KazumiLogger._cachedLogFile != null) {
    return KazumiLogger._cachedLogFile!;
  }
  final dir = (await getApplicationSupportDirectory()).path;
  final logDir = p.join(dir, 'logs');
  final filename = p.join(logDir, 'kazumi_logs.log');

  final directory = Directory(logDir);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File(filename);
  if (!await file.exists()) {
    await KazumiLogger._fileLock.synchronized(() async {
      if (!await file.exists()) {
        await file.create();
      }
    });
  }
  KazumiLogger._cachedLogFile = file;
  return file;
}

Future<bool> clearLogs() async {
  try {
    final file = await getLogsPath();
    await KazumiLogger._fileLock.synchronized(() async {
      if (await file.exists()) {
        await file.writeAsString('');
      }
    });
    KazumiLogger().talker.cleanHistory();
    return true;
  } catch (e) {
    // ignore: avoid_print
    print('Error clearing file: $e');
    return false;
  }
}
