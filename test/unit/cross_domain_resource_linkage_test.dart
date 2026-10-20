import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/cardigann/cardigann_torznab.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';

void main() {
  group('Cross-Domain Resource Linkage & Torznab Category Mapping', () {
    TorrentCategory mapBangumiTypeToTorrentCategory(int bangumiType) {
      return switch (bangumiType) {
        1 => TorrentCategory.document, // 书籍 -> Torznab 3000 Books
        2 => TorrentCategory.video,    // 动画 -> Torznab 5070 Anime
        3 => TorrentCategory.audio,    // 音乐 -> Torznab 1000 Audio
        4 => TorrentCategory.game,     // 游戏 -> Torznab 4050 Games
        6 => TorrentCategory.video,    // 影视 -> Torznab 2000/5000 Movies/TV
        _ => TorrentCategory.all,
      };
    }

    test('Maps Bangumi type 1 (书籍) to TorrentCategory.document (Books 3000)', () {
      final cat = mapBangumiTypeToTorrentCategory(1);
      expect(cat, TorrentCategory.document);
      final torznabCats = TorznabCategories.fromTorrentCategory(cat);
      expect(torznabCats, contains(TorznabCategories.books));
    });

    test('Maps Bangumi type 2 (动画) to TorrentCategory.video (Anime 5070)', () {
      final cat = mapBangumiTypeToTorrentCategory(2);
      expect(cat, TorrentCategory.video);
      final torznabCats = TorznabCategories.fromTorrentCategory(cat);
      expect(torznabCats, contains(TorznabCategories.tvAnime));
    });

    test('Maps Bangumi type 3 (音乐) to TorrentCategory.audio (Audio 1000)', () {
      final cat = mapBangumiTypeToTorrentCategory(3);
      expect(cat, TorrentCategory.audio);
      final torznabCats = TorznabCategories.fromTorrentCategory(cat);
      expect(torznabCats, contains(TorznabCategories.audio));
    });

    test('Maps Bangumi type 4 (游戏) to TorrentCategory.game (PC/Games 4050)', () {
      final cat = mapBangumiTypeToTorrentCategory(4);
      expect(cat, TorrentCategory.game);
      final torznabCats = TorznabCategories.fromTorrentCategory(cat);
      expect(torznabCats, contains(TorznabCategories.pcGames));
    });

    test('Maps Bangumi type 6 (影视) to TorrentCategory.video (Movies/TV 2000/5000)', () {
      final cat = mapBangumiTypeToTorrentCategory(6);
      expect(cat, TorrentCategory.video);
      final torznabCats = TorznabCategories.fromTorrentCategory(cat);
      expect(torznabCats, contains(TorznabCategories.movies));
      expect(torznabCats, contains(TorznabCategories.tv));
    });

    test('BangumiItem properties provide proper search titles for universal search', () {
      final itemWithCn = BangumiItem(
        id: 12345,
        type: 4,
        name: 'The Legend of Zelda',
        nameCn: '塞尔达传说',
        summary: 'Action adventure game',
        airDate: '2017-03-03',
        airWeekday: 5,
        rank: 1,
        images: {},
        tags: [],
        alias: [],
        ratingScore: 9.8,
        votes: 1000,
        votesCount: [],
        info: '',
      );

      final searchKeyword = itemWithCn.nameCn.isNotEmpty ? itemWithCn.nameCn : itemWithCn.name;
      expect(searchKeyword, '塞尔达传说');

      final itemWithoutCn = BangumiItem(
        id: 67890,
        type: 1,
        name: 'Chainsaw Man Manga',
        nameCn: '',
        summary: 'Manga series',
        airDate: '2018-12-03',
        airWeekday: 1,
        rank: 10,
        images: {},
        tags: [],
        alias: [],
        ratingScore: 8.5,
        votes: 500,
        votesCount: [],
        info: '',
      );

      final fallbackKeyword = itemWithoutCn.nameCn.isNotEmpty ? itemWithoutCn.nameCn : itemWithoutCn.name;
      expect(fallbackKeyword, 'Chainsaw Man Manga');
    });
  });
}
