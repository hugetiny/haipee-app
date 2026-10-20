import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';

part 'bangumi_item.g.dart';

@HiveType(typeId: 0)
class BangumiItem {
  @HiveField(0)
  int id;
  @HiveField(1)
  int type;
  @HiveField(2)
  String name;
  @HiveField(3)
  String nameCn;
  @HiveField(4)
  String summary;
  @HiveField(5)
  String airDate;
  @HiveField(6)
  int airWeekday;
  @HiveField(7)
  int rank;
  @HiveField(8)
  Map<String, String> images;
  @HiveField(9, defaultValue: [])
  List<BangumiTag> tags;
  @HiveField(10, defaultValue: [])
  List<String> alias;
  @HiveField(11, defaultValue: 0.0)
  double ratingScore;
  @HiveField(12, defaultValue: 0)
  int votes;
  @HiveField(13, defaultValue: [])
  List<int> votesCount;
  @HiveField(14, defaultValue: '')
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

  /// 动态构造安全的回退/非番剧元数据对象 (如 Bilibili、抖音、自定义 Web 规则源或直链)
  factory BangumiItem.dummy({
    int? id,
    String title = '未知视频',
    String image = '',
  }) {
    final effectiveTitle = title.trim().isNotEmpty ? title.trim() : '未知视频';
    final computedId = (id != null && id > 0)
        ? id
        : (effectiveTitle.hashCode.abs() % 2147483640 + 1);
    return BangumiItem(
      id: computedId,
      type: 2,
      name: effectiveTitle,
      nameCn: effectiveTitle,
      summary: '',
      airDate: '',
      airWeekday: 0,
      rank: 0,
      images: {
        "large": image,
        "common": image,
        "medium": image,
        "small": image,
        "grid": image,
      },
      tags: [],
      alias: [],
      ratingScore: 0.0,
      votes: 0,
      votesCount: [],
      info: '',
    );
  }

  /// 从番剧 info 元数据智能提取总集数/话数 (Animeko MediaSelector 对齐辅助)
  int? get totalEpisodes {
    if (info.isEmpty) return null;
    final match = RegExp(r'(?:话数|集数|总集数|eps)[:：\s]+(\d+)', caseSensitive: false).firstMatch(info);
    if (match != null && match.group(1) != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// 数据源站标识
  String get source => 'Bangumi';

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
      if (!jsonData.containsKey('rating') || jsonData['rating'] == null) {
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
    final ratingMap = json['rating'] is Map<String, dynamic>
        ? json['rating'] as Map<String, dynamic>
        : null;
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
      rank: ratingMap?['rank'] ?? 0,
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
          (ratingMap?['score'] ?? 0.0).toDouble().toStringAsFixed(1)),
      votes: ratingMap?['total'] ?? 0,
      votesCount: voteList,
      info: json['info'] ?? '',
    );
  }
}
