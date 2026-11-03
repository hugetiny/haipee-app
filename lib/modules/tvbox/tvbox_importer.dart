import 'dart:convert';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// TVBox / FongMi (蜂蜜) 规范解析与一键规则转换器
/// 负责将国内最庞大的电视盒/播放器规则规范无缝转换为 Haipee 统一插件规范
class TvBoxImporter {
  /// 判断给定文本是否为 TVBox / FongMi 规范订阅或配置
  static bool isTvBoxConfig(String content) {
    final clean = content.trim();
    if (!clean.startsWith('{') || !clean.endsWith('}')) {
      return false;
    }
    try {
      final decoded = jsonDecode(clean);
      if (decoded is Map) {
        if (decoded.containsKey('sites') && decoded['sites'] is List) {
          return true;
        }
        if (decoded.containsKey('spider') || decoded.containsKey('wallpaper')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// 将 TVBox 配置中的所有站点提取并转换为 Haipee 规则列表
  static List<Plugin> convertToPlugins(String content) {
    final clean = content.trim();
    if (clean.isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(clean);
    } catch (e) {
      HaipeeLogger().log(Level.warning, 'TVBox 配置 JSON 解码失败: $e');
      return const [];
    }

    if (decoded is! Map) return const [];

    final sites = decoded['sites'];
    if (sites is! List) return const [];

    final List<Plugin> plugins = [];

    for (final item in sites) {
      if (item is! Map) continue;

      final name = item['name']?.toString().trim() ?? '';
      final api = item['api']?.toString().trim() ?? '';
      final typeVal = item['type'];
      final searchable = item['searchable'];

      // 跳过明确不可搜索或没有 API 地址的空站
      if (name.isEmpty || api.isEmpty || searchable == 0) {
        continue;
      }

      int siteType = 1;
      if (typeVal is num) {
        siteType = typeVal.toInt();
      } else if (typeVal is String) {
        siteType = int.tryParse(typeVal) ?? 1;
      }

      Plugin? plugin;

      // TVBox Type 0/1: MacCMS 苹果采集站标准接口 (XML / JSON)
      if (siteType == 0 || siteType == 1) {
        String cleanApi = api;
        if (!cleanApi.startsWith('http://') && !cleanApi.startsWith('https://')) {
          cleanApi = 'https://$cleanApi';
        }

        String searchUrl = cleanApi;
        if (!searchUrl.contains('/api.php/provide/vod')) {
          searchUrl = searchUrl.endsWith('/')
              ? '${searchUrl}api.php/provide/vod/'
              : '$searchUrl/api.php/provide/vod/';
        }
        final connector = searchUrl.contains('?') ? '&' : '?';
        searchUrl = '$searchUrl${connector}ac=detail&at=json&wd=@keyword';

        plugin = Plugin(
          api: '1',
          type: '2', // Haipee MacCMS 标准协议
          name: name,
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: 'Mozilla/5.0 (Haipee/TVBox)',
          baseUrl: cleanApi,
          searchURL: searchUrl,
          searchList: '',
          searchName: 'vod_name',
          searchResult: 'vod_id',
          chapterRoads: '',
          chapterResult: '',
          referer: cleanApi,
          searchPic: 'vod_pic',
        );
      }
      // TVBox Type 4: AList 聚合网盘源
      else if (siteType == 4) {
        String cleanApi = api;
        if (!cleanApi.startsWith('http://') && !cleanApi.startsWith('https://')) {
          cleanApi = 'https://$cleanApi';
        }
        plugin = Plugin(
          api: '1',
          type: 'alist',
          name: name,
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: 'Mozilla/5.0 (Haipee/AList)',
          baseUrl: cleanApi,
          searchURL: cleanApi,
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: cleanApi,
        );
      }

      if (plugin != null) {
        plugins.add(plugin);
      }
    }

    HaipeeLogger().log(Level.info, '从 TVBox 配置成功解析并转换 ${plugins.length} 个规则');
    return plugins;
  }
}
