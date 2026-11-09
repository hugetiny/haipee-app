import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/modal_sheet/haipee_modal_sheet.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/pages/player/local_player_page.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_service.dart';
import 'package:haipee/modules/torrent_stream/widgets/torrent_stream_dialog.dart';
import 'package:haipee/modules/torrent_search/widgets/selective_download_dialog.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_search/widgets/torrent_link_badge.dart';
import 'package:haipee/modules/torrent_search/utils/torrent_download_helper.dart';
import 'package:haipee/modules/torrent_search/parser/torrent_file_parser.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:haipee/router_constants.dart';

import 'package:haipee/utils/constants.dart';
import 'package:haipee/bean/widget/adaptive_data_view.dart';
import 'package:haipee/bean/widget/search/unified_search_workspace.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';

/// 全网资源搜索视图显示模式（统一对齐全局 AdaptiveViewMode 规范）
typedef ResourceViewMode = AdaptiveViewMode;

/// 迅雷风格泛用全网资源搜索主体视图
/// 深度整合 Bangumi 官方元数据与多源全网资源下载检索
class ResourceSearchContent extends ConsumerStatefulWidget {
  final void Function(String keyword)? onSearchKeywordSelected;
  final bool showInlineFilterSection;
  final ResourceViewMode? externalViewMode;
  final ValueChanged<ResourceViewMode>? onExternalViewModeChanged;

  const ResourceSearchContent({
    super.key,
    this.onSearchKeywordSelected,
    this.showInlineFilterSection = true,
    this.externalViewMode,
    this.onExternalViewModeChanged,
  });

  @override
  ConsumerState<ResourceSearchContent> createState() =>
      _ResourceSearchContentState();
}

class _ResourceSearchContentState extends ConsumerState<ResourceSearchContent> {
  // 迅雷风格表格水平与垂直滚动控制器
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // 视图显示模式（默认为 auto 自动响应式，亦支持强制表格或卡片/网格）
  ResourceViewMode _viewMode = ResourceViewMode.auto;

  ResourceViewMode get _effectiveViewMode =>
      widget.externalViewMode ?? _viewMode;

  void _updateViewMode(ResourceViewMode mode) {
    if (widget.onExternalViewModeChanged != null) {
      widget.onExternalViewModeChanged!(mode);
    } else {
      setState(() {
        _viewMode = mode;
      });
    }
  }

  /// 自动切换表格视图的可用宽度断点（对齐 Material 3 紧凑屏基准 600dp 并预留侧边栏与边距）
  static final double responsiveBreakpoint =
      LayoutBreakpoint.compact['width']! + 100.0; // 700.0

  // 当前表格选中的行索引（对齐迅雷选中高亮体验）
  int? _selectedRowIndex;

  /// 计算在给定可用宽度和当前视图模式下的实际展示样式
  bool _isTableViewForWidth(double availableWidth) {
    switch (_effectiveViewMode) {
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
            HaipeeDialog.showToast(message: '已复制资源全称', context: context);
          }
        },
      ),
    ];
  }



  Future<void> _copyMagnet(TorrentItem item) async {
    final magnet = item.effectiveMagnetUrl ?? item.magnetUrl;
    if (magnet.isEmpty) {
      HaipeeDialog.showToast(message: '未找到有效的磁力链接', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: magnet));
    if (mounted) {
      HaipeeDialog.showToast(message: '已复制磁力链接', context: context);
    }
  }

  Future<void> _copyTorrentUrl(TorrentItem item) async {
    final url = item.effectiveTorrentUrl;
    if (url == null || url.isEmpty) {
      HaipeeDialog.showToast(message: '未找到有效的种子下载链接', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      HaipeeDialog.showToast(message: '已复制种子下载链接', context: context);
    }
  }

  Future<void> _saveTorrentFile(TorrentItem item) async {
    final url = item.effectiveTorrentUrl;
    if (url == null || url.isEmpty) {
      HaipeeDialog.showToast(message: '未找到有效的种子下载链接', context: context);
      return;
    }

    HaipeeDialog.showLoading(msg: '正在下载种子文件 (.torrent)...');
    try {
      final bytes = await TorrentDownloadHelper.fetchTorrentBytes(url);
      HaipeeDialog.dismiss();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          HaipeeDialog.showToast(
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
        HaipeeDialog.showToast(message: '种子已保存至: ${file.path}', context: context);
      }
    } catch (e) {
      HaipeeDialog.dismiss();
      if (mounted) {
        HaipeeDialog.showToast(message: '保存种子异常: $e', context: context);
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
        HaipeeDialog.showToast(message: '无法在浏览器中打开链接', context: context);
      }
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '打开链接失败: $e', context: context);
      }
    }
  }

  Future<void> _handleDownload(TorrentItem item) async {
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      HaipeeDialog.showToast(message: '未找到有效的下载链接', context: context);
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
        HaipeeLogger().log(
          Level.warning,
          '优先下载种子文件失败，平滑降级至磁力链接添加: $e',
        );
      }
    }

    // 种子内存下载失败或超时：平滑降级使用磁力链接；若无磁力链接则直接将原种子 URL 交付 Gopeed 引擎后台下载
    final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
    final fallbackUrl = fallbackMagnet.isNotEmpty
        ? fallbackMagnet
        : (item.effectiveTorrentUrl ?? item.torrentUrl ?? '');

    if (fallbackUrl.isEmpty) {
      if (mounted) {
        HaipeeDialog.showToast(message: '未找到可用的下载链接', context: context);
      }
      return;
    }

    try {
      await downloadCtrl.addUris(
        [fallbackUrl],
        title: downloadTitle,
        episodeNumber: episodeNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fallbackUrl.startsWith('magnet:?')
                  ? '已添加磁力下载任务至队列: $downloadTitle'
                  : '已添加下载任务至队列: $downloadTitle',
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
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '添加下载失败: $e', context: context);
      }
    }
  }

  /// 迅雷风格三联树选择性下载流程（默认优先种子秒级展开目录树 + 磁力 DHT 降级兜底）
  Future<void> _handleSelectiveDownload(TorrentItem item) async {
    final hasTorrent = item.hasTorrent && item.effectiveTorrentUrl != null;
    final hasMagnet = item.hasMagnet &&
        (item.effectiveMagnetUrl != null || item.magnetUrl.isNotEmpty);

    if (!hasTorrent && !hasMagnet) {
      HaipeeDialog.showToast(message: '未找到有效的下载链接', context: context);
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
      HaipeeDialog.showLoading(
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

    // 2. 如果无种子或种子拉取失败，平滑降级到磁力 DHT 与 Tracker 解析
    if (entries == null || entries.isEmpty) {
      if (cancelToken.isCancelled) {
        HaipeeDialog.dismiss();
        return;
      }

      final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
      if (fallbackMagnet.isEmpty) {
        HaipeeDialog.dismiss();
        if (mounted) {
          HaipeeDialog.showToast(message: '未能下载种子文件且无磁力链接', context: context);
        }
        return;
      }

      HaipeeDialog.showLoading(
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
            HaipeeDialog.showLoading(msg: status);
          },
        );
      } on TorrentStreamCancelledException {
        HaipeeDialog.dismiss();
        return;
      } catch (e) {
        HaipeeDialog.dismiss();
        if (mounted) {
          HaipeeDialog.showToast(message: '解析磁力元数据失败: $e', context: context);
        }
        return;
      }
    }

    isCompleted = true;
    HaipeeDialog.dismiss();
    if (!mounted) return;

    if (entries.isEmpty) {
      HaipeeDialog.showToast(message: '未能获取到该资源的文件列表', context: context);
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
      HaipeeDialog.showToast(message: '未找到有效的下载链接', context: context);
      return;
    }

    if (item.isArchive) {
      final format = item.archiveFormatName ?? '压缩包';
      final confirmed = await HaipeeModalSheet.showConfirmation(
        context: context,
        title: '无法在线播放',
        message: '该资源为 $format 压缩包格式（${item.title}），不支持直接在线边下边播。\n\n建议离线下载到本地解压后播放。',
        confirmText: '立即下载',
        cancelText: '取消',
        icon: Icons.archive_outlined,
      );
      if (confirmed == true) {
        _handleDownload(item);
      }
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
        HaipeeDialog.showToast(message: '流式播放启动异常: $e', context: context);
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
            // Cardigann 规范多行参数筛选体系 (独立内嵌模式展示；在 UnifiedSearchHeader 页面级模式中由顶部「筛选」按钮统一控制)
            if (widget.showInlineFilterSection)
              _buildCardigannFilterSection(theme, searchState,
                  isTableView: isTableView),

            // 渐进式流式抓取进度条（首屏已呈现，后台索引器仍在并发追加）
            if (searchState.isLoading && searchState.items.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),

            // 内容展示区域（表格视图 / 网格卡片视图 / 统一规则就绪态）
            Expanded(
              child: _buildBody(theme, searchState, isTableView: isTableView),
            ),
          ],
        );
      },
    );
  }

  /// Cardigann 规范多行参数筛选体系 (分类 cat / 访问类型 type / 索引器 indexer / 排序规则 sort)
  Widget _buildCardigannFilterSection(
    ThemeData theme,
    TorrentSearchState searchState, {
    required bool isTableView,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withAlpha(50),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第 1 行: Cardigann 分类参数 (cat / category)
          _buildCategoryFilterRow(theme, searchState),

          if (searchState.items.isNotEmpty) ...[
            Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withAlpha(25)),
            // 第 2 行: Cardigann 站点访问性质 (type: public / semi-private / private)
            _buildTrackerTypeFilterRow(theme, searchState),

            Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withAlpha(25)),
            // 第 3 行: Cardigann 来源站点 (indexer)
            _buildIndexerFilterRow(theme, searchState),

            Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withAlpha(25)),
            // 第 4 行: Cardigann 排序参数 (sort) + 视图切换与条目统计
            _buildSortFilterRow(theme, searchState, isTableView: isTableView),
          ],
        ],
      ),
    );
  }

  /// 封装每行筛选项的标准布局：左侧参数标签 + 中间可横向滑动选项 + 右侧可选操作区
  Widget _buildFilterRowContainer({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // 左侧参数标签 (固定宽度保持对齐)
          SizedBox(
            width: 95,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: theme.colorScheme.primary.withAlpha(200),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 中间水平滑动选项与操作区
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...children,
                  if (trailing != null) ...[
                    const SizedBox(
                      height: 18,
                      child: VerticalDivider(width: 16, thickness: 1),
                    ),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 第 1 行: Cardigann 分类参数 (cat / category) 筛选行
  Widget _buildCategoryFilterRow(
      ThemeData theme, TorrentSearchState searchState) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final counts = searchState.categoryCounts;
    final activeProtocol = searchState.ruleProtocolFilter ?? 'all';
    final alistCount =
        searchState.items.where(TorrentSearchState.isAlistItem).length;
    final cardigannCount = searchState.items.length - alistCount;

    return _buildFilterRowContainer(
      theme: theme,
      label: '分类 (cat)',
      icon: Icons.category_outlined,
      children: [
        ...TorrentCategory.values.map((cat) {
          final isSelected = searchState.categoryFilter == cat;
          final count = cat == TorrentCategory.all
              ? searchState.items.length
              : (counts[cat] ?? 0);
          final icon = _getCategoryIcon(cat);
          final color = _getCategoryColor(cat, theme);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('category_chip_${cat.name}'),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                icon,
                size: 14,
                color: isSelected ? theme.colorScheme.onPrimary : color,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.label, style: const TextStyle(fontSize: 12)),
                  if (searchState.items.isNotEmpty && count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 10,
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
        }),
        const SizedBox(
          height: 18,
          child: VerticalDivider(width: 14, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            key: const Key('resource_rule_chip_cardigann'),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(
              Icons.downloading_outlined,
              size: 14,
              color: activeProtocol == 'cardigann'
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cardigann 规则', style: TextStyle(fontSize: 12)),
                if (searchState.items.isNotEmpty && cardigannCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($cardigannCount)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activeProtocol == 'cardigann'
                          ? theme.colorScheme.onPrimary.withAlpha(220)
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            selected: activeProtocol == 'cardigann',
            onSelected: (_) => notifier.setRuleProtocolFilter(
              activeProtocol == 'cardigann' ? 'all' : 'cardigann',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            key: const Key('resource_rule_chip_alist'),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(
              Icons.cloud_outlined,
              size: 14,
              color: activeProtocol == 'alist'
                  ? theme.colorScheme.onPrimary
                  : Colors.blue.shade600,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('AList 规则', style: TextStyle(fontSize: 12)),
                if (searchState.items.isNotEmpty && alistCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($alistCount)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activeProtocol == 'alist'
                          ? theme.colorScheme.onPrimary.withAlpha(220)
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            selected: activeProtocol == 'alist',
            onSelected: (_) => notifier.setRuleProtocolFilter(
              activeProtocol == 'alist' ? 'all' : 'alist',
            ),
          ),
        ),
      ],
    );
  }

  /// 第 2 行: Cardigann 站点访问性质 (type: public / semi-private / private) 筛选行
  Widget _buildTrackerTypeFilterRow(
      ThemeData theme, TorrentSearchState searchState) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final currentType = searchState.trackerTypeFilter ?? 'all';

    int publicCount = 0;
    int semiPrivateCount = 0;
    int privateCount = 0;
    for (final item in searchState.items) {
      if (item.isPrivateTracker) {
        privateCount++;
      } else if (item.isSemiPrivateTracker) {
        semiPrivateCount++;
      } else {
        publicCount++;
      }
    }

    final types = [
      ('all', '全部性质', searchState.items.length, Icons.all_inclusive),
      ('public', '公开 Public', publicCount, Icons.public),
      ('semi-private', '半私有 Semi', semiPrivateCount, Icons.lock_open_outlined),
      ('private', '私有 PT', privateCount, Icons.lock_outlined),
    ];

    return _buildFilterRowContainer(
      theme: theme,
      label: '性质 (type)',
      icon: Icons.shield_outlined,
      children: [
        ...types.map((entry) {
          final isSelected = currentType == entry.$1;
          final count = entry.$3;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('tracker_type_chip_${entry.$1}'),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                entry.$4,
                size: 13,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.$2, style: const TextStyle(fontSize: 12)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 10,
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
              onSelected: (_) => notifier.setTrackerTypeFilter(entry.$1),
            ),
          );
        }),
      ],
    );
  }

  /// 第 3 行: Cardigann 来源站点 (indexer) 筛选行
  Widget _buildIndexerFilterRow(
      ThemeData theme, TorrentSearchState searchState) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final currentIndexer = searchState.indexerFilter ?? '全部';

    final indexerCounts = <String, int>{};
    for (final item in searchState.items) {
      final name = item.effectiveSourceName;
      indexerCounts[name] = (indexerCounts[name] ?? 0) + 1;
    }

    return _buildFilterRowContainer(
      theme: theme,
      label: '站点 (indexer)',
      icon: Icons.hub_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            key: const Key('indexer_chip_all'),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(
              '全部站点 (${searchState.items.length})',
              style: const TextStyle(fontSize: 12),
            ),
            selected: currentIndexer == '全部',
            onSelected: (_) => notifier.setIndexerFilter(null),
          ),
        ),
        ...indexerCounts.entries.map((entry) {
          final isSelected = currentIndexer == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('indexer_chip_${entry.key}'),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                '${entry.key} (${entry.value})',
                style: const TextStyle(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (val) {
                notifier.setIndexerFilter(val ? entry.key : null);
              },
            ),
          );
        }),
      ],
    );
  }

  /// 第 4 行: Cardigann 排序参数 (sort) 与控制栏
  Widget _buildSortFilterRow(
    ThemeData theme,
    TorrentSearchState searchState, {
    required bool isTableView,
  }) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    final filteredCount = searchState.filteredItems.length;
    final totalCount = searchState.items.length;

    final sortOptions = [
      (TorrentSortMode.smart, '智能综合', Icons.auto_awesome),
      (TorrentSortMode.seeders, '做种优先', Icons.arrow_upward),
      (TorrentSortMode.age, '发布时间', Icons.schedule),
      (TorrentSortMode.size, '文件体积', Icons.data_usage),
      (TorrentSortMode.leechers, '下载热度', Icons.arrow_downward),
      (TorrentSortMode.title, '资源名称', Icons.sort_by_alpha),
    ];

    return _buildFilterRowContainer(
      theme: theme,
      label: '排序 (sort)',
      icon: Icons.sort_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 升序/降序快速切换按钮
          IconButton(
            tooltip: searchState.sortAscending
                ? '当前升序 (点击切换为降序)'
                : '当前降序 (点击切换为升序)',
            icon: Icon(
              searchState.sortAscending ? Icons.north : Icons.south,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => notifier.setSortMode(
              searchState.sortMode,
              ascending: !searchState.sortAscending,
            ),
          ),
          const SizedBox(width: 4),
          const SizedBox(
            height: 16,
            child: VerticalDivider(width: 10, thickness: 1),
          ),
          // 响应式视图切换器（自动 / 表格 / 卡片）
          AdaptiveViewSwitcher(
            viewMode: _effectiveViewMode,
            isTableView: isTableView,
            onModeChanged: _updateViewMode,
          ),
          const SizedBox(width: 8),
          // 统计计数徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              filteredCount == totalCount
                  ? '共 $totalCount 项'
                  : '$filteredCount / $totalCount 项',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      children: [
        ...sortOptions.map((entry) {
          final isSelected = searchState.sortMode == entry.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey('sort_chip_${entry.$1.name}'),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                entry.$3,
                size: 13,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) {
                if (isSelected) {
                  // 点击已选中的排序方式时，反转升降序
                  notifier.setSortMode(entry.$1,
                      ascending: !searchState.sortAscending);
                } else {
                  notifier.setSortMode(entry.$1);
                }
              },
            ),
          );
        }),
      ],
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
              '可尝试切换“全部”分类或重置画质与站点筛选',
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

    // 使用全局统一自适应公共组件（支持 Table View 表格视图与 Grid View 网格卡片视图）
    return Column(
      children: [
        if (!widget.showInlineFilterSection)
          UnifiedSearchResultSummaryBar(
            headerIcon: Icons.hub_outlined,
            countLabel: filtered.length == searchState.items.length
                ? '找到 ${filtered.length} 项全网资源'
                : '筛选出 ${filtered.length} / ${searchState.items.length} 项全网资源',
            isSearching: searchState.isLoading,
            completedSources: searchState.sourceCount.length,
            totalSources: searchState.sourceCount.length,
          ),
        Expanded(
          child: AdaptiveDataView(
            viewMode: _effectiveViewMode,
            breakpoint: LayoutBreakpoint.compact['width']! + 100.0,
            cardBuilder: (context) => LayoutBuilder(
              builder: (context, cardConstraints) {
                final width = cardConstraints.maxWidth;
                // 宽屏/平板 (>= 620px) 采用多列网格视图 (Grid View)，窄屏移动端 (< 620px) 采用单列卡片流
                if (width >= 620) {
                  final crossAxisCount = width >= 1150 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 232,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildTorrentCard(theme, item, inGrid: true);
                    },
                  );
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildTorrentCard(theme, item, inGrid: false);
                  },
                );
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
              // 1. 资源名称（分类色彩图标 + 完整标题 + 字幕组/Freeleech 徽章）
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

  /// 站点访问性质标签（公开 / 半私有 / 私有 PT / 网盘）
  Widget _buildTrackerNatureTag(ThemeData theme, TorrentItem item) {
    final bool isAlist = TorrentSearchState.isAlistItem(item);
    final String label;
    final Color bgColor;
    final Color fgColor;

    if (isAlist) {
      label = '网盘';
      bgColor = Colors.blue.withAlpha(30);
      fgColor = Colors.blue;
    } else if (item.isPrivateTracker) {
      label = '私有 PT';
      bgColor = theme.colorScheme.errorContainer.withAlpha(160);
      fgColor = theme.colorScheme.error;
    } else if (item.isSemiPrivateTracker) {
      label = '半私有';
      bgColor = Colors.orange.withAlpha(35);
      fgColor = Colors.orange.shade800;
    } else {
      label = '公开';
      bgColor = Colors.green.withAlpha(30);
      fgColor = Colors.green.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fgColor.withAlpha(70), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fgColor,
        ),
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

    final siteWidget = hasPageUrl
        ? Tooltip(
            message: tooltipMsg,
            child: InkWell(
              onTap: () => _openBrowserUrl(item.pageUrl!),
              borderRadius: BorderRadius.circular(4),
              child: badge,
            ),
          )
        : Tooltip(
            message: tooltipMsg,
            child: badge,
          );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          siteWidget,
          const SizedBox(width: 4),
          _buildTrackerNatureTag(theme, item),
        ],
      ),
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

  /// 迅雷风格资源卡片（同时兼容桌面端多列 Grid View 与移动端单列卡片视图）
  Widget _buildTorrentCard(
    ThemeData theme,
    TorrentItem item, {
    bool inGrid = false,
  }) {
    final isDead = item.seeders == 0;
    final icon = _getCategoryIcon(item.category);
    final iconColor = _getCategoryColor(item.category, theme);

    final middleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 属性徽章行（列式信息客观展现）
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 协议类型徽标 (区分 CARDIGANN 与 ALIST)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: TorrentSearchState.isAlistItem(item)
                    ? Colors.blue.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                TorrentSearchState.isAlistItem(item) ? 'ALIST' : 'CARDIGANN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TorrentSearchState.isAlistItem(item)
                      ? Colors.blue.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            // 站点
            Tooltip(
              message: 'Torznab / Cardigann P2P 种子索引',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            _buildTrackerNatureTag(theme, item),

            // 链接类型徽章（标清楚是磁力还是种子，还是两者都有）
            if (item.linkType != TorrentLinkType.none)
              TorrentLinkBadge.fromItem(item, compact: false),

            // 分类徽标
            if (item.category != TorrentCategory.all)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade700, width: 0.6),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

            if (item.isFreeleech)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade600, width: 0.8),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

            // 体积
            if (item.displayFileSize.isNotEmpty && item.displayFileSize != '-')
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isDead ? Colors.grey : Colors.green).withAlpha(30),
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
                    Icon(Icons.link,
                        size: 14, color: theme.colorScheme.primary),
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
                    Icon(Icons.open_in_new,
                        size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

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
                    maxLines: inGrid ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (inGrid)
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: middleSection,
                ),
              )
            else
              middleSection,
            const SizedBox(height: 10),

            // 操作按钮行（迅雷风格：工具操作居左，在线播放与立即下载严格锚定右下角，全卡片基线对齐）
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
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

  /// 搜索未发起时的工具型首屏（复用全局统一组件 UnifiedRuleReadinessCard，消除冗余搜索历史重复渲染）
  Widget _buildWelcomeSearchHome(ThemeData theme) {
    final plugins = ref.watch(indexerPluginsProvider).plugins;
    final enabledPlugins = plugins.where((p) => p.isEnabled).toList();
    final alistCount = enabledPlugins
        .where((p) =>
            p.id.toLowerCase().contains('alist') ||
            p.name.toLowerCase().contains('alist'))
        .length;
    final cardigannCount = enabledPlugins.length - alistCount;
    final publicCount = enabledPlugins
        .where((p) => p.typeStr.toLowerCase() == 'public')
        .length;
    final semiPrivateCount = enabledPlugins
        .where((p) => p.typeStr.toLowerCase() == 'semi-private')
        .length;
    final privateCount = enabledPlugins
        .where((p) => p.typeStr.toLowerCase() == 'private')
        .length;

    return SingleChildScrollView(
      child: UnifiedRuleReadinessCard(
        title: '已启用规则 (${enabledPlugins.length} 个资源索引规则)',
        badges: [
          UnifiedRuleBadgeData(
            icon: Icons.downloading_outlined,
            label: 'Cardigann 规则',
            count: cardigannCount,
          ),
          UnifiedRuleBadgeData(
            icon: Icons.cloud_outlined,
            label: 'AList 规则',
            count: alistCount,
          ),
          UnifiedRuleBadgeData(
            icon: Icons.public_rounded,
            label: '公开 Public 站点',
            count: publicCount,
          ),
          UnifiedRuleBadgeData(
            icon: Icons.lock_open_outlined,
            label: '半私有 Semi 站点',
            count: semiPrivateCount,
          ),
          UnifiedRuleBadgeData(
            icon: Icons.lock_outlined,
            label: '私有 PT 站点',
            count: privateCount,
          ),
        ],
      ),
    );
  }
}

/// 全网资源搜索统一多维筛选面板（复用 UnifiedFilterPanelContainer / UnifiedFilterCategoryRow / UnifiedFilterChoiceChip）
/// 与「视频直播 (OnlineVideoSearchPage)」共享完全一致的筛选面板视觉与交互组件规范
class ResourceSearchFilterPanel extends ConsumerWidget {
  const ResourceSearchFilterPanel({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(torrentSearchProvider);
    final notifier = ref.read(torrentSearchProvider.notifier);
    final counts = searchState.categoryCounts;
    final activeProtocol = searchState.ruleProtocolFilter ?? 'all';
    final alistCount =
        searchState.items.where(TorrentSearchState.isAlistItem).length;
    final cardigannCount = searchState.items.length - alistCount;
    final currentType = searchState.trackerTypeFilter ?? 'all';
    final currentIndexer = searchState.indexerFilter ?? '全部';

    int publicCount = 0;
    int semiPrivateCount = 0;
    int privateCount = 0;
    final indexerCounts = <String, int>{};
    for (final item in searchState.items) {
      if (item.isPrivateTracker) {
        privateCount++;
      } else if (item.isSemiPrivateTracker) {
        semiPrivateCount++;
      } else {
        publicCount++;
      }
      final name = item.effectiveSourceName;
      indexerCounts[name] = (indexerCounts[name] ?? 0) + 1;
    }

    final types = [
      ('all', '全部性质', searchState.items.length, Icons.all_inclusive),
      ('public', '公开 Public', publicCount, Icons.public),
      ('semi-private', '半私有 Semi', semiPrivateCount, Icons.lock_open_outlined),
      ('private', '私有 PT', privateCount, Icons.lock_outlined),
    ];

    final sortOptions = [
      (TorrentSortMode.smart, '智能综合', Icons.auto_awesome),
      (TorrentSortMode.seeders, '做种优先', Icons.arrow_upward),
      (TorrentSortMode.age, '发布时间', Icons.schedule),
      (TorrentSortMode.size, '文件体积', Icons.data_usage),
      (TorrentSortMode.leechers, '下载热度', Icons.arrow_downward),
      (TorrentSortMode.title, '资源名称', Icons.sort_by_alpha),
    ];

    return UnifiedFilterPanelContainer(
      panelKey: const Key('resource_search_filter_panel'),
      rows: [
        // 维度 1：分类 (cat)
        UnifiedFilterCategoryRow(
          categoryTitle: '分类 (cat)',
          categorySubtitle: '资源类型与协议',
          trailing: searchState.hasActiveFilter
              ? TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: notifier.resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: const Text('重置筛选', style: TextStyle(fontSize: 12)),
                )
              : null,
          chips: [
            for (final cat in TorrentCategory.values)
              UnifiedFilterChoiceChip(
                chipKey: ValueKey('category_chip_${cat.name}'),
                icon: _getCategoryIcon(cat),
                label: cat.label,
                count: cat == TorrentCategory.all
                    ? searchState.items.length
                    : (counts[cat] ?? 0),
                showCount: searchState.items.isNotEmpty &&
                    (cat == TorrentCategory.all || (counts[cat] ?? 0) > 0),
                isSelected: searchState.categoryFilter == cat,
                onSelected: () => notifier.setCategoryFilter(cat),
              ),
            UnifiedFilterChoiceChip(
              chipKey: const Key('resource_rule_chip_cardigann'),
              icon: Icons.downloading_outlined,
              label: 'Cardigann 规则',
              count: cardigannCount,
              showCount: searchState.items.isNotEmpty && cardigannCount > 0,
              isSelected: activeProtocol == 'cardigann',
              onSelected: () => notifier.setRuleProtocolFilter(
                activeProtocol == 'cardigann' ? 'all' : 'cardigann',
              ),
            ),
            UnifiedFilterChoiceChip(
              chipKey: const Key('resource_rule_chip_alist'),
              icon: Icons.cloud_outlined,
              label: 'AList 规则',
              count: alistCount,
              showCount: searchState.items.isNotEmpty && alistCount > 0,
              isSelected: activeProtocol == 'alist',
              onSelected: () => notifier.setRuleProtocolFilter(
                activeProtocol == 'alist' ? 'all' : 'alist',
              ),
            ),
          ],
        ),
        // 维度 2：性质 (type)
        UnifiedFilterCategoryRow(
          categoryTitle: '性质 (type)',
          categorySubtitle: '公开 / 半私有 / 私有 PT',
          chips: [
            for (final entry in types)
              UnifiedFilterChoiceChip(
                chipKey: ValueKey('tracker_type_chip_${entry.$1}'),
                icon: entry.$4,
                label: entry.$2,
                count: entry.$3,
                showCount: searchState.items.isNotEmpty && entry.$3 > 0,
                isSelected: currentType == entry.$1,
                onSelected: () => notifier.setTrackerTypeFilter(entry.$1),
              ),
          ],
        ),
        // 维度 3：站点 (indexer)
        if (indexerCounts.isNotEmpty)
          UnifiedFilterCategoryRow(
            categoryTitle: '站点 (indexer)',
            categorySubtitle: '索引源过滤',
            chips: [
              UnifiedFilterChoiceChip(
                chipKey: const Key('indexer_chip_all'),
                icon: Icons.hub_outlined,
                label: '全部站点',
                count: searchState.items.length,
                showCount: searchState.items.isNotEmpty,
                isSelected: currentIndexer == '全部',
                onSelected: () => notifier.setIndexerFilter(null),
              ),
              for (final entry in indexerCounts.entries)
                UnifiedFilterChoiceChip(
                  chipKey: ValueKey('indexer_chip_${entry.key}'),
                  icon: Icons.dns_outlined,
                  label: entry.key,
                  count: entry.value,
                  showCount: true,
                  isSelected: currentIndexer == entry.key,
                  onSelected: () => notifier.setIndexerFilter(
                    currentIndexer == entry.key ? null : entry.key,
                  ),
                ),
            ],
          ),
        // 维度 4：排序 (sort)
        UnifiedFilterCategoryRow(
          categoryTitle: '排序 (sort)',
          categorySubtitle: searchState.sortAscending ? '当前升序' : '当前降序',
          trailing: IconButton(
            tooltip: searchState.sortAscending
                ? '当前升序 (点击切换为降序)'
                : '当前降序 (点击切换为升序)',
            icon: Icon(
              searchState.sortAscending ? Icons.north : Icons.south,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => notifier.setSortMode(
              searchState.sortMode,
              ascending: !searchState.sortAscending,
            ),
          ),
          chips: [
            for (final entry in sortOptions)
              UnifiedFilterChoiceChip(
                chipKey: ValueKey('sort_chip_${entry.$1.name}'),
                icon: entry.$3,
                label: entry.$2,
                showCount: false,
                isSelected: searchState.sortMode == entry.$1,
                onSelected: () {
                  if (searchState.sortMode == entry.$1) {
                    notifier.setSortMode(
                      entry.$1,
                      ascending: !searchState.sortAscending,
                    );
                  } else {
                    notifier.setSortMode(entry.$1);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
