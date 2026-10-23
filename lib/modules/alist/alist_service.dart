import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// AList V3 开放网盘挂载服务
/// 支持阿里云盘、夸克网盘、115网盘、天翼云盘、WebDAV 及本地聚合存储的搜索、目录解析与直链播放
class AlistService {
  static final Set<String> _videoExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.flv',
    '.m3u8',
    '.ts',
    '.mov',
    '.webm',
    '.wmv',
  };

  static bool isVideoFile(String name) {
    final lower = name.toLowerCase();
    return _videoExtensions.any((ext) => lower.endsWith(ext));
  }

  /// 搜索 AList 挂载的影视资源
  static Future<PluginSearchResponse> search(
    String pluginName,
    String baseUrl,
    String keyword,
  ) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanKw = keyword.trim();
    if (cleanKw.isEmpty) {
      return PluginSearchResponse(pluginName: pluginName, data: const []);
    }

    try {
      final resp = await Request().post(
        '$cleanBase/api/fs/search',
        data: {
          'parent': '/',
          'keywords': cleanKw,
          'scope': 0,
          'page': 1,
          'per_page': 30,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
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
      if (data is Map && data['data'] is Map) {
        final content = data['data']['content'];
        if (content is List) {
          for (final item in content) {
            if (item is! Map) continue;
            final name = item['name']?.toString() ?? '';
            final parent = item['parent']?.toString() ?? '/';
            final isDir = item['is_dir'] == true;
            final thumb = item['thumb']?.toString() ?? '';

            if (name.isEmpty) continue;

            // 过滤：必须是文件夹或者是已知视频文件
            if (!isDir && !isVideoFile(name)) {
              continue;
            }

            final fullPath = parent.endsWith('/') ? '$parent$name' : '$parent/$name';

            String picUrl = thumb;
            if (picUrl.isNotEmpty && !picUrl.startsWith('http://') && !picUrl.startsWith('https://')) {
              picUrl = picUrl.startsWith('/') ? '$cleanBase$picUrl' : '$cleanBase/$picUrl';
            }

            items.add(SearchItem(
              name: name,
              src: fullPath,
              pic: picUrl,
              remarks: isDir ? '影视合集' : '单视频',
            ));
          }
        }
      }

      return PluginSearchResponse(pluginName: pluginName, data: items);
    } catch (e) {
      KazumiLogger().log(Level.warning, 'AList 搜索异常: $e');
      return PluginSearchResponse(pluginName: pluginName, data: const []);
    }
  }

  /// 获取选集与直链播放线路
  static Future<List<Road>> queryChapterRoads(
    String baseUrl,
    String path,
  ) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';

    // 1. 如果路径本身直接就是视频文件
    if (isVideoFile(cleanPath)) {
      final fileName = cleanPath.split('/').last;
      final directDownloadUrl = '$cleanBase/d$cleanPath';
      return [
        Road(
          name: 'AList 原画直链',
          data: [directDownloadUrl],
          identifier: [fileName],
        ),
      ];
    }

    // 2. 如果是文件夹，列出目录下的所有子视频文件
    try {
      final resp = await Request().post(
        '$cleanBase/api/fs/list',
        data: {
          'path': cleanPath,
          'password': '',
          'page': 1,
          'per_page': 100,
          'refresh': false,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      dynamic data = resp.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      final List<String> urls = [];
      final List<String> names = [];

      if (data is Map && data['data'] is Map) {
        final content = data['data']['content'];
        if (content is List) {
          for (final item in content) {
            if (item is! Map) continue;
            final name = item['name']?.toString() ?? '';
            final isDir = item['is_dir'] == true;
            if (!isDir && isVideoFile(name)) {
              final filePath = cleanPath.endsWith('/') ? '$cleanPath$name' : '$cleanPath/$name';
              final playUrl = '$cleanBase/d$filePath';
              names.add(name);
              urls.add(playUrl);
            }
          }
        }
      }

      if (urls.isNotEmpty) {
        return [
          Road(
            name: 'AList 网盘选集',
            data: urls,
            identifier: names,
          ),
        ];
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, 'AList 选集解析异常: $e');
    }

    // 降级：直接尝试作为文件播放
    return [
      Road(
        name: 'AList 原画直链',
        data: ['$cleanBase/d$cleanPath'],
        identifier: [cleanPath.split('/').last],
      ),
    ];
  }
}
