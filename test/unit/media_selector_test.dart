import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/playback/media_selector.dart';

void main() {
  group('Animeko MediaSelector Episode Alignment Tests', () {
    test('Normal Season 1 standard numbering maps 1:1', () {
      final res = MediaSelector.resolve(
        rawIndex: 1,
        identifier: '第01话',
        roadName: '极速线路',
      );

      expect(res.bangumiEpisode, equals(1));
      expect(res.danmakuEpisode, equals(1));
      expect(res.season, equals(1));
      expect(res.isSpecial, isFalse);
      expect(res.displayLabel, equals('第 01 集'));
    });

    test('Season 2 with relative scraper numbering and Bangumi total offset', () {
      // Scraper labeled as Season 2 Ep 1 ("第01集"), Bangumi has 12 episodes in Season 1
      final res = MediaSelector.resolve(
        rawIndex: 1,
        identifier: '第01集',
        roadName: '第二季',
        bangumiTotalEpisodes: 12,
      );

      expect(res.season, equals(2));
      expect(res.seasonOffset, equals(12));
      expect(res.bangumiEpisode, equals(13)); // S2 Ep 1 corresponds to Bangumi Ep 13
      expect(res.danmakuEpisode, equals(1)); // DanDanPlay matches relative episode 1
      expect(res.displayLabel, equals('S2 E01'));
    });

    test('Season 2 with cumulative scraper numbering ("第13话") avoids double offset', () {
      // Scraper already labeled Season 2 Ep 1 as cumulative "第13话"
      final res = MediaSelector.resolve(
        rawIndex: 1,
        identifier: '第13话',
        roadName: 'Season 2',
        bangumiTotalEpisodes: 12,
      );

      expect(res.season, equals(2));
      expect(res.seasonOffset, equals(12));
      expect(res.bangumiEpisode, equals(13)); // Uses 13 directly, NOT 13 + 12 = 25
      expect(res.danmakuEpisode, equals(1)); // DanDanPlay relative episode: 13 - 12 = 1
      expect(res.displayLabel, equals('S2 E13'));
    });

    test('Special episode / .5 Recap episode detection and floating float parsing', () {
      final res = MediaSelector.resolve(
        rawIndex: 6,
        identifier: '第05.5话 总集篇',
        roadName: '正片',
      );

      expect(res.isSpecial, isTrue);
      expect(res.episodeFloat, equals(5.5));
      expect(res.bangumiEpisode, equals(5));
      expect(res.displayLabel, contains('5.5'));
      expect(res.displayLabel, contains('总集篇'));
    });

    test('SP / OVA / OAD special episode classification', () {
      final spRes = MediaSelector.resolve(
        rawIndex: 1,
        identifier: 'SP01 温泉篇',
        roadName: '特典',
      );
      expect(spRes.isSpecial, isTrue);

      final ovaRes = MediaSelector.resolve(
        rawIndex: 1,
        identifier: 'OVA 泳装篇',
        roadName: '线路1',
      );
      expect(ovaRes.isSpecial, isTrue);
    });

    test('Season extraction from multiple formats', () {
      expect(MediaSelector.extractSeasonNumber('第二季'), equals(2));
      expect(MediaSelector.extractSeasonNumber('第3季'), equals(3));
      expect(MediaSelector.extractSeasonNumber('Season 4'), equals(4));
      expect(MediaSelector.extractSeasonNumber('S02'), equals(2));
      expect(MediaSelector.extractSeasonNumber('正片'), isNull);
    });

    test('Episode number extraction from various strings', () {
      expect(MediaSelector.extractEpisodeNumber('第08话'), equals(8));
      expect(MediaSelector.extractEpisodeNumber('E12'), equals(12));
      expect(MediaSelector.extractEpisodeNumber('EP05'), equals(5));
      expect(MediaSelector.extractEpisodeNumber('S02E03'), equals(3));
      expect(MediaSelector.extractEpisodeNumber('24'), equals(24));
    });
  });
}
