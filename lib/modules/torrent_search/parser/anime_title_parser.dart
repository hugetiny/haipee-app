class AnimeTitleParseResult {
  final String? subgroup;
  final String? episode;
  final String? resolution;
  final String? language;
  final String cleanedTitle;

  const AnimeTitleParseResult({
    this.subgroup,
    this.episode,
    this.resolution,
    this.language,
    required this.cleanedTitle,
  });
}

class AnimeTitleParser {
  static final RegExp _bracketPrefixRegex = RegExp(r'^(?:\[([^\]]+)\]|【([^】]+)】)');
  static final RegExp _resolutionRegex = RegExp(r'\b(4k|2160p|1080p|720p|480p)\b', caseSensitive: false);

  // 集数识别正则：合集/范围优先，单集次之
  static final List<RegExp> _episodeRegexes = [
    RegExp(r'(\d{1,3}\s*[-~–—]\s*\d{1,3}|全[集話]|Fin)', caseSensitive: false),
    RegExp(r'(?:第|\bEP?|\bE)\s*(\d{1,3}(?:\.\d)?)\s*(?:[话話集]|\b)', caseSensitive: false),
    RegExp(r'\[(\d{1,3}(?:\.\d)?)\]'),
    RegExp(r'[\s_\-–—](\d{1,3}(?:\.\d)?)[\s_\-–—]'),
    RegExp(r'\b(\d{1,2}(?:\.\d)?)\s*(?:话|話|集)'),
  ];

  // 语言/字幕识别
  static final List<MapEntry<RegExp, String>> _languagePatterns = [
    MapEntry(RegExp(r'(简日|繁日|双语|双語|Bilingual)', caseSensitive: false), '双语'),
    MapEntry(RegExp(r'(简繁|简繁内封|簡繁內封)', caseSensitive: false), '简繁内封'),
    MapEntry(RegExp(r'(简体|简中|CHS|GB|SC)', caseSensitive: false), '简中'),
    MapEntry(RegExp(r'(繁体|繁中|CHT|BIG5|TC)', caseSensitive: false), '繁中'),
    MapEntry(RegExp(r'(日文|RAW|NC-RAW)', caseSensitive: false), '日文/无字'),
  ];

  // 非字幕组标签过滤
  static final RegExp _tagFilterRegex = RegExp(r'新番|月|TV|BDRip|WebRip|Movie|OVA|OAD', caseSensitive: false);

  /// 解析标题文本
  static AnimeTitleParseResult parse(String rawTitle) {
    String working = rawTitle.trim();

    // 1. 提取字幕组
    String? subgroup;
    final prefixMatch = _bracketPrefixRegex.firstMatch(working);
    if (prefixMatch != null) {
      final candidate = (prefixMatch.group(1) ?? prefixMatch.group(2) ?? '').trim();
      if (!_tagFilterRegex.hasMatch(candidate)) {
        subgroup = candidate;
      }
    }

    // 2. 提取分辨率
    String? resolution;
    final resMatch = _resolutionRegex.firstMatch(working);
    if (resMatch != null) {
      resolution = resMatch.group(1)?.toUpperCase();
    }

    // 3. 提取语言
    String? language;
    for (final entry in _languagePatterns) {
      if (entry.key.hasMatch(working)) {
        language = entry.value;
        break;
      }
    }

    // 4. 提取集数
    String? episode;
    for (final reg in _episodeRegexes) {
      final epMatch = reg.firstMatch(working);
      if (epMatch != null) {
        final val = epMatch.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          // 如果是范围或文字（如 01-28, 全集），直接使用
          if (val.contains(RegExp(r'[-~–—]')) || val.contains('全') || val.toLowerCase() == 'fin') {
            episode = val.replaceAll(' ', '');
            break;
          }
          final numVal = double.tryParse(val);
          if (numVal != null && (numVal > 1900 || numVal == 1080 || numVal == 720 || numVal == 480)) {
            continue;
          }
          episode = val.padLeft(2, '0');
          break;
        }
      }
    }

    // 5. 生成对小白友好的干净标题
    var cleaned = working;
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'【[^】]*】'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\.(mkv|mp4|avi|rmvb|flv)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return AnimeTitleParseResult(
      subgroup: subgroup,
      episode: episode,
      resolution: resolution,
      language: language,
      cleanedTitle: cleaned.isNotEmpty ? cleaned : rawTitle,
    );
  }
}
