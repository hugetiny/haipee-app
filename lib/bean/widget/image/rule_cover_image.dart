import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:haipee/plugins/rule_cover_extractor.dart';

/// 强韧媒体封面 HTTP 客户端 (Resilient Cover HTTP Client)
/// 解决第三方规则源（Haipee、MacCMS、TVBox）图片 CDN 的三大高频痛点：
/// 1. 采集站图片域名 SSL 证书过期或域名不匹配 (如 img.guangsuimage.com 绑定 image.jinyingimage.com)
/// 2. 采集站接口返回 https:// 地址，但图片服务器仅开启 80 端口未配置 443 TLS (如 fffgood.com)，需自动降级 http://
/// 3. 防盗链 Referer 校验与域名劫持返回 text/html 伪装 200 导致 Flutter 图片解码器崩溃
class ResilientCoverHttpClient extends http.BaseClient {
  final http.Client _inner;

  ResilientCoverHttpClient({http.Client? innerClient})
      : _inner = innerClient ?? _createDefaultIoClient();

  static http.Client _createDefaultIoClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // 允许加载第三方影视采集站证书域名不匹配或自签名的静态海报图
        return true;
      };
    return IOClient(ioClient);
  }

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final targetUri = request.url;

    // 1. 首次尝试原始请求
    try {
      final primaryResp = await _sendSingleGet(targetUri, baseHeaders: request.headers);
      if (_isValidImageResponse(primaryResp)) {
        return primaryResp;
      }

      // 若触发 403/401 防盗链，尝试补充同源 Referer 重试
      if (primaryResp.statusCode == 403 || primaryResp.statusCode == 401) {
        final originReferer = '${targetUri.scheme}://${targetUri.host}/';
        final retryHeaders = Map<String, String>.from(request.headers)
          ..['Referer'] = originReferer;
        final refererResp = await _sendSingleGet(targetUri, baseHeaders: retryHeaders);
        if (_isValidImageResponse(refererResp)) {
          return refererResp;
        }
      }
    } catch (_) {
      // 忽略首次连接/TLS握手异常，继续进入协议降级流程
    }

    // 2. 自动协议降级：当 https:// 握手失败或返回非图片状态时，自动降级为 http:// 重试
    if (targetUri.scheme == 'https') {
      final downgradedUri = targetUri.replace(scheme: 'http');
      try {
        final downgradedResp =
            await _sendSingleGet(downgradedUri, baseHeaders: request.headers);
        if (_isValidImageResponse(downgradedResp)) {
          return downgradedResp;
        }
      } catch (_) {}
    }

    // 3. 若均失败或遭遇运营商 text/html 劫持，返回干净的 404 避免缓存脏数据或引发图片解码异常
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      404,
      request: request,
      headers: const {'content-type': 'text/plain'},
    );
  }

  Future<http.StreamedResponse> _sendSingleGet(
    Uri uri, {
    required Map<String, String> baseHeaders,
  }) async {
    final req = http.Request('GET', uri);
    req.followRedirects = true;
    req.maxRedirects = 4;
    req.headers.addAll(baseHeaders);
    req.headers.putIfAbsent('User-Agent', () => _defaultUserAgent);
    req.headers.putIfAbsent(
      'Accept',
      () => 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    );
    return _inner.send(req).timeout(const Duration(seconds: 7));
  }

  static bool _isValidImageResponse(http.StreamedResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    // 拦截域名过期/劫持后返回的 200 OK text/html 错误页，防止引发 Invalid image data 异常
    if (contentType.contains('text/html') || contentType.contains('application/json')) {
      return false;
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > 0 && contentLength < 64) {
      // 小于 64 字节通常是 1x1 空白或错误文本
      return false;
    }
    return true;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// 规则封面专用缓存管理器
class RuleCoverCacheManager {
  static const String key = 'haipeeRuleCoverCache';

  static CacheManager? _instance;

  static CacheManager get instance {
    return _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 600,
        fileService: HttpFileService(
          httpClient: ResilientCoverHttpClient(),
        ),
      ),
    );
  }
}

/// 统一规则封面渲染组件 (RuleCoverImage)
/// 支持：
/// 1. 主封面 URL 加载（内置 SSL 容错与 HTTPS -> HTTP 自动降级）
/// 2. 跨源协同备用封面 URL (fallbackImageUrl) 自动无缝切换
/// 3. 优雅的 Material 3 渐变海报占位卡片兜底
class RuleCoverImage extends StatefulWidget {
  final String imageUrl;
  final String fallbackImageUrl;
  final String title;
  final String? ruleTag;
  final BoxFit fit;
  final double iconSize;

  const RuleCoverImage({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl = '',
    this.title = '',
    this.ruleTag,
    this.fit = BoxFit.cover,
    this.iconSize = 30,
  });

  @override
  State<RuleCoverImage> createState() => _RuleCoverImageState();
}

class _RuleCoverImageState extends State<RuleCoverImage> {
  bool _primaryFailed = false;

  @override
  void didUpdateWidget(covariant RuleCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _primaryFailed = false;
    }
  }

  List<String> _buildCandidateUrls() {
    final candidates = <String>[];
    final primary = widget.imageUrl.trim();
    final fallback = widget.fallbackImageUrl.trim();
    if (primary.isNotEmpty && !RuleCoverExtractor.isPlaceholderImageUrl(primary)) {
      candidates.add(primary);
    }
    if (fallback.isNotEmpty &&
        fallback != primary &&
        !RuleCoverExtractor.isPlaceholderImageUrl(fallback)) {
      candidates.add(fallback);
    }
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _buildCandidateUrls();
    if (candidates.isEmpty) {
      return _buildM3PosterFallback(context);
    }

    final activeIndex = (_primaryFailed && candidates.length > 1) ? 1 : 0;
    final activeUrl = candidates[activeIndex];

    // 无头 Widget 测试环境下避免后台网络 IO 挂起
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isFlutterTest) {
      return _buildM3PosterFallback(context, resolvedUrl: activeUrl);
    }

    return CachedNetworkImage(
      key: ValueKey<String>(activeUrl),
      imageUrl: activeUrl,
      cacheManager: RuleCoverCacheManager.instance,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, url) => _buildLoadingPlaceholder(context),
      errorWidget: (context, url, error) {
        if (!_primaryFailed && candidates.length > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_primaryFailed) {
              setState(() {
                _primaryFailed = true;
              });
            }
          });
          return _buildLoadingPlaceholder(context);
        }
        return _buildM3PosterFallback(context);
      },
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildM3PosterFallback(BuildContext context, {String? resolvedUrl}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: resolvedUrl != null
          ? ValueKey<String>('rule_cover_resolved_$resolvedUrl')
          : const ValueKey<String>('rule_cover_m3_fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.primaryContainer.withValues(alpha: 0.45),
            colorScheme.secondaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.movie_filter_rounded,
            size: widget.iconSize,
            color: colorScheme.primary.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}
