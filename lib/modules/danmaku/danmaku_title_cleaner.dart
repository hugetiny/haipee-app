/// 专为弹幕匹配设计的番剧标题智能清洗与标准化工具
class DanmakuTitleCleaner {
  static final RegExp _bracketPattern = RegExp(r'[\[【\(（](.*?)[\]】\)）]');

  static final Set<String> _ignoredTechnicalWords = {
    // 分辨率
    '1080p', '720p', '2160p', '4k', '480p', '1080i',
    // 媒介与来源
    'bdrip', 'web-dl', 'webdl', 'webrip', 'bluray', 'bd', 'dvdrip', 'dvd', 'hdtv',
    // 编码与音频
    'hevc', 'x265', 'h265', 'h.265', 'x264', 'h264', 'h.264', 'avc', 'av1',
    'flac', 'aac', 'mp3', 'dts', 'ac3', 'eac3', 'truehd', 'opus', '10bit', '8bit',
    // 格式与封装
    'mkv', 'mp4', 'avi', 'rmvb', 'ts',
    // 语言与字幕标签
    'chs', 'cht', 'gb', 'big5', 'jap', 'jpn', 'eng', '简日', '繁日', '简中', '繁中',
    '双语', '外挂', '内嵌', '双语字幕', '简日双语', '繁日双语', '字幕', 'sub', 'multisub',
    // 其它噪音
    'cr', 'baha', 'tv', 'ova', 'sp', 'raw', 'raws', 'rerip', 'v2', 'fin', 'batch',
  };

  /// 从复杂的 BT 种子文件名中提取最纯净的番剧搜索关键词
  static String extractCleanTitle(String rawTitle) {
    if (rawTitle.trim().isEmpty) return '';

    final cleaned = rawTitle.trim();

    // 0. 优先匹配欧美剧集/分集标准规范（如 Scene/P2P 点号分隔: Sparks.of.Tomorrow.S01E13...）
    final sceneMatch = RegExp(
            r'^(.*?)[._\-\s]+S\d{1,2}(?:E\d{1,4})?',
            caseSensitive: false)
        .firstMatch(cleaned);
    if (sceneMatch != null) {
      var showTitle = sceneMatch.group(1) ?? '';
      showTitle = showTitle.replaceAll(_bracketPattern, ' ');
      showTitle = showTitle.replaceAll(RegExp(r'\b(19\d{2}|20\d{2})\b'), ' ');
      showTitle = showTitle.replaceAll('.', ' ');
      showTitle = _cleanBareTechnicalWords(showTitle);
      showTitle = showTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (showTitle.length >= 2) {
        return _refineMultiTitle(showTitle);
      }
    }

    // 1. 先检查去除所有括号后的正文部分
    // 例如: "[Lilith-Raws] 迷宫饭 / Dungeon Meshi - 01 [Baha][1080p].mp4" -> 正文: "迷宫饭 / Dungeon Meshi - 01"
    String unbracketed = cleaned.replaceAll(_bracketPattern, ' ');
    unbracketed = unbracketed.replaceAll(
        RegExp(r'\.(mkv|mp4|avi|flv|ts|rmvb|wmv)$', caseSensitive: false), '');
    unbracketed = _cleanBareTechnicalWords(unbracketed);
    unbracketed = _stripEpisodeInfo(unbracketed);
    unbracketed = unbracketed.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 如果正文部分包含 CJK 字符且有效长度 >= 2，说明正文即是番剧标题
    if (_containsCJK(unbracketed) && unbracketed.length >= 2) {
      return _refineMultiTitle(unbracketed);
    }

    // 2. 如果正文为空或无 CJK，检查方括号中的内容（很多种子把中文标题放在方括号内）
    // 例如: "[DBD-Raws][葬送的芙莉莲][01-28TV全集][1080P][FLAC]"
    final matches = _bracketPattern.allMatches(cleaned).toList();
    if (matches.isNotEmpty) {
      final candidates = <String>[];
      for (int i = 0; i < matches.length; i++) {
        final content = matches[i].group(1)?.trim() ?? '';
        if (content.isEmpty) continue;

        // 如果是首个方括号且是明显字幕组特征，且后续还有括号，则跳过首个字幕组
        if (i == 0 && _isFansubGroup(content) && matches.length > 1) {
          continue;
        }

        // 检查是否全由技术词/噪音词组成
        if (_isTechnicalOrNoise(content)) continue;

        candidates.add(content);
      }

      if (candidates.isNotEmpty) {
        // 优先选择包含中文或日文的候选词
        final cjkCandidates = candidates.where((c) => _containsCJK(c)).toList();
        if (cjkCandidates.isNotEmpty) {
          for (final cjk in cjkCandidates) {
            final stripped = _stripEpisodeInfo(cjk);
            if (stripped.length >= 2) return _refineMultiTitle(stripped);
          }
          return _refineMultiTitle(_stripEpisodeInfo(cjkCandidates.first));
        }

        // 若无 CJK，但正文有效非空（如英文原名 "Sousou no Frieren"）
        if (unbracketed.length >= 2 && !_isBareNoise(unbracketed)) {
          return _refineMultiTitle(unbracketed);
        }

        // 否则选择最长有效非技术候选词
        candidates.sort((a, b) => b.length.compareTo(a.length));
        return _refineMultiTitle(_stripEpisodeInfo(candidates.first));
      }
    }

    // 3. 兜底回退
    if (unbracketed.length >= 2) {
      return _refineMultiTitle(unbracketed);
    }

    return cleaned;
  }

  /// 从标题或文件名中智能提取集数（Episode Number）
  static int? extractEpisodeNumber(String rawTitle) {
    final title = rawTitle.trim();

    // 模式 0: "S01E13" 或 "S1E5" (欧美剧集规范)
    final sMatch =
        RegExp(r'\bS\d{1,2}E(\d{1,4})\b', caseSensitive: false).firstMatch(title);
    if (sMatch != null) {
      return int.tryParse(sMatch.group(1)!);
    }

    // 模式 1: "第 02 话" / "第02集"
    final chMatch = RegExp(r'第\s*(\d{1,4})\s*[话話集]').firstMatch(title);
    if (chMatch != null) {
      return int.tryParse(chMatch.group(1)!);
    }

    // 模式 2: " - 02 " / " - 02.mkv" / " - 02 [" / " - 02v2"
    final dashMatch =
        RegExp(r'[\s_\-–—](\d{1,4})(?:v\d)?(?=[\s_\.\[\(\]–—]|$)').firstMatch(title);
    if (dashMatch != null) {
      final numVal = int.tryParse(dashMatch.group(1)!);
      if (numVal != null &&
          numVal < 2000 &&
          numVal != 1080 &&
          numVal != 720 &&
          numVal != 480) {
        return numVal;
      }
    }

    // 模式 3: "EP02" / "E02"
    final epMatch =
        RegExp(r'\bEP?(\d{1,4})\b', caseSensitive: false).firstMatch(title);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!);
    }

    // 模式 4: "[02]"
    final bracketMatch = RegExp(r'\[(\d{1,4})\]').firstMatch(title);
    if (bracketMatch != null) {
      final numVal = int.tryParse(bracketMatch.group(1)!);
      if (numVal != null && numVal < 1000) {
        return numVal;
      }
    }

    return null;
  }

  static bool _containsCJK(String str) {
    return RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff]').hasMatch(str);
  }

  static bool _isFansubGroup(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.contains('字幕') ||
        lower.contains('汉化') ||
        lower.contains('raws') ||
        lower.contains('raw') ||
        lower.contains('rip') ||
        lower.contains('sub') ||
        lower.contains('subs') ||
        lower.contains('club') ||
        lower.contains('team') ||
        lower.contains('house') ||
        lower.contains('fansub')) {
      return true;
    }
    return false;
  }

  static bool _isBareNoise(String text) {
    final lower = text.toLowerCase().trim();
    return _ignoredTechnicalWords.contains(lower) ||
        RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(lower);
  }

  static String _cleanBareTechnicalWords(String text) {
    var res = text;
    // 去除 CRC32 / 8位十六进制
    res = res.replaceAll(RegExp(r'\b[0-9a-fA-F]{8}\b'), ' ');
    // 去除新番前缀
    res = res.replaceAll(RegExp(r'★?\s*\d{1,2}月新番\s*★?'), ' ');
    res = res.replaceAll(RegExp(r'[★☆◆◇▲▼]'), ' ');
    // 去除技术词
    for (final word in _ignoredTechnicalWords) {
      res = res.replaceAll(
          RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false), ' ');
    }
    // 中文技术噪音
    const cnWords = [
      '双语字幕',
      '简日双语',
      '繁日双语',
      '简中',
      '繁中',
      '简日',
      '繁日',
      '外挂',
      '内嵌',
      '双语',
      '全集',
      '新番'
    ];
    for (final word in cnWords) {
      res = res.replaceAll(word, ' ');
    }
    return res;
  }

  static bool _isTechnicalOrNoise(String block) {
    final lower = block.toLowerCase().trim();

    // 纯数字或版本号或范围
    if (RegExp(r'^\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^\d{1,3}-\d{1,3}$').hasMatch(lower)) return true; // 如 01-28
    if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(lower)) return true; // CRC32

    // 仅由技术词组合而成（如 "1080P BDRip HEVC"）
    final tokens = lower.split(RegExp(r'[\s\.\-_]+'));
    if (tokens.isNotEmpty &&
        tokens.every((t) =>
            _ignoredTechnicalWords.contains(t) ||
            RegExp(r'^\d+$').hasMatch(t))) {
      return true;
    }

    // 特别包含全集/特典/季度
    if (lower.contains('tv全集') ||
        lower.contains('特典映像') ||
        lower.contains('特典')) {
      return true;
    }

    return false;
  }

  static String _refineMultiTitle(String title) {
    var cleaned = title.trim();
    // 如果包含 '/' 或 '|' 或 '｜' 分割的多语种标题
    final parts = cleaned.split(RegExp(r'\s*[/|｜]\s*'));
    if (parts.length > 1) {
      final cjkPart = parts.firstWhere(
          (p) => _containsCJK(p) && p.trim().length >= 2,
          orElse: () => '');
      if (cjkPart.isNotEmpty) {
        cleaned = cjkPart.trim();
      } else {
        cleaned = parts.first.trim();
      }
    }
    cleaned = cleaned.replaceAll(RegExp(r'^[_\-\.\s]+|[_\-\.\s]+$'), '');
    return cleaned.trim();
  }

  static String _stripEpisodeInfo(String title) {
    var res = title;
    // 去除 "第xx话"
    res = res.replaceAll(RegExp(r'第\s*\d{1,4}\s*[话話集]'), ' ');
    // 去除 " - 01" / " S01E02"
    res = res.replaceAll(
        RegExp(r'[\s_\-–—]\d{1,4}(?:v\d)?(?=[\s_\.\-\]–—]|$)'), ' ');
    res = res.replaceAll(
        RegExp(r'\bS\d{1,2}(?:E\d{1,4})?\b', caseSensitive: false), ' ');
    res = res.replaceAll(RegExp(r'\s+'), ' ').trim();
    return res;
  }
}
