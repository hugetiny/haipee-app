import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';

void main() {
  group('Indexer Plugin Lifecycle, Override & Ingestion Tests', () {
    test('内置站点判定 (isBundledId) 能准确识别官方 11 个预置索引器', () {
      const expectedBundled = [
        'nyaasi',
        'mikan',
        'thepiratebay',
        '1337x',
        'dmhy',
        'torrentscsv',
        'yts',
        'eztv',
        'acgrip',
        'tokyotosho',
        'animetosho-xyz',
      ];

      for (final id in expectedBundled) {
        expect(IndexerPluginsNotifier.isBundledId(id), isTrue,
            reason: '$id 应该被识别为官方内置');
      }

      expect(IndexerPluginsNotifier.isBundledId('custom_site_xyz'), isFalse);
      expect(IndexerPluginsNotifier.isBundledId('my_private_tracker'), isFalse);
    });

    test('已覆写内置规则判定 (isPluginOverridden) 能够精确检测用户修改', () {
      final nyaaFile = File('assets/indexers/nyaasi.yml');
      expect(nyaaFile.existsSync(), isTrue);
      final originalYaml = nyaaFile.readAsStringSync();

      // 注册原始版本至缓存
      IndexerPluginsNotifier.registerBundledYaml('nyaasi', originalYaml);

      // 1. 未修改版本：isOverridden 必须为 false
      expect(
        IndexerPluginsNotifier.isPluginOverridden('nyaasi', originalYaml),
        isFalse,
      );

      // 2. 用户修改了链接或选择器：isOverridden 必须为 true
      final modifiedYaml = originalYaml.replaceFirst(
        'https://nyaa.si/',
        'https://nyaa.land/',
      );
      expect(
        IndexerPluginsNotifier.isPluginOverridden('nyaasi', modifiedYaml),
        isTrue,
      );

      // 3. 自定义规则 (非内置)：isOverridden 必须为 false
      expect(
        IndexerPluginsNotifier.isPluginOverridden(
          'custom_site',
          'site: custom\nname: Custom\n',
        ),
        isFalse,
      );
    });

    test('IndexerPlugin 实体状态属性 (isBundled, isOverridden, isCustom) 正确性', () {
      final nyaaFile = File('assets/indexers/nyaasi.yml');
      final originalYaml = nyaaFile.readAsStringSync();
      IndexerPluginsNotifier.registerBundledYaml('nyaasi', originalYaml);

      // 官方未修改内置插件
      final builtInPlugin = IndexerPlugin.fromYaml(
        originalYaml,
        isBuiltIn: true,
      );
      expect(builtInPlugin.id, equals('nyaasi'));
      expect(builtInPlugin.isBundled, isTrue);
      expect(builtInPlugin.isOverridden, isFalse);
      expect(builtInPlugin.isCustom, isFalse);

      // 用户覆写修改后的内置插件
      final modifiedYaml = '$originalYaml\n# Custom comment by user';
      final overriddenPlugin = IndexerPlugin.fromYaml(
        modifiedYaml,
        isBuiltIn: true,
      );
      expect(overriddenPlugin.id, equals('nyaasi'));
      expect(overriddenPlugin.isBundled, isTrue);
      expect(overriddenPlugin.isOverridden, isTrue);
      expect(overriddenPlugin.isCustom, isFalse);

      // 用户全新上传的第三方新站插件 (YAML 保持原样)
      const customYaml = '''
site: futuretracker
name: Future Tracker
description: A brand new torrent tracker for testing
language: zh-CN
type: public
links:
  - https://future-tracker.org/
caps:
  categories:
    all: Other
search:
  paths:
    - path: search
      inputs:
        q: "{{ .Keywords }}"
  rows:
    selector: table.torrents tr
  fields:
    title:
      selector: a.title
    magnet:
      selector: a[href^="magnet:"]
      attribute: href
''';

      final customPlugin = IndexerPlugin.fromYaml(customYaml);
      expect(customPlugin.id, equals('futuretracker'));
      expect(customPlugin.name, equals('Future Tracker'));
      expect(customPlugin.isBundled, isFalse);
      expect(customPlugin.isOverridden, isFalse);
      expect(customPlugin.isCustom, isTrue);
      expect(customPlugin.rawYaml, equals(customYaml)); // 原样保持，零篡改
    });
  });
}
