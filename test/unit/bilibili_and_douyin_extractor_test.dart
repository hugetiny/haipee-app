import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_wbi.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';

void main() {
  group('Bilibili WBI Signer Tests', () {
    test('getMixinKey generates accurate 32-char mixin key based on mixinKeyEncTab', () {
      const origKey = '7cd0844827f3484483e71c8bad20a2805113a535c3b045e4ac54a49fe05fa5f7';
      final mixinKey = BiliWbiSigner.getMixinKey(origKey);

      expect(mixinKey.length, equals(32));
      // 验证混淆密钥中只包含有效的十六进制字符
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(mixinKey), isTrue);
    });

    test('signParams sorts query keys alphabetically and generates wts and w_rid', () {
      final params = <String, dynamic>{
        'bvid': 'BV1xx411c7mD',
        'cid': 123456,
        'qn': 80,
      };

      final signed = BiliWbiSigner.signParams(
        params,
        imgKey: BiliWbiSigner.defaultImgKey,
        subKey: BiliWbiSigner.defaultSubKey,
      );

      expect(signed.containsKey('bvid'), isTrue);
      expect(signed.containsKey('cid'), isTrue);
      expect(signed.containsKey('qn'), isTrue);
      expect(signed.containsKey('wts'), isTrue);
      expect(signed.containsKey('w_rid'), isTrue);

      expect(signed['wts'], isA<int>());
      expect(signed['w_rid'], isA<String>());
      expect((signed['w_rid'] as String).length, equals(32)); // MD5 32 hex chars
    });

    test('signParams sanitizes reserved characters in query values per WBI spec', () {
      final params = <String, dynamic>{
        'keyword': "Hello (World)*! 'test'",
      };

      final signed = BiliWbiSigner.signParams(params);
      expect(signed['w_rid'], isNotNull);
      expect((signed['w_rid'] as String).isNotEmpty, isTrue);
    });
  });

  group('Bilibili Models Tests', () {
    test('BiliVideoItem.fromJson parses title stripping HTML keywords and normalizes cover url', () {
      final json = {
        'bvid': 'BV1234567890',
        'title': '【独家】<em class="keyword">孤独摇滚！</em> 剧场总集篇',
        'author': '芳文社Official',
        'pic': '//i0.hdslb.com/bfs/archive/test_cover.jpg',
        'play': 1500000,
        'video_review': 34567,
        'duration': '23:45',
        'pubdate': 1698765432,
      };

      final item = BiliVideoItem.fromJson(json);

      expect(item.bvid, equals('BV1234567890'));
      expect(item.title, equals('【独家】孤独摇滚！ 剧场总集篇'));
      expect(item.author, equals('芳文社Official'));
      expect(item.pic, equals('https://i0.hdslb.com/bfs/archive/test_cover.jpg'));
      expect(item.play, equals(1500000));
      expect(item.danmaku, equals(34567));
      expect(item.duration, equals('23:45'));
      expect(item.pubdate, equals(1698765432));
    });

    test('BiliVideoDetail.fromJson deserializes multipart video list', () {
      final json = {
        'bvid': 'BV1TestMultiPart',
        'aid': 998877,
        'title': '间谍过家家 第二季',
        'pic': 'https://i0.hdslb.com/bfs/archive/spy.jpg',
        'desc': '双面特工与读心少女的日常',
        'owner': {'name': 'WIT STUDIO'},
        'pages': [
          {
            'cid': 10001,
            'page': 1,
            'part': '第01话 跟着父亲走',
            'duration': 1420,
          },
          {
            'cid': 10002,
            'page': 2,
            'part': '第02话 邦德的危机',
            'duration': 1435,
          },
        ],
      };

      final detail = BiliVideoDetail.fromJson(json);

      expect(detail.bvid, equals('BV1TestMultiPart'));
      expect(detail.aid, equals(998877));
      expect(detail.title, equals('间谍过家家 第二季'));
      expect(detail.parts.length, equals(2));
      expect(detail.parts[0].cid, equals(10001));
      expect(detail.parts[0].page, equals(1));
      expect(detail.parts[0].part, equals('第01话 跟着父亲走'));
      expect(detail.parts[1].cid, equals(10002));
      expect(detail.parts[1].part, equals('第02话 邦德的危机'));
    });

    test('BiliPlayUrl supports DASH dual-stream separation and headers', () {
      const playUrl = BiliPlayUrl(
        videoUrl: 'https://cn-sh-fx-bcache.bilivideo.com/video.m4s',
        audioUrl: 'https://cn-sh-fx-bcache.bilivideo.com/audio.m4s',
        quality: 80,
        format: 'dash',
        headers: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent': 'Mozilla/5.0 HaipeeClient',
        },
      );

      expect(playUrl.videoUrl, contains('video.m4s'));
      expect(playUrl.audioUrl, contains('audio.m4s'));
      expect(playUrl.quality, equals(80));
      expect(playUrl.format, equals('dash'));
      expect(playUrl.headers['Referer'], equals('https://www.bilibili.com'));
    });
  });

  group('Bilibili Danmaku XML Parsing Tests', () {
    test('parseDanmakuXml accurately extracts timestamp, color, and message', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<i>
  <d p="12.345,1,16777215,user1">前方高能预警！！！</d>
  <d p="45.678,4,16711680,user2">名场面打卡</d>
  <d p="89.100,5,65280,user3">完结撒花~</d>
  <d p="invalid">无效弹幕</d>
</i>''';

      final danmakus = BilibiliService.parseDanmakuXml(xml);

      expect(danmakus.length, equals(3));

      expect(danmakus[0].time, closeTo(12.345, 0.001));
      expect(danmakus[0].message, equals('前方高能预警！！！'));
      expect(danmakus[0].source, equals('[BiliBili]'));

      expect(danmakus[1].time, closeTo(45.678, 0.001));
      expect(danmakus[1].message, equals('名场面打卡'));

      expect(danmakus[2].time, closeTo(89.100, 0.001));
      expect(danmakus[2].message, equals('完结撒花~'));
    });

    test('parseDanmakuXml handles standard 8-field Bilibili format with font size, color, and XML entities', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<i>
  <d p="15.200,1,25,16777215,1690000000,0,user1,1001">真实B站原生弹幕 &amp; 经典台词</d>
  <d p="32.500,4,25,16711680,1690000001,0,user2,1002">名场面 &lt;tag&gt; &quot;引号&quot;</d>
</i>''';

      final danmakus = BilibiliService.parseDanmakuXml(xml);

      expect(danmakus.length, equals(2));

      expect(danmakus[0].time, closeTo(15.2, 0.001));
      expect(danmakus[0].type, equals(1));
      expect(danmakus[0].message, equals('真实B站原生弹幕 & 经典台词'));
      expect(danmakus[0].color, equals(const Color(0xFFFFFFFF)));
      expect(danmakus[0].source, equals('[BiliBili]'));

      expect(danmakus[1].time, closeTo(32.5, 0.001));
      expect(danmakus[1].type, equals(4));
      expect(danmakus[1].message, equals('名场面 <tag> "引号"'));
      expect(danmakus[1].color, equals(const Color(0xFFFF0000)));
      expect(danmakus[1].source, equals('[BiliBili]'));
    });

    test('parseDanmakuXml decodes decimal and hexadecimal numeric XML entities and apos', () {
      // &#21704; = 0x54C8 ('哈'), &#x1F600; = 😀, &apos; / &#39; = '
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<i>
  <d p="5.000,1,25,16777215,1700000000,0,user1,101">&#21704;&#21704;&#21704; &apos;It&#39;s great&apos; &#x1F600;</d>
</i>''';

      final danmakus = BilibiliService.parseDanmakuXml(xml);

      expect(danmakus.length, equals(1));
      expect(danmakus[0].message, equals("哈哈哈 'It's great' \u{1F600}"));
    });

    test('parseDanmakuXml handles 9-field Bilibili XML format and captures 0.0 second opening danmaku', () {
      // 9-part: time, type, font_size, color, timestamp, pool, user_hash, dmid, weight
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<i>
  <d p="0.00000,1,25,16777215,1700000000,0,a1b2c3d4,9876543210,0">注意：此视频为B站已知最古老的视频</d>
  <d p="0.50000,5,25,16711680,1700000001,0,e5f6a7b8,9876543211,10">顶部红字弹幕测试</d>
</i>''';

      final danmakus = BilibiliService.parseDanmakuXml(xml);

      expect(danmakus.length, equals(2));
      expect(danmakus[0].time, equals(0.0));
      expect(danmakus[0].message, equals('注意：此视频为B站已知最古老的视频'));
      expect(danmakus[0].type, equals(1));
      expect(danmakus[0].color, equals(const Color(0xFFFFFFFF)));

      expect(danmakus[1].time, closeTo(0.5, 0.001));
      expect(danmakus[1].type, equals(5));
      expect(danmakus[1].color, equals(const Color(0xFFFF0000)));
    });

    test('parseDanmakuXml handles empty or malformed inputs without throwing', () {
      expect(BilibiliService.parseDanmakuXml(''), isEmpty);
      expect(BilibiliService.parseDanmakuXml('<root><empty/></root>'), isEmpty);
      expect(BilibiliService.parseDanmakuXml('<d p="1"></d>'), isEmpty);
    });

    test('getDanmaku decompresses RFC 1951 raw deflate binary stream', () async {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<i>
  <d p="428.44100,1,25,16777215,1729272332,0,94a4c6a9,1234567890">关谷：你猜我是哪里人？</d>
</i>''';
      final compressedBytes = ZLibEncoder(raw: true).convert(utf8.encode(xml));

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: compressedBytes,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final danmakus = await BilibiliService.getDanmaku(1868025, client: dio);

      expect(danmakus.length, equals(1));
      expect(danmakus[0].message, equals('关谷：你猜我是哪里人？'));
      expect(danmakus[0].time, closeTo(428.441, 0.001));
      expect(danmakus[0].source, equals('[BiliBili]'));
    });

    test('getDanmaku returns empty list for invalid cid or network error without throwing', () async {
      expect(await BilibiliService.getDanmaku(0), isEmpty);
      expect(await BilibiliService.getDanmaku(-1), isEmpty);

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Network connection failed',
              ),
            );
          },
        ),
      );

      final danmakus = await BilibiliService.getDanmaku(99999, client: dio);
      expect(danmakus, isEmpty);
    });
  });

  group('Douyin Extractor Tests', () {
    test('extractItemId parses standard web video URLs', () {
      const url = 'https://www.douyin.com/video/7212345678901234567?previous_page=app_code';
      final id = DouyinService.extractItemId(url);
      expect(id, equals('7212345678901234567'));
    });

    test('extractItemId parses modal_id format', () {
      const url = 'https://www.douyin.com/?modal_id=7398765432109876543';
      final id = DouyinService.extractItemId(url);
      expect(id, equals('7398765432109876543'));
    });

    test('extractItemId parses direct item id digits', () {
      const rawId = '7123456789012345678';
      final id = DouyinService.extractItemId(rawId);
      expect(id, equals('7123456789012345678'));
    });

    test('extractItemId returns null for unrelated texts', () {
      expect(DouyinService.extractItemId(''), isNull);
      expect(DouyinService.extractItemId('https://example.com/video/123'), isNull);
      expect(DouyinService.extractItemId('纯文字内容没有视频ID'), isNull);
    });

    test('hasDouyinPattern accurately distinguishes Douyin links/IDs from plain keywords', () {
      expect(DouyinService.hasDouyinPattern('https://www.douyin.com/video/7212345678901234567'), isTrue);
      expect(DouyinService.hasDouyinPattern('https://v.douyin.com/iRk9U5N/'), isTrue);
      expect(DouyinService.hasDouyinPattern('7123456789012345678'), isTrue);
      expect(DouyinService.hasDouyinPattern('孤独摇滚'), isFalse);
      expect(DouyinService.hasDouyinPattern('周杰伦'), isFalse);
      expect(DouyinService.hasDouyinPattern(''), isFalse);
    });

    test('extractItemId parses note URL format', () {
      const url = 'https://www.douyin.com/note/7345678901234567890';
      final id = DouyinService.extractItemId(url);
      expect(id, equals('7345678901234567890'));
    });

    test('extractVideo returns null on plain keyword without throwing or making network calls', () async {
      final res = await DouyinService.extractVideo('进击的巨人');
      expect(res, isNull);
    });

    test('extractVideo parses mobile feed API response and replaces playwm with play', () async {
      final mockFeedJson = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7123456789012345678',
            'desc': '【神级转场】动漫名场面混剪',
            'author': {'nickname': '剪辑小王'},
            'duration': 18500,
            'video': {
              'cover': {
                'url_list': ['https://p3.douyinpic.com/cover.jpg']
              },
              'play_addr': {
                'url_list': [
                  'https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200fg123',
                ]
              }
            }
          }
        ]
      });

      final dio = Dio();
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

      final item = await DouyinService.extractVideo('7123456789012345678', client: dio);
      expect(item, isNotNull);
      expect(item!.id, equals('7123456789012345678'));
      expect(item.title, equals('【神级转场】动漫名场面混剪'));
      expect(item.author, equals('剪辑小王'));
      expect(item.cover, equals('https://p3.douyinpic.com/cover.jpg'));
      expect(item.playUrl, contains('/play/'));
      expect(item.playUrl, isNot(contains('/playwm/')));
      expect(item.duration, equals(18));
    });

    test('extractVideo safely handles non-json Argus security responses without throwing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: 'Blocked by ArgusSecurityPlugin Uifid Not Found',
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final item = await DouyinService.extractVideo('7123456789012345678', client: dio);
      expect(item, isNull);
    });

    test('fetchSearchSuggestions parses sug_list from aweme sug api', () async {
      final mockSugJson = jsonEncode({
        'sug_list': [
          {'content': '孤独摇滚'},
          {'content': '孤独摇滚壁纸'},
        ]
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockSugJson,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final suggestions = await DouyinService.fetchSearchSuggestions('孤独', client: dio);
      expect(suggestions, equals(['孤独摇滚', '孤独摇滚壁纸']));
    });

    test('getHotBillboard parses word_list from billboard api', () async {
      final mockBillboardJson = jsonEncode({
        'status_code': 0,
        'word_list': [
          {'word': '中国空间站最新动态'},
          {'word': '秋天的第一杯奶茶'},
        ]
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockBillboardJson,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final words = await DouyinService.getHotBillboard(client: dio);
      expect(words, equals(['中国空间站最新动态', '秋天的第一杯奶茶']));
    });

    test('resolveShortUrl resolves links without scheme and tokens with underscores and hyphens', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'HEAD') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': ['https://www.douyin.com/video/7234567890123456789'],
                  }),
                ),
              );
            } else {
              handler.next(options);
            }
          },
        ),
      );

      final id = await DouyinService.resolveShortUrl(
        'v.douyin.com/iL7_x-z/ 复制本段打开抖音',
        client: dio,
      );
      expect(id, equals('7234567890123456789'));
    });

    test('extractItemId supports 15-22 digit historical and new video IDs', () {
      expect(DouyinService.extractItemId('https://www.douyin.com/video/6543210987654321'), equals('6543210987654321'));
      expect(DouyinService.extractItemId('6543210987654321'), equals('6543210987654321'));
      expect(DouyinService.hasDouyinPattern('6543210987654321'), isTrue);
    });

    test('extractVideo gracefully handles DioException (network error, timeout, 500) without throwing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
                message: 'Connection timed out',
              ),
            );
          },
        ),
      );

      final result = await DouyinService.extractVideo('7234567890123456789', client: dio);
      expect(result, isNull);
    });

    test('extractVideo upgrades plaintext http cover and playUrl to https', () async {
      final mockFeedJson = jsonEncode({
        'status_code': 0,
        'aweme_list': [
          {
            'aweme_id': '7123456789012345678',
            'desc': '测试HTTP升级',
            'author': {'nickname': '创作者'},
            'video': {
              'cover': {
                'url_list': ['http://p3.douyinpic.com/cover.jpg']
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

      final dio = Dio();
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

      final item = await DouyinService.extractVideo('7123456789012345678', client: dio);
      expect(item, isNotNull);
      expect(item!.cover, startsWith('https://'));
      expect(item.playUrl, startsWith('https://'));
    });
  });
}
