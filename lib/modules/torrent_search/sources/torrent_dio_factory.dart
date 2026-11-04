import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:haipee/request/core/network_config.dart';
import 'package:haipee/services/network/system_proxy_service.dart';

/// 统一创建适用于 BT 索引器与公网爬虫的 Dio 实例
/// 自动集成用户配置的代理服务、系统代理并允许公网自签名/不受信证书
class TorrentDioFactory {
  static Dio create({
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 12),
    Map<String, dynamic>? headers,
  }) {
    final config = NetworkConfig.fromSettings();
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: headers,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (config.hasProxy) {
          client.findProxy = (_) => 'PROXY ${config.proxyHost}:${config.proxyPort}';
        } else if (Platform.isWindows) {
          client.findProxy = SystemProxyService.findProxy;
        }
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    return dio;
  }
}
