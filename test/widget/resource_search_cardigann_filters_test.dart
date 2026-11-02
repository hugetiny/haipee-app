import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/pages/resource/resource_search_content.dart';
import 'package:haipee/utils/storage.dart';

class _MockPopularController extends PopularController {
  @override
  PopularState build() => PopularState(
        trendList: [
          BangumiItem.fromJson({
            'id': 1,
            'name': 'dummy',
            'type': 2,
            'name_cn': '测试番剧',
            'summary': '测试',
            'date': '2024-01-01',
            'images': {
              'large': '',
              'common': '',
              'medium': '',
              'small': '',
              'grid': '',
            },
          }),
        ],
      );
}

void main() {
  late Directory tempDir;

  final publicItem = TorrentItem(
    title: '[ANi] 芙莉莲 公开源 - 01 [1080P][MP4]',
    magnetUrl: 'magnet:?xt=urn:btih:1111111111111111111111111111111111111111',
    fileSize: '1.2 GB',
    sizeBytes: 1200000000,
    seeders: 100,
    leechers: 10,
    publishDate: '1小时前',
    source: TorrentSourceType.mikan,
    indexerName: 'Mikan',
    trackerType: 'public',
    customCategory: TorrentCategory.video,
  );

  final semiPrivateItem = TorrentItem(
    title: '[Sub] 芙莉莲 半私有源 - 02 [1080P][MKV]',
    magnetUrl: 'magnet:?xt=urn:btih:2222222222222222222222222222222222222222',
    fileSize: '2.5 GB',
    sizeBytes: 2500000000,
    seeders: 50,
    leechers: 5,
    publishDate: '2小时前',
    source: TorrentSourceType.dmhy,
    indexerName: 'DMHY',
    trackerType: 'semi-private',
    customCategory: TorrentCategory.video,
  );

  final privateItem = TorrentItem(
    title: '[PT] 芙莉莲 私有源 - 03 [2160P][FLAC]',
    magnetUrl: 'magnet:?xt=urn:btih:3333333333333333333333333333333333333333',
    fileSize: '8.0 GB',
    sizeBytes: 8000000000,
    seeders: 300,
    leechers: 2,
    publishDate: '3小时前',
    source: TorrentSourceType.cardigann,
    indexerName: 'M-Team',
    trackerType: 'private',
    customCategory: TorrentCategory.video,
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('haipee_cardigann_filter_test_');
    Hive.init(tempDir.path);
    await GStorage.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('验证全网搜索呈现严格遵循 Cardigann 规范的 4 行筛选项（cat/type/indexer/sort），无任何非 Cardigann 冗余项',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        popularProvider.overrideWith(_MockPopularController.new),
      ],
    );

    // 初始状态注入三条不同 trackerType 的数据
    final notifier = container.read(torrentSearchProvider.notifier);
    notifier.state = TorrentSearchState(
      isLoading: false,
      keyword: '芙莉莲',
      items: [publicItem, semiPrivateItem, privateItem],
      categoryCounts: {TorrentCategory.video: 3},
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 1. 验证 4 行核心 Cardigann 规范参数标题存在
    expect(find.text('分类 (cat)'), findsOneWidget);
    expect(find.text('性质 (type)'), findsOneWidget);
    expect(find.text('站点 (indexer)'), findsOneWidget);
    expect(find.text('排序 (sort)'), findsOneWidget);

    // 2. 验证非 Cardigann 规范的不靠谱/历史残留筛选项已被彻底清除
    expect(find.textContaining('CAM'), findsNothing);
    expect(find.textContaining('枪版'), findsNothing);
    expect(find.textContaining('画质:'), findsNothing);

    // 3. 验证站点性质 (type) 筛选
    expect(find.byKey(const ValueKey('tracker_type_chip_all')), findsOneWidget);
    expect(find.byKey(const ValueKey('tracker_type_chip_public')), findsOneWidget);
    expect(find.byKey(const ValueKey('tracker_type_chip_semi-private')), findsOneWidget);
    expect(find.byKey(const ValueKey('tracker_type_chip_private')), findsOneWidget);

    // 点击筛选“私有 PT”
    await tester.tap(find.byKey(const ValueKey('tracker_type_chip_private')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 验证当前过滤后只剩下私有 PT 资源
    final stateAfterType = container.read(torrentSearchProvider);
    expect(stateAfterType.filteredItems.length, equals(1));
    expect(stateAfterType.filteredItems.first.title, contains('私有源'));

    // 点击筛选“公开 Public”
    await tester.tap(find.byKey(const ValueKey('tracker_type_chip_public')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final stateAfterPublic = container.read(torrentSearchProvider);
    expect(stateAfterPublic.filteredItems.length, equals(1));
    expect(stateAfterPublic.filteredItems.first.title, contains('公开源'));

    // 切回“全部性质”
    await tester.tap(find.byKey(const ValueKey('tracker_type_chip_all')));
    await tester.pumpAndSettle();
    expect(container.read(torrentSearchProvider).filteredItems.length, equals(3));

    // 4. 验证站点 (indexer) 筛选
    expect(find.byKey(const ValueKey('indexer_chip_Mikan')), findsOneWidget);
    expect(find.byKey(const ValueKey('indexer_chip_DMHY')), findsOneWidget);
    expect(find.byKey(const ValueKey('indexer_chip_M-Team')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('indexer_chip_DMHY')));
    await tester.pumpAndSettle();
    expect(container.read(torrentSearchProvider).filteredItems.length, equals(1));
    expect(container.read(torrentSearchProvider).filteredItems.first.effectiveSourceName, equals('DMHY'));

    // 5. 验证在小屏移动端视口 (375x667) 下 4 行筛选项零溢出
    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
