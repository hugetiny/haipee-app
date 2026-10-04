import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/utils/aria2_client.dart';
import 'package:kazumi/utils/aria2_process_manager.dart';
import 'package:kazumi/utils/aria2_websocket.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class DownloadState {
  final List<DownloadTask> activeTasks;
  final List<DownloadTask> waitingTasks;
  final List<DownloadTask> completedTasks;
  final bool isLoading;
  final String? errorMessage;
  final bool isConnected;
  final Aria2ConnectionState wsConnectionState;
  final DateTime? lastSyncTime;
  final bool needsRefresh;

  const DownloadState({
    this.activeTasks = const [],
    this.waitingTasks = const [],
    this.completedTasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isConnected = false,
    this.wsConnectionState = Aria2ConnectionState.disconnected,
    this.lastSyncTime,
    this.needsRefresh = false,
  });

  DownloadState copyWith({
    List<DownloadTask>? activeTasks,
    List<DownloadTask>? waitingTasks,
    List<DownloadTask>? completedTasks,
    bool? isLoading,
    String? errorMessage,
    bool? isConnected,
    Aria2ConnectionState? wsConnectionState,
    DateTime? lastSyncTime,
    bool? needsRefresh,
  }) {
    return DownloadState(
      activeTasks: activeTasks ?? this.activeTasks,
      waitingTasks: waitingTasks ?? this.waitingTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isConnected: isConnected ?? this.isConnected,
      wsConnectionState: wsConnectionState ?? this.wsConnectionState,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      needsRefresh: needsRefresh ?? this.needsRefresh,
    );
  }

  int get totalDownloading => activeTasks.length + waitingTasks.length;
  int get totalCompleted => completedTasks.length;
  int get totalFailed => completedTasks.where((t) => t.isError).length;

  // Calculate total download speed
  int get totalDownloadSpeed {
    return activeTasks.fold(0, (sum, task) => sum + task.downloadSpeed);
  }

  // Calculate total remaining bytes
  int get totalRemainingBytes {
    return activeTasks.fold(0, (sum, task) {
      return sum + (task.totalLength - task.completedLength);
    });
  }

  // Estimate total remaining time in seconds
  int get estimatedRemainingSeconds {
    if (totalDownloadSpeed == 0) return 0;
    return totalRemainingBytes ~/ totalDownloadSpeed;
  }

  /// 是否应该使用轮询（WebSocket 未连接时的后备方案）
  bool get shouldPoll =>
      wsConnectionState != Aria2ConnectionState.connected ||
      (activeTasks.isNotEmpty || waitingTasks.isNotEmpty);
}

class DownloadController extends Notifier<DownloadState> {
  @override
  DownloadState build() {
    ref.onDispose(_cleanup);
    Future.microtask(() => _initialize());
    return const DownloadState();
  }

  Timer? _syncTimer;
  StreamSubscription<Aria2ConnectionState>? _wsStateSubscription;
  final KazumiLogger _logger = KazumiLogger();
  Aria2Client? _aria2Client;
  Aria2WebSocketClient? _wsClient;

  // 防抖：避免频繁刷新
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 500);

  // 乐观更新的任务状态缓存
  final Map<String, DownloadTask> _optimisticTaskCache = {};

  // 标记正在进行的操作
  final Set<String> _pendingOperations = {};

  // Event stream controllers for external subscribers
  final StreamController<Aria2EventData> _eventStreamController =
      StreamController<Aria2EventData>.broadcast();
  final StreamController<Aria2ConnectionState> _connectionStateController =
      StreamController<Aria2ConnectionState>.broadcast();

  /// Public event stream for listening to download events
  Stream<Aria2EventData> get eventStream => _eventStreamController.stream;

  /// Public connection state stream
  Stream<Aria2ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Future<void> _initialize() async {
    try {
      _aria2Client = Aria2Client.fromSettings();
      await _loadFromStorage();
      await refreshDownloads();
      _connectWebSocket();
      _startSmartSync();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Initialization failed: $e');
      state = state.copyWith(
        errorMessage: '初始化失败: $e',
        isConnected: false,
      );
    }
  }

  /// 连接 WebSocket 监听实时事件
  void _connectWebSocket() {
    try {
      _wsClient = Aria2WebSocketClient(
        onEvent: _handleWebSocketEvent,
        onBatchEvents: _handleBatchWebSocketEvents,
        onConnected: () {
          _logger.log(Level.info, '[DownloadController] WebSocket connected');
          state = state.copyWith(
            wsConnectionState: Aria2ConnectionState.connected,
            isConnected: true,
          );
          // 连接成功后立即刷新一次
          _scheduleRefresh(immediate: true);
        },
        onDisconnected: () {
          _logger.log(
              Level.warning, '[DownloadController] WebSocket disconnected');
          state = state.copyWith(
            wsConnectionState: Aria2ConnectionState.disconnected,
          );
        },
        onError: (error) {
          _logger.log(
              Level.error, '[DownloadController] WebSocket error: $error');
        },
        eventBufferDuration: const Duration(milliseconds: 300),
        maxReconnectAttempts: 10,
      );

      // 监听连接状态变化
      _wsStateSubscription =
          _wsClient!.connectionStateStream.listen((newState) {
        state = state.copyWith(wsConnectionState: newState);

        // Broadcast to external stream
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(newState);
        }

        // 连接状态变化时调整同步策略
        _adjustSyncStrategy();
      });

      _wsClient!.connect();
    } catch (e) {
      _logger.log(Level.warning,
          '[DownloadController] WebSocket connection failed: $e');
    }
  }

  /// 处理单个 WebSocket 事件（用于快速响应）
  void _handleWebSocketEvent(Aria2EventData eventData) {
    _logger.log(
      Level.info,
      '[DownloadController] Event: ${eventData.event} for gid: ${eventData.gid}',
    );

    // Broadcast event to external listeners via stream
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(eventData);
    }

    // 根据事件类型进行乐观更新
    switch (eventData.event) {
      case Aria2Event.downloadStart:
        _optimisticUpdateTaskStatus(eventData.gid, 'active');
        break;
      case Aria2Event.downloadPause:
        _optimisticUpdateTaskStatus(eventData.gid, 'paused');
        break;
      case Aria2Event.downloadStop:
        _optimisticUpdateTaskStatus(eventData.gid, 'removed');
        break;
      case Aria2Event.downloadComplete:
      case Aria2Event.btDownloadComplete:
        _optimisticUpdateTaskStatus(eventData.gid, 'complete');
        break;
      case Aria2Event.downloadError:
        _optimisticUpdateTaskStatus(eventData.gid, 'error');
        break;
    }

    // 标记需要刷新（防抖延迟刷新以避免过于频繁）
    _scheduleRefresh();
  }

  /// 处理批量 WebSocket 事件（用于批量更新）
  void _handleBatchWebSocketEvents(List<Aria2EventData> events) {
    _logger.log(
      Level.info,
      '[DownloadController] Processing ${events.length} batched events',
    );

    // 批量处理事件
    for (var eventData in events) {
      switch (eventData.event) {
        case Aria2Event.downloadStart:
          _optimisticUpdateTaskStatus(eventData.gid, 'active', batch: true);
          break;
        case Aria2Event.downloadPause:
          _optimisticUpdateTaskStatus(eventData.gid, 'paused', batch: true);
          break;
        case Aria2Event.downloadStop:
          _optimisticUpdateTaskStatus(eventData.gid, 'removed', batch: true);
          break;
        case Aria2Event.downloadComplete:
        case Aria2Event.btDownloadComplete:
          _optimisticUpdateTaskStatus(eventData.gid, 'complete', batch: true);
          break;
        case Aria2Event.downloadError:
          _optimisticUpdateTaskStatus(eventData.gid, 'error', batch: true);
          break;
      }
    }

    // 批量处理后刷新一次
    _scheduleRefresh();
  }

  /// 调度刷新（带防抖）
  void _scheduleRefresh({bool immediate = false}) {
    if (immediate) {
      _debounceTimer?.cancel();
      refreshDownloads();
      return;
    }

    // 取消之前的防抖定时器
    _debounceTimer?.cancel();

    // 设置新的防抖定时器
    _debounceTimer = Timer(_debounceDuration, () {
      refreshDownloads();
    });
  }

  /// 乐观更新：立即更新任务状态
  void _optimisticUpdateTaskStatus(
    String gid,
    String newStatus, {
    bool batch = false,
  }) {
    final allTasks = [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.completedTasks,
    ];

    final taskIndex = allTasks.indexWhere((t) => t.gid == gid);
    if (taskIndex == -1) {
      // 任务不存在，可能是新任务，标记需要刷新
      if (!batch) {
        state = state.copyWith(needsRefresh: true);
      }
      return;
    }

    final task = allTasks[taskIndex];
    final updatedTask = DownloadTask(
      gid: task.gid,
      url: task.url,
      title: task.title,
      status: newStatus,
      totalLength: task.totalLength,
      completedLength: task.completedLength,
      downloadSpeed: task.downloadSpeed,
      fileName: task.fileName,
      errorMessage: task.errorMessage,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      bangumiId: task.bangumiId,
      episodeNumber: task.episodeNumber,
    );

    // 缓存乐观更新的任务
    _optimisticTaskCache[gid] = updatedTask;

    // 如果不是批量模式，立即更新 UI
    if (!batch) {
      _applyOptimisticUpdates();
    }
  }

  /// 应用乐观更新到状态
  void _applyOptimisticUpdates() {
    final allTasks = [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.completedTasks,
    ];

    // 应用缓存的乐观更新
    final updatedTasks = allTasks.map((task) {
      return _optimisticTaskCache[task.gid] ?? task;
    }).toList();

    // 重新分配到对应的列表
    final active = <DownloadTask>[];
    final waiting = <DownloadTask>[];
    final completed = <DownloadTask>[];

    for (var task in updatedTasks) {
      if (task.isActive) {
        active.add(task);
      } else if (task.isWaiting || task.isPaused) {
        waiting.add(task);
      } else {
        completed.add(task);
      }
    }

    state = state.copyWith(
      activeTasks: active,
      waitingTasks: waiting,
      completedTasks: completed,
    );
  }

  /// 乐观更新：立即移除任务
  void _optimisticRemoveTask(String gid) {
    state = state.copyWith(
      activeTasks: state.activeTasks.where((t) => t.gid != gid).toList(),
      waitingTasks: state.waitingTasks.where((t) => t.gid != gid).toList(),
      completedTasks: state.completedTasks.where((t) => t.gid != gid).toList(),
    );
    _optimisticTaskCache.remove(gid);
  }

  Future<void> _loadFromStorage() async {
    try {
      final box = GStorage.downloadTasks;
      final List<DownloadTask> tasks = [];
      for (var key in box.keys) {
        final task = box.get(key);
        if (task is DownloadTask) {
          tasks.add(task);
        }
      }

      final active = tasks.where((t) => t.isActive).toList();
      final waiting = tasks.where((t) => t.isWaiting || t.isPaused).toList();
      final completed = tasks.where((t) => t.isComplete || t.isError).toList();

      state = state.copyWith(
        activeTasks: active,
        waitingTasks: waiting,
        completedTasks: completed,
      );
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Load from storage failed: $e');
    }
  }

  /// 智能同步策略
  void _startSmartSync() {
    _syncTimer?.cancel();

    // 初始使用较短间隔
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _smartSync();
    });
  }

  /// 智能同步：根据 WebSocket 连接状态决定是否需要轮询
  Future<void> _smartSync() async {
    // 如果 WebSocket 已连接且没有标记需要刷新，跳过轮询
    if (state.wsConnectionState == Aria2ConnectionState.connected &&
        !state.needsRefresh) {
      // WebSocket 工作正常，延长轮询间隔作为健康检查
      _adjustSyncInterval(const Duration(seconds: 30));
      return;
    }

    // WebSocket 未连接或标记需要刷新，执行同步
    await refreshDownloads();
  }

  /// 调整同步策略
  void _adjustSyncStrategy() {
    final hasActiveTasks =
        state.activeTasks.isNotEmpty || state.waitingTasks.isNotEmpty;
    final wsConnected =
        state.wsConnectionState == Aria2ConnectionState.connected;

    Duration interval;

    if (wsConnected) {
      // WebSocket 已连接
      if (hasActiveTasks) {
        // 有活动任务时，使用较长的健康检查间隔（30秒）
        interval = const Duration(seconds: 30);
      } else {
        // 无任务时，使用更长的间隔（60秒）
        interval = const Duration(seconds: 60);
      }
    } else {
      // WebSocket 未连接，回退到轮询模式
      if (hasActiveTasks) {
        // 有活动任务时频繁轮询（3秒）
        interval = const Duration(seconds: 3);
      } else {
        // 无任务时较慢轮询（10秒）
        interval = const Duration(seconds: 10);
      }
    }

    _adjustSyncInterval(interval);
  }

  void _adjustSyncInterval(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      _smartSync();
    });
  }

  Future<void> refreshDownloads() async {
    _aria2Client ??= Aria2Client.fromSettings();

    try {
      final activeResults = await _aria2Client!.tellActive();
      final waitingResults = await _aria2Client!.tellWaiting(0, 100);
      final stoppedResults = await _aria2Client!.tellStopped(0, 100);

      final List<DownloadTask> activeTasks = [];
      final List<DownloadTask> waitingTasks = [];
      final List<DownloadTask> completedTasks = [];

      final box = GStorage.downloadTasks;

      // 处理活动任务
      for (var result in activeResults) {
        if (result is Map<String, dynamic>) {
          final gid = result['gid'] as String?;
          if (gid != null) {
            DownloadTask? existingTask = box.get(gid);
            final task = DownloadTask.fromAria2Status(
              result,
              title: existingTask?.title,
              bangumiId: existingTask?.bangumiId,
              episodeNumber: existingTask?.episodeNumber,
            );
            activeTasks.add(task);
            await box.put(gid, task);
          }
        }
      }

      // 处理等待任务
      for (var result in waitingResults) {
        if (result is Map<String, dynamic>) {
          final gid = result['gid'] as String?;
          if (gid != null) {
            DownloadTask? existingTask = box.get(gid);
            final task = DownloadTask.fromAria2Status(
              result,
              title: existingTask?.title,
              bangumiId: existingTask?.bangumiId,
              episodeNumber: existingTask?.episodeNumber,
            );
            waitingTasks.add(task);
            await box.put(gid, task);
          }
        }
      }

      // 处理已停止/完成任务
      for (var result in stoppedResults) {
        if (result is Map<String, dynamic>) {
          final gid = result['gid'] as String?;
          if (gid != null) {
            DownloadTask? existingTask = box.get(gid);
            final task = DownloadTask.fromAria2Status(
              result,
              title: existingTask?.title,
              bangumiId: existingTask?.bangumiId,
              episodeNumber: existingTask?.episodeNumber,
            );
            completedTasks.add(task);
            await box.put(gid, task);
          }
        }
      }

      // 清理乐观更新缓存
      _optimisticTaskCache.clear();

      state = state.copyWith(
        activeTasks: activeTasks,
        waitingTasks: waitingTasks,
        completedTasks: completedTasks,
        isConnected: true,
        errorMessage: null,
        lastSyncTime: DateTime.now(),
        needsRefresh: false,
      );

      // 根据任务状态调整同步策略
      _adjustSyncStrategy();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Refresh failed: $e');
      
      // 隐式自动检测并唤醒内置下载引擎
      if (!Aria2ProcessManager().isRunning) {
        Aria2ProcessManager().start().then((success) {
          if (success) {
            _connectWebSocket();
          }
        });
      }

      state = state.copyWith(
        errorMessage: '下载服务启动中...',
        isConnected: false,
        needsRefresh: false,
      );

      // 连接失败时调整策略
      _adjustSyncStrategy();
    }
  }

  Future<void> addDownload(
    String url, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    _aria2Client ??= Aria2Client.fromSettings();

    try {
      final gid = await _aria2Client!.addUri([url], options: options);
      if (gid != null) {
        final task = DownloadTask(
          gid: gid,
          url: url,
          title: title ?? url,
          status: 'waiting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          bangumiId: bangumiId,
          episodeNumber: episodeNumber,
        );

        await GStorage.downloadTasks.put(gid, task);

        // 乐观添加到等待列表
        state = state.copyWith(
          waitingTasks: [...state.waitingTasks, task],
        );

        // 如果 WebSocket 未连接，立即刷新
        if (state.wsConnectionState != Aria2ConnectionState.connected) {
          await refreshDownloads();
        }
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add download failed: $e');
      state = state.copyWith(errorMessage: '添加下载失败: $e');
    }
  }

  /// Add multiple URLs as separate download tasks
  Future<void> addUris(
    List<String> urls, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    _aria2Client ??= Aria2Client.fromSettings();

    final newTasks = <DownloadTask>[];

    try {
      for (var url in urls) {
        try {
          final gid = await _aria2Client!.addUri([url], options: options);
          if (gid != null) {
            final task = DownloadTask(
              gid: gid,
              url: url,
              title: title ?? url,
              status: 'waiting',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              bangumiId: bangumiId,
              episodeNumber: episodeNumber,
            );

            await GStorage.downloadTasks.put(gid, task);
            newTasks.add(task);
          }
        } catch (e) {
          _logger.log(
              Level.error, '[DownloadController] Add URI failed for $url: $e');
        }
      }

      // 乐观批量添加到等待列表
      if (newTasks.isNotEmpty) {
        state = state.copyWith(
          waitingTasks: [...state.waitingTasks, ...newTasks],
        );
      }

      // 如果 WebSocket 未连接，立即刷新
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add URIs failed: $e');
      state = state.copyWith(errorMessage: '批量添加下载失败: $e');
    }
  }

  /// Add torrent file
  Future<void> addTorrent(
    File torrentFile, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    _aria2Client ??= Aria2Client.fromSettings();

    try {
      // Read torrent file and encode to base64
      final bytes = await torrentFile.readAsBytes();
      final base64String = base64Encode(bytes);

      final gid = await _aria2Client!.addTorrent(
        base64String,
        options: options,
      );

      if (gid != null) {
        final task = DownloadTask(
          gid: gid,
          url: torrentFile.path,
          title: title ?? torrentFile.path.split(Platform.pathSeparator).last,
          status: 'waiting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          bangumiId: bangumiId,
          episodeNumber: episodeNumber,
        );

        await GStorage.downloadTasks.put(gid, task);

        // 乐观添加到等待列表
        state = state.copyWith(
          waitingTasks: [...state.waitingTasks, task],
        );

        // 如果 WebSocket 未连接，立即刷新
        if (state.wsConnectionState != Aria2ConnectionState.connected) {
          await refreshDownloads();
        }
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add torrent failed: $e');
      state = state.copyWith(errorMessage: '添加种子下载失败: $e');
      rethrow;
    }
  }

  Future<void> pauseDownload(String gid) async {
    if (_aria2Client == null) return;
    if (_pendingOperations.contains(gid)) return;

    _pendingOperations.add(gid);

    // 乐观更新：立即更新 UI 状态
    _optimisticUpdateTaskStatus(gid, 'paused');

    try {
      await _aria2Client!.pause(gid);
      // WebSocket 会收到事件并触发刷新
      // 如果 WebSocket 未连接，则手动刷新
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Pause failed: $e');
      state = state.copyWith(errorMessage: '暂停失败');
      // 失败时回滚状态
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> resumeDownload(String gid) async {
    if (_aria2Client == null) return;
    if (_pendingOperations.contains(gid)) return;

    _pendingOperations.add(gid);

    // 乐观更新：立即更新 UI 状态
    _optimisticUpdateTaskStatus(gid, 'active');

    try {
      await _aria2Client!.resume(gid);
      // WebSocket 会收到事件并触发刷新
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Resume failed: $e');
      state = state.copyWith(errorMessage: '恢复失败');
      // 失败时回滚状态
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> removeDownload(String gid, {bool force = false}) async {
    if (_aria2Client == null) return;
    if (_pendingOperations.contains(gid)) return;

    _pendingOperations.add(gid);

    // 乐观更新：立即从 UI 中移除任务
    _optimisticRemoveTask(gid);

    try {
      await _aria2Client!.remove(gid, force: force);
      await GStorage.downloadTasks.delete(gid);
      // WebSocket 会收到事件并触发刷新
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Remove failed: $e');
      state = state.copyWith(errorMessage: '删除失败');
      // 失败时回滚状态
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> clearCompleted() async {
    if (_aria2Client == null) return;

    try {
      await _aria2Client!.purgeCompleted();

      final box = GStorage.downloadTasks;
      final keysToDelete = <String>[];
      for (var key in box.keys) {
        final task = box.get(key);
        if (task is DownloadTask && (task.isComplete || task.isError)) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      // 乐观清空已完成列表
      state = state.copyWith(completedTasks: []);

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Clear completed failed: $e');
      state = state.copyWith(errorMessage: '清除失败');
    }
  }

  /// Pause all active downloads
  Future<void> pauseAll() async {
    if (_aria2Client == null) return;

    try {
      // 乐观批量更新
      for (var task in [...state.activeTasks, ...state.waitingTasks]) {
        _optimisticUpdateTaskStatus(task.gid, 'paused', batch: true);
      }
      _applyOptimisticUpdates();

      // 执行实际操作
      for (var task in [...state.activeTasks, ...state.waitingTasks]) {
        try {
          await _aria2Client!.pause(task.gid);
        } catch (e) {
          _logger.log(Level.warning,
              '[DownloadController] Failed to pause ${task.gid}: $e');
        }
      }

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Pause all failed: $e');
      state = state.copyWith(errorMessage: '全部暂停失败');
    }
  }

  /// Resume all paused downloads
  Future<void> resumeAll() async {
    if (_aria2Client == null) return;

    try {
      final pausedTasks =
          state.completedTasks.where((t) => t.isPaused).toList();

      // 乐观批量更新
      for (var task in pausedTasks) {
        _optimisticUpdateTaskStatus(task.gid, 'active', batch: true);
      }
      _applyOptimisticUpdates();

      // 执行实际操作
      for (var task in pausedTasks) {
        try {
          await _aria2Client!.resume(task.gid);
        } catch (e) {
          _logger.log(Level.warning,
              '[DownloadController] Failed to resume ${task.gid}: $e');
        }
      }

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Resume all failed: $e');
      state = state.copyWith(errorMessage: '全部恢复失败');
    }
  }

  /// Delete all tasks (both active and completed)
  Future<void> deleteAll({bool force = true}) async {
    if (_aria2Client == null) return;

    try {
      // 乐观清空所有任务
      state = state.copyWith(
        activeTasks: [],
        waitingTasks: [],
        completedTasks: [],
      );

      // Remove all active downloads
      for (var task in [...state.activeTasks, ...state.waitingTasks]) {
        try {
          await _aria2Client!.remove(task.gid, force: force);
        } catch (e) {
          _logger.log(Level.warning,
              '[DownloadController] Failed to remove ${task.gid}: $e');
        }
      }

      // Purge completed
      await _aria2Client!.purgeCompleted();

      // Clear storage
      await GStorage.downloadTasks.clear();

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Delete all failed: $e');
      state = state.copyWith(errorMessage: '全部删除失败');
      await refreshDownloads();
    }
  }

  /// Pause selected downloads
  Future<void> pauseSelected(List<String> gids) async {
    if (_aria2Client == null) return;

    try {
      // 乐观批量更新
      for (var gid in gids) {
        _optimisticUpdateTaskStatus(gid, 'paused', batch: true);
      }
      _applyOptimisticUpdates();

      // 执行实际操作
      for (var gid in gids) {
        try {
          await _aria2Client!.pause(gid);
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to pause $gid: $e');
        }
      }

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Pause selected failed: $e');
      state = state.copyWith(errorMessage: '批量暂停失败');
    }
  }

  /// Resume selected downloads
  Future<void> resumeSelected(List<String> gids) async {
    if (_aria2Client == null) return;

    try {
      // 乐观批量更新
      for (var gid in gids) {
        _optimisticUpdateTaskStatus(gid, 'active', batch: true);
      }
      _applyOptimisticUpdates();

      // 执行实际操作
      for (var gid in gids) {
        try {
          await _aria2Client!.resume(gid);
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to resume $gid: $e');
        }
      }

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Resume selected failed: $e');
      state = state.copyWith(errorMessage: '批量恢复失败');
    }
  }

  /// Delete selected downloads
  Future<void> deleteSelected(List<String> gids, {bool force = true}) async {
    if (_aria2Client == null) return;

    try {
      // 乐观批量移除
      for (var gid in gids) {
        _optimisticRemoveTask(gid);
      }

      // 执行实际操作
      for (var gid in gids) {
        try {
          await _aria2Client!.remove(gid, force: force);
          await GStorage.downloadTasks.delete(gid);
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to delete $gid: $e');
        }
      }

      // 如果 WebSocket 未连接，刷新确认
      if (state.wsConnectionState != Aria2ConnectionState.connected) {
        await refreshDownloads();
      }
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Delete selected failed: $e');
      state = state.copyWith(errorMessage: '批量删除失败');
    }
  }

  /// Retry a failed download
  Future<void> retryDownload(DownloadTask task) async {
    if (_aria2Client == null) return;

    try {
      // First remove the failed task
      try {
        await _aria2Client!.remove(task.gid, force: true);
      } catch (e) {
        // Ignore removal errors, task might already be removed
        _logger.log(Level.info,
            '[DownloadController] Failed to remove before retry: $e');
      }

      // Re-add the download
      await addDownload(
        task.url,
        title: task.title,
        bangumiId: task.bangumiId,
        episodeNumber: task.episodeNumber,
      );

      // Delete old task from storage
      await GStorage.downloadTasks.delete(task.gid);

      _logger.log(
          Level.info, '[DownloadController] Retrying download: ${task.title}');
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Retry failed: $e');
      state = state.copyWith(errorMessage: '重试失败: $e');
    }
  }

  /// Get all tasks (for search/filter purposes)
  List<DownloadTask> getAllTasks() {
    return [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.completedTasks,
    ];
  }

  /// Filter tasks by status
  List<DownloadTask> filterByStatus(String status) {
    return getAllTasks().where((t) => t.status == status).toList();
  }

  /// Search tasks by title
  List<DownloadTask> searchTasks(String query) {
    if (query.isEmpty) return getAllTasks();
    final lowerQuery = query.toLowerCase();
    return getAllTasks()
        .where((t) => t.title.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Sort tasks by various criteria
  List<DownloadTask> sortTasks(
    List<DownloadTask> tasks,
    String sortBy, {
    bool ascending = true,
  }) {
    final sorted = List<DownloadTask>.from(tasks);

    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'size':
        sorted.sort((a, b) => a.totalLength.compareTo(b.totalLength));
        break;
      case 'speed':
        sorted.sort((a, b) => a.downloadSpeed.compareTo(b.downloadSpeed));
        break;
      case 'progress':
        sorted.sort((a, b) => a.progress.compareTo(b.progress));
        break;
      case 'created':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'updated':
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      default:
        // Default: sort by creation time (newest first)
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return ascending ? sorted : sorted.reversed.toList();
  }

  /// 获取 WebSocket 统计信息
  Map<String, dynamic>? getWebSocketStats() {
    return _wsClient?.getStats();
  }

  /// 手动触发刷新
  Future<void> manualRefresh() async {
    await refreshDownloads();
  }

  void _cleanup() {
    _logger.log(Level.info, '[DownloadController] Disposing...');

    // 取消所有定时器
    _syncTimer?.cancel();
    _debounceTimer?.cancel();

    // 取消订阅
    _wsStateSubscription?.cancel();

    // 释放 WebSocket 客户端
    _wsClient?.dispose();

    // Close stream controllers
    _eventStreamController.close();
    _connectionStateController.close();

    // 清理缓存
    _optimisticTaskCache.clear();
    _pendingOperations.clear();
  }
}
