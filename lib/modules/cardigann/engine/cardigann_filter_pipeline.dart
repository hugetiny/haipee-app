import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';

/// Execution pipeline for Cardigann filters applied to extracted HTML field strings.
class CardigannFilterPipeline {
  /// Applies a list of filters sequentially to an initial input string.
  static String apply(
    String input,
    List<CardigannFilter> filters, {
    Map<String, String>? contextVariables,
  }) {
    var result = input;
    for (final filter in filters) {
      result = applyFilter(result, filter, contextVariables: contextVariables);
    }
    return result;
  }

  static dynamic _interpolateContextVariables(
    dynamic args,
    Map<String, String> contextVariables,
  ) {
    if (args is String) {
      var res = args;
      contextVariables.forEach((key, val) {
        res = res.replaceAll('{{ .Result.$key }}', val);
        res = res.replaceAll('{{.Result.$key}}', val);
        res = res.replaceAll('{{ .$key }}', val);
      });

      // Evaluate basic Result conditionals: {{ if eq .Result.<key> "<val>" }}...{{ else }}...{{ end }}
      final ifRegex = RegExp(
        r'\{\{\s*if\s+eq\s+\.Result\.([a-zA-Z0-9_-]+)\s+"([^"]*)"\s*\}\}([\s\S]*?)(?:\{\{\s*else\s*\}\}([\s\S]*?))?\{\{\s*end\s*\}\}',
      );
      res = res.replaceAllMapped(ifRegex, (match) {
        final key = match.group(1)!;
        final targetVal = match.group(2) ?? '';
        final thenBlock = match.group(3) ?? '';
        final elseBlock = match.group(4) ?? '';
        final actualVal = contextVariables[key] ?? '';
        return actualVal == targetVal ? thenBlock : elseBlock;
      });

      // Strip any unhandled residual {{ ... }} markers
      res = res.replaceAll(RegExp(r'\{\{[^\}]*\}\}'), '');
      return res;
    } else if (args is List) {
      return args
          .map((item) => _interpolateContextVariables(item, contextVariables))
          .toList();
    } else if (args is Map) {
      final map = <dynamic, dynamic>{};
      args.forEach((k, v) {
        map[k] = _interpolateContextVariables(v, contextVariables);
      });
      return map;
    }
    return args;
  }

  static String applyFilter(
    String input,
    CardigannFilter filter, {
    Map<String, String>? contextVariables,
  }) {
    final name = filter.name.trim().toLowerCase();
    var args = filter.args;
    if (contextVariables != null && args != null) {
      args = _interpolateContextVariables(args, contextVariables);
    }

    switch (name) {
      case 'trim':
        return input.trim();

      case 'trimstrings':
        if (args == null) return input.trim();
        final trimStr = args.toString();
        var s = input;
        while (s.startsWith(trimStr)) {
          s = s.substring(trimStr.length);
        }
        while (s.endsWith(trimStr)) {
          s = s.substring(0, s.length - trimStr.length);
        }
        return s;

      case 'replace':
        if (args case [final from?, final to?, ...]) {
          return input.replaceAll(from.toString(), to.toString());
        } else if (args is Map) {
          var res = input;
          args.forEach((k, v) {
            res = res.replaceAll(k.toString(), v?.toString() ?? '');
          });
          return res;
        }
        return input;

      case 're_replace':
        if (args case [final from?, final to?, ...]) {
          try {
            final pattern = RegExp(from.toString());
            final replacement = to.toString();
            return input.replaceAll(pattern, replacement);
          } catch (_) {
            return input;
          }
        }
        return input;

      case 'regexp':
        if (args == null) return input;
        try {
          String patternStr = '';
          int groupIdx = 1;
          if (args is List && args.isNotEmpty) {
            patternStr = args[0]?.toString() ?? '';
            if (args.length > 1 && args[1] is int) {
              groupIdx = args[1] as int;
            } else if (args.length > 1) {
              groupIdx = int.tryParse(args[1].toString()) ?? 1;
            }
          } else {
            patternStr = args.toString();
          }

          final regex = RegExp(patternStr);
          final match = regex.firstMatch(input);
          if (match == null) return '';
          if (match.groupCount >= groupIdx && match.group(groupIdx) != null) {
            return match.group(groupIdx)!;
          }
          return match.group(0) ?? '';
        } catch (_) {
          return input;
        }

      case 'append':
        return '$input${args?.toString() ?? ''}';

      case 'prepend':
        return '${args?.toString() ?? ''}$input';

      case 'split':
        if (args is List && args.isNotEmpty) {
          final delim = args[0]?.toString() ?? '';
          final idx = (args.length > 1 ? int.tryParse(args[1].toString()) : null) ?? 0;
          final parts = input.split(delim);
          if (idx >= 0 && idx < parts.length) {
            return parts[idx];
          } else if (idx < 0 && (parts.length + idx) >= 0) {
            return parts[parts.length + idx];
          }
        }
        return input;

      case 'querystring':
        final paramName = args?.toString() ?? '';
        if (paramName.isEmpty) return input;
        try {
          // If input is a relative or full url
          final uri = Uri.tryParse(input.contains('?') ? input : '?$input');
          if (uri != null && uri.queryParameters.containsKey(paramName)) {
            return uri.queryParameters[paramName] ?? '';
          }
        } catch (_) {}
        return input;

      case 'urldecode':
        try {
          return Uri.decodeComponent(input);
        } catch (_) {
          return input;
        }

      case 'urlencode':
        try {
          return Uri.encodeComponent(input);
        } catch (_) {
          return input;
        }

      case 'tolower':
        return input.toLowerCase();

      case 'toupper':
        return input.toUpperCase();

      case 'dateparse':
        return parseDateString(input, formatPattern: args?.toString());

      case 'timeago':
        return parseRelativeTime(input);

      case 'fuzzytime':
        final parsed = DateTime.tryParse(input);
        if (parsed != null) return parsed.toIso8601String();
        return parseRelativeTime(input);

      case 'sub':
        // Math subtract or regex sub
        if (args != null) {
          final numVal = num.tryParse(input);
          final subVal = num.tryParse(args.toString());
          if (numVal != null && subVal != null) {
            return (numVal - subVal).toString();
          }
        }
        return input;

      case 'parse_bytes':
      case 'validsize':
        final bytes = parseHumanSizeToBytes(input);
        return bytes.toString();

      default:
        return input;
    }
  }

  /// Parses human-readable size (e.g., "1.4 GB", "500 MB", "2.5 GiB") to bytes integer.
  static int parseHumanSizeToBytes(String sizeStr) {
    final clean = sizeStr.replaceAll(',', '').trim().toUpperCase();
    if (clean.isEmpty) return 0;

    // Check if raw integer
    final rawInt = int.tryParse(clean);
    if (rawInt != null) return rawInt;

    final regex = RegExp(r'^([\d\.]+)\s*([KMGTP]?I?B?)$');
    final match = regex.firstMatch(clean);
    if (match == null) return 0;

    final value = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = match.group(2) ?? '';

    final multiplier = switch (unit.isNotEmpty ? unit[0] : '') {
      'K' => 1024.0,
      'M' => 1024.0 * 1024.0,
      'G' => 1024.0 * 1024.0 * 1024.0,
      'T' => 1024.0 * 1024.0 * 1024.0 * 1024.0,
      'P' => 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0,
      _ => 1.0,
    };

    return (value * multiplier).round();
  }

  /// Formats bytes integer to human-readable size string (e.g. "1.4 GB").
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(dBytes >= 100 ? 0 : (dBytes >= 10 ? 1 : 2))} ${suffixes[i]}';
  }

  /// Parses date string with optional format pattern, returning ISO 8601 string.
  static String parseDateString(String input, {String? formatPattern}) {
    final clean = input.trim();
    if (clean.isEmpty) return DateTime.now().toIso8601String();

    // Check if timestamp in seconds or milliseconds
    final numeric = int.tryParse(clean);
    if (numeric != null) {
      if (clean.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(numeric * 1000, isUtc: true).toIso8601String();
      } else if (clean.length == 13) {
        return DateTime.fromMillisecondsSinceEpoch(numeric, isUtc: true).toIso8601String();
      }
    }

    // Try standard ISO-8601 / RFC 3339
    final direct = DateTime.tryParse(clean);
    if (direct != null) {
      return direct.toIso8601String();
    }

    // Common patterns:
    // "yyyy-MM-dd HH:mm:ss" or "yyyy-MM-dd HH:mm"
    final ymdHmsRegex = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?');
    final m1 = ymdHmsRegex.firstMatch(clean);
    if (m1 != null) {
      final y = int.parse(m1.group(1)!);
      final m = int.parse(m1.group(2)!);
      final d = int.parse(m1.group(3)!);
      final hh = m1.group(4) != null ? int.parse(m1.group(4)!) : 0;
      final mm = m1.group(5) != null ? int.parse(m1.group(5)!) : 0;
      final ss = m1.group(6) != null ? int.parse(m1.group(6)!) : 0;
      return DateTime(y, m, d, hh, mm, ss).toIso8601String();
    }

    // "dd-MM-yyyy HH:mm" or "dd/MM/yyyy"
    final dmyRegex = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?');
    final m2 = dmyRegex.firstMatch(clean);
    if (m2 != null) {
      final d = int.parse(m2.group(1)!);
      final m = int.parse(m2.group(2)!);
      final y = int.parse(m2.group(3)!);
      final hh = m2.group(4) != null ? int.parse(m2.group(4)!) : 0;
      final mm = m2.group(5) != null ? int.parse(m2.group(5)!) : 0;
      final ss = m2.group(6) != null ? int.parse(m2.group(6)!) : 0;
      return DateTime(y, m, d, hh, mm, ss).toIso8601String();
    }

    // Month name patterns e.g. "Jan 02, 2024" or "02 Jan 2024"
    final monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final monthNameRegex = RegExp(r'([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})');
    final m3 = monthNameRegex.firstMatch(clean);
    if (m3 != null) {
      final monthStr = m3.group(1)!.substring(0, 3).toLowerCase();
      final m = monthMap[monthStr] ?? 1;
      final d = int.parse(m3.group(2)!);
      final y = int.parse(m3.group(3)!);
      return DateTime(y, m, d).toIso8601String();
    }

    // Fallback: try relative time or current time
    final rel = parseRelativeTime(clean);
    if (rel != clean) {
      return rel;
    }

    return DateTime.now().toIso8601String();
  }

  /// Parses relative time string (e.g. "2 hours ago", "3天前") to ISO 8601 string.
  static String parseRelativeTime(String input) {
    final lower = input.trim().toLowerCase();
    final now = DateTime.now();

    if (lower.contains('刚刚') || lower.contains('just now') || lower.contains('moments ago')) {
      return now.toIso8601String();
    }

    if (lower.startsWith('today') || lower.startsWith('今天')) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(lower);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!);
        final m = int.parse(timeMatch.group(2)!);
        return DateTime(now.year, now.month, now.day, h, m).toIso8601String();
      }
      return now.toIso8601String();
    }

    if (lower.startsWith('yesterday') || lower.startsWith('昨天')) {
      final yesterday = now.subtract(const Duration(days: 1));
      final timeMatch = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(lower);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!);
        final m = int.parse(timeMatch.group(2)!);
        return DateTime(yesterday.year, yesterday.month, yesterday.day, h, m).toIso8601String();
      }
      return yesterday.toIso8601String();
    }

    final match = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z\u4e00-\u9fa5]+)').firstMatch(lower);
    if (match != null) {
      final count = double.tryParse(match.group(1) ?? '') ?? 0.0;
      final unit = match.group(2) ?? '';

      if (unit.contains('sec') || unit.contains('秒')) {
        return now.subtract(Duration(seconds: count.round())).toIso8601String();
      } else if (unit.contains('min') || unit.contains('分')) {
        return now.subtract(Duration(minutes: count.round())).toIso8601String();
      } else if (unit.contains('hour') || unit.contains('hr') || unit.contains('时') || unit.contains('小時') || unit.contains('小时')) {
        return now.subtract(Duration(hours: count.round())).toIso8601String();
      } else if (unit.contains('day') || unit.contains('d') || unit.contains('天') || unit.contains('日')) {
        return now.subtract(Duration(days: count.round())).toIso8601String();
      } else if (unit.contains('week') || unit.contains('wk') || unit.contains('周') || unit.contains('星期')) {
        return now.subtract(Duration(days: (count * 7).round())).toIso8601String();
      } else if (unit.contains('month') || unit.contains('mo') || unit.contains('月')) {
        return now.subtract(Duration(days: (count * 30).round())).toIso8601String();
      } else if (unit.contains('year') || unit.contains('yr') || unit.contains('年')) {
        return now.subtract(Duration(days: (count * 365).round())).toIso8601String();
      }
    }

    return input;
  }
}
