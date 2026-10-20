import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/services/logging/log_module.dart';
import 'package:kazumi/services/logging/rolling_file_sink.dart';
import 'package:kazumi/utils/storage.dart';
export 'package:kazumi/utils/logger.dart' show KazumiLogger, getLogsPath, clearLogs;

/// Module-tagged Talker log record.
class ModuleLog extends TalkerLog {
  ModuleLog(
    super.message, {
    required this.module,
    super.logLevel,
    Object? error,
    super.stackTrace,
    super.time,
  }) : super(
          error: error is Error ? error : null,
          exception: error is Error ? null : error,
        );

  final LogModule module;

  @override
  String get title => module.tag;

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) => '[$title] $message';
}

/// Observer directing Talker logs to the rolling file sink and error notifier.
class AppLogObserver extends TalkerObserver {
  AppLogObserver(this.sink);

  final RollingFileSink sink;

  @override
  void onError(TalkerError err) {
    AppLog.recordError();
    final msg = err.message ?? err.error.toString();
    final moduleStr = LogModule.detect(msg).tag;
    _write(
      time: err.time,
      level: 'ERROR',
      module: moduleStr,
      message: msg,
      error: err.error,
      stackTrace: err.stackTrace,
    );
    AppLog.notifyError(
      msg,
      error: err.error,
      stackTrace: err.stackTrace,
    );
  }

  @override
  void onException(TalkerException err) {
    AppLog.recordError();
    final msg = err.message ?? err.exception.toString();
    final moduleStr = LogModule.detect(msg).tag;
    _write(
      time: err.time,
      level: 'EXCEPTION',
      module: moduleStr,
      message: msg,
      error: err.exception,
      stackTrace: err.stackTrace,
    );
    AppLog.notifyError(
      msg,
      error: err.exception,
      stackTrace: err.stackTrace,
    );
  }

  @override
  void onLog(TalkerData log) {
    final level = log.logLevel;
    final isDebug = level == LogLevel.debug || level == LogLevel.verbose;

    // Filter out DEBUG and VERBOSE when developer debug mode is disabled
    if (isDebug && !AppLog.isDebugMode) {
      return;
    }

    final msg = log.message ?? '';
    final levelStr = level?.name.toUpperCase() ?? 'LOG';
    final moduleStr = log is ModuleLog
        ? log.module.tag
        : LogModule.detect(msg).tag;

    _write(
      time: log.time,
      level: levelStr,
      module: moduleStr,
      message: msg,
      error: log.error ?? log.exception,
      stackTrace: log.stackTrace,
    );

    if (level == LogLevel.error || level == LogLevel.critical) {
      AppLog.recordError();
      AppLog.notifyError(
        msg,
        error: log.error ?? log.exception,
        stackTrace: log.stackTrace,
      );
    }
  }

  void _write({
    required DateTime time,
    required String level,
    required String module,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = AppLog.formatLogEntry(
      time: time,
      level: level,
      module: module,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    sink.write(entry);
  }
}

/// Centralized, high-ergonomics application logging facade for Kazumi.
class AppLog {
  AppLog._();

  static bool _resolveInitialDebugMode() {
    try {
      if (GStorage.setting.isOpen) {
        return GStorage.setting.get(
          SettingBoxKey.diagnosticLogsEnabled,
          defaultValue: kDebugMode,
        ) as bool? ?? kDebugMode;
      }
    } catch (_) {}
    return kDebugMode;
  }

  static final ValueNotifier<bool> debugModeNotifier =
      ValueNotifier<bool>(_resolveInitialDebugMode());
  static bool get isDebugMode => debugModeNotifier.value;
  static void setDebugMode(bool value) {
    debugModeNotifier.value = value;
    try {
      if (GStorage.setting.isOpen) {
        GStorage.setting.put(SettingBoxKey.diagnosticLogsEnabled, value);
      }
    } catch (_) {}
  }

  /// Reloads and synchronizes developer debug mode setting from storage once Hive is initialized.
  static void loadSavedSettings() {
    try {
      if (GStorage.setting.isOpen) {
        final saved = GStorage.setting.get(
          SettingBoxKey.diagnosticLogsEnabled,
          defaultValue: kDebugMode,
        ) as bool? ?? kDebugMode;
        if (debugModeNotifier.value != saved) {
          debugModeNotifier.value = saved;
        }
      }
    } catch (_) {}
  }

  static GlobalKey<NavigatorState>? rootNavigatorKey;

  static final RollingFileSink fileSink = RollingFileSink(
    directoryProvider: () async {
      final base = (await getApplicationSupportDirectory()).path;
      return Directory(p.join(base, 'logs'));
    },
    baseName: 'kazumi.log',
    maxFileSizeBytes: 5 * 1024 * 1024, // 5MB
    maxBackups: 2, // kazumi.1.log, kazumi.2.log
  );

  static final Talker talker = TalkerFlutter.init(
    observer: AppLogObserver(fileSink),
    settings: TalkerSettings(
      maxHistoryItems: 1000,
      useConsoleLogs: !kReleaseMode,
    ),
  );

  static final ValueNotifier<bool> logScreenOpenNotifier =
      ValueNotifier<bool>(false);
  static bool get isLogScreenOpen => logScreenOpenNotifier.value;
  static void setLogScreenVisible(bool visible) {
    if (logScreenOpenNotifier.value == visible) return;
    try {
      final binding = SchedulerBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        binding.addPostFrameCallback((_) {
          logScreenOpenNotifier.value = visible;
        });
      } else {
        logScreenOpenNotifier.value = visible;
      }
    } catch (_) {
      logScreenOpenNotifier.value = visible;
    }
  }

  static final ValueNotifier<int> errorCountNotifier = ValueNotifier<int>(0);
  static int get errorCount => errorCountNotifier.value;
  static void recordError() {
    try {
      final binding = WidgetsBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        binding.addPostFrameCallback((_) {
          errorCountNotifier.value++;
        });
      } else {
        errorCountNotifier.value++;
      }
    } catch (_) {
      errorCountNotifier.value++;
    }
  }
  static void resetErrorCount() {
    errorCountNotifier.value = 0;
  }

  /// Merged listenable for reactive HUD and developer widgets.
  static Listenable get listenable => Listenable.merge([
        debugModeNotifier,
        logScreenOpenNotifier,
        errorCountNotifier,
      ]);

  // ─── Formatting ─────────────────────────────────────────────────────────────

  /// Formats log entry according to standard AI and developer inspection schema:
  /// `[YYYY-MM-DD HH:mm:ss.SSS] [LEVEL] [MODULE] message`
  static String formatLogEntry({
    required DateTime time,
    required String level,
    required String module,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    final timeStr = '$y-$m-$d $h:$min:$s.$ms';

    final buffer = StringBuffer();
    buffer.write('[$timeStr] [$level] [$module] $message');
    if (error != null) {
      buffer.write('\n    Error: $error');
    }
    if (stackTrace != null && stackTrace != StackTrace.empty) {
      buffer.write('\n    StackTrace:\n$stackTrace');
    }
    return buffer.toString();
  }

  // ─── Ergonomic Typed Logging Methods ────────────────────────────────────────

  /// Debug log with strong module tag
  static void d(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.debug,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Info log with strong module tag
  static void i(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.info,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Warning log with strong module tag
  static void w(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.warning,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Error log with strong module tag
  static void e(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.error,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Fatal / Critical log with strong module tag
  static void f(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.critical,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Verbose / Trace log with strong module tag
  static void t(
    LogModule module,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(
      ModuleLog(
        message.toString(),
        module: module,
        logLevel: LogLevel.verbose,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Handle uncaught exception or error
  static void handle(
    Object exception, [
    StackTrace? stackTrace,
    dynamic message,
    LogModule? module,
  ]) {
    final mod = module ?? LogModule.detect(message ?? exception);
    final text = message != null ? '$message: $exception' : '$exception';
    talker.logCustom(
      ModuleLog(
        text,
        module: mod,
        logLevel: LogLevel.error,
        error: exception,
        stackTrace: stackTrace,
      ),
    );
  }

  // ─── Module Optional Convenience Overloads ─────────────────────────────────

  static void debug(
    dynamic message, {
    LogModule module = LogModule.system,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      d(module, message, error: error, stackTrace: stackTrace);

  static void info(
    dynamic message, {
    LogModule module = LogModule.system,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      i(module, message, error: error, stackTrace: stackTrace);

  static void warning(
    dynamic message, {
    LogModule module = LogModule.system,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      w(module, message, error: error, stackTrace: stackTrace);

  static void error(
    dynamic message, {
    LogModule module = LogModule.system,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      e(module, message, error: error, stackTrace: stackTrace);

  // ─── In-App Developer HUD & Error Notification ──────────────────────────────

  /// Non-intrusively notifies users/devs about an error with 1-click inspection.
  /// Throttled to at most once per 3 seconds to avoid UI spam.
  static void notifyError(
    String summary, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Errors are non-intrusively recorded into Talker / RollingFileSink / errorCountNotifier
    // to preserve smooth user browsing without disruptive toast popups.
  }

  /// Resolves the most appropriate [NavigatorState] without throwing errors
  /// even if called from widgets above the Navigator (e.g., MaterialApp.builder).
  static NavigatorState? _resolveNavigatorState([BuildContext? context]) {
    if (rootNavigatorKey?.currentState != null) {
      return rootNavigatorKey!.currentState;
    }
    if (context != null && context.mounted) {
      final state = Navigator.maybeOf(context);
      if (state != null) return state;
    }
    final observerCtx = KazumiDialog.observer.currentContext;
    if (observerCtx != null && observerCtx.mounted) {
      final state = Navigator.maybeOf(observerCtx);
      if (state != null) return state;
    }
    return null;
  }

  /// Opens the interactive [LogsPage].
  static void openLogScreen([BuildContext? context]) {
    if (!isDebugMode) return;
    if (isLogScreenOpen) return;
    final navState = _resolveNavigatorState(context);
    if (navState == null) return;

    setLogScreenVisible(true);
    navState
        .push(
          MaterialPageRoute(
            builder: (_) => const LogsPage(),
            settings: const RouteSettings(name: 'LogsPage'),
          ),
        )
        .whenComplete(() {
          setLogScreenVisible(false);
        });
  }

  /// Toggles the interactive [LogsPage] (opens if closed, pops if opened).
  static void toggleLogScreen([BuildContext? context]) {
    if (!isDebugMode) return;
    final navState = _resolveNavigatorState(context);
    if (navState == null) return;

    if (isLogScreenOpen) {
      if (navState.canPop()) {
        navState.pop();
      }
    } else {
      openLogScreen(context);
    }
  }

  // ─── Diagnostics & AI Accessibility ─────────────────────────────────────────

  /// Gathers full diagnostic report including device environment and chronological logs.
  static Future<String> exportDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('       KAZUMI SYSTEM DIAGNOSTICS REPORT ');
    buffer.writeln('========================================');
    buffer.writeln('App Version: ${Api.version}');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart Version: ${Platform.version}');
    buffer.writeln('Debug Mode: $isDebugMode');
    buffer.writeln('Session Error Count: $errorCount');
    try {
      final dir = await fileSink.getLogDirectory();
      buffer.writeln('Logs Directory: ${dir.path}');
      final files = await fileSink.getExistingLogFiles();
      buffer.writeln('Log Files Present:');
      for (final f in files) {
        final len = await f.length();
        buffer.writeln('  - ${p.basename(f.path)}: ${(len / 1024).toStringAsFixed(1)} KB');
      }
    } catch (e) {
      buffer.writeln('Logs Directory Error: $e');
    }
    buffer.writeln('========================================');
    buffer.writeln();

    final logsContent = await fileSink.readAllLogsChronological();
    buffer.write(logsContent);
    return buffer.toString();
  }

  /// Copies primary log file path to clipboard.
  static Future<void> copyLogFilePath() async {
    final file = await fileSink.getPrimaryFile();
    await Clipboard.setData(ClipboardData(text: file.path));
  }

  /// Copies full diagnostic report to clipboard.
  static Future<void> copyDiagnostics() async {
    final report = await exportDiagnostics();
    await Clipboard.setData(ClipboardData(text: report));
  }

  /// Opens the log folder in the system's file manager (Finder/Explorer/Files).
  static Future<bool> openLogsDirectory() async {
    try {
      final dir = await fileSink.getLogDirectory();
      final uri = Uri.file(dir.path);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        // Fallback for desktop shell
        if (Platform.isMacOS) {
          await Process.run('open', [dir.path]);
          return true;
        } else if (Platform.isWindows) {
          await Process.run('explorer.exe', [dir.path]);
          return true;
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [dir.path]);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Returns the primary active log file.
  static Future<File> getActiveLogFile() => fileSink.getPrimaryFile();

  /// Clears active and backup log files, and resets talker memory history.
  static Future<bool> clearLogs() async {
    try {
      await fileSink.clear();
      talker.cleanHistory();
      resetErrorCount();
      return true;
    } catch (_) {
      return false;
    }
  }
}
