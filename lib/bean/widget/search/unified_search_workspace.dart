import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/adaptive_data_view.dart';
import 'package:haipee/modules/search/search_history_dropdown.dart';

/// 筛选条件摘要项（用于筛选面板收起时展示当前已激活的过滤条件）
class UnifiedActiveFilterTag {
  final String label;
  final VoidCallback onDeleted;

  const UnifiedActiveFilterTag({
    required this.label,
    required this.onDeleted,
  });
}

/// 规则就绪状态徽章数据（用于搜索页空闲首屏展示已启用规则概览）
class UnifiedRuleBadgeData {
  final IconData icon;
  final String label;
  final int count;

  const UnifiedRuleBadgeData({
    required this.icon,
    required this.label,
    required this.count,
  });
}

/// 统一搜索工作区头部组件（对标 AppFlowy / Spotube / PiliPala 标准组件复用架构）
///
/// 由「视频直播 (OnlineVideoSearchPage)」与「全网资源 (ResourceSearchPage)」共同复用：
/// 1. 统一搜索输入框 + 下拉搜索历史 (`SearchHistoryDropdown`)
/// 2. 搜索框右侧统一的「筛选」展开/收起按钮（带激活条件计数徽章）
/// 3. 搜索框右侧统一的「表格 / 网格」视图切换快捷按钮
/// 4. 收起态下的已激活筛选标签条 + 展开态下的多维分类筛选面板 (`filterPanel`)
class UnifiedSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final Key filterToggleKey;
  final bool isFilterExpanded;
  final VoidCallback onToggleFilter;
  final int activeFilterCount;
  final List<UnifiedActiveFilterTag> activeFilterTags;
  final VoidCallback? onResetFilters;
  final Widget? filterPanel;
  final AdaptiveViewMode? viewMode;
  final bool? isTableView;
  final ValueChanged<AdaptiveViewMode>? onViewModeChanged;

  const UnifiedSearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSearch,
    required this.onClear,
    required this.filterToggleKey,
    required this.isFilterExpanded,
    required this.onToggleFilter,
    this.activeFilterCount = 0,
    this.activeFilterTags = const [],
    this.onResetFilters,
    this.filterPanel,
    this.viewMode,
    this.isTableView,
    this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasActiveFilter = activeFilterCount > 0 || activeFilterTags.isNotEmpty;

    final isUltraNarrow = MediaQuery.sizeOf(context).width < 420;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isUltraNarrow ? 12 : 20,
        16,
        isUltraNarrow ? 12 : 20,
        12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 搜索输入框 + 右侧「筛选」按钮 + 可选「视图切换」按钮
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SearchHistoryDropdown(
                      controller: controller,
                      focusNode: focusNode,
                      onSelectKeyword: onSearch,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: onSearch,
                        decoration: InputDecoration(
                          hintText: hintText,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minHeight: 38,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: onClear,
                                ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 19),
                                tooltip: '开始搜索',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                onPressed: () => onSearch(controller.text),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isUltraNarrow ? 10 : 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isUltraNarrow ? 6 : 10),
                  // 搜索框旁边的统一「筛选」按钮
                  SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      key: filterToggleKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: isFilterExpanded || hasActiveFilter
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                        foregroundColor: isFilterExpanded || hasActiveFilter
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltraNarrow ? 10 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isFilterExpanded || hasActiveFilter
                                ? colorScheme.primary.withValues(alpha: 0.45)
                                : colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      onPressed: onToggleFilter,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '筛选',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (activeFilterCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$activeFilterCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 2),
                          Icon(
                            isFilterExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (viewMode != null &&
                      isTableView != null &&
                      onViewModeChanged != null) ...[
                    SizedBox(width: isUltraNarrow ? 6 : 8),
                    UnifiedViewToggleButtons(
                      viewMode: viewMode!,
                      isTableView: isTableView!,
                      onModeChanged: onViewModeChanged!,
                    ),
                  ],
                ],
              ),

              // 2. 当筛选面板收起且存在已激活筛选条件时，展示紧凑的当前筛选条件摘要条
              if (!isFilterExpanded && activeFilterTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 15,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '当前筛选:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      for (final tag in activeFilterTags)
                        InputChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            tag.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: tag.onDeleted,
                        ),
                      if (onResetFilters != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: onResetFilters,
                          icon: const Icon(Icons.restart_alt_rounded, size: 15),
                          label: const Text(
                            '重置全部',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // 3. 点开「筛选」按钮后展开的结构化多维度分类筛选面板
              if (isFilterExpanded && filterPanel != null) ...[
                const SizedBox(height: 12),
                filterPanel!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一的「网格视图 / 表格视图」双态切换组件（支持一键切换 Grid View 与 Table View）
class UnifiedViewToggleButtons extends StatelessWidget {
  final AdaptiveViewMode viewMode;
  final bool isTableView;
  final ValueChanged<AdaptiveViewMode> onModeChanged;

  const UnifiedViewToggleButtons({
    super.key,
    required this.viewMode,
    required this.isTableView,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            context,
            key: const Key('unified_view_mode_grid'),
            icon: Icons.grid_view_rounded,
            tooltip: '网格视图 (Grid View)',
            selected: !isTableView,
            onTap: () => onModeChanged(AdaptiveViewMode.card),
          ),
          const SizedBox(width: 2),
          _buildSegment(
            context,
            key: const Key('unified_view_mode_table'),
            icon: Icons.table_rows_rounded,
            tooltip: '表格视图 (Table View)',
            selected: isTableView,
            onTap: () => onModeChanged(AdaptiveViewMode.table),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 统一结构化筛选面板容器（供「视频直播」与「全网资源」复用）
class UnifiedFilterPanelContainer extends StatelessWidget {
  final Key? panelKey;
  final List<Widget> rows;

  const UnifiedFilterPanelContainer({
    super.key,
    this.panelKey,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: panelKey,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 统一筛选分类行组件（供「视频直播」与「全网资源」复用）
class UnifiedFilterCategoryRow extends StatelessWidget {
  final String categoryTitle;
  final String categorySubtitle;
  final List<Widget> chips;
  final Widget? trailing;

  const UnifiedFilterCategoryRow({
    super.key,
    required this.categoryTitle,
    required this.categorySubtitle,
    required this.chips,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                categoryTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                categorySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}

/// 统一筛选单选芯片组件（供「视频直播」与「全网资源」复用）
class UnifiedFilterChoiceChip extends StatelessWidget {
  final Key chipKey;
  final IconData icon;
  final String label;
  final int count;
  final bool showCount;
  final bool isSelected;
  final VoidCallback onSelected;

  const UnifiedFilterChoiceChip({
    super.key,
    required this.chipKey,
    required this.icon,
    required this.label,
    this.count = 0,
    this.showCount = false,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      key: chipKey,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (count > 0
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.3))
                    : (count > 0
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (count > 0
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface)
                      : (count > 0 ? colorScheme.primary : colorScheme.outline),
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// 统一搜索结果统计与检索状态栏（供「视频直播」与「全网资源」复用）
class UnifiedSearchResultSummaryBar extends StatelessWidget {
  final IconData headerIcon;
  final String countLabel;
  final bool isSearching;
  final int completedSources;
  final int totalSources;
  final AdaptiveViewMode? viewMode;
  final bool? isTableView;
  final ValueChanged<AdaptiveViewMode>? onViewModeChanged;
  final bool showViewToggle;
  final Widget? trailing;

  const UnifiedSearchResultSummaryBar({
    super.key,
    required this.headerIcon,
    required this.countLabel,
    required this.isSearching,
    required this.completedSources,
    required this.totalSources,
    this.viewMode,
    this.isTableView,
    this.onViewModeChanged,
    this.showViewToggle = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  countLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isSearching) ...[
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    totalSources > 0
                        ? '正在并发检索 ($completedSources/$totalSources 个源)...'
                        : '正在并发检索...',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (totalSources > 0) ...[
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '已检索全部 $totalSources 个源',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (trailing != null) trailing!,
              if (showViewToggle &&
                  viewMode != null &&
                  isTableView != null &&
                  onViewModeChanged != null)
                UnifiedViewToggleButtons(
                  viewMode: viewMode!,
                  isTableView: isTableView!,
                  onModeChanged: onViewModeChanged!,
                ),
            ],
          ),
          if (isSearching && totalSources > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (completedSources / totalSources).clamp(0.0, 1.0),
                minHeight: 2,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 统一规则就绪看板组件（供「视频直播」与「全网资源」在未搜索空闲态共同复用）
class UnifiedRuleReadinessCard extends StatelessWidget {
  final String title;
  final List<UnifiedRuleBadgeData> badges;

  const UnifiedRuleReadinessCard({
    super.key,
    required this.title,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_outlined,
                          color: colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final badge in badges)
                        _buildBadge(colorScheme, badge),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(ColorScheme colorScheme, UnifiedRuleBadgeData badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badge.count > 0
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${badge.count}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    badge.count > 0 ? colorScheme.primary : colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
