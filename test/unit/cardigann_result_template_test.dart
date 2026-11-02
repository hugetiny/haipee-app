import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';

void main() {
  test('Cardigann parser correctly resolves {{ .Result._id }} in fields and filters', () {
    const yamlString = '''
id: internetarchive
name: Internet Archive
links:
  - https://archive.org/
caps:
  categories:
    Other: 8000
search:
  paths:
    - path: advancedsearch.php
  rows:
    selector: response.docs
  fields:
    _id:
      selector: identifier
    title:
      selector: title
      default: "Missing title for {{ .Result._id }}"
    details:
      text: "details/{{ .Result._id }}"
    download:
      text: "download/{{ .Result._id }}/{{ .Result._id }}_archive.torrent"
    _btih:
      selector: btih
    magnet:
      text: "{{ .Result._btih }}"
      filters:
        - name: append
          args: "&dn={{ .Result.title }}"
''';

    final def = CardigannParser.parseYaml(yamlString);
    const mockJson = '''
{
  "response": {
    "docs": [
      {
        "identifier": "sanguozhi9_pc",
        "title": "三国志9 威力加强版",
        "btih": "magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12"
      }
    ]
  }
}
''';

    final executor = CardigannQueryExecutor();
    final items = executor.parseJsonResults(
      jsonContent: mockJson,
      definition: def,
      baseUrl: 'https://archive.org',
    );

    expect(items.length, equals(1));
    final item = items.first;
    expect(item.title, equals('三国志9 威力加强版'));
    expect(
      item.torrentUrl,
      equals('https://archive.org/download/sanguozhi9_pc/sanguozhi9_pc_archive.torrent'),
    );
    expect(
      item.magnetUrl,
      equals('magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12&dn=三国志9 威力加强版'),
    );
    expect(
      item.pageUrl,
      equals('https://archive.org/details/sanguozhi9_pc'),
    );
  });
}
