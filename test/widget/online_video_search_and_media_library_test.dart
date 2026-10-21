import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/parse_failure/parse_failure_module.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/pages/media_library/media_library_page.dart';
import 'package:kazumi/pages/online/online_video_search_page.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/utils/storage.dart';

class MockPluginsControllerForTest extends PluginsController {
  final List<Plugin> initialPlugins;
  MockPluginsControllerForTest(this.initialPlugins);

  @override
  PluginsState build() {
    return PluginsState(pluginList: initialPlugins);
  }

  @override
  bool isPluginEnabled(String name) => true;
}

class FakeSearchHistoryNotifier extends SearchHistoryNotifier {
  final List<SearchHistory> initial;
  FakeSearchHistoryNotifier([this.initial = const []]);

  @override
  List<SearchHistory> build() {
    return List<SearchHistory>.from(initial);
  }

  @override
  Future<void> addHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    state = [
      SearchHistory(clean, DateTime.now().millisecondsSinceEpoch),
      ...state.where((h) => h.keyword != clean),
    ];
  }

  @override
  Future<void> deleteHistory(SearchHistory item) async {
    state = state.where((h) => h.keyword != item.keyword).toList();
  }

  @override
  Future<void> clearAll() async {
    state = const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('online_and_library_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(BangumiItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HistoryAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SearchHistoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CollectedBangumiAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ProgressAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(BangumiTagAdapter());
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(ParseFailureRecordAdapter());

    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    GStorage.histories = await Hive.openBox<History>('histories');
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('OnlineVideoSearchPage Widget & Search Engine Tests', () {
    testWidgets('OnlineVideoSearchPage renders centered search engine header with 4 source filter chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final dummyPlugins = <Plugin>[
        Plugin(
          name: 'dalvdm',
          version: '1.0.0',
          type: 'anime',
          api: '1',
          baseUrl: 'https://example.com',
          searchURL: 'https://example.com/search?q=@keyword',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: false,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest(dummyPlugins)),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证标题与搜索框
      expect(find.text('在线视频搜索'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('输入作品、关键词或粘贴链接 (B站 / 苹果CMS / Web规则源)'),
        findsOneWidget,
      );

      // 2. 验证 3 大在线规则源切换 Chips 及底层技术说明
      expect(find.text('全部源'), findsOneWidget);
      expect(find.text('哔哩哔哩'), findsOneWidget);
      expect(find.text('Web 规则源 (1 个)'), findsOneWidget);
      expect(find.text('抖音短视频'), findsNothing); // 已从主过滤器移除脆弱的抖音专有标签
      expect(find.text('底层技术: 多协议并发聚合调度 · 毫秒级原生直出'), findsOneWidget);

      // 3. 验证快捷操作入口 (视频规则管理与下载管理快捷图标)
      expect(find.byIcon(Icons.video_library_outlined), findsWidgets);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage renders distinct badges for Bilibili, Douyin, and Web rules',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final testVideos = [
        const BiliVideoItem(
          bvid: 'BV1xx411c7mD',
          title: '孤独摇滚 第一话',
          author: '芳文社',
          pic: '',
          duration: '24:00',
        ),
        const BiliVideoItem(
          bvid: 'douyin_7234567890123456789',
          title: '二次元神级剪辑',
          author: '动漫剪辑君',
          pic: '',
          duration: '15s',
          description: 'https://v.douyin.com/test',
        ),
        const BiliVideoItem(
          bvid: 'web_dalvdm_https://example.com/play/1',
          title: '间谍过家家 第二季',
          author: 'dalvdm',
          pic: '',
          duration: 'Web规则',
          description: 'https://example.com/play/1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: testVideos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 3 种不同源的徽章
      expect(find.text('BiliBili'), findsOneWidget);
      expect(find.text('抖音'), findsOneWidget);
      expect(find.text('Web · dalvdm'), findsOneWidget);

      // 验证每种源背后的底层技术机制展示
      expect(find.text('官方 WBI 签名 · DASH 音画分离'), findsOneWidget);
      expect(find.text('无水印 CDN 直链'), findsOneWidget);
      expect(find.text('XPath / DOM 嗅探规则'), findsOneWidget);

      // 验证视频条目正常呈现
      expect(find.text('孤独摇滚 第一话'), findsOneWidget);
      expect(find.text('二次元神级剪辑'), findsOneWidget);
      expect(find.text('间谍过家家 第二季'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage reacts to pluginsProvider updates without ProviderException',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final testPlugin = Plugin(
        name: 'test_rule',
        version: '1.0.0',
        type: 'anime',
        api: '1',
        baseUrl: 'https://example.com',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: false,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(
            () => MockPluginsControllerForTest([testPlugin]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial rendering
      expect(find.text('Web 规则源 (1 个)'), findsOneWidget);

      // Mutate pluginsProvider state as if catalog/disabled state loaded asynchronously
      final controller = container.read(pluginsProvider.notifier);
      controller.state = controller.state.copyWith(
        disabledPluginNames: {'test_rule'},
      );
      await tester.pumpAndSettle();

      // Verify reactive update succeeded without ProviderException
      expect(find.text('Web 规则源 (0 个)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage displays history dropdown overlay when focused and supports search, deletion and clear all',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final fakeNotifier = FakeSearchHistoryNotifier([
        SearchHistory('凉宫春日的忧郁', 1000),
        SearchHistory('CLANNAD', 2000),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([])),
            searchHistoryProvider.overrideWith(() => fakeNotifier),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证聚焦前主页面干净克制，无旧版平铺堆叠的历史 Chips
      expect(find.text('最近搜索历史'), findsNothing);

      // 聚焦搜索框
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证浮层已在搜索框下方展示
      expect(find.text('搜索历史'), findsOneWidget);
      expect(find.text('凉宫春日的忧郁'), findsOneWidget);
      expect(find.text('CLANNAD'), findsOneWidget);
      expect(find.text('清空全部'), findsOneWidget);

      // 1. 测试删除单项
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsWidgets);
      await tester.tap(closeIcons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 2. 点击清空全部
      await tester.tap(find.text('清空全部'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('暂无搜索历史记录'), findsOneWidget);

      // 3. 动态添加新历史并测试点击单项即刻搜索
      await fakeNotifier.addHistory('命运石之门');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('命运石之门'), findsOneWidget);

      await tester.tap(find.text('命运石之门'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('命运石之门'));
      expect(find.text('清空全部'), findsNothing); // 浮层已自动收起

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage handles empty search in specific filter with graceful guidance card and 1-click switch',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 切换至 Web 规则源
      await tester.tap(find.text('Web 规则源 (0 个)'));
      await tester.pumpAndSettle();

      // 输入普通搜索关键词（当前无插件匹配）
      await tester.enterText(find.byType(TextField), '进击的巨人');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 验证零崩溃、呈现优雅降级提示卡片
      expect(tester.takeException(), isNull);
      expect(find.text('未找到匹配的在线视频'), findsOneWidget);
      expect(find.text('使用全部源检索「进击的巨人」'), findsOneWidget);

      // 点击切换至全部源按钮
      await tester.tap(find.text('使用全部源检索「进击的巨人」'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证规则源已自动切换至全部源且未报错
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage dismisses history dropdown overlay on Escape key',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final fakeNotifier = FakeSearchHistoryNotifier([
        SearchHistory('凉宫春日的忧郁', 1000),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([])),
            searchHistoryProvider.overrideWith(() => fakeNotifier),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus search box
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('搜索历史'), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Verify overlay dismissed
      expect(find.text('搜索历史'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage dynamically switches TextField hint text and tech stack for each filter mode',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 全部源默认状态
      expect(
        find.text('输入作品、关键词或粘贴链接 (B站 / 苹果CMS / Web规则源)'),
        findsOneWidget,
      );
      expect(find.text('底层技术: 多协议并发聚合调度 · 毫秒级原生直出'), findsOneWidget);

      // 2. 切换至哔哩哔哩
      await tester.tap(find.text('哔哩哔哩'));
      await tester.pumpAndSettle();

      expect(find.text('搜索 Bilibili 视频关键词或粘贴 BV 号'), findsOneWidget);
      expect(find.text('底层技术: 官方 WBI 签名 · DASH 音画分离'), findsOneWidget);

      // 3. 切换至 Web 规则源
      await tester.tap(find.text('Web 规则源 (0 个)'));
      await tester.pumpAndSettle();

      expect(find.text('搜索苹果CMS及Web规则源，或输入番剧片名'), findsOneWidget);
      expect(find.text('底层技术: 苹果CMS V10 JSON · 声明式规则体系'), findsOneWidget);

      // 4. 切回全部源
      await tester.tap(find.text('全部源'));
      await tester.pumpAndSettle();

      expect(
        find.text('输入作品、关键词或粘贴链接 (B站 / 苹果CMS / Web规则源)'),
        findsOneWidget,
      );
      expect(find.text('底层技术: 多协议并发聚合调度 · 毫秒级原生直出'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('MediaLibraryPage Integration & Single AppBar Tests', () {
    testWidgets('MediaLibraryPage renders exactly ONE SysAppBar, 3 quick cards and embedded 5-tab MediaPage',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: const MaterialApp(
              home: MediaLibraryPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证只有 1 个 SysAppBar，避免嵌套 Scaffold / 双顶栏缺陷
      expect(find.byType(SysAppBar), findsOneWidget);
      expect(find.text('媒体库'), findsOneWidget);

      // 2. 验证顶部三联卡片: 个人收藏, 追番日历, 播放历史
      expect(find.text('个人收藏'), findsWidgets);
      expect(find.text('追番日历'), findsWidgets);
      expect(find.text('播放历史'), findsWidgets);

      // 3. 验证嵌入的 MediaPage 5 大分类正常渲染
      expect(find.text('动画'), findsOneWidget);
      expect(find.text('影视'), findsOneWidget);
      expect(find.text('游戏'), findsOneWidget);
      expect(find.text('音乐'), findsOneWidget);
      expect(find.text('书籍'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
