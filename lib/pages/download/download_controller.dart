import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/modules/download/download_file_utils.dart';
import 'package:kazumi/modules/download/gofile_helper.dart';
import 'package:kazumi/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:kazumi/utils/aria2_client.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:kazumi/utils/aria2_process_manager.dart';
import 'package:kazumi/utils/aria2_websocket.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class DownloadState {
  final List<DownloadTask> activeTasks;
  final List<DownloadTask> waitingTasks;
  final List<DownloadTask> pausedTasks;
  final List<DownloadTask> completedTasks;
  final List<DownloadTask> failedTasks;
  final bool isLoading;
  final String? errorMessage;
  final bool isConnected;
  final Aria2ConnectionState wsConnectionState;
  final DateTime? lastSyncTime;
  final bool needsRefresh;
  final int globalDownloadSpeed;
  final int globalUploadSpeed;

  const DownloadState({
    this.activeTasks = const [],
    this.waitingTasks = const [],
    this.pausedTasks = const [],
    this.completedTasks = const [],
    this.failedTasks = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isConnected = false,
    this.wsConnectionState = Aria2ConnectionState.disconnected,
    this.lastSyncTime,
    this.needsRefresh = false,
    this.globalDownloadSpeed = 0,
    this.globalUploadSpeed = 0,
  });

  static const Object _undefined = Object();

  DownloadState copyWith({
    List<DownloadTask>? activeTasks,
    List<DownloadTask>? waitingTasks,
    List<DownloadTask>? pausedTasks,
    List<DownloadTask>? completedTasks,
    List<DownloadTask>? failedTasks,
    bool? isLoading,
    Object? errorMessage = _undefined,
    bool? isConnected,
    Aria2ConnectionState? wsConnectionState,
    DateTime? lastSyncTime,
    bool? needsRefresh,
    int? globalDownloadSpeed,
    int? globalUploadSpeed,
  }) {
    return DownloadState(
      activeTasks: activeTasks ?? this.activeTasks,
      waitingTasks: waitingTasks ?? this.waitingTasks,
      pausedTasks: pausedTasks ?? this.pausedTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _undefined)
          ? this.errorMessage
          : errorMessage as String?,
      isConnected: isConnected ?? this.isConnected,
      wsConnectionState: wsConnectionState ?? this.wsConnectionState,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      needsRefresh: needsRefresh ?? this.needsRefresh,
      globalDownloadSpeed: globalDownloadSpeed ?? this.globalDownloadSpeed,
      globalUploadSpeed: globalUploadSpeed ?? this.globalUploadSpeed,
    );
  }

  int get totalDownloading => activeTasks.length + waitingTasks.length;
  int get totalPaused => pausedTasks.length;
  int get totalCompleted => completedTasks.length;
  int get totalFailed => failedTasks.length;
  int get totalAll =>
      activeTasks.length +
      waitingTasks.length +
      pausedTasks.length +
      completedTasks.length +
      failedTasks.length;

  // Calculate total download speed
  int get totalDownloadSpeed {
    final activeSpeed =
        activeTasks.fold(0, (sum, task) => sum + task.downloadSpeed);
    return globalDownloadSpeed > activeSpeed
        ? globalDownloadSpeed
        : activeSpeed;
  }

  // Calculate total upload speed
  int get totalUploadSpeed {
    final activeUpload =
        activeTasks.fold(0, (sum, task) => sum + task.uploadSpeed);
    return globalUploadSpeed > activeUpload
        ? globalUploadSpeed
        : activeUpload;
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
  bool _isDisposed = false;

  @override
  DownloadState build() {
    _isDisposed = false;
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
      await _loadFromStorage();
      if (Aria2FeatureManager().isAvailable && !Aria2ProcessManager().isRunning) {
        await Aria2ProcessManager().start();
      }
      _aria2Client = Aria2Client.fromSettings();
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
          if (_isDisposed || !ref.mounted) return;
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
          if (_isDisposed || !ref.mounted) return;
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
        if (_isDisposed || !ref.mounted) return;
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
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
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
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
    ];

    // 应用缓存的乐观更新
    final updatedTasks = allTasks.map((task) {
      return _optimisticTaskCache[task.gid] ?? task;
    }).toList();

    // 重新分配到对应的列表
    final active = <DownloadTask>[];
    final waiting = <DownloadTask>[];
    final paused = <DownloadTask>[];
    final completed = <DownloadTask>[];
    final failed = <DownloadTask>[];

    for (var task in updatedTasks) {
      if (task.isActive) {
        active.add(task);
      } else if (task.isWaiting) {
        waiting.add(task);
      } else if (task.isPaused) {
        paused.add(task);
      } else if (task.isComplete) {
        completed.add(task);
      } else if (task.isError) {
        failed.add(task);
      }
    }

    state = state.copyWith(
      activeTasks: active,
      waitingTasks: waiting,
      pausedTasks: paused,
      completedTasks: completed,
      failedTasks: failed,
    );
  }

  /// 乐观更新：立即移除任务
  void _optimisticRemoveTask(String gid) {
    state = state.copyWith(
      activeTasks: state.activeTasks.where((t) => t.gid != gid).toList(),
      waitingTasks: state.waitingTasks.where((t) => t.gid != gid).toList(),
      pausedTasks: state.pausedTasks.where((t) => t.gid != gid).toList(),
      completedTasks: state.completedTasks.where((t) => t.gid != gid).toList(),
      failedTasks: state.failedTasks.where((t) => t.gid != gid).toList(),
    );
    _optimisticTaskCache.remove(gid);
  }

  Future<void> _loadFromStorage() async {
    try {
      final box = GStorage.downloadTasks;
      final List<DownloadTask> tasks = [];
      for (var key in box.keys) {
        var task = box.get(key);
        if (task is DownloadTask) {
          if (task.isComplete) {
            final validation = DownloadFileUtils.validateDownloadedContent(task);
            if (!validation.isValid) {
              task = task.copyWith(
                status: 'error',
                errorMessage: validation.errorMessage ?? '下载内容为重定向网页或鉴权失败，文件可能已失效',
                errorCode: 24,
              );
              box.put(key, task);
            }
          }
          tasks.add(task);
        }
      }

      final active = tasks.where((t) => t.isActive).toList();
      final waiting = tasks.where((t) => t.isWaiting).toList();
      final paused = tasks.where((t) => t.isPaused).toList();
      final completed = tasks.where((t) => t.isComplete).toList();
      final failed = tasks.where((t) => t.isError).toList();

      state = state.copyWith(
        activeTasks: active,
        waitingTasks: waiting,
        pausedTasks: paused,
        completedTasks: completed,
        failedTasks: failed,
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
    if (_isDisposed || !ref.mounted) return;

    final activePort = Aria2ProcessManager.activePort;
    if (_aria2Client == null ||
        (activePort != null && _aria2Client!.endpoint.port != activePort)) {
      _aria2Client = Aria2Client.fromSettings();
    }

    try {
      final activeResults = await _aria2Client!.tellActive();
      if (_isDisposed || !ref.mounted) return;

      final waitingResults = await _aria2Client!.tellWaiting(0, 100);
      if (_isDisposed || !ref.mounted) return;

      final stoppedResults = await _aria2Client!.tellStopped(0, 100);
      if (_isDisposed || !ref.mounted) return;

      final List<DownloadTask> activeTasks = [];
      final List<DownloadTask> waitingTasks = [];
      final List<DownloadTask> pausedTasks = [];
      final List<DownloadTask> completedTasks = [];
      final List<DownloadTask> failedTasks = [];

      final box = GStorage.downloadTasks;
      if (!box.isOpen) return;

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

      // 处理等待任务 (包含 paused 任务)
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
            if (task.isPaused) {
              pausedTasks.add(task);
            } else {
              waitingTasks.add(task);
            }
            await box.put(gid, task);
          }
        }
      }

      int globalDown = 0;
      int globalUp = 0;
      try {
        final gStat = await _aria2Client!.getGlobalStat();
        globalDown =
            int.tryParse(gStat['downloadSpeed']?.toString() ?? '0') ?? 0;
        globalUp =
            int.tryParse(gStat['uploadSpeed']?.toString() ?? '0') ?? 0;
      } catch (_) {}

      // 处理已停止任务 (complete / error / paused)
      for (var result in stoppedResults) {
        if (result is Map<String, dynamic>) {
          final gid = result['gid'] as String?;
          if (gid != null) {
            DownloadTask? existingTask = box.get(gid);
            var task = DownloadTask.fromAria2Status(
              result,
              title: existingTask?.title,
              bangumiId: existingTask?.bangumiId,
              episodeNumber: existingTask?.episodeNumber,
            );
            if (task.isComplete) {
              final validation =
                  DownloadFileUtils.validateDownloadedContent(task);
              if (!validation.isValid) {
                task = task.copyWith(
                  status: 'error',
                  errorMessage: validation.errorMessage ??
                      '下载内容为重定向网页或鉴权失败，文件可能已失效',
                  errorCode: 24,
                );
                failedTasks.add(task);
                await box.put(gid, task);
                continue;
              }
              completedTasks.add(task);
            } else if (task.isError) {
              failedTasks.add(task);
            } else if (task.isPaused) {
              pausedTasks.add(task);
            }
            await box.put(gid, task);
          }
        }
      }

      // 清理乐观更新缓存
      _optimisticTaskCache.clear();

      if (_isDisposed || !ref.mounted) return;

      state = state.copyWith(
        activeTasks: activeTasks,
        waitingTasks: waitingTasks,
        pausedTasks: pausedTasks,
        completedTasks: completedTasks,
        failedTasks: failedTasks,
        isConnected: true,
        errorMessage: null,
        lastSyncTime: DateTime.now(),
        needsRefresh: false,
        globalDownloadSpeed: globalDown,
        globalUploadSpeed: globalUp,
      );

      // 根据任务状态调整同步策略
      _adjustSyncStrategy();
    } catch (e) {
      if (_isDisposed || !ref.mounted) return;

      _logger.log(Level.warning, '[DownloadController] Refresh skipped: $e');

      // 降级：从本地持久化存储加载任务，确保离线或服务唤醒期间历史下载依然可见
      await _loadFromStorage();

      // 隐式自动检测并唤醒内置下载引擎
      if (!Aria2ProcessManager().isRunning) {
        Aria2ProcessManager().start().then((success) {
          if (_isDisposed || !ref.mounted) return;
          if (success) {
            _aria2Client = Aria2Client.fromSettings();
            _connectWebSocket();
            refreshDownloads();
          }
        });
      }

      if (_isDisposed || !ref.mounted) return;

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
    await addUris(
      [url],
      title: title,
      bangumiId: bangumiId,
      episodeNumber: episodeNumber,
      options: options,
    );
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
          String targetUrl = url;
          if (url.startsWith('magnet:?')) {
            try {
              targetUrl = await TorrentTrackerService.instance
                  .rewriteMagnetWithDoh(url)
                  .timeout(const Duration(seconds: 2));
            } catch (_) {
              targetUrl = TorrentTrackerService.instance.injectTrackers(url);
            }
          }

          final taskOptions = Map<String, dynamic>.from(options ?? {});

          // Smart headers & filename detection for HTTP/HTTPS URLs
          if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
            if (!taskOptions.containsKey('user-agent')) {
              taskOptions['user-agent'] =
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
            }
            if (!taskOptions.containsKey('check-certificate')) {
              taskOptions['check-certificate'] = 'false';
            }

            // If URL has a clean file name at the end of path, set 'out' option if not provided
            if (!taskOptions.containsKey('out')) {
              final uri = Uri.tryParse(targetUrl);
              if (uri != null && uri.pathSegments.isNotEmpty) {
                final lastSegment = uri.pathSegments.last;
                if (lastSegment.contains('.') && !lastSegment.endsWith('.')) {
                  final decoded = Uri.decodeComponent(lastSegment).trim();
                  if (decoded.isNotEmpty) {
                    taskOptions['out'] = decoded;
                  }
                }
              }
            }

            // Gofile or web-share detection: automatically resolve token, cookie, and direct link
            if (GofileHelper().isGofileUrl(targetUrl)) {
              try {
                final gofileInfo = await GofileHelper().resolve(targetUrl);
                if (gofileInfo != null) {
                  targetUrl = gofileInfo.downloadUrl;
                  if (!taskOptions.containsKey('out')) {
                    taskOptions['out'] = gofileInfo.fileName;
                  }
                  final headersList = <String>[];
                  if (taskOptions['header'] is List) {
                    headersList.addAll((taskOptions['header'] as List).map((e) => e.toString()));
                  } else if (taskOptions['header'] != null) {
                    headersList.add(taskOptions['header'].toString());
                  }
                  if (!headersList.any((h) => h.toLowerCase().startsWith('cookie:'))) {
                    headersList.add('Cookie: accountToken=${gofileInfo.token}');
                  }
                  if (!headersList.any((h) => h.toLowerCase().startsWith('referer:'))) {
                    headersList.add('Referer: https://gofile.io/');
                  }
                  taskOptions['header'] = headersList;
                }
              } catch (e) {
                _logger.log(Level.warning, '[DownloadController] Gofile resolve error: $e');
              }
            }
          }

          final gid = await _aria2Client!.addUri([targetUrl], options: taskOptions);
          if (gid != null) {
            String initialTitle = title ?? '';
            if (initialTitle.isEmpty) {
              if (taskOptions['out'] != null) {
                initialTitle = taskOptions['out'].toString();
              } else {
                initialTitle = url;
              }
            }

            final task = DownloadTask(
              gid: gid,
              url: url,
              title: initialTitle,
              fileName: taskOptions['out']?.toString(),
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

  /// Add torrent from in-memory byte array
  Future<void> addTorrentBytes(
    List<int> bytes, {
    String? title,
    String? originalUrl,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    _aria2Client ??= Aria2Client.fromSettings();

    try {
      final base64String = base64Encode(bytes);

      final gid = await _aria2Client!.addTorrent(
        base64String,
        options: options,
      );

      if (gid != null) {
        final task = DownloadTask(
          gid: gid,
          url: originalUrl ?? 'torrent://bytes',
          title: title ?? 'Torrent Download',
          status: 'waiting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          bangumiId: bangumiId,
          episodeNumber: episodeNumber,
        );

        await GStorage.downloadTasks.put(gid, task);

        state = state.copyWith(
          waitingTasks: [...state.waitingTasks, task],
        );

        if (state.wsConnectionState != Aria2ConnectionState.connected) {
          await refreshDownloads();
        }
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add torrent bytes failed: $e');
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

  Future<void> removeDownload(String gid, {bool force = false, bool deleteFile = false}) async {
    if (_aria2Client == null) return;
    if (_pendingOperations.contains(gid)) return;

    _pendingOperations.add(gid);

    final box = GStorage.downloadTasks;
    final existingTask = box.get(gid) as DownloadTask?;

    // 乐观更新：立即从 UI 中移除任务
    _optimisticRemoveTask(gid);

    try {
      await _aria2Client!.remove(gid, force: force);
      await box.delete(gid);

      if (deleteFile && existingTask != null) {
        await DownloadFileUtils.deleteDownloadedFile(existingTask.filePath ?? existingTask.fileName);
      }

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

  Future<void> clearCompleted({bool deleteFiles = false}) async {
    if (_aria2Client == null) return;

    try {
      await _aria2Client!.purgeCompleted();

      final box = GStorage.downloadTasks;
      final keysToDelete = <String>[];
      for (var key in box.keys) {
        final task = box.get(key);
        if (task is DownloadTask && task.isComplete) {
          keysToDelete.add(key);
          if (deleteFiles) {
            await DownloadFileUtils.deleteDownloadedFile(task.filePath ?? task.fileName);
          }
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
      final pausedTasks = List<DownloadTask>.from(state.pausedTasks);

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

  /// Delete all tasks (both active, paused, failed, and completed)
  Future<void> deleteAll({bool force = true, bool deleteFiles = false}) async {
    if (_aria2Client == null) return;

    try {
      final allTasks = getAllTasks();

      // 乐观清空所有任务
      state = state.copyWith(
        activeTasks: [],
        waitingTasks: [],
        pausedTasks: [],
        completedTasks: [],
        failedTasks: [],
      );

      // Remove all active downloads
      for (var task in allTasks) {
        try {
          await _aria2Client!.remove(task.gid, force: force);
          if (deleteFiles) {
            await DownloadFileUtils.deleteDownloadedFile(task.filePath ?? task.fileName);
          }
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
  Future<void> deleteSelected(List<String> gids, {bool force = true, bool deleteFiles = false}) async {
    if (_aria2Client == null) return;

    try {
      // 乐观批量移除
      for (var gid in gids) {
        _optimisticRemoveTask(gid);
      }

      // 执行实际操作
      for (var gid in gids) {
        try {
          final box = GStorage.downloadTasks;
          final existingTask = box.get(gid) as DownloadTask?;
          await _aria2Client!.remove(gid, force: force);
          await box.delete(gid);
          if (deleteFiles && existingTask != null) {
            await DownloadFileUtils.deleteDownloadedFile(existingTask.filePath ?? existingTask.fileName);
          }
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
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
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

  /// 直接从本地持久化存储重载任务（用于离线状态或无头集成测试）
  Future<void> loadFromStorage() async {
    await _loadFromStorage();
  }

  void _cleanup() {
    _isDisposed = true;
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
