import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/pages/player/local_player_page.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/modules/torrent_stream/widgets/torrent_stream_dialog.dart';
import 'package:kazumi/modules/torrent_search/widgets/selective_download_dialog.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:kazumi/modules/torrent_search/widgets/torrent_link_badge.dart';
import 'package:kazumi/modules/torrent_search/utils/torrent_download_helper.dart';
import 'package:kazumi/modules/torrent_search/parser/torrent_file_parser.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/router_constants.dart';

import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/widget/adaptive_data_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';

/// 全网资源搜索视图显示模式（统一对齐全局 AdaptiveViewMode 规范）
typedef ResourceViewMode = AdaptiveViewMode;

/// 迅雷风格泛用全网资源搜索主体视图
/// 深度整合 Bangumi 官方元数据与多源全网资源下载检索
class ResourceSearchContent extends ConsumerStatefulWidget {
  final void Function(String keyword)? onSearchKeywordSelected;

  const ResourceSearchContent({
    super.key,
    this.onSearchKeywordSelected,
  });

  @override
  ConsumerState<ResourceSearchContent> createState() =>
      _ResourceSearchContentState();
}

class _ResourceSearchContentState extends ConsumerState<ResourceSearchContent> {
  // 迅雷风格表格水平与垂直滚动控制器
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // 视图显示模式（默认为 auto 自动响应式，亦支持强制表格或卡片）
  ResourceViewMode _viewMode = ResourceViewMode.auto;

  /// 自动切换表格视图的可用宽度断点（对齐 Material 3 紧凑屏基准 600dp 并预留侧边栏与边距）
  static final double responsiveBreakpoint =
      LayoutBreakpoint.compact['width']! + 100.0; // 700.0

  // 当前表格选中的行索引（对齐迅雷选中高亮体验）
  int? _selectedRowIndex;

  /// 计算在给定可用宽度和当前视图模式下的实际展示样式
  bool _isTableViewForWidth(double availableWidth) {
    switch (_viewMode) {
      case ResourceViewMode.auto:
        return availableWidth >= responsiveBreakpoint;
      case ResourceViewMode.table:
        return true;
      case ResourceViewMode.card:
        return false;
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// 桌面端与移动端上下文菜单统一规格
  List<AppMenuItem> _buildContextMenuItems(TorrentItem item) {
    return [
      AppMenuAction(
        title: '立即下载',
        icon: Icons.download,
        onSelected: () => _handleDownload(item),
      ),
      AppMenuAction(
        title: '选择下载 (三联树)...',
        icon: Icons.checklist_rtl,
        onSelected: () => _handleSelectiveDownload(item),
      ),
      if (item.canStreamVideo)
        AppMenuAction(
          title: '在线播放 / 边下边播',
          icon: Icons.play_arrow,
          onSelected: () => _handleStreamPlay(item),
        ),
      if (item.canStreamAudio)
        AppMenuAction(
          title: '在线收听 / 边下边听',
          icon: Icons.headphones_outlined,
          onSelected: () => _handleStreamPlay(item),
        ),
      const AppMenuSeparator(),
      if (item.pageUrl != null && item.pageUrl!.isNotEmpty)
        AppMenuAction(
          title: '打开原始发布页',
          icon: Icons.open_in_browser,
          onSelected: () => _openBrowserUrl(item.pageUrl!),
        ),
      if (item.hasMagnet)
        AppMenuAction(
          title: '复制磁力链接',
          icon: Icons.copy,
          onSelected: () => _copyMagnet(item),
        ),
      if (item.hasTorrent) ...[
        AppMenuAction(
          title: '复制种子下载链接',
          icon: Icons.link,
          onSelected: () => _copyTorrentUrl(item),
        ),
        AppMenuAction(
          title: '另存种子文件 (.torrent)',
          icon: Icons.save_alt,
          onSelected: () => _saveTorrentFile(item),
        ),
      ],
      const AppMenuSeparator(),
      AppMenuAction(
        title: '复制资源名称',
        icon: Icons.title,
        onSelected: () async {
          await Clipboard.setData(ClipboardData(text: item.title));
          if (mounted) {
            KazumiDialog.showToast(message: '已复制资源全称', context: context);
          }
        },
      ),
    ];
  }



  Future<void> _copyMagnet(TorrentItem item) async {
    final magnet = item.effectiveMagnetUrl ?? item.magnetUrl;
    if (magnet.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的磁力链接', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: magnet));
    if (mounted) {
      KazumiDialog.showToast(message: '已复制磁力链接', context: context);
    }
  }

  Future<void> _copyTorrentUrl(TorrentItem item) async {
    final url = item.effectiveTorrentUrl;
    if (url == null || url.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的种子下载链接', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      KazumiDialog.showToast(message: '已复制种子下载链接', context: context);
    }
  }

  Future<void> _saveTorrentFile(TorrentItem item) async {
    final url = item.effectiveTorrentUrl;
    if (url == null || url.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的种子下载链接', context: context);
      return;
    }

    KazumiDialog.showLoading(msg: '正在下载种子文件 (.torrent)...');
    try {
      final bytes = await TorrentDownloadHelper.fetchTorrentBytes(url);
      KazumiDialog.dismiss();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          KazumiDialog.showToast(
            message: '下载种子文件失败，可能是网络问题或防盗链拦截',
            context: context,
          );
        }
        return;
      }

      final file = await TorrentDownloadHelper.saveTorrentToFile(
        bytes,
        defaultFileName: '${item.title}.torrent',
      );
      if (file != null && mounted) {
        KazumiDialog.showToast(message: '种子已保存至: ${file.path}', context: context);
      }
    } catch (e) {
      KazumiDialog.dismiss();
      if (mounted) {
        KazumiDialog.showToast(message: '保存种子异常: $e', context: context);
      }
    }
  }

  Future<void> _openBrowserUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final success = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        KazumiDialog.showToast(message: '无法在浏览器中打开链接', context: context);
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '打开链接失败: $e', context: context);
      }
    }
  }

  Future<void> _handleDownload(TorrentItem item) async {
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      KazumiDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    final downloadCtrl = ref.read(downloadControllerProvider.notifier);
    // 非视频类型严格保留原始完整文件名与扩展名，绝不破坏软件版本、系统镜像或游戏标识
    final downloadTitle = (!item.isVideo ||
            item.cleanedTitle == null ||
            item.cleanedTitle!.isEmpty)
        ? item.title
        : item.cleanedTitle!;
    final episodeNumber = item.isVideo
        ? int.tryParse(item.episode?.replaceAll('E', '') ?? '')
        : null;

    // 默认优先种子：如果具备种子文件，尝试在 3 秒内极速下载并直接推送给 Aria2
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
            episodeNumber: episodeNumber,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已添加至下载队列 (种子优先): $downloadTitle'),
                action: SnackBarAction(
                  label: '查看下载',
                  onPressed: () {
                    context.go(Routes.download);
                  },
                ),
              ),
            );
          }
          return;
        }
      } catch (e) {
        KazumiLogger().log(
          Level.warning,
          '优先下载种子文件失败，平滑降级至磁力链接添加: $e',
        );
      }
    }

    // 种子不存在或种子拉取失败/超时：平滑降级使用磁力链接
    final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
    if (fallbackMagnet.isEmpty) {
      if (mounted) {
        KazumiDialog.showToast(message: '种子下载失败且无可用磁力链接', context: context);
      }
      return;
    }

    try {
      await downloadCtrl.addUris(
        [fallbackMagnet],
        title: downloadTitle,
        episodeNumber: episodeNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加磁力下载任务至队列: $downloadTitle'),
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

  /// 迅雷风格三联树选择性下载流程（默认优先种子秒级展开目录树 + 磁力 DHT 降级兜底）
  Future<void> _handleSelectiveDownload(TorrentItem item) async {
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      KazumiDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    bool isCompleted = false;
    final cancelToken = TorrentStreamCancelToken();
    Uint8List? torrentBytes;
    List<TorrentFileEntry>? entries;

    final downloadTitle = (!item.isVideo ||
            item.cleanedTitle == null ||
            item.cleanedTitle!.isEmpty)
        ? item.title
        : item.cleanedTitle!;
    final episodeNumber = item.isVideo
        ? int.tryParse(item.episode?.replaceAll('E', '') ?? '')
        : null;

    // 1. 默认优先种子：尝试通过 HTTP 下载 .torrent 文件并在 0ms 瞬间解析文件树
    if (hasTorrent) {
      KazumiDialog.showLoading(
        msg: '正在极速下载种子元数据 (.torrent)...',
        onCancel: () {
          cancelToken.cancel();
        },
        onDismiss: () {
          if (!isCompleted) {
            cancelToken.cancel();
          }
        },
      );

      try {
        torrentBytes = await TorrentDownloadHelper.fetchTorrentBytes(
          item.effectiveTorrentUrl!,
          timeout: const Duration(seconds: 4),
          cancelToken: cancelToken,
        );

        if (cancelToken.isCancelled) {
          KazumiDialog.dismiss();
          return;
        }

        if (torrentBytes != null && torrentBytes.isNotEmpty) {
          final parsed = TorrentFileParser.parseBytes(torrentBytes);
          if (parsed.files.isNotEmpty) {
            entries = parsed.files;
          }
        }
      } catch (e) {
        KazumiLogger().log(
          Level.warning,
          '种子秒级解析失败，准备降级为磁力 DHT 解析: $e',
        );
      }
    }

    // 2. 如果无种子或种子拉取失败，平滑降级到磁力 DHT 与 Tracker 解析
    if (entries == null || entries.isEmpty) {
      if (cancelToken.isCancelled) {
        KazumiDialog.dismiss();
        return;
      }

      final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
      if (fallbackMagnet.isEmpty) {
        KazumiDialog.dismiss();
        if (mounted) {
          KazumiDialog.showToast(message: '未能下载种子文件且无磁力链接', context: context);
        }
        return;
      }

      KazumiDialog.showLoading(
        msg: hasTorrent
            ? '种子拉取受阻，正在通过 DHT 解析磁力元数据...'
            : '正在通过 DHT 与 Tracker 解析磁力元数据...',
        onCancel: () {
          cancelToken.cancel();
        },
        onDismiss: () {
          if (!isCompleted) {
            cancelToken.cancel();
          }
        },
      );

      try {
        entries = await TorrentStreamService.instance.resolveMagnetFiles(
          fallbackMagnet,
          cancelToken: cancelToken,
          onProgress: (status) {
            KazumiDialog.showLoading(msg: status);
          },
        );
      } on TorrentStreamCancelledException {
        KazumiDialog.dismiss();
        return;
      } catch (e) {
        KazumiDialog.dismiss();
        if (mounted) {
          KazumiDialog.showToast(message: '解析磁力元数据失败: $e', context: context);
        }
        return;
      }
    }

    isCompleted = true;
    KazumiDialog.dismiss();
    if (!mounted) return;

    if (entries.isEmpty) {
      KazumiDialog.showToast(message: '未能获取到该资源的文件列表', context: context);
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
        options['select-file'] = indices.join(',');

        final downloadCtrl = ref.read(downloadControllerProvider.notifier);

        if (torrentBytes != null && torrentBytes.isNotEmpty) {
          // 种子优先提交
          await downloadCtrl.addTorrentBytes(
            torrentBytes,
            title: downloadTitle,
            originalUrl: item.effectiveTorrentUrl,
            episodeNumber: episodeNumber,
            options: options,
          );
        } else {
          // 磁力提交
          final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
          await downloadCtrl.addUris(
            [fallbackMagnet],
            title: downloadTitle,
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
                  context.go(Routes.download);
                },
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _handleStreamPlay(TorrentItem item) async {
    final magnet = item.magnetUrl;
    if (magnet.isEmpty) {
      KazumiDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    if (item.isArchive) {
      final format = item.archiveFormatName ?? '压缩包';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法在线播放'),
          content: Text('该资源为 $format 压缩包格式（${item.title}），不支持直接在线边下边播。\n\n建议使用 Aria2 离线下载到本地解压后播放。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleDownload(item);
              },
              child: const Text('立即下载'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final downloadState = ref.read(downloadControllerProvider);
      final downloadTitle = (!item.isVideo ||
              item.cleanedTitle == null ||
              item.cleanedTitle!.isEmpty)
          ? item.title
          : item.cleanedTitle!;

      // 1. 优先检查当前离线下载库中是否已有已就绪的完整文件，有则直接本地播放
      final allTasks = [
        ...downloadState.activeTasks,
        ...downloadState.waitingTasks,
        ...downloadState.completedTasks,
      ];
      DownloadTask? existingTask;
      for (final t in allTasks) {
        if (t.url == magnet || (t.title == downloadTitle && t.filePath != null)) {
          existingTask = t;
          break;
        }
      }

      if (existingTask != null && existingTask.filePath != null) {
        final existingFile = File(existingTask.filePath!);
        if (existingFile.existsSync()) {
          context.push(
            Routes.localPlayer,
            extra: LocalVideoPlayArgs(
              filePath: existingFile.absolute.path,
              title: downloadTitle,
              episode: item.isVideo
                  ? int.tryParse(item.episode?.replaceAll('E', '') ?? '')
                  : null,
              isAudio: item.isAudio,
            ),
          );
          return;
        }
      }

      // 2. 边下边播由 TorrentStreamDialog 与流式引擎协同接管，实时展示做种节点与首尾分片预缓冲 HUD
      final session = await TorrentStreamDialog.show(
        context: context,
        ref: ref,
        item: item,
        overrideTitle: downloadTitle,
        episode: item.isVideo
            ? int.tryParse(item.episode?.replaceAll('E', '') ?? '')
            : null,
        isAudio: item.isAudio,
      );

      if (session != null && mounted) {
        context.push(
          Routes.localPlayer,
          extra: LocalVideoPlayArgs(
            filePath: session.streamUrl,
            title: session.selectedFile?.name ?? downloadTitle,
            episode: item.isVideo
                ? int.tryParse(item.episode?.replaceAll('E', '') ?? '')
                : null,
            isAudio: session.isAudio || item.isAudio,
            streamId: session.streamId,
            torrentId: session.torrentId,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '流式播放启动异常: $e', context: context);
      }
    }
  }

  String _getSourceName(TorrentSourceType source) {
    switch (source) {
      case TorrentSourceType.cardigann:
      case TorrentSourceType.indexerPlugin:
        return 'Cardigann';
      case TorrentSourceType.torznab:
      case TorrentSourceType.prowlarr:
        return '外部 Torznab';
      case TorrentSourceType.mikan:
        return '蜜柑计划';
      case TorrentSourceType.nyaa:
        return 'Nyaa';
      case TorrentSourceType.dmhy:
        return '动漫花园';
      case TorrentSourceType.piratebay:
        return 'The Pirate Bay';
      case TorrentSourceType.torrentscsv:
        return 'Torrents.csv';
    }
  }

  IconData _getCategoryIcon(TorrentCategory category) {
    switch (category) {
      case TorrentCategory.video:
        return Icons.movie_outlined;
      case TorrentCategory.audio:
        return Icons.music_note_outlined;
      case TorrentCategory.software:
        return Icons.computer_outlined;
      case TorrentCategory.game:
        return Icons.sports_esports_outlined;
      case TorrentCategory.document:
        return Icons.menu_book_outlined;
      case TorrentCategory.all:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getCategoryColor(TorrentCategory category, ThemeData theme) {
    switch (category) {
      case TorrentCategory.video:
        return Colors.blue.shade600;
      case TorrentCategory.audio:
        return Colors.orange.shade700;
      case TorrentCategory.software:
        return Colors.purple.shade600;
      case TorrentCategory.game:
        return Colors.green.shade700;
      case TorrentCategory.document:
        return Colors.teal.shade700;
      case TorrentCategory.all:
        return theme.colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(torrentSearchProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTableView = _isTableViewForWidth(constraints.maxWidth);

        return Column(
          children: [
            // 迅雷风格分类导航选项卡（全部 / 视频 / 音乐 / 软件 / 游戏 / 文档 / 其它）
            _buildXunleiCategoryTabs(theme, searchState),

            // 迅雷风格次级工具栏（条目计数统计 + 视图切换 + 枪版/分辨率/站点筛选）
            if (searchState.items.isNotEmpty)
              _buildArrFilterBar(theme, searchState, isTableView: isTableView),

            // 渐进式流式抓取进度条（首屏已呈现，后台索引器仍在并发追加）
            if (searchState.isLoading && searchState.items.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),

            // 内容展示区域（表格视图 / 卡片视图 / 欢迎推荐）
            Expanded(
              child: _buildBody(theme, searchState, isTableView: isTableView),
            ),
          ],
        );
      },
    );
  }

  /// 迅雷风格分类导航栏
  Widget _buildXunleiCategoryTabs(
      ThemeData theme, TorrentSearchState searchState) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final counts = searchState.categoryCounts;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withAlpha(50),
            width: 0.8,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: TorrentCategory.values.map((cat) {
            final isSelected = searchState.categoryFilter == cat;
            final count = cat == TorrentCategory.all
                ? searchState.items.length
                : (counts[cat] ?? 0);
            final icon = _getCategoryIcon(cat);
            final color = _getCategoryColor(cat, theme);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('category_chip_${cat.name}'),
                avatar: Icon(
                  icon,
                  size: 15,
                  color: isSelected ? theme.colorScheme.onPrimary : color,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.label),
                    if (searchState.items.isNotEmpty && count > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.onPrimary.withAlpha(220)
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => notifier.setCategoryFilter(cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 迅雷风格交互式工具栏与筛选栏
  Widget _buildArrFilterBar(
    ThemeData theme,
    TorrentSearchState searchState, {
    required bool isTableView,
  }) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final filteredCount = searchState.filteredItems.length;
    final totalCount = searchState.items.length;

    // 收集所有出现的分辨率
    final resolutions = <String>{'全部'};
    for (final item in searchState.items) {
      if (item.resolution != null && item.resolution!.isNotEmpty) {
        resolutions.add(item.resolution!);
      }
    }

    // 收集所有来源索引器
    final indexers = <String>{'全部'};
    for (final item in searchState.items) {
      indexers.add(item.effectiveSourceName);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 资源计数统计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                filteredCount == totalCount
                    ? '共 $totalCount 项资源'
                    : '显示 $filteredCount / $totalCount 项',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 响应式视图切换器（自动响应式 / 强制表格 / 强制卡片）
            AdaptiveViewSwitcher(
              viewMode: _viewMode,
              isTableView: isTableView,
              onModeChanged: (mode) {
                setState(() {
                  _viewMode = mode;
                });
              },
            ),
            const SizedBox(width: 8),

            // 排序方式（迅雷核心要素：做种数 / 最新发布 / 体积 / 下载数 / 名称 / 站点）
            PopupMenuButton<TorrentSortMode>(
              tooltip: '更改排序方式',
              initialValue: searchState.sortMode,
              onSelected: (mode) => notifier.setSortMode(mode),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      switch (searchState.sortMode) {
                        TorrentSortMode.seeders =>
                          '做种数${searchState.sortAscending ? ' (升序)' : ' (降序)'}',
                        TorrentSortMode.age =>
                          '发布时间${searchState.sortAscending ? ' (最早)' : ' (最新)'}',
                        TorrentSortMode.size =>
                          '体积${searchState.sortAscending ? ' (从小到大)' : ' (从大到小)'}',
                        TorrentSortMode.leechers =>
                          '下载数${searchState.sortAscending ? ' (升序)' : ' (降序)'}',
                        TorrentSortMode.title =>
                          '名称${searchState.sortAscending ? ' (A-Z)' : ' (Z-A)'}',
                        TorrentSortMode.source =>
                          '站点${searchState.sortAscending ? ' (A-Z)' : ' (Z-A)'}',
                        TorrentSortMode.smart =>
                          '智能排序',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: TorrentSortMode.smart,
                  child: Text('智能综合排序'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.seeders,
                  child: Text('做种数 (Seeders) 优先'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.age,
                  child: Text('最新发布时间 (Age) 优先'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.size,
                  child: Text('文件体积 (Size) 优先'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.leechers,
                  child: Text('下载热度 (Leechers) 优先'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.title,
                  child: Text('资源名称 (A-Z) 排序'),
                ),
                const PopupMenuItem(
                  value: TorrentSortMode.source,
                  child: Text('来源站点 排序'),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // 隐藏 CAM/TS 枪版开关
            FilterChip(
              avatar: Icon(
                searchState.hideCam ? Icons.visibility_off : Icons.visibility,
                size: 14,
              ),
              label: const Text('隐藏 CAM 枪版'),
              selected: searchState.hideCam,
              onSelected: (_) => notifier.toggleHideCam(),
            ),
            const SizedBox(width: 8),

            // 分辨率筛选（仅在“全部”或“视频”分类下有意义）
            if ((searchState.categoryFilter == TorrentCategory.all ||
                    searchState.categoryFilter == TorrentCategory.video) &&
                resolutions.length > 2) ...[
              Text(
                '画质: ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ...resolutions.map((res) {
                final isSelected =
                    (searchState.resolutionFilter ?? '全部') == res;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(res),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        notifier.setResolutionFilter(res == '全部' ? null : res);
                      }
                    },
                  ),
                );
              }),
            ],

            // 索引器来源筛选
            if (indexers.length > 2) ...[
              const VerticalDivider(width: 12),
              Text(
                '站点: ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ...indexers.map((idx) {
                final isSelected = (searchState.indexerFilter ?? '全部') == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(idx),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        notifier.setIndexerFilter(idx == '全部' ? null : idx);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(width: 4),
              ActionChip(
                avatar: const Icon(Icons.rule_folder_outlined, size: 14),
                label: const Text('规则管理'),
                tooltip: '前往设置管理 Cardigann 索引规则 (多级分类与市场)',
                onPressed: () => context.push(Routes.settingsIndexers),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    TorrentSearchState searchState, {
    required bool isTableView,
  }) {
    if (searchState.isLoading && searchState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            const CircularProgressIndicator(),
            Text(
              '正在并发检索全网资源…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final activeCount = ref
                    .watch(indexerPluginsProvider)
                    .plugins
                    .where((p) => p.isEnabled)
                    .length;
                return Text(
                  'Cardigann 引擎并发解析中 · 已激活 $activeCount 个 YAML 规则',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                );
              },
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 200.ms),
      );
    }

    if (searchState.error != null && searchState.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              Text(
                '搜索失败: ${searchState.error}',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              FilledButton.tonal(
                onPressed: () {
                  if (searchState.keyword.isNotEmpty) {
                    ref
                        .read(torrentSearchProvider.notifier)
                        .search(searchState.keyword);
                  }
                },
                child: const Text('重试'),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
        ),
      );
    }

    final filtered = searchState.filteredItems;

    // 当未搜索或没有结果时，展示引擎状态与迅雷多分类快捷搜索
    if (searchState.items.isEmpty) {
      return _buildWelcomeSearchHome(theme);
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
            Text(
              '当前筛选条件下无匹配资源',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '可尝试切换“全部”分类、取消“隐藏 CAM 枪版”或切换画质与站点',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 250.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              curve: Curves.easeOutQuad,
            ),
      );
    }

    // 使用全局统一自适应公共组件（宽屏表格 vs 窄屏卡片）
    return Column(
      children: [
        Expanded(
          child: AdaptiveDataView(
            viewMode: _viewMode,
            breakpoint: LayoutBreakpoint.compact['width']! + 100.0,
            cardBuilder: (context) => ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildTorrentCard(theme, item);
              },
            ),
            tableBuilder: (context) =>
                _buildXunleiTableView(theme, filtered, searchState),
          ),
        ),
        _buildXunleiStatusBar(theme, searchState),
      ],
    );
  }

  /// 迅雷风格底部状态栏（资源统计、健康状态与选中项概览）
  Widget _buildXunleiStatusBar(
      ThemeData theme, TorrentSearchState searchState) {
    final filtered = searchState.filteredItems;
    final total = searchState.items.length;
    final healthyCount =
        filtered.where((item) => item.health != TorrentHealth.dead).length;

    TorrentItem? selectedItem;
    if (_selectedRowIndex != null &&
        _selectedRowIndex! >= 0 &&
        _selectedRowIndex! < filtered.length) {
      selectedItem = filtered[_selectedRowIndex!];
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withAlpha(45),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: Text(
              '共 $total 项资源 · 当前展示 ${filtered.length} 项 (可用做种: $healthyCount)',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectedItem != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                '已选中: ${selectedItem.displayTitle} (${selectedItem.displayFileSize.isNotEmpty && selectedItem.displayFileSize != '-' ? selectedItem.displayFileSize : '未知大小'}) · 做种: ${selectedItem.seeders}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 迅雷风格全功能表格视图
  Widget _buildXunleiTableView(ThemeData theme, List<TorrentItem> filtered,
      TorrentSearchState searchState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表格最小保证宽度，确保在窄窗口或移动端横屏/滑动时不被挤压、标题获得充足展示空间（至少 300px+）
        const minTableWidth = 1280.0;
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;
        final needsHorizontalScroll = constraints.maxWidth < minTableWidth;

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: needsHorizontalScroll,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // 表头 (固定在顶部，支持全字段即时排序)
                  _buildTableHeader(theme, searchState),

                  // 数据行列表 (带独立垂直滚动条与控制器)
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _verticalScrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildTableRow(theme, filtered[index], index);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 迅雷表格表头（全字段支持点击列标题即时排序）
  Widget _buildTableHeader(ThemeData theme, TorrentSearchState searchState) {
    final notifier = ref.read(torrentSearchProvider.notifier);

    Widget sortHeader({
      required String label,
      required TorrentSortMode mode,
      required double width,
      Alignment alignment = Alignment.center,
    }) {
      final isActive = searchState.sortMode == mode;
      return SizedBox(
        width: width,
        child: InkWell(
          onTap: () => notifier.setSortMode(mode),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Align(
              alignment: alignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 2),
                    if (isActive)
                      Icon(
                        searchState.sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 13,
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(
                        Icons.unfold_more,
                        size: 13,
                        color: theme.colorScheme.outline.withAlpha(120),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 资源名称 (弹性填充，支持名称 A-Z 排序)
          Expanded(
            child: InkWell(
              onTap: () => notifier.setSortMode(TorrentSortMode.title),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '资源名称',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            searchState.sortMode == TorrentSortMode.title
                                ? FontWeight.bold
                                : FontWeight.w600,
                        color: searchState.sortMode == TorrentSortMode.title
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 2),
                    if (searchState.sortMode == TorrentSortMode.title)
                      Icon(
                        searchState.sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 13,
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(
                        Icons.unfold_more,
                        size: 13,
                        color: theme.colorScheme.outline.withAlpha(120),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 站点 / 来源 (95px，可排序)
          sortHeader(
            label: '站点 / 来源',
            mode: TorrentSortMode.source,
            width: 95,
          ),
          const SizedBox(width: 8),

          // 文件大小 (85px，可排序)
          sortHeader(
            label: '文件大小',
            mode: TorrentSortMode.size,
            width: 85,
            alignment: Alignment.centerRight,
          ),
          const SizedBox(width: 8),

          // 做种数 / 健康度 (95px，可排序)
          sortHeader(
            label: '做种数',
            mode: TorrentSortMode.seeders,
            width: 95,
          ),
          const SizedBox(width: 8),

          // 下载数 (70px，可排序)
          sortHeader(
            label: '下载数',
            mode: TorrentSortMode.leechers,
            width: 70,
          ),
          const SizedBox(width: 8),

          // 发布时间 (85px，可排序)
          sortHeader(
            label: '发布时间',
            mode: TorrentSortMode.age,
            width: 85,
          ),
          const SizedBox(width: 8),

          // 画质 (75px，非视频类型留空)
          SizedBox(
            width: 75,
            child: Center(
              child: Text(
                '画质',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 片源 / 编码 (115px，非视频类型留空)
          SizedBox(
            width: 115,
            child: Center(
              child: Text(
                '片源 / 编码',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 操作列 (270px，标准右对齐与下方数据行完全一致)
          SizedBox(
            width: 270,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  '操作',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 迅雷风格表格数据行
  Widget _buildTableRow(ThemeData theme, TorrentItem item, int index) {
    final isEven = index.isEven;
    final isDead = item.seeders == 0;
    final isSelected = _selectedRowIndex == index;

    final rowBg = isSelected
        ? theme.colorScheme.primaryContainer.withAlpha(90)
        : (isEven
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerLowest);

    final rowWidget = Material(
      color: rowBg,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRowIndex = index;
          });
        },
        onSecondaryTapDown: (_) {
          setState(() {
            _selectedRowIndex = index;
          });
        },
        onDoubleTap: () => _handleDownload(item),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withAlpha(45),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              // 1. 资源名称（分类色彩图标 + 完整标题 + 字幕组/Freeleech/CAM 徽章）
              Expanded(
                child: _buildTitleCell(theme, item, isDead),
              ),
              const SizedBox(width: 8),

              // 2. 站点 / 来源 (95px)
              SizedBox(
                width: 95,
                child: Center(child: _buildSourceCell(theme, item)),
              ),
              const SizedBox(width: 8),

              // 3. 文件大小 (85px)
              SizedBox(
                width: 85,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.displayFileSize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        color: isDead ? theme.colorScheme.outline : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 4. 做种数 / 健康度 (95px)
              SizedBox(
                width: 95,
                child:
                    Center(child: _buildSeedersHealthCell(theme, item, isDead)),
              ),
              const SizedBox(width: 8),

              // 5. 下载数 (70px)
              SizedBox(
                width: 70,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_downward,
                            size: 12, color: theme.colorScheme.outline),
                        const SizedBox(width: 2),
                        Text(
                          '${item.leechers}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 6. 发布时间 (85px)
              SizedBox(
                width: 85,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.displayAge,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 7. 画质 / 分辨率 (75px) —— 非视频类型严格留空！
              SizedBox(
                width: 75,
                child: Center(
                  child: item.isVideo && item.tableResolution.isNotEmpty
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.tableResolution,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(), // 非视频类型留空
                ),
              ),
              const SizedBox(width: 8),

              // 8. 片源 / 编码 (115px) —— 非视频类型严格留空！
              SizedBox(
                width: 115,
                child: Center(
                  child: item.isVideo && item.tableCodecInfo.isNotEmpty
                      ? Text(
                          item.tableCodecInfo,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(), // 非视频类型留空
                ),
              ),
              const SizedBox(width: 8),

              // 9. 操作列 (270px) —— 迅雷主流规范：右对齐排布，下载按钮固定锚定最右侧，全列绝对垂直对齐
              SizedBox(
                width: 270,
                child: _buildActionCell(theme, item),
              ),
            ],
          ),
        ),
      ),
    );

    return AppContextMenu(
      itemsBuilder: (context) => _buildContextMenuItems(item),
      child: rowWidget
          .animate()
          .fadeIn(duration: 180.ms)
          .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
    );
  }

  /// 资源标题单元格
  Widget _buildTitleCell(ThemeData theme, TorrentItem item, bool isDead) {
    final icon = _getCategoryIcon(item.category);
    final iconColor = _getCategoryColor(item.category, theme);

    final linkDesc = switch (item.linkType) {
      TorrentLinkType.dual => '\n链接: 种子 + 磁力 (双链 · 默认优先种子)',
      TorrentLinkType.torrentOnly => '\n链接: 种子文件 (.torrent)',
      TorrentLinkType.magnetOnly => '\n链接: 磁力链接 (magnet)',
      TorrentLinkType.none => '',
    };

    return Tooltip(
      message:
          '${item.title}\n\n分类: ${item.category == TorrentCategory.all ? '全部/未分类' : item.category.label}$linkDesc\n体积: ${item.displayFileSize}${item.effectiveTorrentUrl != null ? '\n种子: ${item.effectiveTorrentUrl}' : ''}${item.effectiveMagnetUrl != null ? '\n磁力: ${item.effectiveMagnetUrl}' : ''}${item.pageUrl != null && item.pageUrl!.isNotEmpty ? '\n原始发布页: ${item.pageUrl}' : ''}',
      waitDuration: const Duration(milliseconds: 300),
      child: Row(
        children: [
          // 分类图标
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),

          // 标题与徽章
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.displayTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDead
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.linkType != TorrentLinkType.none) ...[
                  const SizedBox(width: 6),
                  TorrentLinkBadge.fromItem(item, compact: true),
                ],
                if (item.subgroup != null && item.subgroup!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.secondaryContainer.withAlpha(140),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.subgroup!,
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (item.isFreeleech) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                      border:
                          Border.all(color: Colors.green.shade600, width: 0.6),
                    ),
                    child: const Text(
                      'Freeleech',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (item.isVideo && item.isCollection) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(140),
                          width: 0.6),
                    ),
                    child: Text(
                      '合集',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (item.isVideo && item.isCam) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'CAM 枪版',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (item.isArchive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                      border:
                          Border.all(color: Colors.amber.shade700, width: 0.6),
                    ),
                    child: Text(
                      '${item.archiveFormatName ?? "压缩包"} 需解压',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 站点徽标单元格
  Widget _buildSourceCell(ThemeData theme, TorrentItem item) {
    final name = item.indexerName ?? _getSourceName(item.source);
    final hasPageUrl = item.pageUrl != null && item.pageUrl!.isNotEmpty;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(160),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasPageUrl) ...[
            const SizedBox(width: 3),
            Icon(
              Icons.open_in_new,
              size: 10,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );

    final tooltipMsg = hasPageUrl
        ? 'Torznab / Cardigann P2P 种子索引\n点击在浏览器中打开原始发布页:\n${item.pageUrl}'
        : 'Torznab / Cardigann P2P 种子索引';

    if (hasPageUrl) {
      return Tooltip(
        message: tooltipMsg,
        child: InkWell(
          onTap: () => _openBrowserUrl(item.pageUrl!),
          borderRadius: BorderRadius.circular(4),
          child: badge,
        ),
      );
    }

    return Tooltip(
      message: tooltipMsg,
      child: badge,
    );
  }

  /// 做种数与健康度单元格
  Widget _buildSeedersHealthCell(
      ThemeData theme, TorrentItem item, bool isDead) {
    final (Color dotColor, String statusText) = switch (item.health) {
      TorrentHealth.high => (Colors.green.shade600, '极佳'),
      TorrentHealth.medium => (Colors.amber.shade700, '良好'),
      TorrentHealth.low => (Colors.orange.shade700, '较慢'),
      TorrentHealth.dead => (theme.colorScheme.outline, '无做种'),
    };

    return Tooltip(
      message: '做种数: ${item.seeders} · 健康度: $statusText',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.arrow_upward,
              size: 12,
              color: isDead ? theme.colorScheme.outline : dotColor,
            ),
            const SizedBox(width: 2),
            Text(
              isDead ? '0' : '${item.seeders}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDead ? theme.colorScheme.outline : dotColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 表格操作按钮列（迅雷与现代主流表格规范：右对齐排布，下载按钮固定锚定最右侧，单行绝不折行，全列绝对垂直对齐）
  Widget _buildActionCell(ThemeData theme, TorrentItem item) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // 1. 在线看 / 在线听 (仅针对多媒体视频/音频类型展示，单行不折行)
            if (item.canStreamVideo) ...[
              OutlinedButton.icon(
                onPressed: () => _handleStreamPlay(item),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text(
                  '在线看',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(72, 30),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
            ] else if (item.canStreamAudio) ...[
              OutlinedButton.icon(
                onPressed: () => _handleStreamPlay(item),
                icon: const Icon(Icons.headphones_outlined, size: 14),
                label: const Text(
                  '在线听',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(72, 30),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
            ],

            // 2. 打开原始发布页 (如果存在原始发布页 URL)
            if (item.pageUrl != null && item.pageUrl!.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.open_in_browser, size: 16),
                tooltip: '打开原始发布页:\n${item.pageUrl}',
                onPressed: () => _openBrowserUrl(item.pageUrl!),
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                  maxWidth: 28,
                  maxHeight: 28,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],

            // 3. 复制磁力链接 (常驻工具)
            IconButton(
              icon: const Icon(Icons.copy, size: 15),
              tooltip: '复制磁力链接',
              onPressed: () => _copyMagnet(item),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
                maxWidth: 28,
                maxHeight: 28,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),

            // 4. 迅雷风格三联树选择性下载 (常驻核心工具)
            IconButton(
              icon: const Icon(Icons.checklist_rtl, size: 16),
              tooltip: '选择性下载 (三联树文件定制)',
              onPressed: () => _handleSelectiveDownload(item),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
                maxWidth: 28,
                maxHeight: 28,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),

            // 5. 迅雷一键下载 (主要核心操作，严格固定在最右侧，单行绝不折行，全列绝对垂直对齐)
            FilledButton.tonalIcon(
              onPressed: () => _handleDownload(item),
              icon: const Icon(Icons.download, size: 14),
              label: const Text(
                '下载',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(66, 30),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  /// 迅雷风格资源卡片（供移动端或卡片模式使用）
  Widget _buildTorrentCard(ThemeData theme, TorrentItem item) {
    final isDead = item.seeders == 0;
    final icon = _getCategoryIcon(item.category);
    final iconColor = _getCategoryColor(item.category, theme);

    final cardWidget = Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行与分类图标
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDead ? theme.colorScheme.outline : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 属性徽章行（列式信息客观展现）
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 站点
                Tooltip(
                  message: 'Torznab / Cardigann P2P 种子索引',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.indexerName ?? _getSourceName(item.source),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),

                // 链接类型徽章（标清楚是磁力还是种子，还是两者都有）
                if (item.linkType != TorrentLinkType.none)
                  TorrentLinkBadge.fromItem(item, compact: false),

                // 分类徽标
                if (item.category != TorrentCategory.all)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),

                if (item.isArchive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: Colors.amber.shade700, width: 0.6),
                    ),
                    child: Text(
                      '${item.archiveFormatName ?? "压缩包"} 需解压',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),

                // 视频特有属性（画质、片源、编码等，非视频直接留空省略）
                if (item.isVideo && item.tableResolution.isNotEmpty)
                  Badge(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    label: Text(
                      item.tableResolution,
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (item.isVideo && item.tableCodecInfo.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.tableCodecInfo,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                if (item.subgroup != null && item.subgroup!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

                if (item.isFreeleech)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: Colors.green.shade600, width: 0.8),
                    ),
                    child: const Text(
                      'Freeleech',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (item.isVideo && item.isCollection)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(140),
                          width: 0.6),
                    ),
                    child: Text(
                      '合集',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (item.isCam)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CAM 枪版',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // 体积
                if (item.displayFileSize.isNotEmpty &&
                    item.displayFileSize != '-')
                  Text(
                    item.displayFileSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                // 发布时间
                if (item.ageString.isNotEmpty)
                  Text(
                    '· ${item.ageString}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),

                // 做种与下载健康度
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 13,
                      color: isDead
                          ? theme.colorScheme.outline
                          : Colors.green.shade700,
                    ),
                    Text(
                      '${item.seeders}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDead
                            ? theme.colorScheme.outline
                            : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_downward,
                        size: 13, color: theme.colorScheme.outline),
                    Text(
                      '${item.leechers}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            (isDead ? Colors.grey : Colors.green).withAlpha(30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        item.health.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDead
                              ? theme.colorScheme.outline
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 原始完整标题
            Text(
              item.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // 原始发布页 URL（如果存在，直观显示并支持一键打开）
            if (item.pageUrl != null && item.pageUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Tooltip(
                message: '点击在浏览器中打开原始发布页:\n${item.pageUrl}',
                child: InkWell(
                  onTap: () => _openBrowserUrl(item.pageUrl!),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '原始页面',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.pageUrl!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 12, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // 操作按钮行（迅雷风格：工具操作居左，在线播放与立即下载严格锚定右下角，全卡片基线对齐）
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  // 复制磁力链接
                  IconButton.outlined(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: '复制磁力链接',
                    onPressed: () => _copyMagnet(item),
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 6),

                  // 选文件（三联树选择性下载）
                  IconButton.outlined(
                    onPressed: () => _handleSelectiveDownload(item),
                    icon: const Icon(Icons.checklist_rtl, size: 16),
                    tooltip: '选择性下载 (三联树)',
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),

                  // 原始发布页 (如果存在)
                  if (item.pageUrl != null && item.pageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      onPressed: () => _openBrowserUrl(item.pageUrl!),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      tooltip: '原始页面:\n${item.pageUrl}',
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: EdgeInsets.zero,
                    ),
                  ],

                  const SizedBox(width: 12),

                  // 在线看 / 在线听
                  if (item.canStreamVideo) ...[
                    OutlinedButton.icon(
                      onPressed: () => _handleStreamPlay(item),
                      icon: const Icon(Icons.play_arrow, size: 15),
                      label: const Text('在线看', maxLines: 1, softWrap: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (item.canStreamAudio) ...[
                    OutlinedButton.icon(
                      onPressed: () => _handleStreamPlay(item),
                      icon: const Icon(Icons.headphones_outlined, size: 15),
                      label: const Text('在线听', maxLines: 1, softWrap: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // 立即下载 (统一锚定在卡片最右侧，全卡片严格垂直对齐)
                  FilledButton.tonalIcon(
                    onPressed: () => _handleDownload(item),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('立即下载', maxLines: 1, softWrap: false),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return AppContextMenu(
      itemsBuilder: (context) => _buildContextMenuItems(item),
      child: cardWidget
          .animate()
          .fadeIn(duration: 180.ms)
          .slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
    );
  }

  /// 搜索未发起时的工具型首屏（仅展示用户本身的搜索历史，杜绝硬编码假热门推荐）
  Widget _buildWelcomeSearchHome(ThemeData theme) {
    final histories = ref.watch(searchHistoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (histories.isNotEmpty) ...[
              // 搜索历史标题与清空操作栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '搜索历史',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(searchHistoryProvider.notifier).clearAll();
                    },
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      size: 15,
                      color: theme.colorScheme.outline,
                    ),
                    label: Text(
                      '清空历史',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 历史记录气泡标签列表
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: histories.map((h) {
                  return InputChip(
                    avatar: Icon(
                      Icons.history,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      h.keyword,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      widget.onSearchKeywordSelected?.call(h.keyword);
                      ref
                          .read(torrentSearchProvider.notifier)
                          .search(h.keyword);
                    },
                    onDeleted: () {
                      ref
                          .read(searchHistoryProvider.notifier)
                          .deleteHistory(h);
                    },
                    deleteIcon: const Icon(Icons.close, size: 14),
                    deleteButtonTooltipMessage: '删除此记录',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.dividerColor.withAlpha(50),
                      ),
                    ),
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),
            ] else ...[
              // 无搜索历史时的极简工具型占位引导
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(100),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.travel_explore_outlined,
                          size: 36,
                          color: theme.colorScheme.primary.withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '全网资源聚合检索',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '在上方搜索框直接输入作品名称，支持动漫、影视、音乐、游戏与各类资源',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 底部索引器引擎就绪状态指示器
            Consumer(
              builder: (context, ref, _) {
                final activeCount = ref
                    .watch(indexerPluginsProvider)
                    .plugins
                    .where((p) => p.isEnabled)
                    .length;
                return Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(60),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withAlpha(40),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Cardigann 引擎就绪 · 已激活 $activeCount 个索引规则',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
  }
}
