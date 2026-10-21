import 'dart:io';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/bean/widget/download_context_menu.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/pages/player/local_player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/modules/download/download_file_utils.dart';
import 'package:kazumi/pages/download/download_task_detail_dialog.dart';
import 'package:kazumi/pages/download/widgets/add_download_dialog.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage>
    with SingleTickerProviderStateMixin {
  static const Color xunleiBlue = Color(0xFF0A84FF);

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 5个标签：下载中、已暂停、已完成、下载失败、全部
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // 监听搜索框输入
    _searchController.addListener(() {
      ref
          .read(downloadPageUIProvider.notifier)
          .updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _playTask(BuildContext context, DownloadTask task) {
    if (!task.isPlayable) {
      KazumiDialog.showToast(message: '该文件不是音视频媒体文件，无法直接播放');
      return;
    }
    final path = task.filePath ?? task.fileName;
    if (path == null || path.isEmpty) {
      KazumiDialog.showToast(message: '未找到视频文件路径');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      KazumiDialog.showToast(message: '视频文件不存在: $path');
      return;
    }

    context.push(
      Routes.localPlayer,
      extra: LocalVideoPlayArgs(
        filePath: file.absolute.path,
        title: task.title,
        bangumiId: task.bangumiId,
        episode: task.episodeNumber,
      ),
    );
  }

  void _streamPlayTask(BuildContext context, DownloadTask task) {
    if (!task.isPlayable) {
      KazumiDialog.showToast(message: '非音视频文件不支持边下边播');
      return;
    }
    final path = task.filePath ?? task.fileName;
    if (path == null || path.isEmpty) {
      KazumiDialog.showToast(message: '正在分配本地空间与元数据，请稍候');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      KazumiDialog.showToast(message: '文件正在高速缓冲首部，请稍候点击');
      return;
    }

    if (task.completedLength < 10 * 1024 * 1024 && !task.isComplete) {
      KazumiDialog.showToast(
          message: '已缓冲 ${_formatFileSize(task.completedLength)}，正在加速首尾关键帧');
    }

    context.push(
      Routes.localPlayer,
      extra: LocalVideoPlayArgs(
        filePath: file.absolute.path,
        title: task.title,
        bangumiId: task.bangumiId,
        episode: task.episodeNumber,
      ),
    );
  }

  void _toggleSelectionMode() {
    ref.read(downloadPageUIProvider.notifier).toggleSelectionMode();
  }

  void _toggleSelection(String gid) {
    ref.read(downloadPageUIProvider.notifier).toggleSelection(gid);
  }

  void _selectAll(List<DownloadTask> tasks) {
    ref.read(downloadPageUIProvider.notifier).selectAll(tasks);
  }

  void _onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go('/tab/popular');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    return '${_formatFileSize(bytesPerSecond)}/s';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0秒';
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分${seconds % 60}秒';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (mins == 0) return '$hours小时';
    return '$hours小时$mins分';
  }

  void _showDeleteConfirmDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.app.delete),
        content: Text(t.downloads.page.dialog.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.app.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(t.app.delete),
          ),
        ],
      ),
    );
  }

  /// 构建 AppBar Actions
  List<Widget> _buildAppBarActions(DownloadController downloadController) {
    final uiState = ref.read(downloadPageUIProvider);
    if (uiState.isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: () {
            final allTasks = downloadController.getAllTasks();
            _selectAll(allTasks);
          },
          tooltip: t.downloads.page.actions.selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: uiState.selectedGids.isEmpty
              ? null
              : () {
                  downloadController
                      .resumeSelected(uiState.selectedGids.toList());
                  _toggleSelectionMode();
                },
          tooltip: t.downloads.page.actions.resume,
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: uiState.selectedGids.isEmpty
              ? null
              : () {
                  downloadController
                      .pauseSelected(uiState.selectedGids.toList());
                  _toggleSelectionMode();
                },
          tooltip: t.downloads.page.actions.pause,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: uiState.selectedGids.isEmpty
              ? null
              : () {
                  _showDeleteConfirmDialog(
                    context,
                    () {
                      downloadController
                          .deleteSelected(uiState.selectedGids.toList());
                      _toggleSelectionMode();
                    },
                  );
                },
          tooltip: t.downloads.page.actions.delete,
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            context.push('/settings/download');
          },
          tooltip: t.downloads.page.downloadSettings,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'pause_all':
                downloadController.pauseAll();
                break;
              case 'resume_all':
                downloadController.resumeAll();
                break;
              case 'clear_completed':
                downloadController.clearCompleted();
                break;
              case 'delete_all':
                _showDeleteConfirmDialog(
                  context,
                  () => downloadController.deleteAll(),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'resume_all',
              child: const Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: xunleiBlue),
                  SizedBox(width: 8),
                  Text('全部开始'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pause_all',
              child: const Row(
                children: [
                  Icon(Icons.pause_rounded),
                  SizedBox(width: 8),
                  Text('全部暂停'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear_completed',
              child: const Row(
                children: [
                  Icon(Icons.cleaning_services_outlined),
                  SizedBox(width: 8),
                  Text('清空已完成'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_all',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text('全部删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ];
    }
  }

  void _updateAppBarConfig() {
    if (!mounted) return;
    final uiState = ref.read(downloadPageUIProvider);
    final downloadController = ref.read(downloadControllerProvider.notifier);

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: uiState.isSelectionMode
          ? '已选择 ${uiState.selectedGids.length} 项'
          : '下载管理',
      needTopOffset: false,
      leading: uiState.isSelectionMode
          ? AppBackButton(
              icon: Icons.close,
              tooltip: '取消选择',
              onPressed: _toggleSelectionMode,
            )
          : null,
      actions: _buildAppBarActions(downloadController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadControllerProvider);
    final downloadController = ref.read(downloadControllerProvider.notifier);
    final uiState = ref.watch(downloadPageUIProvider);

    // 初始化时设置 AppBar
    Future.microtask(() {
      if (mounted) {
        _updateAppBarConfig();
      }
    });

    // 响应式更新 AppBar
    ref.listen<DownloadPageUIState>(downloadPageUIProvider, (previous, next) {
      if (previous?.isSelectionMode != next.isSelectionMode ||
          previous?.selectedGids.length != next.selectedGids.length) {
        _updateAppBarConfig();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _onBackPressed(context);
      },
      child: Stack(
        children: [
          Column(
            children: [
              if (downloadState.errorMessage != null)
                Builder(
                  builder: (context) {
                    final isStarting =
                        downloadState.errorMessage!.contains('启动中');
                    final theme = Theme.of(context);
                    final bgColor = isStarting
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.errorContainer;
                    final fgColor = isStarting
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onErrorContainer;
                    final icon = isStarting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fgColor,
                            ),
                          )
                        : Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 18,
                          );

                    return Container(
                      width: double.infinity,
                      color: bgColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          icon,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              downloadState.errorMessage!,
                              style: TextStyle(color: fgColor, fontSize: 13),
                            ),
                          ),
                          if (isStarting)
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(downloadControllerProvider.notifier)
                                    .refreshDownloads();
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: Text('立即重连',
                                  style:
                                      TextStyle(color: fgColor, fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              // 1. 迅雷经典风格顶部工具栏
              _buildXunleiToolbar(context, downloadState, downloadController),
              // 2. 实时全局统计信息面板（总下载速度、总上传速度、正在下载数、预计剩余时间）
              _buildGlobalStatsBanner(context, downloadState),
              // 3. 5分类标签栏（下载中、已暂停、已完成、下载失败、全部，带任务数量Badge）
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: xunleiBlue,
                  indicatorColor: xunleiBlue,
                  indicatorWeight: 3,
                  tabs: [
                    _buildTabItem(
                      '下载中',
                      downloadState.totalDownloading,
                      badgeColor: xunleiBlue,
                    ),
                    _buildTabItem(
                      '已暂停',
                      downloadState.totalPaused,
                      badgeColor: const Color(0xFFFFA000),
                    ),
                    _buildTabItem(
                      '已完成',
                      downloadState.totalCompleted,
                      badgeColor: const Color(0xFF4CAF50),
                    ),
                    _buildTabItem(
                      '下载失败',
                      downloadState.totalFailed,
                      badgeColor: const Color(0xFFE53935),
                    ),
                    _buildTabItem(
                      '全部',
                      downloadState.totalAll,
                      badgeColor: const Color(0xFF78909C),
                    ),
                  ],
                ),
              ),
              // 4. 任务列表内容视图
              Expanded(
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: [
                        // 下载中 Tab
                        _buildDownloadingList(
                          context,
                          downloadState,
                          downloadController,
                        ),
                        // 已暂停 Tab
                        _buildPausedList(
                          context,
                          downloadState,
                          downloadController,
                        ),
                        // 已完成 Tab
                        _buildCompletedList(
                          context,
                          downloadState,
                          downloadController,
                        ),
                        // 下载失败 Tab
                        _buildFailedList(
                          context,
                          downloadState,
                          downloadController,
                        ),
                        // 全部 Tab
                        _buildAllList(
                          context,
                          downloadState,
                          downloadController,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // FloatingActionButton (移动端快捷按钮)
          if (!uiState.isSelectionMode)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddDownloadDialog(),
                  );
                },
                backgroundColor: xunleiBlue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('新建下载'),
                tooltip: '新建下载任务',
              ),
            ),
        ],
      ),
    );
  }

  /// 迅雷风格经典顶部工具栏
  Widget _buildXunleiToolbar(
    BuildContext context,
    DownloadState downloadState,
    DownloadController downloadController,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;
          return Column(
            children: [
              if (isNarrow) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 醒目的新建下载按钮 (迅雷蓝高亮)
                      FilledButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const AddDownloadDialog(),
                          );
                        },
                        icon: const Icon(Icons.add_rounded,
                            size: 20, color: Colors.white),
                        label: const Text(
                          '新建',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: xunleiBlue,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          shadowColor: xunleiBlue.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 全部开始
                      OutlinedButton.icon(
                        onPressed: downloadState.totalPaused > 0
                            ? () => downloadController.resumeAll()
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('开始'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 全部暂停
                      OutlinedButton.icon(
                        onPressed: downloadState.totalDownloading > 0
                            ? () => downloadController.pauseAll()
                            : null,
                        icon: const Icon(Icons.pause_rounded, size: 18),
                        label: const Text('暂停'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 清空已完成
                      OutlinedButton.icon(
                        onPressed: downloadState.totalCompleted > 0
                            ? () => downloadController.clearCompleted()
                            : null,
                        icon:
                            const Icon(Icons.cleaning_services_outlined, size: 16),
                        label: const Text('清空'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 排序下拉
                      _buildSortDropdownButton(context, uiState),
                      const SizedBox(width: 4),
                      // 批量管理
                      IconButton(
                        icon: Icon(
                          uiState.isSelectionMode
                              ? Icons.checklist_rtl
                              : Icons.checklist_rounded,
                          color: uiState.isSelectionMode ? xunleiBlue : null,
                        ),
                        tooltip: '批量管理',
                        onPressed: _toggleSelectionMode,
                      ),
                      // 刷新
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: '刷新列表',
                        onPressed: () => downloadController.refreshDownloads(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: _buildSearchTextField(theme, uiState),
                ),
              ] else ...[
                Row(
                  children: [
                    // 醒目的新建下载按钮 (迅雷蓝高亮)
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const AddDownloadDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded,
                          size: 20, color: Colors.white),
                      label: const Text(
                        '新建下载',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: xunleiBlue,
                        foregroundColor: Colors.white,
                        elevation: 1.5,
                        shadowColor: xunleiBlue.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 全部开始
                    OutlinedButton.icon(
                      onPressed: downloadState.totalPaused > 0
                          ? () => downloadController.resumeAll()
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('全部开始'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 全部暂停
                    OutlinedButton.icon(
                      onPressed: downloadState.totalDownloading > 0
                          ? () => downloadController.pauseAll()
                          : null,
                      icon: const Icon(Icons.pause_rounded, size: 18),
                      label: const Text('全部暂停'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 清空已完成
                    OutlinedButton.icon(
                      onPressed: downloadState.totalCompleted > 0
                          ? () => downloadController.clearCompleted()
                          : null,
                      icon:
                          const Icon(Icons.cleaning_services_outlined, size: 16),
                      label: const Text('清空已完成'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                    const Spacer(),
                    // 宽屏模式下将搜索框并列于工具栏
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: _buildSearchTextField(theme, uiState),
                    ),
                    const SizedBox(width: 8),
                    // 排序下拉
                    _buildSortDropdownButton(context, uiState),
                    const SizedBox(width: 4),
                    // 批量管理
                    IconButton(
                      icon: Icon(
                        uiState.isSelectionMode
                            ? Icons.checklist_rtl
                            : Icons.checklist_rounded,
                        color: uiState.isSelectionMode ? xunleiBlue : null,
                      ),
                      tooltip: '批量管理',
                      onPressed: _toggleSelectionMode,
                    ),
                    // 刷新
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: '刷新列表',
                      onPressed: () => downloadController.refreshDownloads(),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchTextField(ThemeData theme, DownloadPageUIState uiState) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        isDense: true,
        hintText: '搜索任务或文件名...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: uiState.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  ref.read(downloadPageUIProvider.notifier).clearSearch();
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildSortDropdownButton(
      BuildContext context, DownloadPageUIState uiState) {
    final notifier = ref.read(downloadPageUIProvider.notifier);
    String sortLabel;
    switch (uiState.sortBy) {
      case 'name':
        sortLabel = '按名称';
        break;
      case 'size':
        sortLabel = '按大小';
        break;
      case 'speed':
        sortLabel = '按速度';
        break;
      case 'progress':
        sortLabel = '按进度';
        break;
      case 'created':
      default:
        sortLabel = '按时间';
        break;
    }

    return PopupMenuButton<String>(
      tooltip: '排序方式',
      onSelected: (value) {
        if (uiState.sortBy == value) {
          notifier.updateSort(value, ascending: !uiState.sortAscending);
        } else {
          notifier.updateSort(value, ascending: false);
        }
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(context, uiState, 'created', '按创建时间'),
        _buildSortMenuItem(context, uiState, 'name', '按文件名称'),
        _buildSortMenuItem(context, uiState, 'size', '按文件大小'),
        _buildSortMenuItem(context, uiState, 'speed', '按下载速度'),
        _buildSortMenuItem(context, uiState, 'progress', '按下载进度'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18),
            const SizedBox(width: 4),
            Text(
              sortLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 2),
            Icon(
              uiState.sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: xunleiBlue,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
    BuildContext context,
    DownloadPageUIState uiState,
    String value,
    String label,
  ) {
    final isSelected = uiState.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            Icon(
              uiState.sortAscending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
              color: xunleiBlue,
            ),
          if (isSelected) const SizedBox(width: 6),
          Text(
            label,
            style: isSelected
                ? const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: xunleiBlue,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// 迅雷风格实时统计信息面板
  Widget _buildGlobalStatsBanner(BuildContext context, DownloadState state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 实时总下载速度
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: xunleiBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: xunleiBlue,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '总下载: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatSpeed(state.totalDownloadSpeed),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: xunleiBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            // 实时总上传速度
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 14,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '总上传: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatSpeed(state.totalUploadSpeed),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            // 正在下载数
            Row(
              children: [
                Icon(
                  Icons.downloading_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '下载中: ${state.totalDownloading}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            // 预计剩余时间
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  state.estimatedRemainingSeconds > 0
                      ? '预计剩余: ${_formatDuration(state.estimatedRemainingSeconds)}'
                      : '预计剩余: --',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            // 已完成数
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '已完成: ${state.totalCompleted}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 带数量 Badge 的 TabBar 项
  Widget _buildTabItem(String title, int count, {Color? badgeColor}) {
    final theme = Theme.of(context);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: count > 0
                  ? (badgeColor ?? xunleiBlue)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: count > 0
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 280;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 12 : 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 14 : 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: isCompact ? 36 : 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 20),
                    Text(
                      title,
                      style: (isCompact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadingList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = [...state.activeTasks, ...state.waitingTasks];

    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isDownloading)
          .toList();
    }

    tasks = controller.sortTasks(tasks, uiState.sortBy,
        ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.downloading,
        title: uiState.searchQuery.isNotEmpty
            ? '未找到匹配的下载中任务'
            : t.downloads.page.empty.downloading,
        subtitle: uiState.searchQuery.isNotEmpty
            ? ''
            : t.downloads.page.empty.hint,
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildDownloadItem(context, task, controller, isActive: true);
      },
    );
  }

  Widget _buildPausedList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = List<DownloadTask>.from(state.pausedTasks);

    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isPaused)
          .toList();
    }

    tasks = controller.sortTasks(tasks, uiState.sortBy,
        ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.pause_circle_outline,
        title: uiState.searchQuery.isNotEmpty ? '未找到匹配的已暂停任务' : '没有已暂停的任务',
        subtitle: uiState.searchQuery.isNotEmpty ? '' : '暂停的下载任务会显示在这里',
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildDownloadItem(context, task, controller, isActive: false);
      },
    );
  }

  Widget _buildCompletedList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = List<DownloadTask>.from(state.completedTasks);

    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isComplete)
          .toList();
    }

    tasks = controller.sortTasks(tasks, uiState.sortBy,
        ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.check_circle_outline,
        title: uiState.searchQuery.isNotEmpty
            ? '未找到匹配的已完成任务'
            : t.downloads.page.empty.completed,
        subtitle: uiState.searchQuery.isNotEmpty
            ? ''
            : t.downloads.page.empty.hint,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '共 ${tasks.length} 项已完成',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                TextButton.icon(
                  onPressed: () => controller.clearCompleted(),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: const Text('清空全部已完成'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildDownloadItem(context, task, controller,
                  isActive: false);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFailedList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = List<DownloadTask>.from(state.failedTasks);

    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isError)
          .toList();
    }

    tasks = controller.sortTasks(tasks, uiState.sortBy,
        ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.check_circle_outline,
        title: uiState.searchQuery.isNotEmpty ? '未找到匹配的失败任务' : '没有下载失败的任务',
        subtitle: uiState.searchQuery.isNotEmpty
            ? ''
            : '若有链接失效或鉴权失败任务会清晰汇总在此',
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildDownloadItem(context, task, controller, isActive: false);
      },
    );
  }

  Widget _buildAllList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var allTasks = controller.getAllTasks();

    if (uiState.searchQuery.isNotEmpty) {
      allTasks = controller.searchTasks(uiState.searchQuery);
    }

    allTasks = controller.sortTasks(allTasks, uiState.sortBy,
        ascending: uiState.sortAscending);

    if (allTasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.inbox_outlined,
        title: uiState.searchQuery.isNotEmpty
            ? '未找到匹配的下载任务'
            : t.downloads.page.empty.all,
        subtitle: uiState.searchQuery.isNotEmpty
            ? ''
            : t.downloads.page.empty.hint,
      );
    }

    return ListView.builder(
      itemCount: allTasks.length,
      itemBuilder: (context, index) {
        final task = allTasks[index];
        return _buildDownloadItem(
          context,
          task,
          controller,
          isActive: task.isDownloading,
        );
      },
    );
  }

  /// 区分文件类型图标与彩色背景
  IconData _getFileIcon(DownloadTask task) {
    if (task.isVideo) return Icons.movie_outlined;
    if (task.isAudio) return Icons.music_note_outlined;
    if (task.isArchive) return Icons.folder_zip_outlined;
    if (task.isInstaller) return Icons.install_desktop_outlined;
    if (task.isDocument) return Icons.description_outlined;
    if (task.isTorrent) return Icons.hub_outlined;
    return Icons.insert_drive_file_outlined;
  }

  /// 区分文件类型主题色
  Color _getFileTypeColor(DownloadTask task) {
    if (task.isVideo) return const Color(0xFF0A84FF); // 视频蓝色
    if (task.isAudio) return const Color(0xFF9C27B0); // 音频紫色
    if (task.isArchive) return const Color(0xFFFF9800); // 压缩包琥珀/橙色
    if (task.isInstaller) return const Color(0xFF009688); // 安装包青色
    if (task.isDocument) return const Color(0xFF3F51B5); // 文档靛蓝
    if (task.isTorrent) return const Color(0xFFFF5722); // 种子深橙
    return const Color(0xFF607D8B); // 其它
  }

  /// 提取彩色角标文本标签
  String _getFileTypeTag(DownloadTask task) {
    final ext = task.fileExtension;
    if (ext.isNotEmpty) {
      return ext.replaceFirst('.', '').toUpperCase();
    }
    return task.fileTypeDisplay;
  }

  /// 迅雷风格的任务卡片
  Widget _buildDownloadItem(
    BuildContext context,
    DownloadTask task,
    DownloadController controller, {
    required bool isActive,
  }) {
    final uiState = ref.watch(downloadPageUIProvider);
    final theme = Theme.of(context);
    final isSelected = uiState.selectedGids.contains(task.gid);
    final typeColor = _getFileTypeColor(task);
    final typeTag = _getFileTypeTag(task);

    final cardWidget = Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      elevation: isSelected ? 3 : 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: xunleiBlue, width: 2)
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 0.8,
              ),
      ),
      color: isSelected
          ? xunleiBlue.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: uiState.isSelectionMode
            ? () => _toggleSelection(task.gid)
            : () {
                showDialog(
                  context: context,
                  builder: (context) => DownloadTaskDetailDialog(
                    task: task,
                    onRetry: (task.isError || task.isRemoved)
                        ? () async {
                            await controller.retryDownload(task);
                            if (context.mounted) {
                              KazumiDialog.showToast(
                                  message: t.downloads.page.toast.retrying);
                            }
                          }
                        : null,
                    onOpenFile: (task.isComplete || task.isRemoved) && task.isPlayable
                        ? () => _playTask(context, task)
                        : null,
                  ),
                );
              },
        onLongPress: !uiState.isSelectionMode
            ? () {
                _toggleSelectionMode();
                _toggleSelection(task.gid);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：多选复选框、文件图标、彩色角标与文件名、状态Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (uiState.isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: xunleiBlue,
                      onChanged: (value) => _toggleSelection(task.gid),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 文件类型大图标 (带背景)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        _getFileIcon(task),
                        color: typeColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 彩色角标 + 任务标题 + 路径
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 彩色角标 Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: typeColor.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                typeTag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 文件标题
                            Expanded(
                              child: Text(
                                task.displayTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (task.fileName != null &&
                            task.fileName != task.displayTitle) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.fileName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(context, task),
                ],
              ),
              const SizedBox(height: 12),

              // 中部：下载进度条或状态详情
              if (isActive || task.isPaused) ...[
                // 迅雷风格进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.isPaused ? const Color(0xFFFFA000) : xunleiBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // 已下载 / 总大小
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.data_usage_rounded,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatFileSize(task.completedLength)} / ${_formatFileSize(task.totalLength)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // 进度百分比
                    Text(
                      '${(task.progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: task.isPaused
                            ? const Color(0xFFFFA000)
                            : xunleiBlue,
                      ),
                    ),
                    // 速度与剩余时间各项平铺至 Wrap，避免极窄设备（如 320px）横向溢出
                    if (task.isActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: xunleiBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 12,
                              color: xunleiBlue,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatSpeed(task.downloadSpeed),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: xunleiBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (task.uploadSpeed > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 12,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatSpeed(task.uploadSpeed),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (task.downloadSpeed > 0)
                        Text(
                          '剩余 ${_formatDuration((task.totalLength - task.completedLength) ~/ task.downloadSpeed)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                    ] else if (task.isPaused) ...[
                      Text(
                        '已暂停',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (task.isComplete) ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storage_rounded,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '文件大小: ${_formatFileSize(task.totalLength)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '完成时间: ${task.updatedAt.month}月${task.updatedAt.day}日 ${task.updatedAt.hour.toString().padLeft(2, '0')}:${task.updatedAt.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else if (task.isError) ...[
                // 失败或直链鉴权失效提示栏
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        task.isRedirectOrAuthError
                            ? Icons.warning_amber_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.errorMessage ?? task.readableErrorMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (task.isRedirectOrAuthError) ...[
                              const SizedBox(height: 2),
                              Text(
                                '提示：目标文件获取到的实际是网页或鉴权错误，未获得真实资源。可点击右侧重新配置，填写 Cookie / Referer 重新下载。',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.error
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 底部操作区 (严格遵守非媒体文件严禁播放或边下边播规则)
              if (!uiState.isSelectionMode) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // 已完成状态下的按钮
                    if (task.isComplete) ...[
                      // 真正为音视频文件时才显示播放按钮
                      if (task.isPlayable) ...[
                        FilledButton.icon(
                          onPressed: () => _playTask(context, task),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('播放'),
                          style: FilledButton.styleFrom(
                            backgroundColor: xunleiBlue,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 严禁对 RAR、ZIP、7Z、ISO、EXE 等非媒体文件显示播放，只显示“打开文件”
                      if (!task.isPlayable) ...[
                        FilledButton.icon(
                          onPressed: () => DownloadFileUtils.openFile(
                              task.filePath ?? task.fileName),
                          icon: const Icon(Icons.file_open_rounded, size: 16),
                          label: const Text('打开文件'),
                          style: FilledButton.styleFrom(
                            backgroundColor: xunleiBlue,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 打开所在文件夹
                      OutlinedButton.icon(
                        onPressed: () => DownloadFileUtils.openContainingFolder(
                            task.filePath ?? task.fileName),
                        icon:
                            const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('打开文件夹'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ]
                    // 下载中状态下的按钮
                    else if (task.isActive) ...[
                      // 仅在真正为媒体文件时才支持“边下边播”
                      if (task.isPlayable) ...[
                        FilledButton.tonalIcon(
                          onPressed: () => _streamPlayTask(context, task),
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 18),
                          label: const Text('边下边播'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => controller.pauseDownload(task.gid),
                        icon: const Icon(Icons.pause_rounded, size: 18),
                        label: const Text('暂停'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ]
                    // 已暂停状态下的按钮
                    else if (task.isPaused) ...[
                      FilledButton.icon(
                        onPressed: () => controller.resumeDownload(task.gid),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('继续'),
                        style: FilledButton.styleFrom(
                          backgroundColor: xunleiBlue,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ]
                    // 下载失败或已取消状态下的按钮
                    else if (task.isError || task.isRemoved) ...[
                      FilledButton.icon(
                        onPressed: () => controller.retryDownload(task),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(task.isRemoved ? '重新下载' : '重试'),
                        style: FilledButton.styleFrom(
                          backgroundColor: xunleiBlue,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (task.isRedirectOrAuthError) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AddDownloadDialog(
                                initialUrl: task.url,
                                initialFileName: task.fileName,
                              ),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('重新配置'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                    // 删除按钮
                    IconButton(
                      onPressed: () =>
                          controller.removeDownload(task.gid, force: true),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      tooltip: '删除任务',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return AppContextMenu(
      enableLongPress: false,
      itemsBuilder: (context) => _buildTaskContextMenuItems(
        context,
        task,
        controller,
        isActive: isActive,
      ),
      child: cardWidget,
    );
  }

  /// 桌面端与移动端统一右键/长按菜单构建器
  List<AppMenuItem> _buildTaskContextMenuItems(
    BuildContext context,
    DownloadTask task,
    DownloadController controller, {
    required bool isActive,
  }) {
    return DownloadContextMenuHelper.buildMenuItems(
      context: context,
      ref: ref,
      task: task,
      controller: controller,
      isActive: isActive,
      onPlay: () => _playTask(context, task),
      onStreamPlay: () => _streamPlayTask(context, task),
      onToggleSelectionMode: _toggleSelectionMode,
      onToggleSelection: _toggleSelection,
      showDeleteConfirmDialog: _showDeleteConfirmDialog,
    );
  }

  Widget _buildStatusChip(BuildContext context, DownloadTask task) {
    Color backgroundColor;
    Color foregroundColor;
    String label;

    if (task.isActive) {
      backgroundColor = xunleiBlue.withValues(alpha: 0.15);
      foregroundColor = xunleiBlue;
      label = task.downloadSpeed > 0
          ? _formatSpeed(task.downloadSpeed)
          : '下载中';
    } else if (task.isWaiting) {
      backgroundColor = const Color(0xFFFFA000).withValues(alpha: 0.15);
      foregroundColor = const Color(0xFFFFA000);
      label = '等待中';
    } else if (task.isPaused) {
      backgroundColor = Colors.grey.withValues(alpha: 0.15);
      foregroundColor = Colors.grey.shade700;
      label = '已暂停';
    } else if (task.isComplete) {
      backgroundColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      foregroundColor = const Color(0xFF2E7D32);
      label = '已完成';
    } else if (task.isError) {
      backgroundColor = Theme.of(context).colorScheme.errorContainer;
      foregroundColor = Theme.of(context).colorScheme.onErrorContainer;
      label = task.isRedirectOrAuthError ? '鉴权失效' : '失败';
    } else if (task.isRemoved) {
      backgroundColor = Colors.blueGrey.withValues(alpha: 0.15);
      foregroundColor = Colors.blueGrey.shade700;
      label = '已取消';
    } else {
      backgroundColor =
          Theme.of(context).colorScheme.surfaceContainerHighest;
      foregroundColor = Theme.of(context).colorScheme.onSurface;
      label = task.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
