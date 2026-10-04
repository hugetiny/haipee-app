import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/router_constants.dart';

class TorrentSearchSheet extends ConsumerStatefulWidget {
  final String initialKeyword;
  final String? bangumiId;

  const TorrentSearchSheet({
    super.key,
    required this.initialKeyword,
    this.bangumiId,
  });

  static void show(
    BuildContext context, {
    required String initialKeyword,
    String? bangumiId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TorrentSearchSheet(
        initialKeyword: initialKeyword,
        bangumiId: bangumiId,
      ),
    );
  }

  @override
  ConsumerState<TorrentSearchSheet> createState() => _TorrentSearchSheetState();
}

class _TorrentSearchSheetState extends ConsumerState<TorrentSearchSheet> {
  late final TextEditingController _textController;
  String _selectedEpisodeFilter = '全部';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialKeyword);
    Future.microtask(() {
      ref.read(torrentSearchProvider.notifier).search(widget.initialKeyword);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _textController.text.trim();
    if (query.isNotEmpty) {
      ref.read(torrentSearchProvider.notifier).search(query);
    }
  }

  Future<void> _handleDownload(TorrentItem item) async {
    final magnet = item.magnetUrl;
    if (magnet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到有效的下载链接')),
      );
      return;
    }

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final downloadTitle = item.displayTitle == item.title
          ? item.title
          : '${widget.initialKeyword} - ${item.displayTitle}';

      await downloadCtrl.addUris(
        [magnet],
        title: downloadTitle,
        bangumiId: widget.bangumiId,
        episodeNumber: int.tryParse(item.episode ?? ''),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加至下载队列: $downloadTitle'),
            action: SnackBarAction(
              label: '知道了',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加下载失败: $e')),
        );
      }
    }
  }

  Future<void> _handleStreamPlay(TorrentItem item) async {
    final magnet = item.magnetUrl;
    if (magnet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到有效的下载链接')),
      );
      return;
    }

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final downloadTitle = item.displayTitle == item.title
          ? item.title
          : '${widget.initialKeyword} - ${item.displayTitle}';

      await downloadCtrl.addUris(
        [magnet],
        title: downloadTitle,
        bangumiId: widget.bangumiId,
        episodeNumber: int.tryParse(item.episode ?? ''),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已启动首尾关键帧优先缓冲: $downloadTitle'),
            action: SnackBarAction(
              label: '查看下载/播放',
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.download);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动边下边播失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(torrentSearchProvider);

    // 提取所有集数选项供筛选
    final episodeSet = <String>{'全部'};
    for (final item in state.items) {
      if (item.episode != null && item.episode!.isNotEmpty) {
        episodeSet.add(item.episode!);
      }
    }
    final sortedEpisodes = episodeSet.toList()
      ..sort((a, b) {
        if (a == '全部') return -1;
        if (b == '全部') return 1;
        final aNum = double.tryParse(a);
        final bNum = double.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });

    // 根据选中的集数过滤结果
    final filteredItems = _selectedEpisodeFilter == '全部'
        ? state.items
        : state.items.where((i) => i.episode == _selectedEpisodeFilter).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖动条
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 搜索标题与输入框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: '搜索高清资源 (支持番名、字幕组等)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textController.clear();
                            },
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _triggerSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: state.isLoading ? null : _triggerSearch,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('搜索'),
                    ),
                  ],
                ),
              ),

              // 集数过滤 Chips 栏
              if (sortedEpisodes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sortedEpisodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final ep = sortedEpisodes[index];
                        final isSelected = ep == _selectedEpisodeFilter;
                        return ChoiceChip(
                          label: Text(ep == '全部' ? '全部资源' : '第 $ep 集'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedEpisodeFilter = ep;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

              const Divider(height: 16),

              // 状态提示或列表展示
              Expanded(
                child: state.isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('正在聚合检索 Mikan 与 Nyaa 高清资源...'),
                          ],
                        ),
                      )
                    : filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  state.items.isEmpty
                                      ? '未找到相关资源，可尝试更换关键词'
                                      : '当前集数下暂无资源，切换“全部”查看',
                                  style: TextStyle(color: colorScheme.outline),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _buildResourceCard(context, item);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResourceCard(BuildContext context, TorrentItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sourceName = item.source == TorrentSourceType.mikan
        ? '蜜柑'
        : item.source == TorrentSourceType.nyaa
            ? 'Nyaa'
            : 'Torznab';

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：展示集数标签 + 来源 Badge + 做种数
            Row(
              children: [
                Text(
                  item.displayTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  label: Text(sourceName),
                  backgroundColor: colorScheme.secondaryContainer,
                  textColor: colorScheme.onSecondaryContainer,
                ),
                const Spacer(),
                if (item.seeders > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, size: 14, color: colorScheme.primary),
                      Text(
                        '${item.seeders}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 第二行：原始发布组完整标题
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // 第三行：清洗后的小白元数据副标题与操作按钮
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.simplifiedSubtitle.isNotEmpty
                        ? item.simplifiedSubtitle
                        : item.fileSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 复制磁力链按钮
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '复制磁力链接',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.magnetUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('磁力链接已复制到剪贴板'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // 边下边播快捷动作
                FilledButton.tonalIcon(
                  onPressed: () => _handleStreamPlay(item),
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('边下边播'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                // 核心大动作：一键下载
                FilledButton.icon(
                  onPressed: () => _handleDownload(item),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('下载'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
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
