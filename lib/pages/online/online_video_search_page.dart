import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/image/rule_cover_image.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';
import 'package:haipee/modules/search/search_history_dropdown.dart';
import 'package:haipee/modules/search/search_history_provider.dart';
import 'package:haipee/pages/online/online_video_search_provider.dart';
import 'package:haipee/pages/player/local_video_play_args.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:flutter/services.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';

export 'package:haipee/pages/online/online_video_search_provider.dart'
    show OnlineSourceFilter, onlineVideoSearchProvider, OnlineVideoSearchState;

/// 在线视频搜索引擎一级页面 (极简工业质感，搜索历史整合至下拉浮层)
/// 严格独立于 BT/磁力/PT 种子搜索，专精于 Web 在线流媒体直搜与流畅播放
class OnlineVideoSearchPage extends ConsumerStatefulWidget {
  final List<BiliVideoItem>? initialPopularVideos;
  const OnlineVideoSearchPage({super.key, this.initialPopularVideos});

  @override
  ConsumerState<OnlineVideoSearchPage> createState() =>
      _OnlineVideoSearchPageState();
}

class _OnlineVideoSearchPageState extends ConsumerState<OnlineVideoSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<BiliVideoItem> _popularVideos = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    final currentKeyword = ref.read(onlineVideoSearchProvider).keyword;
    if (currentKeyword.isNotEmpty) {
      _searchController.text = currentKeyword;
    }

    if (widget.initialPopularVideos != null) {
      _popularVideos = List.from(widget.initialPopularVideos!);
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
    ref.read(onlineVideoSearchProvider.notifier).search(clean);
  }

  /// 点击视频卡片处理 (自动解析分P与播放)
  Future<void> _handleVideoTap(BiliVideoItem item) async {
    if (item.bvid.isEmpty) return;

    // 1. 检查是否为抖音短视频链接
    if (item.bvid.startsWith('douyin_')) {
      String playUrl = item.description;
      final id = item.bvid.replaceFirst('douyin_', '');
      final isDirectCdn = playUrl.isNotEmpty &&
          (playUrl.contains('.mp4') ||
              playUrl.contains('365yg.com') ||
              playUrl.contains('douyinvod.com') ||
              playUrl.contains('amemv.com') ||
              playUrl.contains('tos-cn'));

      if (!isDirectCdn) {
        HaipeeDialog.showToast(message: '正在解析抖音无水印直链...');
        final extracted = await DouyinService.extractVideo(id);
        if (!mounted) return;
        if (extracted != null && extracted.playUrl.isNotEmpty) {
          playUrl = extracted.playUrl;
        } else if (playUrl.isEmpty || !playUrl.startsWith('http')) {
          playUrl =
              'https://api-play.amemv.com/aweme/v1/play/?video_id=$id&is_play_url=1';
        }
      }

      if (playUrl.isNotEmpty) {
        context.push(
          Routes.localPlayer,
          extra: LocalVideoPlayArgs(
            filePath: playUrl,
            title: item.title,
            httpHeaders: const {
              'User-Agent': 'okhttp/3.10.0.1',
            },
          ),
        );
      } else {
        HaipeeDialog.showToast(message: '无效的抖音播放直链');
      }
      return;
    }

    // 2. 检查是否为 Web 规则源视频
    if (item.bvid.startsWith('web_')) {
      final pluginName = item.author;
      final src = item.description;
      if (src.isEmpty) {
        HaipeeDialog.showToast(message: '无效的播放地址');
        return;
      }
      HaipeeDialog.showToast(message: '正在拉取 [$pluginName] 剧集与播放线路...');
      final videoPageController = ref.read(videoProvider.notifier);
      final effectiveCover = item.pic.isNotEmpty
          ? item.pic
          : ref.read(onlineVideoSearchProvider).resolveFallbackCover(item);
      videoPageController.bangumiItem = BangumiItem.dummy(
        title: item.title,
        image: effectiveCover,
      );
      videoPageController.title = item.title;
      videoPageController.src = src;
      try {
        await videoPageController.queryRoads(src, pluginName);
        if (mounted && context.mounted) {
          context.push(Routes.video);
        }
      } catch (e) {
        AppLog.w(LogModule.plugin, '获取播放线路失败: $e');
        HaipeeDialog.showToast(message: '获取播放线路失败: $e');
      }
      return;
    }

    // 3. 哔哩哔哩视频处理 (拉取分P并直接起播 / 选集)
    HaipeeDialog.showToast(message: '正在拉取视频分P信息...');
    final detail = await BilibiliService.getVideoDetails(item.bvid);
    if (detail == null || detail.parts.isEmpty) {
      HaipeeDialog.showToast(message: '无法获取该视频分P信息');
      return;
    }

    if (!mounted) return;

    if (detail.parts.length == 1) {
      // 单集视频直接播放
      await _playBiliPart(detail, detail.parts.first);
    } else {
      // 多P视频弹出集数选择器 (完全在 Haipee 内呈现，绝不跳出原站)
      _showPartSelectorSheet(detail);
    }
  }

  /// 弹出分P列表抽屉
  void _showPartSelectorSheet(BiliVideoDetail detail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '选择集数 (${detail.parts.length}P)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: detail.parts.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final part = detail.parts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child: Text(
                            '${part.page}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          part.part.isNotEmpty ? part.part : 'P${part.page}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: part.duration > 0
                            ? Text('${part.duration} 秒')
                            : null,
                        trailing: const Icon(Icons.play_arrow_outlined),
                        onTap: () {
                          Navigator.of(context).pop();
                          _playBiliPart(detail, part);
                        },
                      );
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

  /// 播放 B站 某一个具体的分P
  Future<void> _playBiliPart(BiliVideoDetail detail, BiliVideoPart part) async {
    HaipeeDialog.showToast(message: '正在拉取播放直链...');
    try {
      final playUrl = await BilibiliService.getPlayUrl(detail.bvid, part.cid);
      if (!mounted) return;

      if (playUrl == null || playUrl.videoUrl.isEmpty) {
        HaipeeDialog.showToast(message: '获取播放直链失败');
        return;
      }

      context.push(
        Routes.localPlayer,
        extra: LocalVideoPlayArgs(
          filePath: playUrl.videoUrl,
          title: '${detail.title} - ${part.part}',
          audioUrl: playUrl.audioUrl,
          httpHeaders: playUrl.headers,
          biliCid: part.cid,
          biliBvid: detail.bvid,
          biliQuality: playUrl.quality,
          biliAvailableQualities: playUrl.availableQualities,
        ),
      );
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '播放失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pluginsState = ref.watch(pluginsProvider);
    final enabledPluginCount = pluginsState.enabledPluginCount;

    final searchState = ref.watch(onlineVideoSearchProvider);
    final searchNotifier = ref.read(onlineVideoSearchProvider.notifier);

    final bool isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Scaffold(
          appBar: SysAppBar(
            title: const Text('在线视频搜索'),
            actions: [
              IconButton(
                tooltip: 'BT/磁力直搜 (Mikan/Nyaa)',
                icon: const Icon(Icons.cloud_download_outlined),
                onPressed: () {
                  final kw = _searchController.text.trim();
                  TorrentSearchSheet.show(
                    context,
                    initialKeyword: kw,
                  );
                },
              ),
              IconButton(
                tooltip: 'Haipee 视频规则',
                icon: const Icon(Icons.video_library_outlined),
                onPressed: () => context.push(Routes.settingsPlugin),
              ),
              IconButton(
                tooltip: '下载管理',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => context.push(Routes.download),
              ),
            ],
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
            child: _buildScrollContent(
              theme,
              colorScheme,
              enabledPluginCount,
              searchState,
              searchNotifier,
              isWide: isWide,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollContent(
    ThemeData theme,
    ColorScheme colorScheme,
    int enabledPluginCount,
    OnlineVideoSearchState searchState,
    OnlineVideoSearchNotifier searchNotifier, {
    required bool isWide,
  }) {
    final isSearching = searchState.isSearching;
    final activeKeyword = searchState.keyword;
    final completedSources = searchState.completedSources;
    final totalSources = searchState.totalSources;
    final allResults = searchState.allResults;
    final currentFilteredResults = searchState.currentFilteredResults;
    final selectedFilter = searchState.selectedFilter;

    return CustomScrollView(
      slivers: [
        // 1. 搜索引擎顶部核心区域
        SliverToBoxAdapter(
          child: _buildSearchEngineHeader(
            theme,
            colorScheme,
            enabledPluginCount,
            selectedFilter,
            activeKeyword,
            searchNotifier,
            isWide: isWide,
            searchState: searchState,
          ),
        ),

        // 2. 搜索中全屏加载态
        if (isSearching && allResults.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '正在全网并发检索在线视频与直播流 ($completedSources/$totalSources 个源)...',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. 搜索结果卡片流
        if (activeKeyword.isNotEmpty && (allResults.isNotEmpty || !isSearching)) ...[
          SliverToBoxAdapter(
            child: _buildSearchResultSummary(
              theme,
              colorScheme,
              currentFilteredResults,
              selectedFilter,
              isSearching,
              completedSources,
              totalSources,
            ),
          ),
          if (currentFilteredResults.isEmpty && !isSearching)
            SliverToBoxAdapter(
              child: _buildEmptyStateCard(
                theme,
                colorScheme,
                selectedFilter,
                allResults,
                activeKeyword,
                searchNotifier,
              ),
            )
          else if (currentFilteredResults.isEmpty && isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    selectedFilter == OnlineSourceFilter.live
                        ? '当前分类暂未检索到直播频道，其余源检索中...'
                        : '当前分类暂未检索到视频，其余源检索中...',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  int crossAxisCount = 2;
                  if (width >= 1200) {
                    crossAxisCount = 5;
                  } else if (width >= 900) {
                    crossAxisCount = 4;
                  } else if (width >= 600) {
                    crossAxisCount = 3;
                  }

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = currentFilteredResults[index];
                        return _buildVideoCard(item, theme, colorScheme);
                      },
                      childCount: currentFilteredResults.length,
                    ),
                  );
                },
              ),
            ),
        ],

        // 4. 空闲未搜索状态时：若有传入初始视频(测试场景)则呈现卡片，否则呈现纯工具引导视图
        if (activeKeyword.isEmpty) ...[
          if (_popularVideos.isNotEmpty)
            Builder(
              builder: (context) {
                final displayedPopular =
                    searchState.resultsForFilter(selectedFilter, _popularVideos);
                if (displayedPopular.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      int crossAxisCount = 2;
                      if (width >= 1200) {
                        crossAxisCount = 5;
                      } else if (width >= 900) {
                        crossAxisCount = 4;
                      } else if (width >= 600) {
                        crossAxisCount = 3;
                      }

                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = displayedPopular[index];
                            return _buildVideoCard(item, theme, colorScheme);
                          },
                          childCount: displayedPopular.length,
                        ),
                      );
                    },
                  ),
                );
              },
            )
          else
            SliverToBoxAdapter(
              child: _buildToolGuideView(
                theme,
                colorScheme,
                enabledPluginCount,
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// 构建纯工具引导态 (展示规则就绪状态与搜索历史，绝不预加载第三方内容)
  Widget _buildToolGuideView(
    ThemeData theme,
    ColorScheme colorScheme,
    int enabledPluginCount,
  ) {
    final pluginsState = ref.watch(pluginsProvider);
    final enabledPlugins = pluginsState.enabledPlugins;

    final haipeeCount =
        enabledPlugins.where((p) => p.ruleType == PluginRuleType.haipee).length;
    final maccmsCount =
        enabledPlugins.where((p) => p.ruleType == PluginRuleType.maccms).length;
    final tvboxCount =
        enabledPlugins.where((p) => p.ruleType == PluginRuleType.tvbox).length;
    final iptvCount =
        enabledPlugins.where((p) => p.ruleType == PluginRuleType.iptv).length;
    final pipedCount = (pluginsState.isPluginEnabled('bilibili') ? 1 : 0) +
        (pluginsState.isPluginEnabled('douyin') ? 1 : 0) +
        enabledPlugins
            .where((p) =>
                p.ruleType == PluginRuleType.piped &&
                !p.isBilibili &&
                !p.isDouyin)
            .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 规则就绪看板
              Card(
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
                              '已启用规则 ($enabledPluginCount 个规则)',
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
                          _buildRuleStatusBadge(
                            theme,
                            colorScheme,
                            icon: Icons.extension_rounded,
                            label: 'Haipee 规则',
                            count: haipeeCount,
                          ),
                          _buildRuleStatusBadge(
                            theme,
                            colorScheme,
                            icon: Icons.movie_outlined,
                            label: 'MacCMS 规则',
                            count: maccmsCount,
                          ),
                          _buildRuleStatusBadge(
                            theme,
                            colorScheme,
                            icon: Icons.widgets_outlined,
                            label: 'TVBox 规则',
                            count: tvboxCount,
                          ),
                          _buildRuleStatusBadge(
                            theme,
                            colorScheme,
                            icon: Icons.live_tv_outlined,
                            label: 'IPTV 直播',
                            count: iptvCount,
                          ),
                          _buildRuleStatusBadge(
                            theme,
                            colorScheme,
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Piped 流媒体',
                            count: pipedCount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleStatusBadge(
    ThemeData theme,
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required int count,
  }) {
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
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
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
              color: count > 0
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: count > 0 ? colorScheme.primary : colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSearchEngineHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    int enabledPluginCount,
    OnlineSourceFilter selectedFilter,
    String activeKeyword,
    OnlineVideoSearchNotifier searchNotifier, {
    required bool isWide,
    required OnlineVideoSearchState searchState,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 搜索框主体 (整合统一下拉历史记录浮层)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SearchHistoryDropdown(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSelectKeyword: _performSearch,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  _performSearch(val);
                },
                decoration: InputDecoration(
                  hintText: selectedFilter == OnlineSourceFilter.video
                      ? '搜索在线视频、动漫番剧或粘贴 B站 BV 号'
                      : (selectedFilter == OnlineSourceFilter.live
                          ? '搜索电视直播频道、央视、卫视或轮播台'
                          : '输入作品、频道名称或粘贴 B站 BV 号'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            searchNotifier.clear();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: '开始搜索',
                        onPressed: () {
                          _performSearch(_searchController.text);
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 统一横向分类与规则筛选栏 (对齐下载界面规范，全屏统一呈现，包含全部/视频/直播及5大规则协议并附带动态数量Badge)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: OnlineSourceFilter.audiovisualFilters.map((filter) {
                final isSelected = selectedFilter == filter;
                final count = searchState.countForFilter(filter);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: Key('online_search_chip_${filter.id}'),
                    showCheckmark: false,
                    avatar: Icon(
                      filter.icon,
                      size: 16,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter.label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (searchState.allResults.isNotEmpty || count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (count > 0 ? colorScheme.onPrimary : colorScheme.onSurface)
                                    : (count > 0 ? colorScheme.primary : colorScheme.outline),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        searchNotifier.setFilter(filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果头部信息与源检索进度指示 (例如：“找到 X 条视频”、“X 个直播频道”，或者搜索进度指示“已完成 M/N 个源”)
  Widget _buildSearchResultSummary(
    ThemeData theme,
    ColorScheme colorScheme,
    List<BiliVideoItem> filteredResults,
    OnlineSourceFilter selectedFilter,
    bool isSearching,
    int completedSources,
    int totalSources,
  ) {
    String countLabel;
    IconData headerIcon;
    switch (selectedFilter) {
      case OnlineSourceFilter.haipee:
      case OnlineSourceFilter.anime:
        countLabel = '找到 ${filteredResults.length} 部 Haipee 规则内容';
        headerIcon = Icons.extension_rounded;
        break;
      case OnlineSourceFilter.maccms:
        countLabel = '找到 ${filteredResults.length} 部 MacCMS 采集影片';
        headerIcon = Icons.movie_outlined;
        break;
      case OnlineSourceFilter.tvbox:
        countLabel = '找到 ${filteredResults.length} 部 TVBox 聚合内容';
        headerIcon = Icons.widgets_outlined;
        break;
      case OnlineSourceFilter.iptv:
        countLabel = '找到 ${filteredResults.length} 个 IPTV 直播频道';
        headerIcon = Icons.live_tv_outlined;
        break;
      case OnlineSourceFilter.piped:
      case OnlineSourceFilter.bilibili:
      case OnlineSourceFilter.douyin:
        countLabel = '找到 ${filteredResults.length} 条 Piped 流媒体视频';
        headerIcon = Icons.play_circle_outline_rounded;
        break;
      case OnlineSourceFilter.live:
        countLabel = '找到 ${filteredResults.length} 个直播频道';
        headerIcon = Icons.live_tv_outlined;
        break;
      case OnlineSourceFilter.video:
        countLabel = '找到 ${filteredResults.length} 条视频';
        headerIcon = Icons.video_library_outlined;
        break;
      case OnlineSourceFilter.all:
        countLabel = '找到 ${filteredResults.length} 条视听内容';
        headerIcon = Icons.auto_awesome_motion_outlined;
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    '正在并发检索 ($completedSources/$totalSources 个源)...',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              ],
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

  /// 构建搜索无结果时的降级引导卡片
  Widget _buildEmptyStateCard(
    ThemeData theme,
    ColorScheme colorScheme,
    OnlineSourceFilter selectedFilter,
    List<BiliVideoItem> allResults,
    String activeKeyword,
    OnlineVideoSearchNotifier searchNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedFilter == OnlineSourceFilter.live
                        ? '未找到匹配的直播频道'
                        : (selectedFilter == OnlineSourceFilter.video
                            ? '未找到匹配的在线视频'
                            : '未找到匹配的视听内容'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedFilter == OnlineSourceFilter.live
                        ? '请尝试更换关键词，或切换上方分类；亦可在规则管理中检查是否启用了 IPTV 直播源。'
                        : (selectedFilter == OnlineSourceFilter.video
                            ? '请尝试更换关键词，或切换上方检索分类（哔哩哔哩 / Web 规则源 / 苹果CMS）；亦支持直接粘贴 B站 BV 号或抖音短视频分享链接无水印解析播放。'
                            : '请尝试更换关键词，或在规则管理中检查是否启用了相关在线视听规则。'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (selectedFilter != OnlineSourceFilter.all) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: Icon(
                        allResults.isNotEmpty
                            ? Icons.visibility_outlined
                            : Icons.all_inclusive,
                      ),
                      label: Text(
                        allResults.isNotEmpty
                            ? '查看全部分类检索结果 (${allResults.length})'
                            : '使用全部源检索「$activeKeyword」',
                      ),
                      onPressed: () {
                        searchNotifier.setFilter(OnlineSourceFilter.all);
                        if (allResults.isEmpty) {
                          _performSearch(activeKeyword);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getSourceLabel(BiliVideoItem item) {
    if (item.bvid.startsWith('douyin_')) {
      return '抖音';
    }
    if (item.bvid.startsWith('web_')) {
      return item.author.isNotEmpty
          ? item.author
          : (item.tag.isNotEmpty ? item.tag : '网络');
    }
    return 'BiliBili';
  }

  /// 构建视频卡片 (严谨防溢出，比例协调)
  Widget _buildVideoCard(
    BiliVideoItem item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final cardWidget = Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => _handleVideoTap(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图与时长
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RuleCoverImage(
                    imageUrl: item.pic,
                    fallbackImageUrl: ref
                        .read(onlineVideoSearchProvider)
                        .resolveFallbackCover(item),
                    title: item.title,
                    ruleTag: item.tag,
                  ),
                  // 时长或分P药丸 (右下角)
                  if (item.duration.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // 规则协议标识 (右上角)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.resolvedRuleType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // 来源标识 (左上角：纯来源标签，不与右上角的类型重复)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.bvid.startsWith('douyin_')
                            ? Colors.black87
                            : (item.bvid.startsWith('web_')
                                ? Colors.teal.shade800
                                : Colors.pinkAccent.withValues(alpha: 0.9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getSourceLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 标题与来源元数据
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    Row(
                      children: [
                        // 来源协议标签
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: item.bvid.startsWith('douyin_')
                                  ? Colors.cyan.withValues(alpha: 0.15)
                                  : (item.tag.contains('直播')
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : (item.bvid.startsWith('web_')
                                          ? Colors.teal.withValues(alpha: 0.15)
                                          : Colors.pink.withValues(alpha: 0.15))),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.bvid.startsWith('douyin_')
                                  ? '短视频'
                                  : (item.bvid.startsWith('web_')
                                      ? item.tag
                                      : 'B站高清'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (item.author.isNotEmpty && !item.bvid.startsWith('web_')) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final pageUrl = item.bvid.startsWith('douyin_')
        ? 'https://www.douyin.com/video/${item.bvid.replaceFirst('douyin_', '')}'
        : (item.bvid.startsWith('web_')
            ? item.description
            : 'https://www.bilibili.com/video/${item.bvid}');

    return AppContextMenu(
      itemsBuilder: (context) => [
        AppMenuAction(
          title: '播放视频',
          icon: Icons.play_arrow_rounded,
          onSelected: () => _handleVideoTap(item),
        ),
        AppMenuAction(
          title: '检索相关资源/下载...',
          icon: Icons.download_rounded,
          onSelected: () {
            TorrentSearchSheet.show(
              context,
              initialKeyword: item.title,
            );
          },
        ),
        if (item.tag.contains('资源') ||
            item.tag.contains('网盘') ||
            item.tag.contains('BT')) ...[
          AppMenuAction(
            title: '复制资源下载直链 (支持下载器/网盘转存)',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: item.description));
              if (context.mounted) {
                HaipeeDialog.showToast(message: '已复制资源下载直链', context: context);
              }
            },
          ),
        ],
        const AppMenuSeparator(),
        AppMenuAction(
          title: '复制视频标题',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: item.title));
            if (context.mounted) {
              HaipeeDialog.showToast(message: '已复制视频标题', context: context);
            }
          },
        ),
        if (item.author.isNotEmpty)
          AppMenuAction(
            title: '复制来源/作者 (${item.author})',
            icon: Icons.person_outline_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: item.author));
              if (context.mounted) {
                HaipeeDialog.showToast(message: '已复制作者信息', context: context);
              }
            },
          ),
        if (pageUrl.isNotEmpty) ...[
          AppMenuAction(
            title: '复制视频链接',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: pageUrl));
              if (context.mounted) {
                HaipeeDialog.showToast(message: '已复制视频链接', context: context);
              }
            },
          ),
          if (pageUrl.startsWith('http'))
            AppMenuAction(
              title: '在浏览器中打开原网页',
              icon: Icons.open_in_browser_rounded,
              onSelected: () => Utils.openUrl(pageUrl),
            ),
        ],
      ],
      child: cardWidget,
    );
  }
}
