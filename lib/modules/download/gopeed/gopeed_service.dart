import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'gopeed_models.dart';
import 'libgopeed_worker.dart';

class GopeedService {
  static final GopeedService _instance = GopeedService._();
  factory GopeedService() => _instance;
  GopeedService._();

  final LibgopeedWorker _worker = LibgopeedWorker();
  bool _initialized = false;
  final StreamController<GopeedTaskEvent> _eventController =
      StreamController<GopeedTaskEvent>.broadcast();

  bool get isInitialized => _initialized;
  Stream<GopeedTaskEvent> get taskEvents => _eventController.stream;

  Future<void> initialize({String? storageDir}) async {
    if (_initialized) return;

    String targetDir = storageDir ?? '';
    if (targetDir.isEmpty) {
      try {
        final appDir = await getApplicationSupportDirectory().timeout(const Duration(seconds: 2));
        targetDir = '${appDir.path}/gopeed';
      } catch (_) {
        targetDir = '${Directory.current.path}/.gopeed';
      }
    }

    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final config = {
      'network': 'tcp',
      'address': '127.0.0.1:0',
      'apiEnable': false,
      'storage': 'bolt',
      'storageDir': '${dir.path}/storage',
      'refreshInterval': 1000,
    };

    await _worker.start(jsonEncode(config));
    // Subscribe to task done and error events (mask = 0x03: done=1, error=2)
    await _worker.subscribeTaskEvents(0x03);
    _worker.taskEvents.listen((data) {
      _eventController.add(GopeedTaskEvent.fromJson(data));
    });

    _initialized = true;
  }

  /// Create a new download task via in-process FFI
  Future<String> createTask({
    required String url,
    String? name,
    String? savePath,
    Map<String, String>? headers,
    List<String>? trackers,
  }) async {
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
      'opts': {
        if (name != null && name.isNotEmpty) 'name': name,
        if (savePath != null && savePath.isNotEmpty) 'path': savePath,
      },
    };

    final res = await _worker.invoke('POST', '/api/v1/tasks', '', jsonEncode(body));
    if (res is Map && res['code'] == 0) {
      return res['data']?.toString() ?? '';
    }
    throw StateError('Failed to create Gopeed task: $res');
  }

  /// Fetch all tasks from in-process Gopeed engine
  Future<List<GopeedTask>> getTasks() async {
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
    final res = await _worker.invoke('GET', '/api/v1/tasks/$id', '', '');
    if (res is Map && res['code'] == 0 && res['data'] is Map) {
      return GopeedTask.fromJson((res['data'] as Map).cast<String, dynamic>());
    }
    return null;
  }

  /// Pause a task
  Future<void> pauseTask(String id) async {
    await _worker.invoke('PUT', '/api/v1/tasks/$id/pause', '', '');
  }

  /// Resume a task
  Future<void> resumeTask(String id) async {
    await _worker.invoke('PUT', '/api/v1/tasks/$id/continue', '', '');
  }

  /// Pause all tasks
  Future<void> pauseAll() async {
    await _worker.invoke('PUT', '/api/v1/tasks/pause', '', '');
  }

  /// Resume all tasks
  Future<void> resumeAll() async {
    await _worker.invoke('PUT', '/api/v1/tasks/continue', '', '');
  }

  /// Delete a task
  Future<void> deleteTask(String id, {bool force = false}) async {
    await _worker.invoke('DELETE', '/api/v1/tasks/$id', force ? 'force=true' : '', '');
  }

  /// Stop Gopeed engine
  Future<void> stop() async {
    if (!_initialized) return;
    await _worker.stop();
    _initialized = false;
  }
}
