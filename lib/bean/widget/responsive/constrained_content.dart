import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/responsive/breakpoints.dart';

/// 统一受约束内容容器组件
/// 针对宽屏/桌面端强制限制最大内容宽度并水平居中，防止表单、详情或列表在 2K/4K 大屏无限拉伸
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.defaultMaxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return content;
  }
}
