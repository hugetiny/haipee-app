import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_stream/torrent_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TorrentTrackerService Tests', () {
    late TorrentTrackerService trackerService;

    setUp(() {
      trackerService = TorrentTrackerService.instance;
      trackerService.resetTrackersForTesting();
    });

    tearDown(() {
      trackerService.resetTrackersForTesting();
    });

    test('defaultTrackers contains essential HTTP, HTTPS and UDP trackers', () {
      final trackers = TorrentTrackerService.defaultTrackers;
      expect(trackers.isNotEmpty, isTrue);
      expect(trackers.length, greaterThanOrEqualTo(20));

      // 验证包含高连通性的 HTTP/HTTPS 穿透 Tracker
      expect(trackers.any((t) => t.startsWith('http://') || t.startsWith('https://')), isTrue);
      // 验证包含经典高效 UDP Tracker
      expect(trackers.any((t) => t.startsWith('udp://')), isTrue);
      // 验证包含动漫专享 Tracker
      expect(trackers.any((t) => t.contains('acgnx') || t.contains('lilithraws') || t.contains('renfei')), isTrue);
    });

    test('activeTrackers contains default list initially', () {
      final active = trackerService.activeTrackers;
      expect(active.length, greaterThanOrEqualTo(20));
      expect(active, contains('http://tracker.renfei.net:8080/announce'));
      expect(active, contains('udp://tracker.opentrackr.org:1337/announce'));
    });

    test('injectTrackers appends active trackers to plain magnet link', () {
      const magnet = 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';
      final enhanced = trackerService.injectTrackers(magnet);

      expect(enhanced.startsWith(magnet), isTrue);
      expect(enhanced, contains('&tr='));
      expect(enhanced, contains(Uri.encodeComponent('http://tracker.renfei.net:8080/announce')));
      expect(enhanced, contains(Uri.encodeComponent('udp://tracker.opentrackr.org:1337/announce')));
    });

    test('injectTrackers does not duplicate already present trackers', () {
      const existingTracker = 'http://tracker.renfei.net:8080/announce';
      final encoded = Uri.encodeComponent(existingTracker);
      final magnet = 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=$encoded';

      final enhanced = trackerService.injectTrackers(magnet);

      // 统计该 tracker 出现次数，严禁重复注入膨胀 URL
      final count = encoded.allMatches(enhanced).length;
      expect(count, equals(1));
    });

    test('setTrackersForTesting updates active trackers and injection list', () {
      trackerService.setTrackersForTesting([
        'http://custom-tracker.com/announce',
        'udp://custom-udp.org:6969/announce',
      ]);

      expect(trackerService.activeTrackers, [
        'http://custom-tracker.com/announce',
        'udp://custom-udp.org:6969/announce',
      ]);

      const magnet = 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';
      final enhanced = trackerService.injectTrackers(magnet);

      expect(enhanced, contains(Uri.encodeComponent('http://custom-tracker.com/announce')));
      expect(enhanced, contains(Uri.encodeComponent('udp://custom-udp.org:6969/announce')));
    });
  });
}
