import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class Progress {
  int episode;

  int road;

  int _progressInMilli;

  Duration get progress => Duration(milliseconds: _progressInMilli);

  set progress(Duration d) => _progressInMilli = d.inMilliseconds;

  Progress(this.episode, this.road, this._progressInMilli);

  Map<String, dynamic> toJson() {
    return {
      'episode': episode,
      'road': road,
      '_progressInMilli': _progressInMilli,
    };
  }

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      json['episode'],
      json['road'],
      json['_progressInMilli'],
    );
  }

  @override
  String toString() {
    return 'Episode ${episode.toString()}, progress $progress';
  }
}

class History {
  Map<int, Progress> progresses = {};

  int lastWatchEpisode;

  String adapterName;

  BangumiItem bangumiItem;

  DateTime lastWatchTime;

  String lastSrc;

  String lastWatchEpisodeName;

  String get key => adapterName + bangumiItem.id.toString();

  History(this.bangumiItem, this.lastWatchEpisode, this.adapterName,
      this.lastWatchTime, this.lastSrc, this.lastWatchEpisodeName);

  static String getKey(String n, BangumiItem s) => n + s.id.toString();

  Map<String, dynamic> toJson() {
    return {
      'progresses': progresses.map((k, v) => MapEntry(k.toString(), v.toJson())),
      'lastWatchEpisode': lastWatchEpisode,
      'adapterName': adapterName,
      'bangumiItem': bangumiItem.toJson(),
      'lastWatchTime': lastWatchTime.millisecondsSinceEpoch,
      'lastSrc': lastSrc,
      'lastWatchEpisodeName': lastWatchEpisodeName,
    };
  }

  factory History.fromJson(Map<String, dynamic> json) {
    final history = History(
      BangumiItem.fromJson(json['bangumiItem']),
      json['lastWatchEpisode'],
      json['adapterName'],
      DateTime.fromMillisecondsSinceEpoch(json['lastWatchTime']),
      json['lastSrc'],
      json['lastWatchEpisodeName'] ?? '',
    );
    if (json['progresses'] != null) {
      history.progresses = (json['progresses'] as Map).map(
        (k, v) => MapEntry(int.parse(k.toString()), Progress.fromJson(v)),
      );
    }
    return history;
  }

  @override
  String toString() {
    return 'Adapter: $adapterName, anime: ${bangumiItem.name}';
  }
}
