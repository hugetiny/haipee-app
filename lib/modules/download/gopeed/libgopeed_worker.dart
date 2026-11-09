import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'libgopeed_bind.dart';

typedef _InvokeResultNative = Void Function(Uint64 requestID, Int32 success, Pointer<Char> payload);
typedef _TaskEventNative = Void Function(Pointer<Char> payload);

class LibgopeedWorker {
  factory LibgopeedWorker() => _instance;

  LibgopeedWorker._() {
    if (_isMobile) {
      _initMobile();
    } else {
      _spawnWorker();
    }
  }

  static final LibgopeedWorker _instance = LibgopeedWorker._();
  static const MethodChannel _channel = MethodChannel('gopeed.com/libgopeed');
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  final Map<int, Completer<Object?>> _pending = {};
  StreamController<Map<String, dynamic>> _taskEvents = StreamController<Map<String, dynamic>>.broadcast();
  Future<Isolate>? _isolateReady;
  Completer<SendPort>? _sendPort;
  Future<void>? _stopFuture;
  int _requestID = 0;
  bool _stopping = false;
  bool _stopped = false;
  bool _started = false;
  bool _workerHasError = false;
  Future<int>? _startFuture;

  void _spawnWorker() {
    if (_isMobile) return;
    _cleanWorker();
    final rx = ReceivePort();
    final err = ReceivePort();
    final send = Completer<SendPort>();
    _receivePort = rx;
    _errorPort = err;
    _sendPort = send;
    _workerHasError = false;
    rx.listen(_handleWorkerMessage);
    err.listen(_handleWorkerError);
    _isolateReady = Isolate.spawn(_workerMain, rx.sendPort, onError: err.sendPort);
  }

  void _cleanWorker() {
    try {
      _receivePort?.close();
    } catch (_) {}
    try {
      _errorPort?.close();
    } catch (_) {}
    _receivePort = null;
    _errorPort = null;
    _isolateReady = null;
    _sendPort = null;
  }

  void reset() {
    _stopped = false;
    _stopping = false;
    _started = false;
    _startFuture = null;
    _stopFuture = null;
    _workerHasError = false;
    if (!_isMobile) {
      _spawnWorker();
    }
  }

  Stream<Map<String, dynamic>> get taskEvents {
    if (_taskEvents.isClosed) {
      _taskEvents = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _taskEvents.stream;
  }
  bool get isStarted => _started;

  void _initMobile() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'taskEvent') {
        try {
          final payload = call.arguments is String
              ? jsonDecode(call.arguments as String) as Map<String, dynamic>
              : (call.arguments as Map).cast<String, dynamic>();
          if (!_taskEvents.isClosed) {
            _taskEvents.add(payload);
          }
        } catch (_) {}
      }
    });
  }

  Future<int> start(String config) {
    if (_started && !_workerHasError) return Future.value(0);
    if (_startFuture != null) return _startFuture!;
    _stopped = false;
    _stopping = false;
    return _startFuture = (_isMobile ? _startMobile(config) : _request<int>('start', [config])).then((res) {
      _started = true;
      _workerHasError = false;
      return res;
    }).catchError((e) {
      _startFuture = null;
      _started = false;
      throw e;
    });
  }

  Future<int> _startMobile(String config) async {
    final port = await _channel.invokeMethod<int>('start', {'cfg': config});
    return port ?? 0;
  }

  Future<void> stop() => _stopFuture ??= _stop();

  Future<void> _stop() async {
    _stopping = true;
    try {
      if (_isMobile) {
        await _channel.invokeMethod<void>('stop');
      } else {
        await _request<Object?>('stop', const [], allowWhileStopping: true);
      }
    } catch (_) {}
    _stopped = true;
    _started = false;
    _startFuture = null;
    final stoppingError = StateError('libgopeed worker stopped before the request completed');
    for (final completer in _pending.values) {
      completer.completeError(stoppingError);
    }
    _pending.clear();
    await _taskEvents.close();
    if (!_isMobile) {
      _cleanWorker();
    }
  }

  Future<Object?> invoke(String method, String path, String query, String body) {
    if (_isMobile) {
      return _invokeMobile(method, path, query, body);
    }
    return _request<Object?>('invoke', [method, path, query, body]);
  }

  Future<Object?> _invokeMobile(String method, String path, String query, String body) async {
    final requestID = _requestID++;
    final res = await _channel.invokeMethod<String>('invoke', {
      'method': method,
      'path': path,
      'query': query,
      'body': body,
      'requestID': requestID,
    });
    if (res != null && res.isNotEmpty) {
      try {
        return jsonDecode(res);
      } catch (_) {
        return res;
      }
    }
    return null;
  }

  Future<String> apiServer(String operation) {
    if (_isMobile) {
      return _apiServerMobile(operation);
    }
    return _request<String>('apiServer', [operation]);
  }

  Future<String> _apiServerMobile(String operation) async {
    final res = await _channel.invokeMethod<String>(operation);
    return res ?? '';
  }

  Future<void> subscribeTaskEvents(int mask) async {
    if (_isMobile) {
      await _channel.invokeMethod<void>('subscribeTaskEvents', {'mask': mask});
      return;
    }
    await _request<Object?>('subscribeTaskEvents', [mask]);
  }

  Future<T> _request<T>(String type, List<Object?> arguments, {bool allowWhileStopping = false}) async {
    if (_stopped || (_stopping && !allowWhileStopping)) {
      throw StateError('libgopeed worker is stopping or stopped');
    }
    if (!_isMobile && (_workerHasError || _isolateReady == null || _sendPort == null)) {
      _spawnWorker();
    }
    if (_isolateReady != null) await _isolateReady;
    final sendPortCompleter = _sendPort;
    if (sendPortCompleter == null) {
      throw StateError('libgopeed worker sendPort is not initialized');
    }
    final sendPort = await sendPortCompleter.future;
    final requestID = _requestID++;
    final completer = Completer<Object?>();
    _pending[requestID] = completer;
    sendPort.send([type, requestID, ...arguments]);
    return (await completer.future) as T;
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is SendPort) {
      if (_sendPort != null && !_sendPort!.isCompleted) {
        _sendPort!.complete(message);
      }
      return;
    }
    final response = message as List<dynamic>;
    switch (response[0] as String) {
      case 'response':
        final requestID = response[1] as int;
        final completer = _pending.remove(requestID);
        if (completer == null) return;
        if (response[2] as bool) {
          completer.complete(response[3]);
        } else {
          completer.completeError(StateError(response[3]?.toString() ?? 'Unknown error'));
        }
      case 'taskEvent':
        _taskEvents.add((response[1] as Map<Object?, Object?>).cast<String, dynamic>());
    }
  }

  void _handleWorkerError(dynamic message) {
    _workerHasError = true;
    _started = false;
    _startFuture = null;
    final parts = message is List<dynamic> ? message : <dynamic>[message];
    final error = StateError(parts.map((part) => part.toString()).join('\n'));
    if (_sendPort != null && !_sendPort!.isCompleted) {
      _sendPort!.completeError(error);
    }
    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
    if (!_taskEvents.isClosed) {
      _taskEvents.addError(error);
    }
  }

  static void _workerMain(SendPort mainSendPort) {
    final requests = ReceivePort();
    final dylib = _openDynamicLibrary();
    final bindings = LibgopeedBind(dylib);
    late final NativeCallable<_InvokeResultNative> invokeResultCallback;
    late final NativeCallable<_TaskEventNative> taskEventCallback;

    invokeResultCallback = NativeCallable<_InvokeResultNative>.listener((
      int requestID,
      int success,
      Pointer<Char> payload,
    ) {
      if (payload == nullptr) {
        mainSendPort.send(['response', requestID, false, 'Gopeed InvokeAsync returned null']);
        return;
      }
      try {
        final result = payload.cast<Utf8>().toDartString();
        mainSendPort.send(['response', requestID, success != 0, success != 0 ? jsonDecode(result) : result]);
      } catch (error) {
        mainSendPort.send(['response', requestID, false, error.toString()]);
      } finally {
        bindings.FreeCString(payload);
      }
    });

    taskEventCallback = NativeCallable<_TaskEventNative>.listener((Pointer<Char> payload) {
      if (payload == nullptr) return;
      try {
        final event = jsonDecode(payload.cast<Utf8>().toDartString()) as Map<String, dynamic>;
        mainSendPort.send(['taskEvent', event]);
      } catch (_) {
      } finally {
        bindings.FreeCString(payload);
      }
    });

    mainSendPort.send(requests.sendPort);
    requests.listen((dynamic message) {
      final request = message as List<dynamic>;
      final type = request[0] as String;
      final requestID = request[1] as int;
      if (type == 'invoke') {
        try {
          _invokeAsync(
            bindings,
            invokeResultCallback.nativeFunction.address,
            requestID,
            request[2] as String,
            request[3] as String,
            request[4] as String,
            request[5] as String,
          );
        } catch (error) {
          mainSendPort.send(['response', requestID, false, error.toString()]);
        }
        return;
      }

      try {
        final response = switch (type) {
          'start' => _start(bindings, request[2] as String),
          'stop' => _stopNative(bindings),
          'apiServer' => _apiServer(bindings, request[2] as String),
          'subscribeTaskEvents' => _subscribeTaskEvents(
            bindings,
            taskEventCallback.nativeFunction.address,
            request[2] as int,
          ),
          _ => throw StateError('Unknown libgopeed worker request: $type'),
        };
        mainSendPort.send(['response', requestID, true, response]);
        if (type == 'stop') {
          invokeResultCallback.close();
          taskEventCallback.close();
          requests.close();
        }
      } catch (error) {
        mainSendPort.send(['response', requestID, false, error.toString()]);
      }
    });
  }

  static int _start(LibgopeedBind bindings, String config) {
    final configPtr = config.toNativeUtf8();
    try {
      final result = bindings.Start(configPtr.cast());
      if (result.r1 != nullptr) {
        try {
          throw StateError(result.r1.cast<Utf8>().toDartString());
        } finally {
          bindings.FreeCString(result.r1);
        }
      }
      return result.r0;
    } finally {
      malloc.free(configPtr);
    }
  }

  static Object? _stopNative(LibgopeedBind bindings) {
    bindings.Stop();
    return null;
  }

  static Object? _subscribeTaskEvents(LibgopeedBind bindings, int callback, int mask) {
    bindings.SubscribeTaskEvents(mask, mask == 0 ? 0 : callback);
    return null;
  }

  static String _apiServer(LibgopeedBind bindings, String operation) {
    final resultPtr = switch (operation) {
      'get' => bindings.GetAPIServerState(),
      'start' => bindings.StartAPIServer(),
      'stop' => bindings.StopAPIServer(),
      'restart' => bindings.RestartAPIServer(),
      _ => throw StateError('Unknown API server operation: $operation'),
    };
    if (resultPtr == nullptr) {
      throw StateError('Gopeed API server operation returned a null response');
    }
    try {
      return resultPtr.cast<Utf8>().toDartString();
    } finally {
      bindings.FreeCString(resultPtr);
    }
  }

  static void _invokeAsync(
    LibgopeedBind bindings,
    int callback,
    int requestID,
    String method,
    String path,
    String query,
    String body,
  ) {
    final methodPtr = method.toNativeUtf8();
    final pathPtr = path.toNativeUtf8();
    final queryPtr = query.toNativeUtf8();
    final bodyPtr = body.toNativeUtf8();
    try {
      bindings.InvokeAsync(methodPtr.cast(), pathPtr.cast(), queryPtr.cast(), bodyPtr.cast(), requestID, callback);
    } finally {
      malloc.free(methodPtr);
      malloc.free(pathPtr);
      malloc.free(queryPtr);
      malloc.free(bodyPtr);
    }
  }

  static DynamicLibrary _openDynamicLibrary() {
    final candidates = <String>[];
    if (Platform.isMacOS) {
      candidates.addAll([
        // Inside app bundle
        '${File(Platform.resolvedExecutable).parent.parent.path}/Frameworks/libgopeed.dylib',
        '${File(Platform.resolvedExecutable).parent.path}/libgopeed.dylib',
        // In local development / test execution directory
        '${Directory.current.path}/macos/Frameworks/libgopeed.dylib',
        '${Directory.current.path}/Frameworks/libgopeed.dylib',
        'macos/Frameworks/libgopeed.dylib',
        'Frameworks/libgopeed.dylib',
        'libgopeed.dylib',
      ]);
      Directory? dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 20 && dir != null; i++) {
        candidates.add('${dir.path}/macos/Frameworks/libgopeed.dylib');
        candidates.add('${dir.path}/Frameworks/libgopeed.dylib');
        candidates.add('${dir.path}/libgopeed.dylib');
        final nextDir = dir.parent;
        if (nextDir.path == dir.path) break;
        dir = nextDir;
      }
    } else if (Platform.isWindows) {
      candidates.addAll([
        '${File(Platform.resolvedExecutable).parent.path}/libgopeed.dll',
        '${Directory.current.path}/windows/libgopeed.dll',
        'windows/libgopeed.dll',
        'libgopeed.dll',
      ]);
      Directory? dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 20 && dir != null; i++) {
        candidates.add('${dir.path}/windows/libgopeed.dll');
        candidates.add('${dir.path}/libgopeed.dll');
        final nextDir = dir.parent;
        if (nextDir.path == dir.path) break;
        dir = nextDir;
      }
    } else if (Platform.isLinux) {
      candidates.addAll([
        '${File(Platform.resolvedExecutable).parent.path}/lib/libgopeed.so',
        '${File(Platform.resolvedExecutable).parent.path}/libgopeed.so',
        '${Directory.current.path}/linux/libgopeed.so',
        'linux/libgopeed.so',
        'libgopeed.so',
      ]);
      Directory? dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 20 && dir != null; i++) {
        candidates.add('${dir.path}/linux/libgopeed.so');
        candidates.add('${dir.path}/libgopeed.so');
        final nextDir = dir.parent;
        if (nextDir.path == dir.path) break;
        dir = nextDir;
      }
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        try {
          return DynamicLibrary.open(path);
        } catch (_) {}
      }
    }

    // Fallback to library name lookup in system dynamic linker
    final fallbackName = Platform.isWindows
        ? 'libgopeed.dll'
        : (Platform.isMacOS ? 'libgopeed.dylib' : 'libgopeed.so');
    return DynamicLibrary.open(fallbackName);
  }

}
