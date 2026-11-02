import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/responsive/breakpoints.dart';
import 'package:haipee/bean/widget/responsive/responsive_builder.dart';

/// 槽位式响应式分发容器组件
/// 提供 mobile / tablet / desktop 三种经典视口插槽，未显式提供的插槽会自动优雅降级
class ResponsiveLayout extends StatelessWidget {
  /// 移动端布局构建器（必选基准）
  final WidgetBuilder mobile;

  /// 平板端布局构建器（可选，默认降级为 mobile）
  final WidgetBuilder? tablet;

  /// 桌面端布局构建器（可选，默认降级为 tablet ?? mobile）
  final WidgetBuilder? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType, constraints) {
        switch (screenType) {
          case ScreenType.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case ScreenType.tablet:
            return (tablet ?? mobile)(context);
          case ScreenType.mobile:
            return mobile(context);
        }
      },
    );
  }
}
