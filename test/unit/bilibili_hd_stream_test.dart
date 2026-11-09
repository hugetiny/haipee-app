import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bilibili HD Stream & Quality Helper Tests', () {
    test('1. BiliQualityHelper correctly maps quality IDs to labels', () {
      expect(BiliQualityHelper.getLabel(120), equals('4K 超清'));
      expect(BiliQualityHelper.getLabel(116), equals('1080P 60帧'));
      expect(BiliQualityHelper.getLabel(80), equals('1080P 高清'));
      expect(BiliQualityHelper.getLabel(64), equals('720P 高清'));
      expect(BiliQualityHelper.getLabel(32), equals('480P 清晰'));
      expect(BiliQualityHelper.getLabel(16), equals('360P 流畅'));
    });

    test('2. getPlayUrl parses multiple DASH qualities and selects requested quality', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.uri.path.contains('/playurl')) {
          return ResponseBody.fromString(
            '''
{
  "code": 0,
  "data": {
    "dash": {
      "duration": 300,
      "video": [
        {"id": 116, "baseUrl": "https://cn-bj.bilivideo.com/video_1080p60.m4s"},
        {"id": 80, "baseUrl": "https://cn-bj.bilivideo.com/video_1080p.m4s"},
        {"id": 64, "baseUrl": "https://cn-bj.bilivideo.com/video_720p.m4s"},
        {"id": 16, "baseUrl": "https://cn-bj.bilivideo.com/video_360p.m4s"}
      ],
      "audio": [
        {"id": 30280, "baseUrl": "https://cn-bj.bilivideo.com/audio_192k.m4s"}
      ]
    }
  }
}
''',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else if (options.uri.path.contains('/nav')) {
          return ResponseBody.fromString(
            '{"code":0,"data":{"wbi_img":{"img_url":"https://i0.hdslb.com/bfs/wbi/img1.png","sub_url":"https://i0.hdslb.com/bfs/wbi/sub1.png"}}}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      // Default: picks highest quality available (116 = 1080P 60帧)
      final playUrl = await BilibiliService.getPlayUrl(
        'BV1xx411c7mD',
        1001,
        client: mockDio,
        sessData: 'mock_vip_sess',
      );

      expect(playUrl, isNotNull);
      expect(playUrl!.quality, equals(116));
      expect(playUrl.qualityLabel, equals('1080P 60帧'));
      expect(playUrl.videoUrl, contains('video_1080p60.m4s'));
      expect(playUrl.audioUrl, contains('audio_192k.m4s'));
      expect(playUrl.format, equals('dash'));
      expect(playUrl.availableQualities.length, equals(6));
      expect(playUrl.availableQualities[0].id, equals(116));
      expect(playUrl.availableQualities[1].id, equals(112));
      expect(playUrl.availableQualities[2].id, equals(80));
      expect(playUrl.availableQualities[3].id, equals(64));
      expect(playUrl.availableQualities[4].id, equals(32));
      expect(playUrl.availableQualities[5].id, equals(16));

      // Specific targetQuality: picks 80 (1080P 高清)
      final playUrl1080 = await BilibiliService.getPlayUrl(
        'BV1xx411c7mD',
        1001,
        client: mockDio,
        sessData: 'mock_vip_sess',
        targetQuality: 80,
      );

      expect(playUrl1080, isNotNull);
      expect(playUrl1080!.quality, equals(80));
      expect(playUrl1080.qualityLabel, equals('1080P 高清'));
      expect(playUrl1080.videoUrl, contains('video_1080p.m4s'));
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
