import 'package:kazumi/modules/danmaku/danmaku_module.dart';

class LocalVideoPlayArgs {
  final String filePath;
  final String title;
  final String? bangumiId;
  final int? episode;
  final bool isAudio;
  final int? streamId;
  final int? torrentId;
  final String? audioUrl;
  final Map<String, String>? httpHeaders;
  final int? biliCid;
  final List<DanmakuEntry>? danmakus;

  const LocalVideoPlayArgs({
    required this.filePath,
    required this.title,
    this.bangumiId,
    this.episode,
    this.isAudio = false,
    this.streamId,
    this.torrentId,
    this.audioUrl,
    this.httpHeaders,
    this.biliCid,
    this.danmakus,
  });

  bool get effectiveIsAudio {
    if (isAudio) return true;
    const audioExts = [
      '.mp3',
      '.flac',
      '.wav',
      '.ape',
      '.dsd',
      '.alac',
      '.ogg',
      '.m4a',
      '.aac',
      '.opus',
      '.wma',
      '.dsf',
      '.dff',
    ];

    bool matches(String s) {
      if (s.isEmpty) return false;
      final lower = s.toLowerCase();
      String clean = lower;
      final q = clean.indexOf('?');
      if (q != -1) clean = clean.substring(0, q);
      final h = clean.indexOf('#');
      if (h != -1) clean = clean.substring(0, h);
      if (audioExts.any((ext) => clean.endsWith(ext))) return true;

      for (final ext in audioExts) {
        if (lower.contains(ext)) {
          final idx = lower.indexOf(ext);
          final nextIdx = idx + ext.length;
          if (nextIdx >= lower.length ||
              lower[nextIdx] == '&' ||
              lower[nextIdx] == '?' ||
              lower[nextIdx] == '#' ||
              lower[nextIdx] == ')' ||
              lower[nextIdx] == ']' ||
              lower[nextIdx] == ' ') {
            return true;
          }
        }
      }
      return false;
    }

    const audioKeywordRegex = [
      r'\[\s*(flac|wav|ape|dsd|dsf|dff|alac|lossless|ost|hi-res|320kbps)\s*\]',
      r'\(\s*(flac|wav|ape|dsd|dsf|dff|alac|lossless|ost|hi-res|320kbps)\s*\)',
      r'\b(flac|lossless|soundtrack|hi-res|audiobook)\b',
      r'无损',
      r'原声带',
      r'游戏原声',
    ];

    bool matchesKeywords(String s) {
      if (s.isEmpty) return false;
      final lower = s.toLowerCase();
      for (final pat in audioKeywordRegex) {
        if (RegExp(pat, caseSensitive: false).hasMatch(lower)) return true;
      }
      return false;
    }

    return matches(filePath) || matches(title) || matchesKeywords(title);
  }
}
