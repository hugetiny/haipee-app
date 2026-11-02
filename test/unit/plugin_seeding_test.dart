import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';

void main() {
  group('Video Plugin Seeding and Specification Tests', () {
    test('内置预装规则配置包含官方精选规则列表', () {
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/mutefun.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/dalvdm.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/anime7.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/DM84.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/xfdm.json'));
    });

    test('全部预置 assets/plugins/*.json 文件存在且符合 Plugin 规范', () {
      for (final assetPath in PluginsController.bundledPluginAssets) {
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: '内置规则文件不存在: $assetPath');

        final jsonStr = file.readAsStringSync();
        expect(jsonStr.isNotEmpty, isTrue);

        final dynamic data = jsonDecode(jsonStr);
        expect(data, isA<Map<String, dynamic>>());

        final plugin = Plugin.fromJson(data as Map<String, dynamic>);
        expect(plugin.name.isNotEmpty, isTrue);
        expect(plugin.baseUrl.isNotEmpty, isTrue);
        expect(plugin.api.isNotEmpty, isTrue);
      }
    });

    test('解析 mutefun.json, dalvdm.json 规则属性完整正确且为 API 模式', () {
      final mutefunFile = File('assets/plugins/mutefun.json');
      final mutefunPlugin = Plugin.fromJson(jsonDecode(mutefunFile.readAsStringSync()));
      expect(mutefunPlugin.name, 'mutefun');
      expect(mutefunPlugin.type, 'anime');
      expect(mutefunPlugin.searchMode, 'api');
      expect(mutefunPlugin.searchApiConfig, isNotNull);

      final dalvdmFile = File('assets/plugins/dalvdm.json');
      final dalvdmPlugin = Plugin.fromJson(jsonDecode(dalvdmFile.readAsStringSync()));
      expect(dalvdmPlugin.name, 'dalvdm');
      expect(dalvdmPlugin.searchMode, 'api');
      expect(dalvdmPlugin.searchApiConfig, isNotNull);
    });

    test('去重逻辑验证：重复添加同名规则不会导致列表膨胀', () {
      final anime7File = File('assets/plugins/anime7.json');
      final plugin = Plugin.fromJson(jsonDecode(anime7File.readAsStringSync()));

      final List<Plugin> list = [];
      // 首次添加
      if (!list.any((p) => p.name == plugin.name)) {
        list.add(plugin);
      }
      expect(list.length, 1);

      // 二次添加相同规则
      if (!list.any((p) => p.name == plugin.name)) {
        list.add(plugin);
      }
      expect(list.length, 1);
    });
  });
}
