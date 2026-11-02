import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';

void main() {
  group('全网资源搜索多维度多方向即时排序测试 (Multi-field & Bi-directional Sorting)', () {
    final itemA = const TorrentItem(
      title: 'Attack on Titan S01 1080p',
      magnetUrl: 'magnet:?xt=urn:btih:AAA111',
      fileSize: '1.2 GB',
      sizeBytes: 1200000000,
      publishDate: '2026-10-10 10:00:00',
      rawPublishDate: '2026-10-10T10:00:00.000Z',
      source: TorrentSourceType.mikan,
      indexerName: 'Mikan',
      seeders: 50,
      leechers: 10,
      episode: '01',
    );

    final itemB = const TorrentItem(
      title: 'Bleach TYBW Part 3 4K',
      magnetUrl: 'magnet:?xt=urn:btih:BBB222',
      fileSize: '4.5 GB',
      sizeBytes: 4500000000,
      publishDate: '2026-10-14 12:00:00',
      rawPublishDate: '2026-10-14T12:00:00.000Z',
      source: TorrentSourceType.nyaa,
      indexerName: 'Nyaa',
      seeders: 150,
      leechers: 80,
      episode: '02',
    );

    final itemC = const TorrentItem(
      title: 'Cyberpunk Edgerunners Complete',
      magnetUrl: 'magnet:?xt=urn:btih:CCC333',
      fileSize: '800 MB',
      sizeBytes: 800000000,
      publishDate: '2026-10-01 08:00:00',
      rawPublishDate: '2026-10-01T08:00:00.000Z',
      source: TorrentSourceType.indexerPlugin,
      indexerName: '1337x',
      seeders: 5,
      leechers: 2,
    );

    final testItems = [itemA, itemB, itemC];

    test('做种数排序 (Seeders): 降序与升序', () {
      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.seeders,
        ascending: false,
      );
      expect(desc.map((i) => i.seeders).toList(), [150, 50, 5]);
      expect(desc.first.title, contains('Bleach'));

      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.seeders,
        ascending: true,
      );
      expect(asc.map((i) => i.seeders).toList(), [5, 50, 150]);
      expect(asc.first.title, contains('Cyberpunk'));
    });

    test('下载数排序 (Leechers): 降序与升序', () {
      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.leechers,
        ascending: false,
      );
      expect(desc.map((i) => i.leechers).toList(), [80, 10, 2]);

      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.leechers,
        ascending: true,
      );
      expect(asc.map((i) => i.leechers).toList(), [2, 10, 80]);
    });

    test('文件大小排序 (Size): 从大到小 (降序) 与 从小到大 (升序)', () {
      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.size,
        ascending: false,
      );
      expect(desc.map((i) => i.sizeBytes).toList(), [
        4500000000,
        1200000000,
        800000000,
      ]);

      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.size,
        ascending: true,
      );
      expect(asc.map((i) => i.sizeBytes).toList(), [
        800000000,
        1200000000,
        4500000000,
      ]);
    });

    test('文件大小排序特殊处理: 依换算后字节排序，未知大小在升序降序下均沉底，显示人类易读单位', () {
      final itemKb = const TorrentItem(
        title: 'Small Patch',
        magnetUrl: 'magnet:?xt=urn:btih:KB1',
        fileSize: '500 KB',
        source: TorrentSourceType.mikan,
      );
      final itemMb = const TorrentItem(
        title: 'Single Episode',
        magnetUrl: 'magnet:?xt=urn:btih:MB1',
        fileSize: '950 MB',
        source: TorrentSourceType.mikan,
      );
      final itemGb = const TorrentItem(
        title: 'Movie 1080P',
        magnetUrl: 'magnet:?xt=urn:btih:GB1',
        fileSize: '', // 未直接给 fileSize，但有 sizeBytes
        sizeBytes: 1500000000, // 约 1.40 GB
        source: TorrentSourceType.nyaa,
      );
      final itemTb = const TorrentItem(
        title: 'Animation Discography 4K',
        magnetUrl: 'magnet:?xt=urn:btih:TB1',
        fileSize: '2.1 TB',
        source: TorrentSourceType.indexerPlugin,
      );
      final itemUnknownSize = const TorrentItem(
        title: 'Mysterious Torrent Without Size',
        magnetUrl: 'magnet:?xt=urn:btih:UNKNOWN1',
        fileSize: '',
        sizeBytes: 0,
        source: TorrentSourceType.mikan,
      );

      final mixedSizes = [
        itemUnknownSize,
        itemMb,
        itemTb,
        itemKb,
        itemGb,
      ];

      // 人类易读单位显示验证
      expect(itemKb.displayFileSize, '500 KB');
      expect(itemMb.displayFileSize, '950 MB');
      expect(itemGb.displayFileSize, contains('GB'));
      expect(itemTb.displayFileSize, '2.1 TB');
      expect(itemUnknownSize.displayFileSize, '-');

      // 降序排序 (从大到小): TB > GB > MB > KB > 未知大小(沉底)
      final desc = TorrentSearchService.sortItems(
        mixedSizes,
        TorrentSortMode.size,
        ascending: false,
      );
      expect(desc.map((i) => i.title).toList(), [
        'Animation Discography 4K',
        'Movie 1080P',
        'Single Episode',
        'Small Patch',
        'Mysterious Torrent Without Size',
      ]);
      expect(desc.last.title, 'Mysterious Torrent Without Size');

      // 升序排序 (从小到大): KB < MB < GB < TB < 未知大小(沉底，绝不上浮到最顶)
      final asc = TorrentSearchService.sortItems(
        mixedSizes,
        TorrentSortMode.size,
        ascending: true,
      );
      expect(asc.map((i) => i.title).toList(), [
        'Small Patch',
        'Single Episode',
        'Movie 1080P',
        'Animation Discography 4K',
        'Mysterious Torrent Without Size',
      ]);
      expect(asc.last.title, 'Mysterious Torrent Without Size');
    });

    test('发布时间排序特殊处理: 没有日期的项目在升序降序下均绝不浮到上面 (严格沉底)', () {
      final itemNew = const TorrentItem(
        title: 'Just Released Today',
        magnetUrl: 'magnet:?xt=urn:btih:NEW1',
        publishDate: '2026-10-15 03:00:00',
        source: TorrentSourceType.mikan,
      );
      final itemMid = const TorrentItem(
        title: 'Released Last Week',
        magnetUrl: 'magnet:?xt=urn:btih:MID1',
        rawPublishDate: 'Fri, 20 Oct 2023 15:30:00 -0000',
        source: TorrentSourceType.nyaa,
      );
      final itemOld = const TorrentItem(
        title: 'Classic 2020 Release',
        magnetUrl: 'magnet:?xt=urn:btih:OLD1',
        publishDate: '2020-01-01',
        source: TorrentSourceType.mikan,
      );
      final itemNoDate1 = const TorrentItem(
        title: 'Torrent With No Date 1',
        magnetUrl: 'magnet:?xt=urn:btih:NODATE1',
        publishDate: '',
        rawPublishDate: null,
        source: TorrentSourceType.indexerPlugin,
      );
      final itemNoDate2 = const TorrentItem(
        title: 'Torrent With Empty Date 2',
        magnetUrl: 'magnet:?xt=urn:btih:NODATE2',
        publishDate: '-',
        rawPublishDate: '',
        source: TorrentSourceType.indexerPlugin,
      );

      final mixedDates = [
        itemNoDate1,
        itemMid,
        itemNoDate2,
        itemOld,
        itemNew,
      ];

      // 降序排序 (最新优先): New > Mid > Old > 无日期项目沉底在最后
      final desc = TorrentSearchService.sortItems(
        mixedDates,
        TorrentSortMode.age,
        ascending: false,
      );
      expect(desc.take(3).map((i) => i.title).toList(), [
        'Just Released Today',
        'Released Last Week',
        'Classic 2020 Release',
      ]);
      expect(desc.skip(3).map((i) => i.title), containsAll([
        'Torrent With No Date 1',
        'Torrent With Empty Date 2',
      ]));

      // 升序排序 (最早发布优先): Old < Mid < New < 无日期项目沉底在最后 (绝不上浮到最顶)
      final asc = TorrentSearchService.sortItems(
        mixedDates,
        TorrentSortMode.age,
        ascending: true,
      );
      expect(asc.take(3).map((i) => i.title).toList(), [
        'Classic 2020 Release',
        'Released Last Week',
        'Just Released Today',
      ]);
      expect(asc.skip(3).map((i) => i.title), containsAll([
        'Torrent With No Date 1',
        'Torrent With Empty Date 2',
      ]));
    });

    test('发布时间排序 (Age): 最新发布 (降序) 与 最早发布 (升序)', () {
      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.age,
        ascending: false,
      );
      expect(desc.first.title, contains('Bleach')); // 2026-10-14
      expect(desc.last.title, contains('Cyberpunk')); // 2026-10-01

      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.age,
        ascending: true,
      );
      expect(asc.first.title, contains('Cyberpunk')); // 2026-10-01
      expect(asc.last.title, contains('Bleach')); // 2026-10-14
    });

    test('资源名称排序 (Title): A-Z (升序) 与 Z-A (降序)', () {
      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.title,
        ascending: true,
      );
      expect(asc[0].title, contains('Attack'));
      expect(asc[1].title, contains('Bleach'));
      expect(asc[2].title, contains('Cyberpunk'));

      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.title,
        ascending: false,
      );
      expect(desc[0].title, contains('Cyberpunk'));
      expect(desc[1].title, contains('Bleach'));
      expect(desc[2].title, contains('Attack'));
    });

    test('站点来源排序 (Source): A-Z (升序) 与 Z-A (降序)', () {
      final asc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.source,
        ascending: true,
      );
      expect(asc[0].effectiveSourceName, '1337x');
      expect(asc[1].effectiveSourceName, 'Mikan');
      expect(asc[2].effectiveSourceName, 'Nyaa');

      final desc = TorrentSearchService.sortItems(
        testItems,
        TorrentSortMode.source,
        ascending: false,
      );
      expect(desc[0].effectiveSourceName, 'Nyaa');
      expect(desc[1].effectiveSourceName, 'Mikan');
      expect(desc[2].effectiveSourceName, '1337x');
    });

    test('TorrentSearchState.filteredItems 即时响应排序配置', () {
      final state = TorrentSearchState(
        items: testItems,
        sortMode: TorrentSortMode.seeders,
        sortAscending: false,
      );

      // 默认做种数降序
      expect(state.filteredItems.first.title, contains('Bleach'));

      // 切换为做种数升序
      final ascState = state.copyWith(sortAscending: true);
      expect(ascState.filteredItems.first.title, contains('Cyberpunk'));

      // 切换为名称排序 A-Z
      final titleState = state.copyWith(
        sortMode: TorrentSortMode.title,
        sortAscending: true,
      );
      expect(titleState.filteredItems.first.title, contains('Attack'));

      // 切换为名称排序 Z-A
      final titleDescState = state.copyWith(
        sortMode: TorrentSortMode.title,
        sortAscending: false,
      );
      expect(titleDescState.filteredItems.first.title, contains('Cyberpunk'));
    });
  });
}
