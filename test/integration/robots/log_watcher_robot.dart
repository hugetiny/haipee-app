import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/logging/app_log.dart';

enum BugSeverity { fatal, warning, overflow }

enum BugType {
  layoutOverflow,
  unhandledException,
  appLogError,
  stateSyncError,
}

class DiscoveredBug {
  final BugType type;
  final BugSeverity severity;
  final String message;
  final String? contextDescription;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  DiscoveredBug({
    required this.type,
    required this.severity,
    required this.message,
    this.contextDescription,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    final ctx = contextDescription != null ? ' in [$contextDescription]' : '';
    return '[${type.name.toUpperCase()}] ($severity)$ctx: $message';
  }
}

/// Robot that observes Flutter errors, layout overflows, unhandled exceptions,
/// and [AppLog.errorCountNotifier] to catch and report bugs during crawler runs.
class LogWatcherRobot {
  final List<DiscoveredBug> bugs = [];
  FlutterExceptionHandler? _previousOnError;
  bool Function(Object exception, StackTrace stackTrace)? _previousPlatformOnError;
  VoidCallback? _appLogErrorListener;
  int _initialAppLogErrorCount = 0;

  bool get hasBugs => bugs.isNotEmpty;
  int get bugCount => bugs.length;

  List<DiscoveredBug> get overflowBugs =>
      bugs.where((b) => b.type == BugType.layoutOverflow).toList();

  List<DiscoveredBug> get exceptionBugs =>
      bugs.where((b) => b.type == BugType.unhandledException).toList();

  /// Attaches listeners to [FlutterError.onError], [PlatformDispatcher.instance.onError], and [AppLog.errorCountNotifier].
  void attach() {
    bugs.clear();
    _initialAppLogErrorCount = AppLog.errorCountNotifier.value;
    _previousOnError = FlutterError.onError;
    _previousPlatformOnError = PlatformDispatcher.instance.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[FLUTTER_ERROR_DETAILS]:\n$details');
      final msg = details.exceptionAsString();
      final isOverflow = msg.contains('RenderFlex overflowed by');
      if (isOverflow) {
        debugPrint('[OVERFLOW DETECTED]: $msg\nContext: ${details.context?.toDescription()}\n${details.informationCollector?.call().map((e) => e.toString()).join("\n")}');
      }
      final bug = DiscoveredBug(
        type: isOverflow ? BugType.layoutOverflow : BugType.unhandledException,
        severity: isOverflow ? BugSeverity.overflow : BugSeverity.fatal,
        message: msg,
        contextDescription: details.context?.toDescription(),
        stackTrace: details.stack,
      );
      bugs.add(bug);

      // Also forward to previous handler if appropriate
      if (_previousOnError != null) {
        _previousOnError!(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final msg = error.toString();
      bugs.add(
        DiscoveredBug(
          type: BugType.unhandledException,
          severity: BugSeverity.fatal,
          message: 'Unhandled platform/zone error: $msg',
          stackTrace: stack,
        ),
      );
      if (_previousPlatformOnError != null) {
        return _previousPlatformOnError!(error, stack);
      }
      return true;
    };

    _appLogErrorListener = () {
      final current = AppLog.errorCountNotifier.value;
      if (current > _initialAppLogErrorCount) {
        // AppLog recorded an error
        bugs.add(
          DiscoveredBug(
            type: BugType.appLogError,
            severity: BugSeverity.warning,
            message: 'AppLog recorded error (count: $current)',
          ),
        );
      }
    };
    AppLog.errorCountNotifier.addListener(_appLogErrorListener!);
  }

  /// Re-hooks FlutterError.onError inside testWidgets.
  void hookFlutterError() {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[FULL_FLUTTER_ERROR_DETAILS]:\n${details.toDiagnosticsNode().toStringDeep()}');
      oldHandler?.call(details);
    };
  }

  /// Checks if [tester.takeException()] captured any error on the widget tree.
  void checkTesterException(WidgetTester tester, {String? contextDescription}) {
    final error = tester.takeException();
    if (error != null) {
      if (error is FlutterError) {
        for (int i = 0; i < error.diagnostics.length; i++) {
          final n = error.diagnostics[i];
          debugPrint('[DIAG_NODE $i ${n.name}]: ${n.toDescription()}');
          if (n.value is RenderObject) {
            debugPrint('[RENDER_OBJECT]: ${(n.value as RenderObject).toStringDeep()}');
          }
        }
      } else {
        debugPrint('[TESTER_EXCEPTION]: $error');
      }
      final msg = error.toString();
      final isOverflow = msg.contains('RenderFlex overflowed by');
      bugs.add(
        DiscoveredBug(
          type: isOverflow ? BugType.layoutOverflow : BugType.unhandledException,
          severity: isOverflow ? BugSeverity.overflow : BugSeverity.fatal,
          message: msg,
          contextDescription: contextDescription,
        ),
      );
    }
  }

  /// Manually record an issue found by crawler robots.
  void recordBug(DiscoveredBug bug) {
    bugs.add(bug);
  }

  /// Detaches all listeners and restores Flutter error handling.
  void detach() {
    if (_previousOnError != null) {
      FlutterError.onError = _previousOnError;
      _previousOnError = null;
    }
    if (_previousPlatformOnError != null) {
      PlatformDispatcher.instance.onError = _previousPlatformOnError;
      _previousPlatformOnError = null;
    }
    if (_appLogErrorListener != null) {
      AppLog.errorCountNotifier.removeListener(_appLogErrorListener!);
      _appLogErrorListener = null;
    }
  }

  /// Asserts that no bugs, unhandled exceptions, or layout overflows occurred.
  void assertNoErrors({bool allowExpectedNetworkErrors = true}) {
    final criticalBugs = bugs.where((b) {
      if (b.type == BugType.layoutOverflow) return true;
      if (b.type == BugType.unhandledException) return true;
      if (b.type == BugType.stateSyncError) return true;
      if (b.type == BugType.appLogError) {
        return !allowExpectedNetworkErrors;
      }
      return true;
    }).toList();

    if (criticalBugs.isNotEmpty) {
      final formatted = criticalBugs.map((b) => '  - $b').join('\n');
      fail('LogWatcherRobot detected ${criticalBugs.length} critical bug(s) during execution:\n$formatted');
    }
  }

  /// Formats all caught issues for reporting.
  String generateReport() {
    if (bugs.isEmpty) {
      return 'LogWatcherRobot: 0 bugs detected. Clean run.';
    }
    final sb = StringBuffer();
    sb.writeln('LogWatcherRobot Bug Discovery Report (${bugs.length} total):');
    for (int i = 0; i < bugs.length; i++) {
      sb.writeln('${i + 1}. ${bugs[i]}');
      if (bugs[i].stackTrace != null) {
        sb.writeln('   Stack: ${bugs[i].stackTrace.toString().split('\n').take(3).join('\n   ')}');
      }
    }
    return sb.toString();
  }
}
