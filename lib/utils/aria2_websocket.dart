import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

/// Aria2 WebSocket 事件类型
enum Aria2Event {
  downloadStart,
  downloadPause,
  downloadStop,
  downloadComplete,
  downloadError,
  btDownloadComplete,
}

/// Aria2 连接状态
enum Aria2ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Aria2 事件数据
class Aria2EventData {
  const Aria2EventData({
    required this.gid,
    required this.event,
    required this.timestamp,
    this.data,
  });

  final String gid;
  final Aria2Event event;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  @override
  String toString() =>
      'Aria2EventData(gid: $gid, event: $event, timestamp: $timestamp)';
}

/// Aria2 事件回调
typedef Aria2EventCallback = void Function(Aria2EventData eventData);

/// Aria2 WebSocket 客户端
///
/// 负责监听 aria2 的实时事件推送
/// 特性：
/// - 自动重连与指数退避
/// - 心跳检测
/// - 事件缓冲与批量处理
/// - 连接状态流
/// - 乐观更新支持
class Aria2WebSocketClient {
  Aria2WebSocketClient({
    required this.onEvent,
    this.onBatchEvents,
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.eventBufferDuration = const Duration(milliseconds: 300),
    this.maxReconnectAttempts = 5,
    this.initialReconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  final Aria2EventCallback onEvent;
  final void Function(List<Aria2EventData> events)? onBatchEvents;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final Function(dynamic error)? onError;

  /// 事件缓冲时长（用于批量处理）
  final Duration eventBufferDuration;

  /// 最大重连次数
  final int maxReconnectAttempts;

  /// 初始重连延迟
  final Duration initialReconnectDelay;

  /// 最大重连延迟（指数退避上限）
  final Duration maxReconnectDelay;

  /// 心跳间隔
  final Duration heartbeatInterval;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _eventBufferTimer;

  final List<Aria2EventData> _eventBuffer = [];
  int _reconnectAttempts = 0;
  DateTime? _lastHeartbeatSent;
  DateTime? _lastMessageReceived;

  final KazumiLogger _logger = KazumiLogger();

  /// 连接状态流控制器
  final StreamController<Aria2ConnectionState> _stateController =
      StreamController<Aria2ConnectionState>.broadcast();

  /// 连接状态流
  Stream<Aria2ConnectionState> get connectionStateStream =>
      _stateController.stream;

  Aria2ConnectionState _connectionState = Aria2ConnectionState.disconnected;

  /// 当前连接状态
  Aria2ConnectionState get connectionState => _connectionState;

  /// 是否已连接
  bool get isConnected => _connectionState == Aria2ConnectionState.connected;

  /// 是否已释放
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  /// 获取 WebSocket URL
  Uri _getWebSocketUrl() {
    final httpEndpoint = GStorage.setting.get(
      SettingBoxKey.aria2Endpoint,
      defaultValue: 'http://127.0.0.1:6800/jsonrpc',
    ) as String;

    // 将 http:// 替换为 ws://，https:// 替换为 wss://
    String wsUrl = httpEndpoint
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    // 确保 URL 以 /jsonrpc 结尾
    if (!wsUrl.endsWith('/jsonrpc')) {
      if (!wsUrl.endsWith('/')) {
        wsUrl += '/jsonrpc';
      } else {
        wsUrl += 'jsonrpc';
      }
    }

    return Uri.parse(wsUrl);
  }

  /// 获取 RPC secret
  String? _getSecret() {
    final secret = GStorage.setting.get(
      SettingBoxKey.aria2Secret,
      defaultValue: '',
    ) as String;
    return secret.isEmpty ? null : secret;
  }

  /// 更新连接状态
  void _updateConnectionState(Aria2ConnectionState newState) {
    if (_connectionState == newState) return;
    _connectionState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
    _logger.log(Level.info, '[Aria2WebSocket] State changed to: $newState');
  }

  /// 连接到 aria2 WebSocket
  Future<void> connect() async {
    if (_isDisposed) {
      _logger.log(Level.warning, '[Aria2WebSocket] Cannot connect: disposed');
      return;
    }

    if (_connectionState == Aria2ConnectionState.connected ||
        _connectionState == Aria2ConnectionState.connecting) {
      _logger.log(Level.info,
          '[Aria2WebSocket] Already connected or connecting: $_connectionState');
      return;
    }

    _updateConnectionState(Aria2ConnectionState.connecting);

    try {
      final wsUrl = _getWebSocketUrl();
      _logger.log(Level.info, '[Aria2WebSocket] Connecting to $wsUrl');

      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;

      // 监听消息
      channel.stream.listen(
        _onMessage,
        onError: _onWebSocketError,
        onDone: _onWebSocketDone,
        cancelOnError: false,
      );

      // 等待连接建立完成，避免连接失败时抛出未捕获的异步异常
      await channel.ready;

      _updateConnectionState(Aria2ConnectionState.connected);
      _reconnectAttempts = 0;
      _lastMessageReceived = DateTime.now();
      _logger.log(Level.info, '[Aria2WebSocket] Connected successfully');

      // 启动心跳
      _startHeartbeat();

      onConnected?.call();
    } catch (e, stackTrace) {
      _logger.log(
        Level.warning,
        '[Aria2WebSocket] Connection failed: $e',
      );
      _updateConnectionState(Aria2ConnectionState.error);
      onError?.call(e);
      _scheduleReconnect();
    }
  }

  /// 处理接收到的消息
  void _onMessage(dynamic message) {
    if (_isDisposed) return;

    _lastMessageReceived = DateTime.now();

    try {
      final data = jsonDecode(message as String);

      // 检查是否是事件通知
      if (data is Map<String, dynamic>) {
        final method = data['method'] as String?;
        final params = data['params'] as List?;

        if (method != null && params != null && params.isNotEmpty) {
          _handleEvent(method, params);
        } else if (data.containsKey('result')) {
          // 这是对请求的响应（如心跳响应），可以忽略或记录
          // _logger.log(Level.debug, '[Aria2WebSocket] Received response: ${data['id']}');
        }
      }
    } catch (e) {
      _logger.log(
        Level.warning,
        '[Aria2WebSocket] Failed to parse message: $e',
      );
    }
  }

  /// 处理 aria2 事件
  void _handleEvent(String method, List params) {
    // aria2 事件格式：method = "aria2.onDownloadStart", params = [{"gid": "xxx"}]
    if (!method.startsWith('aria2.on')) return;

    final gidData = params.firstOrNull;
    if (gidData is! Map || !gidData.containsKey('gid')) return;

    final gid = gidData['gid'] as String;
    final event = _parseEventType(method);

    if (event != null) {
      _logger.log(Level.info, '[Aria2WebSocket] Event: $method, gid: $gid');

      final eventData = Aria2EventData(
        gid: gid,
        event: event,
        timestamp: DateTime.now(),
        data: gidData is Map<String, dynamic> ? gidData : null,
      );

      // 立即触发单个事件回调
      onEvent(eventData);

      // 添加到缓冲区用于批量处理
      if (onBatchEvents != null) {
        _bufferEvent(eventData);
      }
    }
  }

  /// 缓冲事件用于批量处理
  void _bufferEvent(Aria2EventData eventData) {
    _eventBuffer.add(eventData);

    // 如果缓冲定时器未启动，启动它
    if (_eventBufferTimer == null || !_eventBufferTimer!.isActive) {
      _eventBufferTimer = Timer(eventBufferDuration, _flushEventBuffer);
    }
  }

  /// 刷新事件缓冲区
  void _flushEventBuffer() {
    if (_eventBuffer.isEmpty) return;

    final events = List<Aria2EventData>.from(_eventBuffer);
    _eventBuffer.clear();

    _logger.log(
      Level.info,
      '[Aria2WebSocket] Flushing ${events.length} buffered events',
    );

    onBatchEvents?.call(events);
  }

  /// 解析事件类型
  Aria2Event? _parseEventType(String method) {
    switch (method) {
      case 'aria2.onDownloadStart':
        return Aria2Event.downloadStart;
      case 'aria2.onDownloadPause':
        return Aria2Event.downloadPause;
      case 'aria2.onDownloadStop':
        return Aria2Event.downloadStop;
      case 'aria2.onDownloadComplete':
        return Aria2Event.downloadComplete;
      case 'aria2.onDownloadError':
        return Aria2Event.downloadError;
      case 'aria2.onBtDownloadComplete':
        return Aria2Event.btDownloadComplete;
      default:
        return null;
    }
  }

  /// WebSocket 错误处理
  void _onWebSocketError(dynamic error) {
    if (_isDisposed) return;

    _logger.log(Level.warning, '[Aria2WebSocket] WebSocket error: $error');
    _updateConnectionState(Aria2ConnectionState.error);
    onError?.call(error);
  }

  /// WebSocket 连接关闭处理
  void _onWebSocketDone() {
    if (_isDisposed) return;

    _logger.log(Level.warning, '[Aria2WebSocket] Connection closed');
    _updateConnectionState(Aria2ConnectionState.disconnected);
    _stopHeartbeat();

    // 刷新剩余的缓冲事件
    _flushEventBuffer();

    onDisconnected?.call();

    // 自动重连
    _scheduleReconnect();
  }

  /// 安排重连（使用指数退避）
  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer?.isActive ?? false) return;

    if (_reconnectAttempts >= maxReconnectAttempts) {
      _logger.log(
        Level.error,
        '[Aria2WebSocket] Max reconnect attempts ($maxReconnectAttempts) reached',
      );
      _updateConnectionState(Aria2ConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    _updateConnectionState(Aria2ConnectionState.reconnecting);

    // 指数退避：delay = min(initialDelay * 2^attempts, maxDelay)
    final delayMs =
        (initialReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1)))
            .clamp(
      initialReconnectDelay.inMilliseconds,
      maxReconnectDelay.inMilliseconds,
    );
    final delay = Duration(milliseconds: delayMs);

    _logger.log(
      Level.info,
      '[Aria2WebSocket] Scheduling reconnect attempt $_reconnectAttempts/$maxReconnectAttempts in ${delay.inSeconds}s',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        connect().catchError((e) {
          // 捕获定时重连时的异常，避免未处理的全局异常
        });
      }
    });
  }

  /// 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (isConnected && !_isDisposed) {
        _checkHeartbeat();
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 检查心跳状态
  void _checkHeartbeat() {
    final now = DateTime.now();

    // 检查是否太久没有收到消息
    if (_lastMessageReceived != null) {
      final timeSinceLastMessage = now.difference(_lastMessageReceived!);
      if (timeSinceLastMessage > heartbeatInterval * 2) {
        _logger.log(
          Level.warning,
          '[Aria2WebSocket] No message received for ${timeSinceLastMessage.inSeconds}s, reconnecting...',
        );
        disconnect();
        connect();
        return;
      }
    }

    // 发送心跳
    _sendHeartbeat();
  }

  /// 发送心跳（调用 aria2.getVersion 作为心跳）
  void _sendHeartbeat() {
    if (!isConnected || _channel == null) return;

    try {
      final secret = _getSecret();
      final params = secret != null ? ['token:$secret'] : [];

      final request = {
        'jsonrpc': '2.0',
        'id': 'heartbeat_${DateTime.now().millisecondsSinceEpoch}',
        'method': 'aria2.getVersion',
        'params': params,
      };

      _channel!.sink.add(jsonEncode(request));
      _lastHeartbeatSent = DateTime.now();

      // _logger.log(Level.debug, '[Aria2WebSocket] Heartbeat sent');
    } catch (e) {
      _logger.log(Level.warning, '[Aria2WebSocket] Heartbeat failed: $e');
    }
  }

  /// 手动重置重连计数（当外部确认连接正常时调用）
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
    _logger.log(Level.info, '[Aria2WebSocket] Reconnect attempts reset');
  }

  /// 强制刷新事件缓冲区
  void forceFlushEventBuffer() {
    _flushEventBuffer();
  }

  /// 断开连接
  void disconnect() {
    _logger.log(Level.info, '[Aria2WebSocket] Disconnecting...');

    // 刷新剩余的缓冲事件
    _flushEventBuffer();

    _updateConnectionState(Aria2ConnectionState.disconnected);
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _eventBufferTimer?.cancel();
    _eventBufferTimer = null;

    try {
      _channel?.sink.close();
    } catch (e) {
      _logger.log(Level.warning, '[Aria2WebSocket] Error closing channel: $e');
    }

    _channel = null;
  }

  /// 释放资源
  void dispose() {
    _logger.log(Level.info, '[Aria2WebSocket] Disposing...');
    _isDisposed = true;

    disconnect();

    // 关闭状态流
    _stateController.close();
  }

  /// 获取连接统计信息
  Map<String, dynamic> getStats() {
    return {
      'connectionState': _connectionState.toString(),
      'isConnected': isConnected,
      'reconnectAttempts': _reconnectAttempts,
      'lastHeartbeatSent': _lastHeartbeatSent?.toIso8601String(),
      'lastMessageReceived': _lastMessageReceived?.toIso8601String(),
      'bufferedEvents': _eventBuffer.length,
    };
  }
}
