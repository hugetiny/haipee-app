import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart' show Level;

// A simple dialog helper class to show dialogs and toasts based on flutter native implementation (replace flutter_smart_dialog)
// flutter_smart_dialog use overlays and self-managed route stack to show dialogs.
// It's powerful but can't behave like the default showDialog, e.g. the lack of mask animation. the lack of snackbar.
// Use the implementation should be careful, because shared route stack with the whole app, it may cause some unexpected behaviors.
// Don't use it in double PopScope widget.
class KazumiDialog {
  /// The global observer that tracks contexts across the application
  static final KazumiDialogObserver observer = KazumiDialogObserver();

  KazumiDialog._internal();

  static Future<T?> show<T>({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final result = await showDialog<T>(
          context: ctx,
          barrierDismissible: clickMaskDismiss ?? true,
          builder: builder,
          routeSettings: const RouteSettings(name: 'KazumiDialog'),
        );
        onDismiss?.call();
        return result;
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show dialog: $e');
        return null;
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the dialog');
      return null;
    }
  }

  static void showToast({
    required String message,
    BuildContext? context,
    bool showActionButton = false,
    String? actionLabel,
    Function()? onActionPressed,
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
    dynamic error,
  }) {
    final ctx = context ?? observer.scaffoldContext;
    if (ctx != null && ctx.mounted) {
      try {
        final bool isErr = isError ||
            error != null ||
            message.contains('失败') ||
            message.contains('错误') ||
            message.contains('异常');

        if (isErr) {
          KazumiLogger().log(
            Level.warning,
            'Toast Message: $message${error != null ? "\n$error" : ""}',
            error: error,
          );
        }

        bool hasAction = showActionButton;
        String? label = actionLabel;
        Function()? onAction = onActionPressed;

        ScaffoldMessenger.of(ctx)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: SelectionArea(child: Text(message)),
              behavior: SnackBarBehavior.floating,
              width: MediaQuery.sizeOf(ctx).width >
                      LayoutBreakpoint.medium['width']!
                  ? 600
                  : null,
              duration: duration,
              action: hasAction
                  ? SnackBarAction(
                      label: label ?? 'Dismiss',
                      onPressed: () {
                        onAction?.call();
                        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                      },
                    )
                  : null,
            ),
          );
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show toast: $e');
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No Scaffold context available to show Toast');
    }
  }

  static ValueNotifier<String?>? _loadingMessageNotifier;

  static Future<void> showLoading({
    BuildContext? context,
    String? msg,
    bool barrierDismissible = false,
    Function()? onDismiss,
    VoidCallback? onCancel,
  }) async {
    if (_loadingMessageNotifier != null && observer.hasKazumiDialog) {
      _loadingMessageNotifier!.value = msg ?? 'Loading...';
      return;
    }

    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      final notifier = ValueNotifier<String?>(msg ?? 'Loading...');
      _loadingMessageNotifier = notifier;
      try {
        await showDialog(
          context: ctx,
          barrierDismissible: barrierDismissible,
          builder: (BuildContext context) {
            return Center(
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<String?>(
                        valueListenable: notifier,
                        builder: (context, message, _) {
                          return Text(
                            message ?? 'Loading...',
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            onCancel();
                          },
                          child: const Text('取消等待'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          routeSettings: const RouteSettings(name: 'KazumiDialog'),
        );
        onDismiss?.call();
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show loading dialog: $e');
      } finally {
        if (_loadingMessageNotifier == notifier) {
          _loadingMessageNotifier = null;
        }
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the loading dialog');
    }
  }

  static Future<void> showErrorDialog({
    BuildContext? context,
    String? title,
    required String message,
    dynamic error,
    VoidCallback? onConfirm,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await showDialog(
          context: ctx,
          builder: (BuildContext dialogContext) {
            final dialogTitle = title ?? '错误';
            final fullCopy =
                '【$dialogTitle】\n$message${error != null ? "\n$error" : ""}';
            return AlertDialog(
              title: SelectableText(dialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(message),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        error.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullCopy));
                  },
                  child: const Text('复制报错信息'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                    onConfirm?.call();
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
          routeSettings: const RouteSettings(name: 'KazumiErrorDialog'),
        );
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show error dialog: $e');
      }
    }
  }

  static Future<T?> showBottomSheet<T>({
    BuildContext? context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
    bool useSafeArea = false,
  }) async {
    // Use provided context first, then root context, then fallback to current context
    final ctx = context ?? observer.rootContext ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final result = await showModalBottomSheet<T>(
          context: ctx,
          builder: builder,
          backgroundColor: backgroundColor,
          elevation: elevation,
          shape: shape,
          clipBehavior: clipBehavior,
          constraints: constraints,
          barrierColor: barrierColor,
          isScrollControlled: isScrollControlled,
          useRootNavigator: useRootNavigator,
          isDismissible: isDismissible,
          enableDrag: enableDrag,
          routeSettings:
              routeSettings ?? const RouteSettings(name: 'KazumiBottomSheet'),
          transitionAnimationController: transitionAnimationController,
          anchorPoint: anchorPoint,
          useSafeArea: useSafeArea,
        );
        return result;
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show bottom sheet: $e');
        return null;
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the bottom sheet');
      return null;
    }
  }

  static void dismiss([BuildContext? context]) {
    if (context != null && context.mounted) {
      Navigator.maybePop(context);
      return;
    }
    if (observer.hasKazumiDialog && observer._kazumiDialogRoutes.isNotEmpty) {
      try {
        final route = observer._kazumiDialogRoutes.last;
        if (route.navigator != null) {
          route.navigator!.pop();
          return;
        }
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to dismiss dialog: $e');
      }
    } else {
      debugPrint('Kazumi Dialog Debug: No active KazumiDialog to dismiss');
    }
  }
}

/// Navigator observer to track contexts and dialog routes
class KazumiDialogObserver extends NavigatorObserver {
  /// List of active dialog routes
  final List<Route<dynamic>> _kazumiDialogRoutes = [];

  /// The most recent context from any MaterialPageRoute or PopupRoute
  BuildContext? _currentContext;

  /// The most recent context from any route containing a Scaffold
  BuildContext? _scaffoldContext;

  /// The root context of the app (for bottom sheets to cover the entire app)
  BuildContext? _rootContext;

  BuildContext? get currentContext => _currentContext;

  BuildContext? get scaffoldContext => _scaffoldContext ?? _currentContext;

  /// Get the root context for bottom sheets, fallback to scaffold context, then current context
  BuildContext? get rootContext =>
      _rootContext ?? _scaffoldContext ?? _currentContext;

  bool get hasKazumiDialog => _kazumiDialogRoutes.isNotEmpty;

  BuildContext? get kazumiDialogContext => _kazumiDialogRoutes.isNotEmpty
      ? _kazumiDialogRoutes.last.navigator?.context
      : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.add(route);
    }
    if (route.navigator?.context != null) {
      _updateContexts(route.navigator!.context, route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _removeCurrentSnackBar(route);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context, previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_isKazumiDialogRoute(oldRoute!)) {
      _kazumiDialogRoutes.remove(oldRoute);
    }
    if (_isKazumiDialogRoute(newRoute!)) {
      _kazumiDialogRoutes.add(newRoute);
    }
    if (newRoute.navigator?.context != null) {
      _updateContexts(newRoute.navigator!.context, newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }

    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context, previousRoute);
    }
  }

  void _updateContexts(BuildContext context, Route<dynamic> route) {
    _currentContext = context;
    if (_hasScaffold(context)) {
      _scaffoldContext = context;
      // Always update root context with scaffold contexts to ensure we have the most recent one
      // This helps ensure bottom sheets appear at the app level
      _rootContext = context;
    }
  }

  bool _hasScaffold(BuildContext context) {
    return Scaffold.maybeOf(context) != null;
  }

  bool _isKazumiDialogRoute(Route<dynamic> route) {
    return route.settings.name == 'KazumiDialog' ||
        route.settings.name == 'KazumiBottomSheet';
  }

  void _removeCurrentSnackBar(Route<dynamic>? route) {
    if (route?.navigator?.context != null) {
      try {
        ScaffoldMessenger.maybeOf(route!.navigator!.context)
            ?.removeCurrentSnackBar();
      } catch (_) {}
    }
  }
}
