import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';

void main() {
  group('CardigannParser Tests', () {
    test('Parses complete Cardigann YAML definition correctly', () {
      const yaml = '''
---
id: test-tracker
name: Test Tracker
description: "A test torrent indexer"
language: zh-CN
type: private
encoding: UTF-8
links:
  - https://test-tracker.org/
  - https://backup.test-tracker.org/

caps:
  categorymappings:
    - {id: 1, cat: 5070, desc: "Anime"}
    - {id: 2, cat: 2000, desc: "Movies"}
    - {id: 3, cat: 1000, desc: "Music"}
  modes:
    search: [q]
    tv-search: [q, season, ep]

settings:
  - name: cookie
    type: text
    label: Site Cookie
    default: ""
  - name: passkey
    type: password
    label: Download Passkey
  - name: sort
    type: select
    label: Sort By
    default: seeders
    options:
      seeders: Seeders
      time: Time

login:
  path: /login.php
  method: post
  inputs:
    username: "{{ .Config.username }}"
    password: "{{ .Config.password }}"

search:
  paths:
    - path: /torrents.php
      method: get
      categories: [1, 2]
  inputs:
    search: "{{ .Keywords }}"
    cat: "{{ .Categories }}"
    sort: "{{ .Config.sort }}"

  rows:
    selector: table.torrents > tbody > tr
    after: 1

  fields:
    title:
      selector: a.torrent-name
      attribute: title
      filters:
        - name: trim
    details:
      selector: a.torrent-name
      attribute: href
    magnet:
      selector: a[href^="magnet:"]
      attribute: href
    size:
      selector: td.size
      filters:
        - name: trim
    seeders:
      selector: td.seeders
    leechers:
      selector: td.leechers
    downloadvolumefactor:
      case:
        tr.freeleech: 0
        "*": 1
''';

      final def = CardigannParser.parseYaml(yaml);

      expect(def.id, equals('test-tracker'));
      expect(def.name, equals('Test Tracker'));
      expect(def.description, equals('A test torrent indexer'));
      expect(def.language, equals('zh-CN'));
      expect(def.type, equals('private'));
      expect(def.isPrivate, isTrue);
      expect(def.isPublic, isFalse);
      expect(def.links, equals(['https://test-tracker.org/', 'https://backup.test-tracker.org/']));
      expect(def.defaultLink, equals('https://test-tracker.org/'));

      // Caps
      expect(def.caps.categorymappings.length, equals(3));
      expect(def.caps.categorymappings[0].id, equals('1'));
      expect(def.caps.categorymappings[0].cat, equals(5070));
      expect(def.mapToTorznabCategory('1'), equals(5070));
      expect(def.mapToTorznabCategory('2'), equals(2000));
      expect(def.caps.modes['search'], equals(['q']));

      // Settings
      expect(def.settings.length, equals(3));
      expect(def.settings[0].name, equals('cookie'));
      expect(def.settings[1].name, equals('passkey'));
      expect(def.settings[1].type, equals('password'));
      expect(def.settings[2].options['seeders'], equals('Seeders'));

      // Login
      expect(def.login, isNotNull);
      expect(def.login!.path, equals('/login.php'));
      expect(def.login!.method, equals('post'));

      // Search
      expect(def.search.paths.length, equals(1));
      expect(def.search.paths[0].path, equals('/torrents.php'));
      expect(def.search.paths[0].categories, equals([1, 2]));
      expect(def.search.inputs['search'], equals('{{ .Keywords }}'));

      // Rows
      expect(def.search.rows.selector, equals('table.torrents > tbody > tr'));
      expect(def.search.rows.after, equals(1));

      // Fields
      expect(def.search.fields.containsKey('title'), isTrue);
      expect(def.search.fields['title']!.selector, equals('a.torrent-name'));
      expect(def.search.fields['title']!.attribute, equals('title'));
      expect(def.search.fields['title']!.filters.first.name, equals('trim'));

      expect(def.search.fields['downloadvolumefactor']!.caseConditions?['tr.freeleech'], equals(0));
      expect(def.search.fields['downloadvolumefactor']!.caseConditions?['*'], equals(1));
    });

    test('Throws FormatException on invalid YAML', () {
      expect(() => CardigannParser.parseYaml('just a raw scalar string'), throwsFormatException);
    });

    test('Parses minimal YAML gracefully with sensible defaults', () {
      const yaml = '''
name: Minimal Tracker
links:
  - https://minimal.org/
search:
  rows:
    selector: tr
  fields:
    title:
      selector: a
''';
      final def = CardigannParser.parseYaml(yaml);
      expect(def.name, equals('Minimal Tracker'));
      expect(def.id, equals('minimaltracker'));
      expect(def.type, equals('public'));
      expect(def.isPublic, isTrue);
      expect(def.search.paths.length, equals(1));
      expect(def.search.paths.first.path, equals('/'));
    });
  });
}
