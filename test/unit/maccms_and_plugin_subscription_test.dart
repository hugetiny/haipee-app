import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/plugin/plugin_subscription.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/request/request.dart';

void main() {
  group('AppleCMS / MacCMS JSON Protocol & Asset Tests', () {
    test('Preset MacCMS asset files exist and have valid configuration', () {
      final presetFiles = [
        'assets/plugins/liangzi.json',
        'assets/plugins/ffzy.json',
        'assets/plugins/bfzy.json',
        'assets/plugins/jyzy.json',
      ];

      for (final path in presetFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path should exist');
        final content = file.readAsStringSync();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final plugin = Plugin.fromJson(map);

        expect(plugin.isMacCms, isTrue, reason: '${plugin.name} should be MacCMS');
        expect(plugin.useNativePlayer, isTrue);
        expect(plugin.baseUrl, startsWith('http'));
        expect(plugin.searchURL, contains('ac=detail'));
        expect(plugin.searchURL, contains('at=json'));
      }
    });

    test('PluginsController bundled catalogs include all 4 MacCMS sources', () {
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/liangzi.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/ffzy.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/bfzy.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/jyzy.json'));

      expect(PluginsController.bundledPluginNames, contains('liangzi'));
      expect(PluginsController.bundledPluginNames, contains('ffzy'));
      expect(PluginsController.bundledPluginNames, contains('bfzy'));
      expect(PluginsController.bundledPluginNames, contains('jyzy'));
    });

    test('assets/plugins/index.json market directory contains all 4 MacCMS sources', () {
      final file = File('assets/plugins/index.json');
      expect(file.existsSync(), isTrue);
      final indexList = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      final names = indexList.map((e) => (e as Map<String, dynamic>)['name']?.toString()).toSet();

      expect(names, contains('量子影视'));
      expect(names, contains('非凡影视'));
      expect(names, contains('暴风影视'));
      expect(names, contains('金鹰影视'));
    });

    test('queryMacCmsBangumi parses MacCMS V10 detail JSON with https upgrade and remarks', () async {
      Request(); // 初始化 Request 单例与 dio
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('cj.lziapi.com')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 1,
                  'msg': '数据列表',
                  'page': 1,
                  'pagecount': 1,
                  'limit': '20',
                  'total': 2,
                  'list': [
                    {
                      'vod_id': 98765,
                      'vod_name': '葬送的芙莉莲',
                      'type_name': '日本动漫',
                      'vod_pic': 'http://img.lziapi.com/frieren.jpg',
                      'vod_remarks': '更新至第28集',
                      'vod_play_from': 'lzm3u8',
                      'vod_play_url': '第01集\$https://lz.cdn.com/1.m3u8#第02集\$https://lz.cdn.com/2.m3u8',
                    },
                    {
                      'vod_id': 98766,
                      'vod_name': '葬送的芙莉莲 特别篇',
                      'type_name': '日本动漫',
                      'vod_pic': 'https://img.lziapi.com/sp.jpg',
                      'vod_sub': '全1集',
                      'vod_play_from': 'lzm3u8',
                      'vod_play_url': '正片\$https://lz.cdn.com/sp.m3u8',
                    }
                  ]
                },
              ),
            );
          } else {
            handler.next(options);
          }
        },
      );

      Request.dio.interceptors.insert(0, interceptor);
      try {
        final plugin = Plugin(
          api: '1',
          type: 'maccms',
          name: '量子影视',
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://cj.lziapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );

        final res = await plugin.queryBangumi('芙莉莲');
        expect(res.data.length, equals(2));

        // 验证条目1: 保留原始http海报（避免无SSL站点握手失败），提取vod_remarks
        final item1 = res.data[0];
        expect(item1.name, equals('葬送的芙莉莲'));
        expect(item1.pic, equals('http://img.lziapi.com/frieren.jpg'));
        expect(item1.remarks, equals('更新至第28集'));
        expect(item1.src, contains('ids=98765'));

        // 验证条目2: 原生https海报保留，从vod_sub回退提取remarks
        final item2 = res.data[1];
        expect(item2.name, equals('葬送的芙莉莲 特别篇'));
        expect(item2.pic, equals('https://img.lziapi.com/sp.jpg'));
        expect(item2.remarks, equals('全1集'));
        expect(item2.src, contains('ids=98766'));
      } finally {
        Request.dio.interceptors.remove(interceptor);
      }
    });
  });

  group('Plugin.parseMany & Multi-Rule Batch Parsing Tests', () {
    test('parseMany parses single JSON plugin', () {
      final singleJson = jsonEncode({
        'api': '1',
        'type': 'maccms',
        'name': '单条JSON规则',
        'version': '1.0',
        'baseURL': 'https://json.example.com',
      });

      final result = Plugin.parseMany(singleJson);
      expect(result.length, equals(1));
      expect(result.first.name, equals('单条JSON规则'));
      expect(result.first.isMacCms, isTrue);
    });

    test('parseMany parses JSON array of plugins', () {
      final arrayJson = jsonEncode([
        {'name': '规则1', 'baseURL': 'https://a.com'},
        {'name': '规则2', 'baseURL': 'https://b.com'},
        {'name': '规则3', 'baseURL': 'https://c.com'},
      ]);

      final result = Plugin.parseMany(arrayJson);
      expect(result.length, equals(3));
      expect(result[0].name, equals('规则1'));
      expect(result[1].name, equals('规则2'));
      expect(result[2].name, equals('规则3'));
    });

    test('parseMany parses catalog dictionary format with plugins key', () {
      final catalogJson = jsonEncode({
        'version': '2.0',
        'plugins': [
          {'name': '目录规则A', 'baseURL': 'https://cat-a.com'},
          {'name': '目录规则B', 'baseURL': 'https://cat-b.com'},
        ]
      });

      final result = Plugin.parseMany(catalogJson);
      expect(result.length, equals(2));
      expect(result[0].name, equals('目录规则A'));
      expect(result[1].name, equals('目录规则B'));
    });

    test('parseMany parses single YAML document', () {
      const singleYaml = '''
name: 单个YAML规则
type: maccms
version: "1.0"
baseURL: https://yaml.example.com
searchURL: https://yaml.example.com/api?wd=@keyword
''';

      final result = Plugin.parseMany(singleYaml);
      expect(result.length, equals(1));
      expect(result.first.name, equals('单个YAML规则'));
      expect(result.first.isMacCms, isTrue);
      expect(result.first.baseUrl, equals('https://yaml.example.com'));
    });

    test('parseMany parses multi-document YAML separated by ---', () {
      const multiYaml = '''
name: 多文档规则1
baseURL: https://doc1.com
type: maccms
---
name: 多文档规则2
baseURL: https://doc2.com
type: anime
---
name: 多文档规则3
baseURL: https://doc3.com
''';

      final result = Plugin.parseMany(multiYaml);
      expect(result.length, equals(3));
      expect(result[0].name, equals('多文档规则1'));
      expect(result[0].isMacCms, isTrue);
      expect(result[1].name, equals('多文档规则2'));
      expect(result[2].name, equals('多文档规则3'));
    });

    test('parseMany parses Base64 encoded JSON string', () {
      final rawJson = jsonEncode({
        'name': 'Base64编码规则',
        'type': 'maccms',
        'baseURL': 'https://b64.example.com',
      });
      final b64 = base64Encode(utf8.encode(rawJson));

      final result = Plugin.parseMany(b64);
      expect(result.length, equals(1));
      expect(result.first.name, equals('Base64编码规则'));
      expect(result.first.baseUrl, equals('https://b64.example.com'));
    });

    test('parseMany parses haipee:// Base64 URI string', () {
      final rawJson = jsonEncode({
        'name': 'Haipee口令规则',
        'type': 'maccms',
        'baseURL': 'https://uri.example.com',
      });
      final b64 = 'haipee://${base64Encode(utf8.encode(rawJson))}';

      final result = Plugin.parseMany(b64);
      expect(result.length, equals(1));
      expect(result.first.name, equals('Haipee口令规则'));
      expect(result.first.baseUrl, equals('https://uri.example.com'));
    });

    test('parseMany parses kazumi:// Base64 URI string', () {
      final rawJson = jsonEncode({
        'name': 'Kazumi口令规则',
        'type': 'maccms',
        'baseURL': 'https://uri.example.com',
      });
      final b64 = 'kazumi://${base64Encode(utf8.encode(rawJson))}';

      final result = Plugin.parseMany(b64);
      expect(result.length, equals(1));
      expect(result.first.name, equals('Kazumi口令规则'));
      expect(result.first.baseUrl, equals('https://uri.example.com'));
    });

    test('parseMany gracefully returns empty list on invalid input', () {
      expect(Plugin.parseMany(''), isEmpty);
      expect(Plugin.parseMany('   '), isEmpty);
      expect(Plugin.parseMany('not valid json or yaml: [::]'), isEmpty);
    });
  });

  group('PluginSubscription Remote Fetch Tests', () {
    test('PluginSubscription serialization round-trip', () {
      final sub = PluginSubscription(
        id: 'sub_123',
        name: '高质量苹果CMS远程订阅源',
        url: 'https://raw.githubusercontent.com/user/rules/main/index.json',
        enabled: true,
        lastSync: DateTime.parse('2026-10-19T12:00:00Z'),
        pluginCount: 8,
      );

      final json = sub.toJson();
      final restored = PluginSubscription.fromJson(json);

      expect(restored.id, equals(sub.id));
      expect(restored.name, equals(sub.name));
      expect(restored.url, equals(sub.url));
      expect(restored.enabled, equals(sub.enabled));
      expect(restored.lastSync, equals(sub.lastSync));
      expect(restored.pluginCount, equals(sub.pluginCount));
    });

    test('fetchPluginsFromUrl parses remote JSON subscription array', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode([
                  {
                    'name': '订阅源规则1',
                    'baseURL': 'https://remote1.com',
                    'type': 'maccms',
                  },
                  {
                    'name': '订阅源规则2',
                    'baseURL': 'https://remote2.com',
                    'type': 'maccms',
                  }
                ]),
              ),
            );
          },
        ),
      );

      final plugins = await PluginSubscription.fetchPluginsFromUrl(
        'https://example.com/subscriptions/remote.json',
        client: dio,
      );

      expect(plugins.length, equals(2));
      expect(plugins[0].name, equals('订阅源规则1'));
      expect(plugins[0].isMacCms, isTrue);
      expect(plugins[1].name, equals('订阅源规则2'));
      expect(plugins[1].isMacCms, isTrue);
    });

    test('fetchPluginsFromUrl parses remote multi-document YAML subscription', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: '''
name: 远程YAML源A
baseURL: https://yamla.com
type: maccms
---
name: 远程YAML源B
baseURL: https://yamlb.com
''',
              ),
            );
          },
        ),
      );

      final plugins = await PluginSubscription.fetchPluginsFromUrl(
        'https://example.com/subscriptions/remote.yaml',
        client: dio,
      );

      expect(plugins.length, equals(2));
      expect(plugins[0].name, equals('远程YAML源A'));
      expect(plugins[1].name, equals('远程YAML源B'));
    });
  });
}
