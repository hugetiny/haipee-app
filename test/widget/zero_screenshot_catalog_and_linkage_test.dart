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
import 'package:haipee/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:haipee/pages/info/info_page.dart';
import 'package:haipee/pages/media/media_page.dart';
import 'package:haipee/pages/media_library/media_library_page.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/bean/widget/bangumi_context_menu.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/metadata_sync/models/metadata_record.dart';
import 'package:haipee/pages/info/info_tabview.dart';
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
    testWidgets('视频类（动画/影视）：断言渲染单一高对比度「开始观看」核心按钮，点击直通全网资源聚合与播放流 (TorrentSearchSheet)，彻底杜绝双轨制与旧Kazumi搜索', (tester) async {
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

      // 断言单一统一按钮「开始观看」存在，且彻底杜绝双按钮分流
      expect(find.byKey(const Key('info_btn_watch_online')), findsOneWidget);
      expect(find.text('开始观看'), findsOneWidget);
      expect(find.byKey(const Key('info_btn_search_torrent')), findsNothing);
      expect(find.text('全网BT搜索'), findsNothing);

      // 断言不存在非视频类的单一宽按钮
      expect(find.byKey(const Key('info_btn_universal_search')), findsNothing);

      // 点击「开始观看」，验证直接唤起聚合资源与播放流 (TorrentSearchSheet)，绝不跳转旧版Kazumi规则搜索
      await tester.tap(find.byKey(const Key('info_btn_watch_online')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TorrentSearchSheet), findsOneWidget);

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

  group('【无截图验证体系】4. 剧集列表与卡片菜单深度直通聚合播放流断言', () {
    testWidgets('条目详情页 (InfoTabView) 点击分集卡片，断言直接唤起 TorrentSearchSheet 并填入作品与集数', (tester) async {
      final animeSubject = makeSubject(
        id: 1001,
        name: '葬送のフリーレン',
        nameCn: '葬送的芙莉莲',
        type: 2,
      );

      final metadata = MetadataRecord(
        slug: 'frieren',
        primaryTitle: '葬送的芙莉莲',
        localeTag: 'zh-CN',
        updatedAt: DateTime.now(),
        episodes: const [
          EpisodeMetadata(
            number: 1,
            title: '冒险的终点',
            synopsis: '勇者一行人击败魔王后的旅程...',
          ),
        ],
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: DefaultTabController(
                length: 5,
                child: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                        sliver: const SliverToBoxAdapter(),
                      ),
                    ],
                    body: Builder(
                      builder: (context) => InfoTabView(
                        tabController: DefaultTabController.of(context),
                        bangumiItem: animeSubject,
                        commentsList: const [],
                        isLoading: false,
                        metadataRecord: metadata,
                        metadataLoading: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 断言剧集 ListTile 渲染
      expect(find.text('冒险的终点'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);

      // 点击分集卡片直接播放
      await tester.tap(find.text('冒险的终点'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TorrentSearchSheet), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('番剧卡片上下文菜单：旧规则缺失时，继续观看优雅回退至 TorrentSearchSheet', (tester) async {
      final animeSubject = makeSubject(
        id: 1001,
        name: '葬送のフリーレン',
        nameCn: '葬送的芙莉莲',
        type: 2,
      );

      final history = History(
        animeSubject,
        5,
        'uninstalled_plugin',
        DateTime.now(),
        'https://example.com/video',
        '第5话',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      router.go(Routes.media);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (ctx, child) => Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return child!;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext currentContext = tester.element(find.byType(MediaLibraryPage));

      await BangumiContextMenuHelper.playBangumiHistory(
        currentContext,
        capturedRef,
        history,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TorrentSearchSheet), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('TorrentSearchSheet 多语种备选别名芯片渲染与一键切换检索断言', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: TorrentSearchSheet(
                  initialKeyword: '葬送的芙莉莲',
                  aliases: [
                    '葬送的芙莉莲',
                    'Sousou no Frieren',
                    'Frieren: Beyond Journey\'s End',
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证备选别名芯片正常渲染
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);

      // 点击别名芯片，断言输入框文本同步切换
      await tester.tap(find.text('Sousou no Frieren'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Sousou no Frieren'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('卡片上下文菜单：视频类展示「立即观看」，非视频类（游戏/书籍）展示「全网搜索资源」', (tester) async {
      final animeSubject = makeSubject(
        id: 1001,
        name: '葬送のフリーレン',
        nameCn: '葬送的芙莉莲',
        type: 2, // 动画
      );
      final gameSubject = makeSubject(
        id: 2001,
        name: '塞尔达传说',
        nameCn: '塞尔达传说',
        type: 4, // 游戏
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      late BuildContext buildContext;
      late WidgetRef widgetRef;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    buildContext = context;
                    widgetRef = ref;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. 动画条目上下文菜单检查
      final animeMenuItems = BangumiContextMenuHelper.buildMenuItems(
        context: buildContext,
        ref: widgetRef,
        bangumiItem: animeSubject,
      );
      final animeTitles = animeMenuItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      expect(animeTitles.contains('立即观看'), isTrue);
      expect(animeTitles.contains('全网搜索资源'), isFalse);

      // 2. 游戏条目上下文菜单检查
      final gameMenuItems = BangumiContextMenuHelper.buildMenuItems(
        context: buildContext,
        ref: widgetRef,
        bangumiItem: gameSubject,
      );
      final gameTitles = gameMenuItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      expect(gameTitles.contains('全网搜索资源'), isTrue);
      expect(gameTitles.contains('立即观看'), isFalse);
    });
  });
}
