import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:haipee/bean/widget/image/rule_cover_image.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/pages/online/online_video_search_provider.dart';
import 'package:haipee/plugins/rule_cover_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. RuleCoverExtractor - 启发式多属性 DOM 与协议保护测试', () {
    test('优先提取 data-original 并跳过 AGE 等站点的 src 占位图', () {
      const htmlStr = '''
      <ul>
        <li class="card">
          <a href="/detail/20000001">
            <img class="video_thumbs lazyload"
                 src="https://p1.bdxiguaimg.com/origin/137860000e3053288f11f"
                 data-original="https://cdn.aqdstatic.com:966/age/covers/20000001.jpg"
                 alt="海贼王" />
          </a>
          <h5><a href="/detail/20000001">海贼王</a></h5>
        </li>
      </ul>
      ''';
      final doc = parse(htmlStr).documentElement!;
      final liNode = doc.queryXPath('//li').node!;
      final cover = RuleCoverExtractor.extractFromXPathNode(
        liNode,
        baseUrl: 'https://www.agedm.io/',
      );
      expect(
        cover,
        equals('https://cdn.aqdstatic.com:966/age/covers/20000001.jpg'),
      );
    });

    test('支持提取海螺/MacCMS 网页模板中非 img 标签 (<a data-original>) 的封面', () {
      const htmlStr = '''
      <div class="module-items">
        <div class="module-item">
          <a class="myui-vodlist__thumb lazyload"
             href="/voddetail/123.html"
             data-original="/upload/vod/2026/onepiece.webp"></a>
          <div class="title"><a href="/voddetail/123.html">航海王</a></div>
        </div>
      </div>
      ''';
      final doc = parse(htmlStr).documentElement!;
      final itemNode = doc.queryXPath('//div[@class="module-item"]').node!;
      final cover = RuleCoverExtractor.extractFromXPathNode(
        itemNode,
        baseUrl: 'https://www.7sefun.top/',
      );
      expect(
        cover,
        equals('https://www.7sefun.top/upload/vod/2026/onepiece.webp'),
      );
    });

    test('支持提取内联 CSS background-image: url(...) 背景图封面', () {
      const htmlStr = '''
      <div class="search-card">
        <div class="thumb" style="background-image: url('//img.example.com/posters/op.jpg');"></div>
        <a class="name" href="/play/1">海贼王</a>
      </div>
      ''';
      final doc = parse(htmlStr).documentElement!;
      final cardNode = doc.queryXPath('//div[@class="search-card"]').node!;
      final cover = RuleCoverExtractor.extractFromXPathNode(
        cardNode,
        baseUrl: 'https://example.com',
      );
      expect(cover, equals('https://img.example.com/posters/op.jpg'));
    });

    test('当 searchList 指向卡片内层文字容器时，安全回溯单卡片父节点提取封面', () {
      const htmlStr = '''
      <div class="vod-card">
        <div class="vod-thumb"><img data-src="https://img.example.com/cover1.jpg" src="/img/loading.gif"/></div>
        <div class="vod-info"><h3><a href="/v/1">凡人修仙传</a></h3></div>
      </div>
      ''';
      final doc = parse(htmlStr).documentElement!;
      final innerNode = doc.queryXPath('//div[@class="vod-info"]').node!;
      final cover = RuleCoverExtractor.extractFromXPathNode(
        innerNode,
        baseUrl: 'https://example.com',
      );
      expect(cover, equals('https://img.example.com/cover1.jpg'));
    });

    test('MacCMS / TVBox JSON 提取：保持原生 http:// 协议不被强转为 https://', () {
      final maccmsItem = {
        'vod_id': 21681,
        'vod_name': '海贼王',
        'vod_pic': r'http:\/\/fffgood.com\/upload\/vod\/20221211-1\/cdbb8c.jpg',
      };
      final cover = RuleCoverExtractor.extractFromJsonMap(
        maccmsItem,
        picKey: r'$.vod_pic',
        baseUrl: 'https://cj.ffzyapi.com',
      );
      expect(
        cover,
        equals('http://fffgood.com/upload/vod/20221211-1/cdbb8c.jpg'),
      );
    });
  });

  group('2. ResilientCoverHttpClient - HTTPS->HTTP 自动降级与防劫持测试', () {
    test('当 https:// 触发 TLS 握手失败时，自动降级至 http:// 并成功获取图片', () async {
      final requestedUrls = <String>[];
      final mockInner = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.scheme == 'https') {
          throw const HandshakeException('SSL_ERROR_SYSCALL on port 443');
        }
        return http.Response.bytes(
          List<int>.filled(128, 0xFF),
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final client = ResilientCoverHttpClient(innerClient: mockInner);
      final req = http.Request(
        'GET',
        Uri.parse('https://fffgood.com/upload/vod/cover.jpg'),
      );
      final resp = await client.send(req);

      expect(resp.statusCode, equals(200));
      expect(
        requestedUrls,
        equals([
          'https://fffgood.com/upload/vod/cover.jpg',
          'http://fffgood.com/upload/vod/cover.jpg',
        ]),
      );
      client.close();
    });

    test('当域名被运营商劫持返回 200 OK text/html 时，拦截并返回 404 防止图片解码崩溃', () async {
      final mockInner = MockClient((request) async {
        return http.Response(
          '<html><body>ISP Hijack</body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final client = ResilientCoverHttpClient(innerClient: mockInner);
      final req = http.Request(
        'GET',
        Uri.parse('http://p.lztutu.com/upload/vod/hijacked.jpg'),
      );
      final resp = await client.send(req);

      expect(resp.statusCode, equals(404));
      client.close();
    });
  });

  group('3. Cross-Source Cover Synergy - 跨源同名封面协同与 RuleCoverImage 渲染测试', () {
    test('同名影视条目跨规则协同解析备用封面', () {
      const state = OnlineVideoSearchState(
        keyword: '海贼王',
        synergyCovers: {
          '海贼王': 'https://img.bmddm.com/pic/onepiece.webp',
        },
      );
      const itemWithoutCover = BiliVideoItem(
        bvid: 'web_7sefun_1',
        title: '【高清】海贼王 (更新至1122集)',
        author: '7sefun',
        pic: '',
      );
      expect(
        state.resolveFallbackCover(itemWithoutCover),
        equals('https://img.bmddm.com/pic/onepiece.webp'),
      );
    });

    testWidgets('RuleCoverImage 在窄卡片与桌面尺寸下零溢出渲染 M3 海报兜底', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 240,
              child: RuleCoverImage(
                imageUrl: '',
                title: '海贼王 One Piece',
                ruleTag: 'MacCMS · 非凡影视',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('rule_cover_m3_fallback')), findsOneWidget);
      expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
    });
  });
}
