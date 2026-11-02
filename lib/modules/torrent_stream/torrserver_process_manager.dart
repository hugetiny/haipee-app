import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/services/logging/app_log.dart' hide HaipeeLogger;
import 'package:haipee/services/logging/log_module.dart';
import 'package:logger/logger.dart';

/// 专为流媒体在线播放设计的 TorrServer (MatriX) 本地子进程管理器。
///
/// 核心特性：
/// 1. 自动感知与复用已运行的 TorrServer（支持局域网 NAS / 本地已有服务）；
/// 2. 自动从资产目录解压并托管独立的 TorrServer 二进制；
/// 3. 毫秒级健康探测与安全就绪检查；
/// 4. 纯内存环形缓冲区支持，零磁盘磨损。
class TorrServerProcessManager {
  static final TorrServerProcessManager instance = TorrServerProcessManager._internal();
  factory TorrServerProcessManager() => instance;
  TorrServerProcessManager._internal();

  static const int defaultPort = 8090;

  Process? _process;
  bool _isRunning = false;
  int _activePort = defaultPort;
  String _activeHost = '127.0.0.1';
  final HaipeeLogger _logger = HaipeeLogger();

  bool get isRunning => _isRunning;
  int get activePort => _activePort;
  String get activeHost => _activeHost;
  String get baseUrl => 'http://$_activeHost:$_activePort';

  /// 寻找可用的本地私有端口（优先 8090）
  static Future<int> findAvailablePort([int preferred = defaultPort]) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, preferred);
      final port = server.port;
      await server.close();
      return port;
    } catch (_) {
      try {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = server.port;
        await server.close();
        return port;
      } catch (_) {
        return preferred;
      }
    }
  }

  /// 探测指定端点是否为健康的 TorrServer
  static Future<bool> ping(String host, int port, {Duration timeout = const Duration(milliseconds: 600)}) async {
    try {
      final uri = Uri.parse('http://$host:$port/echo');
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode == 200 && (res.body.contains('MatriX') || res.body.isNotEmpty)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 启动并确保 TorrServer 服务就绪
  Future<bool> start() async {
    if (_isRunning) {
      if (await ping(_activeHost, _activePort)) {
        return true;
      }
      _isRunning = false;
      _process = null;
    }

    // 1. 检查用户设置中是否配置了自定义远端或本地 TorrServer 地址
    try {
      final customUrl = (GStorage.setting.get('customTorrServerUrl', defaultValue: '') as String).trim();
      if (customUrl.isNotEmpty) {
        final uri = Uri.tryParse(customUrl);
        if (uri != null && uri.host.isNotEmpty) {
          final port = uri.port > 0 ? uri.port : 8090;
          if (await ping(uri.host, port, timeout: const Duration(seconds: 1))) {
            _logger.log(Level.info, '[TorrServerProcessManager] Using configured TorrServer: $customUrl');
            _activeHost = uri.host;
            _activePort = port;
            _isRunning = true;
            return true;
          }
        }
      }
    } catch (_) {}

    // 2. 检查本地默认端口 8090 是否已有正在运行的 TorrServer
    if (await ping('127.0.0.1', defaultPort)) {
      _logger.log(Level.info, '[TorrServerProcessManager] Detected existing TorrServer running on 127.0.0.1:$defaultPort');
      _activeHost = '127.0.0.1';
      _activePort = defaultPort;
      _isRunning = true;
      return true;
    }

    // 3. 准备启动内嵌 TorrServer 二进制
    final binaryPath = await _findOrExtractBinary();
    if (binaryPath == null) {
      _logger.log(Level.error, '[TorrServerProcessManager] TorrServer binary not available on this platform/build');
      return false;
    }

    final dataDir = await _getDataDirectory();
    final assignedPort = await findAvailablePort(defaultPort);
    _activeHost = '127.0.0.1';
    _activePort = assignedPort;

    final args = [
      '-p',
      '$assignedPort',
      '-d',
      dataDir.path,
    ];

    _logger.log(Level.info, '[TorrServerProcessManager] Launching TorrServer: $binaryPath ${args.join(' ')}');

    try {
      _process = await Process.start(binaryPath, args);
      _isRunning = true;
    } catch (e) {
      _logger.log(Level.error, '[TorrServerProcessManager] Failed to launch process: $e');
      _isRunning = false;
      _process = null;
      return false;
    }

    _process!.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      final out = line.trim();
      if (out.isNotEmpty) {
        AppLog.d(LogModule.stream, '[TorrServer] $out');
      }
    });

    _process!.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      final err = line.trim();
      if (err.isNotEmpty) {
        AppLog.w(LogModule.stream, '[TorrServer] $err');
      }
    });

    _process!.exitCode.then((code) {
      if (code == 0) {
        AppLog.i(LogModule.stream, '[TorrServer] Process exited cleanly with code: 0');
      } else {
        AppLog.w(LogModule.stream, '[TorrServer] Process exited with code: $code');
      }
      _isRunning = false;
      _process = null;
    });

    // 4. 等待服务就绪（健康检查，最多 5 秒）
    for (int i = 0; i < 25; i++) {
      if (!_isRunning) break;
      if (await ping('127.0.0.1', assignedPort, timeout: const Duration(milliseconds: 300))) {
        _logger.log(Level.info, '[TorrServerProcessManager] TorrServer is healthy and ready on 127.0.0.1:$assignedPort');
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _logger.log(Level.error, '[TorrServerProcessManager] TorrServer failed health check on 127.0.0.1:$assignedPort');
    stop();
    return false;
  }

  /// 停止托管的子进程
  void stop() {
    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
      } catch (_) {}
      _process = null;
    }
    _isRunning = false;
  }

  /// 查找或提取 TorrServer 二进制路径
  Future<String?> _findOrExtractBinary() async {
    // 优先检查系统 PATH
    try {
      final res = await Process.run('which', ['torrserver']);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        final path = res.stdout.toString().trim();
        if (File(path).existsSync()) return path;
      }
    } catch (_) {}

    // 检查 AppSupport 目录
    String subPath = '';
    String binaryName = 'torrserver';
    if (Platform.isMacOS) {
      subPath = 'macos';
      binaryName = 'torrserver';
    } else if (Platform.isWindows) {
      subPath = 'windows';
      binaryName = 'torrserver.exe';
    } else if (Platform.isLinux) {
      subPath = 'linux';
      binaryName = 'torrserver';
    } else {
      return null;
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final targetFile = File('${appDir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}$binaryName');

      if (!await targetFile.exists()) {
        final assetPath = 'assets/bin/$subPath/$binaryName';
        _logger.log(Level.info, '[TorrServerProcessManager] Extracting bundled asset: $assetPath -> ${targetFile.path}');
        await targetFile.parent.create(recursive: true);
        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', targetFile.path]);
      }
      return targetFile.path;
    } catch (e) {
      _logger.log(Level.warning, '[TorrServerProcessManager] Could not extract asset binary: $e');
    }

    // 开发环境本地兜底：直接读取工程下的 assets/bin/macos/torrserver
    final devPath = 'assets/bin/$subPath/$binaryName';
    final devFile = File(devPath);
    if (devFile.existsSync()) {
      return devFile.absolute.path;
    }

    return null;
  }

  /// 获取持久化数据目录并确保已创建
  Future<Directory> _getDataDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}torrserver_data');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
