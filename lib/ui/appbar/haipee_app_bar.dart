import 'dart:io' show Platform; 
import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/bean/widget/desktop_window_controls_safe_area.dart';

/// 统一外观的 AppBar 封装：普通页面使用它替代直接 new AppBar
class HaipeeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool transparent;
  final bool centerTitle;
  final double height;
  final bool enableDragOnDesktop;
  final bool requireOffset;

  const HaipeeAppBar({
    super.key,
    this.title,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.transparent = false,
    this.centerTitle = false,
    this.height = 40,
    this.enableDragOnDesktop = false,
    this.requireOffset = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = transparent
        ? Colors.transparent
        : theme.colorScheme.surface;
    final fgColor = theme.colorScheme.onSurface;

    // 可选：桌面端在标题区域支持拖动（保持插槽简洁，避免强依赖）
    Widget titleArea = title ?? const SizedBox.shrink();
    if (enableDragOnDesktop && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // 使用一个不可交互的区域模拟可拖动区域（实际拖动逻辑由外层自定义 AppBar 承担）
      titleArea = Row(children: [Expanded(child: titleArea)]);
    }

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && Navigator.canPop(context)) {
      effectiveLeading = const AppBackButton();
    }

    final bool requireLeadingOffset =
        requireOffset || Navigator.canPop(context) || (effectiveLeading is AppBackButton);

    double? effectiveLeadingWidth = leadingWidth;
    if (effectiveLeading != null) {
      effectiveLeading = DesktopWindowControlsSafeArea.wrapLeading(
        effectiveLeading,
        requireOffset: requireLeadingOffset,
      );
      effectiveLeadingWidth = DesktopWindowControlsSafeArea.leadingWidth(
        leadingWidth,
        requireOffset: requireLeadingOffset,
      );
    } else if (DesktopWindowControlsSafeArea.shouldAvoid(requireOffset: requireOffset)) {
      effectiveLeading = const SizedBox(
        width: DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth,
      );
      effectiveLeadingWidth = DesktopWindowControlsSafeArea.leadingWidth(
        leadingWidth ?? 0.0,
        requireOffset: requireOffset,
      );
    }

    return AppBar(
      backgroundColor: bgColor,
      elevation: transparent ? 0 : 0.5,
      scrolledUnderElevation: 0,
      titleTextStyle: theme.textTheme.titleMedium?.copyWith(color: fgColor),
      iconTheme: IconThemeData(color: fgColor, size: 22),
      centerTitle: centerTitle,
      title: titleArea,
      leading: effectiveLeading,
      leadingWidth: effectiveLeadingWidth,
      actions: actions,
      toolbarHeight: height,
      surfaceTintColor: Colors.transparent,
    );
  }
}
