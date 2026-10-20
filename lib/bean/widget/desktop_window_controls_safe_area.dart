import 'dart:io';
import 'package:flutter/material.dart';

/// 桌面端窗口原生控制区（如 macOS 红黄绿交通灯）自适应安全区域组件
///
/// 在 macOS 平台使用 TitleBarStyle.hidden（隐藏原生标题栏）时，原生交通灯按钮（关闭、最小化、缩放）
/// 位于窗口左上角区域（约 x: 0..76, y: 0..38）。
///
/// 由于 Flutter 引擎在桌面端不会将原生窗口按钮上报为 [MediaQueryData.padding]（仍返回 EdgeInsets.zero），
/// 如果页面使用标准 [AppBar] 或未做避让的顶部行，回退按钮与标题将直接与红黄绿按钮重叠穿透。
///
/// [DesktopWindowControlsSafeArea] 提供以下系统级能力：
/// 1. 作为包装组件：为子组件（顶部工具栏、自定义 Overlay、Header）自动注入安全的左侧/顶部边距；
/// 2. 静态辅助方法：[wrapLeading]、[leadingWidth]、[shouldAvoid]，供 [SysAppBar]、[SliverAppBar] 等无缝复用；
/// 3. 与全局架构契合：当处于全屏状态或已有左侧导航栏（NavigationRail）时，自动停用左侧避让，避免多余留白。
class DesktopWindowControlsSafeArea extends StatelessWidget {
  /// macOS 原生红黄绿三色控制按钮占用的横向基准安全宽度（含外边距）
  static const double kMacOsTrafficLightsWidth = 76.0;

  /// macOS 原生红黄绿三色控制按钮占用的纵向基准安全高度
  static const double kMacOsTrafficLightsHeight = 38.0;

  /// 子组件
  final Widget child;

  /// 是否需要避让（默认 true，若页面已有全局侧边栏或全屏播放可设为 false）
  final bool requireOffset;

  /// 是否避让左侧（主要用于防止返回按钮与红黄绿重叠）
  final bool avoidLeft;

  /// 是否避让顶部
  final bool avoidTop;

  /// 自定义左侧避让宽度，若为空则使用 [kMacOsTrafficLightsWidth]
  final double? customLeftWidth;

  const DesktopWindowControlsSafeArea({
    super.key,
    required this.child,
    this.requireOffset = true,
    this.avoidLeft = true,
    this.avoidTop = false,
    this.customLeftWidth,
  });

  /// 判断当前环境是否需要避让 macOS 原生视窗按钮
  static bool shouldAvoid({bool requireOffset = true}) {
    return Platform.isMacOS && requireOffset;
  }

  /// 计算 AppBar / SliverAppBar 上的 leadingWidth，确保加上 76px 避让间距
  static double leadingWidth(double? baseWidth, {bool requireOffset = true}) {
    final base = baseWidth ?? 48.0;
    if (shouldAvoid(requireOffset: requireOffset)) {
      return base + kMacOsTrafficLightsWidth;
    }
    return base;
  }

  /// 为 leading 组件注入安全左边距；若 leading 为空则返回 76px 的占位组件以防标题重叠
  static Widget? wrapLeading(Widget? leading, {bool requireOffset = true}) {
    if (!shouldAvoid(requireOffset: requireOffset)) {
      return leading;
    }
    if (leading != null) {
      return Padding(
        padding: const EdgeInsets.only(left: kMacOsTrafficLightsWidth),
        child: leading,
      );
    }
    return const SizedBox(width: kMacOsTrafficLightsWidth);
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldAvoid(requireOffset: requireOffset)) {
      return child;
    }

    final double left =
        avoidLeft ? (customLeftWidth ?? kMacOsTrafficLightsWidth) : 0.0;
    final double top = avoidTop ? kMacOsTrafficLightsHeight : 0.0;

    if (left == 0.0 && top == 0.0) {
      return child;
    }

    return Padding(
      padding: EdgeInsets.only(left: left, top: top),
      child: child,
    );
  }
}
