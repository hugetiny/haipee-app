import 'package:flutter/material.dart';
export 'package:kazumi/bean/widget/settings/card_settings_ui.dart' show SettingsBadge;

/// 统一规则卡片组件 (Unified Rule Grid Card Component)
///
/// 服务于 Kazumi 视频规则与 Cardigann 规则，提供高度一致的视觉质感、槽位布局与交互体系：
/// 1. 顶部槽位：类型/状态图标徽章（多选模式下为选择框）、规则标题、标识/版本号标签、状态开关 (Switch) 或自定义操作
/// 2. 信息槽位：站点/主域名可点击链接、来源性质（预置/自定义/覆写）、解析协议/类型、播放特性、有效性及更新状态徽章
/// 3. 说明槽位：多行描述文本，完整显示不截断
/// 4. 底部动作条：统一采用 Wrap 响应式流式布局，放置测试抓取 (Dry-Run)、查看/编辑、在线更新、分享、凭据配置与删除重置按钮
class UnifiedRuleCard extends StatelessWidget {
  /// 规则名称
  final String title;

  /// 标题旁边的徽章标签（如版本号或内部 ID）
  final Widget? titleBadge;

  /// 左侧图标或前缀组件
  final Widget? icon;

  /// 图标容器背景色调（用于区分规则类型或启用状态）
  final Color? iconColor;

  /// 是否启用
  final bool enabled;

  /// 启用开关变更回调（为 null 时不显示 Switch 开关）
  final ValueChanged<bool>? onEnabledChanged;

  /// 右上角自定义尾部组件（用于替代 Switch，例如安装/升级按钮）
  final Widget? trailing;

  /// 规则主域名或站点链接
  final String? url;

  /// 链接悬浮提示说明
  final String? urlTooltip;

  /// 点击链接回调
  final VoidCallback? onUrlTap;

  /// 规则徽章列表（来源、分类、协议、特性、有效性等）
  final List<Widget> badges;

  /// 规则描述信息（完整显示不截断）
  final String? description;

  /// 底部快捷操作按钮组（测试、编辑、更新、分享、删除等）
  final List<Widget> actions;

  /// 是否处于多选模式
  final bool isMultiSelectMode;

  /// 当前卡片是否被选中
  final bool isSelected;

  /// 卡片点击回调
  final VoidCallback? onTap;

  /// 卡片长按回调（如触发多选）
  final VoidCallback? onLongPress;

  /// 卡片内边距
  final EdgeInsetsGeometry padding;

  const UnifiedRuleCard({
    super.key,
    required this.title,
    this.titleBadge,
    this.icon,
    this.iconColor,
    this.enabled = true,
    this.onEnabledChanged,
    this.trailing,
    this.url,
    this.urlTooltip,
    this.onUrlTap,
    this.badges = const [],
    this.description,
    this.actions = const [],
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveCardColor = isSelected
        ? colorScheme.primaryContainer.withAlpha(90)
        : colorScheme.surfaceContainer;

    final effectiveBorderSide = isSelected
        ? BorderSide(color: colorScheme.primary, width: 1.5)
        : BorderSide(color: colorScheme.outlineVariant.withAlpha(55), width: 0.8);

    return Card(
      elevation: 0,
      color: effectiveCardColor,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: effectiveBorderSide,
      ),
      child: InkWell(
        onTap: isMultiSelectMode
            ? onTap
            : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 上半部分：头部信息 + 标签组 + 描述
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头部：图标/选择框 + 规则标题与版本 + 开关/自定义尾部
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMultiSelectMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 10, top: 2),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => onTap?.call(),
                          ),
                        )
                      else if (icon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: enabled
                                ? (iconColor != null
                                    ? iconColor!.withAlpha(35)
                                    : colorScheme.primaryContainer)
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: icon,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (titleBadge != null) ...[
                                  const SizedBox(width: 6),
                                  titleBadge!,
                                ],
                              ],
                            ),
                            if (url != null && url!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Tooltip(
                                message: urlTooltip ?? '打开站点主页:\n$url',
                                child: InkWell(
                                  onTap: onUrlTap,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new,
                                        size: 11,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          url!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null)
                        trailing!
                      else if (onEnabledChanged != null && !isMultiSelectMode)
                        Switch(
                          value: enabled,
                          onChanged: onEnabledChanged,
                        ),
                    ],
                  ),

                  // 徽章标签组
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: badges,
                    ),
                  ],

                  // 描述说明（完整显示）
                  if (description != null && description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),

              // 下半部分：分割线 + 底部操作按钮组
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withAlpha(50),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一自适应规则网格组件 (Unified Rule Grid)
///
/// 采用响应式多列自适应布局，根据容器宽度动态计算最适列数：
/// - 极窄/移动竖屏 (< 680): 单列完整呈现
/// - 折叠屏/平板/中等窗口 (680 ~ 1180): 双列自适应
/// - 宽屏桌面 (1180 ~ 1680): 三列优雅网格
/// - 超宽显示器 (>= 1680): 四列高密度排版
///
/// 每行通过 [IntrinsicHeight] 动态拉伸卡片高度，保证同行卡片整齐统一，
/// 且内容永不发生 [RenderFlex] 溢出截断。
class UnifiedRuleGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double runSpacing;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final int? forcedColumns;

  const UnifiedRuleGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
    this.runSpacing = 12,
    this.physics,
    this.controller,
    this.forcedColumns,
  });

  /// 依据可用容器宽度计算最适列数（响应式平滑阶梯，宽屏超宽屏智能扩展）
  static int columnsForWidth(double width) {
    if (width < 650) return 1;
    if (width < 1100) return 2;
    if (width < 1550) return 3;
    if (width < 2000) return 4;
    if (width < 2500) return 5;
    if (width < 3000) return 6;
    if (width < 3500) return 7;
    return (width / 480).floor().clamp(1, 10);
  }

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = forcedColumns ?? columnsForWidth(constraints.maxWidth);

        if (columns <= 1) {
          return ListView.separated(
            controller: controller,
            physics: physics,
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, __) => SizedBox(height: runSpacing),
            itemBuilder: itemBuilder,
          );
        }

        final rowCount = (itemCount + columns - 1) ~/ columns;

        return ListView.separated(
          controller: controller,
          physics: physics,
          padding: padding,
          itemCount: rowCount,
          separatorBuilder: (_, __) => SizedBox(height: runSpacing),
          itemBuilder: (context, rowIndex) {
            final startIndex = rowIndex * columns;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: spacing),
                    Expanded(
                      child: (startIndex + col < itemCount)
                          ? itemBuilder(context, startIndex + col)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
