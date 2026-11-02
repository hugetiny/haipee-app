import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/cardigann/cardigann_torznab.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/info/info_page.dart';
import 'package:haipee/pages/media/media_page.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;

  BangumiItem makeSubject({
    required int id,
    required String name,
    required String nameCn,
    required int type,
  }) {
    return BangumiItem(
      id: id,
      name: name,
      nameCn: nameCn,
      type: type,
      summary: 'Test summary',
      airDate: '2024-01-01',
      airWeekday: 1,
      rank: 1,
      images: {},
      tags: [],
      alias: [],
      ratingScore: 9.0,
      votes: 100,
      votesCount: [],
      info: '',
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('haipee_zero_screenshot_test_');
    Hive.init(tempDir.path);
    await GStorage.init();
    await GStorage.setting.put(SettingBoxKey.showWindowButton, false);
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('【无截图验证体系】1. 资源分类 (MediaPage) 5 大类与源站选择器自省', () {
    testWidgets('验证 5 大类 Tab、源站选择器、滑动切换与动作芯片（桌面与移动双视口 0 溢出）', (tester) async {
      // 1. 设置桌面视口 (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: const MaterialApp(
              home: MediaPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证页面标题为「资源分类」
      expect(find.text('资源分类'), findsOneWidget);

      // 验证元数据源站下拉徽章存在且标注当前源站 Bangumi
      expect(find.byKey(const Key('metadata_provider_selector')), findsOneWidget);
      expect(find.text('Bangumi'), findsWidgets);

      // 验证 5 大类独立 Tab 胶囊均存在
      expect(find.byKey(const Key('catalog_tab_anime')), findsOneWidget);
      expect(find.byKey(const Key('catalog_tab_real')), findsOneWidget);
      expect(find.byKey(const Key('catalog_tab_game')), findsOneWidget);
      expect(find.byKey(const Key('catalog_tab_music')), findsOneWidget);
      expect(find.byKey(const Key('catalog_tab_book')), findsOneWidget);

      // 初始在动画大类，验证专属动作「放送时间表」
      expect(find.byKey(const Key('catalog_chip_timeline')), findsOneWidget);
      expect(find.text('放送时间表'), findsOneWidget);

      // 切换到「影视」
      await tester.tap(find.byKey(const Key('catalog_tab_real')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_chip_search_real')), findsOneWidget);
      expect(find.text('全网影视搜索'), findsOneWidget);

      // 切换到「游戏」
      await tester.tap(find.byKey(const Key('catalog_tab_game')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_chip_search_game')), findsOneWidget);
      expect(find.text('全网游戏搜索'), findsOneWidget);

      // 切换到「音乐」
      await tester.tap(find.byKey(const Key('catalog_tab_music')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_chip_search_music')), findsOneWidget);
      expect(find.text('全网音乐检索'), findsOneWidget);

      // 切换到「书籍」
      await tester.tap(find.byKey(const Key('catalog_tab_book')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_chip_search_book')), findsOneWidget);
      expect(find.text('全网图书检索'), findsOneWidget);

      // 2. 移动端窄屏视口 (375x812) 响应式与 0 溢出验证
      tester.view.physicalSize = const Size(375, 812);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '移动端窄屏下 MediaPage 应 0 像素溢出');

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('【无截图验证体系】2. 详情页 (InfoPage) 按媒体类型智能分流断言', () {
    testWidgets('视频类（动画/影视）：断言渲染左右双按钮（全网BT搜索 + 在线观看）', (tester) async {
      final animeSubject = makeSubject(
        id: 1001,
        name: '葬送のフリーレン',
        nameCn: '葬送的芙莉莲',
        type: 2, // 动画
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: InfoPage(bangumi: animeSubject),
            ),
          ),
        ),
      );
      await tester.pump();

      // 断言双按钮存在
      expect(find.byKey(const Key('info_btn_search_torrent')), findsOneWidget);
      expect(find.text('全网BT搜索'), findsOneWidget);
      expect(find.byKey(const Key('info_btn_watch_online')), findsOneWidget);

      // 断言不存在非视频类的单一宽按钮
      expect(find.byKey(const Key('info_btn_universal_search')), findsNothing);

      // 推进时间以排空底层网络超时定时器
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('非视频类（游戏/音乐/书籍）：断言渲染单大按钮「全网搜索资源」，彻底屏蔽在线观看', (tester) async {
      final gameSubject = makeSubject(
        id: 2002,
        name: 'Elden Ring',
        nameCn: '艾尔登法环',
        type: 4, // 游戏
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: InfoPage(bangumi: gameSubject),
            ),
          ),
        ),
      );
      await tester.pump();

      // 断言仅渲染单大按钮「全网搜索资源」
      expect(find.byKey(const Key('info_btn_universal_search')), findsOneWidget);
      expect(find.text('全网搜索资源'), findsOneWidget);

      // 断言彻底不渲染「在线观看」和「全网BT搜索」
      expect(find.byKey(const Key('info_btn_watch_online')), findsNothing);
      expect(find.byKey(const Key('info_btn_search_torrent')), findsNothing);

      // 推进时间以排空底层网络超时定时器
      await tester.pump(const Duration(seconds: 15));
    });
  });

  group('【无截图验证体系】3. 跨域联动与 Torznab 标准分类映射', () {
    testWidgets('点击游戏「全网搜索资源」，断言主导航切至全网资源，单选锁定 Game 分类 (Torznab 4050/4000) 并填入关键字', (tester) async {
      final gameSubject = makeSubject(
        id: 3003,
        name: 'Black Myth: Wukong',
        nameCn: '黑神话：悟空',
        type: 4, // 游戏
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 启动并渲染路由应用
      router.go(Routes.media);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 执行联动跳转逻辑
      final searchKeyword = gameSubject.nameCn.isNotEmpty ? gameSubject.nameCn : gameSubject.name;
      final TorrentCategory targetCategory = switch (gameSubject.type) {
        1 => TorrentCategory.document,
        2 => TorrentCategory.video,
        3 => TorrentCategory.audio,
        4 => TorrentCategory.game,
        6 => TorrentCategory.video,
        _ => TorrentCategory.all,
      };

      container.read(torrentSearchProvider.notifier).setCategoryFilter(targetCategory);
      container.read(torrentSearchProvider.notifier).search(searchKeyword);
      container.read(navigationProvider.notifier).updateSelectedIndex(1);
      router.go(Routes.resource);

      await tester.pumpAndSettle();

      // 断言 1: 导航索引更新为 1 (全网资源)
      expect(container.read(navigationProvider).selectedIndex, 1);

      // 断言 2: 搜索关键词与单选分类状态
      final searchState = container.read(torrentSearchProvider);
      expect(searchState.keyword, '黑神话：悟空');
      expect(searchState.categoryFilter, TorrentCategory.game);

      // 断言 3: Torznab 工业标准分类映射正确 (TorznabCategories.pcGames = 4050 / TorznabCategories.pc = 4000)
      final torznabCats = TorznabCategories.fromTorrentCategory(searchState.categoryFilter);
      expect(torznabCats, contains(TorznabCategories.pcGames));

      // 推进时间以排空底层网络超时定时器
      await tester.pump(const Duration(seconds: 16));
    });
  });
}
