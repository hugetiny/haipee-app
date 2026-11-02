import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/plugins/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plugin YAML Specification & Cover (searchPic) Tests', () {
    test('1. Bilibili YAML loads correctly with auth and searchPic specifications', () {
      final yamlContent = File('assets/plugins/bilibili.yaml').readAsStringSync();
      final plugin = Plugin.fromYaml(yamlContent);

      expect(plugin.name, equals('bilibili'));
      expect(plugin.type, equals('bilibili'));
      expect(plugin.isBilibili, isTrue);
      expect(plugin.searchMode, equals('bilibili'));
      expect(plugin.searchPic, equals(r'$.data.result[*].pic'));
      expect(plugin.authConfig, isNotNull);
      expect(plugin.authConfig!['type'], equals('bilibili_qrcode'));
      expect(plugin.supportsAuth, isTrue);
    });

    test('2. MacCMS YAML loads correctly with searchPic parameter', () {
      final yamlContent = File('plugins/bfzy.yaml').readAsStringSync();
      final plugin = Plugin.fromYaml(yamlContent);

      expect(plugin.name, equals('暴风影视'));
      expect(plugin.type, equals('maccms'));
      expect(plugin.isMacCms, isTrue);
      expect(plugin.searchPic, equals(r'$.vod_pic'));
    });

    test('3. XPath plugins correctly declare searchPic (.//img)', () {
      final yamlContent = File('plugins/anime7.yaml').readAsStringSync();
      final plugin = Plugin.fromYaml(yamlContent);

      expect(plugin.name, equals('anime7'));
      expect(plugin.searchPic, equals('.//img'));
    });

    test('4. Universal YAML List Parser handles multiple plugins', () {
      const multiYaml = r'''
api: "10"
name: "源A"
type: "maccms"
version: "1.0"
baseURL: "https://a.com"
searchURL: "https://a.com/search?wd=@keyword"
searchPic: "$.vod_pic"
searchList: ""
searchName: ""
searchResult: ""
chapterRoads: ""
chapterResult: ""
---
api: "10"
name: "源B"
type: "anime"
version: "1.0"
baseURL: "https://b.com"
searchURL: "https://b.com/search?wd=@keyword"
searchPic: ".//img"
searchList: "//li"
searchName: "//h3"
searchResult: "//a"
chapterRoads: ""
chapterResult: ""
''';

      final plugins = Plugin.fromYamlList(multiYaml);
      expect(plugins.length, equals(2));
      expect(plugins[0].name, equals('源A'));
      expect(plugins[0].searchPic, equals(r'$.vod_pic'));
      expect(plugins[1].name, equals('源B'));
      expect(plugins[1].searchPic, equals('.//img'));
    });
  });
}
