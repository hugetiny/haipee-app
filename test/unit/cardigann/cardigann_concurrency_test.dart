import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';

class MockDelayedSource implements TorrentSource {
  @override
  final String name;
  final Duration delay;
  final List<TorrentItem> results;
  final bool shouldThrow;

  MockDelayedSource({
    required this.name,
    required this.delay,
    required this.results,
    this.shouldThrow = false,
  });

  @override
  TorrentSourceType get type => TorrentSourceType.indexerPlugin;

  @override
  bool get enabled => true;

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    await Future.delayed(delay);
    if (shouldThrow) {
      throw Exception('Simulated network failure on $name');
    }
    return results;
  }
}

void main() {
  group('Progressive Streaming Concurrency Tests', () {
    test('searchStream progressively yields results as sources finish', () async {
      final fastSource = MockDelayedSource(
        name: 'FastSource',
        delay: const Duration(milliseconds: 30),
        results: [
          const TorrentItem(
            title: 'Fast Release 1',
            magnetUrl: 'magnet:?xt=urn:btih:FAST1',
            source: TorrentSourceType.indexerPlugin,
            seeders: 50,
          ),
        ],
      );

      final mediumSource = MockDelayedSource(
        name: 'MediumSource',
        delay: const Duration(milliseconds: 100),
        results: [
          const TorrentItem(
            title: 'Medium Release 1',
            magnetUrl: 'magnet:?xt=urn:btih:MED1',
            source: TorrentSourceType.indexerPlugin,
            seeders: 100,
          ),
        ],
      );

      final failingSource = MockDelayedSource(
        name: 'FailingSource',
        delay: const Duration(milliseconds: 50),
        results: [],
        shouldThrow: true,
      );

      final service = TorrentSearchService(
        sources: [fastSource, failingSource, mediumSource],
      );

      final emissions = <List<TorrentItem>>[];
      await for (final items in service.searchStream('test', concurrency: 8)) {
        emissions.add(items);
      }

      // Must have emitted at least 2 progressive updates (fast first, medium second)
      expect(emissions.length, greaterThanOrEqualTo(2));

      // First emission should contain fast release
      expect(emissions.first.any((i) => i.title == 'Fast Release 1'), isTrue);

      // Final emission should contain both fast and medium releases, despite failingSource throwing
      final finalItems = emissions.last;
      expect(finalItems.length, equals(2));
      expect(finalItems.any((i) => i.title == 'Fast Release 1'), isTrue);
      expect(finalItems.any((i) => i.title == 'Medium Release 1'), isTrue);

      // Seeders sorting: Medium Release (100 seeders) should be first, Fast Release (50 seeders) second
      expect(finalItems[0].title, equals('Medium Release 1'));
      expect(finalItems[1].title, equals('Fast Release 1'));
    });

    test('searchStream handles single-source timeout gracefully', () async {
      final hangingSource = MockDelayedSource(
        name: 'HangingSource',
        delay: const Duration(milliseconds: 500),
        results: [
          const TorrentItem(
            title: 'Hanging Release',
            magnetUrl: 'magnet:?xt=urn:btih:HANG1',
            source: TorrentSourceType.indexerPlugin,
          ),
        ],
      );

      final quickSource = MockDelayedSource(
        name: 'QuickSource',
        delay: const Duration(milliseconds: 20),
        results: [
          const TorrentItem(
            title: 'Quick Release',
            magnetUrl: 'magnet:?xt=urn:btih:QUICK1',
            source: TorrentSourceType.indexerPlugin,
            seeders: 10,
          ),
        ],
      );

      final service = TorrentSearchService(
        sources: [quickSource, hangingSource],
      );

      // Set timeout to 80ms, so hanging source times out without stalling the stream
      final results = await service.searchAll(
        'test',
        sortMode: TorrentSortMode.seeders,
        sourceTimeout: const Duration(milliseconds: 80),
      );

      expect(results.length, equals(1));
      expect(results.first.title, equals('Quick Release'));
    });
  });
}
