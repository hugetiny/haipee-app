import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_stream/aria2_stream_server.dart';

void main() {
  group('Aria2StreamServer HTTP 206 Streaming Tests', () {
    late Directory tempDir;
    late File testFile;
    const testFileSize = 1024 * 64; // 64KB
    late Aria2StreamServer server;
    late Dio dio;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aria2_stream_test_');
      testFile = File('${tempDir.path}/sample_video.mp4');

      // Create test file with patterned bytes
      final bytes = List<int>.generate(testFileSize, (i) => i % 256);
      await testFile.writeAsBytes(bytes, flush: true);

      server = Aria2StreamServer(
        filePath: testFile.path,
        totalLength: testFileSize,
      );

      dio = Dio(BaseOptions(
        validateStatus: (status) => true,
      ));
    });

    tearDown(() async {
      await server.stop();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Server starts on ephemeral loopback port and provides streamUrl', () async {
      final port = await server.start();
      expect(port, greaterThan(0));
      expect(server.isRunning, isTrue);
      expect(server.streamUrl, equals('http://127.0.0.1:$port/stream'));
    });

    test('HEAD request returns 200 OK with correct Accept-Ranges and Content-Length', () async {
      await server.start();
      final response = await dio.head(server.streamUrl);

      expect(response.statusCode, equals(200));
      expect(response.headers.value('accept-ranges'), equals('bytes'));
      expect(response.headers.value('content-length'), equals(testFileSize.toString()));
      expect(response.headers.value('content-type'), equals('video/mp4'));
    });

    test('Full GET request without Range returns complete file', () async {
      await server.start();
      final response = await dio.get<List<int>>(
        server.streamUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      expect(response.statusCode, equals(200));
      expect(response.data?.length, equals(testFileSize));
      expect(response.headers.value('content-length'), equals(testFileSize.toString()));
    });

    test('Range request for head bytes returns HTTP 206 Partial Content', () async {
      await server.start();
      const start = 0;
      const end = 1023; // 1024 bytes
      final response = await dio.get<List<int>>(
        server.streamUrl,
        options: Options(
          headers: {'range': 'bytes=$start-$end'},
          responseType: ResponseType.bytes,
        ),
      );

      expect(response.statusCode, equals(206));
      expect(response.headers.value('content-range'), equals('bytes 0-1023/$testFileSize'));
      expect(response.headers.value('content-length'), equals('1024'));
      expect(response.data?.length, equals(1024));
      expect(response.data?[0], equals(0));
      expect(response.data?[1], equals(1));
    });

    test('Open-ended Range request (bytes=1024-) returns bytes from offset to EOF', () async {
      await server.start();
      const start = 1024;
      final expectedLength = testFileSize - start;
      final response = await dio.get<List<int>>(
        server.streamUrl,
        options: Options(
          headers: {'range': 'bytes=$start-'},
          responseType: ResponseType.bytes,
        ),
      );

      expect(response.statusCode, equals(206));
      expect(
        response.headers.value('content-range'),
        equals('bytes $start-${testFileSize - 1}/$testFileSize'),
      );
      expect(response.headers.value('content-length'), equals(expectedLength.toString()));
      expect(response.data?.length, equals(expectedLength));
    });

    test('Suffix Range request (bytes=-512) returns tail bytes for container index probe', () async {
      await server.start();
      const suffix = 512;
      final expectedStart = testFileSize - suffix;
      final response = await dio.get<List<int>>(
        server.streamUrl,
        options: Options(
          headers: {'range': 'bytes=-$suffix'},
          responseType: ResponseType.bytes,
        ),
      );

      expect(response.statusCode, equals(206));
      expect(
        response.headers.value('content-range'),
        equals('bytes $expectedStart-${testFileSize - 1}/$testFileSize'),
      );
      expect(response.headers.value('content-length'), equals(suffix.toString()));
      expect(response.data?.length, equals(suffix));
    });

    test('Out of bounds Range request returns 416 Range Not Satisfiable', () async {
      await server.start();
      final response = await dio.get(
        server.streamUrl,
        options: Options(
          headers: {'range': 'bytes=${testFileSize + 1000}-${testFileSize + 2000}'},
        ),
      );

      expect(response.statusCode, equals(416));
      expect(response.headers.value('content-range'), equals('bytes */$testFileSize'));
    });

    test('Correct MIME type inference across multimedia file extensions', () {
      expect(Aria2StreamServer.getMimeType('video.mp4'), equals('video/mp4'));
      expect(Aria2StreamServer.getMimeType('movie.mkv'), equals('video/x-matroska'));
      expect(Aria2StreamServer.getMimeType('clip.webm'), equals('video/webm'));
      expect(Aria2StreamServer.getMimeType('audio.flac'), equals('audio/flac'));
      expect(Aria2StreamServer.getMimeType('song.mp3'), equals('audio/mpeg'));
      expect(Aria2StreamServer.getMimeType('track.wav'), equals('audio/wav'));
    });
  });
}
