import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_stream/torrent_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TorrentTrackerService BEP 15 DoH UDP Rewrite Tests', () {
    late TorrentTrackerService trackerService;

    setUp(() {
      trackerService = TorrentTrackerService.instance;
      TorrentTrackerService.clearDohCache();
    });

    tearDown(() {
      TorrentTrackerService.clearDohCache();
      trackerService.resetTrackersForTesting();
    });

    test('resolveHostWithDoh returns direct IPv4 unchanged without network', () async {
      final ip = await trackerService.resolveHostWithDoh('185.125.190.29');
      expect(ip, equals('185.125.190.29'));
    });

    test('resolveHostWithDoh hits seeded DoH memory cache', () async {
      TorrentTrackerService.seedDohCache('tracker.opentrackr.org', '185.125.190.29');

      final resolved = await trackerService.resolveHostWithDoh('tracker.opentrackr.org');
      expect(resolved, equals('185.125.190.29'));
    });

    test('rewriteTrackerUrlWithDoh rewrites UDP tracker with resolved IP', () async {
      TorrentTrackerService.seedDohCache('tracker.opentrackr.org', '185.125.190.29');

      const original = 'udp://tracker.opentrackr.org:1337/announce';
      final rewritten = await trackerService.rewriteTrackerUrlWithDoh(original);

      expect(rewritten, equals('udp://185.125.190.29:1337/announce'));
    });

    test('rewriteTrackerUrlWithDoh leaves non-UDP trackers untouched', () async {
      const httpTracker = 'http://tracker.renfei.net:8080/announce';
      final rewritten = await trackerService.rewriteTrackerUrlWithDoh(httpTracker);

      expect(rewritten, equals(httpTracker));

      const httpsTracker = 'https://tracker.tamersunion.org:443/announce';
      final rewrittenHttps = await trackerService.rewriteTrackerUrlWithDoh(httpsTracker);

      expect(rewrittenHttps, equals(httpsTracker));
    });

    test('rewriteTrackersWithDoh rewrites list in batch', () async {
      TorrentTrackerService.seedDohCache('tracker.opentrackr.org', '185.125.190.29');
      TorrentTrackerService.seedDohCache('open.demonii.com', '104.21.32.1');

      final list = [
        'udp://tracker.opentrackr.org:1337/announce',
        'http://tracker.renfei.net:8080/announce',
        'udp://open.demonii.com:1337/announce',
      ];

      final rewrittenList = await trackerService.rewriteTrackersWithDoh(list);

      expect(rewrittenList[0], equals('udp://185.125.190.29:1337/announce'));
      expect(rewrittenList[1], equals('http://tracker.renfei.net:8080/announce'));
      expect(rewrittenList[2], equals('udp://104.21.32.1:1337/announce'));
    });

    test('rewriteMagnetWithDoh replaces UDP tracker in magnet link with resolved IP', () async {
      TorrentTrackerService.seedDohCache('tracker.opentrackr.org', '185.125.190.29');

      trackerService.setTrackersForTesting([
        'udp://tracker.opentrackr.org:1337/announce',
      ]);

      const baseMagnet = 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';
      final rewrittenMagnet = await trackerService.rewriteMagnetWithDoh(baseMagnet);

      expect(rewrittenMagnet, contains(Uri.encodeComponent('udp://185.125.190.29:1337/announce')));
      expect(rewrittenMagnet.contains('tracker.opentrackr.org'), isFalse);
    });
  });
}
