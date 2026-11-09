import 'package:flutter/material.dart';

/// 商业级多端自适应模态弹窗外框 (Adaptive Dialog Frame)
///
/// 遵循现代移动端与桌面端主流响应式设计规范：
/// - 移动端 / 紧凑视口 (< 640px)：
///   展示为贴合屏幕底部、100% 满宽的底部抽屉 (Modal BottomSheet 质感)；
///   具备顶部灰色胶囊拖拽指示条 (Drag Handle Indicator)、优雅圆角 (24dp) 与安全区感知；
///   键盘弹出时自适应向上推移，彻底避免居中小框在手机上的局促与拥挤感。
/// - 桌面端 / 宽屏视口 (>= 640px)：
///   居中优雅浮层弹窗，具备合理的 maxWidth / maxHeight 约束与外边距。
class AdaptiveDialogFrame extends StatelessWidget {
  final Widget? child;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;
  final double mobileMaxHeightFactor;
  final bool showDragHandle;
  final Clip clipBehavior;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final bool expand;
  final bool scrollable;

  const AdaptiveDialogFrame({
    super.key,
    this.child,
    this.title,
    this.content,
    this.actions,
    this.maxWidth = 600,
    this.maxHeight = 720,
    this.mobileMaxHeightFactor = 0.90,
    this.showDragHandle = true,
    this.clipBehavior = Clip.antiAlias,
    this.backgroundColor,
    this.padding,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.expand = false,
    this.scrollable = true,
  }) : assert(child != null || content != null || title != null,
            '必须提供 child 或 content/title 之一');

  /// 快捷呼出响应式弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    RouteSettings? routeSettings,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      routeSettings: routeSettings,
      builder: builder,
    );
  }

  Widget _buildBody(BuildContext context, bool isMobile) {
    if (child != null) {
      return padding != null ? Padding(padding: padding!, child: child) : child!;
    }

    final theme = Theme.of(context);
    final List<Widget> columnChildren = [];

    // Header / Title
    if (title != null) {
      columnChildren.add(
        Padding(
          padding: titlePadding ??
              EdgeInsets.fromLTRB(
                  20, isMobile ? 12 : 18, 20, isMobile ? 10 : 14),
          child: DefaultTextStyle(
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ) ??
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            child: title!,
          ),
        ),
      );
      columnChildren.add(
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.35),
        ),
      );
    }

    // Content
    if (content != null) {
      final effectiveContent = Padding(
        padding: contentPadding ??
            EdgeInsets.fromLTRB(20, 14, 20, actions != null && actions!.isNotEmpty ? 12 : 20),
        child: content!,
      );

      if (expand) {
        columnChildren.add(
          Expanded(
            child: scrollable
                ? SingleChildScrollView(child: effectiveContent)
                : effectiveContent,
          ),
        );
      } else {
        columnChildren.add(
          Flexible(
            child: scrollable
                ? SingleChildScrollView(child: effectiveContent)
                : effectiveContent,
          ),
        );
      }
    }

    // Actions / Footer
    if (actions != null && actions!.isNotEmpty) {
      columnChildren.add(
        Container(
          padding: actionsPadding ??
              EdgeInsets.fromLTRB(
                16,
                10,
                16,
                12 + (isMobile ? MediaQuery.paddingOf(context).bottom : 0),
              ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions!,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: columnChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < 640;
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    final bodyWidget = _buildBody(context, isMobile);

    if (isMobile) {
      final targetHeight = screenHeight * mobileMaxHeightFactor;
      return Dialog(
        insetPadding: EdgeInsets.only(top: mediaQuery.padding.top + 12),
        alignment: Alignment.bottomCenter,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: double.infinity,
          height: expand ? targetHeight : null,
          constraints: expand
              ? null
              : BoxConstraints(
                  maxHeight: targetHeight,
                ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: clipBehavior,
          child: SafeArea(
            top: false,
            bottom: actions == null || actions!.isEmpty,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: mediaQuery.viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  if (expand)
                    Expanded(child: bodyWidget)
                  else
                    Flexible(child: bodyWidget),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      alignment: Alignment.center,
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: clipBehavior,
      child: Container(
        width: maxWidth,
        height: expand ? maxHeight : null,
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: bodyWidget,
      ),
    );
  }
}
