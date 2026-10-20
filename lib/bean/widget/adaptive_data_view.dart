import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';

/// 全局通用的自适应视图显示模式
enum AdaptiveViewMode {
  /// 自动响应式：宽屏(>=断点)自动切换为表格视图，窄屏(<断点)自动切换为卡片视图
  auto,

  /// 强制表格视图
  table,

  /// 强制卡片视图
  card,
}

/// 统一的自适应视图切换器组件（芯片/下拉菜单）
/// 规范全局多页面统一交互，清晰呈现当前状态（如「自适应 (表格)」、「自适应 (卡片)」、「锁定表格」、「锁定卡片」）
class AdaptiveViewSwitcher extends StatelessWidget {
  final AdaptiveViewMode viewMode;
  final bool isTableView;
  final ValueChanged<AdaptiveViewMode> onModeChanged;
  final String? tooltip;

  const AdaptiveViewSwitcher({
    super.key,
    required this.viewMode,
    required this.isTableView,
    required this.onModeChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String currentLabel = switch (viewMode) {
      AdaptiveViewMode.auto => isTableView ? '自适应 (表格)' : '自适应 (卡片)',
      AdaptiveViewMode.table => '锁定表格',
      AdaptiveViewMode.card => '锁定卡片',
    };

    final IconData currentIcon = switch (viewMode) {
      AdaptiveViewMode.auto => Icons.auto_awesome,
      AdaptiveViewMode.table => Icons.table_chart,
      AdaptiveViewMode.card => Icons.view_agenda_outlined,
    };

    return PopupMenuButton<AdaptiveViewMode>(
      tooltip: tooltip ??
          '视图显示模式 (当前: ${viewMode == AdaptiveViewMode.auto ? "自动响应式" : (viewMode == AdaptiveViewMode.table ? "强制表格" : "强制卡片")})',
      initialValue: viewMode,
      onSelected: onModeChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AdaptiveViewMode.auto,
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: viewMode == AdaptiveViewMode.auto
                    ? colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '自动响应式 (宽屏表格 / 窄屏卡片)',
                style: TextStyle(
                  fontWeight: viewMode == AdaptiveViewMode.auto
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: viewMode == AdaptiveViewMode.auto
                      ? colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: AdaptiveViewMode.table,
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                size: 16,
                color: viewMode == AdaptiveViewMode.table
                    ? colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '强制表格视图',
                style: TextStyle(
                  fontWeight: viewMode == AdaptiveViewMode.table
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: viewMode == AdaptiveViewMode.table
                      ? colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: AdaptiveViewMode.card,
          child: Row(
            children: [
              Icon(
                Icons.view_agenda_outlined,
                size: 16,
                color: viewMode == AdaptiveViewMode.card
                    ? colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '强制卡片视图',
                style: TextStyle(
                  fontWeight: viewMode == AdaptiveViewMode.card
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: viewMode == AdaptiveViewMode.card
                      ? colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: viewMode == AdaptiveViewMode.auto
                ? colorScheme.primary.withAlpha(120)
                : colorScheme.outlineVariant.withAlpha(80),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentIcon,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一的自适应数据视图容器组件
/// 根据自身容器的实际 constraints.maxWidth 自动在表格与卡片间响应式切换，
/// 彻底摆脱对屏幕物理像素缩放的依赖，杜绝桌面端像素溢出与放大失真。
class AdaptiveDataView extends StatelessWidget {
  final AdaptiveViewMode viewMode;
  final double breakpoint;
  final Widget Function(BuildContext context) tableBuilder;
  final Widget Function(BuildContext context) cardBuilder;

  /// 默认自适应断点（对齐 Material 3 紧凑屏基准 600dp 并预留侧边栏 100dp）
  static final double defaultBreakpoint =
      LayoutBreakpoint.compact['width']! + 100.0; // 700.0

  const AdaptiveDataView({
    super.key,
    required this.viewMode,
    this.breakpoint = 700.0,
    required this.tableBuilder,
    required this.cardBuilder,
  });

  /// 依据可用宽度判断是否呈现表格
  static bool isTableViewForWidth({
    required double availableWidth,
    required AdaptiveViewMode viewMode,
    double? breakpoint,
  }) {
    final bp = breakpoint ?? defaultBreakpoint;
    switch (viewMode) {
      case AdaptiveViewMode.auto:
        return availableWidth >= bp;
      case AdaptiveViewMode.table:
        return true;
      case AdaptiveViewMode.card:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTable = isTableViewForWidth(
          availableWidth: constraints.maxWidth,
          viewMode: viewMode,
          breakpoint: breakpoint,
        );

        if (isTable) {
          return tableBuilder(context);
        } else {
          return cardBuilder(context);
        }
      },
    );
  }
}
