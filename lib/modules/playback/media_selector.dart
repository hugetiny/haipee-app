/// Result of Animeko MediaSelector intelligent episode alignment.
class MediaEpisodeResolution {
  final int bangumiEpisode;
  final int danmakuEpisode;
  final double episodeFloat;
  final bool isSpecial;
  final int season;
  final int seasonOffset;
  final String displayLabel;

  const MediaEpisodeResolution({
    required this.bangumiEpisode,
    required this.danmakuEpisode,
    required this.episodeFloat,
    required this.isSpecial,
    required this.season,
    required this.seasonOffset,
    required this.displayLabel,
  });

  @override
  String toString() =>
      'MediaEpisodeResolution(bgmEp: $bangumiEpisode, ddmkEp: $danmakuEpisode, float: $episodeFloat, season: $season, isSp: $isSpecial, label: $displayLabel)';
}

/// Animeko MediaSelector 剧集智能对齐算法 (Episode & Season Index Mapping)
///
/// 解决抓取源剧集索引 (通常每季从 1..N 编号)、Bangumi 官方通算索引 (例如第二季从第 13 集开始，或独立条目)、
/// 以及 .5 总集篇 / SP / OVA 特别篇之间的映射冲突与弹幕/评论错位问题。
class MediaSelector {
  MediaSelector._();

  /// 智能对齐解析算法核心入口
  static MediaEpisodeResolution resolve({
    required int rawIndex, // 线路数据列表中的 1-based 索引
    String identifier = '', // 抓取源给出的集数标识 (e.g. "第13话", "S02E01", "05.5", "总集篇", "SP01")
    String roadName = '', // 线路/播放列表名称 (e.g. "第二季", "Season 2", "正片", "OVA")
    int? bangumiTotalEpisodes, // Bangumi 官方当前条目正片总集数 (若已知)
    int? explicitSeasonNumber, // 显式指定的季度
    int? explicitSeasonOffset, // 显式指定的通算偏移
  }) {
    final cleanId = identifier.trim();
    final cleanRoad = roadName.trim();

    // 1. 判断是否为特别篇 / .5 总集篇
    final isSpecial = isSpecialEpisode(cleanId) || isSpecialEpisode(cleanRoad);

    // 2. 解析季度 (Season)
    int season = explicitSeasonNumber ??
        extractSeasonNumber(cleanRoad) ??
        extractSeasonNumber(cleanId) ??
        1;

    // 3. 解析集数 (Episode) 与浮点小数 (例如 5.5)
    final (extractedNumber, extractedFloat) = _extractNumbers(cleanId, rawIndex);

    // 4. 计算多季偏移量 (Season Offset)
    int seasonOffset = explicitSeasonOffset ?? 0;
    if (seasonOffset == 0 && season > 1 && bangumiTotalEpisodes != null && bangumiTotalEpisodes > 0) {
      // 若 Bangumi 条目为多季通算条目且当前季度 > 1
      seasonOffset = (season - 1) * bangumiTotalEpisodes;
    }

    // 5. 计算 Bangumi 官方对齐集数与 DanDanPlay 弹幕对齐集数
    int bgmEp;
    int ddmkEp;

    if (isSpecial) {
      // 特别篇通常对应 Bangumi SP 1..N 或独立编号
      bgmEp = extractedNumber > 0 ? extractedNumber : rawIndex;
      ddmkEp = bgmEp;
    } else {
      // 若原始标识本身已经是通算大集数 (例如 "第13集" 或 "13")，直接使用
      if (extractedNumber > 0) {
        if (seasonOffset > 0 && extractedNumber > seasonOffset) {
          // 已经自带通算大集数 (例如第二季直接标注第 13 集)
          bgmEp = extractedNumber;
          ddmkEp = extractedNumber - seasonOffset;
        } else if (extractedNumber > 12 && season > 1 && seasonOffset == 0) {
          // 未显式给定 offset 但集数大于 12 且属于第 2+ 季，本身即为通算大集数
          bgmEp = extractedNumber;
          ddmkEp = extractedNumber;
        } else {
          // 相对集数 (例如第二季第 1 集)
          bgmEp = extractedNumber + seasonOffset;
          ddmkEp = extractedNumber; // DanDanPlay 通常按相对集数匹配
        }
      } else {
        // 回退至原始行索引 + 季度偏移
        bgmEp = rawIndex + seasonOffset;
        ddmkEp = rawIndex;
      }
    }

    // 6. 生成规范化展示标签
    final displayLabel = _formatDisplayLabel(
      extractedNumber: extractedNumber,
      extractedFloat: extractedFloat,
      isSpecial: isSpecial,
      season: season,
      rawIndex: rawIndex,
      originalIdentifier: cleanId,
    );

    return MediaEpisodeResolution(
      bangumiEpisode: bgmEp > 0 ? bgmEp : rawIndex,
      danmakuEpisode: ddmkEp > 0 ? ddmkEp : rawIndex,
      episodeFloat: extractedFloat ?? (bgmEp.toDouble()),
      isSpecial: isSpecial,
      season: season,
      seasonOffset: seasonOffset,
      displayLabel: displayLabel,
    );
  }

  /// 提取集数整数与浮点数
  static (int, double?) _extractNumbers(String input, int defaultIndex) {
    if (input.isEmpty) return (defaultIndex, null);

    // 1. 匹配小数集数 (如 05.5, 5.5, 第05.5话)
    final decimalMatch = RegExp(r'(\d+)\.(\d+)').firstMatch(input);
    if (decimalMatch != null) {
      final floatVal = double.tryParse('${decimalMatch.group(1)}.${decimalMatch.group(2)}');
      final intPart = int.tryParse(decimalMatch.group(1)!) ?? defaultIndex;
      return (intPart, floatVal);
    }

    // 2. 匹配 S01E08 / E08 / EP08
    final sxxMatch = RegExp(r'(?:S\d+)?(?:E|EP)(\d+)', caseSensitive: false).firstMatch(input);
    if (sxxMatch != null && sxxMatch.group(1) != null) {
      final ep = int.tryParse(sxxMatch.group(1)!) ?? defaultIndex;
      return (ep, null);
    }

    // 3. 匹配标准 "第 XX 话/集" 或单纯前后带空格/括号的数字
    final cnMatch = RegExp(r'第?(\d+)[话集期]?').firstMatch(input);
    if (cnMatch != null && cnMatch.group(1) != null) {
      final ep = int.tryParse(cnMatch.group(1)!) ?? defaultIndex;
      return (ep, null);
    }

    // 4. 匹配纯数字 (如 "08", " 12 ")
    final pureMatch = RegExp(r'\b(\d{1,4})\b').firstMatch(input);
    if (pureMatch != null && pureMatch.group(1) != null) {
      final ep = int.tryParse(pureMatch.group(1)!) ?? defaultIndex;
      return (ep, null);
    }

    return (defaultIndex, null);
  }

  /// 提取季度数字 (例如 "第二季" -> 2, "Season 3" -> 3, "S02" -> 2)
  static int? extractSeasonNumber(String input) {
    if (input.isEmpty) return null;

    // S02 / S2
    final sMatch = RegExp(r'\bS(\d{1,2})\b', caseSensitive: false).firstMatch(input);
    if (sMatch != null) return int.tryParse(sMatch.group(1)!);

    // Season 2
    final seasonMatch = RegExp(r'Season\s*(\d+)', caseSensitive: false).firstMatch(input);
    if (seasonMatch != null) return int.tryParse(seasonMatch.group(1)!);

    // 中文第X季
    final cnNumMap = {
      '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    };
    final cnMatch = RegExp(r'第([一二两三四五六七八九十\d]+)季').firstMatch(input);
    if (cnMatch != null && cnMatch.group(1) != null) {
      final rawNum = cnMatch.group(1)!;
      final parsedInt = int.tryParse(rawNum);
      if (parsedInt != null) return parsedInt;
      if (cnNumMap.containsKey(rawNum)) return cnNumMap[rawNum];
    }

    return null;
  }

  /// 判断是否为特别篇 / 总集篇 / OVA / SP
  static bool isSpecialEpisode(String input) {
    if (input.isEmpty) return false;
    final lower = input.toLowerCase();

    return lower.contains('.5') ||
        lower.contains('总集篇') ||
        lower.contains('总集') ||
        lower.contains('recap') ||
        lower.contains('sp') ||
        lower.contains('ova') ||
        lower.contains('oad') ||
        lower.contains('特别篇') ||
        lower.contains('特番') ||
        lower.contains('番外') ||
        lower.contains('剧场版') ||
        lower.contains('preview');
  }

  /// 智能从标题提取集数整数
  static int extractEpisodeNumber(String input, {int fallback = 0}) {
    final (num, _) = _extractNumbers(input, fallback);
    return num;
  }

  /// 格式化用户界面展示标签
  static String _formatDisplayLabel({
    required int extractedNumber,
    required double? extractedFloat,
    required bool isSpecial,
    required int season,
    required int rawIndex,
    required String originalIdentifier,
  }) {
    if (extractedFloat != null) {
      return '第 $extractedFloat 话 [总集篇]';
    }
    if (isSpecial) {
      if (originalIdentifier.isNotEmpty) return originalIdentifier;
      return 'SP $extractedNumber';
    }
    final epNum = extractedNumber > 0 ? extractedNumber : rawIndex;
    final padNum = epNum < 10 ? '0$epNum' : '$epNum';
    if (season > 1) {
      return 'S$season E$padNum';
    }
    return '第 $padNum 集';
  }
}
