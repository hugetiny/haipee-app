import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/download/download_file_utils.dart';
import 'package:haipee/modules/download/gofile_helper.dart';
import 'package:haipee/modules/download/gopeed/gopeed_models.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:haipee/modules/torrent_search/utils/torrent_download_helper.dart';
import 'package:haipee/utils/storage.dart';

import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadConnectionState {
  disconnected,
  connecting,
  connected,
  error;
}

// Compatibility aliases
typedef Aria2ConnectionState = DownloadConnectionState;

enum DownloadEvent {
  downloadStart,
  downloadPause,
  downloadStop,
  downloadComplete,
  downloadError,
}

typedef Aria2Event = DownloadEvent;

class DownloadEventData {
  final DownloadEvent event;
  final String gid;
  final DateTime timestamp;
  final String? errorMessage;

  DownloadEventData({
    required this.event,
    required this.gid,
    DateTime? timestamp,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();
}

typedef Aria2EventData = DownloadEventData;

class DownloadState {
  final List<DownloadTask> activeTasks;
  final List<DownloadTask> waitingTasks;
  final List<DownloadTask> pausedTasks;
  final List<DownloadTask> completedTasks;
  final List<DownloadTask> failedTasks;
  final bool isLoading;
  final String? errorMessage;
  final bool isConnected;
  final DownloadConnectionState connectionState;
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
    this.connectionState = DownloadConnectionState.disconnected,
    this.lastSyncTime,
    this.needsRefresh = false,
    this.globalDownloadSpeed = 0,
    this.globalUploadSpeed = 0,
  });

  // Backward compatibility getter
  DownloadConnectionState get wsConnectionState => connectionState;

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
    DownloadConnectionState? connectionState,
    DownloadConnectionState? wsConnectionState,
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
      connectionState: connectionState ?? wsConnectionState ?? this.connectionState,
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

  int get totalDownloadSpeed {
    final activeSpeed =
        activeTasks.fold(0, (sum, task) => sum + task.downloadSpeed);
    return globalDownloadSpeed > activeSpeed
        ? globalDownloadSpeed
        : activeSpeed;
  }

  int get totalUploadSpeed {
    final activeUpload =
        activeTasks.fold(0, (sum, task) => sum + task.uploadSpeed);
    return globalUploadSpeed > activeUpload
        ? globalUploadSpeed
        : activeUpload;
  }

  int get totalRemainingBytes {
    return activeTasks.fold(0, (sum, task) {
      return sum + (task.totalLength - task.completedLength);
    });
  }

  int get estimatedRemainingSeconds {
    if (totalDownloadSpeed == 0) return 0;
    return totalRemainingBytes ~/ totalDownloadSpeed;
  }

  bool get shouldPoll =>
      connectionState != DownloadConnectionState.connected ||
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
  StreamSubscription<GopeedTaskEvent>? _eventSubscription;
  final HaipeeLogger _logger = HaipeeLogger();

  // Debounce refresh
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 300);

  // Optimistic update cache
  final Map<String, DownloadTask> _optimisticTaskCache = {};
  final Set<String> _pendingOperations = {};

  final StreamController<DownloadEventData> _eventStreamController =
      StreamController<DownloadEventData>.broadcast();
  final StreamController<DownloadConnectionState> _connectionStateController =
      StreamController<DownloadConnectionState>.broadcast();

  Stream<DownloadEventData> get eventStream => _eventStreamController.stream;
  Stream<DownloadConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Future<void> reinitialize() async {
    _logger.log(Level.info, '[DownloadController] Reinitializing download engine...');
    state = state.copyWith(
      errorMessage: '下载服务连接中...',
      isConnected: false,
      connectionState: DownloadConnectionState.connecting,
    );
    _broadcastConnectionState(DownloadConnectionState.connecting);
    await GopeedService().reset();
    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadFromStorage();
      await GopeedService().initialize();

      state = state.copyWith(
        errorMessage: null,
        isConnected: true,
        connectionState: DownloadConnectionState.connected,
      );
      _broadcastConnectionState(DownloadConnectionState.connected);

      // Subscribe to Gopeed real-time task events
      await _eventSubscription?.cancel();
      _eventSubscription = GopeedService().taskEvents.listen(_handleGopeedEvent);

      try {
        await refreshDownloads();
      } catch (refreshErr) {
        _logger.log(
            Level.warning, '[DownloadController] Initial refresh error: $refreshErr');
      }
      _startSyncTimer();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Initialization failed: $e');
      state = state.copyWith(
        errorMessage: '初始化失败: $e',
        isConnected: false,
        connectionState: DownloadConnectionState.error,
      );
      _broadcastConnectionState(DownloadConnectionState.error);
    }
  }

  void _broadcastConnectionState(DownloadConnectionState newState) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
  }

  void _handleGopeedEvent(GopeedTaskEvent event) {
    final type = event.eventType.toLowerCase();
    final taskId = event.taskId;

    _logger.log(Level.info,
        '[DownloadController] Gopeed task event: $type for task: $taskId');

    DownloadEvent? mappedEvent;
    if (type.contains('start') || type.contains('running')) {
      mappedEvent = DownloadEvent.downloadStart;
      _optimisticUpdateTaskStatus(taskId, 'active');
    } else if (type.contains('pause')) {
      mappedEvent = DownloadEvent.downloadPause;
      _optimisticUpdateTaskStatus(taskId, 'paused');
    } else if (type.contains('delete')) {
      mappedEvent = DownloadEvent.downloadStop;
      _optimisticRemoveTask(taskId);
    } else if (type.contains('done') || type.contains('complete')) {
      mappedEvent = DownloadEvent.downloadComplete;
      _optimisticUpdateTaskStatus(taskId, 'complete');
    } else if (type.contains('error')) {
      mappedEvent = DownloadEvent.downloadError;
      _optimisticUpdateTaskStatus(taskId, 'error');
    }

    if (mappedEvent != null && !_eventStreamController.isClosed) {
      _eventStreamController.add(DownloadEventData(
        event: mappedEvent,
        gid: taskId,
        errorMessage: event.error,
      ));
    }

    _scheduleRefresh();
  }

  void _scheduleRefresh({bool immediate = false}) {
    if (immediate) {
      _debounceTimer?.cancel();
      refreshDownloads();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      refreshDownloads();
    });
  }

  void _optimisticUpdateTaskStatus(String gid, String newStatus, {bool batch = false}) {
    final allTasks = [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
    ];

    final taskIndex = allTasks.indexWhere((t) => t.gid == gid);
    if (taskIndex == -1) {
      if (!batch) {
        state = state.copyWith(needsRefresh: true);
      }
      return;
    }

    final task = allTasks[taskIndex];
    final updatedTask = task.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    _optimisticTaskCache[gid] = updatedTask;

    if (!batch) {
      _applyOptimisticUpdates();
    }
  }

  void _applyOptimisticUpdates() {
    final allTasks = [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
    ];

    final updatedTasks = allTasks.map((task) {
      return _optimisticTaskCache[task.gid] ?? task;
    }).toList();

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
                errorMessage: validation.errorMessage ?? '下载内容异常或文件已失效',
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

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.needsRefresh) {
        refreshDownloads();
      }
    });
  }

  Future<void> refreshDownloads() async {
    if (_isDisposed || !ref.mounted) return;

    try {
      if (!GopeedService().isInitialized) {
        await GopeedService().initialize();
      }

      final gopeedTasks = await GopeedService().getTasks();
      if (_isDisposed || !ref.mounted) return;

      final List<DownloadTask> activeTasks = [];
      final List<DownloadTask> waitingTasks = [];
      final List<DownloadTask> pausedTasks = [];
      final List<DownloadTask> completedTasks = [];
      final List<DownloadTask> failedTasks = [];

      final box = GStorage.downloadTasks;
      if (!box.isOpen) return;

      int globalDown = 0;
      int globalUp = 0;

      for (var gt in gopeedTasks) {
        DownloadTask? existingTask = box.get(gt.id);
        var task = DownloadTask.fromGopeedTask(
          gt,
          title: existingTask?.title,
          bangumiId: existingTask?.bangumiId,
          episodeNumber: existingTask?.episodeNumber,
        );

        if (existingTask != null && existingTask.url.isNotEmpty && task.url.isEmpty) {
          task = task.copyWith(url: existingTask.url);
        }

        globalDown += task.downloadSpeed;
        globalUp += task.uploadSpeed;

        if (task.isComplete) {
          final validation = DownloadFileUtils.validateDownloadedContent(task);
          if (!validation.isValid) {
            task = task.copyWith(
              status: 'error',
              errorMessage: validation.errorMessage ?? '下载内容异常或文件已失效',
              errorCode: 24,
            );
            failedTasks.add(task);
            await box.put(task.gid, task);
            continue;
          }
          completedTasks.add(task);
        } else if (task.isError) {
          failedTasks.add(task);
        } else if (task.isPaused) {
          pausedTasks.add(task);
        } else if (task.isActive) {
          activeTasks.add(task);
        } else if (task.isRemoved) {
          failedTasks.add(task);
        } else {
          waitingTasks.add(task);
        }
        await box.put(task.gid, task);
      }

      // Merge historical tasks from local storage that are not in current Gopeed memory
      for (var key in box.keys) {
        final localTask = box.get(key);
        if (localTask is DownloadTask) {
          final alreadyIncluded = activeTasks.any((t) => t.gid == localTask.gid) ||
              waitingTasks.any((t) => t.gid == localTask.gid) ||
              pausedTasks.any((t) => t.gid == localTask.gid) ||
              completedTasks.any((t) => t.gid == localTask.gid) ||
              failedTasks.any((t) => t.gid == localTask.gid);
          if (!alreadyIncluded) {
            if (localTask.isComplete) {
              completedTasks.add(localTask);
            } else if (localTask.isError) {
              failedTasks.add(localTask);
            } else if (localTask.isPaused) {
              pausedTasks.add(localTask);
            } else if (localTask.isActive) {
              activeTasks.add(localTask);
            } else if (localTask.isRemoved) {
              failedTasks.add(localTask);
            } else {
              waitingTasks.add(localTask);
            }
          }
        }
      }

      _optimisticTaskCache.clear();

      if (_isDisposed || !ref.mounted) return;

      state = state.copyWith(
        activeTasks: activeTasks,
        waitingTasks: waitingTasks,
        pausedTasks: pausedTasks,
        completedTasks: completedTasks,
        failedTasks: failedTasks,
        isConnected: true,
        connectionState: DownloadConnectionState.connected,
        errorMessage: null,
        lastSyncTime: DateTime.now(),
        needsRefresh: false,
        globalDownloadSpeed: globalDown,
        globalUploadSpeed: globalUp,
      );
    } catch (e) {
      if (_isDisposed || !ref.mounted) return;
      _logger.log(Level.warning, '[DownloadController] Refresh skipped: $e');

      await _loadFromStorage();
      if (_isDisposed || !ref.mounted) return;

      state = state.copyWith(
        errorMessage: '下载服务连接中...',
        isConnected: false,
        connectionState: DownloadConnectionState.connecting,
        needsRefresh: false,
      );
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

  Future<void> addUris(
    List<String> urls, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    final newTasks = <DownloadTask>[];

    try {
      final defaultDir = DownloadFileUtils.getDefaultDownloadDirectorySync();

      for (var url in urls) {
        try {
          String targetUrl = url;
          if (url.startsWith('magnet:?')) {
            targetUrl = TorrentTrackerService.instance.injectTrackers(url);
          }

          final cleanLower = url.toLowerCase().split('?').first;
          if ((url.startsWith('http://') || url.startsWith('https://')) &&
              cleanLower.endsWith('.torrent')) {
            try {
              final torrentBytes = await TorrentDownloadHelper.fetchTorrentBytes(
                url,
                timeout: const Duration(seconds: 3),
              );
              if (torrentBytes != null && torrentBytes.isNotEmpty) {
                await addTorrentBytes(
                  torrentBytes,
                  title: title,
                  originalUrl: url,
                  bangumiId: bangumiId,
                  episodeNumber: episodeNumber,
                  options: options,
                );
                continue;
              }
            } catch (e) {
              _logger.log(
                Level.warning,
                '[DownloadController] Fetching torrent URL bytes failed, falling back to direct URI: $e',
              );
            }
          }

          final taskOptions = Map<String, dynamic>.from(options ?? {});
          final Map<String, String> headers = {};

          if (taskOptions['header'] is List) {
            for (var h in (taskOptions['header'] as List)) {
              final str = h.toString();
              final idx = str.indexOf(':');
              if (idx > 0) {
                headers[str.substring(0, idx).trim()] = str.substring(idx + 1).trim();
              }
            }
          } else if (taskOptions['header'] is Map) {
            (taskOptions['header'] as Map).forEach((k, v) {
              if (k != null && v != null) {
                headers[k.toString()] = v.toString();
              }
            });
          }

          if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
            if (!headers.containsKey('User-Agent') && !headers.containsKey('user-agent')) {
              headers['User-Agent'] =
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
            }

            if (GofileHelper().isGofileUrl(targetUrl)) {
              try {
                final gofileInfo = await GofileHelper().resolve(targetUrl);
                if (gofileInfo != null) {
                  targetUrl = gofileInfo.downloadUrl;
                  if (!taskOptions.containsKey('out')) {
                    taskOptions['out'] = gofileInfo.fileName;
                  }
                  headers['Cookie'] = 'accountToken=${gofileInfo.token}';
                  headers['Referer'] = 'https://gofile.io/';
                }
              } catch (e) {
                _logger.log(Level.warning, '[DownloadController] Gofile resolve error: $e');
              }
            }
          }

          String saveDir = taskOptions['dir']?.toString() ?? '';
          if (saveDir.isEmpty) {
            saveDir = defaultDir;
          }

          List<int>? selectFiles;
          if (taskOptions['selectFiles'] is List) {
            selectFiles = (taskOptions['selectFiles'] as List)
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toList();
          } else if (taskOptions['select-file'] != null || taskOptions['select-files'] != null) {
            final raw = (taskOptions['select-file'] ?? taskOptions['select-files']).toString();
            selectFiles = raw
                .split(',')
                .map((e) => int.tryParse(e.trim()))
                .whereType<int>()
                .map((e) => e > 0 ? e - 1 : e)
                .toList();
          }

          String? customName = taskOptions['out']?.toString();
          if ((customName == null || customName.isEmpty) &&
              title != null &&
              !title.startsWith('http') &&
              !title.startsWith('magnet:')) {
            customName = title;
          }

          if (!GopeedService().isInitialized) {
            await GopeedService().initialize();
          }

          final gid = await GopeedService().createTask(
            url: targetUrl,
            name: customName,
            savePath: saveDir,
            selectFiles: selectFiles,
            headers: headers.isNotEmpty ? headers : null,
          );

          if (gid.isNotEmpty) {
            String initialTitle = title ?? '';
            if (initialTitle.isEmpty) {
              if (customName != null && customName.isNotEmpty) {
                initialTitle = customName;
              } else {
                initialTitle = url;
              }
            }

            final task = DownloadTask(
              gid: gid,
              url: url,
              title: initialTitle,
              fileName: customName,
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

      if (newTasks.isNotEmpty) {
        state = state.copyWith(
          waitingTasks: [...state.waitingTasks, ...newTasks],
        );
      }

      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add URIs failed: $e');
      state = state.copyWith(errorMessage: '批量添加下载失败: $e');
    }
  }

  Future<void> addTorrent(
    File torrentFile, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    try {
      final defaultDir = DownloadFileUtils.getDefaultDownloadDirectorySync();

      final taskOptions = Map<String, dynamic>.from(options ?? {});
      String saveDir = taskOptions['dir']?.toString() ?? '';
      if (saveDir.isEmpty) {
        saveDir = defaultDir;
      }

      List<int>? selectFiles;
      if (taskOptions['selectFiles'] is List) {
        selectFiles = (taskOptions['selectFiles'] as List)
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      } else if (taskOptions['select-file'] != null || taskOptions['select-files'] != null) {
        final raw = (taskOptions['select-file'] ?? taskOptions['select-files']).toString();
        selectFiles = raw
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .map((e) => e > 0 ? e - 1 : e)
            .toList();
      }

      final fileName = torrentFile.path.split(Platform.pathSeparator).last;
      final fileUri = 'file://${torrentFile.absolute.path}';

      if (!GopeedService().isInitialized) {
        await GopeedService().initialize();
      }

      final gid = await GopeedService().createTask(
        url: fileUri,
        name: title ?? fileName,
        savePath: saveDir,
        selectFiles: selectFiles,
      );

      if (gid.isNotEmpty) {
        final task = DownloadTask(
          gid: gid,
          url: torrentFile.path,
          title: title ?? fileName,
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

        _scheduleRefresh();
      }
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add torrent failed: $e');
      state = state.copyWith(errorMessage: '添加种子下载失败: $e');
      rethrow;
    }
  }

  Future<void> addTorrentBytes(
    List<int> bytes, {
    String? title,
    String? originalUrl,
    String? bangumiId,
    int? episodeNumber,
    Map<String, dynamic>? options,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/haipee_${DateTime.now().millisecondsSinceEpoch}.torrent');
      await tempFile.writeAsBytes(bytes);

      await addTorrent(
        tempFile,
        title: title,
        bangumiId: bangumiId,
        episodeNumber: episodeNumber,
        options: options,
      );
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Add torrent bytes failed: $e');
      state = state.copyWith(errorMessage: '添加种子下载失败: $e');
      rethrow;
    }
  }

  Future<void> pauseDownload(String gid) async {
    if (_pendingOperations.contains(gid)) return;
    _pendingOperations.add(gid);

    _optimisticUpdateTaskStatus(gid, 'paused');

    try {
      await GopeedService().pauseTask(gid);
      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Pause failed: $e');
      state = state.copyWith(errorMessage: '暂停失败');
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> resumeDownload(String gid) async {
    if (_pendingOperations.contains(gid)) return;
    _pendingOperations.add(gid);

    _optimisticUpdateTaskStatus(gid, 'active');

    try {
      await GopeedService().resumeTask(gid);
      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Resume failed: $e');
      state = state.copyWith(errorMessage: '恢复失败');
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> removeDownload(String gid, {bool force = false, bool deleteFile = false}) async {
    if (_pendingOperations.contains(gid)) return;
    _pendingOperations.add(gid);

    final box = GStorage.downloadTasks;
    final existingTask = box.get(gid) as DownloadTask?;

    _optimisticRemoveTask(gid);

    try {
      await GopeedService().deleteTask(gid, force: force);
      await box.delete(gid);

      if (deleteFile && existingTask != null) {
        await DownloadFileUtils.deleteDownloadedFile(existingTask.filePath ?? existingTask.fileName);
      }

      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Remove failed: $e');
      state = state.copyWith(errorMessage: '删除失败');
      await refreshDownloads();
    } finally {
      _pendingOperations.remove(gid);
    }
  }

  Future<void> clearCompleted({bool deleteFiles = false}) async {
    try {
      final box = GStorage.downloadTasks;
      final keysToDelete = <String>[];
      for (var key in box.keys) {
        final task = box.get(key);
        if (task is DownloadTask && task.isComplete) {
          keysToDelete.add(key);
          if (deleteFiles) {
            await DownloadFileUtils.deleteDownloadedFile(task.filePath ?? task.fileName);
          }
          try {
            await GopeedService().deleteTask(task.gid, force: true);
          } catch (_) {}
        }
      }

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      state = state.copyWith(completedTasks: []);
      _scheduleRefresh();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Clear completed failed: $e');
      state = state.copyWith(errorMessage: '清除失败');
    }
  }

  Future<void> pauseAll() async {
    try {
      for (var task in [...state.activeTasks, ...state.waitingTasks]) {
        _optimisticUpdateTaskStatus(task.gid, 'paused', batch: true);
      }
      _applyOptimisticUpdates();

      await GopeedService().pauseAll();
      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Pause all failed: $e');
      state = state.copyWith(errorMessage: '全部暂停失败');
    }
  }

  Future<void> resumeAll() async {
    try {
      final pausedTasks = List<DownloadTask>.from(state.pausedTasks);
      for (var task in pausedTasks) {
        _optimisticUpdateTaskStatus(task.gid, 'active', batch: true);
      }
      _applyOptimisticUpdates();

      await GopeedService().resumeAll();
      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Resume all failed: $e');
      state = state.copyWith(errorMessage: '全部恢复失败');
    }
  }

  Future<void> deleteAll({bool force = true, bool deleteFiles = false}) async {
    try {
      final allTasks = getAllTasks();

      state = state.copyWith(
        activeTasks: [],
        waitingTasks: [],
        pausedTasks: [],
        completedTasks: [],
        failedTasks: [],
      );

      for (var task in allTasks) {
        try {
          await GopeedService().deleteTask(task.gid, force: force);
          if (deleteFiles) {
            await DownloadFileUtils.deleteDownloadedFile(task.filePath ?? task.fileName);
          }
        } catch (e) {
          _logger.log(Level.warning,
              '[DownloadController] Failed to remove ${task.gid}: $e');
        }
      }

      await GStorage.downloadTasks.clear();
      _scheduleRefresh();
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Delete all failed: $e');
      state = state.copyWith(errorMessage: '全部删除失败');
      await refreshDownloads();
    }
  }

  Future<void> pauseSelected(List<String> gids) async {
    try {
      for (var gid in gids) {
        _optimisticUpdateTaskStatus(gid, 'paused', batch: true);
      }
      _applyOptimisticUpdates();

      for (var gid in gids) {
        try {
          await GopeedService().pauseTask(gid);
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to pause $gid: $e');
        }
      }

      _scheduleRefresh();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Pause selected failed: $e');
      state = state.copyWith(errorMessage: '批量暂停失败');
    }
  }

  Future<void> resumeSelected(List<String> gids) async {
    try {
      for (var gid in gids) {
        _optimisticUpdateTaskStatus(gid, 'active', batch: true);
      }
      _applyOptimisticUpdates();

      for (var gid in gids) {
        try {
          await GopeedService().resumeTask(gid);
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to resume $gid: $e');
        }
      }

      _scheduleRefresh();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Resume selected failed: $e');
      state = state.copyWith(errorMessage: '批量恢复失败');
    }
  }

  Future<void> deleteSelected(List<String> gids, {bool force = true, bool deleteFiles = false}) async {
    try {
      for (var gid in gids) {
        _optimisticRemoveTask(gid);
      }

      for (var gid in gids) {
        try {
          final box = GStorage.downloadTasks;
          final existingTask = box.get(gid) as DownloadTask?;
          await GopeedService().deleteTask(gid, force: force);
          await box.delete(gid);
          if (deleteFiles && existingTask != null) {
            await DownloadFileUtils.deleteDownloadedFile(existingTask.filePath ?? existingTask.fileName);
          }
        } catch (e) {
          _logger.log(
              Level.warning, '[DownloadController] Failed to delete $gid: $e');
        }
      }

      _scheduleRefresh();
    } catch (e) {
      _logger.log(
          Level.error, '[DownloadController] Delete selected failed: $e');
      state = state.copyWith(errorMessage: '批量删除失败');
    }
  }

  Future<void> retryDownload(DownloadTask task) async {
    try {
      try {
        await GopeedService().deleteTask(task.gid, force: true);
      } catch (e) {
        _logger.log(Level.info,
            '[DownloadController] Failed to remove before retry: $e');
      }

      if (task.url.endsWith('.torrent') && File(task.url).existsSync()) {
        await addTorrent(
          File(task.url),
          title: task.title,
          bangumiId: task.bangumiId,
          episodeNumber: task.episodeNumber,
        );
      } else {
        await addDownload(
          task.url,
          title: task.title,
          bangumiId: task.bangumiId,
          episodeNumber: task.episodeNumber,
        );
      }

      await GStorage.downloadTasks.delete(task.gid);
      _logger.log(
          Level.info, '[DownloadController] Retrying download: ${task.title}');
    } catch (e) {
      _logger.log(Level.error, '[DownloadController] Retry failed: $e');
      state = state.copyWith(errorMessage: '重试失败: $e');
    }
  }

  List<DownloadTask> getAllTasks() {
    return [
      ...state.activeTasks,
      ...state.waitingTasks,
      ...state.pausedTasks,
      ...state.completedTasks,
      ...state.failedTasks,
    ];
  }

  List<DownloadTask> filterByStatus(String status) {
    return getAllTasks().where((t) => t.status == status).toList();
  }

  List<DownloadTask> searchTasks(String query) {
    if (query.isEmpty) return getAllTasks();
    final lowerQuery = query.toLowerCase();
    return getAllTasks()
        .where((t) => t.title.toLowerCase().contains(lowerQuery))
        .toList();
  }

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
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return ascending ? sorted : sorted.reversed.toList();
  }

  Map<String, dynamic> getWebSocketStats() {
    return {
      'engine': 'gopeed',
      'connected': state.isConnected,
      'activeTasks': state.activeTasks.length,
      'waitingTasks': state.waitingTasks.length,
      'totalSpeed': state.totalDownloadSpeed,
    };
  }

  Future<void> manualRefresh() async {
    await refreshDownloads();
  }

  Future<void> loadFromStorage() async {
    await _loadFromStorage();
  }

  void _cleanup() {
    _isDisposed = true;
    _logger.log(Level.info, '[DownloadController] Disposing...');

    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _eventSubscription?.cancel();

    _eventStreamController.close();
    _connectionStateController.close();

    _optimisticTaskCache.clear();
    _pendingOperations.clear();
  }
}
