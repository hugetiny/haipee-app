/// Template engine for Cardigann URL paths and query inputs.
class CardigannTemplate {
  /// Renders a template string by replacing Go template variables and evaluating basic conditionals.
  static String render(
    String template, {
    required String keyword,
    List<dynamic> categories = const [],
    Map<String, String> config = const {},
    Map<String, String> query = const {},
    Map<String, String> result = const {},
    bool urlEncodeKeywords = false,
  }) {
    if (template.isEmpty) return '';

    final resultVars = result;
    var output = template;

    // 1. Evaluate range: {{ range .Categories }}{{ . }}{{ end }}
    final rangeRegex = RegExp(
      r'\{\{\s*range\s+\.Categories\s*\}\}([\s\S]*?)\{\{\s*end\s*\}\}',
    );
    output = output.replaceAllMapped(rangeRegex, (match) {
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
    while (innermostIfRegex.hasMatch(output) && maxLoops-- > 0) {
      output = output.replaceAllMapped(innermostIfRegex, (match) {
        final conditionVar = match.group(1)!.trim();
        final thenBlock = match.group(2) ?? '';
        final elseBlock = match.group(3) ?? '';

        final isTrue = _evalCondition(
          conditionVar,
          keyword: keyword,
          categories: categories,
          config: config,
          query: query,
          result: resultVars,
        );
        return isTrue ? thenBlock : elseBlock;
      });
    }

    // 3. Variable replacements
    final kwValue = urlEncodeKeywords ? Uri.encodeComponent(keyword) : keyword;
    final catValue = categories.isNotEmpty ? categories.join(',') : '';

    output = output.replaceAll(RegExp(r'\{\{\s*\.Keywords\s*\}\}'), kwValue);
    output = output.replaceAll(RegExp(r'\{\{\s*\.Query\.Keywords\s*\}\}'), kwValue);
    output = output.replaceAll(RegExp(r'\{\{\s*\.Categories\s*\}\}'), catValue);

    // Query variables: {{ .Query.<field> }}
    query.forEach((k, v) {
      output = output.replaceAll(
          RegExp(r'\{\{\s*\.Query\.' + RegExp.escape(k) + r'\s*\}\}'), v);
    });

    // Date variables
    final now = DateTime.now();
    output = output.replaceAll(
        RegExp(r'\{\{\s*\.Today\.Year\s*\}\}'), now.year.toString());
    output = output.replaceAll(RegExp(r'\{\{\s*\.Today\.Month\s*\}\}'),
        now.month.toString().padLeft(2, '0'));
    output = output.replaceAll(RegExp(r'\{\{\s*\.Today\.Day\s*\}\}'),
        now.day.toString().padLeft(2, '0'));

    // Result variables (row field context): {{ .Result.fieldName }}
    final resultVarRegex = RegExp(r'\{\{\s*\.Result\.([a-zA-Z0-9_-]+)\s*\}\}');
    output = output.replaceAllMapped(resultVarRegex, (match) {
      return resultVars[match.group(1)!] ?? '';
    });

    // Config variables: {{ .Config.settingName }}
    final configVarRegex = RegExp(r'\{\{\s*\.Config\.([a-zA-Z0-9_-]+)\s*\}\}');
    output = output.replaceAllMapped(configVarRegex, (match) {
      final key = match.group(1)!;
      return config[key] ?? '';
    });

    // Clean any remaining unhandled template markers
    output = output.replaceAll(RegExp(r'\{\{[^\}]*\}\}'), '').trim();

    return output;
  }

  static bool _evalCondition(
    String condition, {
    required String keyword,
    required List<dynamic> categories,
    required Map<String, String> config,
    Map<String, String> query = const {},
    Map<String, String> result = const {},
  }) {
    final clean = condition.trim();

    // Logical operators: or/and <arg1> <arg2> ...
    final logicMatch = RegExp(r'^(or|and)\s+(.+)$').firstMatch(clean);
    if (logicMatch != null) {
      final args = logicMatch.group(2)!.split(RegExp(r'\s+')).where((a) => a.isNotEmpty);
      bool evalArg(String a) => _evalCondition(
            a,
            keyword: keyword,
            categories: categories,
            config: config,
            query: query,
            result: result,
          );
      return logicMatch.group(1) == 'or' ? args.any(evalArg) : args.every(evalArg);
    }

    // Check negation e.g. "not .Keywords"
    if (clean.startsWith('not ')) {
      final sub = clean.substring(4).trim();
      return !_evalCondition(
        sub,
        keyword: keyword,
        categories: categories,
        config: config,
        query: query,
        result: result,
      );
    }

    // Comparison: eq <arg1> <arg2> or ne <arg1> <arg2>
    final cmpMatch =
        RegExp(r'^(eq|ne)\s+([^\s]+)\s+([^\s]+)$').firstMatch(clean);
    if (cmpMatch != null) {
      final op = cmpMatch.group(1)!;
      final a =
          _resolveValue(cmpMatch.group(2)!, keyword, categories, config, query, result);
      final b =
          _resolveValue(cmpMatch.group(3)!, keyword, categories, config, query, result);
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

    if (clean.startsWith('.Result.')) {
      final val = result[clean.substring(8)];
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
    Map<String, String> query, [
    Map<String, String> result = const {},
  ]) {
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
    if (clean.startsWith('.Result.')) {
      return result[clean.substring(8)] ?? '';
    }
    return clean;
  }
}
