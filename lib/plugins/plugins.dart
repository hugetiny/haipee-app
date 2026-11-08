import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/modules/roads/road_module.dart';
import 'package:haipee/request/request.dart';
import 'package:html/parser.dart';
import 'package:logger/logger.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/utils/logger.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:haipee/utils/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';
import 'package:haipee/modules/tvbox/tvbox_importer.dart';
import 'package:haipee/modules/iptv/iptv_service.dart';
import 'package:haipee/modules/alist/alist_service.dart';
import 'package:haipee/modules/piped/piped_service.dart';
import 'package:haipee/plugins/rule_cover_extractor.dart';

/// 规则与媒体源一级分类枚举 (四大分类架构，网盘与BT明确归属为资源类/下载类)
enum PluginCategory {
  video(
    id: 'video',
    label: '在线视频',
    groupLabel: '视听在线',
    isResource: false,
    isDownloadable: false,
  ),
  live(
    id: 'live',
    label: '电视直播',
    groupLabel: '视听在线',
    isResource: false,
    isDownloadable: false,
  ),
  drive(
    id: 'drive',
    label: '网盘资源',
    groupLabel: '资源下载',
    isResource: true, // 特殊归属：属于资源类，也就是下载类
    isDownloadable: true,
  ),
  bt(
    id: 'bt',
    label: 'BT磁力',
    groupLabel: '资源下载',
    isResource: true, // 特殊归属：属于资源类，也就是下载类
    isDownloadable: true,
  );

  final String id;
  final String label;
  final String groupLabel;
  final bool isResource;
  final bool isDownloadable;

  const PluginCategory({
    required this.id,
    required this.label,
    required this.groupLabel,
    required this.isResource,
    required this.isDownloadable,
  });

  static PluginCategory fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    if (clean == 'live' || clean == 'iptv' || clean == 'm3u') return PluginCategory.live;
    if (clean == 'drive' || clean == 'alist' || clean == 'pan' || clean == 'webdav') return PluginCategory.drive;
    if (clean == 'bt' || clean == 'torrent' || clean == 'magnet' || clean == 'cardigann') return PluginCategory.bt;
    return PluginCategory.video;
  }
}

/// 七大规则协议类型定义 (按规则引擎/协议规范划分：5大视听流媒体规则 + 2大资源下载规则)
enum PluginRuleType {
  haipee(id: 'haipee', label: 'Haipee 规则', icon: Icons.extension_rounded),
  maccms(id: 'maccms', label: 'MacCMS 规则', icon: Icons.movie_outlined),
  tvbox(id: 'tvbox', label: 'TVBox 规则', icon: Icons.widgets_outlined),
  iptv(id: 'iptv', label: 'IPTV 规则', icon: Icons.live_tv_outlined),
  piped(id: 'piped', label: 'Piped 规则', icon: Icons.play_circle_outline_rounded),
  alist(id: 'alist', label: 'AList 规则', icon: Icons.cloud_outlined),
  cardigann(id: 'cardigann', label: 'Cardigann 规则', icon: Icons.downloading_outlined);

  final String id;
  final String label;
  final IconData icon;

  const PluginRuleType({
    required this.id,
    required this.label,
    required this.icon,
  });

  /// 是否属于全网资源下载域 (AList 网盘 + Cardigann BT磁力)
  bool get isResourceDomain =>
      this == PluginRuleType.alist || this == PluginRuleType.cardigann;

  /// 是否属于视频直播视听流媒体域 (Haipee / MacCMS / TVBox / IPTV / Piped)
  bool get isStreamingDomain => !isResourceDomain;

  // Backward compatibility alias accessors
  static PluginRuleType get kazumi => haipee;
  static PluginRuleType get anime => haipee;
  static PluginRuleType get bilibili => piped;
  static PluginRuleType get douyin => piped;
  static PluginRuleType get live => iptv;
  static PluginRuleType get drive => alist;
  static PluginRuleType get bt => cardigann;

  static PluginRuleType fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    if (clean == 'tvbox' || clean == 'fongmi' || clean == 'box') {
      return PluginRuleType.tvbox;
    }
    if (clean == 'maccms' || clean == '2' || clean == 'vod' || clean == 'applecms') {
      return PluginRuleType.maccms;
    }
    if (clean == 'iptv' || clean == 'live' || clean == 'm3u' || clean == 'm3u8') {
      return PluginRuleType.iptv;
    }
    if (clean == 'piped' || clean == 'youtube' || clean == 'bilibili' || clean == 'douyin') {
      return PluginRuleType.piped;
    }
    if (clean == 'alist' || clean == 'drive' || clean == 'pan' || clean == 'webdav') {
      return PluginRuleType.alist;
    }
    if (clean == 'cardigann' || clean == 'bt' || clean == 'torrent' || clean == 'magnet') {
      return PluginRuleType.cardigann;
    }
    return PluginRuleType.haipee;
  }
}

class Plugin {
  String api;
  String type;
  String name;
  String version;
  String category;
  bool muliSources;
  bool useWebview;
  bool useNativePlayer;
  bool usePost;
  bool useLegacyParser;
  String userAgent;
  String baseUrl;
  String searchURL;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterResult;
  String referer;
  String searchPic;
  final String searchMode;
  final Map<String, dynamic>? searchApiConfig;
  final String chapterMode;
  final Map<String, dynamic>? chapterApiConfig;
  final bool adBlocker;
  final Map<String, dynamic>? authConfig;

  Plugin({
    required this.api,
    required this.type,
    required this.name,
    required this.version,
    required this.muliSources,
    required this.useWebview,
    required this.useNativePlayer,
    required this.usePost,
    required this.useLegacyParser,
    required this.userAgent,
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    required this.referer,
    this.category = '',
    this.searchPic = '',
    this.searchMode = '',
    this.searchApiConfig,
    this.chapterMode = '',
    this.chapterApiConfig,
    this.adBlocker = false,
    this.authConfig,
  });

  PluginCategory get resolvedCategory {
    if (category.isNotEmpty) {
      return PluginCategory.fromString(category);
    }
    if (isIptv) return PluginCategory.live;
    if (isAlist) return PluginCategory.drive;
    if (type.toLowerCase() == 'torrent' || type.toLowerCase() == 'cardigann') {
      return PluginCategory.bt;
    }
    return PluginCategory.video;
  }

  /// 网盘和 BT 属于资源类（也就是下载类）
  bool get isResource => resolvedCategory.isResource;
  bool get isDownloadable => resolvedCategory.isDownloadable;
  bool get isLive => resolvedCategory == PluginCategory.live;
  bool get isDrive => resolvedCategory == PluginCategory.drive;
  bool get isBt => resolvedCategory == PluginCategory.bt;
  bool get isVideo => resolvedCategory == PluginCategory.video;

  bool get supportsAuth => authConfig != null || isBilibili;

  bool get isMacCms =>
      type == '2' ||
      type.toLowerCase() == 'maccms' ||
      type.toLowerCase() == 'applecms' ||
      searchURL.contains('/provide/vod') ||
      searchURL.contains('/inc/apijson');

  bool get isBilibili =>
      type.toLowerCase() == 'bilibili' ||
      name.toLowerCase() == 'bilibili' ||
      searchMode.toLowerCase() == 'bilibili';

  bool get isDouyin =>
      type.toLowerCase() == 'douyin' ||
      name.toLowerCase() == 'douyin' ||
      searchMode.toLowerCase() == 'douyin';

  bool get isIptv =>
      type.toLowerCase() == 'iptv' ||
      type.toLowerCase() == 'live' ||
      type.toLowerCase() == 'm3u' ||
      searchMode.toLowerCase() == 'iptv' ||
      searchURL.toLowerCase().endsWith('.m3u') ||
      searchURL.toLowerCase().endsWith('.m3u8') ||
      baseUrl.toLowerCase().endsWith('.m3u') ||
      baseUrl.toLowerCase().endsWith('.m3u8');

  bool get isAlist =>
      type.toLowerCase() == 'alist' ||
      name.toLowerCase().contains('alist') ||
      searchMode.toLowerCase() == 'alist';

  bool get isPiped =>
      type.toLowerCase() == 'piped' ||
      type.toLowerCase() == 'youtube' ||
      searchMode.toLowerCase() == 'piped';

  bool get isTvBox =>
      type.toLowerCase() == 'tvbox' ||
      type.toLowerCase() == 'fongmi' ||
      name.toLowerCase().contains('tvbox') ||
      userAgent.toLowerCase().contains('kazumi/tvbox') ||
      userAgent.toLowerCase().contains('haipee/tvbox') ||
      searchMode.toLowerCase() == 'tvbox';

  bool get isCardigann =>
      type.toLowerCase() == 'cardigann' ||
      type.toLowerCase() == 'torrent' ||
      type.toLowerCase() == 'bt' ||
      type.toLowerCase() == 'magnet' ||
      resolvedCategory == PluginCategory.bt;

  PluginRuleType get ruleType {
    if (isCardigann || resolvedCategory == PluginCategory.bt) {
      return PluginRuleType.cardigann;
    }
    if (isAlist || resolvedCategory == PluginCategory.drive) {
      return PluginRuleType.alist;
    }
    if (isIptv || resolvedCategory == PluginCategory.live) {
      return PluginRuleType.iptv;
    }
    if (isTvBox) {
      return PluginRuleType.tvbox;
    }
    if (isMacCms || type == '2' || type.toLowerCase() == 'maccms') {
      return PluginRuleType.maccms;
    }
    if (isPiped || isBilibili || isDouyin) {
      return PluginRuleType.piped;
    }
    return PluginRuleType.haipee;
  }

  static dynamic _yamlToDart(dynamic node) {
    if (node is YamlMap) {
      return node.map((k, v) => MapEntry(k.toString(), _yamlToDart(v)));
    } else if (node is YamlList) {
      return node.map(_yamlToDart).toList();
    }
    return node;
  }

  factory Plugin.fromYaml(String yamlString) {
    final doc = loadYaml(yamlString);
    if (doc is YamlMap) {
      final map = _yamlToDart(doc) as Map<String, dynamic>;
      return Plugin.fromJson(map);
    }
    throw const FormatException('YAML 格式必须为对象映射');
  }

  /// 从 YAML 文本或流中批量解析多条规则列表 (支持多文档 --- 及 YAML 数组)
  static List<Plugin> fromYamlList(String yamlString) {
    final List<Plugin> results = [];
    try {
      final docs = loadYamlStream(yamlString);
      for (final doc in docs) {
        if (doc is YamlMap) {
          try {
            final map = _yamlToDart(doc) as Map<String, dynamic>;
            final plugin = Plugin.fromJson(map);
            if (plugin.name.trim().isNotEmpty) {
              results.add(plugin);
            }
          } catch (_) {}
        } else if (doc is YamlList) {
          for (final item in doc) {
            if (item is YamlMap) {
              try {
                final map = _yamlToDart(item) as Map<String, dynamic>;
                final plugin = Plugin.fromJson(map);
                if (plugin.name.trim().isNotEmpty) {
                  results.add(plugin);
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  /// 万能批量解析器：智能识别单条/数组 JSON、YAML 规则清单、TVBox 订阅、Base64 口令及多文档 YAML
  static List<Plugin> parseMany(String content) {
    final clean = content.trim();
    if (clean.isEmpty) return const [];

    // 0. 尝试识别 TVBox / FongMi 规范订阅并一键转换
    if (TvBoxImporter.isTvBoxConfig(clean)) {
      final tvboxPlugins = TvBoxImporter.convertToPlugins(clean);
      if (tvboxPlugins.isNotEmpty) return tvboxPlugins;
    }

    // 1. 尝试直接作为 JSON / JSON 数组解析
    try {
      final decoded = jsonDecode(clean);
      if (decoded is List) {
        final list = <Plugin>[];
        for (final item in decoded) {
          if (item is Map) {
            try {
              final plugin = Plugin.fromJson(Map<String, dynamic>.from(item));
              if (plugin.name.trim().isNotEmpty) list.add(plugin);
            } catch (_) {}
          }
        }
        if (list.isNotEmpty) return list;
      } else if (decoded is Map) {
        if (decoded['rules'] is List) {
          final list = <Plugin>[];
          for (final item in decoded['rules'] as List) {
            if (item is Map) {
              try {
                final plugin = Plugin.fromJson(Map<String, dynamic>.from(item));
                if (plugin.name.trim().isNotEmpty) list.add(plugin);
              } catch (_) {}
            }
          }
          if (list.isNotEmpty) return list;
        } else if (decoded['plugins'] is List) {
          final list = <Plugin>[];
          for (final item in decoded['plugins'] as List) {
            if (item is Map) {
              try {
                final plugin = Plugin.fromJson(Map<String, dynamic>.from(item));
                if (plugin.name.trim().isNotEmpty) list.add(plugin);
              } catch (_) {}
            }
          }
          if (list.isNotEmpty) return list;
        }
        final single = Plugin.fromJson(Map<String, dynamic>.from(decoded));
        if (single.name.trim().isNotEmpty) return [single];
      }
    } catch (_) {}

    // 2. 尝试 haipee:// 或 kazumi:// 或标准 Base64 编码口令
    try {
      String b64 = clean;
      if (b64.startsWith('haipee://')) {
        b64 = b64.substring(9);
      } else if (b64.startsWith('kazumi://')) {
        b64 = b64.substring(9);
      }
      final decodedStr = utf8.decode(base64.decode(b64.trim()));
      final fromB64 = parseMany(decodedStr);
      if (fromB64.isNotEmpty) return fromB64;
    } catch (_) {}

    // 3. 尝试作为 YAML 列表 / YAML 流
    try {
      final yamlList = fromYamlList(clean);
      if (yamlList.isNotEmpty) return yamlList;
    } catch (_) {}

    // 4. 尝试单条 YAML 对象
    try {
      final singleYaml = Plugin.fromYaml(clean);
      if (singleYaml.name.trim().isNotEmpty) return [singleYaml];
    } catch (_) {}

    return const [];
  }

  String toYamlString() {
    final buffer = StringBuffer();
    final map = toJson();
    map.forEach((k, v) {
      if (v == null) return;
      if (v is String) {
        if (v.contains('\n') || v.contains(':') || v.contains('#') || v.contains('"')) {
          final escaped = v.replaceAll('"', r'\"');
          buffer.writeln('$k: "$escaped"');
        } else {
          buffer.writeln('$k: "$v"');
        }
      } else if (v is bool || v is num) {
        buffer.writeln('$k: $v');
      } else if (v is Map) {
        buffer.writeln('$k:');
        v.forEach((mk, mv) {
          buffer.writeln('  $mk: "$mv"');
        });
      }
    });
    return buffer.toString();
  }

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
        api: json['api']?.toString() ?? '1',
        type: json['type']?.toString() ?? 'anime',
        name: json['name']?.toString() ?? '',
        version: json['version']?.toString() ?? '1.0',
        muliSources: json['muliSources'] ?? false,
        useWebview: json['useWebview'] ?? false,
        useNativePlayer: json['useNativePlayer'] ?? false,
        usePost: json['usePost'] ?? false,
        useLegacyParser: json['useLegacyParser'] ?? false,
        userAgent: json['userAgent']?.toString() ?? '',
        baseUrl: json['baseURL']?.toString() ?? '',
        searchURL: json['searchURL']?.toString() ?? '',
        searchList: json['searchList']?.toString() ?? '',
        searchName: json['searchName']?.toString() ?? '',
        searchResult: json['searchResult']?.toString() ?? '',
        chapterRoads: json['chapterRoads']?.toString() ?? '',
        chapterResult: json['chapterResult']?.toString() ?? '',
        // Use referer if provided and non-empty, otherwise fallback to baseURL
        referer: (json['referer'] != null && json['referer'].toString().trim().isNotEmpty)
            ? json['referer'].toString().trim()
            : (json['baseURL']?.toString() ?? ''),
        category: json['category']?.toString() ?? '',
        searchPic: json['searchPic']?.toString() ?? '',
        searchMode: json['searchMode']?.toString() ?? '',
        searchApiConfig: json['searchApiConfig'] is Map ? Map<String, dynamic>.from(json['searchApiConfig']) : null,
        chapterMode: json['chapterMode']?.toString() ?? '',
        chapterApiConfig: json['chapterApiConfig'] is Map ? Map<String, dynamic>.from(json['chapterApiConfig']) : null,
        adBlocker: json['adBlocker'] ?? false,
        authConfig: json['auth'] is Map ? Map<String, dynamic>.from(json['auth']) : null);
  }

  factory Plugin.fromTemplate() {
    return Plugin(
        api: Api.apiLevel.toString(),
        type: 'anime',
        name: '',
        version: '',
        category: 'video',
        muliSources: true,
        useWebview: true,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: '',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        searchPic: '');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['api'] = api;
    data['type'] = type;
    data['name'] = name;
    data['version'] = version;
    if (category.isNotEmpty) data['category'] = category;
    data['muliSources'] = muliSources;
    data['useWebview'] = useWebview;
    data['useNativePlayer'] = useNativePlayer;
    data['usePost'] = usePost;
    data['useLegacyParser'] = useLegacyParser;
    data['userAgent'] = userAgent;
    data['baseURL'] = baseUrl;
    data['searchURL'] = searchURL;
    data['searchList'] = searchList;
    data['searchName'] = searchName;
    data['searchResult'] = searchResult;
    data['chapterRoads'] = chapterRoads;
    data['chapterResult'] = chapterResult;
    data['referer'] = referer;
    if (searchPic.isNotEmpty) data['searchPic'] = searchPic;
    data['searchMode'] = searchMode;
    data['searchApiConfig'] = searchApiConfig;
    data['chapterMode'] = chapterMode;
    data['chapterApiConfig'] = chapterApiConfig;
    data['adBlocker'] = adBlocker;
    if (authConfig != null) data['auth'] = authConfig;
    return data;
  }

  static String cleanKeywordForSearch(String keyword) {
    var clean = keyword.trim();
    // 替换日文波浪号、全角波浪号为普通空格
    clean = clean.replaceAll(RegExp(r'[〜～~]'), ' ');
    // 移除括号及其包含的无用标签
    clean = clean.replaceAll(RegExp(r'[\[【\(（].*?[\]】\)）]'), ' ');
    // 移除其他杂音标点
    clean = clean.replaceAll(RegExp(r'[★☆◆◇▲▼]'), ' ');
    // 合并多余空白
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? keyword.trim() : clean;
  }

  /// 智能规则测速与连通性检测（基于 HTTP 响应状态码及协议连通性，彻底杜绝因特定搜索词无结果而误判失效）
  Future<(bool isSuccess, int latencyMs, String? error)> testConnectivity({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      // 1. IPTV 直播规则 (以 M3U 订阅连通性与 HTTP 状态码为唯一事实依据)
      if (isIptv) {
        final m3uUrl = searchURL.isNotEmpty ? searchURL : baseUrl;
        if (m3uUrl.trim().isEmpty) {
          stopwatch.stop();
          return (false, 0, 'IPTV 订阅地址为空');
        }
        final resp = await Request().get(
          m3uUrl.trim(),
          options: Options(
            headers: {
              'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Haipee/IPTV; Player)',
              'Accept': '*/*',
            },
          ),
          shouldRethrow: true,
        ).timeout(timeout);
        stopwatch.stop();

        final status = resp.statusCode ?? 200;
        if (status >= 200 && status < 400) {
          return (true, stopwatch.elapsedMilliseconds, null);
        } else {
          return (false, stopwatch.elapsedMilliseconds, 'HTTP $status 响应异常');
        }
      }

      // 2. 苹果 CMS (MacCMS) / TVBox VOD 规则
      if (isMacCms || (isTvBox && searchURL.contains('/api.php/provide/vod'))) {
        try {
          final res = await queryBangumi('海贼王', shouldRethrow: true).timeout(timeout);
          if (res.data.isNotEmpty) {
            stopwatch.stop();
            return (true, stopwatch.elapsedMilliseconds, null);
          }
        } catch (_) {
          // 搜索特定词失败，回退探测 MacCMS 根采集接口
        }

        final rootUrl = searchURL.isNotEmpty
            ? searchURL.replaceAll(RegExp(r'[?&]wd=[^&]*'), '').replaceAll('@keyword', '')
            : (baseUrl.endsWith('/')
                ? '${baseUrl}api.php/provide/vod/?ac=detail&at=json'
                : '$baseUrl/api.php/provide/vod/?ac=detail&at=json');

        final resp = await Request().get(
          rootUrl,
          options: Options(
            headers: {
              'referer': baseUrl.isNotEmpty ? '$baseUrl/' : '',
              'Accept': 'application/json, text/plain, */*',
              'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Haipee/Player)',
            },
          ),
          shouldRethrow: true,
        ).timeout(const Duration(seconds: 6));
        stopwatch.stop();

        final status = resp.statusCode ?? 200;
        if (status >= 200 && status < 400) {
          return (true, stopwatch.elapsedMilliseconds, null);
        } else {
          return (false, stopwatch.elapsedMilliseconds, 'HTTP $status 接口异常');
        }
      }

      // 3. AList 开放网盘挂载规则
      if (isAlist) {
        final targetBase = baseUrl.isNotEmpty ? baseUrl : searchURL;
        final cleanBase = targetBase.endsWith('/') ? targetBase.substring(0, targetBase.length - 1) : targetBase;
        final resp = await Request().get(
          '$cleanBase/api/public/settings',
          options: Options(
            headers: {
              'Accept': 'application/json',
              'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Haipee/AList; Player)',
            },
          ),
          shouldRethrow: false,
        ).timeout(timeout);
        stopwatch.stop();

        final status = resp.statusCode ?? 200;
        if (status >= 200 && status < 400) {
          return (true, stopwatch.elapsedMilliseconds, null);
        }
        final searchRes = await AlistService.search(name, cleanBase, '1').timeout(const Duration(seconds: 6));
        return (searchRes.data.isNotEmpty || status == 200, stopwatch.elapsedMilliseconds, null);
      }

      // 4. Piped (YouTube 镜像前端) 规则
      if (isPiped) {
        final host = baseUrl.isNotEmpty ? baseUrl : api;
        final cleanHost = host.isNotEmpty
            ? (host.endsWith('/') ? host.substring(0, host.length - 1) : host)
            : PipedService.defaultApi;

        final resp = await Request().get(
          '$cleanHost/trending?region=US',
          options: Options(
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Haipee/Piped)',
            },
          ),
          shouldRethrow: true,
        ).timeout(timeout);
        stopwatch.stop();

        final status = resp.statusCode ?? 200;
        if (status >= 200 && status < 400) {
          return (true, stopwatch.elapsedMilliseconds, null);
        } else {
          return (false, stopwatch.elapsedMilliseconds, 'HTTP $status 节点异常');
        }
      }

      // 5. Bilibili / 抖音
      if (isBilibili) {
        final biliResults = await BilibiliService.searchVideos('海贼王').timeout(timeout);
        stopwatch.stop();
        return (biliResults.isNotEmpty, stopwatch.elapsedMilliseconds, null);
      }
      if (isDouyin) {
        final douyinResults = await DouyinService.searchVideos('海贼王').timeout(timeout);
        stopwatch.stop();
        return (douyinResults.isNotEmpty, stopwatch.elapsedMilliseconds, null);
      }

      // 6. 常规网页爬虫规则 (Haipee 规则)
      var res = await queryBangumi('海贼王', shouldRethrow: true).timeout(timeout);
      if (res.data.isNotEmpty) {
        stopwatch.stop();
        return (true, stopwatch.elapsedMilliseconds, null);
      }

      res = await queryBangumi('柯南', shouldRethrow: true).timeout(const Duration(seconds: 6));
      if (res.data.isNotEmpty) {
        stopwatch.stop();
        return (true, stopwatch.elapsedMilliseconds, null);
      }

      // 若两组特定词搜索均为空（如某些特定专精影视站点），基于根站点 HTTP 状态码探测站点可用性
      final pingUrl = baseUrl.isNotEmpty ? baseUrl : searchURL.replaceAll('@keyword', '1');
      if (pingUrl.isNotEmpty) {
        final resp = await Request().get(
          pingUrl,
          options: Options(
            headers: {
              'User-Agent': userAgent.isNotEmpty ? userAgent : Utils.getRandomUA(),
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ),
          shouldRethrow: true,
        ).timeout(const Duration(seconds: 6));
        stopwatch.stop();

        final status = resp.statusCode ?? 200;
        if (status >= 200 && status < 400) {
          return (true, stopwatch.elapsedMilliseconds, null);
        } else {
          return (false, stopwatch.elapsedMilliseconds, 'HTTP $status 站点异常');
        }
      }

      stopwatch.stop();
      return (true, stopwatch.elapsedMilliseconds, null);
    } on DioException catch (e) {
      stopwatch.stop();
      final status = e.response?.statusCode;
      final errMsg = status != null ? 'HTTP $status 访问失败' : (e.message ?? '连接超时或失败');
      return (false, stopwatch.elapsedMilliseconds, errMsg);
    } catch (e) {
      stopwatch.stop();
      return (false, stopwatch.elapsedMilliseconds, e.toString());
    }
  }

  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    if (isBilibili) {
      try {
        final biliResults = await BilibiliService.searchVideos(keyword);
        final items = biliResults
            .map((item) => SearchItem(
                  name: item.title,
                  src: 'https://www.bilibili.com/video/${item.bvid}',
                  pic: RuleCoverExtractor.normalizeCoverUrl(item.pic, baseUrl: baseUrl),
                  remarks: item.duration,
                  category: resolvedCategory.id,
                ))
            .toList();
        return PluginSearchResponse(
          pluginName: name,
          data: items,
          category: resolvedCategory.id,
        );
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'Bilibili 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (isDouyin) {
      try {
        final douyinResults = await DouyinService.searchVideos(keyword);
        final items = douyinResults
            .map((item) => SearchItem(
                  name: item.title,
                  src: item.playUrl.isNotEmpty
                      ? item.playUrl
                      : 'https://www.douyin.com/video/${item.id}',
                  pic: RuleCoverExtractor.normalizeCoverUrl(item.cover, baseUrl: baseUrl),
                  remarks: item.duration > 0 ? '${item.duration}s' : '',
                  category: resolvedCategory.id,
                ))
            .toList();
        return PluginSearchResponse(
          pluginName: name,
          data: items,
          category: resolvedCategory.id,
        );
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'Douyin 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (isIptv) {
      try {
        final m3uUrl = searchURL.isNotEmpty ? searchURL : baseUrl;
        return await IptvService.searchChannels(name, m3uUrl, keyword);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'IPTV 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (isAlist) {
      try {
        final targetBase = baseUrl.isNotEmpty ? baseUrl : searchURL;
        return await AlistService.search(name, targetBase, keyword);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'AList 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (isPiped) {
      try {
        final host = baseUrl.isNotEmpty ? baseUrl : api;
        return await PipedService.search(name, host, keyword);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'Piped/YouTube 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (searchMode.toLowerCase() == 'api' && searchApiConfig != null) {
      return _queryApiBangumi(keyword, shouldRethrow: shouldRethrow);
    }
    if (isMacCms || (isTvBox && (searchList.isEmpty || searchURL.contains('/provide/vod') || searchURL.contains('/inc/apijson')))) {
      return _queryMacCmsBangumi(keyword, shouldRethrow: shouldRethrow);
    }

    final cleanKeyword = cleanKeywordForSearch(keyword);
    final encodedKeyword = Uri.encodeQueryComponent(cleanKeyword);
    String queryURL = searchURL.replaceAll('@keyword', encodedKeyword);
    dynamic resp;
    List<SearchItem> searchItems = [];
    if (usePost) {
      Uri uri = Uri.parse(queryURL);
      Map<String, String> queryParams = uri.queryParameters;
      Uri postUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      );
      var httpHeaders = {
        'referer': referer.isNotEmpty ? referer : (baseUrl.isNotEmpty ? '$baseUrl/' : ''),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'User-Agent': userAgent.isNotEmpty ? userAgent : Utils.getRandomUA(),
        'Connection': 'keep-alive',
      };
      resp = await Request().post(postUri.toString(),
          options: Options(headers: httpHeaders),
          extra: {'customError': ''},
          data: queryParams,
          shouldRethrow: shouldRethrow);
    } else {
      var httpHeaders = {
        'referer': referer.isNotEmpty ? referer : (baseUrl.isNotEmpty ? '$baseUrl/' : ''),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'User-Agent': userAgent.isNotEmpty ? userAgent : Utils.getRandomUA(),
        'Connection': 'keep-alive',
      };
      resp = await Request().get(queryURL,
          options: Options(headers: httpHeaders),
          shouldRethrow: shouldRethrow,
          extra: {'customError': ''});
    }

    var htmlString = resp.data.toString();
    var htmlElement = parse(htmlString).documentElement!;

    htmlElement.queryXPath(searchList).nodes.forEach((element) {
      try {
        String srcUrl = element.queryXPath(searchResult).node!.attributes['href'] ?? '';
        // 规范化 URL，避免双斜杠
        String fullUrl;
        if (srcUrl.startsWith('http://') || srcUrl.startsWith('https://')) {
          fullUrl = srcUrl;
        } else if (srcUrl.startsWith('/')) {
          // 绝对路径，直接拼接 baseUrl
          fullUrl = baseUrl.endsWith('/') ? baseUrl + srcUrl.substring(1) : baseUrl + srcUrl;
        } else {
          // 相对路径
          fullUrl = baseUrl.endsWith('/') ? baseUrl + srcUrl : '$baseUrl/$srcUrl';
        }
        final String picUrl = RuleCoverExtractor.extractFromXPathNode(
          element,
          searchPic: searchPic,
          baseUrl: baseUrl,
        );
        SearchItem searchItem = SearchItem(
          name: element.queryXPath(searchName).node!.text?.trim() ?? '',
          src: srcUrl,
          pic: picUrl,
          category: resolvedCategory.id,
        );
        searchItems.add(searchItem);
        HaipeeLogger().log(Level.info,
            '$name ${element.queryXPath(searchName).node!.text ?? ''} $fullUrl');
      } catch (_) {}
    });
    PluginSearchResponse pluginSearchResponse = PluginSearchResponse(
        pluginName: name, data: searchItems, category: resolvedCategory.id);
    return pluginSearchResponse;
  }

  /// 现代化 API 检索接口（如 /index.php/ajax/suggest 及 RPC 端点）
  Future<PluginSearchResponse> _queryApiBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    final searchConfig = searchApiConfig;
    if (searchConfig == null) {
      return PluginSearchResponse(pluginName: name, data: const []);
    }

    final reqConfig = searchConfig['request'] as Map<String, dynamic>? ?? {};
    final method = (reqConfig['method'] as String?)?.toUpperCase() ?? 'GET';
    final rawUrl = reqConfig['url'] as String? ?? '';
    if (rawUrl.isEmpty) {
      return PluginSearchResponse(pluginName: name, data: const []);
    }

    final cleanKeyword = cleanKeywordForSearch(keyword);
    final headers = <String, dynamic>{
      'referer': referer.isNotEmpty ? referer : (baseUrl.isNotEmpty ? '$baseUrl/' : ''),
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'User-Agent': userAgent.isNotEmpty ? userAgent : Utils.getRandomUA(),
    };

    if (reqConfig['headers'] is Map) {
      (reqConfig['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    dynamic resp;
    if (method == 'POST') {
      final bodyType = reqConfig['bodyType']?.toString() ?? 'json';
      dynamic bodyData = reqConfig['body'];
      if (bodyData is Map) {
        bodyData = bodyData.map((k, v) {
          final strVal = v.toString();
          return MapEntry(k, strVal.replaceAll('@keyword', cleanKeyword));
        });
      }
      resp = await Request().post(
        rawUrl,
        data: bodyData,
        options: Options(
          headers: headers,
          contentType: bodyType == 'json' ? 'application/json' : 'application/x-www-form-urlencoded',
        ),
        shouldRethrow: shouldRethrow,
        extra: {'customError': ''},
      );
    } else {
      final query = reqConfig['query'] as Map<String, dynamic>? ?? {};
      final queryParams = query.map((k, v) {
        final strVal = v.toString();
        return MapEntry(k, strVal.replaceAll('@keyword', cleanKeyword));
      });
      resp = await Request().get(
        rawUrl,
        data: queryParams,
        options: Options(headers: headers),
        shouldRethrow: shouldRethrow,
        extra: {'customError': ''},
      );
    }

    final searchItems = <SearchItem>[];
    dynamic data = resp.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    List<dynamic> itemsList = [];
    if (data is List) {
      itemsList = data;
    } else if (data is Map) {
      final listPath = searchConfig['listPath']?.toString() ?? r'$.list[*]';
      if (listPath.contains('list') && data['list'] is List) {
        itemsList = data['list'] as List;
      } else if (data['data'] is List) {
        itemsList = data['data'] as List;
      }
    }

    final namePath = searchConfig['namePath']?.toString() ?? r'$.name';
    final nameKey = namePath.replaceAll(RegExp(r'^\$\.'), '');
    final sourcePath = searchConfig['sourcePath']?.toString() ?? r'$.id';
    final sourceKey = sourcePath.replaceAll(RegExp(r'^\$\.'), '');
    final sourceTemplate = searchConfig['sourceTemplate']?.toString() ?? '';
    final picPath = searchConfig['picPath']?.toString() ?? '';
    final picKey = picPath.replaceAll(RegExp(r'^\$\.'), '');

    for (final item in itemsList) {
      if (item is Map) {
        final itemName = item[nameKey]?.toString().trim() ?? '';
        final itemId = item[sourceKey]?.toString().trim() ?? '';
        if (itemName.isNotEmpty && itemId.isNotEmpty) {
          String itemSrc = itemId;
          if (sourceTemplate.isNotEmpty) {
            itemSrc = sourceTemplate.replaceAll('@source', itemId);
            if (!itemSrc.startsWith('http://') && !itemSrc.startsWith('https://')) {
              final cleanPath = itemSrc.startsWith('/') ? itemSrc.substring(1) : itemSrc;
              itemSrc = baseUrl.endsWith('/') ? '$baseUrl$cleanPath' : '$baseUrl/$cleanPath';
            }
          } else if (!itemSrc.startsWith('http://') && !itemSrc.startsWith('https://')) {
            itemSrc = baseUrl.endsWith('/') ? '$baseUrl$itemId.html' : '$baseUrl/$itemId.html';
          }
          final String itemPic = RuleCoverExtractor.extractFromJsonMap(
            item,
            picKey: picKey.isNotEmpty ? picKey : searchPic,
            baseUrl: baseUrl,
          );
          searchItems.add(SearchItem(
            name: itemName,
            src: itemSrc,
            pic: itemPic,
            category: resolvedCategory.id,
          ));
          HaipeeLogger().log(Level.info, '$name [API] $itemName -> $itemSrc');
        }
      }
    }

    return PluginSearchResponse(
      pluginName: name,
      data: searchItems,
      category: resolvedCategory.id,
    );
  }

  /// 苹果 CMS V10 标准 JSON/XML 采集接口搜索 (强制确保 ac=detail 以返回 vod_pic 海报、更新状态与播放线路)
  Future<PluginSearchResponse> _queryMacCmsBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    final cleanKeyword = cleanKeywordForSearch(keyword);
    String queryURL;
    if (searchURL.isNotEmpty) {
      queryURL = searchURL.replaceAll('@keyword', Uri.encodeComponent(cleanKeyword));
    } else {
      queryURL = baseUrl.endsWith('/')
          ? '${baseUrl}api.php/provide/vod/?ac=detail&at=json&wd=${Uri.encodeComponent(cleanKeyword)}'
          : '$baseUrl/api.php/provide/vod/?ac=detail&at=json&wd=${Uri.encodeComponent(cleanKeyword)}';
    }
    // 确保使用 ac=detail / ac=videolist：MacCMS 默认 ac=list 不返回 vod_pic 封面字段
    if (queryURL.contains('ac=list')) {
      queryURL = queryURL.replaceAll('ac=list', 'ac=detail');
    } else if (!queryURL.contains('ac=')) {
      queryURL += queryURL.contains('?') ? '&ac=detail' : '?ac=detail';
    }
    if (!queryURL.contains('at=json') && !queryURL.contains('/at/xml')) {
      queryURL += queryURL.contains('?') ? '&at=json' : '?at=json';
    }

    final httpHeaders = {
      'referer': '$baseUrl/',
      'Accept': 'application/json, application/xml, text/xml, text/plain, */*',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Haipee/Player)',
    };

    final resp = await Request().get(
      queryURL,
      options: Options(headers: httpHeaders),
      shouldRethrow: shouldRethrow,
      extra: {'customError': ''},
    );

    List<SearchItem> searchItems = [];
    dynamic data = resp.data;
    String? rawString;
    if (data is String) {
      rawString = data.trim();
      try {
        data = jsonDecode(rawString);
      } catch (_) {}
    }

    if (data is Map && data['list'] is List) {
      final list = data['list'] as List;
      for (final item in list) {
        if (item is Map) {
          final vodName = item['vod_name']?.toString().trim() ??
              item['name']?.toString().trim() ??
              '';
          final vodId = item['vod_id']?.toString().trim() ??
              item['id']?.toString().trim() ??
              '';
          final vodPic = RuleCoverExtractor.extractFromJsonMap(
            item,
            picKey: searchPic,
            baseUrl: baseUrl,
          );
          final vodRemarks = item['vod_remarks']?.toString().trim() ??
              item['vod_sub']?.toString().trim() ??
              item['note']?.toString().trim() ??
              '';
          if (vodName.isNotEmpty && vodId.isNotEmpty) {
            final detailSrc = '/api.php/provide/vod/?ac=detail&at=json&ids=$vodId';
            searchItems.add(SearchItem(
              name: vodName,
              src: detailSrc,
              pic: vodPic,
              remarks: vodRemarks,
              category: resolvedCategory.id,
            ));
            HaipeeLogger().log(Level.info, '$name [MacCMS] $vodName $detailSrc');
          }
        }
      }
    } else if (rawString != null && rawString.startsWith('<')) {
      // 兼容 TVBox Type 0 / 苹果 CMS XML 格式 (<rss><list><video><id/><name/><pic/><note/></video></list></rss>)
      try {
        final doc = parse(rawString);
        for (final videoEl in doc.querySelectorAll('video')) {
          final vodName = videoEl
                  .querySelector('name')
                  ?.text
                  .replaceAll('<![CDATA[', '')
                  .replaceAll(']]>', '')
                  .trim() ??
              '';
          final vodId = videoEl.querySelector('id')?.text.trim() ?? '';
          final rawPic = videoEl
                  .querySelector('pic')
                  ?.text
                  .replaceAll('<![CDATA[', '')
                  .replaceAll(']]>', '')
                  .trim() ??
              '';
          final vodPic = RuleCoverExtractor.normalizeCoverUrl(rawPic, baseUrl: baseUrl);
          final vodRemarks = videoEl
                  .querySelector('note')
                  ?.text
                  .replaceAll('<![CDATA[', '')
                  .replaceAll(']]>', '')
                  .trim() ??
              '';
          if (vodName.isNotEmpty && vodId.isNotEmpty) {
            final detailSrc = '/api.php/provide/vod/?ac=detail&ids=$vodId';
            searchItems.add(SearchItem(
              name: vodName,
              src: detailSrc,
              pic: vodPic,
              remarks: vodRemarks,
              category: resolvedCategory.id,
            ));
          }
        }
      } catch (_) {}
    }

    return PluginSearchResponse(
      pluginName: name,
      data: searchItems,
      category: resolvedCategory.id,
    );
  }

  Future<List<Road>> querychapterRoads(String url,
      {CancelToken? cancelToken}) async {
    if (isBilibili) {
      try {
        final bvMatch = RegExp(r'BV[a-zA-Z0-9]{10}').firstMatch(url);
        final bvid = bvMatch?.group(0) ?? url;
        final detail = await BilibiliService.getVideoDetails(bvid);
        if (detail != null && detail.parts.isNotEmpty) {
          final cids = detail.parts
              .map((p) => 'bili://$bvid/${p.cid}')
              .toList();
          final names = detail.parts
              .map((p) => p.part.isNotEmpty
                  ? p.part
                  : '第${detail.parts.indexOf(p) + 1}P')
              .toList();
          return [
            Road(
              name: '官方原画 (WBI/DASH)',
              data: cids,
              identifier: names,
            ),
          ];
        }
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'B站规则选集解析异常: $e');
      }
      return [];
    }

    if (isDouyin) {
      try {
        String playUrl = url;
        if (!playUrl.startsWith('http://') && !playUrl.startsWith('https://')) {
          final item = await DouyinService.extractVideo(url);
          if (item != null) {
            playUrl = item.playUrl;
          }
        }
        if (playUrl.isNotEmpty) {
          return [
            Road(
              name: '无水印直链',
              data: [playUrl],
              identifier: ['原画'],
            ),
          ];
        }
      } catch (e) {
        HaipeeLogger().log(Level.warning, '抖音规则选集解析异常: $e');
      }
      return [];
    }

    if (isIptv) {
      try {
        final m3uUrl = searchURL.isNotEmpty ? searchURL : baseUrl;
        return await IptvService.queryChapterRoads(m3uUrl, url);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'IPTV 选集解析异常: $e');
        return [];
      }
    }

    if (isAlist) {
      try {
        final targetBase = baseUrl.isNotEmpty ? baseUrl : searchURL;
        return await AlistService.queryChapterRoads(targetBase, url);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'AList 选集解析异常: $e');
        return [];
      }
    }

    if (isPiped) {
      try {
        final host = baseUrl.isNotEmpty ? baseUrl : api;
        return await PipedService.queryChapterRoads(host, url);
      } catch (e) {
        HaipeeLogger().log(Level.warning, 'Piped 选集解析异常: $e');
        return [];
      }
    }

    if (isMacCms || url.contains('/api.php/provide/vod')) {
      return _queryMacCmsChapterRoads(url, cancelToken: cancelToken);
    }

    List<Road> roadList = [];
    // 预处理
    if (!url.contains('https')) {
      url = url.replaceAll('http', 'https');
    }
    String queryURL = '';
    if (url.contains(baseUrl)) {
      queryURL = url;
    } else {
      // 规范化 URL 拼接，避免双斜杠
      if (url.startsWith('/')) {
        queryURL = baseUrl.endsWith('/') ? baseUrl + url.substring(1) : baseUrl + url;
      } else {
        queryURL = baseUrl.endsWith('/') ? baseUrl + url : '$baseUrl/$url';
      }
    }
    // 清理可能存在的双斜杠（除了协议的 ://）
    queryURL = queryURL.replaceAllMapped(RegExp(r'([^:])/+'), (match) => '${match.group(1)}/');
    var httpHeaders = {
      'referer': referer.isNotEmpty ? referer : (baseUrl.isNotEmpty ? '$baseUrl/' : ''),
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'User-Agent': userAgent.isNotEmpty ? userAgent : Utils.getRandomUA(),
      'Connection': 'keep-alive',
    };
    try {
      var resp = await Request().get(queryURL,
          options: Options(headers: httpHeaders), cancelToken: cancelToken);
      var htmlString = resp.data.toString();
      var htmlElement = parse(htmlString).documentElement!;
      int count = 1;
      htmlElement.queryXPath(chapterRoads).nodes.forEach((element) {
        try {
          List<String> chapterUrlList = [];
          List<String> chapterNameList = [];
          element.queryXPath(chapterResult).nodes.forEach((item) {
            String itemUrl = item.node.attributes['href'] ?? '';
            String itemName = item.node.text ?? '';
            chapterUrlList.add(itemUrl);
            chapterNameList.add(itemName.replaceAll(RegExp(r'\s+'), ''));
          });
          if (chapterUrlList.isNotEmpty && chapterNameList.isNotEmpty) {
            Road road = Road(
                name: '播放列表$count',
                data: chapterUrlList,
                identifier: chapterNameList);
            roadList.add(road);
            count++;
          }
        } catch (_) {}
      });
    } catch (_) {}
    return roadList;
  }

  /// 苹果 CMS V10 标准 JSON 选集与线路解析
  Future<List<Road>> _queryMacCmsChapterRoads(String url,
      {CancelToken? cancelToken}) async {
    List<Road> roadList = [];
    String queryURL = url;
    if (!queryURL.startsWith('http://') && !queryURL.startsWith('https://')) {
      queryURL = baseUrl.endsWith('/')
          ? baseUrl + (queryURL.startsWith('/') ? queryURL.substring(1) : queryURL)
          : '$baseUrl/$queryURL';
    }
    if (!queryURL.contains('at=json')) {
      queryURL += queryURL.contains('?') ? '&at=json' : '?at=json';
    }

    final httpHeaders = {
      'referer': '$baseUrl/',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Haipee/Player)',
    };

    try {
      final resp = await Request().get(
        queryURL,
        options: Options(headers: httpHeaders),
        cancelToken: cancelToken,
      );
      dynamic data = resp.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map && data['list'] is List && (data['list'] as List).isNotEmpty) {
        final vod = data['list'][0] as Map;
        final rawFrom = vod['vod_play_from']?.toString() ?? '';
        final rawUrls = vod['vod_play_url']?.toString() ?? '';

        final playFromList = rawFrom.split(RegExp(r'\$\$\$|\$\$'));
        final playUrlList = rawUrls.split(RegExp(r'\$\$\$|\$\$'));

        for (int i = 0; i < playUrlList.length; i++) {
          final fromName = (i < playFromList.length && playFromList[i].trim().isNotEmpty)
              ? playFromList[i].trim()
              : '线路 ${i + 1}';
          final epParts = playUrlList[i].split('#');

          final List<String> chapterUrlList = [];
          final List<String> chapterNameList = [];

          for (final ep in epParts) {
            final trimmed = ep.trim();
            if (trimmed.isEmpty) continue;
            final dollarParts = trimmed.split('\$');
            if (dollarParts.length >= 2) {
              final epName = dollarParts[0].trim();
              final epUrl = dollarParts.sublist(1).join('\$').trim();
              chapterNameList.add(epName.isEmpty ? '第${chapterNameList.length + 1}集' : epName);
              chapterUrlList.add(epUrl);
            } else if (trimmed.isNotEmpty) {
              chapterNameList.add('第${chapterNameList.length + 1}集');
              chapterUrlList.add(trimmed);
            }
          }

          if (chapterUrlList.isNotEmpty) {
            roadList.add(Road(
              name: fromName,
              data: chapterUrlList,
              identifier: chapterNameList,
            ));
          }
        }
      }
    } catch (e, stack) {
      HaipeeLogger().log(Level.error, 'MacCMS 解析选集失败: $e', stackTrace: stack);
    }

    return roadList;
  }
}
