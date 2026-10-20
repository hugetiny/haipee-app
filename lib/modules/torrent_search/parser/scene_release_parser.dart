class ParsedSceneInfo {
  final String? cleanTitle;
  final String? year;
  final String? season;
  final String? episode;
  final String? resolution;
  final String? source;
  final String? codec;
  final String? audio;
  final String? releaseGroup;
  final bool isCam;

  const ParsedSceneInfo({
    this.cleanTitle,
    this.year,
    this.season,
    this.episode,
    this.resolution,
    this.source,
    this.codec,
    this.audio,
    this.releaseGroup,
    this.isCam = false,
  });

  /// 格式化为 -arr 风格的质量徽章，如："WEB-DL · 1080p · x265"
  String get qualityBadge {
    final parts = <String>[];
    if (source != null) parts.add(source!);
    if (resolution != null) parts.add(resolution!);
    if (codec != null) parts.add(codec!);
    if (audio != null) parts.add(audio!);
    return parts.join(' · ');
  }
}

/// 通用 Scene / P2P 影视发布命名解析器（对标 Sonarr / Radarr 标准）
class SceneReleaseParser {
  static final RegExp _yearRegex = RegExp(r'\b(19\d{2}|20\d{2})\b');
  
  static final RegExp _resolutionRegex = RegExp(
    r'\b(2160p|4k|1080p|1080i|720p|576p|480p)\b',
    caseSensitive: false,
  );

  static final List<(RegExp pattern, String tag)> _sourcePatterns = [
    (RegExp(r'\b(Remux|BD-Remux)\b', caseSensitive: false), 'Remux'),
    (RegExp(r'\b(UHD[\s\.-]?BluRay|BluRay|BD[\s\.-]?Rip|BRRip)\b', caseSensitive: false), 'BluRay'),
    (RegExp(r'\b(WEB[\s\.-]?DL|WebDL)\b', caseSensitive: false), 'WEB-DL'),
    (RegExp(r'\b(WEBRip|Web-Rip)\b', caseSensitive: false), 'WEBRip'),
    (RegExp(r'\b(HDTV|HDTVRip)\b', caseSensitive: false), 'HDTV'),
    (RegExp(r'\b(DVDRip|DVD|DVD5|DVD9)\b', caseSensitive: false), 'DVD'),
    (RegExp(r'\b(CAM|HDCAM|CAMRip|TS|TELESYNC|HDTS|HD-TS)\b', caseSensitive: false), 'CAM'),
  ];

  static final List<(RegExp pattern, String tag)> _codecPatterns = [
    (RegExp(r'\b(x265|h\.?265|hevc)\b', caseSensitive: false), 'HEVC'),
    (RegExp(r'\b(x264|h\.?264|avc)\b', caseSensitive: false), 'AVC'),
    (RegExp(r'\b(av1)\b', caseSensitive: false), 'AV1'),
    (RegExp(r'\b(xvid)\b', caseSensitive: false), 'XviD'),
  ];

  static final List<(RegExp pattern, String tag)> _audioPatterns = [
    (RegExp(r'\bTrueHD\b', caseSensitive: false), 'TrueHD'),
    (RegExp(r'\b(DDP\d*(?:\.\d)?|EAC3)\b', caseSensitive: false), 'DDP'),
    (RegExp(r'\bDTS[\s\.-]?HD(?:\s*MA)?\b', caseSensitive: false), 'DTS-HD'),
    (RegExp(r'\bDTS\b', caseSensitive: false), 'DTS'),
    (RegExp(r'\b(AC3|DD\d*(?:\.\d)?)\b', caseSensitive: false), 'AC3'),
    (RegExp(r'\bFLAC\b', caseSensitive: false), 'FLAC'),
    (RegExp(r'\bAAC\b', caseSensitive: false), 'AAC'),
    (RegExp(r'\bAtmos\b', caseSensitive: false), 'Atmos'),
  ];

  static final RegExp _seasonEpRegex = RegExp(
    r'\bS(\d{1,2})(?:[\s\.-]?E(\d{1,3}))?\b',
    caseSensitive: false,
  );

  static final List<RegExp> _additionalEpRegexes = [
    RegExp(r'(?:第|\bEP?|\bE)\s*(\d{1,3}(?:\.\d)?)\s*(?:[话話集]|\b)', caseSensitive: false),
    RegExp(r'[\s_\-–—](\d{1,3}(?:\.\d)?)[\s_\-–—]'),
    RegExp(r'[\s_\-–—](\d{1,3}(?:\.\d)?)\s*\('),
    RegExp(r'\[(\d{1,3}(?:\.\d)?)\]'),
    RegExp(r'\b(\d{1,2}(?:\.\d)?)\s*(?:话|話|集)'),
  ];

  static final RegExp _camRegex = RegExp(
    r'\b(CAM|HDCAM|CAMRip|TS|TELESYNC|HDTS|HD-TS)\b',
    caseSensitive: false,
  );

  static final RegExp _bracketPrefix = RegExp(r'^(?:\[([^\]]+)\]|【([^】]+)】)');
  static final RegExp _sceneGroupSuffix = RegExp(r'-([a-zA-Z0-9_]+)(?:\.[a-zA-Z0-9]{2,4})?$');

  /// 解析发布名称
  static ParsedSceneInfo parse(String rawTitle) {
    final title = rawTitle.trim();

    // 1. 年份
    final year = _yearRegex.firstMatch(title)?.group(1);

    // 2. 分辨率 (Dart 3 模式匹配表达式)
    final resolution = switch (_resolutionRegex.firstMatch(title)?.group(1)?.toLowerCase()) {
      '4k' || '2160p' => '2160p',
      final r? => r,
      null => null,
    };

    // 3. 片源介质 (Dart 3 Records 解构)
    String? source;
    for (final (pattern, tag) in _sourcePatterns) {
      if (pattern.hasMatch(title)) {
        source = tag;
        break;
      }
    }

    // 4. 视频编码
    String? codec;
    for (final (pattern, tag) in _codecPatterns) {
      if (pattern.hasMatch(title)) {
        codec = tag;
        break;
      }
    }

    // 5. 音频编码
    String? audio;
    for (final (pattern, tag) in _audioPatterns) {
      if (pattern.hasMatch(title)) {
        audio = tag;
        break;
      }
    }

    // 6. 季数与集数
    String? season;
    String? episode;
    final seMatch = _seasonEpRegex.firstMatch(title);
    if (seMatch != null) {
      final s = seMatch.group(1);
      final e = seMatch.group(2);
      if (s != null) season = 'S${s.padLeft(2, '0')}';
      if (e != null) episode = 'E${e.padLeft(2, '0')}';
    }

    if (episode == null) {
      for (final reg in _additionalEpRegexes) {
        final epMatch = reg.firstMatch(title);
        if (epMatch != null) {
          final epStr = epMatch.group(1)?.trim();
          if (epStr != null && epStr.isNotEmpty) {
            final numVal = double.tryParse(epStr);
            if (numVal != null && (numVal > 1900 || numVal == 1080 || numVal == 720 || numVal == 480)) {
              continue;
            }
            episode = 'E${epStr.padLeft(2, '0')}';
            break;
          }
        }
      }
    }

    // 7. 发布组 (Group)
    final releaseGroup = switch (_bracketPrefix.firstMatch(title)) {
      Match m => (m.group(1) ?? m.group(2))?.trim(),
      null => _sceneGroupSuffix.firstMatch(title)?.group(1)?.trim(),
    };

    // 8. 枪版判定 (CAM / TS)
    final isCam = _camRegex.hasMatch(title);

    // 9. 干净标题清洗 (剔除年份及后面的技术后缀)
    String cleanTitle = title;
    // 如果有点分隔符形式 (Scene 格式: Dune.Part.Two.2024...)
    if (year != null && cleanTitle.contains(year)) {
      final yearIndex = cleanTitle.indexOf(year);
      cleanTitle = cleanTitle.substring(0, yearIndex).replaceAll('.', ' ').trim();
    } else if (season != null && cleanTitle.contains(RegExp(r'\bS\d{1,2}', caseSensitive: false))) {
      final sIndex = cleanTitle.indexOf(RegExp(r'\bS\d{1,2}', caseSensitive: false));
      cleanTitle = cleanTitle.substring(0, sIndex).replaceAll('.', ' ').trim();
    }
    // 清除头尾括号与扩展名
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'【[^】]*】'), ' ');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\.(mkv|mp4|avi|rmvb|flv|ts)$', caseSensitive: false), '');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedSceneInfo(
      cleanTitle: cleanTitle.isNotEmpty ? cleanTitle : title,
      year: year,
      season: season,
      episode: episode,
      resolution: resolution,
      source: source,
      codec: codec,
      audio: audio,
      releaseGroup: releaseGroup,
      isCam: isCam,
    );
  }
}
