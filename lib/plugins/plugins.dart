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
  });

  bool get isMacCms =>
      type.toLowerCase() == 'maccms' ||
      type.toLowerCase() == 'applecms' ||
      searchURL.contains('/api.php/provide/vod');

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
        api: json['api'],
        type: json['type'],
        name: json['name'],
        version: json['version'],
        muliSources: json['muliSources'],
        useWebview: json['useWebview'],
        useNativePlayer: json['useNativePlayer'],
        usePost: json['usePost'] ?? false,
        useLegacyParser: json['useLegacyParser'] ?? false,
        userAgent: json['userAgent'],
        baseUrl: json['baseURL'],
        searchURL: json['searchURL'],
        searchList: json['searchList'],
        searchName: json['searchName'],
        searchResult: json['searchResult'],
        chapterRoads: json['chapterRoads'],
        chapterResult: json['chapterResult'],
        // Use referer if provided, otherwise fallback to baseURL
        referer: json['referer'] ?? json['baseURL'] ?? '');
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
        referer: '');
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
    return data;
  }

  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    if (isMacCms) {
      return _queryMacCmsBangumi(keyword, shouldRethrow: shouldRethrow);
    }

    String queryURL = searchURL.replaceAll('@keyword', keyword);
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
        'referer': '$baseUrl/',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      resp = await Request().post(postUri.toString(),
          options: Options(headers: httpHeaders),
          extra: {'customError': ''},
          data: queryParams,
          shouldRethrow: shouldRethrow);
    } else {
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
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
        SearchItem searchItem = SearchItem(
          name: element.queryXPath(searchName).node!.text?.trim() ?? '',
          src: srcUrl,
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

  /// 苹果 CMS V10 标准 JSON 采集接口搜索
  Future<PluginSearchResponse> _queryMacCmsBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    String queryURL;
    if (searchURL.isNotEmpty) {
      queryURL = searchURL.replaceAll('@keyword', Uri.encodeComponent(keyword));
    } else {
      queryURL = baseUrl.endsWith('/')
          ? '${baseUrl}api.php/provide/vod/?ac=videolist&at=json&wd=${Uri.encodeComponent(keyword)}'
          : '$baseUrl/api.php/provide/vod/?ac=videolist&at=json&wd=${Uri.encodeComponent(keyword)}';
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
          if (vodName.isNotEmpty && vodId.isNotEmpty) {
            final detailSrc = '/api.php/provide/vod/?ac=detail&at=json&ids=$vodId';
            searchItems.add(SearchItem(name: vodName, src: detailSrc));
            KazumiLogger().log(Level.info, '$name [MacCMS] $vodName $detailSrc');
          }
        }
      }
    }

    return PluginSearchResponse(pluginName: name, data: searchItems);
  }

  Future<List<Road>> querychapterRoads(String url,
      {CancelToken? cancelToken}) async {
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
      'referer': '$baseUrl/',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
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
