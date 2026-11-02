import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haipee/modules/torrent_stream/torrserver_client.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_service.dart';

void main() {
  group('TorrServer Models & Client Tests', () {
    test('TorrServerFile model parses JSON correctly', () {
      final json = {
        'id': 1,
        'path': 'Frieren/Season 01/Frieren_EP01.mkv',
        'length': 1024 * 1024 * 500, // 500MB
      };

      final file = TorrServerFile.fromJson(json);
      expect(file.id, equals(1));
      expect(file.name, equals('Frieren_EP01.mkv'));
      expect(file.length, equals(1024 * 1024 * 500));
    });

    test('TorrServerTorrent model computes peer count and preload progress', () {
      final json = {
        'hash': 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c',
        'title': 'Big Buck Bunny',
        'stat': 3,
        'stat_string': 'Torrent working',
        'total_peers': 25,
        'active_peers': 12,
        'connected_seeders': 8,
        'download_speed': 1024 * 1024 * 3, // 3 MB/s
        'preloaded_bytes': 1024 * 1024 * 10, // 10MB
        'preload_size': 1024 * 1024 * 20, // 20MB
        'files': [
          {
            'id': 1,
            'path': 'bbb_sunflower_1080p_30fps_normal.mp4',
            'length': 276107484,
          }
        ]
      };

      final torrent = TorrServerTorrent.fromJson(json);
      expect(torrent.hash, equals('dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c'));
      expect(torrent.effectivePeerCount, equals(25));
      expect(torrent.downloadSpeed, equals(1024 * 1024 * 3));
      expect(torrent.preloadProgress, equals(0.5));
      expect(torrent.files.length, equals(1));
      expect(torrent.files.first.name, equals('bbb_sunflower_1080p_30fps_normal.mp4'));
    });

    test('TorrServerClient buildStreamUrl encodes query and file paths properly with hash priority', () {
      final client = TorrServerClient(baseUrl: 'http://127.0.0.1:8090');
      const magnet = 'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Test';

      final url = client.buildStreamUrl(
        link: magnet,
        hash: 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c',
        fileIndex: 2,
        fileName: 'Episode 01 [1080p].mp4',
      );

      expect(url, startsWith('http://127.0.0.1:8090/stream/'));
      expect(url, contains('Episode%2001%20%5B1080p%5D.mp4'));
      expect(url, contains('link=dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c'));
      expect(url, contains('index=2'));
      expect(url, endsWith('&play'));
    });

    test('TorrServerClient triggerPreload fires preload request correctly', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, startsWith('/stream/'));
        expect(request.url.queryParameters['link'], equals('mock-hash-123'));
        expect(request.url.queryParameters['index'], equals('1'));
        expect(request.url.queryParameters.containsKey('preload'), isTrue);
        return http.Response('', 200);
      });

      final client = TorrServerClient(
        baseUrl: 'http://127.0.0.1:8090',
        httpClient: mockHttp,
      );

      await expectLater(
        client.triggerPreload(
          hash: 'mock-hash-123',
          fileIndex: 1,
          fileName: 'test.mkv',
        ),
        completes,
      );
    });

    test('TorrServerClient addTorrent posts correct payload and parses response', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/torrents'));
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], equals('add'));
        expect(body['title'], equals('Sample Title'));

        return http.Response(
          jsonEncode({
            'hash': 'mock-hash-123',
            'title': 'Sample Title',
            'stat': 0,
            'stat_string': 'Torrent added',
            'total_peers': 15,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = TorrServerClient(
        baseUrl: 'http://127.0.0.1:8090',
        httpClient: mockHttp,
      );

      final torrent = await client.addTorrent(
        link: 'magnet:?xt=urn:btih:mock-hash-123',
        title: 'Sample Title',
      );

      expect(torrent.hash, equals('mock-hash-123'));
      expect(torrent.effectivePeerCount, equals(15));
    });

    test('TorrentStreamEngine enum includes torrserver', () {
      expect(TorrentStreamEngine.values, contains(TorrentStreamEngine.torrserver));
    });
  });
}
