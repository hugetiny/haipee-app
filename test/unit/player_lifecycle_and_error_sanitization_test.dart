import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/video/video_controller.dart';

void main() {
  group('1. Error Sanitizer Tests (HaipeeDialog.sanitizeUserMessage)', () {
    test('Cryptic exit code 1 or ERROR 1 is sanitized to helpful Chinese prompt', () {
      expect(
        HaipeeDialog.sanitizeUserMessage('1'),
        contains('错误码: 1'),
      );
      expect(
        HaipeeDialog.sanitizeUserMessage('ERROR 1'),
        contains('错误码: 1'),
      );
      expect(
        HaipeeDialog.sanitizeUserMessage('error: 1'),
        contains('错误码: 1'),
      );
      expect(
        HaipeeDialog.sanitizeUserMessage('exception: 1'),
        contains('错误码: 1'),
      );
    });

    test('Prefixed error messages with 1 are properly mapped', () {
      final sanitized = HaipeeDialog.sanitizeUserMessage('获取播放线路失败: 1');
      expect(sanitized, contains('获取播放线路失败:'));
      expect(sanitized, contains('底层接口返回代码 1，请尝试更换线路'));

      final sanitizedError = HaipeeDialog.sanitizeUserMessage('播放失败: ERROR 1');
      expect(sanitizedError, contains('播放失败:'));
      expect(sanitizedError, contains('底层接口返回代码 1，请尝试更换线路'));
    });

    test('null / undefined / object errors are sanitized', () {
      expect(
        HaipeeDialog.sanitizeUserMessage('null'),
        contains('发生未知异常，请稍后重试'),
      );
      expect(
        HaipeeDialog.sanitizeUserMessage('[object Object]'),
        contains('发生未知异常，请稍后重试'),
      );
    });

    test('Normal actionable messages remain intact', () {
      const normalMsg = '已成功添加到下载列表';
      expect(HaipeeDialog.sanitizeUserMessage(normalMsg), normalMsg);

      const warningMsg = '视频资源解析失败，请尝试更换其他视频来源';
      expect(HaipeeDialog.sanitizeUserMessage(warningMsg), warningMsg);
    });
  });

  group('2. Media URL Classification & Fast Extraction Tests', () {
    test('Direct media streams are recognized correctly', () {
      expect(
        VideoPageController.isDirectMediaUrl('https://example.com/live/stream.m3u8'),
        isTrue,
      );
      expect(
        VideoPageController.isDirectMediaUrl('https://example.com/video.mp4?token=abc'),
        isTrue,
      );
      expect(
        VideoPageController.isDirectMediaUrl('https://example.com/movie.mkv'),
        isTrue,
      );
      expect(
        VideoPageController.isDirectMediaUrl('bili://BV1xx411c7mD/12345'),
        isTrue,
      );
      expect(
        VideoPageController.isDirectMediaUrl('rtmp://live.example.com/app/stream'),
        isTrue,
      );
    });

    test('Non-media HTML player pages are identified and not treated as direct streams', () {
      // Real-world MacCMS and player pages that caused mpv format recognition errors
      expect(
        VideoPageController.isDirectMediaUrl('https://v.gsuus.com/play/dG692RQb'),
        isFalse,
      );
      expect(
        VideoPageController.isDirectMediaUrl('https://1080p.huyall.com/play/azpmjZqd'),
        isFalse,
      );
      expect(
        VideoPageController.isDirectMediaUrl('https://omofun.in/vod/play/2017837769/oad.html'),
        isFalse,
      );
    });

    test('Embedded stream regex extracts direct .m3u8 from DPlayer HTML landing pages', () {
      const htmlFromGsuus = '''
      <head>
          <script src="https://s2.pstatp.com/cdn/expire-1-M/hls.js/1.1.5/hls.min.js"></script>
          <script src="https://s2.pstatp.com/cdn/expire-1-M/dplayer/1.25.1/DPlayer.min.js"></script>
      </head>
      <body>
          <script>
              const vid = 'https://v.gsuus.com/play/dG692RQb/index.m3u8';
              const videoConfig = { url: vid, type: 'hls' };
          </script>
      </body>
      ''';

      final matches = VideoPageController.embeddedStreamRegex.allMatches(htmlFromGsuus);
      final extracted = matches
          .map((m) => m.group(0))
          .where((url) =>
              url != null &&
              !url.contains('.js') &&
              !url.contains('dplayer') &&
              !url.contains('hls.min'))
          .toList();

      expect(extracted, isNotEmpty);
      expect(extracted.first, 'https://v.gsuus.com/play/dG692RQb/index.m3u8');
      expect(VideoPageController.isDirectMediaUrl(extracted.first!), isTrue);
    });

    test('Embedded stream regex extracts direct stream from Huya player page', () {
      const htmlFromHuya = '''
      <script>
          const vid = 'https://hd.kuktxu.com/play/azpmjZqd/index.m3u8';
          function customHls(video) { const url = vid; }
      </script>
      ''';

      final matches = VideoPageController.embeddedStreamRegex.allMatches(htmlFromHuya);
      final extracted = matches
          .map((m) => m.group(0))
          .where((url) =>
              url != null &&
              !url.contains('.js') &&
              !url.contains('dplayer') &&
              !url.contains('hls.min'))
          .toList();

      expect(extracted, isNotEmpty);
      expect(extracted.first, 'https://hd.kuktxu.com/play/azpmjZqd/index.m3u8');
      expect(VideoPageController.isDirectMediaUrl(extracted.first!), isTrue);
    });
  });
}
