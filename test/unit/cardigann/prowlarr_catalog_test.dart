import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/cardigann/widgets/prowlarr_catalog_dialog.dart';

void main() {
  group('Prowlarr Catalog & Pre-bundled Cardigann Indexers Tests', () {
    test('prowlarr_catalog.json 能够完整读取并成功反序列化 577+ 官方索引器', () {
      final file = File('assets/indexers/prowlarr_catalog.json');
      expect(file.existsSync(), isTrue);

      final jsonStr = file.readAsStringSync();
      final list = jsonDecode(jsonStr) as List;
      expect(list.length, equals(577));

      final entries = list
          .map((e) => ProwlarrCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(entries.length, equals(577));

      // 验证关键主流站点存在
      final ids = entries.map((e) => e.id).toSet();
      expect(ids.contains('nyaasi'), isTrue);
      expect(ids.contains('1337x'), isTrue);
      expect(ids.contains('yts'), isTrue);
      expect(ids.contains('eztv'), isTrue);
      expect(ids.contains('dmhy'), isTrue);
      expect(ids.contains('mikan'), isTrue);
      expect(ids.contains('thepiratebay'), isTrue);
      expect(ids.contains('acgrip'), isTrue);

      // 验证属性解析正确性
      final yts = entries.firstWhere((e) => e.id == 'yts');
      expect(yts.name, equals('YTS'));
      expect(yts.isPublic, isTrue);
      expect(yts.isPrivate, isFalse);
      expect(yts.links, isNotEmpty);
      expect(yts.categoryLabels, contains('电影'));

      final eztv = entries.firstWhere((e) => e.id == 'eztv');
      expect(eztv.name, equals('EZTV'));
      expect(eztv.isPublic, isTrue);
    });

    test('全部 11 个预置的 assets/indexers/*.yml 均可通过 CardigannParser 规范校验', () {
      final bundledFiles = [
        'assets/indexers/nyaasi.yml',
        'assets/indexers/mikan.yml',
        'assets/indexers/thepiratebay.yml',
        'assets/indexers/1337x.yml',
        'assets/indexers/dmhy.yml',
        'assets/indexers/torrentscsv.yml',
        'assets/indexers/yts.yml',
        'assets/indexers/eztv.yml',
        'assets/indexers/acgrip.yml',
        'assets/indexers/tokyotosho.yml',
        'assets/indexers/animetosho-xyz.yml',
      ];

      for (final path in bundledFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'File $path should exist');
        final content = file.readAsStringSync();
        final def = CardigannParser.parseYaml(content);
        expect(def.id, isNotEmpty, reason: '$path must have valid id');
        expect(def.name, isNotEmpty, reason: '$path must have valid name');
        expect(def.search.paths, isNotEmpty, reason: '$path must have search paths');
      }
    });
  });
}
