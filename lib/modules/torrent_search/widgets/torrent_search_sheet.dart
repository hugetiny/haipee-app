import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/modules/torrent_search/widgets/selective_download_dialog.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_service.dart';
import 'package:haipee/modules/torrent_search/parser/torrent_file_parser.dart';
import 'package:haipee/modules/torrent_search/utils/torrent_download_helper.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/utils.dart';

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
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到有效的下载链接')),
        );
      }
      return;
    }

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final downloadTitle = item.displayTitle == item.title
          ? item.title
          : '${widget.initialKeyword} - ${item.displayTitle}';
      final episodeNumber = int.tryParse(item.episode ?? '');

      // 默认优先种子：如果具备种子文件，尝试在 3 秒内极速下载并直接推送到下载服务
      if (hasTorrent) {
        try {
          final torrentBytes = await TorrentDownloadHelper.fetchTorrentBytes(
            item.effectiveTorrentUrl!,
            timeout: const Duration(seconds: 3),
          );

          if (torrentBytes != null && torrentBytes.isNotEmpty) {
            await downloadCtrl.addTorrentBytes(
              torrentBytes,
              title: downloadTitle,
              originalUrl: item.effectiveTorrentUrl,
              bangumiId: widget.bangumiId,
              episodeNumber: episodeNumber,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已添加至下载队列 (种子优先): $downloadTitle'),
                  action: SnackBarAction(
                    label: '查看下载',
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.download);
                    },
                  ),
                ),
              );
            }
            return;
          }
        } catch (e) {
          HaipeeLogger().log(
            Level.warning,
            '优先下载种子文件失败，平滑降级至磁力链接添加: $e',
          );
        }
      }

      final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
      final fallbackUrl = fallbackMagnet.isNotEmpty
          ? fallbackMagnet
          : (item.effectiveTorrentUrl ?? item.torrentUrl ?? '');

      if (fallbackUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到可用的下载链接')),
          );
        }
        return;
      }

      await downloadCtrl.addUris(
        [fallbackUrl],
        title: downloadTitle,
        bangumiId: widget.bangumiId,
        episodeNumber: episodeNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加至下载队列: $downloadTitle'),
            action: SnackBarAction(
              label: '查看下载',
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.download);
              },
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

  Future<void> _handleSelectiveDownload(TorrentItem item) async {
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到有效的下载链接')),
        );
      }
      return;
    }

    final cancelToken = TorrentStreamCancelToken();
    bool isCompleted = false;
    Uint8List? torrentBytes;
    List<TorrentFileEntry>? entries;

    final downloadTitle = item.displayTitle == item.title
        ? item.title
        : '${widget.initialKeyword} - ${item.displayTitle}';
    final episodeNumber = int.tryParse(item.episode ?? '');

    // 1. 种子优先秒级解析文件树
    if (hasTorrent) {
      HaipeeDialog.showLoading(
        msg: '正在极速下载种子元数据 (.torrent)...',
        onCancel: () => cancelToken.cancel(),
        onDismiss: () {
          if (!isCompleted) cancelToken.cancel();
        },
      );

      try {
        torrentBytes = await TorrentDownloadHelper.fetchTorrentBytes(
          item.effectiveTorrentUrl!,
          timeout: const Duration(seconds: 4),
          cancelToken: cancelToken,
        );

        if (cancelToken.isCancelled) {
          HaipeeDialog.dismiss();
          return;
        }

        if (torrentBytes != null && torrentBytes.isNotEmpty) {
          final parsed = TorrentFileParser.parseBytes(torrentBytes);
          if (parsed.files.isNotEmpty) {
            entries = parsed.files;
          }
        }
      } catch (e) {
        HaipeeLogger().log(
          Level.warning,
          '种子秒级解析失败，准备降级为磁力 DHT 解析: $e',
        );
      }
    }

    // 2. 磁力 DHT 解析降级兜底
    if (entries == null || entries.isEmpty) {
      if (cancelToken.isCancelled) {
        HaipeeDialog.dismiss();
        return;
      }

      final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
      if (fallbackMagnet.isEmpty) {
        HaipeeDialog.dismiss();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未能下载种子文件且无磁力链接')),
          );
        }
        return;
      }

      HaipeeDialog.showLoading(
        msg: hasTorrent
            ? '种子拉取受阻，正在通过 DHT 解析磁力元数据...'
            : '正在通过 DHT 与 Tracker 解析磁力元数据...',
        onCancel: () => cancelToken.cancel(),
        onDismiss: () {
          if (!isCompleted) cancelToken.cancel();
        },
      );

      try {
        entries = await TorrentStreamService.instance.resolveMagnetFiles(
          fallbackMagnet,
          cancelToken: cancelToken,
          onProgress: (status) {
            HaipeeDialog.showLoading(msg: status);
          },
        );
      } on TorrentStreamCancelledException {
        HaipeeDialog.dismiss();
        return;
      } catch (e) {
        HaipeeDialog.dismiss();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('解析磁力元数据失败: $e')),
          );
        }
        return;
      }
    }

    isCompleted = true;
    HaipeeDialog.dismiss();
    if (!mounted) return;

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能获取到该资源的文件列表')),
      );
      return;
    }

    await SelectiveDownloadDialog.show(
      context,
      title: downloadTitle,
      files: entries,
      onConfirm: (indices, savePath) async {
        final options = <String, dynamic>{};
        if (savePath.isNotEmpty) {
          options['dir'] = savePath;
        }
        if (indices.isNotEmpty) {
          options['select-file'] = indices.join(',');
        }

        final downloadCtrl = ref.read(downloadControllerProvider.notifier);

        if (torrentBytes != null && torrentBytes.isNotEmpty) {
          await downloadCtrl.addTorrentBytes(
            torrentBytes,
            title: downloadTitle,
            originalUrl: item.effectiveTorrentUrl,
            bangumiId: widget.bangumiId,
            episodeNumber: episodeNumber,
            options: options,
          );
        } else {
          final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
          await downloadCtrl.addUris(
            [fallbackMagnet],
            title: downloadTitle,
            bangumiId: widget.bangumiId,
            episodeNumber: episodeNumber,
            options: options,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '已添加选择性下载任务 (${torrentBytes != null ? '种子优先' : '磁力'} · 已勾选 ${indices.length} 个文件): $downloadTitle',
              ),
              action: SnackBarAction(
                label: '查看下载',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.download);
                },
              ),
            ),
          );
        }
      },
    );
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
                          showCheckmark: false,
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

    final cardWidget = Card.outlined(
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
                const SizedBox(width: 6),
                Badge(
                  label: const Text('Torznab / Cardigann P2P 种子索引'),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  textColor: colorScheme.onSurfaceVariant,
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
                  key: Key('torrent_sheet_download_btn_${item.title}'),
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

    return AppContextMenu(
      itemsBuilder: (context) => [
        AppMenuAction(
          title: '极速下载',
          icon: Icons.download_rounded,
          onSelected: () => _handleDownload(item),
        ),
        AppMenuAction(
          title: '选择性下载 (迅雷树)...',
          icon: Icons.checklist_rtl_rounded,
          onSelected: () => _handleSelectiveDownload(item),
        ),
        AppMenuAction(
          title: '边下边播 (首尾关键帧优先)',
          icon: Icons.play_circle_outline_rounded,
          onSelected: () => _handleStreamPlay(item),
        ),
        const AppMenuSeparator(),
        AppMenuAction(
          title: '复制磁力链接',
          icon: Icons.copy_rounded,
          onSelected: () {
            Clipboard.setData(ClipboardData(text: item.magnetUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('磁力链接已复制到剪贴板'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        AppMenuAction(
          title: '复制资源全称',
          icon: Icons.title_rounded,
          onSelected: () {
            Clipboard.setData(ClipboardData(text: item.title));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制资源全称'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        if (item.displayTitle != item.title)
          AppMenuAction(
            title: '复制短标题 (${item.displayTitle})',
            icon: Icons.subtitles_outlined,
            onSelected: () {
              Clipboard.setData(ClipboardData(text: item.displayTitle));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制短标题'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        if (item.pageUrl != null && item.pageUrl!.isNotEmpty) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '在浏览器中打开原始发布页',
            icon: Icons.open_in_browser_rounded,
            onSelected: () => Utils.openUrl(item.pageUrl!),
          ),
        ],
      ],
      child: cardWidget,
    );
  }
}
