import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';

void main() {
  group('DouyinService.searchVideos Tests', () {
    test('searchVideos returns empty list when keyword is empty or whitespace', () async {
      final res1 = await DouyinService.searchVideos('');
      final res2 = await DouyinService.searchVideos('   ');
      expect(res1, isEmpty);
      expect(res2, isEmpty);
    });

    test('searchVideos pins single extracted video when keyword contains Douyin link or video ID', () async {
      final dio = Dio();
      final mockFeedJson = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7345678901234567890',
            'desc': '置顶分享短视频测试',
            'author': {'nickname': '创作者A'},
            'video': {
              'cover': {
                'url_list': ['http://p3.douyinpic.com/cover1.jpg']
              },
              'play_addr': {
                'url_list': [
                  'http://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200fg123',
                ]
              }
            }
          }
        ]
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockFeedJson,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final results = await DouyinService.searchVideos(
        'https://www.douyin.com/video/7345678901234567890',
        client: dio,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('7345678901234567890'));
      expect(results.first.title, equals('置顶分享短视频测试'));
      expect(results.first.author, equals('创作者A'));
      expect(results.first.playUrl, contains('play'));
      expect(results.first.playUrl, isNot(contains('playwm')));
      expect(results.first.playUrl, startsWith('https://'));
    });

    test('searchVideos returns empty list for arbitrary plain keywords without fake search or feed scraping', () async {
      final dio = Dio();
      final results1 = await DouyinService.searchVideos('原神', client: dio);
      final results2 = await DouyinService.searchVideos('你好', client: dio);
      final results3 = await DouyinService.searchVideos('猫咪合集', client: dio);
      expect(results1, isEmpty);
      expect(results2, isEmpty);
      expect(results3, isEmpty);
    });

    test('searchVideos parses short link (v.douyin.com) into single extracted video', () async {
      final dio = Dio();
      final mockFeedJson = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7123456789012345678',
            'desc': '分享短链接视频提取测试',
            'author': {'nickname': '短剧达人'},
            'video': {
              'cover': {
                'url_list': ['http://p3.douyinpic.com/short_cover.jpg']
              },
              'play_addr': {
                'url_list': [
                  'http://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200fgshort',
                ]
              }
            }
          }
        ]
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('v.douyin.com')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': ['https://www.douyin.com/video/7123456789012345678']
                  }),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: mockFeedJson,
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );

      final results = await DouyinService.searchVideos(
        '长按复制此条消息，打开抖音搜索，查看TA的精彩作品！ https://v.douyin.com/iABC123/',
        client: dio,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('7123456789012345678'));
      expect(results.first.title, equals('分享短链接视频提取测试'));
      expect(results.first.author, equals('短剧达人'));
      expect(results.first.playUrl, isNot(contains('playwm')));
      expect(results.first.playUrl, startsWith('https://'));
    });

    test('searchVideos parses pure numeric 18-20 digit video ID', () async {
      final dio = Dio();
      final mockFeedJson = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7654321098765432109',
            'desc': '纯数字ID解析测试',
            'author': {'nickname': '创作者B'},
            'video': {
              'cover': {
                'url_list': ['https://p3.douyinpic.com/cover_num.jpg']
              },
              'play_addr': {
                'url_list': [
                  'https://v26-web.douyinvod.com/video/tos/playwm/num.mp4',
                ]
              }
            }
          }
        ]
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockFeedJson,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final results = await DouyinService.searchVideos(
        '7654321098765432109',
        client: dio,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals('7654321098765432109'));
      expect(results.first.title, equals('纯数字ID解析测试'));
      expect(results.first.playUrl, isNot(contains('playwm')));
    });

    test('getRecommendedVideos retrieves playable videos from mobile feed for empty browsing state', () async {
      final dio = Dio();
      final mockFeed = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7611111111111111111',
            'desc': '精选热门短视频A',
            'author': {'nickname': '创作者A'},
            'duration': 12000,
            'video': {
              'cover': {'url_list': ['https://p3.douyinpic.com/rec1.jpg']},
              'play_addr': {'url_list': ['https://v5.365yg.com/rec1.mp4']}
            }
          }
        ]
      });

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockFeed,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final recs = await DouyinService.getRecommendedVideos(client: dio, count: 5);
      expect(recs.length, equals(1));
      expect(recs.first.title, equals('精选热门短视频A'));
      expect(recs.first.playUrl, equals('https://v5.365yg.com/rec1.mp4'));
    });

    test('searchVideos gracefully recovers from Dio exceptions without throwing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
                message: 'Search connection timeout',
              ),
            );
          },
        ),
      );

      final results = await DouyinService.searchVideos('测试超时', client: dio);
      expect(results, isEmpty);
    });
  });

  group('Bilibili & Douyin Declarative Plugin YAML/JSON Tests', () {
    test('assets/plugins/bilibili.json is valid declarative plugin with isBilibili == true', () {
      final file = File('assets/plugins/bilibili.json');
      expect(file.existsSync(), isTrue);

      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final plugin = Plugin.fromJson(jsonMap);

      expect(plugin.name, equals('bilibili'));
      expect(plugin.type, equals('bilibili'));
      expect(plugin.isBilibili, isTrue);
      expect(plugin.isDouyin, isFalse);
      expect(plugin.useNativePlayer, isTrue);
      expect(plugin.baseUrl, equals('https://www.bilibili.com/'));
    });

    test('assets/plugins/douyin.json is valid declarative plugin with isDouyin == true', () {
      final file = File('assets/plugins/douyin.json');
      expect(file.existsSync(), isTrue);

      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final plugin = Plugin.fromJson(jsonMap);

      expect(plugin.name, equals('douyin'));
      expect(plugin.type, equals('douyin'));
      expect(plugin.isDouyin, isTrue);
      expect(plugin.isBilibili, isFalse);
      expect(plugin.useNativePlayer, isTrue);
      expect(plugin.baseUrl, equals('https://www.douyin.com/'));
    });

    test('assets/plugins/bilibili.yaml can be parsed via Plugin.fromYaml and preserves properties', () {
      final file = File('assets/plugins/bilibili.yaml');
      expect(file.existsSync(), isTrue);

      final yamlContent = file.readAsStringSync();
      final plugin = Plugin.fromYaml(yamlContent);

      expect(plugin.name, equals('bilibili'));
      expect(plugin.type, equals('bilibili'));
      expect(plugin.isBilibili, isTrue);
      expect(plugin.useNativePlayer, isTrue);
      expect(plugin.baseUrl, equals('https://www.bilibili.com/'));
    });

    test('assets/plugins/douyin.yaml can be parsed via Plugin.fromYaml and preserves properties', () {
      final file = File('assets/plugins/douyin.yaml');
      expect(file.existsSync(), isTrue);

      final yamlContent = file.readAsStringSync();
      final plugin = Plugin.fromYaml(yamlContent);

      expect(plugin.name, equals('douyin'));
      expect(plugin.type, equals('douyin'));
      expect(plugin.isDouyin, isTrue);
      expect(plugin.useNativePlayer, isTrue);
      expect(plugin.baseUrl, equals('https://www.douyin.com/'));
    });

    test('Plugin.toYamlString and Plugin.fromYaml round-trip preserves all core fields', () {
      final original = Plugin(
        api: '1',
        type: 'media',
        name: 'test_yaml_roundtrip',
        version: '1.2.3',
        muliSources: true,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: 'test_ua',
        baseUrl: 'https://example.com',
        searchURL: 'https://example.com/search?q=@keyword',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: 'https://example.com',
        searchMode: 'douyin',
      );

      final yamlStr = original.toYamlString();
      expect(yamlStr, contains('test_yaml_roundtrip'));
      expect(yamlStr, contains('douyin'));

      final parsed = Plugin.fromYaml(yamlStr);
      expect(parsed.name, equals(original.name));
      expect(parsed.type, equals(original.type));
      expect(parsed.version, equals(original.version));
      expect(parsed.baseUrl, equals(original.baseUrl));
      expect(parsed.searchMode, equals(original.searchMode));
      expect(parsed.useNativePlayer, equals(original.useNativePlayer));
      expect(parsed.isDouyin, isTrue);
    });

    test('PluginsController bundled catalog includes bilibili and douyin', () {
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/bilibili.json'));
      expect(PluginsController.bundledPluginAssets, contains('assets/plugins/douyin.json'));

      expect(PluginsController.bundledPluginNames, contains('bilibili'));
      expect(PluginsController.bundledPluginNames, contains('douyin'));
    });

    test('assets/plugins/index.json bundled market contains entries for bilibili and douyin', () {
      final indexFile = File('assets/plugins/index.json');
      expect(indexFile.existsSync(), isTrue);

      final indexList = jsonDecode(indexFile.readAsStringSync()) as List<dynamic>;
      final names = indexList.map((e) => (e as Map<String, dynamic>)['name']?.toString()).toSet();

      expect(names, contains('bilibili'));
      expect(names, contains('douyin'));
    });
  });
}
