import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/debrid/debrid_provider.dart';
import 'package:kazumi/modules/debrid/debrid_service.dart';
import 'package:kazumi/modules/debrid/providers/real_debrid_provider.dart';
import 'package:kazumi/modules/debrid/providers/torbox_provider.dart';
import 'package:kazumi/modules/debrid/providers/pikpak_provider.dart';

class MockDebridProvider implements DebridProvider {
  final bool hasInstantCache;
  final String? resolvedUrl;

  MockDebridProvider({this.hasInstantCache = true, this.resolvedUrl = 'https://cdn.example.com/video.mp4'});

  @override
  String get name => 'MockDebrid';

  @override
  String get identifier => 'mock';

  @override
  bool get isConfigured => true;

  @override
  Future<bool> checkInstantAvailability(String infoHash) async => hasInstantCache;

  @override
  Future<String?> resolveStreamUrl(String magnetOrInfoHash, {int targetEpisode = 1}) async => resolvedUrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Debrid Provider Units', () {
    test('RealDebridProvider extracts 40-char infoHash from magnet or plain string', () {
      const hex = '0123456789abcdef0123456789abcdef01234567';
      expect(RealDebridProvider.extractInfoHash(hex), equals(hex));

      const magnet = 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Test';
      expect(RealDebridProvider.extractInfoHash(magnet), equals(hex));
    });

    test('RealDebridProvider isConfigured is true when apiKey provided', () {
      final configured = RealDebridProvider(apiKey: 'secret_token_123');
      expect(configured.isConfigured, isTrue);

      final unconfigured = RealDebridProvider(apiKey: '');
      expect(unconfigured.isConfigured, isFalse);
    });

    test('RealDebridProvider mock availability check hits cache on rd list', () async {
      const hash = '0123456789abcdef0123456789abcdef01234567';
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.contains('/torrents/instantAvailability/$hash')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    hash: {
                      'rd': [
                        {'1': {'filename': 'sample.mkv', 'filesize': 1024000}}
                      ]
                    }
                  },
                ),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Not found',
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final provider = RealDebridProvider(dio: dio, apiKey: 'test_token');
      final available = await provider.checkInstantAvailability(hash);
      expect(available, isTrue);
    });

    test('RealDebridProvider resolveStreamUrl executes unrestrict pipeline', () async {
      const hash = '0123456789abcdef0123456789abcdef01234567';
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.contains('/torrents/addMagnet')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 201,
                data: {'id': 'torr_abc_123'},
              ));
            }
            if (options.uri.path.contains('/torrents/selectFiles/torr_abc_123')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 204,
                data: null,
              ));
            }
            if (options.uri.path.contains('/torrents/info/torr_abc_123')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'links': ['https://real-debrid.com/d/LINK123']
                },
              ));
            }
            if (options.uri.path.contains('/unrestrict/link')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'download': 'https://download.real-debrid.com/stream/sample.mkv'},
              ));
            }
            return handler.next(options);
          },
        ),
      );

      final provider = RealDebridProvider(dio: dio, apiKey: 'test_token');
      final streamUrl = await provider.resolveStreamUrl(hash);
      expect(streamUrl, equals('https://download.real-debrid.com/stream/sample.mkv'));
    });

    test('TorBoxProvider & PikPakProvider basic properties', () {
      final torbox = TorBoxProvider(apiKey: 'key');
      expect(torbox.name, equals('TorBox'));
      expect(torbox.identifier, equals('torbox'));
      expect(torbox.isConfigured, isTrue);

      final pikpak = PikPakProvider(apiKey: 'key');
      expect(pikpak.name, equals('PikPak'));
      expect(pikpak.identifier, equals('pikpak'));
      expect(pikpak.isConfigured, isTrue);
    });
  });

  group('DebridService Hub Tests', () {
    late DebridService service;

    setUp(() {
      service = DebridService.instance;
    });

    tearDown(() {
      service.setProviderForTesting(null);
    });

    test('availableProviders returns 3 major providers', () {
      final list = service.availableProviders;
      expect(list.length, equals(3));
      expect(list.any((p) => p is RealDebridProvider), isTrue);
      expect(list.any((p) => p is TorBoxProvider), isTrue);
      expect(list.any((p) => p is PikPakProvider), isTrue);
    });

    test('tryResolveDebridStream returns direct CDN url on cache hit', () async {
      service.setProviderForTesting(MockDebridProvider(
        hasInstantCache: true,
        resolvedUrl: 'https://fast-cdn.example.com/anime.mp4',
      ));

      final url = await service.tryResolveDebridStream('0123456789abcdef0123456789abcdef01234567');
      expect(url, equals('https://fast-cdn.example.com/anime.mp4'));
    });

    test('tryResolveDebridStream returns null on cache miss for fallback', () async {
      service.setProviderForTesting(MockDebridProvider(
        hasInstantCache: false,
      ));

      final url = await service.tryResolveDebridStream('0123456789abcdef0123456789abcdef01234567');
      expect(url, isNull);
    });
  });
}
