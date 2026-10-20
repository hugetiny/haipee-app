import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/responsive/breakpoints.dart';

/// 响应式组件构建函数签名
typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  ScreenType screenType,
  BoxConstraints constraints,
);

/// 基于父级实际约束的响应式组件构建器
/// 彻底摆脱对单一屏幕物理宽度的依赖，在多列分栏、弹窗、侧边栏或主视口中均能以实际可用空间自适应
class ResponsiveBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double effectiveWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final screenType = AppBreakpoints.getScreenType(effectiveWidth);
        return builder(context, screenType, constraints);
      },
    );
  }
}
