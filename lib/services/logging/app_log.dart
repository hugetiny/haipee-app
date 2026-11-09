import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/logs/logs_page.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/services/logging/log_enricher.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:haipee/services/logging/rolling_file_sink.dart';
import 'package:haipee/utils/storage.dart';
export 'package:haipee/services/logging/log_enricher.dart' show DiagnosticInfo, LogEnricher;
export 'package:haipee/utils/logger.dart' show HaipeeLogger, getLogsPath, clearLogs;

/// Module-tagged Talker log record.
///
/// The record always carries a [TalkerKey] derived from its [LogLevel]
/// (`error`, `warning`, `info`, ...). `TalkerScreen` groups its filter chips
/// and `TalkerFilter` matches records purely by `key`, so a `null` key would
/// make the log invisible under every category chip in [LogsPage].
class ModuleLog extends TalkerLog {
  ModuleLog(
    super.message, {
    required this.module,
    LogLevel? logLevel,
    Object? error,
    super.stackTrace,
    super.time,
  }) : super(
          logLevel: logLevel ?? LogLevel.debug,
          key: TalkerKey.fromLogLevel(logLevel ?? LogLevel.debug),
          error: error is Error ? error : null,
          exception: error is Error ? null : error,
        );

  final LogModule module;

  /// Card title shown in [LogsPage], e.g. `error · PLAYER`.
  ///
  /// Talker assigns `title = settings.getTitleByKey(key)` before dispatching;
  /// the inherited setter stores that value but this getter keeps the module
  /// tag visible next to the level.
  @override
  String get title => '${key ?? 'log'} · ${module.tag}';

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) => '[${key ?? 'log'}] [${module.tag}] $message';
}

/// In-memory Talker history that keeps the error counter derived from the
/// exact same list rendered by [LogsPage].
///
/// The debug HUD badge, the `error` chip in [LogsPage] and the diagnostics
/// tooling therefore always read one single source of truth: entries are
/// counted on write, decremented on ring-buffer eviction and reset on
/// `cleanHistory()` (including the "Clean history" action inside TalkerScreen).
class AppLogHistory implements TalkerHistory {
  AppLogHistory({required TalkerSettings Function() settings, this.onChanged})
      : _settings = settings;

  final TalkerSettings Function() _settings;
  final VoidCallback? onChanged;
  final List<TalkerData> _items = <TalkerData>[];
  int _errorCount = 0;

  int get errorCount => _errorCount;

  @override
  List<TalkerData> get history => _items;

  @override
  void clean() {
    if (!_settings().useHistory) return;
    _items.clear();
    _errorCount = 0;
    onChanged?.call();
  }

  @override
  void write(TalkerData data) {
    final settings = _settings();
    if (!settings.useHistory || !settings.enabled) return;
    if (settings.maxHistoryItems <= _items.length && _items.isNotEmpty) {
      final evicted = _items.removeAt(0);
      if (AppLog.isErrorRecord(evicted)) _errorCount--;
    }
    _items.add(data);
    if (AppLog.isErrorRecord(data)) _errorCount++;
    onChanged?.call();
  }
}

/// Observer directing Talker logs to the rolling file sink and error notifier.
class AppLogObserver extends TalkerObserver {
  AppLogObserver(this.sink);

  final RollingFileSink sink;

  @override
  void onError(TalkerError err) {
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
    if (!kReleaseMode || AppLog.isFirebaseTestLab) {
      debugPrintSynchronously(entry);
    }
    if (level == 'ERROR' || level == 'CRITICAL' || level == 'EXCEPTION' || AppLog.isFirebaseTestLab) {
      developer.log(
        entry,
        name: 'haipee',
        level: (level == 'ERROR' || level == 'CRITICAL' || level == 'EXCEPTION') ? 1000 : 800,
        error: error,
        stackTrace: stackTrace,
      );
      AppLog.logToNativePlatform(
        level: (level.startsWith('E') || level.startsWith('C')) ? 'E' : 'I',
        message: entry,
      );
      if (kReleaseMode && (level.startsWith('E') || level.startsWith('C'))) {
        try {
          stderr.writeln(entry);
        } catch (_) {}
      }
    }
  }
}

/// Composite observer allowing multiple [TalkerObserver] instances (e.g. file sink + Sentry).
class CompositeTalkerObserver extends TalkerObserver {
  CompositeTalkerObserver(this.primary);
  final TalkerObserver primary;
  final List<TalkerObserver> _additionalObservers = [];

  void addObserver(TalkerObserver observer) {
    if (!_additionalObservers.contains(observer)) {
      _additionalObservers.add(observer);
    }
  }

  @override
  void onError(TalkerError err) {
    primary.onError(err);
    for (final obs in _additionalObservers) {
      obs.onError(err);
    }
  }

  @override
  void onException(TalkerException err) {
    primary.onException(err);
    for (final obs in _additionalObservers) {
      obs.onException(err);
    }
  }

  @override
  void onLog(TalkerData log) {
    primary.onLog(log);
    for (final obs in _additionalObservers) {
      obs.onLog(log);
    }
  }
}

/// Centralized, high-ergonomics application logging facade for Haipee.
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
    baseName: 'haipee.log',
    maxFileSizeBytes: 5 * 1024 * 1024, // 5MB
    maxBackups: 2, // haipee.1.log, haipee.2.log
  );

  static final CompositeTalkerObserver compositeObserver =
      CompositeTalkerObserver(AppLogObserver(fileSink));

  static const bool _isExplicitTestLab =
      bool.fromEnvironment('FIREBASE_TEST_LAB', defaultValue: false);

  static bool _detectedNativeTestLab = false;
  static const MethodChannel _intentChannel = MethodChannel('com.hugetiny.haipee/intent');

  /// Whether current execution is detected as running within Google Cloud Firebase Test Lab
  static bool get isFirebaseTestLab {
    if (_isExplicitTestLab || _detectedNativeTestLab) return true;
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

  /// Automatically queries platform settings to detect Firebase Test Lab
  static Future<void> detectTestLab() async {
    if (_isExplicitTestLab || _detectedNativeTestLab) return;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final isTestLab = await _intentChannel.invokeMethod<bool>('isFirebaseTestLab');
        if (isTestLab == true) {
          _detectedNativeTestLab = true;
          // Console mirroring is driven by AppLogObserver via [isFirebaseTestLab];
          // do NOT call talker.configure() here: it silently replaces the custom
          // [AppLogHistory] (the error-count source of truth) with a default one.
          setDebugMode(true);
        }
      }
    } catch (_) {}
  }

  /// Dispatches log entry directly to native Android logcat / iOS syslog / platform logger
  static void logToNativePlatform({required String level, required String message}) {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _intentChannel.invokeMethod('logNative', {
          'tag': 'haipee',
          'level': level,
          'message': message,
        });
      }
    } catch (_) {}
  }

  /// Records and formats a RenderFlex overflow error so it is surfaced deterministically in Test Lab logs.
  ///
  /// Logged exactly once through [e]; the error counter is derived from the
  /// resulting history entry, never incremented manually.
  static void recordRenderFlexOverflow(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    e(
      LogModule.ui,
      '[HAIPEE_OVERFLOW] RenderFlex layout overflow: $message',
      error: details.exception,
      stackTrace: details.stack,
    );
  }

  /// In-memory history shared by [LogsPage] and the debug HUD error badge.
  static final AppLogHistory history = AppLogHistory(
    settings: () => talker.settings,
    onChanged: _publishErrorCount,
  );

  static final Talker talker = Talker(
    observer: compositeObserver,
    history: history,
    settings: TalkerSettings(
      maxHistoryItems: 1000,
      // AppLogObserver already mirrors every structured entry to the console
      // (debug builds / Test Lab). Talker's own console printer would print
      // each record a second time.
      useConsoleLogs: false,
    ),
  );

  static void addObserver(TalkerObserver observer) {
    compositeObserver.addObserver(observer);
  }

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

  // ─── Error counter (derived, single source of truth) ───────────────────────

  /// Keys counted as errors. Every error path in the app is routed through
  /// [e] / [f] / [handle] (key `error` / `critical`); `exception` is kept for
  /// third-party code calling `talker.handle` directly.
  static const Set<String> errorKeys = {
    TalkerKey.error,
    TalkerKey.critical,
    TalkerKey.exception,
  };

  /// Whether [data] counts towards the HUD error badge.
  static bool isErrorRecord(TalkerData data) {
    final key = data.key;
    if (key != null) return errorKeys.contains(key);
    final level = data.logLevel;
    return level == LogLevel.error || level == LogLevel.critical;
  }

  /// UI-facing notifier mirroring [errorCount]. Updated after the current
  /// frame when a log is written during build/layout/paint so listeners never
  /// trigger "setState() called during build".
  static final ValueNotifier<int> errorCountNotifier = ValueNotifier<int>(0);

  /// Exact number of error records currently held in [talker.history] —
  /// identical to the sum of the `error` / `critical` / `exception` chips in
  /// [LogsPage].
  static int get errorCount => history.errorCount;

  static bool _publishScheduled = false;
  static void _publishErrorCount() {
    try {
      final binding = SchedulerBinding.instance;
      if (binding.schedulerPhase != SchedulerPhase.idle) {
        if (_publishScheduled) return;
        _publishScheduled = true;
        binding.addPostFrameCallback((_) {
          _publishScheduled = false;
          errorCountNotifier.value = history.errorCount;
        });
        binding.ensureVisualUpdate();
        return;
      }
    } catch (_) {
      // Binding not initialized (pure Dart unit tests) – publish directly.
    }
    errorCountNotifier.value = history.errorCount;
  }

  /// Per-key counts of the in-memory history (same grouping as LogsPage chips).
  static Map<String, int> historyKeyCounts() {
    final counts = <String, int>{};
    for (final item in talker.history) {
      final key = item.key ?? 'undefined';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Clears the in-memory log history; the error badge resets as a consequence.
  /// Persistent log files on disk are kept (use [clearLogs] to wipe them too).
  static void resetErrorCount() {
    talker.cleanHistory();
    _publishErrorCount();
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
    final sanitizedMessage = LogEnricher.sanitizeMessage(message);
    buffer.write('[$timeStr] [$level] [$module] $sanitizedMessage');

    final bool isFailureLevel = level == 'ERROR' ||
        level == 'EXCEPTION' ||
        level == 'WARNING' ||
        level == 'CRITICAL' ||
        error != null;

    if (isFailureLevel) {
      final diag = LogEnricher.analyze(message, error);
      if (diag != null) {
        buffer.write('\n    Diagnostic: [${diag.code}] ${diag.title}');
        buffer.write('\n    Explanation: ${diag.explanation}');
        buffer.write('\n    Action: ${diag.remediation}');
      }
    }

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
    final observerCtx = HaipeeDialog.observer.currentContext;
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
    buffer.writeln('       HAIPEE SYSTEM DIAGNOSTICS REPORT ');
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

  /// 供 AI Coding Agent 或自省工具直接获取结构化的近期错误列表
  static Future<List<Map<String, dynamic>>> getRecentErrorsJson({int limit = 50}) async {
    final file = await getActiveLogFile();
    if (!file.existsSync()) return [];
    final lines = await file.readAsLines();
    final List<Map<String, dynamic>> result = [];
    final regExp = RegExp(
      r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\] \[(ERROR|EXCEPTION|WARNING)\] \[([^\]]+)\] (.*)$',
    );

    for (final line in lines.reversed) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final time = match.group(1)!;
        final level = match.group(2)!;
        final module = match.group(3)!;
        final msg = match.group(4)!;
        final diag = LogEnricher.analyze(msg);
        result.add({
          'timestamp': time,
          'level': level,
          'module': module,
          'message': msg,
          if (diag != null) ...{
            'diagnosticCode': diag.code,
            'diagnosticTitle': diag.title,
            'explanation': diag.explanation,
            'action': diag.remediation,
          },
        });
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// Clears active and backup log files, and resets talker memory history.
  static Future<bool> clearLogs() async {
    try {
      await fileSink.clear();
      resetErrorCount();
      return true;
    } catch (_) {
      return false;
    }
  }
}
