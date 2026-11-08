import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/adaptive_data_view.dart';
import 'package:haipee/bean/widget/search/unified_search_workspace.dart';
import 'package:haipee/modules/search/search_history_provider.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/resource/resource_search_content.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/utils.dart';

/// 全网资源搜索一级页面（支持 Mikan、Nyaa、Torznab 聚合直搜与一键下载/播放）
/// 与「在线视频搜索 (OnlineVideoSearchPage)」共享统一的 UnifiedSearchHeader、
/// 可展开分类筛选面板 (UnifiedFilterPanelContainer) 与「网格视图 / 表格视图」切换能力
class ResourceSearchPage extends ConsumerStatefulWidget {
  const ResourceSearchPage({super.key});

  @override
  ConsumerState<ResourceSearchPage> createState() => _ResourceSearchPageState();
}

class _ResourceSearchPageState extends ConsumerState<ResourceSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isFilterExpanded = false;
  AdaptiveViewMode _viewMode = AdaptiveViewMode.auto;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    final currentKeyword = ref.read(torrentSearchProvider).keyword;
    if (currentKeyword.isNotEmpty) {
      _searchController.text = currentKeyword;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  void _performSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _searchFocusNode.unfocus();
    ref.read(searchHistoryProvider.notifier).addHistory(clean);
    ref.read(torrentSearchProvider.notifier).search(clean);
  }

  bool _isTableViewForWidth(double availableWidth) {
    final breakpoint = LayoutBreakpoint.compact['width']! + 100.0;
    switch (_viewMode) {
      case AdaptiveViewMode.auto:
        return availableWidth >= breakpoint;
      case AdaptiveViewMode.table:
        return true;
      case AdaptiveViewMode.card:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;
    final searchState = ref.watch(torrentSearchProvider);
    final searchNotifier = ref.read(torrentSearchProvider.notifier);

    ref.listen<String>(torrentSearchProvider.select((s) => s.keyword), (prev, next) {
      if (next.isNotEmpty && _searchController.text != next) {
        _searchController.text = next;
      }
    });

    final activeTags = <UnifiedActiveFilterTag>[
      if (searchState.categoryFilter != TorrentCategory.all)
        UnifiedActiveFilterTag(
          label: '分类: ${searchState.categoryFilter.label}',
          onDeleted: () => searchNotifier.setCategoryFilter(TorrentCategory.all),
        ),
      if (searchState.ruleProtocolFilter != null &&
          searchState.ruleProtocolFilter != 'all')
        UnifiedActiveFilterTag(
          label: searchState.ruleProtocolFilter == 'alist'
              ? '协议: AList 规则'
              : '协议: Cardigann 规则',
          onDeleted: () => searchNotifier.setRuleProtocolFilter('all'),
        ),
      if (searchState.trackerTypeFilter != null &&
          searchState.trackerTypeFilter != 'all')
        UnifiedActiveFilterTag(
          label: '性质: ${searchState.trackerTypeFilter}',
          onDeleted: () => searchNotifier.setTrackerTypeFilter('all'),
        ),
      if (searchState.indexerFilter != null &&
          searchState.indexerFilter!.isNotEmpty &&
          searchState.indexerFilter != '全部')
        UnifiedActiveFilterTag(
          label: '站点: ${searchState.indexerFilter}',
          onDeleted: () => searchNotifier.setIndexerFilter(null),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTableView = _isTableViewForWidth(constraints.maxWidth);

        return Scaffold(
          appBar: SysAppBar(
            title: const Text('全网资源搜索'),
            needTopOffset: !isDesktopSideMenu,
          ),
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification ||
                  notification is ScrollUpdateNotification) {
                if (_searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                }
              }
              return false;
            },
            child: Column(
              children: [
                // 统一搜索头部栏 (搜索输入框 + 筛选折叠按钮 + 网格/表格视图切换 + 可展开多维筛选面板)
                UnifiedSearchHeader(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: '输入作品名称、磁力关键词或软件/音乐资源',
                  onSearch: _performSearch,
                  onClear: () {
                    _searchController.clear();
                    searchNotifier.clear();
                  },
                  filterToggleKey: const Key('resource_search_filter_toggle_btn'),
                  isFilterExpanded: _isFilterExpanded,
                  onToggleFilter: () {
                    setState(() {
                      _isFilterExpanded = !_isFilterExpanded;
                    });
                  },
                  activeFilterCount: searchState.activeFilterCount,
                  activeFilterTags: activeTags,
                  onResetFilters: searchNotifier.resetFilters,
                  viewMode: _viewMode,
                  isTableView: isTableView,
                  onViewModeChanged: (mode) {
                    setState(() {
                      _viewMode = mode;
                    });
                  },
                  filterPanel: const ResourceSearchFilterPanel(),
                ),

                // 内容列表区域（支持表格视图 Table View 与多列网格视图 Grid View）
                Expanded(
                  child: ResourceSearchContent(
                    showInlineFilterSection: false,
                    externalViewMode: _viewMode,
                    onExternalViewModeChanged: (mode) {
                      setState(() {
                        _viewMode = mode;
                      });
                    },
                    onSearchKeywordSelected: (kw) {
                      _searchController.text = kw;
                      _performSearch(kw);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
