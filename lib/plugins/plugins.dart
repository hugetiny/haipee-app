import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:html/parser.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:kazumi/modules/bilibili/bilibili_service.dart';
import 'package:kazumi/modules/douyin/douyin_service.dart';

class Plugin {
  String api;
  String type;
  String name;
  String version;
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
    this.searchPic = '',
    this.searchMode = '',
    this.searchApiConfig,
    this.chapterMode = '',
    this.chapterApiConfig,
    this.adBlocker = false,
    this.authConfig,
  });

  bool get supportsAuth => authConfig != null || isBilibili;

  bool get isMacCms =>
      type.toLowerCase() == 'maccms' ||
      type.toLowerCase() == 'applecms' ||
      searchURL.contains('/api.php/provide/vod');

  bool get isBilibili =>
      type.toLowerCase() == 'bilibili' ||
      name.toLowerCase() == 'bilibili' ||
      searchMode.toLowerCase() == 'bilibili';

  bool get isDouyin =>
      type.toLowerCase() == 'douyin' ||
      name.toLowerCase() == 'douyin' ||
      searchMode.toLowerCase() == 'douyin';

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

  /// 万能批量解析器：智能识别单条/数组 JSON、YAML 规则清单、Base64 口令及多文档 YAML
  static List<Plugin> parseMany(String content) {
    final clean = content.trim();
    if (clean.isEmpty) return const [];

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

    // 2. 尝试 kazumi:// 或标准 Base64 编码口令
    try {
      String b64 = clean;
      if (b64.startsWith('kazumi://')) {
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

  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    if (isBilibili) {
      try {
        final biliResults = await BilibiliService.searchVideos(keyword);
        final items = biliResults
            .map((item) => SearchItem(
                  name: item.title,
                  src: 'https://www.bilibili.com/video/${item.bvid}',
                ))
            .toList();
        return PluginSearchResponse(pluginName: name, data: items);
      } catch (e) {
        KazumiLogger().log(Level.warning, 'Bilibili 规则搜索异常: $e');
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
                ))
            .toList();
        return PluginSearchResponse(pluginName: name, data: items);
      } catch (e) {
        KazumiLogger().log(Level.warning, 'Douyin 规则搜索异常: $e');
        if (shouldRethrow) rethrow;
        return PluginSearchResponse(pluginName: name, data: const []);
      }
    }

    if (searchMode.toLowerCase() == 'api' && searchApiConfig != null) {
      return _queryApiBangumi(keyword, shouldRethrow: shouldRethrow);
    }
    if (isMacCms) {
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
        String picUrl = '';
        if (searchPic.isNotEmpty) {
          try {
            final picNode = element.queryXPath(searchPic).node;
            if (picNode != null) {
              picUrl = picNode.attributes['src'] ??
                  picNode.attributes['data-original'] ??
                  picNode.attributes['data-src'] ??
                  picNode.attributes['data-echo'] ??
                  picNode.text?.trim() ??
                  '';
            }
          } catch (_) {}
        }
        // 自动回退：当规则未配置 searchPic 或未提取到时，尝试抓取该条目内的首个 img 标签
        if (picUrl.isEmpty) {
          try {
            final fallbackImg = element.queryXPath('.//img').node;
            if (fallbackImg != null) {
              picUrl = fallbackImg.attributes['src'] ??
                  fallbackImg.attributes['data-original'] ??
                  fallbackImg.attributes['data-src'] ??
                  fallbackImg.attributes['data-echo'] ??
                  '';
            }
          } catch (_) {}
        }

        if (picUrl.isNotEmpty) {
          picUrl = picUrl.trim();
          if (picUrl.startsWith('//')) {
            picUrl = 'https:$picUrl';
          } else if (picUrl.startsWith('http://')) {
            picUrl = picUrl.replaceFirst('http://', 'https://');
          } else if (!picUrl.startsWith('https://')) {
            picUrl = baseUrl.endsWith('/')
                ? (picUrl.startsWith('/') ? baseUrl + picUrl.substring(1) : '$baseUrl$picUrl')
                : (picUrl.startsWith('/') ? '$baseUrl$picUrl' : '$baseUrl/$picUrl');
          }
        }
        SearchItem searchItem = SearchItem(
          name: element.queryXPath(searchName).node!.text?.trim() ?? '',
          src: srcUrl,
          pic: picUrl,
        );
        searchItems.add(searchItem);
        KazumiLogger().log(Level.info,
            '$name ${element.queryXPath(searchName).node!.text ?? ''} $fullUrl');
      } catch (_) {}
    });
    PluginSearchResponse pluginSearchResponse =
        PluginSearchResponse(pluginName: name, data: searchItems);
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
          String itemPic = '';
          final rawPic = (picKey.isNotEmpty ? item[picKey] : null) ??
              item['pic'] ??
              item['vod_pic'] ??
              item['cover'] ??
              item['img'];
          if (rawPic != null) {
            itemPic = rawPic.toString().trim();
            if (itemPic.startsWith('//')) {
              itemPic = 'https:$itemPic';
            } else if (itemPic.startsWith('http://')) {
              itemPic = itemPic.replaceFirst('http://', 'https://');
            } else if (!itemPic.startsWith('https://')) {
              final cleanPath = itemPic.startsWith('/') ? itemPic.substring(1) : itemPic;
              itemPic = baseUrl.endsWith('/') ? '$baseUrl$cleanPath' : '$baseUrl/$cleanPath';
            }
          }
          searchItems.add(SearchItem(name: itemName, src: itemSrc, pic: itemPic));
          KazumiLogger().log(Level.info, '$name [API] $itemName -> $itemSrc');
        }
      }
    }

    return PluginSearchResponse(pluginName: name, data: searchItems);
  }

  /// 苹果 CMS V10 标准 JSON 采集接口搜索 (支持 ac=detail 快速获取高清海报、更新状态与播放线路)
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
    if (!queryURL.contains('at=json')) {
      queryURL += queryURL.contains('?') ? '&at=json' : '?at=json';
    }

    final httpHeaders = {
      'referer': '$baseUrl/',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Kazumi/Player)',
    };

    final resp = await Request().get(
      queryURL,
      options: Options(headers: httpHeaders),
      shouldRethrow: shouldRethrow,
      extra: {'customError': ''},
    );

    List<SearchItem> searchItems = [];
    dynamic data = resp.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    if (data is Map && data['list'] is List) {
      final list = data['list'] as List;
      for (final item in list) {
        if (item is Map) {
          final vodName = item['vod_name']?.toString().trim() ?? '';
          final vodId = item['vod_id']?.toString().trim() ?? '';
          var vodPic = item['vod_pic']?.toString().trim() ??
              item['pic']?.toString().trim() ??
              '';
          if (vodPic.startsWith('//')) {
            vodPic = 'https:$vodPic';
          } else if (vodPic.startsWith('http://')) {
            vodPic = vodPic.replaceFirst('http://', 'https://');
          } else if (vodPic.startsWith('/') && baseUrl.isNotEmpty) {
            vodPic = baseUrl.endsWith('/') ? '$baseUrl${vodPic.substring(1)}' : '$baseUrl$vodPic';
          }
          final vodRemarks = item['vod_remarks']?.toString().trim() ??
              item['vod_sub']?.toString().trim() ??
              '';
          if (vodName.isNotEmpty && vodId.isNotEmpty) {
            final detailSrc = '/api.php/provide/vod/?ac=detail&at=json&ids=$vodId';
            searchItems.add(SearchItem(
              name: vodName,
              src: detailSrc,
              pic: vodPic,
              remarks: vodRemarks,
            ));
            KazumiLogger().log(Level.info, '$name [MacCMS] $vodName $detailSrc');
          }
        }
      }
    }

    return PluginSearchResponse(pluginName: name, data: searchItems);
  }

  Future<List<Road>> querychapterRoads(String url,
      {CancelToken? cancelToken}) async {
    if (isBilibili) {
      try {
        final bvMatch = RegExp(r'BV[a-zA-Z0-9]{10}').firstMatch(url);
        final bvid = bvMatch?.group(0) ?? url;
        final detail = await BilibiliService.getVideoDetails(bvid);
        if (detail != null && detail.parts.isNotEmpty) {
          final cids = detail.parts.map((p) => p.cid.toString()).toList();
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
        KazumiLogger().log(Level.warning, 'B站规则选集解析异常: $e');
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
        KazumiLogger().log(Level.warning, '抖音规则选集解析异常: $e');
      }
      return [];
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
      'User-Agent': userAgent.isNotEmpty ? userAgent : 'Mozilla/5.0 (Kazumi/Player)',
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
      KazumiLogger().log(Level.error, 'MacCMS 解析选集失败: $e', stackTrace: stack);
    }

    return roadList;
  }
}
