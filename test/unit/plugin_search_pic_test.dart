import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/storage.dart';

class _MockPicInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('xpath-pic-test')) {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="video-list">
    <div class="video-item">
      <a class="title" href="/detail/1001.html">测试动漫一</a>
      <img class="poster" src="https://img.example.com/cover1.jpg" />
    </div>
    <div class="video-item">
      <a class="title" href="/detail/1002.html">测试动漫二</a>
      <img class="poster" data-original="https://img.example.com/cover2.webp" />
    </div>
  </div>
</body>
</html>
''';
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: html,
        ),
      );
    }

    if (options.path.contains('api-pic-test')) {
      final apiJson = {
        'code': 1,
        'list': [
          {
            'name': 'API动漫A',
            'id': '2001',
            'pic': 'https://api-img.example.com/a.jpg',
          },
          {
            'name': 'API动漫B',
            'id': '2002',
            'pic': '/uploads/b.png',
          }
        ]
      };
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonEncode(apiJson),
        ),
      );
    }

    return handler.next(options);
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_search_pic_test');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
    Request(); // 初始化 Request.dio 单例
    Request.dio.interceptors.insert(0, _MockPicInterceptor());
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Plugin searchPic & picPath 缩略图引擎扩展测试', () {
    test('Plugin.fromJson 与 toYamlString 完整支持 searchPic', () {
      final json = {
        'api': '9',
        'type': 'anime',
        'name': 'custom_rule',
        'version': '1.0',
        'baseURL': 'https://example.com/',
        'searchURL': 'https://example.com/search?q=@keyword',
        'searchList': '//div[@class="video-item"]',
        'searchName': './/a[@class="title"]',
        'searchResult': './/a[@class="title"]',
        'searchPic': './/img[@class="poster"]',
        'chapterRoads': '//div',
        'chapterResult': '//a',
      };

      final plugin = Plugin.fromJson(json);
      expect(plugin.searchPic, equals('.//img[@class="poster"]'));

      final outJson = plugin.toJson();
      expect(outJson['searchPic'], equals('.//img[@class="poster"]'));

      final yaml = plugin.toYamlString();
      expect(yaml, contains('searchPic: ".//img[@class=\\"poster\\"]"'));
    });

    test('XPath 规则通过 searchPic 成功抽取并解析缩略图直链 (包含 data-original 兼容)', () async {
      final plugin = Plugin(
        api: '4',
        type: 'anime',
        name: 'mock_xpath_pic',
        version: '1.0',
        muliSources: false,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: 'https://example.com',
        searchURL: 'https://example.com/xpath-pic-test?wd=@keyword',
        searchList: '//div[@class="video-item"]',
        searchName: './/a[@class="title"]',
        searchResult: './/a[@class="title"]',
        searchPic: './/img[@class="poster"]',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
      );

      final resp = await plugin.queryBangumi('测试');
      expect(resp.data.length, equals(2));

      // 第一个从 src 提取
      expect(resp.data[0].name, equals('测试动漫一'));
      expect(resp.data[0].pic, equals('https://img.example.com/cover1.jpg'));

      // 第二个从 data-original 懒加载属性提取
      expect(resp.data[1].name, equals('测试动漫二'));
      expect(resp.data[1].pic, equals('https://img.example.com/cover2.webp'));
    });

    test('API 规则通过 picPath 成功抽取并规范化相对路径图片', () async {
      final plugin = Plugin(
        api: '9',
        type: 'anime',
        name: 'mock_api_pic',
        version: '1.0',
        muliSources: false,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: 'https://api-site.com',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        searchMode: 'api',
        searchApiConfig: {
          'request': {
            'method': 'GET',
            'url': 'https://api-site.com/api-pic-test',
          },
          'listPath': r'$.list[*]',
          'namePath': r'$.name',
          'sourcePath': r'$.id',
          'picPath': r'$.pic',
          'sourceTemplate': 'https://api-site.com/detail/@source.html',
        },
      );

      final resp = await plugin.queryBangumi('测试');
      expect(resp.data.length, equals(2));

      // 绝对路径
      expect(resp.data[0].name, equals('API动漫A'));
      expect(resp.data[0].pic, equals('https://api-img.example.com/a.jpg'));

      // 相对路径自动拼接 baseUrl
      expect(resp.data[1].name, equals('API动漫B'));
      expect(resp.data[1].pic, equals('https://api-site.com/uploads/b.png'));
    });
  });
}
