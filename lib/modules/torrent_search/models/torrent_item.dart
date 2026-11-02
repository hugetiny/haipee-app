enum TorrentSourceType {
  mikan,
  nyaa,
  torznab,
  cardigann,
  piratebay,
  indexerPlugin,
  prowlarr,
  dmhy,
  torrentscsv,
}

enum TorrentCategory {
  all,
  video,
  audio,
  software,
  game,
  document,
}

extension TorrentCategoryExtension on TorrentCategory {
  String get label => switch (this) {
    TorrentCategory.all => '全部',
    TorrentCategory.video => '视频',
    TorrentCategory.audio => '音频',
    TorrentCategory.software => '软件',
    TorrentCategory.game => '游戏',
    TorrentCategory.document => '文档',
  };
}

enum TorrentSortMode {
  seeders,
  age,
  size,
  leechers,
  title,
  source,
  smart,
}

enum TorrentHealth {
  high,
  medium,
  low,
  dead,
}

extension TorrentHealthExtension on TorrentHealth {
  String get label => switch (this) {
    TorrentHealth.high => '极佳',
    TorrentHealth.medium => '良好',
    TorrentHealth.low => '较慢',
    TorrentHealth.dead => '无做种',
  };
}

enum TorrentLinkType {
  dual,
  torrentOnly,
  magnetOnly,
  none,
}

class TorrentItem {
  final String title;
  final String magnetUrl;
  final String? torrentUrl;
  final String? pageUrl;
  final String fileSize;
  final int sizeBytes;
  final String publishDate;
  final String? rawPublishDate;
  final TorrentSourceType source;
  final String? indexerName;
  final String? indexerId;
  final int seeders;
  final int leechers;

  // 经过标题清洗后的结构化元数据（小白用户友好）
  final String? cleanedTitle;
  final String? episode;
  final String? season;
  final String? year;
  final String? subgroup;
  final String? resolution;
  final String? mediaSource;
  final String? codec;
  final String? audio;
  final bool isCam;
  final bool isFreeleech;
  final String? language;
  final TorrentCategory? customCategory;
  final TorrentSortMode? sortMode;
  /// 索引器/站点访问性质：'public' (公开免登), 'semi-private' (半私有), 'private' (私有 PT)
  final String? trackerType;

  const TorrentItem({
    required this.title,
    required this.magnetUrl,
    this.torrentUrl,
    this.pageUrl,
    this.fileSize = '',
    this.sizeBytes = 0,
    this.publishDate = '',
    this.rawPublishDate,
    required this.source,
    this.indexerName,
    this.indexerId,
    this.seeders = 0,
    this.leechers = 0,
    this.cleanedTitle,
    this.episode,
    this.season,
    this.year,
    this.subgroup,
    this.resolution,
    this.mediaSource,
    this.codec,
    this.audio,
    this.isCam = false,
    this.isFreeleech = false,
    this.language,
    this.customCategory,
    this.sortMode,
    this.trackerType,
  });

  bool get isPrivateTracker => trackerType?.toLowerCase() == 'private';
  bool get isSemiPrivateTracker => trackerType?.toLowerCase() == 'semi-private';
  bool get isPublicTracker => trackerType == null || trackerType?.toLowerCase() == 'public';

  String get trackerTypeLabel {
    if (isPrivateTracker) return '私有 PT';
    if (isSemiPrivateTracker) return '半私有';
    return '公开';
  }

  TorrentItem copyWith({
    String? title,
    String? magnetUrl,
    String? torrentUrl,
    String? pageUrl,
    String? fileSize,
    int? sizeBytes,
    String? publishDate,
    String? rawPublishDate,
    TorrentSourceType? source,
    String? indexerName,
    String? indexerId,
    int? seeders,
    int? leechers,
    String? cleanedTitle,
    String? episode,
    String? season,
    String? year,
    String? subgroup,
    String? resolution,
    String? mediaSource,
    String? codec,
    String? audio,
    bool? isCam,
    bool? isFreeleech,
    String? language,
    TorrentCategory? customCategory,
    TorrentSortMode? sortMode,
    String? trackerType,
  }) {
    return TorrentItem(
      title: title ?? this.title,
      magnetUrl: magnetUrl ?? this.magnetUrl,
      torrentUrl: torrentUrl ?? this.torrentUrl,
      pageUrl: pageUrl ?? this.pageUrl,
      fileSize: fileSize ?? this.fileSize,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      publishDate: publishDate ?? this.publishDate,
      rawPublishDate: rawPublishDate ?? this.rawPublishDate,
      source: source ?? this.source,
      indexerName: indexerName ?? this.indexerName,
      indexerId: indexerId ?? this.indexerId,
      seeders: seeders ?? this.seeders,
      leechers: leechers ?? this.leechers,
      cleanedTitle: cleanedTitle ?? this.cleanedTitle,
      episode: episode ?? this.episode,
      season: season ?? this.season,
      year: year ?? this.year,
      subgroup: subgroup ?? this.subgroup,
      resolution: resolution ?? this.resolution,
      mediaSource: mediaSource ?? this.mediaSource,
      codec: codec ?? this.codec,
      audio: audio ?? this.audio,
      isCam: isCam ?? this.isCam,
      isFreeleech: isFreeleech ?? this.isFreeleech,
      language: language ?? this.language,
      customCategory: customCategory ?? this.customCategory,
      sortMode: sortMode ?? this.sortMode,
      trackerType: trackerType ?? this.trackerType,
    );
  }

  /// 链接类型判断
  bool get hasTorrent {
    if (torrentUrl != null &&
        torrentUrl!.isNotEmpty &&
        !torrentUrl!.startsWith('magnet:?')) {
      return true;
    }
    if (magnetUrl.startsWith('http://') || magnetUrl.startsWith('https://')) {
      return true;
    }
    return false;
  }

  bool get hasMagnet {
    if (magnetUrl.startsWith('magnet:?')) {
      return true;
    }
    if (torrentUrl != null && torrentUrl!.startsWith('magnet:?')) {
      return true;
    }
    return false;
  }

  bool get isDualSource => hasTorrent && hasMagnet;

  TorrentLinkType get linkType {
    if (hasTorrent && hasMagnet) return TorrentLinkType.dual;
    if (hasTorrent) return TorrentLinkType.torrentOnly;
    if (hasMagnet) return TorrentLinkType.magnetOnly;
    return TorrentLinkType.none;
  }

  String get linkTypeLabel => switch (linkType) {
        TorrentLinkType.dual => '种子+磁力',
        TorrentLinkType.torrentOnly => '种子',
        TorrentLinkType.magnetOnly => '磁力',
        TorrentLinkType.none => '无链接',
      };

  String? get effectiveTorrentUrl {
    if (torrentUrl != null &&
        torrentUrl!.isNotEmpty &&
        !torrentUrl!.startsWith('magnet:?')) {
      return torrentUrl;
    }
    if (magnetUrl.startsWith('http://') || magnetUrl.startsWith('https://')) {
      return magnetUrl;
    }
    return null;
  }

  String? get effectiveMagnetUrl {
    if (magnetUrl.startsWith('magnet:?')) {
      return magnetUrl;
    }
    if (torrentUrl != null && torrentUrl!.startsWith('magnet:?')) {
      return torrentUrl;
    }
    return null;
  }

  /// 压缩包格式判断
  String? get archiveFormatName {
    final lower = title.toLowerCase();
    if (lower.contains('.zip') || lower.endsWith('.zip')) return 'ZIP';
    if (lower.contains('.rar') || lower.endsWith('.rar')) return 'RAR';
    if (lower.contains('.7z') || lower.endsWith('.7z')) return '7Z';
    if (lower.contains('.iso') || lower.endsWith('.iso')) return 'ISO';
    if (lower.contains('.tar') || lower.endsWith('.tar.gz')) return 'TAR';
    return null;
  }

  bool get isArchive => archiveFormatName != null;

  TorrentCategory get category {
    if (customCategory != null) return customCategory!;
    final lower = title.toLowerCase();
    if (lower.endsWith('.opus') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wma') ||
        lower.endsWith('.dsf') ||
        lower.endsWith('.dff')) {
      return TorrentCategory.audio;
    }
    return TorrentCategory.all;
  }

  bool get isVideo => category == TorrentCategory.video;
  bool get isAudio => category == TorrentCategory.audio;
  bool get isGame => category == TorrentCategory.game;
  bool get isDocument => category == TorrentCategory.document;
  bool get isSoftware => category == TorrentCategory.software;

  bool get isCollection {
    final lower = title.toLowerCase();
    return lower.contains(RegExp(r'\d{1,2}-\d{1,2}')) ||
        lower.contains('完结') ||
        lower.contains('complete') ||
        lower.contains('s01-s05') ||
        lower.contains('前篇+后篇') ||
        lower.contains('+ost');
  }

  /// 辅助判断未明确分类资源是否具备客观的视频特征（用于在「全部」视图中按需展示在线看）
  bool get _hasVideoClues {
    if (episode != null && episode!.isNotEmpty) return true;
    if (resolution != null && resolution!.isNotEmpty) return true;
    if (codec != null && codec!.isNotEmpty) return true;
    if (mediaSource != null && mediaSource!.isNotEmpty) return true;
    final lower = title.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m2ts') ||
        lower.endsWith('.rmvb') ||
        lower.contains('1080p') ||
        lower.contains('720p') ||
        lower.contains('2160p') ||
        lower.contains('4k') ||
        lower.contains('web-dl') ||
        lower.contains('bdrip') ||
        lower.contains('blu-ray') ||
        lower.contains('bluray') ||
        lower.contains('x264') ||
        lower.contains('x265') ||
        lower.contains('hevc');
  }

  /// 辅助判断未明确分类资源是否具备客观的音频特征（用于在「全部」视图中按需展示在线听）
  bool get _hasAudioClues {
    final lower = title.toLowerCase();
    return lower.endsWith('.flac') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wma') ||
        lower.endsWith('.dsf') ||
        lower.endsWith('.dff') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.alac') ||
        lower.endsWith('.ape') ||
        lower.contains('flac') ||
        lower.contains('lossless') ||
        lower.contains('ost');
  }

  bool get canStreamVideo =>
      !isArchive &&
      !isGame &&
      !isDocument &&
      !isSoftware &&
      (isVideo || (category == TorrentCategory.all && _hasVideoClues && !_hasAudioClues));

  bool get canStreamAudio =>
      !isArchive &&
      !isGame &&
      !isDocument &&
      !isSoftware &&
      !isVideo &&
      (isAudio || (category == TorrentCategory.all && _hasAudioClues));

  bool get isPlayable => canStreamVideo || canStreamAudio;

  /// 小白友好的精炼副标题，例如："爱恋字幕组 · 1080P · 简中 · 850 MB"
  String get simplifiedSubtitle {
    final parts = <String>[];
    if (subgroup != null && subgroup!.isNotEmpty) parts.add(subgroup!);
    if (resolution != null && resolution!.isNotEmpty) parts.add(resolution!);
    if (language != null && language!.isNotEmpty) parts.add(language!);
    final size = displayFileSize;
    if (size.isNotEmpty && size != '-') parts.add(size);
    return parts.join(' · ');
  }

  /// 小白友好的主标题：如果有识别出集数，优先展示 "第 XX 集"，否则展示清洗后的标题
  String get displayTitle {
    if (episode != null && episode!.isNotEmpty) {
      return '第 $episode 集';
    }
    if (cleanedTitle != null && cleanedTitle!.isNotEmpty) {
      return cleanedTitle!;
    }
    return title;
  }

  /// 真实计算后的精确字节数（排序核心依据）
  int get effectiveSizeBytes {
    if (sizeBytes > 0) return sizeBytes;
    if (fileSize.isNotEmpty) {
      return parseSizeToBytes(fileSize);
    }
    return 0;
  }

  /// 适合人类易读展示的体积字符串（如 1.45 GB、850 MB 等）
  String get displayFileSize {
    if (fileSize.isNotEmpty &&
        fileSize != '0 B' &&
        fileSize != '0' &&
        fileSize != '-') {
      return fileSize;
    }
    if (effectiveSizeBytes > 0) {
      return formatBytes(effectiveSizeBytes);
    }
    return '-';
  }

  /// 真实解析后的精确发布时间对象（排序核心依据，支持 ISO、RFC2822、标准年月日、相对时间）
  DateTime? get effectivePublishDate {
    if (rawPublishDate != null && rawPublishDate!.isNotEmpty) {
      final d = parseDateTime(rawPublishDate);
      if (d != null) return d;
    }
    if (publishDate.isNotEmpty) {
      final d = parseDateTime(publishDate);
      if (d != null) return d;
    }
    return null;
  }

  /// 适合人类易读展示的发布日期字符串
  String get displayAge {
    if (publishDate.isNotEmpty && publishDate != '-') {
      return publishDate;
    }
    final dt = effectivePublishDate;
    if (dt != null) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  String get ageString => displayAge;
  String get tableResolution => resolution ?? '';
  String get tableCodecInfo => codec ?? mediaSource ?? '';
  TorrentHealth get health {
    if (seeders >= 10) return TorrentHealth.high;
    if (seeders >= 3) return TorrentHealth.medium;
    if (seeders >= 1) return TorrentHealth.low;
    return TorrentHealth.dead;
  }
  String get effectiveSourceName => indexerName ?? source.name;

  /// 解析各类易读文件大小为字节数 (Byte)
  static int parseSizeToBytes(String raw) {
    if (raw.isEmpty) return 0;
    final clean = raw.trim().toLowerCase().replaceAll(',', '');
    final direct = int.tryParse(clean);
    if (direct != null) return direct;

    final match = RegExp(r'^([\d.]+)\s*([a-z]+)?$').firstMatch(clean);
    if (match == null) return 0;

    final numVal = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = match.group(2) ?? '';

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    const tb = gb * 1024;

    if (unit.startsWith('t')) {
      return (numVal * tb).round();
    }
    if (unit.startsWith('g')) {
      return (numVal * gb).round();
    }
    if (unit.startsWith('m')) {
      return (numVal * mb).round();
    }
    if (unit.startsWith('k')) {
      return (numVal * kb).round();
    }
    if (unit.startsWith('b') || unit.isEmpty) {
      return numVal.round();
    }
    return numVal.round();
  }

  /// 格式化字节数为人类易读的 MB, GB, TB
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    const tb = gb * 1024;

    if (bytes >= tb) {
      return '${(bytes / tb).toStringAsFixed(2)} TB';
    }
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  /// 智能解析各类时间字符串为 DateTime
  static DateTime? parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();

    // 1. 标准 ISO 8601 / YYYY-MM-DD
    final direct = DateTime.tryParse(clean);
    if (direct != null) return direct;

    // 2. UNIX 时间戳
    final timestamp = int.tryParse(clean);
    if (timestamp != null && timestamp > 100000000) {
      if (timestamp > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }

    // 3. RFC-2822 / HTTP 格式 (e.g. "Fri, 20 Oct 2023 15:30:00 -0000")
    try {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final parts = clean.split(RegExp(r'[\s,]+'));
      int? day, month, year;
      int hour = 0, minute = 0, second = 0;
      for (final p in parts) {
        final lower = p.toLowerCase();
        if (months.containsKey(lower)) {
          month = months[lower];
        } else if (p.contains(':')) {
          final timeParts = p.split(':');
          if (timeParts.length >= 2) {
            hour = int.tryParse(timeParts[0]) ?? 0;
            minute = int.tryParse(timeParts[1]) ?? 0;
            if (timeParts.length >= 3) {
              second = int.tryParse(timeParts[2]) ?? 0;
            }
          }
        } else if (int.tryParse(p) != null) {
          final val = int.parse(p);
          if (val >= 1970 && val <= 2100) {
            year = val;
          } else if (val >= 1 && val <= 31 && day == null) {
            day = val;
          }
        }
      }
      if (year != null && month != null && day != null) {
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (_) {}

    // 4. 相对时间计算（如 "3小时前", "2 days ago"）
    final now = DateTime.now();
    final lower = clean.toLowerCase();
    final numMatch = RegExp(r'(\d+)').firstMatch(clean);
    if (numMatch != null) {
      final n = int.parse(numMatch.group(1)!);
      if (lower.contains('sec') || lower.contains('秒')) {
        return now.subtract(Duration(seconds: n));
      }
      if (lower.contains('min') || lower.contains('分')) {
        return now.subtract(Duration(minutes: n));
      }
      if (lower.contains('hour') || lower.contains('小时') || lower.contains('点')) {
        return now.subtract(Duration(hours: n));
      }
      if (lower.contains('day') || lower.contains('天')) {
        return now.subtract(Duration(days: n));
      }
      if (lower.contains('week') || lower.contains('周') || lower.contains('星期')) {
        return now.subtract(Duration(days: n * 7));
      }
      if (lower.contains('month') || lower.contains('月')) {
        return now.subtract(Duration(days: n * 30));
      }
      if (lower.contains('year') || lower.contains('年')) {
        return now.subtract(Duration(days: n * 365));
      }
    }

    return null;
  }
}
