import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class CollectedBangumi {
  BangumiItem bangumiItem;

  DateTime time;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  int type;

  String get key => bangumiItem.id.toString();

  CollectedBangumi(this.bangumiItem, this.time, this.type);

  static String getKey(BangumiItem bangumiItem) => bangumiItem.id.toString();

  Map<String, dynamic> toJson() {
    return {
      'bangumiItem': bangumiItem.toJson(),
      'time': time.millisecondsSinceEpoch,
      'type': type,
    };
  }

  factory CollectedBangumi.fromJson(Map<String, dynamic> json) {
    return CollectedBangumi(
      BangumiItem.fromJson(json['bangumiItem']),
      DateTime.fromMillisecondsSinceEpoch(json['time']),
      json['type'],
    );
  }

  @override
  String toString() {
    return 'type: $type, time: $time, anime: ${bangumiItem.name}';
  }
}
