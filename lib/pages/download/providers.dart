import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/utils/aria2_websocket.dart';

/// 下载控制器 Provider
final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(
  DownloadController.new,
);

/// Aria2 WebSocket 事件流 Provider
/// 用于实时监听下载事件
final aria2EventStreamProvider = StreamProvider<Aria2EventData>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  return controller.eventStream;
});

/// Aria2 连接状态流 Provider
/// 实时监听 WebSocket 连接状态变化
final aria2ConnectionStreamProvider =
    StreamProvider<Aria2ConnectionState>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  return controller.connectionStateStream;
});

/// 下载页面 UI 状态
class DownloadPageUIState {
  final bool isSelectionMode;
  final Set<String> selectedGids;
  final String searchQuery;
  final String sortBy; // created, name, size, speed, progress
  final bool sortAscending;
  final String filterType; // all, video, audio, archive, installer, document

  const DownloadPageUIState({
    this.isSelectionMode = false,
    this.selectedGids = const {},
    this.searchQuery = '',
    this.sortBy = 'created',
    this.sortAscending = false,
    this.filterType = 'all',
  });

  DownloadPageUIState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedGids,
    String? searchQuery,
    String? sortBy,
    bool? sortAscending,
    String? filterType,
  }) {
    return DownloadPageUIState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedGids: selectedGids ?? this.selectedGids,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      filterType: filterType ?? this.filterType,
    );
  }
}

/// 下载页面 UI 状态控制器
class DownloadPageUINotifier extends Notifier<DownloadPageUIState> {
  @override
  DownloadPageUIState build() {
    return const DownloadPageUIState();
  }

  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedGids: state.isSelectionMode ? {} : state.selectedGids,
    );
  }

  void toggleSelection(String gid) {
    final newSelection = Set<String>.from(state.selectedGids);
    if (newSelection.contains(gid)) {
      newSelection.remove(gid);
    } else {
      newSelection.add(gid);
    }
    state = state.copyWith(selectedGids: newSelection);
  }

  void selectAll(List<DownloadTask> tasks) {
    state = state.copyWith(
      selectedGids: tasks.map((t) => t.gid).toSet(),
    );
  }

  void deselectAll() {
    state = state.copyWith(
      selectedGids: {},
    );
  }

  void clearSelection() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedGids: {},
    );
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void updateFilterType(String type) {
    state = state.copyWith(filterType: type);
  }

  void updateSort(String sortBy, {bool? ascending}) {
    state = state.copyWith(
      sortBy: sortBy,
      sortAscending: ascending ?? state.sortAscending,
    );
  }

  void toggleSortOrder() {
    state = state.copyWith(sortAscending: !state.sortAscending);
  }
}

/// 下载页面 UI Provider
final downloadPageUIProvider =
    NotifierProvider<DownloadPageUINotifier, DownloadPageUIState>(
  DownloadPageUINotifier.new,
);

/// WebSocket 连接状态 Provider
final aria2ConnectionStateProvider = Provider<Aria2ConnectionState>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.wsConnectionState;
});

/// 是否已连接 Provider
final isAria2ConnectedProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(aria2ConnectionStateProvider);
  return connectionState == Aria2ConnectionState.connected;
});

/// 活动下载任务数量 Provider
final activeDownloadsCountProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.activeTasks.length;
});

/// 等待下载任务数量 Provider
final waitingDownloadsCountProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.waitingTasks.length;
});

/// 已暂停下载任务数量 Provider
final pausedDownloadsCountProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.pausedTasks.length;
});

/// 已完成下载任务数量 Provider
final completedDownloadsCountProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.completedTasks.length;
});

/// 下载失败任务数量 Provider
final failedDownloadsCountProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.failedTasks.length;
});

/// 总下载速度 Provider
final totalDownloadSpeedProvider = Provider<int>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.totalDownloadSpeed;
});

/// 是否有活动任务 Provider
final hasActiveDownloadsProvider = Provider<bool>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);
  return downloadState.activeTasks.isNotEmpty ||
      downloadState.waitingTasks.isNotEmpty;
});

/// WebSocket 统计信息 Provider
final aria2StatsProvider = Provider<Map<String, dynamic>?>((ref) {
  final controller = ref.read(downloadControllerProvider.notifier);
  return controller.getWebSocketStats();
});

/// 过滤后的活动任务 Provider
final filteredActiveTasksProvider = Provider<List<DownloadTask>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  final downloadState = ref.watch(downloadControllerProvider);
  final uiState = ref.watch(downloadPageUIProvider);

  var tasks = [...downloadState.activeTasks, ...downloadState.waitingTasks];

  // Apply search filter
  if (uiState.searchQuery.isNotEmpty) {
    tasks = controller
        .searchTasks(uiState.searchQuery)
        .where((t) => t.isDownloading)
        .toList();
  }

  // Apply file type filter
  if (uiState.filterType != 'all') {
    tasks = _filterByFileType(tasks, uiState.filterType);
  }

  // Apply sort
  return controller.sortTasks(
    tasks,
    uiState.sortBy,
    ascending: uiState.sortAscending,
  );
});

/// 过滤后的已暂停任务 Provider
final filteredPausedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  final downloadState = ref.watch(downloadControllerProvider);
  final uiState = ref.watch(downloadPageUIProvider);

  var tasks = List<DownloadTask>.from(downloadState.pausedTasks);

  if (uiState.searchQuery.isNotEmpty) {
    tasks = controller
        .searchTasks(uiState.searchQuery)
        .where((t) => t.isPaused)
        .toList();
  }

  if (uiState.filterType != 'all') {
    tasks = _filterByFileType(tasks, uiState.filterType);
  }

  return controller.sortTasks(
    tasks,
    uiState.sortBy,
    ascending: uiState.sortAscending,
  );
});

/// 过滤后的已完成任务 Provider
final filteredCompletedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  final downloadState = ref.watch(downloadControllerProvider);
  final uiState = ref.watch(downloadPageUIProvider);

  var tasks = List<DownloadTask>.from(downloadState.completedTasks);

  // Apply search filter
  if (uiState.searchQuery.isNotEmpty) {
    tasks = controller
        .searchTasks(uiState.searchQuery)
        .where((t) => t.isComplete)
        .toList();
  }

  if (uiState.filterType != 'all') {
    tasks = _filterByFileType(tasks, uiState.filterType);
  }

  // Apply sort
  return controller.sortTasks(
    tasks,
    uiState.sortBy,
    ascending: uiState.sortAscending,
  );
});

/// 过滤后的失败任务 Provider
final filteredFailedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  final downloadState = ref.watch(downloadControllerProvider);
  final uiState = ref.watch(downloadPageUIProvider);

  var tasks = List<DownloadTask>.from(downloadState.failedTasks);

  if (uiState.searchQuery.isNotEmpty) {
    tasks = controller
        .searchTasks(uiState.searchQuery)
        .where((t) => t.isError)
        .toList();
  }

  if (uiState.filterType != 'all') {
    tasks = _filterByFileType(tasks, uiState.filterType);
  }

  return controller.sortTasks(
    tasks,
    uiState.sortBy,
    ascending: uiState.sortAscending,
  );
});

/// 过滤后的所有任务 Provider
final filteredAllTasksProvider = Provider<List<DownloadTask>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  final downloadState = ref.watch(downloadControllerProvider);
  final uiState = ref.watch(downloadPageUIProvider);

  var tasks = [
    ...downloadState.activeTasks,
    ...downloadState.waitingTasks,
    ...downloadState.pausedTasks,
    ...downloadState.completedTasks,
    ...downloadState.failedTasks,
  ];

  // Apply search filter
  if (uiState.searchQuery.isNotEmpty) {
    tasks = controller.searchTasks(uiState.searchQuery);
  }

  if (uiState.filterType != 'all') {
    tasks = _filterByFileType(tasks, uiState.filterType);
  }

  // Apply sort
  return controller.sortTasks(
    tasks,
    uiState.sortBy,
    ascending: uiState.sortAscending,
  );
});

List<DownloadTask> _filterByFileType(List<DownloadTask> tasks, String filterType) {
  switch (filterType) {
    case 'video':
      return tasks.where((t) => t.isVideo).toList();
    case 'audio':
      return tasks.where((t) => t.isAudio).toList();
    case 'archive':
      return tasks.where((t) => t.isArchive).toList();
    case 'installer':
      return tasks.where((t) => t.isInstaller).toList();
    case 'document':
      return tasks.where((t) => t.isDocument).toList();
    default:
      return tasks;
  }
}

/// 获取任务详情 Provider (family pattern)
final downloadTaskProvider =
    Provider.family<DownloadTask?, String>((ref, gid) {
  final downloadState = ref.watch(downloadControllerProvider);
  final allTasks = [
    ...downloadState.activeTasks,
    ...downloadState.waitingTasks,
    ...downloadState.pausedTasks,
    ...downloadState.completedTasks,
    ...downloadState.failedTasks,
  ];

  try {
    return allTasks.firstWhere((t) => t.gid == gid);
  } catch (_) {
    return null;
  }
});

/// 下载进度统计 Provider
final downloadStatisticsProvider = Provider<DownloadStatistics>((ref) {
  final downloadState = ref.watch(downloadControllerProvider);

  return DownloadStatistics(
    totalDownloading: downloadState.totalDownloading,
    totalPaused: downloadState.totalPaused,
    totalCompleted: downloadState.totalCompleted,
    totalFailed: downloadState.totalFailed,
    totalAll: downloadState.totalAll,
    totalSpeed: downloadState.totalDownloadSpeed,
    totalUploadSpeed: downloadState.totalUploadSpeed,
    totalRemaining: downloadState.totalRemainingBytes,
    eta: downloadState.estimatedRemainingSeconds,
  );
});

/// 下载统计数据类
class DownloadStatistics {
  final int totalDownloading;
  final int totalPaused;
  final int totalCompleted;
  final int totalFailed;
  final int totalAll;
  final int totalSpeed;
  final int totalUploadSpeed;
  final int totalRemaining;
  final int eta;

  const DownloadStatistics({
    required this.totalDownloading,
    required this.totalPaused,
    required this.totalCompleted,
    required this.totalFailed,
    required this.totalAll,
    required this.totalSpeed,
    this.totalUploadSpeed = 0,
    required this.totalRemaining,
    required this.eta,
  });
}
