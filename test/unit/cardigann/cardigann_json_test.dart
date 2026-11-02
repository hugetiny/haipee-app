import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';

void main() {
  group('CardigannQueryExecutor JSON API Tests', () {
    late CardigannQueryExecutor executor;

    setUp(() {
      executor = CardigannQueryExecutor();
    });

    test('parseJsonResults properly parses Torrents.csv style JSON response', () {
      final yamlContent = File('assets/indexers/torrentscsv.yml').readAsStringSync();
      final definition = CardigannParser.parseYaml(yamlContent);

      const jsonSample = '''
      {
        "torrents": [
          {
            "name": "Ubuntu.Linux.24.04.LTS.Desktop.AMD64.ISO",
            "infohash": "d1c2b3a4e5f60718293a4b5c6d7e8f9012345678",
            "size_bytes": 6120349696,
            "seeders": 450,
            "leechers": 12,
            "created_unix": 1714003200
          },
          {
            "name": "Dune.Part.Two.2024.1080p.WEB-DL.DDP5.1.Atmos.H.264-FLUX",
            "infohash": "aabbccddeeff00112233445566778899aabbccdd",
            "size_bytes": 8589934592,
            "seeders": 120,
            "leechers": 5,
            "created_unix": 1710000000
          }
        ]
      }
      ''';

      final results = executor.parseJsonResults(
        jsonContent: jsonSample,
        definition: definition,
        baseUrl: 'https://torrents-csv.com',
      );

      expect(results.length, equals(2));

      final first = results[0];
      expect(first.title, equals('Ubuntu.Linux.24.04.LTS.Desktop.AMD64.ISO'));
      expect(first.sizeBytes, equals(6120349696));
      expect(first.seeders, equals(450));
      expect(first.leechers, equals(12));
      expect(first.indexerName, equals('Torrents.csv'));
      expect(first.indexerId, equals('torrentscsv'));
      expect(first.source, equals(TorrentSourceType.cardigann));
      expect(first.magnetUrl, startsWith('magnet:?xt=urn:btih:d1c2b3a4e5f60718293a4b5c6d7e8f9012345678'));
      expect(first.magnetUrl, contains('&dn=Ubuntu.Linux.24.04.LTS.Desktop.AMD64.ISO'));

      final second = results[1];
      expect(second.title, contains('Dune.Part.Two'));
      expect(second.resolution, equals('1080p'));
      expect(second.codec, equals('AVC'));
      expect(second.audio, equals('DDP'));
      expect(second.mediaSource, equals('WEB-DL'));
    });

    test('parseJsonResults handles root array JSON response gracefully', () {
      const yaml = '''
id: rootjson
name: Root JSON Tracker
links:
  - https://api.tracker.com/
search:
  paths:
    - path: "api/torrents"
      response:
        type: json
  rows:
    selector: "\$"
  fields:
    title:
      selector: "title"
    magnet:
      selector: "magnetUri"
    size:
      selector: "size"
    seeders:
      selector: "peers.seeders"
''';
      final definition = CardigannParser.parseYaml(yaml);

      const jsonSample = '''
      [
        {
          "title": "OpenSource.Software.v1.0.tar.gz",
          "magnetUri": "magnet:?xt=urn:btih:ROOTTEST12345",
          "size": "50 MB",
          "peers": {
            "seeders": 88
          }
        }
      ]
      ''';

      final results = executor.parseJsonResults(
        jsonContent: jsonSample,
        definition: definition,
        baseUrl: 'https://api.tracker.com',
      );

      expect(results.length, equals(1));
      final item = results.first;
      expect(item.title, equals('OpenSource.Software.v1.0.tar.gz'));
      expect(item.magnetUrl, equals('magnet:?xt=urn:btih:ROOTTEST12345'));
      expect(item.seeders, equals(88));
      expect(item.sizeBytes, equals(50 * 1024 * 1024));
    });
  });
}
