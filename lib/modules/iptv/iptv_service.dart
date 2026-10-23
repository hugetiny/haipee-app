import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// IPTV 电视频道模型
class IptvChannel {
  final String name;
  final String group;
  final String logo;
  final String url;
  final String tvgId;

  const IptvChannel({
    required this.name,
    required this.group,
    required this.logo,
    required this.url,
    this.tvgId = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'group': group,
        'logo': logo,
        'url': url,
        'tvgId': tvgId,
      };
}

/// 全球标准 IPTV / M3U8 电视直播流与轮播流服务
/// 支持 M3U 标准解析、流媒体缓存、频道模糊检索及分组选集生成
class IptvService {
  static final Map<String, List<IptvChannel>> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// 纯文本 M3U / M3U8 解析器
  static List<IptvChannel> parseM3u(String content) {
    final List<IptvChannel> channels = [];
    final lines = LineSplitter.split(content).toList();

    String currentName = '';
    String currentGroup = '直播频道';
    String currentLogo = '';
    String currentTvgId = '';

    final tvgNameRegex = RegExp(r'tvg-name="([^"]+)"', caseSensitive: false);
    final tvgLogoRegex = RegExp(r'tvg-logo="([^"]+)"', caseSensitive: false);
    final groupTitleRegex = RegExp(r'group-title="([^"]+)"', caseSensitive: false);
    final tvgIdRegex = RegExp(r'tvg-id="([^"]+)"', caseSensitive: false);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // 提取属性
        final tvgNameMatch = tvgNameRegex.firstMatch(line);
        final tvgLogoMatch = tvgLogoRegex.firstMatch(line);
        final groupTitleMatch = groupTitleRegex.firstMatch(line);
        final tvgIdMatch = tvgIdRegex.firstMatch(line);

        currentGroup = groupTitleMatch?.group(1)?.trim() ?? '直播频道';
        currentLogo = tvgLogoMatch?.group(1)?.trim() ?? '';
        currentTvgId = tvgIdMatch?.group(1)?.trim() ?? '';

        // 提取逗号后面的频道名称
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex + 1 < line.length) {
          currentName = line.substring(commaIndex + 1).trim();
        } else {
          currentName = tvgNameMatch?.group(1)?.trim() ?? '未命名频道';
        }
      } else if (!line.startsWith('#')) {
        // 这一行是流媒体播放 URL
        if (currentName.isNotEmpty && (line.startsWith('http://') || line.startsWith('https://') || line.startsWith('rtmp://'))) {
          channels.add(IptvChannel(
            name: currentName,
            group: currentGroup,
            logo: currentLogo,
            url: line,
            tvgId: currentTvgId,
          ));
        }
        currentName = '';
        currentLogo = '';
        currentTvgId = '';
        currentGroup = '直播频道';
      }
    }

    return channels;
  }

  /// 拉取并缓存 M3U 列表
  static Future<List<IptvChannel>> getChannels(String m3uUrl) async {
    final cleanUrl = m3uUrl.trim();
    if (cleanUrl.isEmpty) return const [];

    final now = DateTime.now();
    if (_cache.containsKey(cleanUrl) &&
        _cacheTime.containsKey(cleanUrl) &&
        now.difference(_cacheTime[cleanUrl]!) < _cacheDuration) {
      return _cache[cleanUrl]!;
    }

    try {
      final resp = await Request().get(
        cleanUrl,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Kazumi/IPTV; Player)',
            'Accept': '*/*',
          },
        ),
      );
      final content = resp.data.toString();
      final channels = parseM3u(content);
      if (channels.isNotEmpty) {
        _cache[cleanUrl] = channels;
        _cacheTime[cleanUrl] = now;
      }
      return channels;
    } catch (e) {
      KazumiLogger().log(Level.warning, '拉取 IPTV 订阅失败: $cleanUrl, error: $e');
      if (_cache.containsKey(cleanUrl)) {
        return _cache[cleanUrl]!;
      }
      return const [];
    }
  }

  /// 搜索频道
  static Future<PluginSearchResponse> searchChannels(
    String pluginName,
    String m3uUrl,
    String keyword,
  ) async {
    final channels = await getChannels(m3uUrl);
    final cleanKw = keyword.trim().toLowerCase();

    List<IptvChannel> filtered;
    if (cleanKw.isEmpty || cleanKw == '*' || cleanKw == '@keyword') {
      filtered = channels.take(50).toList();
    } else {
      filtered = channels.where((c) {
        return c.name.toLowerCase().contains(cleanKw) ||
            c.group.toLowerCase().contains(cleanKw);
      }).toList();
    }

    final items = filtered.map((c) {
      return SearchItem(
        name: c.name,
        src: c.url,
        pic: c.logo,
        remarks: c.group,
      );
    }).toList();

    return PluginSearchResponse(pluginName: pluginName, data: items);
  }

  /// 根据选中的频道生成播放线路
  static Future<List<Road>> queryChapterRoads(
    String m3uUrl,
    String selectedUrl,
  ) async {
    final channels = await getChannels(m3uUrl);
    IptvChannel? current;
    try {
      current = channels.firstWhere((c) => c.url == selectedUrl);
    } catch (_) {}

    // 如果找到了当前频道的分组，将同分组的所有频道作为相关频道线路
    if (current != null) {
      final sameGroup = channels.where((c) => c.group == current!.group).toList();
      return [
        Road(
          name: '${current.group} (当前频道)',
          data: [current.url],
          identifier: [current.name],
        ),
        if (sameGroup.length > 1)
          Road(
            name: '${current.group} (同组全部频道)',
            data: sameGroup.map((c) => c.url).toList(),
            identifier: sameGroup.map((c) => c.name).toList(),
          ),
      ];
    }

    // 单流回退
    return [
      Road(
        name: '直播原画',
        data: [selectedUrl],
        identifier: ['实时直播流'],
      ),
    ];
  }
}
