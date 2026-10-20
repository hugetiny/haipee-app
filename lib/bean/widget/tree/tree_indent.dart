import 'package:flutter/material.dart';

/// 统一树形缩进组件
/// 严格契约：基于节点深度 (depth) 自动计算边界安全的物理缩进，彻底杜绝业务层手动计算与魔数 clamp
class TreeIndent extends StatelessWidget {
  /// 当前节点在树中的层级深度（从 0 开始）
  final int depth;

  /// 单级缩进基础宽度（默认 14.0dp）
  final double indentWidth;

  /// 最大允许缩进上限（默认 48.0dp，保证极深目录结构下依然给文件名留出足够渲染空间）
  final double maxIndent;

  const TreeIndent({
    super.key,
    required this.depth,
    this.indentWidth = 14.0,
    this.maxIndent = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    if (depth <= 0) {
      return const SizedBox.shrink();
    }

    final double effectiveWidth = (depth * indentWidth).clamp(0.0, maxIndent);
    return SizedBox(width: effectiveWidth);
  }
}
