import 'dart:async';
import 'package:dio/dio.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// 全局最底层 GitHub 加速代理重写拦截器
///
/// 架构原则：
/// 1. 最底层拦截：无论 Haipee 视频规则（订阅/市场/更新）、Cardigann 种子规则（Prowlarr/Manifest）、
///    BT Tracker 列表获取，还是客户端版本检测，只要命中 GitHub 域名且开启了代理，底层自动重写。
/// 2. 动态可配置：实时读取用户在设置中自定义的代理前缀（默认为 https://ghfast.top/，支持自定义任意代理）。
/// 3. 防重复包装：智能检测请求路径，若已包含代理前缀则跳过，杜绝二次拼接导致 404。
class GitProxyInterceptor extends Interceptor {
  /// 推荐的高可用预置镜像列表
  static const List<String> defaultPresets = [
    'https://ghproxy.net/',
    'https://ghfast.top/',
    'https://mirror.ghproxy.com/',
    'https://gh-proxy.com/',
  ];

  static const String defaultProxyUrl = 'https://ghproxy.net/';

  /// 判定当前是否开启了 GitHub 代理
  static bool isEnabled() {
    try {
      final val = GStorage.setting.get(SettingBoxKey.enableGitProxy);
      if (val is bool) return val;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 切换开启状态
  static Future<void> setEnabled(bool value) async {
    await GStorage.setting.put(SettingBoxKey.enableGitProxy, value);
  }

  /// 获取当前生效的 GitHub 代理地址 (保证以 / 结尾)
  static String getEffectiveProxyUrl() {
    try {
      final custom = GStorage.setting.get(SettingBoxKey.gitProxyUrl);
      if (custom is String && custom.trim().isNotEmpty) {
        final trimmed = custom.trim();
        return trimmed.endsWith('/') ? trimmed : '$trimmed/';
      }
    } catch (_) {}
    return defaultProxyUrl;
  }

  /// 保存自定义的代理地址 (自动补全末尾斜杠)
  static Future<void> setProxyUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      await GStorage.setting.put(SettingBoxKey.gitProxyUrl, defaultProxyUrl);
      return;
    }
    final normalized = clean.endsWith('/') ? clean : '$clean/';
    await GStorage.setting.put(SettingBoxKey.gitProxyUrl, normalized);
  }

  /// 判定指定 URL 是否为 GitHub 托管资源
  static bool isGitHubUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    // 注意：api.github.com 为官方 REST API，第三方文件镜像（ghfast/ghproxy）不支持代理该 API，
    // 若重写会导致 "Invalid input." 导致更新检查失败。
    if (lower.contains('api.github.com')) return false;
    return lower.contains('github.com') ||
        lower.contains('raw.githubusercontent.com') ||
        lower.contains('gist.githubusercontent.com') ||
        lower.contains('objects.githubusercontent.com') ||
        lower.contains('github.io');
  }

  /// 对指定 URL 智能应用代理重写
  static String applyProxy(String url) {
    if (!isEnabled()) return url;
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return cleanUrl;

    final proxyUrl = getEffectiveProxyUrl();

    // 如果已经以任何预置镜像或当前生效镜像开头，则避免二次重写
    for (final preset in defaultPresets) {
      if (cleanUrl.startsWith(preset)) return cleanUrl;
    }
    if (cleanUrl.startsWith(proxyUrl)) return cleanUrl;

    if (isGitHubUrl(cleanUrl)) {
      final rewritten = '$proxyUrl$cleanUrl';
      HaipeeLogger().log(
        Level.info,
        '[GitProxy] 成功重写 GitHub 请求: $cleanUrl -> $rewritten',
      );
      return rewritten;
    }

    return cleanUrl;
  }

  /// 测试指定代理地址的连通性与往返延迟 (RTT)
  static Future<(bool success, int latencyMs, String message)> testLatency({
    String? targetProxyUrl,
  }) async {
    final effectiveProxy = (targetProxyUrl != null && targetProxyUrl.trim().isNotEmpty)
        ? (targetProxyUrl.trim().endsWith('/')
            ? targetProxyUrl.trim()
            : '${targetProxyUrl.trim()}/')
        : getEffectiveProxyUrl();

    // 探测测试目标：轻量级稳定 GitHub raw 文件
    const probeTarget = 'https://raw.githubusercontent.com/hugetiny/haipee-app/main/README.md';
    final requestUrl = '$effectiveProxy$probeTarget';

    final stopwatch = Stopwatch()..start();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': 'Mozilla/5.0 Haipee/ProxyProbe',
        },
      ),
    );

    try {
      final response = await dio.head(requestUrl);
      stopwatch.stop();
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400) {
        return (true, stopwatch.elapsedMilliseconds, '连通成功 · 延迟 ${stopwatch.elapsedMilliseconds}ms');
      }
      return (false, stopwatch.elapsedMilliseconds, 'HTTP 异常状态码: ${response.statusCode}');
    } catch (e) {
      // 部分镜像可能不支持 HEAD，尝试 GET 请求读取前 50 字节
      try {
        stopwatch.reset();
        stopwatch.start();
        final getRes = await dio.get(
          requestUrl,
          options: Options(
            headers: {'Range': 'bytes=0-50'},
          ),
        );
        stopwatch.stop();
        if (getRes.statusCode != null &&
            getRes.statusCode! >= 200 &&
            getRes.statusCode! < 400) {
          return (true, stopwatch.elapsedMilliseconds, '连通成功 · 延迟 ${stopwatch.elapsedMilliseconds}ms');
        }
        return (false, stopwatch.elapsedMilliseconds, '状态码: ${getRes.statusCode}');
      } catch (err) {
        stopwatch.stop();
        return (false, stopwatch.elapsedMilliseconds, '连接失败: $err');
      }
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isEnabled()) {
      if (options.path.startsWith('http://') || options.path.startsWith('https://')) {
        final rewritten = applyProxy(options.path);
        if (rewritten != options.path) {
          options.path = rewritten;
        }
      } else if (options.baseUrl.startsWith('http://') || options.baseUrl.startsWith('https://')) {
        if (isGitHubUrl(options.baseUrl)) {
          final rewrittenBase = applyProxy(options.baseUrl);
          if (rewrittenBase != options.baseUrl) {
            options.baseUrl = rewrittenBase;
          }
        }
      }
    }
    handler.next(options);
  }
}
