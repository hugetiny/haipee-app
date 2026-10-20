import 'package:flutter/material.dart';

/// 统一响应式流式布局组件
/// 封装间距规范，当可用宽度低于折叠断点时，自动将流式元素重组为垂直列，避免拥挤和单项溢出
class AdaptiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final double? collapseBreakpoint;

  const AdaptiveWrap({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.alignment = WrapAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.center,
    this.collapseBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    if (collapseBreakpoint == null) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        runAlignment: runAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < collapseBreakpoint!) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) SizedBox(height: runSpacing),
              ],
            ],
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: alignment,
          runAlignment: runAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        );
      },
    );
  }
}
