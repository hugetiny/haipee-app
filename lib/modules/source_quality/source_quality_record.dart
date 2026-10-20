import 'dart:math' as math;

/// 视频播放源历史画质与码率指标记录
class SourceQualityRecord {
  final int bangumiId;
  final String pluginName;
  final String src;
  final int width;
  final int height;
  final double videoBitrate; // 视频流码率 (bits per second)
  final double demuxBitrate; // 解复用封装总码率 (bits per second)
  final String codec; // 视频编码格式, 如 h264, hevc, av1
  final double fps; // 视频帧率
  final DateTime lastUpdated;

  const SourceQualityRecord({
    required this.bangumiId,
    required this.pluginName,
    required this.src,
    required this.width,
    required this.height,
    this.videoBitrate = 0.0,
    this.demuxBitrate = 0.0,
    this.codec = '',
    this.fps = 0.0,
    required this.lastUpdated,
  });

  /// 构建唯一键: '${bangumiId}_${pluginName}_$src'
  static String buildKey(int bangumiId, String pluginName, String src) {
    return '${bangumiId}_${pluginName}_$src';
  }

  String get key => buildKey(bangumiId, pluginName, src);

  /// 有效码率 (优先视频流码率，若无则使用封装流码率)
  double get effectiveBitrate => videoBitrate > 0 ? videoBitrate : demuxBitrate;

  /// 分辨率等级描述: 4K, 2K, 1080P, 720P, 480P, 360P 等
  String get resolutionLabel {
    if (width <= 0 && height <= 0) return '';
    final maxDim = math.max(width, height);
    final minDim = math.min(width, height);

    if (maxDim >= 3800 || minDim >= 2000) {
      return '4K';
    } else if (maxDim >= 2500 || minDim >= 1400) {
      return '2K';
    } else if (maxDim >= 1900 || minDim >= 1000) {
      return '1080P';
    } else if (maxDim >= 1200 || minDim >= 700) {
      return '720P';
    } else if (maxDim >= 800 || minDim >= 450) {
      return '480P';
    } else if (minDim > 0) {
      return '${minDim}P';
    }
    return '';
  }

  /// 码率可读文案: 例如 "2.5 Mbps", "850 kbps"
  String get bitrateLabel {
    final bps = effectiveBitrate;
    if (bps <= 0) return '';
    if (bps >= 1000000) {
      final mbps = bps / 1000000.0;
      return '${mbps.toStringAsFixed(1)} Mbps';
    } else {
      final kbps = bps / 1000.0;
      return '${kbps.toStringAsFixed(0)} kbps';
    }
  }

  /// 紧凑型顶部徽章文案: 例如 "1080P · 2.5 Mbps" 或 "1080P" 或 "2.5 Mbps"
  String get badgeLabel {
    final res = resolutionLabel;
    final br = bitrateLabel;
    if (res.isNotEmpty && br.isNotEmpty) {
      return '$res · $br';
    } else if (res.isNotEmpty) {
      return res;
    } else if (br.isNotEmpty) {
      return br;
    }
    return '';
  }

  /// 详细画质参数文案: 例如 "1080P (1920×1080, 2.5 Mbps, H264 60fps)"
  String get detailedLabel {
    final res = resolutionLabel;
    final br = bitrateLabel;
    final dim = (width > 0 && height > 0) ? '$width×$height' : '';
    final parts = <String>[];
    if (dim.isNotEmpty) parts.add(dim);
    if (br.isNotEmpty) parts.add(br);
    if (codec.isNotEmpty) parts.add(codec.toUpperCase());
    if (fps > 0) parts.add('${fps.toStringAsFixed(0)}fps');

    if (res.isNotEmpty && parts.isNotEmpty) {
      return '$res (${parts.join(', ')})';
    } else if (res.isNotEmpty) {
      return res;
    } else if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return '';
  }

  /// 画质综合评分 (用于按清晰度降序排序，高度占主权重，码率作为决胜指标)
  double get qualityScore {
    final hScore = height > 0 ? height.toDouble() : (width > 0 ? width * 9.0 / 16.0 : 0.0);
    final brScore = effectiveBitrate > 0 ? effectiveBitrate / 1000.0 : 0.0; // kbps
    return (hScore * 1000.0) + brScore;
  }

  Map<String, dynamic> toJson() => {
        'bangumiId': bangumiId,
        'pluginName': pluginName,
        'src': src,
        'width': width,
        'height': height,
        'videoBitrate': videoBitrate,
        'demuxBitrate': demuxBitrate,
        'codec': codec,
        'fps': fps,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory SourceQualityRecord.fromJson(Map<dynamic, dynamic> json) {
    return SourceQualityRecord(
      bangumiId: (json['bangumiId'] as num?)?.toInt() ?? 0,
      pluginName: (json['pluginName'] as String?) ?? '',
      src: (json['src'] as String?) ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      videoBitrate: (json['videoBitrate'] as num?)?.toDouble() ?? 0.0,
      demuxBitrate: (json['demuxBitrate'] as num?)?.toDouble() ?? 0.0,
      codec: (json['codec'] as String?) ?? '',
      fps: (json['fps'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
