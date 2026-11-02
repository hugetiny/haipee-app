import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:haipee/modules/roads/road_module.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// Piped / Invidious 开放流媒体服务 (全球最大视频分享平台开源实现规范)
/// 免官方 API Key、免地域限制、提供纯 Dart REST 的 YouTube 1080P/720P DASH/HLS 直链播放
class PipedService {
  static const String defaultApi = 'https://pipedapi.kavin.rocks';

  /// 搜索 YouTube 视频
  static Future<PluginSearchResponse> search(
    String pluginName,
    String apiHost,
    String keyword,
  ) async {
    final cleanHost = apiHost.isNotEmpty
        ? (apiHost.endsWith('/') ? apiHost.substring(0, apiHost.length - 1) : apiHost)
        : defaultApi;
    final cleanKw = keyword.trim();
    if (cleanKw.isEmpty) {
      return PluginSearchResponse(pluginName: pluginName, data: const []);
    }

    try {
      final resp = await Request().get(
        '$cleanHost/search?q=${Uri.encodeComponent(cleanKw)}&filter=videos',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Haipee/Piped)',
          },
        ),
      );

      dynamic data = resp.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      final List<SearchItem> items = [];
      if (data is Map && data['items'] is List) {
        for (final item in data['items'] as List) {
          if (item is! Map) continue;
          final title = item['title']?.toString().trim() ?? '';
          final rawUrl = item['url']?.toString() ?? '';
          final thumbnail = item['thumbnail']?.toString() ?? '';
          final uploader = item['uploaderName']?.toString() ?? '';

          if (title.isEmpty || rawUrl.isEmpty) continue;

          // 提取 videoId (例如 /watch?v=xxx 或 xxx)
          String videoId = rawUrl;
          if (videoId.contains('v=')) {
            videoId = Uri.parse('https://dummy.com$rawUrl').queryParameters['v'] ?? videoId;
          } else if (videoId.startsWith('/watch/')) {
            videoId = videoId.replaceFirst('/watch/', '');
          }

          items.add(SearchItem(
            name: title,
            src: videoId,
            pic: thumbnail,
            remarks: uploader,
          ));
        }
      }

      return PluginSearchResponse(pluginName: pluginName, data: items);
    } catch (e) {
      HaipeeLogger().log(Level.warning, 'Piped 搜索失败: $e');
      return PluginSearchResponse(pluginName: pluginName, data: const []);
    }
  }

  /// 获取 YouTube 视频原画及多清晰度播放流
  static Future<List<Road>> queryChapterRoads(
    String apiHost,
    String videoIdOrUrl,
  ) async {
    final cleanHost = apiHost.isNotEmpty
        ? (apiHost.endsWith('/') ? apiHost.substring(0, apiHost.length - 1) : apiHost)
        : defaultApi;

    String videoId = videoIdOrUrl.trim();
    if (videoId.contains('v=')) {
      videoId = Uri.parse(videoId.startsWith('http') ? videoId : 'https://dummy.com$videoId')
              .queryParameters['v'] ??
          videoId;
    } else if (videoId.startsWith('/watch/')) {
      videoId = videoId.replaceFirst('/watch/', '');
    }

    try {
      final resp = await Request().get(
        '$cleanHost/streams/$videoId',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Haipee/Piped)',
          },
        ),
      );

      dynamic data = resp.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map) {
        final List<Road> roads = [];

        // 1. 优先提取 HLS 自适应多码率流 (最稳定)
        final hlsUrl = data['hls']?.toString();
        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          roads.add(Road(
            name: 'HLS 自动多码率原画',
            data: [hlsUrl],
            identifier: ['自适应高清'],
          ));
        }

        // 2. 提取 MP4/WebM 独立音视频直链
        if (data['videoStreams'] is List) {
          final List<String> streamUrls = [];
          final List<String> qualityNames = [];

          for (final vs in data['videoStreams'] as List) {
            if (vs is! Map) continue;
            final url = vs['url']?.toString() ?? '';
            final quality = vs['quality']?.toString() ?? '';
            final format = vs['format']?.toString() ?? '';
            final isVideoOnly = vs['videoOnly'] == true;

            // 优先选择包含完整音视频的轨道
            if (url.isNotEmpty && (!isVideoOnly || roads.isEmpty)) {
              streamUrls.add(url);
              qualityNames.add('$quality ($format)');
            }
          }

          if (streamUrls.isNotEmpty) {
            roads.add(Road(
              name: 'MP4 直链流',
              data: streamUrls,
              identifier: qualityNames,
            ));
          }
        }

        if (roads.isNotEmpty) {
          return roads;
        }
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, 'Piped 解析流媒体失败: $e');
    }

    return [];
  }
}
