import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kazumi/utils/logger.dart';

/// 抖音短视频原生抽取与无水印直链解析服务
class DouyinVideoItem {
  final String id;
  final String title;
  final String author;
  final String cover;
  final String playUrl;
  final int duration;

  const DouyinVideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.playUrl,
    this.duration = 0,
  });
}

class DouyinService {
  static final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent': 'okhttp/3.10.0.1',
      },
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  /// 检查文本中是否包含抖音域名或短链接
  static bool hasDouyinUrl(String input) {
    return RegExp(r'https?://(?:[a-zA-Z0-9.-]*\.)?douyin\.com/').hasMatch(input) ||
        input.contains('v.douyin.com') ||
        input.contains('iesdouyin.com');
  }

  /// 检查输入是否为抖音相关内容（包含抖音链接或18-20位纯数字视频ID）
  static bool hasDouyinPattern(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return false;
    if (hasDouyinUrl(clean)) return true;
    if (extractItemId(clean) != null) return true;
    return false;
  }

  /// 从抖音分享文本、URL 或纯数字 ID 抽取视频 ID
  static String? extractItemId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // 1. 标准 URL 路径与参数匹配: video/1234567890123456789, modal_id=..., note/..., aweme_id=...
    final urlParamMatch =
        RegExp(r'(?:video/|modal_id=|note/|aweme_id=)(\d{15,22})').firstMatch(clean);
    if (urlParamMatch != null) {
      return urlParamMatch.group(1);
    }

    // 2. 独立纯数字视频 ID (15 到 22 位十进制数字)
    final rawNumMatch = RegExp(r'^\d{15,22}$').firstMatch(clean);
    if (rawNumMatch != null) {
      return rawNumMatch.group(0);
    }

    return null;
  }

  /// 解析抖音短链接 (v.douyin.com/xxx) 获取重定向后的视频 ID
  static Future<String?> resolveShortUrl(
    String shareTextOrUrl, {
    Dio? client,
  }) async {
    final effectiveClient = client ?? _dio;
    final urlMatch =
        RegExp(r'(?:https?://)?[vV]\.douyin\.com/([a-zA-Z0-9_-]+)').firstMatch(shareTextOrUrl);
    if (urlMatch == null) return null;

    final rawUrl = urlMatch.group(0)!;
    final shortUrl = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    try {
      // 优先通过 HEAD 请求直接嗅探 location 重定向头
      final headRes = await effectiveClient.head(
        shortUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => true,
        ),
      );

      final location = headRes.headers.value('location');
      if (location != null && location.isNotEmpty) {
        final idFromLoc = extractItemId(location);
        if (idFromLoc != null) return idFromLoc;
      }

      // 若未直接获得完整 location，跟随重定向获取最终 URL
      final getRes = await effectiveClient.get(
        shortUrl,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => true,
        ),
      );
      final finalUrl = getRes.realUri.toString();
      return extractItemId(finalUrl);
    } catch (e) {
      KazumiLogger().d('解析抖音短链接重定向失败: $e');
      return null;
    }
  }

  /// 解析抖音直链获取无水印 MP4 CDN 地址与视频信息
  ///
  /// 若输入仅为普通搜索关键词（非视频分享链接或纯数字ID），返回 null，绝不触发无谓的网络请求或异常。
  static Future<DouyinVideoItem?> extractVideo(
    String shareTextOrUrl, {
    Dio? client,
  }) async {
    final clean = shareTextOrUrl.trim();
    if (clean.isEmpty) return null;

    // 非抖音分享内容或非纯视频ID时直接返回，避免无谓网络解析与报错
    if (!hasDouyinPattern(clean)) {
      return null;
    }

    final effectiveClient = client ?? _dio;
    try {
      String? itemId = extractItemId(clean);

      // 若未直接抽取到视频 ID，且包含短链接，尝试追踪重定向
      itemId ??= await resolveShortUrl(clean, client: effectiveClient);

      if (itemId == null) {
        return null;
      }

      // 1. 优先调用移动端官方 feed 接口 (高稳定、免 Cookie 校验、直接下发无水印 CDN 直链)
      final feedItem = await _fetchFromFeedApi(itemId, effectiveClient);
      if (feedItem != null) {
        return feedItem;
      }

      // 2. 备选接口: 官方 Web 端详情接口 (安全兜底并防范 Argus 拦截)
      final webItem = await _fetchFromWebDetailApi(itemId, effectiveClient);
      if (webItem != null) {
        return webItem;
      }
    } catch (e) {
      KazumiLogger().d('抖音视频原生抽取异常: $e');
    }

    return null;
  }

  /// 统一解析单个 aweme 视频对象为 DouyinVideoItem
  static DouyinVideoItem? _parseAwemeItem(Map<String, dynamic> item) {
    try {
      final itemId = item['aweme_id']?.toString().trim() ??
          item['group_id']?.toString().trim() ??
          '';
      if (itemId.isEmpty) return null;

      final title = item['desc']?.toString().trim() ?? '抖音视频';
      final author = item['author']?['nickname']?.toString().trim() ?? '抖音创作者';

      final videoObj = item['video'] as Map<String, dynamic>?;

      // 封面解析 (优先常规封面，兜底原始封面与动态封面)
      String cover = '';
      final coverList = (videoObj?['cover']?['url_list'] ??
              videoObj?['origin_cover']?['url_list'] ??
              item['word_cover']?['url_list']) as List<dynamic>?;
      if (coverList != null && coverList.isNotEmpty) {
        cover = coverList.first.toString();
        if (cover.startsWith('http://')) {
          cover = cover.replaceFirst('http://', 'https://');
        }
      }

      // 播放直链提取 (playwm -> play，自动升级 https)
      final playAddrList = videoObj?['play_addr']?['url_list'] as List<dynamic>?;
      String cleanPlayUrl = '';
      if (playAddrList != null && playAddrList.isNotEmpty) {
        final rawPlayUrl = playAddrList.first.toString();
        cleanPlayUrl = rawPlayUrl.replaceAll('playwm', 'play');
        if (cleanPlayUrl.startsWith('http://')) {
          cleanPlayUrl = cleanPlayUrl.replaceFirst('http://', 'https://');
        }
      }

      int durationSec = 0;
      final rawDuration = item['duration'] ?? videoObj?['duration'];
      if (rawDuration is num) {
        final intMs = rawDuration.toInt();
        durationSec = intMs > 1000 ? intMs ~/ 1000 : intMs;
      }

      return DouyinVideoItem(
        id: itemId,
        title: title.isEmpty ? '抖音视频' : title,
        author: author.isEmpty ? '抖音创作者' : author,
        cover: cover,
        playUrl: cleanPlayUrl,
        duration: durationSec,
      );
    } catch (_) {
      return null;
    }
  }

  /// 官方移动端 feed 接口请求解析
  static Future<DouyinVideoItem?> _fetchFromFeedApi(
    String itemId,
    Dio client,
  ) async {
    try {
      final res = await client.get(
        'https://aweme.snssdk.com/aweme/v1/feed/',
        queryParameters: {'aweme_id': itemId},
        options: Options(
          headers: {'User-Agent': 'okhttp/3.10.0.1'},
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );

      if (res.data == null) return null;
      final rawStr = res.data.toString().trim();
      if (!rawStr.startsWith('{')) return null;

      final dynamic decoded = jsonDecode(rawStr);
      if (decoded is! Map<String, dynamic>) return null;

      final awemeList = decoded['aweme_list'] as List<dynamic>?;
      if (awemeList == null || awemeList.isEmpty) return null;

      // 必须严格匹配请求的目标 itemId，避免把推荐流中的第一条随机视频误当做目标条目
      final match = awemeList.firstWhere(
        (it) =>
            it is Map<String, dynamic> &&
            (it['aweme_id']?.toString().trim() == itemId ||
                it['group_id']?.toString().trim() == itemId),
        orElse: () => null,
      );

      if (match != null) {
        final parsed = _parseAwemeItem(match as Map<String, dynamic>);
        if (parsed != null && parsed.playUrl.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      KazumiLogger().d('Feed API 解析抖音视频异常: $e');
    }
    return null;
  }

  /// 官方 Web 网页详情备用接口解析 (带类型安全防护)
  static Future<DouyinVideoItem?> _fetchFromWebDetailApi(
    String itemId,
    Dio client,
  ) async {
    try {
      final detailRes = await client.get(
        'https://www.iesdouyin.com/aweme/v1/web/aweme/detail/',
        queryParameters: {'aweme_id': itemId},
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );

      if (detailRes.data == null) return null;
      final rawStr = detailRes.data.toString().trim();
      // 拦截非 JSON (如 ArgusSecurityPlugin 拦截的纯文本或 HTML)
      if (!rawStr.startsWith('{')) return null;

      final dynamic decoded = jsonDecode(rawStr);
      if (decoded is! Map<String, dynamic>) return null;

      final detail = decoded['aweme_detail'] as Map<String, dynamic>?;
      if (detail != null) {
        final parsed = _parseAwemeItem(detail);
        if (parsed != null && parsed.playUrl.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      KazumiLogger().d('Web Detail API 解析抖音视频异常: $e');
    }
    return null;
  }


  /// 官方移动端推荐 Feed 流拉取 (免鉴权高稳定直出 365yg/pstatp 无水印直链)
  static Future<List<DouyinVideoItem>> _fetchFeedVideos(
    Dio client, {
    int count = 15,
  }) async {
    final list = <DouyinVideoItem>[];
    try {
      final res = await client.get(
        'https://aweme.snssdk.com/aweme/v1/feed/',
        queryParameters: {'count': count},
        options: Options(
          headers: {'User-Agent': 'okhttp/3.10.0.1'},
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );

      if (res.data == null) return list;
      final rawStr = res.data.toString().trim();
      if (!rawStr.startsWith('{')) return list;

      final dynamic decoded = jsonDecode(rawStr);
      if (decoded is! Map<String, dynamic>) return list;

      final awemeList = decoded['aweme_list'] as List<dynamic>?;
      if (awemeList == null || awemeList.isEmpty) return list;

      for (final rawItem in awemeList) {
        if (rawItem is Map<String, dynamic>) {
          final parsed = _parseAwemeItem(rawItem);
          if (parsed != null && parsed.playUrl.isNotEmpty) {
            list.add(parsed);
          }
        }
      }
    } catch (e) {
      KazumiLogger().d('Feed 流拉取异常: $e');
    }
    return list;
  }

  /// 获取抖音精选推荐短视频流 (供用户在未输入关键词时浏览体验)
  static Future<List<DouyinVideoItem>> getRecommendedVideos({
    Dio? client,
    int count = 15,
  }) async {
    final effectiveClient = client ?? _dio;
    return _fetchFeedVideos(effectiveClient, count: count);
  }

  /// 抖音短视频搜索与直链解析
  ///
  /// 架构与工程规范说明：
  /// 抖音官方 Web 端实施严格的 a_bogus 浏览器指纹校验并对搜索接口强制要求扫码登录（状态码 2483）。
  /// 任何试图在客户端逆向拼凑头条或非官方推荐接口的做法都是脆弱不可靠的非主流 hack，会导致结果为空或错误。
  /// 因此 Kazumi 彻底放弃脆弱的假搜索逻辑，抖音仅保留粘贴链接/口令/ID 时的纯直链解析与播放。
  ///
  /// - 若输入包含确切短链、分享文本或纯数字 ID：直接提取并返回该视频单条结果；
  /// - 若输入仅为普通文本关键词：直接返回空列表，绝不进行假搜索或填充无关推荐。
  static Future<List<DouyinVideoItem>> searchVideos(
    String keyword, {
    Dio? client,
  }) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];

    final effectiveClient = client ?? _dio;

    // 仅在匹配到确切抖音分享链接、短链或视频 ID 时进行单条直链抽取
    if (hasDouyinPattern(clean)) {
      final direct = await extractVideo(clean, client: effectiveClient);
      if (direct != null) {
        return [direct];
      }
    }

    return const [];
  }

  /// 搜索词建议补全检索 (无需登录，稳定返回联想词)
  static Future<List<String>> fetchSearchSuggestions(
    String keyword, {
    Dio? client,
  }) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return const [];

    final effectiveClient = client ?? _dio;
    try {
      final res = await effectiveClient.get(
        'https://aweme.snssdk.com/aweme/v1/search/sug/',
        queryParameters: {
          'keyword': clean,
          'aid': '1128',
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'okhttp/3.10.0.1'},
          validateStatus: (status) => true,
        ),
      );

      if (res.data == null) return const [];
      final rawStr = res.data.toString().trim();
      if (!rawStr.startsWith('{')) return const [];

      final dynamic decoded = jsonDecode(rawStr);
      if (decoded is! Map<String, dynamic>) return const [];

      final list = decoded['sug_list'] as List<dynamic>?;
      if (list == null) return const [];

      final results = <String>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final word = item['content']?.toString().trim();
          if (word != null && word.isNotEmpty && !results.contains(word)) {
            results.add(word);
          }
        }
      }
      return results;
    } catch (e) {
      KazumiLogger().d('获取抖音搜索建议异常: $e');
      return const [];
    }
  }

  /// 获取抖音热门榜单推荐词
  static Future<List<String>> getHotBillboard({Dio? client}) async {
    final effectiveClient = client ?? _dio;
    try {
      final res = await effectiveClient.get(
        'https://www.iesdouyin.com/web/api/v2/hotsearch/billboard/word/',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );

      if (res.data == null) return const [];
      final rawStr = res.data.toString().trim();
      if (!rawStr.startsWith('{')) return const [];

      final dynamic decoded = jsonDecode(rawStr);
      if (decoded is! Map<String, dynamic>) return const [];

      final list = decoded['word_list'] as List<dynamic>?;
      if (list == null) return const [];

      final results = <String>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final word = item['word']?.toString().trim();
          if (word != null && word.isNotEmpty && !results.contains(word)) {
            results.add(word);
          }
        }
      }
      return results;
    } catch (e) {
      KazumiLogger().d('获取抖音热搜榜单异常: $e');
      return const [];
    }
  }
}
