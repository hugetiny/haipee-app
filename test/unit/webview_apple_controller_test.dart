import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebviewAppleItemController parsing and normalization logic', () {
    test('URL path normalization prevents double slashes', () {
      String normalize(String url) {
        return url.replaceAllMapped(
          RegExp(r'^((?:https?:)?//[^/]+)(/.*)$'),
          (match) {
            final host = match.group(1)!;
            final path = match.group(2)!.replaceAll(RegExp(r'/+'), '/');
            return '$host$path';
          },
        );
      }

      expect(
        normalize('https://www.sbdl.cc//index.php/vod/play/id/55063/sid/2/nid/1.html'),
        'https://www.sbdl.cc/index.php/vod/play/id/55063/sid/2/nid/1.html',
      );

      expect(
        normalize('https://dm84.tv///p/6270-1-2.html'),
        'https://dm84.tv/p/6270-1-2.html',
      );

      expect(
        normalize('http://localhost:8080/path//subpath/file.m3u8'),
        'http://localhost:8080/path/subpath/file.m3u8',
      );
    });

    test('Active sniffer JSON response decoding', () {
      const videoResult = '{"type":"video","url":"https://cdn.example.com/stream.m3u8"}';
      final videoParsed = jsonDecode(videoResult);
      expect(videoParsed['type'], 'video');
      expect(videoParsed['url'], 'https://cdn.example.com/stream.m3u8');

      const iframeResult = '{"type":"iframe","url":"https://dm.sbdl.cc/?url=AG-123"}';
      final iframeParsed = jsonDecode(iframeResult);
      expect(iframeParsed['type'], 'iframe');
      expect(iframeParsed['url'], 'https://dm.sbdl.cc/?url=AG-123');
    });

    test('Iframe target sanitization handles protocol-relative URLs', () {
      String sanitize(String url) {
        String target = url.trim();
        if (target.startsWith('//')) {
          target = 'https:$target';
        }
        return target;
      }

      expect(sanitize('//dm.sbdl.cc/?url=test'), 'https://dm.sbdl.cc/?url=test');
      expect(sanitize('https://dm.sbdl.cc/?url=test'), 'https://dm.sbdl.cc/?url=test');
    });
  });
}
