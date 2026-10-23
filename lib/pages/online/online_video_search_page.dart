import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';
import 'package:kazumi/modules/bilibili/bilibili_service.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:kazumi/modules/douyin/douyin_service.dart';
import 'package:kazumi/modules/search/search_history_dropdown.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/pages/player/local_video_play_args.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';

/// 在线视频搜索源枚举 (明确对应四大分类体系)
enum OnlineSourceFilter {
  all(
    id: 'all',
    label: '全部源',
    techStack: '多协议全网并发聚合调度 · 毫秒级原生直出',
    icon: Icons.all_inclusive,
  ),
  video(
    id: 'video',
    label: '在线视频',
    techStack: 'B站官方 4K DASH · 影视CMS采集 · 动漫点播',
    icon: Icons.video_library_outlined,
  ),
  live(
    id: 'live',
    label: '电视直播',
    techStack: 'IPTV M3U8 · 央视卫视 · 二次元轮播',
    icon: Icons.live_tv_outlined,
  ),
  resource(
    id: 'resource',
    label: '资源下载 (网盘/BT)',
    techStack: 'AList 网盘原画直链 · BT磁力种子检索与转存下载',
    icon: Icons.cloud_download_outlined,
  );

  final String id;
  final String label;
  final String techStack;
  final IconData icon;

  const OnlineSourceFilter({
    required this.id,
    required this.label,
    required this.techStack,
    required this.icon,
  });
}

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
  final CancelToken _popularCancelToken = CancelToken();

  OnlineSourceFilter _selectedFilter = OnlineSourceFilter.all;
  bool _isLoading = false;
  String _activeKeyword = '';

  List<BiliVideoItem> _biliResults = [];
  List<BiliVideoItem> _popularVideos = [];
  bool _isLoadingPopular = false;

  // 热搜/热门词推荐
  static const List<String> _trendingTags = [
    '孤独摇滚',
    '间谍过家家',
    '葬送的芙莉莲',
    '鬼灭之刃',
    '进击的巨人',
    '电锯人',
    '赛马娘',
    '刀剑神域',
    '新世纪福音战士',
    '莉可丽丝',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    if (widget.initialPopularVideos != null) {
      _popularVideos = List.from(widget.initialPopularVideos!);
    } else {
      _loadPopularVideos();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _popularCancelToken.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  Future<void> _loadPopularVideos() async {
    if (_isLoadingPopular) return;
    setState(() => _isLoadingPopular = true);
    try {
      final list = await BilibiliService.getPopularVideos(cancelToken: _popularCancelToken);
      if (mounted) {
        setState(() {
          _popularVideos = list;
          _isLoadingPopular = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPopular = false);
    }
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _searchFocusNode.unfocus();
    ref.read(searchHistoryProvider.notifier).addHistory(clean);

    setState(() {
      _activeKeyword = clean;
      _isLoading = true;
    });

    try {
      // 1. 检查是否直接粘贴了抖音分享内容、短链接或视频ID (有确切短链才解析，绝不做非主流假搜索)
      DouyinVideoItem? directDouyinItem;
      if (DouyinService.hasDouyinPattern(clean)) {
        directDouyinItem = await DouyinService.extractVideo(clean);
      }

      // 2. 检查是否直接粘贴了 Bilibili BV 号或视频链接
      BiliVideoDetail? directBiliDetail;
      final bvMatch = RegExp(r'BV[a-zA-Z0-9]{10}').firstMatch(clean);
      if (bvMatch != null && (_selectedFilter == OnlineSourceFilter.all || _selectedFilter == OnlineSourceFilter.video)) {
        directBiliDetail = await BilibiliService.getVideoDetails(bvMatch.group(0)!);
      }

      // 3. 多源并行聚合检索 (四大分类调度：在线视频、电视直播、网盘资源【下载类】、BT磁力【下载类】)
      final List<BiliVideoItem> searchResults = [];
      final List<Future<void>> futures = [];
      final pluginsState = ref.read(pluginsProvider);

      // 3.1 哔哩哔哩源检索 (在 all 且规则启用时执行，或在 video 在线视频分类时执行)
      final isBiliRuleEnabled = pluginsState.isPluginEnabled('bilibili');
      if ((_selectedFilter == OnlineSourceFilter.all && isBiliRuleEnabled) ||
          _selectedFilter == OnlineSourceFilter.video) {
        futures.add(() async {
          try {
            final biliList = await BilibiliService.searchVideos(clean);
            searchResults.addAll(biliList);
          } catch (e) {
            KazumiLogger().log(Level.warning, 'B站搜索异常: $e');
          }
        }());
      }

      // 3.2 苹果CMS、IPTV直播、AList网盘与第三方规则源检索
      futures.add(() async {
        try {
          final enabledPlugins = pluginsState.enabledPlugins.where((plugin) {
            if (plugin.isBilibili || plugin.isDouyin) return false;
            if (_selectedFilter == OnlineSourceFilter.all) return true;
            if (_selectedFilter == OnlineSourceFilter.video) {
              return plugin.resolvedCategory == PluginCategory.video;
            }
            if (_selectedFilter == OnlineSourceFilter.live) {
              return plugin.resolvedCategory == PluginCategory.live;
            }
            if (_selectedFilter == OnlineSourceFilter.resource) {
              return plugin.isResource; // 网盘和 BT 属于资源类 (也就是下载类)
            }
            return true;
          }).toList();

          final webTasks = enabledPlugins.map((plugin) async {
            try {
              final resp = await plugin.queryBangumi(clean).timeout(const Duration(seconds: 8));
              final cat = plugin.resolvedCategory;
              String tagLabel;
              if (cat == PluginCategory.live) {
                tagLabel = '电视直播';
              } else if (cat == PluginCategory.drive) {
                tagLabel = '网盘 · 资源下载';
              } else if (cat == PluginCategory.bt) {
                tagLabel = 'BT · 资源下载';
              } else {
                tagLabel = plugin.isMacCms ? '苹果CMS' : '在线视频';
              }

              for (final item in resp.data) {
                searchResults.add(
                  BiliVideoItem(
                    bvid: 'web_${plugin.name}_${item.src}',
                    title: item.name,
                    author: plugin.name,
                    pic: item.pic,
                    duration: item.remarks.isNotEmpty
                        ? item.remarks
                        : (cat.isResource ? '资源下载类' : (cat == PluginCategory.live ? '实时直播' : '点播正片')),
                    description: item.src,
                    tag: tagLabel,
                  ),
                );
              }
            } catch (_) {}
          });
          await Future.wait(webTasks);
        } catch (e) {
          KazumiLogger().log(Level.warning, '多源并发检索异常: $e');
        }
      }());

      await Future.wait(futures);

      // 如果直接匹配到了抖音直链或 BV 号，将其置顶在首位
      if (directDouyinItem != null) {
        final directItem = BiliVideoItem(
          bvid: 'douyin_${directDouyinItem.id}',
          title: directDouyinItem.title,
          author: directDouyinItem.author,
          pic: directDouyinItem.cover,
          duration: directDouyinItem.duration > 0
              ? '${directDouyinItem.duration}s'
              : '短视频',
          description: directDouyinItem.playUrl,
          tag: '抖音短视频',
        );
        searchResults.removeWhere((i) => i.bvid == directItem.bvid);
        searchResults.insert(0, directItem);
      }

      if (directBiliDetail != null) {
        final directItem = BiliVideoItem(
          bvid: directBiliDetail.bvid,
          title: directBiliDetail.title,
          author: directBiliDetail.ownerName,
          pic: directBiliDetail.pic,
          play: directBiliDetail.view,
          danmaku: directBiliDetail.danmaku,
          duration: directBiliDetail.parts.length > 1
              ? '${directBiliDetail.parts.length}P'
              : (directBiliDetail.parts.isNotEmpty
                  ? '${directBiliDetail.parts.first.duration}s'
                  : ''),
          description: directBiliDetail.desc,
        );
        searchResults.removeWhere((i) => i.bvid == directItem.bvid);
        searchResults.insert(0, directItem);
      }

      if (mounted) {
        setState(() {
          _biliResults = searchResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        KazumiDialog.showToast(message: '搜索出错: $e');
      }
    }
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
        KazumiDialog.showToast(message: '正在解析抖音无水印直链...');
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
        KazumiDialog.showToast(message: '无效的抖音播放直链');
      }
      return;
    }

    // 2. 检查是否为 Web 规则源视频
    if (item.bvid.startsWith('web_')) {
      final pluginName = item.author;
      final src = item.description;
      if (src.isEmpty) {
        KazumiDialog.showToast(message: '无效的播放地址');
        return;
      }
      KazumiDialog.showToast(message: '正在拉取 [$pluginName] 剧集与播放线路...');
      final videoPageController = ref.read(videoProvider.notifier);
      videoPageController.bangumiItem = BangumiItem.dummy(
        title: item.title,
        image: item.pic,
      );
      videoPageController.title = item.title;
      videoPageController.src = src;
      try {
        await videoPageController.queryRoads(src, pluginName);
        if (mounted && context.mounted) {
          context.push(Routes.video);
        }
      } catch (e) {
        KazumiLogger().log(Level.warning, '获取播放线路失败: $e');
        KazumiDialog.showToast(message: '获取播放线路失败: $e');
      }
      return;
    }

    // 3. 哔哩哔哩视频处理 (拉取分P并直接起播 / 选集)
    KazumiDialog.showToast(message: '正在拉取视频分P信息...');
    final detail = await BilibiliService.getVideoDetails(item.bvid);
    if (detail == null || detail.parts.isEmpty) {
      KazumiDialog.showToast(message: '无法获取该视频分P信息');
      return;
    }

    if (!mounted) return;

    if (detail.parts.length == 1) {
      // 单集视频直接播放
      await _playBiliPart(detail, detail.parts.first);
    } else {
      // 多P视频弹出集数选择器 (完全在 Kazumi 内呈现，绝不跳出原站)
      _showPartSelectorSheet(detail);
    }
  }

  /// 弹出分P列表抽屉
  void _showPartSelectorSheet(BiliVideoDetail detail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖动把手与标题
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '分P列表 (${detail.parts.length} 集) - ${detail.title}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: detail.parts.length,
                    itemBuilder: (context, index) {
                      final part = detail.parts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            '${part.page}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          part.part,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.play_circle_outline, size: 22),
                        onTap: () {
                          Navigator.pop(ctx);
                          _playBiliPart(detail, part);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 提取流媒体并启动播放器 (DASH 双流 + 原生弹幕)
  Future<void> _playBiliPart(BiliVideoDetail detail, BiliVideoPart part) async {
    KazumiDialog.showToast(message: '正在解析 DASH 流媒体直链...');
    final playUrl = await BilibiliService.getPlayUrl(detail.bvid, part.cid);
    if (playUrl == null || playUrl.videoUrl.isEmpty) {
      KazumiDialog.showToast(message: '获取播放直链失败，请重试');
      return;
    }

    if (!mounted) return;

    final title = detail.parts.length > 1
        ? '${detail.title} - ${part.part}'
        : detail.title;

    context.push(
      Routes.localPlayer,
      extra: LocalVideoPlayArgs(
        filePath: playUrl.videoUrl,
        title: title,
        audioUrl: playUrl.audioUrl,
        httpHeaders: playUrl.headers,
        biliCid: part.cid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;

    final enabledPluginCount = ref.watch(pluginsProvider.select(
      (s) => s.enabledPluginCount,
    ));

    return Scaffold(
      appBar: SysAppBar(
        title: const Text('在线视频搜索'),
        actions: [
          IconButton(
            tooltip: 'Kazumi 视频规则',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => context.push(Routes.settingsPlugin),
          ),
          IconButton(
            tooltip: '下载管理',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => context.go(Routes.download),
          ),
        ],
        needTopOffset: !isDesktopSideMenu,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollStartNotification ||
              scrollNotification is ScrollUpdateNotification) {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            }
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            // 1. 搜索引擎顶部核心区域 (居中大搜索框 + 规则源切换 + 下拉历史集成)
            SliverToBoxAdapter(
              child: _buildSearchEngineHeader(
                theme,
                colorScheme,
                enabledPluginCount,
              ),
            ),

            // 2. 搜索中加载状态
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在检索在线视频流...'),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. 搜索结果卡片流
            if (!_isLoading && _activeKeyword.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.video_library_outlined, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '搜索结果 (${_biliResults.length} 个视频)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_biliResults.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
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
                                  '未找到匹配的在线视频',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '请尝试更换关键词，或切换上方检索分类（哔哩哔哩 / Web 规则源 / 苹果CMS）；亦支持直接粘贴 B站 BV 号或抖音短视频分享链接无水印解析播放。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                                if (_selectedFilter != OnlineSourceFilter.all) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.all_inclusive, size: 18),
                                    label: Text('使用全部源检索「$_activeKeyword」'),
                                    onPressed: () {
                                      setState(() {
                                        _selectedFilter = OnlineSourceFilter.all;
                                      });
                                      _performSearch(_activeKeyword);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.80,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _biliResults[index];
                        return _buildVideoCard(item, theme, colorScheme);
                      },
                      childCount: _biliResults.length,
                    ),
                  ),
                ),
            ],

            // 4. 初始状态：热门推荐流 (当未主动搜索时展示)
            if (!_isLoading && _activeKeyword.isEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 22, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Text(
                        '全网热门推荐流',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingPopular)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: '刷新热门流',
                          onPressed: _loadPopularVideos,
                        ),
                    ],
                  ),
                ),
              ),
              if (_popularVideos.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '暂无推荐内容，请输入关键词开始搜索',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.80,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _popularVideos[index];
                        return _buildVideoCard(item, theme, colorScheme);
                      },
                      childCount: _popularVideos.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建居中搜索引擎头部 (界面极简化，搜索历史整合入下拉浮层)
  Widget _buildSearchEngineHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    int enabledPluginCount,
  ) {
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
                  hintText: _selectedFilter == OnlineSourceFilter.video
                      ? '搜索在线视频、动漫番剧或粘贴 B站 BV 号'
                      : (_selectedFilter == OnlineSourceFilter.live
                          ? '搜索电视直播频道、央视、卫视或轮播台'
                          : (_selectedFilter == OnlineSourceFilter.resource
                              ? '搜索网盘影视文件 (AList/WebDAV) 或 BT 资源'
                              : '输入作品、频道、网盘文件或粘贴链接 (聚合直搜)')),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _activeKeyword = '';
                              _biliResults = [];
                            });
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
          const SizedBox(height: 12),

          // 规则源切换 Chips (四大分类明确切换)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: OnlineSourceFilter.values.map((filter) {
              final isSelected = _selectedFilter == filter;
              final pluginsState = ref.watch(pluginsProvider);
              String labelText = filter.label;
              if (filter == OnlineSourceFilter.video) {
                final videoCount = pluginsState.enabledPlugins
                    .where((p) => p.resolvedCategory == PluginCategory.video)
                    .length;
                labelText = '在线视频 ($videoCount)';
              } else if (filter == OnlineSourceFilter.live) {
                final liveCount = pluginsState.enabledPlugins
                    .where((p) => p.resolvedCategory == PluginCategory.live)
                    .length;
                labelText = '电视直播 ($liveCount)';
              } else if (filter == OnlineSourceFilter.resource) {
                final resCount = pluginsState.enabledPlugins
                    .where((p) => p.isResource)
                    .length;
                labelText = '资源下载 ($resCount)';
              }
              return ChoiceChip(
                avatar: Icon(filter.icon, size: 16),
                label: Text(labelText),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFilter = filter);
                    if (_searchController.text.trim().isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 底层机制技术说明条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.memory_outlined, size: 13, color: colorScheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '底层技术: ${_selectedFilter.techStack}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 哔哩哔哩专属：扫码登录与 1080P/4K 解锁指示条
          if (_selectedFilter == OnlineSourceFilter.video || _selectedFilter == OnlineSourceFilter.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ValueListenableBuilder<BiliUserProfile?>(
                valueListenable: BiliAuthService().userNotifier,
                builder: (context, user, _) {
                  final isLogin = BiliAuthService().isLoggedIn && user != null;
                  return InkWell(
                    key: const Key('bili_auth_banner'),
                    onTap: () => BiliLoginDialog.show(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLogin
                            ? Colors.pink.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLogin
                              ? Colors.pink.withValues(alpha: 0.3)
                              : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLogin && user.face.isNotEmpty)
                            CircleAvatar(
                              radius: 8,
                              backgroundImage: CachedNetworkImageProvider(user.face),
                            )
                          else
                            Icon(
                              isLogin ? Icons.verified : Icons.lock_open_rounded,
                              size: 14,
                              color: isLogin ? Colors.pink : colorScheme.primary,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            isLogin
                                ? '${user.uname} · 已解锁 ${user.isVip ? "4K / 1080P60" : "1080P 高清"}'
                                : 'B站未登录 (360P) · 点击扫码解锁 1080P/4K',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isLogin ? Colors.pink : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 6),

          // 推荐热搜标签 (保持干净简洁，仅在初始空闲状态时呈现)
          if (_activeKeyword.isEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.trending_up, size: 16, color: Colors.redAccent),
                ..._trendingTags.map((tag) {
                  return ActionChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    backgroundColor: colorScheme.surfaceContainer,
                    onPressed: () {
                      _searchController.text = tag;
                      _performSearch(tag);
                    },
                  );
                }),
              ],
            ),
        ],
      ),
    );
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
                  if (item.pic.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.pic,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.video_library_outlined, size: 36),
                      ),
                    )
                  else
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.video_library_outlined, size: 36),
                    ),

                  // 播放按钮微动效层
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 42,
                        ),
                      ),
                    ),
                  ),

                  // 时长标签
                  if (item.duration.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // 来源标识
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.bvid.startsWith('douyin_')
                            ? Colors.black87
                            : (item.bvid.startsWith('web_')
                                ? (item.tag.contains('直播')
                                    ? Colors.orange.shade800
                                    : (item.tag.contains('资源') || item.tag.contains('网盘') || item.tag.contains('BT')
                                        ? Colors.blue.shade800
                                        : (item.tag == '苹果CMS'
                                            ? Colors.indigo.shade700
                                            : Colors.teal.shade700)))
                                : Colors.pinkAccent.withValues(alpha: 0.9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.bvid.startsWith('douyin_')
                            ? '抖音'
                            : (item.bvid.startsWith('web_')
                                ? '${item.tag} · ${item.author}'
                                : 'BiliBili'),
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

            // 标题、作者与播放量 (严格防溢出布局)
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 4),
                          // 底层技术机制标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              item.bvid.startsWith('douyin_')
                                  ? '无水印 CDN 直链'
                                  : (item.bvid.startsWith('web_')
                                      ? (item.tag == '苹果CMS'
                                          ? '苹果CMS V10 标准 JSON 协议'
                                          : 'XPath / DOM 嗅探规则')
                                      : '官方 WBI 签名 · DASH 音画分离'),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: colorScheme.outline),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.play_arrow_outlined, size: 14, color: colorScheme.outline),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(item.play),
                              style: TextStyle(fontSize: 11, color: colorScheme.outline),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.subtitles_outlined, size: 14, color: colorScheme.outline),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(item.danmaku),
                              style: TextStyle(fontSize: 11, color: colorScheme.outline),
                            ),
                          ],
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
        if (item.tag.contains('资源') || item.tag.contains('网盘') || item.tag.contains('BT')) ...[
          AppMenuAction(
            title: '复制资源下载直链 (支持下载器/网盘转存)',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: item.description));
              if (context.mounted) {
                KazumiDialog.showToast(message: '已复制资源下载直链', context: context);
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
              KazumiDialog.showToast(message: '已复制视频标题', context: context);
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
                KazumiDialog.showToast(message: '已复制作者信息', context: context);
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
                KazumiDialog.showToast(message: '已复制视频链接', context: context);
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

  String _formatCount(int count) {
    if (count <= 0) return '0';
    if (count < 10000) return '$count';
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
}
