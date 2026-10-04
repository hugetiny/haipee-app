import 'package:kazumi/request/request.dart';
import 'package:kazumi/request/api.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/string_match.dart';

class DanmakuRequest {
  // 从BgmBangumiID获取DanDanBangumiID
  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    var path = Api.formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bgmBangumiID]);
    var endPoint = Api.dandanAPIDomain + path;
    final res = await Request()
        .get(endPoint, extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse.bangumiId;
  }

  // 从标题获取DanDanBangumiID
  static Future<int> getBangumiIDByTitle(String title) async {
    DanmakuSearchResponse danmakuSearchResponse =
        await getDanmakuSearchResponse(title);

    int bestAnimeId = 0;
    double maxSimilarity = 0;

    for (var anime in danmakuSearchResponse.animes) {
      int animeId = anime.animeId;
      if (animeId >= 100000 || animeId < 2) {
        continue;
      }

      String animeTitle = anime.animeTitle;
      double similarity = calculateSimilarity(animeTitle, title);
      if (similarity == 1) {
        KazumiLogger().log(Level.debug, '完全匹配番剧弹幕 $title');
        return animeId;
      }

      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        bestAnimeId = animeId;
        KazumiLogger()
            .log(Level.debug, '匹配番剧弹幕 $title --- $animeTitle 相似度: $similarity');
      }
    }
    return bestAnimeId;
  }

  // 从BangumiID获取DanDan分集数据
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
      int bangumiID) async {
    var path = Api.dandanAPIInfo + bangumiID.toString();
    var endPoint = Api.dandanAPIDomain + path;
    final res = await Request()
        .get(endPoint, extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse;
  }

  // 从标题检索DanDan番剧数据库
  static Future<DanmakuSearchResponse> getDanmakuSearchResponse(
      String title) async {
    var path = Api.dandanAPISearch;
    var endPoint = Api.dandanAPIDomain + path;
    Map<String, String> keywordMap = {
      'keyword': title,
    };

    final res = await Request().get(endPoint,
        data: keywordMap, extra: {'customError': '弹幕检索错误: 获取弹幕番剧ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuSearchResponse danmakuSearchResponse =
        DanmakuSearchResponse.fromJson(jsonData);
    return danmakuSearchResponse;
  }

  static Future<List<Danmaku>> getDanDanmaku(int bangumiID, int episode) async {
    List<Danmaku> danmakus = [];
    if (bangumiID == 0) {
      return danmakus;
    }
    var path = Api.dandanAPIComment +
        bangumiID.toString() +
        episode.toString().padLeft(4, '0');
    var endPoint = Api.dandanAPIDomain + path;
    final conversion = DanmakuChConvert.fromValue(
      GStorage.getSetting(SettingsKeys.danmakuChConvert),
    );
    Map<String, String> queryParameters = {
      'withRelated': 'true',
      'chConvert': conversion.value.toString(),
    };
    KazumiLogger().log(Level.info, "弹幕请求最终URL $endPoint");
    final res = await Request().get(endPoint,
        data: queryParameters, extra: {'customError': '弹幕检索错误: 获取弹幕失败'});

    Map<String, dynamic> jsonData = res.data;
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      Danmaku danmaku = Danmaku.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }

  static Future<List<Danmaku>> getDanDanmakuByEpisodeID(int episodeID) async {
    var path = Api.dandanAPIComment + episodeID.toString();
    var endPoint = Api.dandanAPIDomain + path;
    List<Danmaku> danmakus = [];
    final conversion = DanmakuChConvert.fromValue(
      GStorage.getSetting(SettingsKeys.danmakuChConvert),
    );
    Map<String, String> queryParameters = {
      'withRelated': 'true',
      'chConvert': conversion.value.toString(),
    };
    final res = await Request().get(endPoint,
        data: queryParameters, extra: {'customError': '弹幕检索错误: 获取弹幕失败'});
    Map<String, dynamic> jsonData = res.data;
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      Danmaku danmaku = Danmaku.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }
}
