import 'package:haipee/request/request.dart';
import 'package:haipee/request/api.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/modules/danmaku/danmaku_module.dart';
import 'package:haipee/modules/danmaku/danmaku_search_response.dart';
import 'package:haipee/modules/danmaku/danmaku_episode_response.dart';
import 'package:haipee/modules/danmaku/danmaku_ch_convert.dart';
import 'package:haipee/modules/danmaku/danmaku_title_cleaner.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/string_match.dart';

class DanmakuRequest {
  /// 从 BgmBangumiID 获取 DanDanBangumiID
  /// 
  /// 视频播放过程中的弹幕请求默认全静默处理（silent = true），
  /// 无论凭据未配置、未收录还是网络异常，均静默降级为 0，绝不弹窗打扰播放。
  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID,
      {bool silent = true}) async {
    if (bgmBangumiID <= 0) {
      return 0;
    }
    if (!GStorage.hasValidDanDanCredentials()) {
      HaipeeLogger().log(Level.debug, 'DanDanPlay 凭据未配置，跳过弹幕番剧ID检索');
      return 0;
    }
    try {
      var path = Api.formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bgmBangumiID]);
      var endPoint = Api.dandanAPIDomain + path;
      final res = await Request().get(
        endPoint,
        extra: {'customError': '', 'silent': true},
        shouldRethrow: !silent,
      );
      if (res.data == null || res.data is! Map) {
        return 0;
      }
      Map<String, dynamic> jsonData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      DanmakuEpisodeResponse danmakuEpisodeResponse =
          DanmakuEpisodeResponse.fromJson(jsonData);
      return danmakuEpisodeResponse.bangumiId;
    } catch (e) {
      HaipeeLogger().log(
          Level.warning, '通过BgmId获取DanDanBangumiID失败 ($bgmBangumiID): $e');
      if (silent) return 0;
      rethrow;
    }
  }

  /// 清洗复杂视频文件名/种子标题，提取纯净番剧名称以便弹弹play检索
  static String cleanAnimeTitleForSearch(String raw) {
    final extracted = DanmakuTitleCleaner.extractCleanTitle(raw);
    if (extracted.isNotEmpty) return extracted;
    var t = raw.trim();
    // 移除文件后缀
    t = t.replaceAll(RegExp(r'\.(mp4|mkv|avi|flv|wmv|ts|m4v|mov)$', caseSensitive: false), '');
    // 移除字幕组前缀
    t = t.replaceAll(RegExp(r'^[\[【][^\]】]*?[\]】]'), ' ');
    // 移除常见分辨率、编码与来源标签
    t = t.replaceAll(RegExp(r'\[[^\]]*?(?:1080|720|2160|4k|x264|x265|hevc|web|aac|chs|cht|gb|big5|bili|baha)[^\]]*?\]', caseSensitive: false), ' ');
    // 移除集数后缀 如 - 01, 第01话, E01
    t = t.replaceAll(RegExp(r'(?:第\s*\d+\s*[话集]|[-_]\s*\d+(?:\.5)?\b|\b[Ss]\d{1,2}[Ee]\d{1,2}\b)'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isNotEmpty ? t : raw.trim();
  }

  /// 从标题获取 DanDanBangumiID
  static Future<int> getBangumiIDByTitle(String title,
      {bool silent = true}) async {
    final cleanInput = title.trim();
    if (cleanInput.isEmpty) return 0;
    if (!GStorage.hasValidDanDanCredentials()) {
      HaipeeLogger().log(Level.debug, 'DanDanPlay 凭据未配置，跳过标题匹配弹幕');
      return 0;
    }
    try {
      final sanitizedTitle = cleanAnimeTitleForSearch(cleanInput);
      DanmakuSearchResponse danmakuSearchResponse =
          await getDanmakuSearchResponse(sanitizedTitle, silent: silent);

      // 若清洗后标题未检索到结果，且与原标题不同，则以原标题回退重试一次
      if (danmakuSearchResponse.animes.isEmpty && sanitizedTitle != cleanInput) {
        danmakuSearchResponse = await getDanmakuSearchResponse(cleanInput, silent: silent);
      }

      int bestAnimeId = 0;
      double maxSimilarity = 0;

      for (var anime in danmakuSearchResponse.animes) {
        int animeId = anime.animeId;
        if (animeId >= 100000 || animeId < 2) {
          continue;
        }

        String animeTitle = anime.animeTitle;
        double similarity = calculateSimilarity(animeTitle, sanitizedTitle);
        if (similarity == 1) {
          HaipeeLogger().log(Level.debug, '完全匹配番剧弹幕 $sanitizedTitle');
          return animeId;
        }

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          bestAnimeId = animeId;
          HaipeeLogger()
              .log(Level.debug, '匹配番剧弹幕 $sanitizedTitle --- $animeTitle 相似度: $similarity');
        }
      }
      return bestAnimeId;
    } catch (e) {
      if (silent) return 0;
      rethrow;
    }
  }

  /// 从 BangumiID 获取 DanDan 分集数据
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
      int bangumiID,
      {bool silent = true}) async {
    if (bangumiID <= 0) {
      return DanmakuEpisodeResponse.fromTemplate();
    }
    if (!GStorage.hasValidDanDanCredentials()) {
      HaipeeLogger().log(Level.debug, 'DanDanPlay 凭据未配置，跳过分集数据检索');
      return DanmakuEpisodeResponse.fromTemplate();
    }
    try {
      var path = Api.dandanAPIInfo + bangumiID.toString();
      var endPoint = Api.dandanAPIDomain + path;
      final res = await Request().get(
        endPoint,
        extra: {'customError': '', 'silent': true},
        shouldRethrow: !silent,
      );
      if (res.data == null || res.data is! Map) {
        return DanmakuEpisodeResponse.fromTemplate();
      }
      Map<String, dynamic> jsonData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      DanmakuEpisodeResponse danmakuEpisodeResponse =
          DanmakuEpisodeResponse.fromJson(jsonData);
      return danmakuEpisodeResponse;
    } catch (e) {
      HaipeeLogger().log(Level.warning, '获取DanDan分集数据失败 ($bangumiID): $e');
      if (silent) return DanmakuEpisodeResponse.fromTemplate();
      rethrow;
    }
  }

  /// 从标题检索 DanDan 番剧数据库
  static Future<DanmakuSearchResponse> getDanmakuSearchResponse(String title,
      {bool silent = true}) async {
    if (title.trim().isEmpty) {
      return DanmakuSearchResponse(
        animes: [],
        errorCode: 0,
        success: true,
        errorMessage: '',
      );
    }
    if (!GStorage.hasValidDanDanCredentials()) {
      HaipeeLogger().log(Level.debug, 'DanDanPlay 凭据未配置，跳过搜索请求');
      return DanmakuSearchResponse(
        animes: [],
        errorCode: -1,
        success: false,
        errorMessage: 'DanDanPlay credentials not configured',
      );
    }
    var path = Api.dandanAPISearch;
    var endPoint = Api.dandanAPIDomain + path;
    Map<String, String> keywordMap = {
      'keyword': title,
    };

    try {
      final res = await Request().get(
        endPoint,
        data: keywordMap,
        extra: {'customError': '', 'silent': true},
        shouldRethrow: !silent,
      );
      if (res.data == null || res.data is! Map) {
        return DanmakuSearchResponse(
          animes: [],
          errorCode: -1,
          success: false,
          errorMessage: 'Invalid response',
        );
      }
      Map<String, dynamic> jsonData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      DanmakuSearchResponse danmakuSearchResponse =
          DanmakuSearchResponse.fromJson(jsonData);
      return danmakuSearchResponse;
    } catch (e) {
      if (silent) {
        return DanmakuSearchResponse(
          animes: [],
          errorCode: -1,
          success: false,
          errorMessage: e.toString(),
        );
      }
      rethrow;
    }
  }

  static Future<List<Danmaku>> getDanDanmaku(int bangumiID, int episode,
      {bool silent = true}) async {
    List<Danmaku> danmakus = [];
    if (bangumiID <= 0 || episode < 0) {
      return danmakus;
    }
    if (!GStorage.hasValidDanDanCredentials()) {
      return danmakus;
    }
    var path = Api.dandanAPIComment +
        bangumiID.toString() +
        episode.toString().padLeft(4, '0');
    var endPoint = Api.dandanAPIDomain + path;
    try {
      final conversion = DanmakuChConvert.fromValue(
        GStorage.getSetting(SettingsKeys.danmakuChConvert),
      );
      Map<String, String> queryParameters = {
        'withRelated': 'true',
        'chConvert': conversion.value.toString(),
      };
      HaipeeLogger().log(Level.info, "弹幕请求最终URL $endPoint");
      final res = await Request().get(
        endPoint,
        data: queryParameters,
        extra: {'customError': '', 'silent': true},
        shouldRethrow: !silent,
      );

      if (res.data == null || res.data is! Map) {
        return danmakus;
      }
      Map<String, dynamic> jsonData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      List<dynamic>? comments = jsonData['comments'];
      if (comments == null) {
        return danmakus;
      }

      for (var comment in comments) {
        if (comment is Map) {
          Danmaku danmaku = Danmaku.fromJson(comment is Map<String, dynamic>
              ? comment
              : Map<String, dynamic>.from(comment));
          danmakus.add(danmaku);
        }
      }
      return danmakus;
    } catch (e) {
      if (silent) return [];
      rethrow;
    }
  }

  static Future<List<Danmaku>> getDanDanmakuByEpisodeID(int episodeID,
      {bool silent = true}) async {
    List<Danmaku> danmakus = [];
    if (episodeID <= 0) {
      return danmakus;
    }
    if (!GStorage.hasValidDanDanCredentials()) {
      return danmakus;
    }
    var path = Api.dandanAPIComment + episodeID.toString();
    var endPoint = Api.dandanAPIDomain + path;
    try {
      final conversion = DanmakuChConvert.fromValue(
        GStorage.getSetting(SettingsKeys.danmakuChConvert),
      );
      Map<String, String> queryParameters = {
        'withRelated': 'true',
        'chConvert': conversion.value.toString(),
      };
      final res = await Request().get(
        endPoint,
        data: queryParameters,
        extra: {'customError': '', 'silent': true},
        shouldRethrow: !silent,
      );
      if (res.data == null || res.data is! Map) {
        return danmakus;
      }
      Map<String, dynamic> jsonData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : Map<String, dynamic>.from(res.data as Map);
      List<dynamic>? comments = jsonData['comments'];
      if (comments == null) {
        return danmakus;
      }

      for (var comment in comments) {
        if (comment is Map) {
          Danmaku danmaku = Danmaku.fromJson(comment is Map<String, dynamic>
              ? comment
              : Map<String, dynamic>.from(comment));
          danmakus.add(danmaku);
        }
      }
      return danmakus;
    } catch (e) {
      if (silent) return [];
      rethrow;
    }
  }
}
