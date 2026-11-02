import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/modules/search/search_history_provider.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';

class MockRuleAssociationController extends PluginsController {
  final List<Plugin> testPlugins;
  MockRuleAssociationController(this.testPlugins);

  @override
  PluginsState build() {
    return PluginsState(
      pluginList: testPlugins,
      disabledPluginNames: const {},
    );
  }

  @override
  bool isPluginEnabled(String name) => true;
}

class FakeSearchHistoryNotifierForTest extends SearchHistoryNotifier {
  @override
  List<SearchHistory> build() => const [];

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

class TestStreamingPlugin extends Plugin {
  final Future<PluginSearchResponse> Function(String keyword)? onQuery;
  final PluginRuleType testRuleType;

  TestStreamingPlugin({
    required super.name,
    required this.testRuleType,
    this.onQuery,
  }) : super(
          version: '1.0.0',
          type: testRuleType.id,
          api: '1',
          baseUrl: 'https://example.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          searchPic: '',
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
  PluginRuleType get ruleType => testRuleType;

  @override
  bool get isIptv => testRuleType == PluginRuleType.iptv;

  @override
  bool get isTvBox => testRuleType == PluginRuleType.tvbox;

  @override
  bool get isMacCms => testRuleType == PluginRuleType.maccms;

  @override
  bool get isPiped => testRuleType == PluginRuleType.piped;

  @override
  bool get isResource => false;

  @override
  Future<PluginSearchResponse> queryBangumi(String keyword, {bool shouldRethrow = false}) async {
    if (onQuery != null) {
      return onQuery!(keyword);
    }
    return PluginSearchResponse(pluginName: name, data: const []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('haipee_rule_assoc_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SearchHistoryAdapter());
    }
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    LocaleSettings.useDeviceLocale();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('OnlineVideoSearchPage Rule-Centric Search & Filter Association', () {
    testWidgets(
        'Idle unsearched state displays tool guidance with rule status board and zero badges on left filters',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final plugins = [
        TestStreamingPlugin(name: 'kazumi_source', testRuleType: PluginRuleType.haipee),
        TestStreamingPlugin(name: 'maccms_source', testRuleType: PluginRuleType.maccms),
        TestStreamingPlugin(name: 'tvbox_source', testRuleType: PluginRuleType.tvbox),
        TestStreamingPlugin(name: 'iptv_source', testRuleType: PluginRuleType.iptv),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockRuleAssociationController(plugins)),
            searchHistoryProvider.overrideWith(() => FakeSearchHistoryNotifierForTest()),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证未搜索状态下没有任何像素溢出
      expect(tester.takeException(), isNull);

      // 验证呈现纯工具引导视图，绝不展示虚假 B 站 20 条热门
      expect(find.textContaining('已启用规则 (4 个规则)'), findsOneWidget);
      expect(find.text('Haipee 规则'), findsWidgets);
      expect(find.text('MacCMS 规则'), findsWidgets);
      expect(find.text('TVBox 规则'), findsWidgets);
      expect(find.text('IPTV 直播'), findsWidgets);

      // 验证左侧导航中的 8 大筛选标签全部存在
      expect(find.byKey(const Key('online_search_chip_all')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_video')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_live')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_haipee')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_maccms')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_tvbox')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_iptv')), findsOneWidget);
      expect(find.byKey(const Key('online_search_chip_piped')), findsOneWidget);

      // 验证未搜索状态下没有任何角标数字 (例如过去的 20)
      expect(find.text('20'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Concurrent search dynamically streams results into respective rule filter buckets with real-time badges',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final plugins = [
        TestStreamingPlugin(
          name: 'tvbox_test',
          testRuleType: PluginRuleType.tvbox,
          onQuery: (kw) async {
            await Future.delayed(const Duration(milliseconds: 30));
            return PluginSearchResponse(
              pluginName: 'tvbox_test',
              data: [
                SearchItem(name: '鬼灭之刃 无限列车篇', src: '/vod/1'),
                SearchItem(name: '鬼灭之刃 游郭篇', src: '/vod/2'),
              ],
            );
          },
        ),
        TestStreamingPlugin(
          name: 'iptv_test',
          testRuleType: PluginRuleType.iptv,
          onQuery: (kw) async {
            await Future.delayed(const Duration(milliseconds: 80));
            return PluginSearchResponse(
              pluginName: 'iptv_test',
              data: [
                SearchItem(name: '鬼灭之刃 24H 动画轮播台', src: 'http://live.example/m3u8'),
              ],
            );
          },
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockRuleAssociationController(plugins)),
            searchHistoryProvider.overrideWith(() => FakeSearchHistoryNotifierForTest()),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 发起检索
      await tester.enterText(find.byType(TextField), '鬼灭');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 快源 (TVBox) 返回 (30ms 后): 应该有 2 个结果
      await tester.pump(const Duration(milliseconds: 45));

      expect(find.text('鬼灭之刃 无限列车篇'), findsOneWidget);
      expect(find.text('鬼灭之刃 游郭篇'), findsOneWidget);

      // 慢源 (IPTV) 尚未返回时，TVBox 规则与全部分类应显示 2
      expect(find.text('2'), findsWidgets);

      // 慢源 (IPTV) 返回 (再过 60ms)
      await tester.pump(const Duration(milliseconds: 65));
      await tester.pumpAndSettle();

      expect(find.text('鬼灭之刃 24H 动画轮播台'), findsOneWidget);

      // 验证搜索完成状态与各分类角标关联:
      // 全部: 3, 视频: 2, 直播: 1, TVBox: 2, IPTV: 1
      expect(find.text('找到 3 条视听内容'), findsOneWidget);
      expect(find.text('已检索全部 2 个源'), findsOneWidget);

      // 点击左侧 TVBox 规则筛选
      await tester.tap(find.byKey(const Key('online_search_chip_tvbox')));
      await tester.pumpAndSettle();

      expect(find.text('找到 2 部 TVBox 聚合内容'), findsOneWidget);
      expect(find.text('鬼灭之刃 无限列车篇'), findsOneWidget);
      expect(find.text('鬼灭之刃 游郭篇'), findsOneWidget);
      expect(find.text('鬼灭之刃 24H 动画轮播台'), findsNothing);

      // 点击左侧 IPTV 直播筛选
      await tester.tap(find.byKey(const Key('online_search_chip_iptv')));
      await tester.pumpAndSettle();

      expect(find.text('找到 1 个 IPTV 直播频道'), findsOneWidget);
      expect(find.text('鬼灭之刃 24H 动画轮播台'), findsOneWidget);
      expect(find.text('鬼灭之刃 无限列车篇'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
