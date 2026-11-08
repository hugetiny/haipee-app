import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/modules/search/search_history_provider.dart';
import 'package:haipee/pages/media_library/media_library_page.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';

class MockPluginsControllerForTest extends PluginsController {
  final List<Plugin> initialPlugins;
  final bool enableBilibili;
  MockPluginsControllerForTest(this.initialPlugins, {this.enableBilibili = false});

  @override
  PluginsState build() {
    return PluginsState(
      pluginList: initialPlugins,
      disabledPluginNames: enableBilibili ? const {} : const {'bilibili'},
    );
  }

  @override
  bool isPluginEnabled(String name) {
    if (name == 'bilibili') return enableBilibili;
    return true;
  }
}

class FakePlugin extends Plugin {
  final Future<PluginSearchResponse> Function(String keyword)? onQuery;
  final PluginCategory fakeCategory;

  FakePlugin({
    required super.name,
    this.fakeCategory = PluginCategory.video,
    this.onQuery,
  }) : super(
          version: '1.0.0',
          type: fakeCategory.id,
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

  @override
  PluginCategory get resolvedCategory => fakeCategory;

  @override
  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    if (onQuery != null) {
      return await onQuery!(keyword);
    }
    return PluginSearchResponse(pluginName: name, data: const []);
  }
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
    testWidgets('OnlineVideoSearchPage renders centered search engine header with 3 source filter chips',
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
        find.text('输入作品、频道名称或粘贴 B站 BV 号'),
        findsOneWidget,
      );

      // 2. 验证搜索框旁边的「筛选」按钮及点开后的多维度分类面板 (无冗余底层技术文本与生硬数字)
      expect(find.byKey(const Key('online_search_filter_toggle_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('online_search_filter_panel')), findsOneWidget);
      expect(find.text('视频类型'), findsOneWidget);
      expect(find.text('规则类型'), findsOneWidget);
      expect(find.text('全部视频'), findsOneWidget);
      expect(find.text('点播视频'), findsOneWidget);
      expect(find.text('实时直播'), findsOneWidget);
      expect(find.text('网盘资源 (0)'), findsNothing);
      expect(find.textContaining('底层技术:'), findsNothing);

      // 3. 验证顶栏右上角保持极简主流设计，不堆砌冗余的规则设置、下载管理与独立BT直搜按钮
      expect(find.byTooltip('BT/磁力直搜 (Mikan/Nyaa)'), findsNothing);
      expect(find.byTooltip('Haipee 视频规则'), findsNothing);
      expect(find.byTooltip('下载管理'), findsNothing);

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
          tag: 'Web规则',
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

      // 验证 3 种不同源的徽章 (左上角纯来源标签，不与右上角类型重复)
      expect(find.text('BiliBili'), findsOneWidget);
      expect(find.text('抖音'), findsOneWidget);
      expect(find.text('dalvdm'), findsOneWidget);

      // 验证简洁清晰标签 (不再展示冗余自报家门底层技术文字)
      expect(find.text('B站高清'), findsOneWidget);
      expect(find.text('短视频'), findsOneWidget);
      expect(find.text('Web规则'), findsWidgets);
      expect(find.textContaining('官方 WBI 签名'), findsNothing);

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
      expect(find.byKey(const Key('online_search_filter_toggle_btn')), findsOneWidget);

      // Mutate pluginsProvider state as if catalog/disabled state loaded asynchronously
      final controller = container.read(pluginsProvider.notifier);
      controller.state = controller.state.copyWith(
        disabledPluginNames: {'test_rule'},
      );
      await tester.pumpAndSettle();

      // Verify reactive update succeeded without ProviderException
      expect(find.byKey(const Key('online_search_filter_toggle_btn')), findsOneWidget);
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

      // 点击搜索框旁边的「筛选」按钮并切换至视频分类
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online_search_chip_video')));
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

    testWidgets('OnlineVideoSearchPage dynamically switches TextField hint text for each filter mode',
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
        find.text('输入作品、频道名称或粘贴 B站 BV 号'),
        findsOneWidget,
      );
      expect(find.textContaining('底层技术:'), findsNothing);

      // 2. 展开筛选面板并切换至点播视频
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online_search_chip_video')));
      await tester.pumpAndSettle();

      expect(find.text('搜索在线视频、动漫番剧或粘贴 B站 BV 号'), findsOneWidget);
      expect(find.textContaining('底层技术:'), findsNothing);

      // 3. 切换至直播
      await tester.tap(find.byKey(const Key('online_search_chip_live')));
      await tester.pumpAndSettle();

      expect(find.text('搜索电视直播频道、央视、卫视或轮播台'), findsOneWidget);
      expect(find.textContaining('底层技术:'), findsNothing);

      // 4. 切回全部
      await tester.tap(find.byKey(const Key('online_search_chip_all')));
      await tester.pumpAndSettle();

      expect(
        find.text('输入作品、频道名称或粘贴 B站 BV 号'),
        findsOneWidget,
      );
      expect(find.textContaining('底层技术:'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage progressive streaming search displays items as soon as any source returns',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final fastPlugin = FakePlugin(
        name: 'fast_source',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 40));
          return PluginSearchResponse(
            pluginName: 'fast_source',
            data: [
              SearchItem(name: '进击的巨人 第一季', src: '/video/1'),
            ],
          );
        },
      );

      final slowPlugin = FakePlugin(
        name: 'slow_live_source',
        fakeCategory: PluginCategory.live,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 180));
          return PluginSearchResponse(
            pluginName: 'slow_live_source',
            data: [
              SearchItem(name: '进击的巨人 24H 轮播直播', src: '/live/1'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([fastPlugin, slowPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 发起检索
      await tester.enterText(find.byType(TextField), '进击');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 1. 验证刚开始检索时，未返回任何结果时显示全网并发检索进度
      expect(find.textContaining('正在全网并发检索在线视频与直播流'), findsOneWidget);

      // 2. 快源返回：40ms 后 fast_source 已完成，但 slowPlugin 仍在执行
      await tester.pump(const Duration(milliseconds: 60));

      // 验证流式渐进呈现：快源结果立刻上屏，无需等待慢源
      expect(find.text('进击的巨人 第一季'), findsOneWidget);
      expect(find.textContaining('找到 1 条视听内容'), findsOneWidget);
      expect(find.textContaining('正在并发检索 (1/2 个源)'), findsOneWidget);

      // 3. 慢源返回：再过 150ms 后，慢源直播频道也增量展示出来
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(find.text('进击的巨人 第一季'), findsOneWidget);
      expect(find.text('进击的巨人 24H 轮播直播'), findsOneWidget);
      expect(find.textContaining('找到 2 条视听内容'), findsOneWidget);
      expect(find.text('已检索全部 2 个源'), findsOneWidget);

      // 验证展开筛选面板后，各分类标签清晰展示「全部视频」「点播视频」「实时直播」
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('online_search_chip_all')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_video')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_live')), findsOneWidget);
      expect(find.text('全部视频'), findsOneWidget);
      expect(find.text('点播视频'), findsOneWidget);
      expect(find.text('实时直播'), findsWidgets);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage switching filter chips does not interrupt ongoing search',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final fastPlugin = FakePlugin(
        name: 'fast_video',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 30));
          return PluginSearchResponse(
            pluginName: 'fast_video',
            data: [
              SearchItem(name: '孤独摇滚 正片', src: '/video/bocchi'),
            ],
          );
        },
      );

      final slowPlugin = FakePlugin(
        name: 'slow_live',
        fakeCategory: PluginCategory.live,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 150));
          return PluginSearchResponse(
            pluginName: 'slow_live',
            data: [
              SearchItem(name: '孤独摇滚 音乐电台直播', src: '/live/bocchi'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([fastPlugin, slowPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 发起检索
      await tester.enterText(find.byType(TextField), '孤独摇滚');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 快源视频已展示
      expect(find.text('孤独摇滚 正片'), findsOneWidget);

      // 展开筛选面板并切换至“直播”标签（慢源此时仍在网络请求中）
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('online_search_chip_live')));
      await tester.pump();

      // 切换标签不会打断后台慢源请求，当前直播分类显示占位提示
      expect(find.text('孤独摇滚 正片'), findsNothing);
      expect(find.text('当前分类暂未检索到直播频道，其余源检索中...'), findsOneWidget);

      // 等待慢源请求完成
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // 慢源结果直接流式呈现在当前直播视图中
      expect(find.text('孤独摇滚 音乐电台直播'), findsOneWidget);
      expect(find.text('找到 1 个直播频道'), findsOneWidget);

      // 再次切回“视频”标签，原先的视频结果依然保留无需重新检索
      await tester.tap(find.byKey(const Key('online_search_chip_video')));
      await tester.pumpAndSettle();

      expect(find.text('孤独摇滚 正片'), findsOneWidget);
      expect(find.text('找到 1 条视频'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage renders with zero overflow on mobile viewport (375x812) during streaming search and completion',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;

      final fastPlugin = FakePlugin(
        name: 'mobile_fast_video',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 30));
          return PluginSearchResponse(
            pluginName: 'mobile_fast_video',
            data: [
              SearchItem(name: '葬送的芙莉莲 剧集', src: '/video/frieren'),
            ],
          );
        },
      );

      final slowPlugin = FakePlugin(
        name: 'mobile_slow_live',
        fakeCategory: PluginCategory.live,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return PluginSearchResponse(
            pluginName: 'mobile_slow_live',
            data: [
              SearchItem(name: '芙莉莲 24H 慢直播', src: '/live/frieren'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([fastPlugin, slowPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Trigger search
      await tester.enterText(find.byType(TextField), '芙莉莲');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // Active searching state with zero overflow
      expect(tester.takeException(), isNull);

      // Fast plugin returns
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('葬送的芙莉莲 剧集'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Slow plugin returns
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('芙莉莲 24H 慢直播'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage handles synchronous plugin exceptions without crashing or blocking search completion',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final throwingPlugin = FakePlugin(
        name: 'throwing_crash_plugin',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) {
          throw StateError('Simulated synchronous plugin crash');
        },
      );

      final healthyPlugin = FakePlugin(
        name: 'healthy_video_plugin',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 30));
          return PluginSearchResponse(
            pluginName: 'healthy_video_plugin',
            data: [
              SearchItem(name: '健康的在线视频剧集', src: '/video/healthy'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([throwingPlugin, healthyPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '容错测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // Ensure no unhandled framework exception from the throwing plugin
      expect(tester.takeException(), isNull);

      // Advance clock for the healthy plugin
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Healthy plugin result is presented and search completes with all 2 sources accounted for
      expect(find.text('健康的在线视频剧集'), findsOneWidget);
      expect(find.text('已检索全部 2 个源'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage clearing search bar invalidates pending in-flight requests and discards ghost results',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final slowPlugin = FakePlugin(
        name: 'slow_ghost_video',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 150));
          return PluginSearchResponse(
            pluginName: 'slow_ghost_video',
            data: [
              SearchItem(name: '延迟返回的幽灵结果', src: '/video/ghost'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([slowPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 发起搜索
      await tester.enterText(find.byType(TextField), '幽灵测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 搜索正在进行中
      expect(find.textContaining('正在全网并发检索在线视频与直播流'), findsOneWidget);

      // 2. 在慢源返回前，用户点击清空搜索框 (X 按钮)
      final clearBtn = find.byIcon(Icons.clear);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // 验证已回到空闲状态 (去除了「全网热门推荐流」文本)
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
      expect(find.text('全网热门推荐流'), findsNothing);

      // 3. 推进时间，让慢源请求在后台完成
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // 4. 验证幽灵数据被成功丢弃，不会重新蹦出来污染界面
      expect(find.text('延迟返回的幽灵结果'), findsNothing);
      expect(find.text('全网热门推荐流'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage empty state card provides one-click navigation to all results when matches exist in other categories',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      final videoOnlyPlugin = FakePlugin(
        name: 'video_only_plugin',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          return PluginSearchResponse(
            pluginName: 'video_only_plugin',
            data: [
              SearchItem(name: '仅视频有结果的正片', src: '/video/exclusive'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([videoOnlyPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 发起检索
      await tester.enterText(find.byType(TextField), '独家正片');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('仅视频有结果的正片'), findsOneWidget);

      // 展开筛选面板并切换到“直播”标签
      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online_search_chip_live')));
      await tester.pumpAndSettle();

      // 直播分类下无结果，呈现具有数量提示的直观引导卡片
      expect(find.text('未找到匹配的直播频道'), findsOneWidget);
      final navBtn = find.text('查看全部分类检索结果 (1)');
      expect(navBtn, findsOneWidget);

      // 点击引导按钮
      await tester.tap(navBtn);
      await tester.pumpAndSettle();

      // 验证无缝切回全部并展示该内容
      expect(find.text('仅视频有结果的正片'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchPage renders with zero overflow on narrow mobile viewport (320x568)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      final fastPlugin = FakePlugin(
        name: 'narrow_plugin_1',
        fakeCategory: PluginCategory.video,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 30));
          return PluginSearchResponse(
            pluginName: 'narrow_plugin_1',
            data: [
              SearchItem(name: '超窄屏测试视频第一集', src: '/video/narrow'),
            ],
          );
        },
      );

      final slowPlugin = FakePlugin(
        name: 'narrow_plugin_2',
        fakeCategory: PluginCategory.live,
        onQuery: (keyword) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return PluginSearchResponse(
            pluginName: 'narrow_plugin_2',
            data: [
              SearchItem(name: '超窄屏测试直播', src: '/live/narrow'),
            ],
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForTest([fastPlugin, slowPlugin])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), '超窄屏');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('超窄屏测试视频第一集'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.textContaining('找到 2 条视听内容'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 视口高度有限，向下滚动以使第二个结果卡片进入视口
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('超窄屏测试直播'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('OnlineVideoSearchProvider decouples request lifecycle from filter switching with real-time state accumulation and pure chip labels',
        (tester) async {
      // 1. 验证底部导航与多语言命名已统一为「视频直播」
      expect(t.navigation.tabs.media, equals('视频直播'));

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(
            () => MockPluginsControllerForTest([
              FakePlugin(
                name: 'p_video',
                fakeCategory: PluginCategory.video,
                onQuery: (keyword) async {
                  await Future.delayed(const Duration(milliseconds: 50));
                  return PluginSearchResponse(
                    pluginName: 'p_video',
                    data: [
                      SearchItem(name: '并发视频结果', src: '/video/1'),
                    ],
                  );
                },
              ),
              FakePlugin(
                name: 'p_live',
                fakeCategory: PluginCategory.live,
                onQuery: (keyword) async {
                  await Future.delayed(const Duration(milliseconds: 100));
                  return PluginSearchResponse(
                    pluginName: 'p_live',
                    data: [
                      SearchItem(name: '并发直播结果', src: '/live/1'),
                    ],
                  );
                },
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(onlineVideoSearchProvider.notifier);

      // 2. 发起搜索
      notifier.search('测试解耦并发');
      var state = container.read(onlineVideoSearchProvider);
      expect(state.isSearching, isTrue);
      expect(state.totalSources, equals(2));
      expect(state.completedSources, equals(0));
      expect(state.allResults, isEmpty);

      // 3. 此时用户瞬间切换分类到「直播」—— 0延迟切换，绝不中断请求
      notifier.setFilter(OnlineSourceFilter.live);
      state = container.read(onlineVideoSearchProvider);
      expect(state.selectedFilter, equals(OnlineSourceFilter.live));
      expect(state.isSearching, isTrue);

      // 4. 等待快源（视频）返回 —— 实时保存在状态 allResults 中
      await tester.pump(const Duration(milliseconds: 60));
      state = container.read(onlineVideoSearchProvider);
      expect(state.allResults.length, equals(1));
      expect(state.allResults.first.title, equals('并发视频结果'));
      // 当前在「直播」分类下，因此 currentFilteredResults 为空，但全局状态已保存该结果
      expect(state.currentFilteredResults, isEmpty);
      expect(state.completedSources, equals(1));
      expect(state.isSearching, isTrue);

      // 5. 瞬间切回「全部」分类 —— 0延迟即可看到已累积的视频结果，且慢源请求未受任何干扰
      notifier.setFilter(OnlineSourceFilter.all);
      state = container.read(onlineVideoSearchProvider);
      expect(state.currentFilteredResults.length, equals(1));
      expect(state.currentFilteredResults.first.title, equals('并发视频结果'));

      // 6. 等待慢源（直播）返回 —— 全部完成
      await tester.pump(const Duration(milliseconds: 60));
      state = container.read(onlineVideoSearchProvider);
      expect(state.allResults.length, equals(2));
      expect(state.completedSources, equals(2));
      expect(state.isSearching, isFalse);
      expect(state.currentFilteredResults.length, equals(2));

      // 7. 切到「视频」分类 —— 瞬间得到 1 条，无任何冗余请求
      notifier.setFilter(OnlineSourceFilter.video);
      state = container.read(onlineVideoSearchProvider);
      expect(state.currentFilteredResults.length, equals(1));
      expect(state.currentFilteredResults.first.title, equals('并发视频结果'));

      // 8. 切到「直播」分类 —— 瞬间得到 1 条，无任何冗余请求
      notifier.setFilter(OnlineSourceFilter.live);
      state = container.read(onlineVideoSearchProvider);
      expect(state.currentFilteredResults.length, equals(1));
      expect(state.currentFilteredResults.first.title, equals('并发直播结果'));
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
