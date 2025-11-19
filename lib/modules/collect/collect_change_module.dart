// The box stores the changes history of collected bangumi
// The changes will be used to sync with webDav
class CollectedBangumiChange {
  // timestamp in seconds
  int id;

  int bangumiID;

  // 1. add
  // 2. update
  // 3. delete
  int action;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  int type;

  int timestamp;

  CollectedBangumiChange(
      this.id, this.bangumiID, this.action, this.type, this.timestamp);

  @override
  String toString() {
    return 'id: $id, bangumi: $bangumiID, action: $action, time: $timestamp';
  }

  factory CollectedBangumiChange.fromJson(Map<String, dynamic> json) {
    return CollectedBangumiChange(
      json['id'] as int,
      json['bangumiID'] as int,
      json['action'] as int,
      json['type'] as int,
      json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bangumiID': bangumiID,
      'action': action,
      'type': type,
      'timestamp': timestamp,
    };
  }
}
