import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/router_constants.dart';

/// 全网资源搜索一级页面（支持 Mikan、Nyaa、Torznab 聚合直搜与一键下载/播放）
class ResourceSearchPage extends ConsumerStatefulWidget {
  const ResourceSearchPage({super.key});

  @override
  ConsumerState<ResourceSearchPage> createState() => _ResourceSearchPageState();
}

class _ResourceSearchPageState extends ConsumerState<ResourceSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedEpisodeFilter = '全部';
  TorrentSourceType? _selectedSourceFilter;

  static const List<String> _hotSuggestions = [
    '葬送的芙莉莲',
    '胆大党',
    '鬼灭之刃',
    '咒术回战',
    '迷宫饭',
    '孤独摇滚',
    '死神 千年血战篇',
    '间谍过家家',
    '电锯人',
    '我推的孩子',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _searchFocusNode.unfocus();
    setState(() {
      _selectedEpisodeFilter = '全部';
      _selectedSourceFilter = null;
    });
    ref.read(torrentSearchProvider.notifier).search(clean);
  }

  Future<void> _handleDownload(TorrentItem item) async {
    final magnet = item.magnetUrl;
    if (magnet.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final downloadTitle = item.displayTitle == item.title
          ? item.title
          : '${_searchController.text.trim()} - ${item.displayTitle}';

      await downloadCtrl.addUris(
        [magnet],
        title: downloadTitle,
        episodeNumber: int.tryParse(item.episode ?? ''),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加至下载队列: $downloadTitle'),
            action: SnackBarAction(
              label: '查看下载',
              onPressed: () {
                context.go(Routes.download);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '添加下载失败: $e', context: context);
      }
    }
  }

  Future<void> _handleStreamPlay(TorrentItem item) async {
    final magnet = item.magnetUrl;
    if (magnet.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final downloadTitle = item.displayTitle == item.title
          ? item.title
          : '${_searchController.text.trim()} - ${item.displayTitle}';

      await downloadCtrl.addUris(
        [magnet],
        title: downloadTitle,
        episodeNumber: int.tryParse(item.episode ?? ''),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已启动优先缓冲: $downloadTitle'),
            action: SnackBarAction(
              label: '去播放',
              onPressed: () {
                context.go(Routes.download);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '启动边下边播失败: $e', context: context);
      }
    }
  }

  Future<void> _copyMagnet(TorrentItem item) async {
    if (item.magnetUrl.isEmpty) {
      KazumiDialog.showToast(message: '无可用磁力链接', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: item.magnetUrl));
    if (mounted) {
      KazumiDialog.showToast(message: '磁力链接已复制到剪贴板', context: context);
    }
  }

  String _getSourceName(TorrentSourceType source) {
    switch (source) {
      case TorrentSourceType.mikan:
        return '蜜柑计划';
      case TorrentSourceType.nyaa:
        return 'Nyaa';
      case TorrentSourceType.torznab:
        return 'Torznab';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(torrentSearchProvider);

    return Scaffold(
      appBar: SysAppBar(
        title: const Text('全网资源搜索'),
        actions: [
          IconButton(
            tooltip: '下载管理',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => context.go(Routes.download),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索输入栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    decoration: InputDecoration(
                      hintText: '输入动漫名称直接搜索全网资源（如：葬送的芙莉莲）',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _performSearch(_searchController.text),
                  icon: const Icon(Icons.travel_explore, size: 20),
                  label: const Text('搜索'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 热门快捷建议（未搜索时展示）
          if (searchState.items.isEmpty && !searchState.isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '热门搜索推荐',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hotSuggestions.map((kw) {
                      return ActionChip(
                        label: Text(kw),
                        avatar: const Icon(Icons.search, size: 14),
                        onPressed: () {
                          _searchController.text = kw;
                          _performSearch(kw);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // 过滤栏（有结果时展示集数与源筛选）
          if (searchState.items.isNotEmpty)
            _buildFilterBar(theme, searchState),

          // 内容列表区域
          Expanded(
            child: _buildBody(theme, searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, TorrentSearchState searchState) {
    // 提取所有不同的集数
    final episodes = <String>{'全部'};
    for (final item in searchState.items) {
      if (item.episode != null && item.episode!.isNotEmpty) {
        episodes.add('第${item.episode!}集');
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 来源筛选
            FilterChip(
              label: const Text('全部源'),
              selected: _selectedSourceFilter == null,
              onSelected: (_) {
                setState(() => _selectedSourceFilter = null);
              },
            ),
            const SizedBox(width: 6),
            ...TorrentSourceType.values.map((src) {
              final count = searchState.sourceCount[src] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final isSelected = _selectedSourceFilter == src;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('${_getSourceName(src)} ($count)'),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      _selectedSourceFilter = val ? src : null;
                    });
                  },
                ),
              );
            }),
            const VerticalDivider(width: 16),
            // 集数筛选
            if (episodes.length > 2) ...[
              Text(
                '集数: ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ...episodes.map((ep) {
                final isSelected = _selectedEpisodeFilter == ep;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(ep),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedEpisodeFilter = ep);
                      }
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, TorrentSearchState searchState) {
    if (searchState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在聚合搜索全网资源（Mikan、Nyaa、Torznab）…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (searchState.error != null && searchState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('搜索失败: ${searchState.error}'),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _performSearch(_searchController.text),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (searchState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.travel_explore,
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? '全网动漫资源直搜'
                  : '未找到相关资源',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? '输入番剧名称，一键聚合 Mikan 与 Nyaa 高清资源并支持直接下载与看片'
                  : '请尝试更换简繁体或减少筛选关键字',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    // 执行过滤
    final filtered = searchState.items.where((item) {
      if (_selectedSourceFilter != null &&
          item.source != _selectedSourceFilter) {
        return false;
      }
      if (_selectedEpisodeFilter != '全部') {
        final epNum = _selectedEpisodeFilter
            .replaceAll('第', '')
            .replaceAll('集', '')
            .trim();
        if (item.episode != epNum) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '当前筛选条件下无匹配资源',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _buildTorrentCard(theme, item);
      },
    );
  }

  Widget _buildTorrentCard(ThemeData theme, TorrentItem item) {
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              item.displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 属性标签徽章
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 数据源
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getSourceName(item.source),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                // 集数
                if (item.episode != null && item.episode!.isNotEmpty)
                  Badge(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    label: Text(
                      '第${item.episode!}集',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                // 画质
                if (item.resolution != null && item.resolution!.isNotEmpty)
                  Badge(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    label: Text(
                      item.resolution!,
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                // 字幕组
                if (item.subgroup != null && item.subgroup!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.subgroup!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // 体积
                if (item.fileSize.isNotEmpty)
                  Text(
                    item.fileSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                // 做种数
                if (item.seeders > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward,
                          size: 12, color: theme.colorScheme.primary),
                      Text(
                        '${item.seeders}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // 原始完整发布标题
            Text(
              item.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // 操作按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: '复制磁力链接',
                  onPressed: () => _copyMagnet(item),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _handleStreamPlay(item),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('在线看'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _handleDownload(item),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('立即下载'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
