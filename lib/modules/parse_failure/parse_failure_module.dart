/// 视频解析失败记录
class ParseFailureRecord {
  /// 番剧 ID (来自 BangumiItem)
  int bangumiId;

  /// 插件名称
  String pluginName;

  /// 解析地址 (src)
  String src;

  /// 失败次数
  int failureCount;

  /// 最后失败时间
  DateTime lastFailureTime;

  /// 失败原因 (超时/错误)
  String reason;

  ParseFailureRecord({
    required this.bangumiId,
    required this.pluginName,
    required this.src,
    required this.failureCount,
    required this.lastFailureTime,
    this.reason = 'timeout',
  });

  /// 生成唯一键: bangumiId_pluginName_src
  String get key => '${bangumiId}_${pluginName}_$src';

  /// 记录新的失败
  ParseFailureRecord incrementFailure({String? newReason}) {
    return ParseFailureRecord(
      bangumiId: bangumiId,
      pluginName: pluginName,
      src: src,
      failureCount: failureCount + 1,
      lastFailureTime: DateTime.now(),
      reason: newReason ?? reason,
    );
  }

  /// 从 Map 创建
  factory ParseFailureRecord.fromMap(Map<String, dynamic> map) {
    return ParseFailureRecord(
      bangumiId: map['bangumiId'] as int,
      pluginName: map['pluginName'] as String,
      src: map['src'] as String,
      failureCount: map['failureCount'] as int,
      lastFailureTime: DateTime.fromMillisecondsSinceEpoch(map['lastFailureTime'] as int),
      reason: map['reason'] as String? ?? 'timeout',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'bangumiId': bangumiId,
      'pluginName': pluginName,
      'src': src,
      'failureCount': failureCount,
      'lastFailureTime': lastFailureTime.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  factory ParseFailureRecord.fromJson(Map<String, dynamic> json) => ParseFailureRecord.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
