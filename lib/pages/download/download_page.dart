import 'dart:io';
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
import 'package:kazumi/pages/download/download_task_detail_dialog.dart';
import 'package:kazumi/pages/download/widgets/add_download_dialog.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage>
    with SingleTickerProviderStateMixin {
  void _playTask(BuildContext context, DownloadTask task) {
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
      KazumiDialog.showToast(message: '已缓冲 ${_formatFileSize(task.completedLength)}，正在加速首尾关键帧');
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

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 监听搜索框输入
    _searchController.addListener(() {
      ref.read(downloadPageUIProvider.notifier)
        .updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
      final downloadState = ref.read(downloadControllerProvider);
      return [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: () {
            final allTasks = [
              ...downloadState.activeTasks,
              ...downloadState.waitingTasks,
              ...downloadState.completedTasks,
            ];
            _selectAll(allTasks);
          },
          tooltip: t.downloads.page.actions.selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: uiState.selectedGids.isEmpty
              ? null
              : () {
                  downloadController.resumeSelected(uiState.selectedGids.toList());
                  _toggleSelectionMode();
                },
          tooltip: t.downloads.page.actions.resume,
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: uiState.selectedGids.isEmpty
              ? null
              : () {
                  downloadController.pauseSelected(uiState.selectedGids.toList());
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
                      downloadController.deleteSelected(uiState.selectedGids.toList());
                      _toggleSelectionMode();
                    },
                  );
                },
          tooltip: t.downloads.page.actions.delete,
        ),
      ];
    } else {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(t.downloads.page.newDownload),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const AddDownloadDialog(),
            );
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.checklist),
          onPressed: _toggleSelectionMode,
          tooltip: t.downloads.page.batchManage,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            context.push('/settings/download');
          },
          tooltip: t.downloads.page.downloadSettings,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            downloadController.refreshDownloads();
          },
          tooltip: t.downloads.page.refresh,
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
              value: 'pause_all',
              child: Row(
                children: [
                  Icon(Icons.pause),
                  SizedBox(width: 8),
                  Text(t.downloads.page.actions.pauseAll),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'resume_all',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text(t.downloads.page.actions.resumeAll),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear_completed',
              child: Row(
                children: [
                  Icon(Icons.clear_all),
                  SizedBox(width: 8),
                  Text(t.downloads.page.actions.clearCompleted),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete_all',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text(t.downloads.page.actions.deleteAll,
                      style: TextStyle(color: Colors.red)),
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
    final t = context.t;
    final uiState = ref.read(downloadPageUIProvider);
    final downloadController = ref.read(downloadControllerProvider.notifier);

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: uiState.isSelectionMode
          ? t.downloads.page.selectedItems(count: uiState.selectedGids.length)
          : t.downloads.page.title,
      needTopOffset: false,
      leading: uiState.isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
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

    // 使用 ref.listen 响应式更新 AppBar
    ref.listen<DownloadPageUIState>(downloadPageUIProvider, (previous, next) {
      if (previous?.isSelectionMode != next.isSelectionMode ||
          previous?.selectedGids.length != next.selectedGids.length) {
        _updateAppBarConfig();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _onBackPressed(context);
      },
      child: Stack(
        children: [
          Column(
            children: [
              if (downloadState.errorMessage != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          downloadState.errorMessage!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // TabBar
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      text: t.downloads.page.tabs
                          .downloading(count: downloadState.totalDownloading),
                    ),
                    Tab(
                      text: t.downloads.page.tabs
                          .completed(count: downloadState.totalCompleted),
                    ),
                    Tab(
                      text: t.downloads.page.tabs.all,
                    ),
                  ],
                ),
              ),
              // Statistics banner (only show when downloading)
              if (downloadState.isConnected &&
                  downloadState.totalDownloading > 0)
                _buildStatisticsBanner(context, downloadState),
              // Search and sort options
              _buildSearchAndSort(context, downloadController),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Downloading tab
                    _buildDownloadingList(
                      context,
                      downloadState,
                      downloadController,
                    ),
                    // Completed tab
                    _buildCompletedList(
                      context,
                      downloadState,
                      downloadController,
                    ),
                    // All tab
                    _buildAllList(
                      context,
                      downloadState,
                      downloadController,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // FloatingActionButton
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
                icon: const Icon(Icons.add),
                label: Text(t.downloads.page.newDownload),
                tooltip: t.downloads.page.newDownload,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBanner(BuildContext context, DownloadState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.download,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatSpeed(state.totalDownloadSpeed),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.task_alt,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.downloads.page.statistics
                          .tasks(count: state.totalDownloading),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
                if (state.estimatedRemainingSeconds > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.downloads.page.statistics.eta(
                            time: _formatDuration(
                                state.estimatedRemainingSeconds)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort(
      BuildContext context, DownloadController controller) {
    final uiState = ref.watch(downloadPageUIProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: t.downloads.page.search.placeholder,
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: uiState.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(downloadPageUIProvider.notifier).clearSearch();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  // TextController listener 会自动更新 Provider
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.sort,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              tooltip: t.downloads.page.sort.label,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                final notifier = ref.read(downloadPageUIProvider.notifier);
                final currentState = ref.read(downloadPageUIProvider);
                if (currentState.sortBy == value) {
                  notifier.updateSort(value, ascending: !currentState.sortAscending);
                } else {
                  notifier.updateSort(value, ascending: false);
                }
              },
              itemBuilder: (context) => [
                _buildSortMenuItem(
                    context, uiState, 'created', t.downloads.page.sort.created),
                _buildSortMenuItem(context, uiState, 'name', t.downloads.page.sort.name),
                _buildSortMenuItem(context, uiState, 'size', t.downloads.page.sort.size),
                _buildSortMenuItem(
                    context, uiState, 'speed', t.downloads.page.sort.speed),
                _buildSortMenuItem(
                    context, uiState, 'progress', t.downloads.page.sort.progress),
              ],
            ),
          ),
        ],
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
              uiState.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            ),
          if (isSelected) const SizedBox(width: 4),
          Text(
            label,
            style: isSelected
                ? TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    if (seconds < 3600) return '${seconds ~/ 60} 分钟';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (mins == 0) return '$hours 小时';
    return '$hours 小时 $mins 分钟';
  }

  IconData _getTaskIcon(DownloadTask task) {
    if (task.isActive) return Icons.downloading;
    if (task.isWaiting) return Icons.schedule;
    if (task.isPaused) return Icons.pause_circle;
    if (task.isComplete) return Icons.check_circle;
    if (task.isError) return Icons.error;
    return Icons.file_download;
  }

  Color _getStatusColor(BuildContext context, DownloadTask task) {
    if (task.isActive) return Theme.of(context).colorScheme.primary;
    if (task.isWaiting) return Theme.of(context).colorScheme.secondary;
    if (task.isPaused) return Theme.of(context).colorScheme.tertiary;
    if (task.isComplete) return Colors.green;
    if (task.isError) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.outline;
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadingList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = [...state.activeTasks, ...state.waitingTasks];

    // Apply search
    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isDownloading)
          .toList();
    }

    // Apply sort
    tasks = controller.sortTasks(tasks, uiState.sortBy, ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.downloading,
        title: uiState.searchQuery.isNotEmpty
            ? t.downloads.page.empty.downloading
            : t.downloads.page.empty.downloading,
        subtitle: uiState.searchQuery.isNotEmpty ? '' : t.downloads.page.empty.hint,
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

  Widget _buildCompletedList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var tasks = List<DownloadTask>.from(state.completedTasks);

    // Apply search
    if (uiState.searchQuery.isNotEmpty) {
      tasks = controller
          .searchTasks(uiState.searchQuery)
          .where((t) => t.isComplete || t.isError)
          .toList();
    }

    // Apply sort
    tasks = controller.sortTasks(tasks, uiState.sortBy, ascending: uiState.sortAscending);

    if (tasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.check_circle_outline,
        title: uiState.searchQuery.isNotEmpty
            ? t.downloads.page.empty.completed
            : t.downloads.page.empty.completed,
        subtitle: uiState.searchQuery.isNotEmpty ? '' : t.downloads.page.empty.hint,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  controller.clearCompleted();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('清除全部'),
              ),
            ],
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

  Widget _buildAllList(
    BuildContext context,
    DownloadState state,
    DownloadController controller,
  ) {
    final uiState = ref.watch(downloadPageUIProvider);
    var allTasks = [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.completedTasks,
    ];

    // Apply search
    if (uiState.searchQuery.isNotEmpty) {
      allTasks = controller.searchTasks(uiState.searchQuery);
    }

    // Apply sort
    allTasks =
        controller.sortTasks(allTasks, uiState.sortBy, ascending: uiState.sortAscending);

    if (allTasks.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.inbox_outlined,
        title: uiState.searchQuery.isNotEmpty
            ? t.downloads.page.empty.all
            : t.downloads.page.empty.all,
        subtitle: uiState.searchQuery.isNotEmpty ? '' : t.downloads.page.empty.hint,
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

  Widget _buildDownloadItem(
    BuildContext context,
    DownloadTask task,
    DownloadController controller, {
    required bool isActive,
  }) {
    final uiState = ref.watch(downloadPageUIProvider);
    final isSelected = uiState.selectedGids.contains(task.gid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: uiState.isSelectionMode
            ? () => _toggleSelection(task.gid)
            : () {
                // Show detail dialog when not in selection mode
                showDialog(
                  context: context,
                  builder: (context) => DownloadTaskDetailDialog(
                    task: task,
                    onRetry: task.isError
                        ? () async {
                            await controller.retryDownload(task);
                            if (context.mounted) {
                              KazumiDialog.showToast(
                                  message: t.downloads.page.toast.retrying);
                            }
                          }
                        : null,
                    onOpenFile: task.isComplete && task.fileName != null
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (uiState.isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelection(task.gid),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // File icon based on status
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(context, task).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTaskIcon(task),
                      color: _getStatusColor(context, task),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.fileName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.fileName!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
              if (isActive) ...[
                // Progress bar with percentage
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(context, task),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.data_usage,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatFileSize(task.completedLength)} / ${_formatFileSize(task.totalLength)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${(task.progress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatSpeed(task.downloadSpeed),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else if (task.isComplete) ...[
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '大小: ${_formatFileSize(task.totalLength)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ] else if (task.isError && task.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.errorMessage!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!uiState.isSelectionMode) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (task.isComplete) ...[
                      FilledButton.icon(
                        onPressed: () => _playTask(context, task),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('播放'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (task.isActive || task.isPaused) ...[
                      FilledButton.tonalIcon(
                        onPressed: () => _streamPlayTask(context, task),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('边下边播'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (task.isActive)
                      TextButton.icon(
                        onPressed: () => controller.pauseDownload(task.gid),
                        icon: const Icon(Icons.pause),
                        label: Text(t.downloads.page.actions.pause),
                      ),
                    if (task.isPaused)
                      TextButton.icon(
                        onPressed: () => controller.resumeDownload(task.gid),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(t.downloads.page.actions.resume),
                      ),
                    if (task.isError)
                      TextButton.icon(
                        onPressed: () => controller.resumeDownload(task.gid),
                        icon: const Icon(Icons.refresh),
                        label: Text(t.downloads.page.actions.retry),
                      ),
                    TextButton.icon(
                      onPressed: () =>
                          controller.removeDownload(task.gid, force: true),
                      icon: const Icon(Icons.delete),
                      label: Text(t.downloads.page.actions.delete),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, DownloadTask task) {
    Color backgroundColor;
    Color foregroundColor;
    String label;

    if (task.isActive) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      foregroundColor = Theme.of(context).colorScheme.onPrimaryContainer;
      label = t.downloads.page.status.active;
    } else if (task.isWaiting) {
      backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
      foregroundColor = Theme.of(context).colorScheme.onSecondaryContainer;
      label = t.downloads.page.status.waiting;
    } else if (task.isPaused) {
      backgroundColor = Theme.of(context).colorScheme.tertiaryContainer;
      foregroundColor = Theme.of(context).colorScheme.onTertiaryContainer;
      label = t.downloads.page.status.paused;
    } else if (task.isComplete) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      foregroundColor = Theme.of(context).colorScheme.onPrimaryContainer;
      label = t.downloads.page.status.complete;
    } else if (task.isError) {
      backgroundColor = Theme.of(context).colorScheme.errorContainer;
      foregroundColor = Theme.of(context).colorScheme.onErrorContainer;
      label = t.downloads.page.status.error;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      foregroundColor = Theme.of(context).colorScheme.onSurface;
      label = task.status;
    }

    return Chip(
      label: Text(label),
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(
        color: foregroundColor,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
