import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haipee/services/logging/app_log.dart';

/// Global overlay providing:
/// 1. Desktop keyboard shortcuts (`F12`, `Cmd+Shift+L`, `Ctrl+Shift+L`) for instant log toggling.
/// 2. Floating interactive HUD chip with error counter when developer mode is active.
class DebugHudOverlay extends StatefulWidget {
  const DebugHudOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DebugHudOverlay> createState() => _DebugHudOverlayState();
}

class _DebugHudOverlayState extends State<DebugHudOverlay> {
  Offset? _hudOffset;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!AppLog.isDebugMode) return false;
    if (event is! KeyDownEvent) return false;

    // F12 key
    if (event.logicalKey == LogicalKeyboardKey.f12) {
      AppLog.toggleLogScreen();
      return true;
    }

    // Cmd+Shift+L (macOS) or Ctrl+Shift+L (Windows/Linux)
    final isMetaOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (isMetaOrCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyL) {
      AppLog.toggleLogScreen();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLog.listenable,
      builder: (context, _) {
        // Only display floating HUD when in developer debug mode and log screen is not open
        final showHud = AppLog.isDebugMode && !AppLog.isLogScreenOpen;

        if (!showHud) {
          return widget.child;
        }

        final theme = Theme.of(context);
        final errorCount = AppLog.errorCount;
        final mq = MediaQuery.of(context);

        // Initial default position: bottom-right
        final defaultOffset = Offset(
          mq.size.width - 110,
          mq.size.height - 100,
        );
        final pos = _hudOffset ?? defaultOffset;

        // Clamp position within viewport
        final clampedX = pos.dx.clamp(10.0, (mq.size.width - 110).clamp(10.0, mq.size.width));
        final clampedY = pos.dy.clamp(mq.padding.top + 10.0, (mq.size.height - 60).clamp(10.0, mq.size.height));

        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            widget.child,
            Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _hudOffset = Offset(
                      clampedX + details.delta.dx,
                      clampedY + details.delta.dy,
                    );
                  });
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => AppLog.toggleLogScreen(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (errorCount > 0
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.surfaceContainerHighest)
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: errorCount > 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            errorCount > 0
                                ? Icons.error_outline_rounded
                                : Icons.terminal_rounded,
                            size: 16,
                            color: errorCount > 0
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            errorCount > 0 ? '$errorCount' : 'DevLog',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: errorCount > 0
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
