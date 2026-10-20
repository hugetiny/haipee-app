/// Represents a segment / interval returned by AniSkip API.
class AniSkipInterval {
  final double startTime;
  final double endTime;
  final String skipType; // 'op', 'ed', 'recap', 'mixed-op', 'mixed-ed'
  final String? skipId;
  final double episodeLength;

  const AniSkipInterval({
    required this.startTime,
    required this.endTime,
    required this.skipType,
    this.skipId,
    this.episodeLength = 0.0,
  });

  bool get isOp => skipType.toLowerCase().contains('op');
  bool get isEd => skipType.toLowerCase().contains('ed');
  bool get isRecap => skipType.toLowerCase().contains('recap');

  String get typeLabel {
    if (isOp) return '片头 (OP)';
    if (isEd) return '片尾 (ED)';
    if (isRecap) return '前情回顾 (Recap)';
    return '片段';
  }

  /// Whether given playback position (seconds) falls inside this interval.
  bool containsSeconds(double seconds) {
    return seconds >= startTime && seconds <= endTime;
  }

  /// Whether given playback duration falls inside this interval.
  bool contains(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;
    return containsSeconds(seconds);
  }

  factory AniSkipInterval.fromJson(Map<String, dynamic> json) {
    final interval = json['interval'] as Map<String, dynamic>? ?? {};
    return AniSkipInterval(
      startTime: (interval['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (interval['endTime'] as num?)?.toDouble() ?? 0.0,
      skipType: json['skipType'] as String? ?? 'op',
      skipId: json['skipId'] as String?,
      episodeLength: (json['episodeLength'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': {
          'startTime': startTime,
          'endTime': endTime,
        },
        'skipType': skipType,
        'skipId': skipId,
        'episodeLength': episodeLength,
      };

  @override
  String toString() =>
      'AniSkipInterval($skipType: ${startTime.toStringAsFixed(1)}s -> ${endTime.toStringAsFixed(1)}s)';
}
