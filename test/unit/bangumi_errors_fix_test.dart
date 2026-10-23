import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';

void main() {
  group('Bangumi Error Resilience and Dummy Item Guard Tests', () {
    test('1. BangumiItem.dummy correctly marks isDummy and isDummyItem as true', () {
      final dummy = BangumiItem.dummy(title: '暴风影视 - 测试剧集');
      expect(dummy.isDummy, isTrue);
      expect(dummy.isDummyItem, isTrue);
      expect(dummy.id, isPositive);
      expect(dummy.info, equals('__DUMMY__'));
    });

    test('2. Normal BangumiItem constructed with real data is not dummy', () {
      final item = BangumiItem(
        id: 302286,
        type: 2,
        name: 'Chainsaw Man',
        nameCn: '电锯人',
        summary: '少年电次与恶魔波奇塔...',
        airDate: '2022-10-11',
        airWeekday: 2,
        rank: 100,
        images: {},
        tags: [],
        alias: [],
        ratingScore: 8.2,
        votes: 15000,
        votesCount: [],
        info: '话数: 12',
      );
      expect(item.isDummy, isFalse);
      expect(item.isDummyItem, isFalse);
      expect(item.totalEpisodes, equals(12));
    });

    test('3. BangumiHTTP.getBangumiEpisodeByID guards non-positive IDs without throwing', () async {
      final epZero = await BangumiHTTP.getBangumiEpisodeByID(0, 1);
      expect(epZero.id, equals(0));

      final epNeg = await BangumiHTTP.getBangumiEpisodeByID(-100, 1);
      expect(epNeg.id, equals(0));
    });

    test('4. BangumiHTTP.getBangumiCommentsByEpisodeID guards non-positive IDs without throwing type mismatch', () async {
      // Previously, ID 0 was sent to next.bgm.tv/p1/episodes/0/comments, returning HTTP 400
      // Request().get converted the error to a Map<String, String>, which failed when cast to List<dynamic>.
      final resZero = await BangumiHTTP.getBangumiCommentsByEpisodeID(0);
      expect(resZero.commentList, isEmpty);

      final resNeg = await BangumiHTTP.getBangumiCommentsByEpisodeID(-1);
      expect(resNeg.commentList, isEmpty);
    });

    test('5. BangumiHTTP secondary methods gracefully guard ID <= 0', () async {
      final comments = await BangumiHTTP.getBangumiCommentsByID(0);
      expect(comments.commentList, isEmpty);

      final staff = await BangumiHTTP.getBangumiStaffByID(0);
      expect(staff.data, isEmpty);

      final characters = await BangumiHTTP.getCharatersByBangumiID(0);
      expect(characters.charactersList, isEmpty);

      final characterInfo = await BangumiHTTP.getCharacterByCharacterID(0);
      expect(characterInfo.id, equals(0));
    });
  });
}
