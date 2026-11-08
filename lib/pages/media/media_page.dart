import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/card/bangumi_card.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

/// 元数据信息源定义（支持未来扩展多站点）
class MetadataProviderInfo {
  final String id;
  final String name;
  final String description;
  final Color brandColor;
  final bool isSupported;

  const MetadataProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.brandColor,
    required this.isSupported,
  });
}

/// 资源分类一级中枢页面（支持多源元数据站扩展，当前聚合 Bangumi 5 大真实分类：动画、影视、游戏、音乐、书籍）
class MediaPage extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const MediaPage({super.key, this.isEmbedded = false});

  @override
  ConsumerState<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<MediaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<MetadataProviderInfo> _metadataProviders = [
    MetadataProviderInfo(
      id: 'bangumi',
      name: 'Bangumi (番组计划)',
      description: '全品类二次元与影视综合元数据库',
      brandColor: Color(0xFFF09199),
      isSupported: true,
    ),
    MetadataProviderInfo(
      id: 'tmdb',
      name: 'TMDB (The Movie Database)',
      description: '全球海量电影与电视剧集媒体库 (规划扩展)',
      brandColor: Color(0xFF01D277),
      isSupported: false,
    ),
    MetadataProviderInfo(
      id: 'vndb',
      name: 'VNDB (Visual Novel Database)',
      description: '视觉小说与 Galgame 专属权威数据库 (规划扩展)',
      brandColor: Color(0xFF285586),
      isSupported: false,
    ),
    MetadataProviderInfo(
      id: 'douban',
      name: '豆瓣 (Douban)',
      description: '中文图书、音乐与影视综合评分平台 (规划扩展)',
      brandColor: Color(0xFF00B51D),
      isSupported: false,
    ),
  ];

  String _currentProviderId = 'bangumi';

  // 1. 动画 (Anime - Bangumi type 2)
  static const List<String> _animeTags = [
    '全部',
    '热门番剧',
    'TV',
    '剧场版',
    'OVA',
    '日本',
    '欧美',
    '国产',
    '热血',
    '搞笑',
    '科幻',
    '奇幻',
    '日常',
    '恋爱',
    '治愈',
  ];

  // 2. 影视 (Real - Bangumi type 6)
  static const List<String> _realTags = [
    '全部',
    '日剧',
    '欧美剧',
    '电影',
    '特摄',
    '华语剧',
    '韩剧',
    '悬疑',
    '剧情',
    '科幻',
    '动作',
    '喜剧',
  ];

  // 3. 游戏 (Games - Bangumi type 4)
  static const List<String> _gameTags = [
    '全部',
    'PC',
    'Switch',
    'PS5',
    'Steam',
    '独立游戏',
    'RPG',
    'ACT',
    'AVG',
    'NDS',
    'GBA',
    'Galgame',
    '动作冒险',
  ];

  // 4. 音乐 (Music - Bangumi type 3)
  static const List<String> _musicTags = [
    '全部',
    'OST',
    '原声带',
    '流行',
    '古典',
    '纯音乐',
    '广播剧',
    'ACG',
    'J-POP',
    '摇滚',
    '电子',
    'VOCALOID',
  ];

  // 5. 书籍 (Books - Bangumi type 1)
  static const List<String> _bookTags = [
    '全部',
    '漫画',
    '轻小说',
    '画集',
    '单行本',
    '连载',
    '热血',
    '恋爱',
    '奇幻',
    '科幻',
    '悬疑',
    '日常',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToCategorySearch(TorrentCategory category) {
    ref.read(torrentSearchProvider.notifier).setCategoryFilter(category);
    ref.read(navigationProvider.notifier).updateSelectedIndex(1);
    context.go(Routes.resource);
  }

  void _showSourceSelectSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '元数据信息源站 (Metadata Provider)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '选择媒体大分类与条目排行的元数据提供方，支持多源热插拔扩展：',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                ..._metadataProviders.map((provider) {
                  final isSelected = provider.id == _currentProviderId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: provider.brandColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          provider.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (provider.isSupported)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '已连接',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '扩展中',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(provider.description),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : null,
                    onTap: provider.isSupported
                        ? () {
                            setState(() {
                              _currentProviderId = provider.id;
                            });
                            Navigator.pop(sheetContext);
                          }
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceBadge(
    BuildContext context,
    MetadataProviderInfo currentProvider,
    ThemeData theme,
  ) {
    return InkWell(
      key: const Key('metadata_provider_selector'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showSourceSelectSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentProvider.brandColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              currentProvider.name.split(' ').first,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;
    final theme = Theme.of(context);
    final t = () {
      try {
        return context.t;
      } catch (_) {
        return LocaleSettings.currentLocale.translations;
      }
    }();

    final currentProvider = _metadataProviders.firstWhere(
      (p) => p.id == _currentProviderId,
      orElse: () => _metadataProviders.first,
    );

    final PreferredSizeWidget? appBar = widget.isEmbedded
        ? null
        : SysAppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.navigation.tabs.catalog),
                  const SizedBox(width: 8),
                  _buildSourceBadge(context, currentProvider, theme),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: t.navigation.actions.search,
                icon: const Icon(Icons.search),
                onPressed: () => context.push(Routes.search),
              ),
            ],
            needTopOffset: !isDesktopSideMenu,
          );

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          // 顶级分类栏：动画 · 影视 · 游戏 · 音乐 · 书籍 (Bangumi 5 大真实业务分类，支持水平平滑滑动)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(
                          key: Key('catalog_tab_anime'),
                          icon: Icon(Icons.movie_outlined, size: 18),
                          text: '动画',
                        ),
                        Tab(
                          key: Key('catalog_tab_real'),
                          icon: Icon(Icons.tv_outlined, size: 18),
                          text: '影视',
                        ),
                        Tab(
                          key: Key('catalog_tab_game'),
                          icon: Icon(Icons.sports_esports_outlined, size: 18),
                          text: '游戏',
                        ),
                        Tab(
                          key: Key('catalog_tab_music'),
                          icon: Icon(Icons.headphones_outlined, size: 18),
                          text: '音乐',
                        ),
                        Tab(
                          key: Key('catalog_tab_book'),
                          icon: Icon(Icons.auto_stories_outlined, size: 18),
                          text: '书籍',
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isEmbedded) ...[
                  _buildSourceBadge(context, currentProvider, theme),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: t.navigation.actions.search,
                    onPressed: () => context.push(Routes.search),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // 各大分类内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. 动画 (Anime - Bangumi type 2)
                _MediaChannelView(
                  channelType: 2,
                  channelName: '动画',
                  tags: _animeTags,
                  extraActionWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: const Key('catalog_chip_timeline'),
                      avatar: const Icon(Icons.calendar_today, size: 14),
                      label: const Text('放送时间表'),
                      onPressed: () => context.push(Routes.timeline),
                    ),
                  ),
                ),

                // 2. 影视 (Real - Bangumi type 6)
                _MediaChannelView(
                  channelType: 6,
                  channelName: '影视',
                  tags: _realTags,
                  extraActionWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: const Key('catalog_chip_search_real'),
                      avatar: const Icon(Icons.travel_explore, size: 14),
                      label: const Text('全网影视搜索'),
                      onPressed: () => _navigateToCategorySearch(TorrentCategory.video),
                    ),
                  ),
                ),

                // 3. 游戏 (Games - Bangumi type 4)
                _MediaChannelView(
                  channelType: 4,
                  channelName: '游戏',
                  tags: _gameTags,
                  extraActionWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: const Key('catalog_chip_search_game'),
                      avatar: const Icon(Icons.travel_explore, size: 14),
                      label: const Text('全网游戏搜索'),
                      onPressed: () => _navigateToCategorySearch(TorrentCategory.game),
                    ),
                  ),
                ),

                // 4. 音乐 (Music - Bangumi type 3)
                _MediaChannelView(
                  channelType: 3,
                  channelName: '音乐',
                  tags: _musicTags,
                  extraActionWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: const Key('catalog_chip_search_music'),
                      avatar: const Icon(Icons.travel_explore, size: 14),
                      label: const Text('全网音乐检索'),
                      onPressed: () => _navigateToCategorySearch(TorrentCategory.audio),
                    ),
                  ),
                ),

                // 5. 书籍 (Books - Bangumi type 1)
                _MediaChannelView(
                  channelType: 1,
                  channelName: '书籍',
                  tags: _bookTags,
                  extraActionWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: const Key('catalog_chip_search_book'),
                      avatar: const Icon(Icons.travel_explore, size: 14),
                      label: const Text('全网图书检索'),
                      onPressed: () => _navigateToCategorySearch(TorrentCategory.document),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个大分类频道的网格流与标签筛选组件
class _MediaChannelView extends StatefulWidget {
  final int channelType;
  final String channelName;
  final List<String> tags;
  final Widget? extraActionWidget;

  const _MediaChannelView({
    required this.channelType,
    required this.channelName,
    required this.tags,
    this.extraActionWidget,
  });

  @override
  State<_MediaChannelView> createState() => _MediaChannelViewState();
}

class _MediaChannelViewState extends State<_MediaChannelView>
    with AutomaticKeepAliveClientMixin {
  late String _selectedTag;
  final ScrollController _scrollController = ScrollController();
  final List<BangumiItem> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  int _offset = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedTag = '全部';
    _scrollController.addListener(_scrollListener);
    _loadData(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoading) {
      _loadData();
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (isRefresh) {
      _offset = 0;
      _items.clear();
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final int effectiveType = widget.channelType;
      final String tagToQuery = _selectedTag == '全部' ? '' : _selectedTag;

      List<BangumiItem> results = [];
      // 动画分类全部标签优先请求趋势榜
      if (widget.channelType == 2 && (_selectedTag == '热门番剧' || _selectedTag == '全部')) {
        try {
          results = await BangumiHTTP.getBangumiTrendsList(
            type: 2,
            offset: _offset,
            limit: 30,
          );
        } catch (_) {}
        if (results.isEmpty) {
          results = await BangumiHTTP.getBangumiList(
            rank: isRefresh ? 0 : Random().nextInt(4000) + 1,
            tag: '',
            type: 2,
            limit: 30,
            offset: _offset,
          );
        }
      } else {
        // 其他大分类（影视 6、游戏 4、音乐 3、书籍 1）直接按 type 与 tag 精准检索
        results = await BangumiHTTP.getBangumiList(
          rank: isRefresh ? 0 : Random().nextInt(4000) + 1,
          tag: tagToQuery,
          type: effectiveType,
          limit: 30,
          offset: _offset,
        );
      }

      if (mounted) {
        setState(() {
          _items.addAll(results);
          _offset += results.length;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _items.isEmpty;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        // 标签筛选横向滚动条
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                widget.tags.length + (widget.extraActionWidget != null ? 2 : 1),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Chip(
                    avatar: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF09199),
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: const Text(
                      '源站: Bangumi',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }
              if (widget.extraActionWidget != null && index == 1) {
                return widget.extraActionWidget!;
              }
              final prefixCount = widget.extraActionWidget != null ? 2 : 1;
              final tagIndex = index - prefixCount;
              final tag = widget.tags[tagIndex];
              final isSelected = tag == _selectedTag;
              return Center(
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected && _selectedTag != tag) {
                      setState(() {
                        _selectedTag = tag;
                      });
                      _loadData(isRefresh: true);
                    }
                  },
                ),
              );
            },
          ),
        ),

        // 内容展示区域（自适应响应式网格）
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadData(isRefresh: true),
            child: _buildGridContent(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildGridContent(ThemeData theme) {
    if (_hasError && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            Text('加载${widget.channelName}列表失败'),
            FilledButton.tonal(
              onPressed: () => _loadData(isRefresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.colorScheme.outlineVariant),
            Text('暂无${widget.channelName}内容，请尝试切换标签'),
          ],
        ),
      );
    }

    return AdaptiveGrid(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        StyleString.cardSpace,
        8,
        StyleString.cardSpace,
        20,
      ),
      smallMobileColumns: 2,
      mobileColumns: 3,
      tabletColumns: 5,
      desktopColumns: 6,
      mainAxisSpacing: StyleString.cardSpace - 2,
      crossAxisSpacing: StyleString.cardSpace,
      extentBuilder: (columnWidth) =>
          columnWidth / 0.65 + MediaQuery.textScalerOf(context).scale(48.0),
      itemCount: _items.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return BangumiCardV(
          enableHero: false,
          bangumiItem: _items[index],
          source: 'Bangumi',
        );
      },
    );
  }
}
