class DanmakuEpisode {
  int episodeId;
  String episodeTitle;

  DanmakuEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  factory DanmakuEpisode.fromJson(Map<String, dynamic> json) {
    return DanmakuEpisode(
      episodeId: json['episodeId'] as int? ?? 0,
      episodeTitle: json['episodeTitle']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
    };
  }
}

class DanmakuEpisodeResponse {
  int bangumiId;
  List<DanmakuEpisode> episodes;
  int errorCode;
  bool success;
  String errorMessage;

  DanmakuEpisodeResponse({
    required this.bangumiId,
    required this.episodes,
    required this.errorCode,
    required this.success,
    required this.errorMessage,
  });

  factory DanmakuEpisodeResponse.fromJson(Map<String, dynamic> json) {
    final bangumiRaw = json['bangumi'];
    final Map<String, dynamic>? bangumi = bangumiRaw is Map
        ? (bangumiRaw is Map<String, dynamic>
            ? bangumiRaw
            : Map<String, dynamic>.from(bangumiRaw))
        : null;

    final rawEpisodes = bangumi?['episodes'];
    final List<DanmakuEpisode> episodeList = (rawEpisodes is List)
        ? rawEpisodes.whereType<Map>().map((i) {
            return DanmakuEpisode.fromJson(i is Map<String, dynamic>
                ? i
                : Map<String, dynamic>.from(i));
          }).toList()
        : <DanmakuEpisode>[];

    return DanmakuEpisodeResponse(
      bangumiId: bangumi?['animeId'] as int? ?? 0,
      episodes: episodeList,
      errorCode:
          json['errorCode'] as int? ?? (json['success'] == true ? 0 : -1),
      success: json['success'] as bool? ?? false,
      errorMessage: json['errorMessage']?.toString() ?? '',
    );
  }

  factory DanmakuEpisodeResponse.fromTemplate() {
    return DanmakuEpisodeResponse(
      bangumiId: 0,
      episodes: [],
      errorCode: 0,
      success: false,
      errorMessage: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bangumi': episodes.map((episode) => episode.toJson()).toList(),
      'errorCode': errorCode,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}
