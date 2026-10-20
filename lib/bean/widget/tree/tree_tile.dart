import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/tree/tree_indent.dart';

/// 统一领域语义树形瓦片组件 (TreeTile)
///
/// 遵循核心架构原则：
/// "不要试图创造一个‘永远不会溢出的 Row’；而应该创造‘业务上永远不需要直接操心布局细节的组件’。"
/// "不要消灭 Expanded，而是消灭‘业务开发者思考 Expanded’。"
///
/// 严格的插槽布局契约 (Slot-based Layout Contract)：
/// 1. [depth] / 缩进槽：自动受边界约束，绝不侵占过多横向宽度。
/// 2. [expandIcon] / 折叠箭头槽：定宽对齐 (22dp)。
/// 3. [checkbox] / 复选框槽：定宽对齐 (24dp)。
/// 4. [icon] / 类型图标槽：定宽对齐 (20dp)。
/// 5. [title] / 文件与目录名称：强制 Expanded 并单行省略号截断，无论文字多长绝不溢出。
/// 6. [trailing] / 紧凑元数据槽：自适应收敛，超长自裁切。
class TreeTile extends StatelessWidget {
  /// 树层级深度
  final int depth;

  /// 单级缩进基础宽度
  final double indentWidth;

  /// 最大允许缩进上限
  final double maxIndent;

  /// 折叠展开按钮槽位（目录节点专用）
  final Widget? expandIcon;

  /// 是否为无展开按钮的叶子节点保留占位间隙以保证对齐
  final bool reserveExpandSpace;

  /// 三联复选框槽位
  final Widget? checkbox;

  /// 文件/目录类型图标槽位
  final Widget? icon;

  /// 标题内容槽位（自动包裹于 Expanded 中并配置单行省略契约）
  final Widget title;

  /// 紧凑尾部信息槽位（如文件大小、项数统计胶囊）
  final Widget? trailing;

  /// 点击回调
  final VoidCallback? onTap;

  /// 双击回调
  final VoidCallback? onDoubleTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 是否高亮选中
  final bool selected;

  /// 选中的背景颜色
  final Color? selectedTileColor;

  /// 内边距（默认上下 2dp，左右 8dp）
  final EdgeInsetsGeometry contentPadding;

  const TreeTile({
    super.key,
    required this.depth,
    this.indentWidth = 14.0,
    this.maxIndent = 48.0,
    this.expandIcon,
    this.reserveExpandSpace = true,
    this.checkbox,
    this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.selected = false,
    this.selectedTileColor,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget effectiveTitle = DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      child: title,
    );

    return Material(
      color: selected
          ? (selectedTileColor ?? colorScheme.primaryContainer.withAlpha(80))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: contentPadding,
          child: Row(
            spacing: 6,
            children: [
              // 1. 深度缩进槽
              TreeIndent(
                depth: depth,
                indentWidth: indentWidth,
                maxIndent: maxIndent,
              ),

              // 2. 展开箭头槽
              if (expandIcon != null)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(child: expandIcon),
                )
              else if (reserveExpandSpace)
                const SizedBox(width: 22),

              // 3. 复选框槽
              if (checkbox != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(child: checkbox),
                ),

              // 4. 类型图标槽
              if (icon != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(child: icon),
                ),

              // 5. 核心标题槽（严格 Expanded，彻底杜绝 RenderFlex 溢出）
              Expanded(
                child: effectiveTitle,
              ),

              // 6. 紧凑元数据槽
              if (trailing != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
