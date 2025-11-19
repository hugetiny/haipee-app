import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';

class BangumiItem {
  int id;
  int type;
  String name;
  String nameCn;
  String summary;
  String airDate;
  int airWeekday;
  int rank;
  Map<String, String> images;
  List<BangumiTag> tags;
  List<String> alias;
  double ratingScore;
  int votes;
  List<int> votesCount;
  String info;

  BangumiItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.rank,
    required this.images,
    required this.tags,
    required this.alias,
    required this.ratingScore,
    required this.votes,
    required this.votesCount,
    required this.info,
  });

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    List<String> parseBangumiAliases(Map<String, dynamic> jsonData) {
      if (jsonData.containsKey('infobox') && jsonData['infobox'] is List) {
        final List<dynamic> infobox = jsonData['infobox'];
        for (var item in infobox) {
          if (item is Map<String, dynamic> && item['key'] == '别名') {
            final dynamic value = item['value'];
            if (value is List) {
              return value
                  .map<String>((element) {
                    if (element is Map<String, dynamic> &&
                        element.containsKey('v')) {
                      return element['v'].toString();
                    }
                    return '';
                  })
                  .where((alias) => alias.isNotEmpty)
                  .toList();
            }
          }
        }
      }
      return [];
    }

    List<int> parseBangumiVoteCount(Map<String, dynamic> jsonData) {
      if (!jsonData.containsKey('rating')) {
        return [];
      }
      final json = jsonData['rating']['count'];
      // For api.bgm.tv
      if (json is Map<String, dynamic>) {
        return List<int>.generate(10, (i) => json['${i + 1}'] as int);
      }
      // For next.bgm.tv
      if (json is List<dynamic>) {
        return json.map((e) => e as int).toList();
      }
      return [];
    }

    List list = json['tags'] ?? [];
    List<String> bangumiAlias = parseBangumiAliases(json);
    List<BangumiTag> tagList = list.map((i) => BangumiTag.fromJson(i)).toList();
    List<int> voteList = parseBangumiVoteCount(json);
    return BangumiItem(
      id: json['id'],
      type: json['type'] ?? 2,
      name: json['name'] ?? '',
      nameCn: (json['name_cn'] ?? '') == ''
          ? (((json['nameCN'] ?? '') == '') ? json['name'] : json['nameCN'])
          : json['name_cn'],
      summary: json['summary'] ?? '',
      airDate: json['date'] ?? '',
      airWeekday: Utils.dateStringToWeekday(json['date'] ?? '2000-11-11'),
      rank: json['rating']['rank'] ?? 0,
      images: Map<String, String>.from(
        json['images'] ??
            {
              "large": json['image'],
              "common": "",
              "medium": "",
              "small": "",
              "grid": ""
            },
      ),
      tags: tagList,
      alias: bangumiAlias,
      ratingScore: double.parse(
          (json['rating']['score'] ?? 0.0).toDouble().toStringAsFixed(1)),
      votes: json['rating']['total'] ?? 0,
      votesCount: voteList,
      info: json['info'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'name_cn': nameCn,
      'summary': summary,
      'date': airDate,
      'rating': {
        'rank': rank,
        'score': ratingScore,
        'total': votes,
        'count': {
          for (var i = 0; i < votesCount.length; i++) '${i + 1}': votesCount[i]
        }
      },
      'images': images,
      'tags': tags.map((e) => e.toJson()).toList(),
      'alias': alias,
      'info': info,
    };
  }
}
