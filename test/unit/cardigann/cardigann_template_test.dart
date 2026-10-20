import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_template.dart';

void main() {
  group('CardigannTemplate Tests', () {
    test('Substitutes basic variables', () {
      final res = CardigannTemplate.render(
        '/search?q={{ .Keywords }}&cat={{ .Categories }}&sort={{ .Config.sort }}',
        keyword: 'Sousou no Frieren',
        categories: [5070, 5000],
        config: {'sort': 'seeders'},
      );

      expect(
        res,
        equals('/search?q=Sousou no Frieren&cat=5070,5000&sort=seeders'),
      );
    });

    test('Encodes keywords when urlEncodeKeywords is true', () {
      final res = CardigannTemplate.render(
        '/search/{{ .Keywords }}/1/',
        keyword: 'Dune: Part Two',
        urlEncodeKeywords: true,
      );

      expect(res, equals('/search/Dune%3A%20Part%20Two/1/'));
    });

    test('Evaluates {{ if .Keywords }} conditionals', () {
      const tmpl = '{{ if .Keywords }}search/{{ .Keywords }}{{ else }}browse/latest{{ end }}';

      expect(
        CardigannTemplate.render(tmpl, keyword: 'Oppenheimer'),
        equals('search/Oppenheimer'),
      );

      expect(
        CardigannTemplate.render(tmpl, keyword: ''),
        equals('browse/latest'),
      );
    });

    test('Evaluates {{ if .Categories }} conditionals and range', () {
      const tmpl = '{{ if .Categories }}c={{ range .Categories }}[{{ . }}]{{ end }}{{ else }}c=all{{ end }}';

      expect(
        CardigannTemplate.render(tmpl, keyword: '', categories: [1, 2]),
        equals('c=[1][2]'),
      );

      expect(
        CardigannTemplate.render(tmpl, keyword: '', categories: []),
        equals('c=all'),
      );
    });

    test('Substitutes date variables', () {
      final now = DateTime.now();
      final res = CardigannTemplate.render(
        'archive/{{ .Today.Year }}-{{ .Today.Month }}',
        keyword: '',
      );

      final expected = 'archive/${now.year}-${now.month.toString().padLeft(2, '0')}';
      expect(res, equals(expected));
    });

    test('Evaluates .Query conditionals and defaults to else when absent', () {
      const tmpl = '{{ if .Query.IMDBID }}{{ .Query.IMDBID }}{{ else }}{{ .Keywords }}{{ end }}';

      // When IMDBID is not in query, evaluates to keywords (fixes YTS bug)
      expect(
        CardigannTemplate.render(tmpl, keyword: '黑神话悟空'),
        equals('黑神话悟空'),
      );

      // When IMDBID is provided in query, evaluates to IMDBID
      expect(
        CardigannTemplate.render(tmpl, keyword: '黑神话悟空', query: {'IMDBID': 'tt1234567'}),
        equals('tt1234567'),
      );
    });

    test('Evaluates eq and ne comparisons in conditionals', () {
      const tmplEq = '{{ if eq .Config.mode "fast" }}quick{{ else }}thorough{{ end }}';
      expect(
        CardigannTemplate.render(tmplEq, keyword: '', config: {'mode': 'fast'}),
        equals('quick'),
      );
      expect(
        CardigannTemplate.render(tmplEq, keyword: '', config: {'mode': 'slow'}),
        equals('thorough'),
      );
    });
  });
}
