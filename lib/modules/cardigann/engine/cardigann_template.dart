/// Template engine for Cardigann URL paths and query inputs.
class CardigannTemplate {
  /// Renders a template string by replacing Go template variables and evaluating basic conditionals.
  static String render(
    String template, {
    required String keyword,
    List<dynamic> categories = const [],
    Map<String, String> config = const {},
    Map<String, String> query = const {},
    bool urlEncodeKeywords = false,
  }) {
    if (template.isEmpty) return '';

    var result = template;

    // 1. Evaluate range: {{ range .Categories }}{{ . }}{{ end }}
    final rangeRegex = RegExp(
      r'\{\{\s*range\s+\.Categories\s*\}\}([\s\S]*?)\{\{\s*end\s*\}\}',
    );
    result = result.replaceAllMapped(rangeRegex, (match) {
      final itemTemplate = match.group(1) ?? '';
      if (categories.isEmpty) return '';
      final sb = StringBuffer();
      for (final cat in categories) {
        sb.write(itemTemplate.replaceAll('{{ . }}', cat.toString()));
      }
      return sb.toString();
    });

    // 2. Evaluate conditionals: {{ if <cond> }}<then>{{ else }}<else>{{ end }} or {{ if <cond> }}<then>{{ end }}
    final innermostIfRegex = RegExp(
      r'\{\{\s*if\s+([^\}]+?)\s*\}\}((?:(?!\{\{\s*(?:if|end)\s*\}\})[\s\S])*?)(?:\{\{\s*else\s*\}\}((?:(?!\{\{\s*(?:if|end)\s*\}\})[\s\S])*?))?\{\{\s*end\s*\}\}',
    );

    int maxLoops = 20;
    while (innermostIfRegex.hasMatch(result) && maxLoops-- > 0) {
      result = result.replaceAllMapped(innermostIfRegex, (match) {
        final conditionVar = match.group(1)!.trim();
        final thenBlock = match.group(2) ?? '';
        final elseBlock = match.group(3) ?? '';

        final isTrue = _evalCondition(
          conditionVar,
          keyword: keyword,
          categories: categories,
          config: config,
          query: query,
        );
        return isTrue ? thenBlock : elseBlock;
      });
    }

    // 3. Variable replacements
    final kwValue = urlEncodeKeywords ? Uri.encodeComponent(keyword) : keyword;
    final catValue = categories.isNotEmpty ? categories.join(',') : '';

    result = result.replaceAll(RegExp(r'\{\{\s*\.Keywords\s*\}\}'), kwValue);
    result = result.replaceAll(RegExp(r'\{\{\s*\.Query\.Keywords\s*\}\}'), kwValue);
    result = result.replaceAll(RegExp(r'\{\{\s*\.Categories\s*\}\}'), catValue);

    // Query variables: {{ .Query.<field> }}
    query.forEach((k, v) {
      result = result.replaceAll(
          RegExp(r'\{\{\s*\.Query\.' + RegExp.escape(k) + r'\s*\}\}'), v);
    });

    // Date variables
    final now = DateTime.now();
    result = result.replaceAll(
        RegExp(r'\{\{\s*\.Today\.Year\s*\}\}'), now.year.toString());
    result = result.replaceAll(RegExp(r'\{\{\s*\.Today\.Month\s*\}\}'),
        now.month.toString().padLeft(2, '0'));
    result = result.replaceAll(RegExp(r'\{\{\s*\.Today\.Day\s*\}\}'),
        now.day.toString().padLeft(2, '0'));

    // Config variables: {{ .Config.settingName }}
    final configVarRegex = RegExp(r'\{\{\s*\.Config\.([a-zA-Z0-9_-]+)\s*\}\}');
    result = result.replaceAllMapped(configVarRegex, (match) {
      final key = match.group(1)!;
      return config[key] ?? '';
    });

    // Clean any remaining unhandled template markers
    result = result.replaceAll(RegExp(r'\{\{[^\}]*\}\}'), '').trim();

    return result;
  }

  static bool _evalCondition(
    String condition, {
    required String keyword,
    required List<dynamic> categories,
    required Map<String, String> config,
    Map<String, String> query = const {},
  }) {
    final clean = condition.trim();

    // Check negation e.g. "not .Keywords"
    if (clean.startsWith('not ')) {
      final sub = clean.substring(4).trim();
      return !_evalCondition(
        sub,
        keyword: keyword,
        categories: categories,
        config: config,
        query: query,
      );
    }

    // Comparison: eq <arg1> <arg2> or ne <arg1> <arg2>
    final cmpMatch =
        RegExp(r'^(eq|ne)\s+([^\s]+)\s+([^\s]+)$').firstMatch(clean);
    if (cmpMatch != null) {
      final op = cmpMatch.group(1)!;
      final a =
          _resolveValue(cmpMatch.group(2)!, keyword, categories, config, query);
      final b =
          _resolveValue(cmpMatch.group(3)!, keyword, categories, config, query);
      final isEqual = a == b;
      return op == 'eq' ? isEqual : !isEqual;
    }

    if (clean == '.Keywords' || clean == '.Query.Keywords') {
      return keyword.trim().isNotEmpty;
    }

    if (clean == '.Categories') {
      return categories.isNotEmpty;
    }

    if (clean.startsWith('.Config.')) {
      final key = clean.substring(8);
      final val = config[key];
      return val != null && val.trim().isNotEmpty;
    }

    if (clean.startsWith('.Query.')) {
      final key = clean.substring(7);
      if (key == 'Keywords') return keyword.trim().isNotEmpty;
      final val = query[key];
      return val != null && val.trim().isNotEmpty;
    }

    // Leading dot identifier: unspecified / unpopulated context variable evaluates to false
    if (clean.startsWith('.')) {
      return false;
    }

    return clean.isNotEmpty;
  }

  static String _resolveValue(
    String token,
    String keyword,
    List<dynamic> categories,
    Map<String, String> config,
    Map<String, String> query,
  ) {
    var clean = token.trim();
    if ((clean.startsWith('"') && clean.endsWith('"')) ||
        (clean.startsWith("'") && clean.endsWith("'"))) {
      return clean.substring(1, clean.length - 1);
    }
    if (clean == '.Keywords' || clean == '.Query.Keywords') {
      return keyword;
    }
    if (clean.startsWith('.Config.')) {
      return config[clean.substring(8)] ?? '';
    }
    if (clean.startsWith('.Query.')) {
      return query[clean.substring(7)] ?? '';
    }
    return clean;
  }
}
