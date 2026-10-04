import 'package:kazumi/utils/aria2_process_manager.dart';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

int _parseMaxConcurrent(dynamic raw, {required int fallback}) {
  if (raw == null) {
    return fallback;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

int _normalizeMaxConcurrent(int value) {
  return value < 1 ? 1 : value;
}

class Aria2ConcurrencyConfig {
  const Aria2ConcurrencyConfig({required this.maxConcurrentDownloads});

  final int maxConcurrentDownloads;

  Aria2ConcurrencyConfig copyWith({int? maxConcurrentDownloads}) {
    return Aria2ConcurrencyConfig(
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
    );
  }

  Map<String, String> toOptionsPayload() {
    return <String, String>{
      'max-concurrent-downloads': maxConcurrentDownloads.toString(),
    };
  }

  static Aria2ConcurrencyConfig fromOptions(
    Map<String, dynamic> options, {
    required int fallback,
  }) {
    final dynamic raw = options['max-concurrent-downloads'];
    final int parsed = _normalizeMaxConcurrent(
      _parseMaxConcurrent(raw, fallback: fallback),
    );
    return Aria2ConcurrencyConfig(maxConcurrentDownloads: parsed);
  }
}

/// Exception thrown when aria2 RPC responds with an error or unexpected format.
class Aria2RpcException implements Exception {
  Aria2RpcException(this.message, {this.code});

  final String message;
  final dynamic code;

  @override
  String toString() => 'Aria2RpcException(code: $code, message: $message)';
}

/// Lightweight JSON-RPC client for talking to aria2.
///
/// The helper centralises token handling, basic logging, and exposes common
/// queue-management methods used throughout the download feature set.
class Aria2Client {
  Aria2Client({
    required Uri endpoint,
    String? secret,
    Duration timeout = const Duration(seconds: 15),
    Dio? httpClient,
    int maxConcurrentDownloads = _defaultMaxConcurrentDownloads,
  })  : _endpoint = endpoint,
        _secret =
            (secret == null || secret.trim().isEmpty) ? null : secret.trim(),
        _timeout = timeout,
        _maxConcurrentDownloads =
            _normalizeMaxConcurrent(maxConcurrentDownloads),
        _dio = httpClient ??
            Dio(
              BaseOptions(
                connectTimeout: timeout,
                receiveTimeout: timeout,
                sendTimeout: timeout,
                headers: const <String, String>{
                  'Content-Type': 'application/json',
                },
                responseType: ResponseType.json, // 强制 Dio 解析 JSON
              ),
            );

  factory Aria2Client.fromSettings() {
    final setting = GStorage.setting;
    String endpoint = (setting.get(SettingBoxKey.aria2Endpoint,
            defaultValue: _defaultEndpoint) as String)
        .trim();
    String secret =
        (setting.get(SettingBoxKey.aria2Secret, defaultValue: '') as String)
            .trim();

    // 如果是本地回环且存在动态分配的活跃私有端口，无缝对齐
    final dynamicPort = Aria2ProcessManager.activePort;
    final dynamicSecret = Aria2ProcessManager.activeSecret;
    if (dynamicPort != null && (endpoint.contains('127.0.0.1') || endpoint.contains('localhost'))) {
      final uri = Uri.parse(endpoint.isEmpty ? _defaultEndpoint : endpoint);
      endpoint = uri.replace(port: dynamicPort).toString();
      if (secret.isEmpty && dynamicSecret != null) {
        secret = dynamicSecret;
      }
    }
    final int timeoutSeconds =
        setting.get(SettingBoxKey.aria2TimeoutSeconds, defaultValue: 15) as int;
    final dynamic concurrencyRaw = setting.get(
      SettingBoxKey.aria2MaxConcurrentDownloads,
      defaultValue: _defaultMaxConcurrentDownloads,
    );
    final int maxConcurrentDownloads = _normalizeMaxConcurrent(
      _parseMaxConcurrent(
        concurrencyRaw,
        fallback: _defaultMaxConcurrentDownloads,
      ),
    );
    if (!setting.containsKey(SettingBoxKey.aria2MaxConcurrentDownloads)) {
      unawaited(setting.put(
        SettingBoxKey.aria2MaxConcurrentDownloads,
        maxConcurrentDownloads,
      ));
    }

    return Aria2Client(
      endpoint: Uri.parse(endpoint.isEmpty ? _defaultEndpoint : endpoint),
      secret: secret.isEmpty ? null : secret,
      timeout: Duration(seconds: timeoutSeconds.clamp(5, 120)),
      maxConcurrentDownloads: maxConcurrentDownloads,
    );
  }

  static const String _jsonRpcVersion = '2.0';
  static const String _defaultEndpoint = 'http://127.0.0.1:6800/jsonrpc';
  static const List<String> _defaultStatusKeys = <String>[
    'gid',
    'status',
    'totalLength',
    'completedLength',
    'downloadSpeed',
    'connections',
    'numSeeders',
    'errorCode',
    'errorMessage',
    'files',
    'bittorrent',
  ];
  static const int _defaultMaxConcurrentDownloads = 2;

  final Dio _dio;
  final Uri _endpoint;
  final String? _secret;
  final Duration _timeout;
  int _maxConcurrentDownloads;
  final KazumiLogger _logger = KazumiLogger();

  Uri get endpoint => _endpoint;

  bool get hasSecret => _secret?.isNotEmpty ?? false;

  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  Future<String?> addUri(
    List<String> uris, {
    Map<String, dynamic>? options,
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[uris];
    if (options != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    final dynamic result = await _call('aria2.addUri', params: params);
    return result as String?;
  }

  /// Add torrent file (base64 encoded) to download queue
  Future<String?> addTorrent(
    String torrentBase64, {
    List<String>? uris,
    Map<String, dynamic>? options,
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[torrentBase64];
    if (uris != null && uris.isNotEmpty) {
      params.add(uris);
    } else {
      params.add(<String>[]);
    }
    if (options != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    final dynamic result = await _call('aria2.addTorrent', params: params);
    return result as String?;
  }

  /// Add metalink file (base64 encoded) to download queue
  Future<List<String>?> addMetalink(
    String metalinkBase64, {
    Map<String, dynamic>? options,
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[metalinkBase64];
    if (options != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    final dynamic result = await _call('aria2.addMetalink', params: params);
    if (result is List) {
      return result.cast<String>();
    }
    return null;
  }

  Future<Map<String, dynamic>?> tellStatus(
    String gid, {
    List<String>? keys,
  }) async {
    final dynamic result = await _call('aria2.tellStatus',
        params: <dynamic>[gid, keys ?? _defaultStatusKeys]);
    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  Future<List<dynamic>> tellActive({List<String>? keys}) async {
    final dynamic result = await _call('aria2.tellActive',
        params: <dynamic>[keys ?? _defaultStatusKeys]);
    if (result is List<dynamic>) {
      return result;
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> tellWaiting(
    int offset,
    int num, {
    List<String>? keys,
  }) async {
    final dynamic result = await _call(
      'aria2.tellWaiting',
      params: <dynamic>[offset, num, keys ?? _defaultStatusKeys],
    );
    if (result is List<dynamic>) {
      return result;
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> tellStopped(
    int offset,
    int num, {
    List<String>? keys,
  }) async {
    final dynamic result = await _call(
      'aria2.tellStopped',
      params: <dynamic>[offset, num, keys ?? _defaultStatusKeys],
    );
    if (result is List<dynamic>) {
      return result;
    }
    return <dynamic>[];
  }

  Future<bool> pause(String gid, {bool force = false}) async {
    final String method = force ? 'aria2.forcePause' : 'aria2.pause';
    final dynamic result = await _call(method, params: <dynamic>[gid]);
    return result is String;
  }

  Future<bool> resume(String gid) async {
    final dynamic result = await _call('aria2.unpause', params: <dynamic>[gid]);
    return result is String;
  }

  Future<bool> remove(String gid, {bool force = false}) async {
    final String method = force ? 'aria2.forceRemove' : 'aria2.remove';
    final dynamic result = await _call(method, params: <dynamic>[gid]);
    return result is String;
  }

  Future<bool> purgeCompleted() async {
    final dynamic result = await _call('aria2.purgeDownloadResult');
    return result == 'OK';
  }

  /// Test if the aria2 RPC endpoint is accessible and responding correctly.
  /// This is more robust than tellActive() as it uses aria2.getVersion which
  /// always returns a response even when no downloads are active.
  Future<Map<String, dynamic>> getVersion() async {
    _logger.log(Level.info, '[Aria2Client] Calling aria2.getVersion');
    final dynamic result = await _call('aria2.getVersion');
    _logger.log(Level.info,
        '[Aria2Client] getVersion result type: ${result.runtimeType}');
    _logger.log(Level.info, '[Aria2Client] getVersion result: $result');

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    _logger.log(Level.error,
        '[Aria2Client] Unexpected response format from aria2.getVersion: $result');
    throw Aria2RpcException('Unexpected response format from aria2.getVersion');
  }

  /// Test the connection to aria2 RPC server.
  /// Returns a detailed status message.
  Future<String> testConnection() async {
    try {
      _logger.log(Level.info, '[Aria2Client] testConnection starting...');
      _logger.log(Level.info, '[Aria2Client] Endpoint: $_endpoint');
      _logger.log(Level.info, '[Aria2Client] Has secret: $hasSecret');

      final version = await getVersion();

      _logger.log(Level.info, '[Aria2Client] Version data received: $version');
      _logger.log(
          Level.info, '[Aria2Client] Version type: ${version.runtimeType}');
      _logger.log(
          Level.info, '[Aria2Client] Version keys: ${version.keys.toList()}');

      final versionStr = version['version'] as String? ?? 'unknown';
      _logger.log(Level.info, '[Aria2Client] Version string: $versionStr');

      final featuresRaw = version['enabledFeatures'];
      _logger.log(Level.info,
          '[Aria2Client] Features raw: $featuresRaw (type: ${featuresRaw.runtimeType})');

      final List<String> features =
          (featuresRaw as List?)?.cast<String>() ?? [];
      _logger.log(Level.info, '[Aria2Client] Features casted: $features');

      final result = '连接成功\n'
          'aria2 版本: $versionStr\n'
          '已启用特性: ${features.join(", ")}';

      _logger.log(Level.info, '[Aria2Client] testConnection successful');
      return result;
    } catch (e, stackTrace) {
      _logger.log(Level.error, '[Aria2Client] testConnection failed: $e',
          error: e, stackTrace: stackTrace);
      if (e is Aria2RpcException) {
        rethrow;
      }
      throw Aria2RpcException('测试连接失败: ${e.toString()}');
    }
  }

  Future<Aria2ConcurrencyConfig> getConcurrencyConfig() async {
    final dynamic result = await _call('aria2.getGlobalOption');
    if (result is Map) {
      return Aria2ConcurrencyConfig.fromOptions(
        Map<String, dynamic>.from(result),
        fallback: _maxConcurrentDownloads,
      );
    }
    return Aria2ConcurrencyConfig(
      maxConcurrentDownloads: _maxConcurrentDownloads,
    );
  }

  Future<int> ensureMaxConcurrentDownloads({
    int? limit,
    bool persistSetting = false,
    bool force = false,
  }) async {
    final int desired =
        _normalizeMaxConcurrent(limit ?? _maxConcurrentDownloads);
    if (limit != null) {
      _maxConcurrentDownloads = desired;
    }
    final Aria2ConcurrencyConfig remote = await getConcurrencyConfig();
    if (!force && remote.maxConcurrentDownloads == desired) {
      if (persistSetting && limit != null) {
        await GStorage.setting
            .put(SettingBoxKey.aria2MaxConcurrentDownloads, desired);
      }
      return remote.maxConcurrentDownloads;
    }
    await _applyConcurrencyLimit(desired);
    if (persistSetting) {
      await GStorage.setting
          .put(SettingBoxKey.aria2MaxConcurrentDownloads, desired);
    }
    return desired;
  }

  Future<void> setMaxConcurrentDownloads(
    int limit, {
    bool persistSetting = true,
    bool applyToDaemon = true,
  }) async {
    final int normalized = _normalizeMaxConcurrent(limit);
    _maxConcurrentDownloads = normalized;
    if (persistSetting) {
      await GStorage.setting
          .put(SettingBoxKey.aria2MaxConcurrentDownloads, normalized);
    }
    if (applyToDaemon) {
      await _applyConcurrencyLimit(normalized);
    }
  }

  Future<int> refreshMaxConcurrentDownloads(
      {bool persistSetting = false}) async {
    final Aria2ConcurrencyConfig remote = await getConcurrencyConfig();
    _maxConcurrentDownloads = remote.maxConcurrentDownloads;
    if (persistSetting) {
      await GStorage.setting.put(
          SettingBoxKey.aria2MaxConcurrentDownloads, _maxConcurrentDownloads);
    }
    return _maxConcurrentDownloads;
  }

  Future<dynamic> _call(
    String method, {
    List<dynamic>? params,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'jsonrpc': _jsonRpcVersion,
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'method': method,
      'params': _buildParams(params),
    };

    // 降低日志级别，避免刷屏
    // _logger.log(Level.info, '[Aria2Client] Calling $method');

    try {
      final Response<dynamic> response = await _dio.postUri(
        _endpoint,
        data: payload,
        options: Options(
          contentType: 'application/json',
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      // 只在调试时记录详细信息
      // _logger.log(Level.info, '[Aria2Client] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        _logger.log(
          Level.error,
          '[Aria2Client] $method HTTP error: ${response.statusCode}',
        );
        throw Aria2RpcException(
          'HTTP ${response.statusCode}: ${response.statusMessage ?? "Unknown error"}',
        );
      }

      if (response.data == null) {
        _logger.log(
          Level.error,
          '[Aria2Client] $method returned null response',
        );
        throw Aria2RpcException('aria2 服务未运行或端点地址错误');
      }

      // Handle both String (needs parsing) and Map (already parsed) responses
      Map<String, dynamic> body;

      if (response.data is String) {
        // Response is JSON string, need to parse it
        try {
          final parsed = jsonDecode(response.data as String);
          if (parsed is Map) {
            body = Map<String, dynamic>.from(parsed);
          } else {
            _logger.log(Level.error,
                '[Aria2Client] Parsed JSON is not a Map: ${parsed.runtimeType}');
            throw Aria2RpcException('aria2 响应格式错误');
          }
        } catch (e) {
          _logger.log(Level.error, '[Aria2Client] Failed to parse JSON: $e');
          throw Aria2RpcException('aria2 响应解析失败: $e');
        }
      } else if (response.data is Map<String, dynamic>) {
        body = Map<String, dynamic>.from(response.data as Map<String, dynamic>);
      } else if (response.data is Map) {
        // Handle generic Map
        body = Map<String, dynamic>.from(response.data as Map);
      } else {
        _logger.log(
          Level.error,
          '[Aria2Client] $method unexpected response type: ${response.data.runtimeType}',
        );
        throw Aria2RpcException(
          'aria2 服务未运行或端点地址错误（响应格式不正确）',
        );
      }

      _logger.log(Level.info,
          '[Aria2Client] Response body keys: ${body.keys.toList()}');

      if (body.containsKey('error') && body['error'] != null) {
        final Map<String, dynamic> error =
            Map<String, dynamic>.from(body['error'] as Map<String, dynamic>);
        final String message =
            error['message']?.toString() ?? 'aria2 RPC error';
        final dynamic code = error['code'];
        _logger.log(
          Level.error,
          '[Aria2Client] $method failed: $message (code: $code)',
        );
        throw Aria2RpcException(message, code: code);
      }

      _logger.log(
          Level.info, '[Aria2Client] Returning result: ${body['result']}');
      return body['result'];
    } catch (error, stackTrace) {
      if (error is Aria2RpcException) {
        rethrow;
      }

      // Handle DioException specifically
      if (error is DioException) {
        String message = 'aria2 连接失败';

        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            message = 'aria2 连接超时，请检查端点地址和网络';
            break;
          case DioExceptionType.badResponse:
            message = 'aria2 响应错误: ${error.response?.statusCode ?? "未知"}';
            break;
          case DioExceptionType.connectionError:
            message = '无法连接到 aria2 服务，请确保 aria2 已启动';
            break;
          case DioExceptionType.cancel:
            message = 'aria2 请求已取消';
            break;
          case DioExceptionType.unknown:
          default:
            if (error.message?.contains('Connection refused') ?? false) {
              message = '无法连接到 aria2 服务，请确保 aria2 已启动';
            } else if (error.message?.contains('SocketException') ?? false) {
              message = 'aria2 网络错误，请检查端点地址';
            } else {
              message = 'aria2 连接失败: ${error.message ?? "未知错误"}';
            }
            break;
        }

        _logger.log(
          Level.error,
          '[Aria2Client] $method request failed: $message',
          error: error,
          stackTrace: stackTrace,
        );
        throw Aria2RpcException(message);
      }

      _logger.log(
        Level.error,
        '[Aria2Client] $method RPC request failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      throw Aria2RpcException(error.toString());
    }
  }

  List<dynamic> _buildParams(List<dynamic>? params) {
    final List<dynamic> values = <dynamic>[];
    if (hasSecret) {
      values.add('token:$_secret');
    }
    if (params != null) {
      values.addAll(params);
    }
    return values;
  }

  Future<void> _applyConcurrencyLimit(int limit) async {
    final Aria2ConcurrencyConfig config =
        Aria2ConcurrencyConfig(maxConcurrentDownloads: limit);
    await _call(
      'aria2.changeGlobalOption',
      params: <dynamic>[config.toOptionsPayload()],
    );
    _logger.log(
      Level.info,
      '[Aria2Client] Set max concurrent downloads to $limit',
    );
  }
}
