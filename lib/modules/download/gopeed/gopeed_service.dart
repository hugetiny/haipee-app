import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:haipee/modules/download/download_file_utils.dart';
import 'package:haipee/utils/storage.dart';
import 'gopeed_models.dart';
import 'libgopeed_worker.dart';

class GopeedService {
  static final GopeedService _instance = GopeedService._();
  factory GopeedService() => _instance;
  GopeedService._();

  final LibgopeedWorker _worker = LibgopeedWorker();
  bool _initialized = false;
  Future<void>? _initFuture;
  final StreamController<GopeedTaskEvent> _eventController =
      StreamController<GopeedTaskEvent>.broadcast();

  StreamSubscription? _workerSub;

  bool get isInitialized => _initialized;
  Stream<GopeedTaskEvent> get taskEvents => _eventController.stream;

  Future<void> reset() async {
    _initialized = false;
    _initFuture = null;
    try {
      await _workerSub?.cancel();
    } catch (_) {}
    _workerSub = null;
    _worker.reset();
  }

  Future<void> initialize({String? storageDir}) {
    if (_initialized) return Future.value();
    if (_initFuture != null) return _initFuture!;
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final totalTimeout = isTest
        ? const Duration(seconds: 4)
        : const Duration(seconds: 20);
    return _initFuture = _doInitialize(storageDir: storageDir).timeout(
      totalTimeout,
      onTimeout: () {
        throw TimeoutException(
          'GopeedService initialization timed out after ${totalTimeout.inSeconds} seconds',
        );
      },
    ).then((_) {
      _initialized = true;
    }).catchError((e, stack) {
      _initFuture = null;
      _initialized = false;
      throw e;
    });
  }

  Future<void> _doInitialize({String? storageDir}) async {
    String targetDir = storageDir ?? '';
    if (targetDir.isEmpty) {
      try {
        final settingDir = (GStorage.setting.get(
          SettingBoxKey.downloadDirectory,
          defaultValue: '',
        ) as String).trim();
        if (settingDir.isNotEmpty) {
          targetDir = '$settingDir/.gopeed';
        }
      } catch (_) {}
    }

    if (targetDir.isEmpty) {
      try {
        final appDir = await getApplicationSupportDirectory().timeout(const Duration(seconds: 3));
        targetDir = '${appDir.path}/gopeed';
      } catch (_) {
        targetDir = '${Directory.current.path}/.gopeed';
      }
    }

    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    String defaultDownloadDir;
    try {
      defaultDownloadDir = await DownloadFileUtils.getDefaultDownloadDirectory();
    } catch (_) {
      defaultDownloadDir = DownloadFileUtils.getDefaultDownloadDirectorySync();
    }
    if (defaultDownloadDir.isEmpty || defaultDownloadDir == '/') {
      defaultDownloadDir = dir.path;
    }
    try {
      Directory(defaultDownloadDir).createSync(recursive: true);
    } catch (_) {}

    final config = <String, dynamic>{
      'network': 'tcp',
      'address': '127.0.0.1:0',
      'apiEnable': false,
      'storage': 'bolt',
      'storageDir': '${dir.path}/storage',
      'refreshInterval': 1000,
      'downloadConfig': {
        'downloadDir': defaultDownloadDir,
      },
    };

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    try {
      await _worker
          .start(jsonEncode(config))
          .timeout(isTest ? const Duration(seconds: 3) : const Duration(seconds: 15));
    } catch (e) {
      // If bolt storage initialization fails (e.g. stale lock or corrupt db),
      // clean stale gopeed.db and retry, or fallback to memory storage
      try {
        final boltFile = File('${dir.path}/storage/gopeed.db');
        if (boltFile.existsSync()) {
          boltFile.deleteSync();
        }
      } catch (_) {}

      try {
        await _worker
            .start(jsonEncode(config))
            .timeout(isTest ? const Duration(seconds: 3) : const Duration(seconds: 8));
      } catch (_) {
        // Fallback to in-memory storage so the download service always successfully starts
        final memConfig = Map<String, dynamic>.from(config);
        memConfig['storage'] = 'mem';
        await _worker
            .start(jsonEncode(memConfig))
            .timeout(isTest ? const Duration(seconds: 3) : const Duration(seconds: 8));
      }
    }

    // Subscribe to task done and error events (mask = 0x03: done=1, error=2)
    await _worker
        .subscribeTaskEvents(0x03)
        .timeout(isTest ? const Duration(seconds: 2) : const Duration(seconds: 5));
    await _workerSub?.cancel();
    _workerSub = _worker.taskEvents.listen((data) {
      _eventController.add(GopeedTaskEvent.fromJson(data));
    });
  }

  /// Resolve a download target (HTTP, HLS, Magnet, Torrent) before creating a task
  Future<GopeedResolveResult?> resolve({
    required String url,
    Map<String, String>? headers,
    List<String>? trackers,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    final Map<String, dynamic> extra = {};
    if (headers != null && headers.isNotEmpty) {
      extra['header'] = headers;
    }
    if (trackers != null && trackers.isNotEmpty) {
      extra['trackers'] = trackers;
    }

    final body = {
      'req': {
        'url': url,
        if (extra.isNotEmpty) 'extra': extra,
      },
    };

    final res = await _worker.invoke('POST', '/api/v1/resolve', '', jsonEncode(body));
    if (res is Map && res['code'] == 0 && res['data'] is Map) {
      return GopeedResolveResult.fromJson((res['data'] as Map).cast<String, dynamic>());
    }
    return null;
  }

  /// Create a new download task via in-process FFI
  Future<String> createTask({
    String? url,
    String? rid,
    String? name,
    String? savePath,
    List<int>? selectFiles,
    Map<String, String>? headers,
    List<String>? trackers,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    String effectiveSavePath = savePath?.trim() ?? '';
    if (effectiveSavePath.isEmpty) {
      effectiveSavePath = DownloadFileUtils.getDefaultDownloadDirectorySync();
    }
    try {
      Directory(effectiveSavePath).createSync(recursive: true);
    } catch (_) {}

    final Map<String, dynamic> extra = {};
    if (headers != null && headers.isNotEmpty) {
      extra['header'] = headers;
    }
    if (trackers != null && trackers.isNotEmpty) {
      extra['trackers'] = trackers;
    }

    final opts = <String, dynamic>{
      if (name != null && name.isNotEmpty) 'name': name,
      if (effectiveSavePath.isNotEmpty) 'path': effectiveSavePath,
      if (selectFiles != null && selectFiles.isNotEmpty) 'selectFiles': selectFiles,
    };

    final Map<String, dynamic> body = {
      'opts': opts,
    };

    if (rid != null && rid.isNotEmpty) {
      body['rid'] = rid;
    } else if (url != null && url.isNotEmpty) {
      body['req'] = {
        'url': url,
        if (extra.isNotEmpty) 'extra': extra,
      };
    } else {
      throw ArgumentError('Either url or rid must be provided to createTask');
    }

    final res = await _worker.invoke('POST', '/api/v1/tasks', '', jsonEncode(body));
    if (res is Map && res['code'] == 0) {
      return res['data']?.toString() ?? '';
    }
    throw StateError('Failed to create Gopeed task: $res');
  }


  /// Fetch all tasks from in-process Gopeed engine
  Future<List<GopeedTask>> getTasks() async {
    if (!_initialized) return [];
    final res = await _worker.invoke('GET', '/api/v1/tasks', '', '');
    if (res is Map && res['code'] == 0) {
      final list = res['data'] as List<dynamic>? ?? [];
      return list
          .map((item) => GopeedTask.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  /// Fetch a single task by ID
  Future<GopeedTask?> getTask(String id) async {
    if (!_initialized) return null;
    final res = await _worker.invoke('GET', '/api/v1/tasks/$id', '', '');
    if (res is Map && res['code'] == 0 && res['data'] is Map) {
      return GopeedTask.fromJson((res['data'] as Map).cast<String, dynamic>());
    }
    return null;
  }

  /// Pause a task
  Future<void> pauseTask(String id) async {
    if (!_initialized) return;
    await _worker.invoke('PUT', '/api/v1/tasks/$id/pause', '', '');
  }

  /// Resume a task
  Future<void> resumeTask(String id) async {
    if (!_initialized) return;
    await _worker.invoke('PUT', '/api/v1/tasks/$id/continue', '', '');
  }

  /// Pause all tasks
  Future<void> pauseAll() async {
    if (!_initialized) return;
    await _worker.invoke('PUT', '/api/v1/tasks/pause', '', '');
  }

  /// Resume all tasks
  Future<void> resumeAll() async {
    if (!_initialized) return;
    await _worker.invoke('PUT', '/api/v1/tasks/continue', '', '');
  }

  /// Delete a task
  Future<void> deleteTask(String id, {bool force = false}) async {
    if (!_initialized) return;
    await _worker.invoke('DELETE', '/api/v1/tasks/$id', force ? 'force=true' : '', '');
  }

  /// Stop Gopeed engine
  Future<void> stop() async {
    if (!_initialized && _initFuture == null) return;
    try {
      await _workerSub?.cancel();
      _workerSub = null;
      await _worker.stop();
    } finally {
      _initialized = false;
      _initFuture = null;
    }
  }
}
