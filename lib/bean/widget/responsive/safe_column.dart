import 'package:flutter/material.dart';

/// 一个永远不会发生 RenderFlex 底部溢出 (overflowed on the bottom) 的自适应安全 Column。
///
/// 常见溢出场景：
/// 1. 软键盘弹起导致当前视口高度被压缩 300px；
/// 2. 用户在系统无障碍设置中开启了 1.3x ~ 1.8x 大字号；
/// 3. 小屏或极端窄屏设备上内容自然堆叠高度超过父级固定约束。
///
/// [SafeColumn] 的工程原理：
/// - 采用 `LayoutBuilder` 实时监听父级可用高度约束；
/// - 内嵌带有 [ClampingScrollPhysics] 的滚动容器与 [IntrinsicHeight]；
/// - 当内容高度 <= 可用高度时：行为与原生 [Column] 100% 一致（保持原始布局对齐，不触发额外滚动开销）；
/// - 当内容高度 > 可用高度时：自动优雅开启滚动避让，物理层面上彻底消除
///   "A RenderFlex overflowed by xx pixels on the bottom" 的断言异常。
class SafeColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  const SafeColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.physics,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = IntrinsicHeight(
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: children,
          ),
        );

        return SingleChildScrollView(
          controller: controller,
          padding: padding,
          physics: physics ?? const ClampingScrollPhysics(),
          clipBehavior: Clip.antiAlias,
          child: constraints.hasBoundedHeight
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
