import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/comments/comment_response.dart';
import 'package:haipee/modules/characters/characters_response.dart';
import 'package:haipee/modules/bangumi/episode_item.dart';
import 'package:haipee/modules/character/character_full_item.dart';
import 'package:haipee/modules/staff/staff_response.dart';

class BangumiHTTP {
  // why the api havn't been replaced by getCalendarBySearch?
  // Because getCalendarBySearch is not stable, it will miss some bangumi items.
  static Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await Request().get(
        Api.bangumiAPINextDomain + Api.bangumiCalendar,
      );
      final jsonData = res.data;
      if (jsonData is Map) {
        for (int i = 1; i <= 7; i++) {
          List<BangumiItem> bangumiList = [];
          final jsonList = jsonData['$i'];
          if (jsonList is Iterable) {
            for (dynamic jsonItem in jsonList) {
              try {
                BangumiItem bangumiItem =
                    BangumiItem.fromJson(jsonItem['subject']);
                bangumiList.add(bangumiItem);
              } catch (_) {}
            }
          }
          bangumiCalendar.add(bangumiList);
        }
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve calendar failed ${e.toString()}');
    }
    return bangumiCalendar;
  }

  // Get clander by search API, we need a list of strings (the start of the season and the end of the season) eg: ["2024-07-01", "2024-10-01"]
  // because the air date is the launch date of the anime, it is usually a few days before the start of the season
  // So we usually use the start of the season month -1 and the end of the season month -1
  static Future<List<List<BangumiItem>>> getCalendarBySearch(
      List<String> dateRange, int limit, int offset) async {
    List<BangumiItem> bangumiList = [];
    List<List<BangumiItem>> bangumiCalendar = [];
    var params = <String, dynamic>{
      "keyword": "",
      "sort": "rank",
      "filter": {
        "type": [2],
        "tag": ["日本"],
        "air_date": [">=${dateRange[0]}", "<${dateRange[1]}"],
        "rank": [">0", "<=99999"],
        "nsfw": true
      }
    };
    try {
      final url = Api.formatUrl(
          Api.bangumiAPIDomain + Api.bangumiRankSearch, [limit, offset]);
      final res = await Request().post(
        url,
        data: params,
      );
      final jsonData = res.data;
      if (jsonData is Map) {
        final jsonList = jsonData['data'];
        if (jsonList is Iterable) {
          for (dynamic jsonItem in jsonList) {
            if (jsonItem is Map<String, dynamic>) {
              bangumiList.add(BangumiItem.fromJson(jsonItem));
            }
          }
        }
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi list failed ${e.toString()}');
    }
    try {
      for (int weekday = 1; weekday <= 7; weekday++) {
        List<BangumiItem> bangumiDayList = [];
        for (BangumiItem bangumiItem in bangumiList) {
          if (bangumiItem.airWeekday == weekday) {
            bangumiDayList.add(bangumiItem);
          }
        }
        bangumiCalendar.add(bangumiDayList);
      }
    } catch (e) {
      HaipeeLogger().log(
          Level.error, 'Fetch bangumi item to calendar failed ${e.toString()}');
    }
    return bangumiCalendar;
  }

  static Future<List<BangumiItem>> getBangumiList(
      {int rank = 2,
      String tag = '',
      int type = 2,
      int limit = 100,
      int offset = 0}) async {
    List<BangumiItem> bangumiList = [];
    late Map<String, dynamic> params;
    if (tag == '') {
      params = <String, dynamic>{
        'keyword': '',
        'sort': 'rank',
        "filter": {
          "type": [type],
          "rank": [">$rank", "<=99999"],
          "nsfw": false
        },
      };
    } else {
      params = <String, dynamic>{
        'keyword': '',
        'sort': 'rank',
        "filter": {
          "type": [type],
          "tag": [tag],
          "rank": [">$rank", "<=99999"],
          "nsfw": false
        },
      };
    }
    try {
      final res = await Request().post(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiRankSearch, [limit, offset]),
        data: params,
      );
      final jsonData = res.data;
      if (jsonData is Map) {
        final jsonList = jsonData['data'];
        if (jsonList is Iterable) {
          for (dynamic jsonItem in jsonList) {
            if (jsonItem is Map<String, dynamic>) {
              bangumiList.add(BangumiItem.fromJson(jsonItem));
            }
          }
        }
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi list failed ${e.toString()}');
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> getBangumiTrendsList(
      {int type = 2, int limit = 24, int offset = 0}) async {
    List<BangumiItem> bangumiList = [];
    var params = <String, dynamic>{
      'type': type,
      'limit': limit,
      'offset': offset,
    };
    try {
      final res = await Request().get(
        Api.bangumiAPINextDomain + Api.bangumiTrendsNext,
        data: params,
      );
      final jsonData = res.data;
      if (jsonData is Map) {
        final jsonList = jsonData['data'];
        if (jsonList is Iterable) {
          for (dynamic jsonItem in jsonList) {
            if (jsonItem is Map<String, dynamic>) {
              if (jsonItem['subject'] is Map<String, dynamic>) {
                bangumiList.add(BangumiItem.fromJson(jsonItem['subject']));
              } else if (jsonItem.containsKey('id')) {
                bangumiList.add(BangumiItem.fromJson(jsonItem));
              }
            }
          }
        }
      }
    } catch (e) {
      HaipeeLogger().log(
          Level.error, 'Resolve bangumi trends list failed ${e.toString()}');
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> bangumiSearch(String keyword,
      {List<String> tags = const [],
      int offset = 0,
      String sort = 'heat'}) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': sort,
      "filter": {
        "type": [2],
        "tag": tags,
        "rank": (sort == 'rank') ? [">0", "<=99999"] : [">=0", "<=99999"],
        "nsfw": false
      },
    };

    try {
      final res = await Request().post(
        Api.formatUrl(
            Api.bangumiAPIDomain + Api.bangumiRankSearch, [20, offset]),
        data: params,
      );
      final jsonData = res.data;
      if (jsonData is Map) {
        final jsonList = jsonData['data'];
        if (jsonList is Iterable) {
          for (dynamic jsonItem in jsonList) {
            if (jsonItem is Map<String, dynamic>) {
              try {
                BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
                if (bangumiItem.nameCn != '') {
                  bangumiList.add(bangumiItem);
                }
              } catch (e) {
                HaipeeLogger().log(
                    Level.error, 'Resolve search results failed ${e.toString()}');
              }
            }
          }
        }
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, 'Unknown search problem ${e.toString()}');
    }
    return bangumiList;
  }

  static Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await Request().get(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiInfoByID, [id]),
      );
      return BangumiItem.fromJson(res.data);
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi item failed ${e.toString()}');
      return null;
    }
  }

  static Future<EpisodeInfo> getBangumiEpisodeByID(int id, int episode) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    if (id <= 0) {
      return episodeInfo;
    }
    var params = <String, dynamic>{
      'subject_id': id,
      'offset': episode - 1,
      'limit': 1
    };
    try {
      final res = await Request().get(
        Api.bangumiAPIDomain + Api.bangumiEpisodeByID,
        data: params,
      );
      if (res.data is Map &&
          res.data['data'] is List &&
          (res.data['data'] as List).isNotEmpty) {
        final jsonData = res.data['data'][0];
        if (jsonData is Map<String, dynamic>) {
          episodeInfo = EpisodeInfo.fromJson(jsonData);
        }
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi episode failed ${e.toString()}');
    }
    return episodeInfo;
  }

  static Future<CommentResponse> getBangumiCommentsByID(int id,
      {int offset = 0}) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    if (id <= 0) return commentResponse;
    try {
      final res = await Request().get(
        Api.formatUrl(Api.bangumiAPINextDomain + Api.bangumiCommentsByIDNext,
            [id, 20, offset]),
      );
      final jsonData = res.data;
      if (jsonData is Map<String, dynamic> &&
          (jsonData.containsKey('list') || jsonData.containsKey('data'))) {
        commentResponse = CommentResponse.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<EpisodeCommentResponse> getBangumiCommentsByEpisodeID(
      int id) async {
    EpisodeCommentResponse commentResponse =
        EpisodeCommentResponse.fromTemplate();
    if (id <= 0) {
      return commentResponse;
    }
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPINextDomain + Api.bangumiEpisodeCommentsByIDNext,
            [id]),
      );
      final jsonData = res.data;
      if (jsonData is List) {
        commentResponse = EpisodeCommentResponse.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger().log(Level.error,
          'Resolve bangumi episode comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(
      int id) async {
    CharacterCommentResponse commentResponse =
        CharacterCommentResponse.fromTemplate();
    if (id <= 0) return commentResponse;
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPINextDomain + Api.bangumiCharacterCommentsByIDNext,
            [id]),
      );
      final jsonData = res.data;
      if (jsonData is List) {
        commentResponse = CharacterCommentResponse.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger().log(Level.error,
          'Resolve bangumi character comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<StaffResponse> getBangumiStaffByID(int id) async {
    StaffResponse staffResponse = StaffResponse.fromTemplate();
    if (id <= 0) return staffResponse;
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPINextDomain + Api.bangumiStaffByIDNext, [id]),
      );
      final jsonData = res.data;
      if (jsonData is Map<String, dynamic>) {
        staffResponse = StaffResponse.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve bangumi staff failed ${e.toString()}');
    }
    return staffResponse;
  }

  static Future<CharactersResponse> getCharatersByBangumiID(int id) async {
    CharactersResponse charactersResponse = CharactersResponse.fromTemplate();
    if (id <= 0) return charactersResponse;
    try {
      final res = await Request().get(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiCharacterByID, [id]),
      );
      final jsonData = res.data;
      if (jsonData is List) {
        charactersResponse = CharactersResponse.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger().log(
          Level.error, 'Resolve bangumi characters failed ${e.toString()}');
    }
    return charactersResponse;
  }

  static Future<CharacterFullItem> getCharacterByCharacterID(int id) async {
    CharacterFullItem characterFullItem = CharacterFullItem.fromTemplate();
    if (id <= 0) return characterFullItem;
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPINextDomain +
                Api.bangumiCharacterInfoByCharacterIDNext,
            [id]),
      );
      final jsonData = res.data;
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('id')) {
        characterFullItem = CharacterFullItem.fromJson(jsonData);
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.error, 'Resolve character info failed ${e.toString()}');
    }
    return characterFullItem;
  }
}
