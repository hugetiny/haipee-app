import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';

class MockPluginsControllerForFilterTest extends PluginsController {
  final List<Plugin> testPlugins;
  MockPluginsControllerForFilterTest(this.testPlugins);

  @override
  PluginsState build() {
    return PluginsState(
      pluginList: testPlugins,
      disabledPluginNames: const {'bilibili', 'douyin'},
    );
  }

  @override
  bool isPluginEnabled(String name) => true;
}

class FakeStreamPlugin extends Plugin {
  final String pluginRuleTypeId;
  final Future<PluginSearchResponse> Function(String keyword)? onQuery;

  FakeStreamPlugin({
    required super.name,
    required this.pluginRuleTypeId,
    this.onQuery,
  }) : super(
          version: '1.0.0',
          type: pluginRuleTypeId,
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
          category: pluginRuleTypeId == 'iptv' ? 'live' : 'video',
        );

  @override
  PluginRuleType get ruleType => PluginRuleType.fromString(pluginRuleTypeId);

  @override
  Future<PluginSearchResponse> queryBangumi(
    String keyword, {
    bool isRetry = false,
    String? page,
    bool shouldRethrow = false,
  }) async {
    if (onQuery != null) {
      return await onQuery!(keyword);
    }
    return PluginSearchResponse(
      pluginName: name,
      data: [
        SearchItem(
          name: '$name - $keyword',
          src: 'https://example.com/play/$name',
          remarks: ruleType == PluginRuleType.iptv ? '实时直播' : '点播正片',
          pic: 'https://example.com/pic.jpg',
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('online_video_search_filter_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SearchHistoryAdapter());

    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('OnlineVideoSearchPage Unified Layout & Full Request Tests', () {
    test('PluginRuleType correctly separates 5 streaming rules from 2 resource rules', () {
      // 5 大视听流媒体规则
      expect(PluginRuleType.haipee.isStreamingDomain, isTrue);
      expect(PluginRuleType.maccms.isStreamingDomain, isTrue);
      expect(PluginRuleType.tvbox.isStreamingDomain, isTrue);
      expect(PluginRuleType.iptv.isStreamingDomain, isTrue);
      expect(PluginRuleType.piped.isStreamingDomain, isTrue);

      // 2 大全网资源下载规则
      expect(PluginRuleType.alist.isStreamingDomain, isFalse);
      expect(PluginRuleType.alist.isResourceDomain, isTrue);
      expect(PluginRuleType.cardigann.isStreamingDomain, isFalse);
      expect(PluginRuleType.cardigann.isResourceDomain, isTrue);
    });

    test('OnlineSourceFilter contains all 8 filtering options', () {
      final filters = OnlineSourceFilter.audiovisualFilters;
      expect(filters.length, equals(8));
      expect(filters, contains(OnlineSourceFilter.all));
      expect(filters, contains(OnlineSourceFilter.video));
      expect(filters, contains(OnlineSourceFilter.live));
      expect(filters, contains(OnlineSourceFilter.haipee));
      expect(filters, contains(OnlineSourceFilter.maccms));
      expect(filters, contains(OnlineSourceFilter.tvbox));
      expect(filters, contains(OnlineSourceFilter.iptv));
      expect(filters, contains(OnlineSourceFilter.piped));
    });

    testWidgets('Wide desktop viewport (1280x800) has NO left sidebar menu and renders full width',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(
                () => MockPluginsControllerForFilterTest([])),
          ],
          child: const MaterialApp(
            home: OnlineVideoSearchPage(initialPopularVideos: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 断言：左侧侧边栏标题与垂直分割线已被完全移除
      expect(find.text('分类筛选'), findsNothing);
      expect(find.text('视听规则协议 (5类)'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);

      // 断言：搜索框旁边展示「筛选」按钮，点击后展开结构化多维度分类筛选面板
      final filterBtn = find.byKey(const Key('online_search_filter_toggle_btn'));
      expect(filterBtn, findsOneWidget);
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('online_search_filter_panel')), findsOneWidget);
      expect(find.text('视频类型'), findsOneWidget);
      expect(find.text('规则类型'), findsOneWidget);

      for (final filter in OnlineSourceFilter.audiovisualFilters) {
        expect(
          find.byKey(Key('online_search_chip_${filter.id}')),
          findsOneWidget,
          reason: 'Filter chip for ${filter.id} should be visible in filter panel',
        );
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Search executes full parallel requests across all 5 enabled streaming rules',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final queriedPlugins = <String>{};

      final plugins = [
        FakeStreamPlugin(
          name: 'kazumi_src',
          pluginRuleTypeId: 'kazumi',
          onQuery: (kw) async {
            queriedPlugins.add('kazumi');
            return PluginSearchResponse(
              pluginName: 'kazumi_src',
              data: [
                SearchItem(name: 'Kazumi 番剧', src: 'src_1', pic: '', remarks: '更新至12话'),
              ],
            );
          },
        ),
        FakeStreamPlugin(
          name: 'maccms_src',
          pluginRuleTypeId: 'maccms',
          onQuery: (kw) async {
            queriedPlugins.add('maccms');
            return PluginSearchResponse(
              pluginName: 'maccms_src',
              data: [
                SearchItem(name: 'MacCMS 电影', src: 'src_2', pic: '', remarks: 'HD国语'),
              ],
            );
          },
        ),
        FakeStreamPlugin(
          name: 'tvbox_src',
          pluginRuleTypeId: 'tvbox',
          onQuery: (kw) async {
            queriedPlugins.add('tvbox');
            return PluginSearchResponse(
              pluginName: 'tvbox_src',
              data: [
                SearchItem(name: 'TVBox 电视剧', src: 'src_3', pic: '', remarks: '全集'),
              ],
            );
          },
        ),
        FakeStreamPlugin(
          name: 'iptv_src',
          pluginRuleTypeId: 'iptv',
          onQuery: (kw) async {
            queriedPlugins.add('iptv');
            return PluginSearchResponse(
              pluginName: 'iptv_src',
              data: [
                SearchItem(name: 'CCTV-1 综合', src: 'http://live.m3u8', pic: '', remarks: '实时直播'),
              ],
            );
          },
        ),
        FakeStreamPlugin(
          name: 'piped_src',
          pluginRuleTypeId: 'piped',
          onQuery: (kw) async {
            queriedPlugins.add('piped');
            return PluginSearchResponse(
              pluginName: 'piped_src',
              data: [
                SearchItem(name: 'Piped 科技短片', src: 'piped_url', pic: '', remarks: '1080P'),
              ],
            );
          },
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(
              () => MockPluginsControllerForFilterTest(plugins)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnlineVideoSearchPage(initialPopularVideos: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 发起检索
      await tester.enterText(find.byType(TextField), '综合测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // 验证全部 5 类视听规则均被全量并发请求
      expect(queriedPlugins.contains('kazumi'), isTrue);
      expect(queriedPlugins.contains('maccms'), isTrue);
      expect(queriedPlugins.contains('tvbox'), isTrue);
      expect(queriedPlugins.contains('iptv'), isTrue);
      expect(queriedPlugins.contains('piped'), isTrue);

      final state = container.read(onlineVideoSearchProvider);
      // 总计 5 个结果
      expect(state.allResults.length, equals(5));

      // 验证各个分类的数量 Badge 正确计算
      expect(state.countForFilter(OnlineSourceFilter.all), equals(5));
      expect(state.countForFilter(OnlineSourceFilter.video), equals(4)); // 4个点播
      expect(state.countForFilter(OnlineSourceFilter.live), equals(1)); // 1个直播
      expect(state.countForFilter(OnlineSourceFilter.haipee), equals(1));
      expect(state.countForFilter(OnlineSourceFilter.maccms), equals(1));
      expect(state.countForFilter(OnlineSourceFilter.tvbox), equals(1));
      expect(state.countForFilter(OnlineSourceFilter.iptv), equals(1));
      expect(state.countForFilter(OnlineSourceFilter.piped), equals(1));

      // 切换筛选选项完全在前端执行，不发起新的网络请求
      queriedPlugins.clear();

      await tester.tap(find.byKey(const Key('online_search_filter_toggle_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('online_search_chip_maccms')));
      await tester.pumpAndSettle();

      expect(find.text('MacCMS 电影'), findsOneWidget);
      expect(find.text('CCTV-1 综合'), findsNothing);
      expect(queriedPlugins.isEmpty, isTrue); // 没有触发多余网络请求

      await tester.tap(find.byKey(const Key('online_search_chip_iptv')));
      await tester.pumpAndSettle();

      expect(find.text('CCTV-1 综合'), findsOneWidget);
      expect(find.text('MacCMS 电影'), findsNothing);
      expect(queriedPlugins.isEmpty, isTrue); // 依然零多余网络请求

      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    test('Multi-dimensional categorized filter combines 视频类型 (点播/直播), 规则类型, and 来源站点 accurately', () {
      const state = OnlineVideoSearchState(
        keyword: '测试',
        allResults: [
          BiliVideoItem(
            bvid: 'web_baimao_/play/1',
            title: '白猫点播动漫',
            author: 'baimao',
            pic: '',
            duration: 'Haipee规则',
            tag: 'Haipee规则',
          ),
          BiliVideoItem(
            bvid: 'web_fantuan_/play/2',
            title: '饭团点播动漫',
            author: 'fantuan',
            pic: '',
            duration: 'Haipee规则',
            tag: 'Haipee规则',
          ),
          BiliVideoItem(
            bvid: 'web_maccms1_/vod/1',
            title: '苹果CMS点播剧集',
            author: 'maccms1',
            pic: '',
            duration: 'MacCMS',
            tag: 'MacCMS',
          ),
          BiliVideoItem(
            bvid: 'web_iptv1_http://live/1.m3u8',
            title: 'CCTV-6 电影频道',
            author: 'iptv1',
            pic: '',
            duration: '直播流',
            tag: 'IPTV直播',
          ),
        ],
      );

      // 默认全量：4 条，无激活筛选
      expect(state.hasActiveFilter, isFalse);
      expect(state.activeFilterCount, 0);
      expect(state.currentFilteredResults.length, 4);
      expect(state.availableSourceSites.length, 4);

      // 维度 1：仅筛选「点播视频」 -> 排除 IPTV 直播，剩余 3 条点播
      final vodOnly = state.copyWith(videoModeFilter: OnlineSourceFilter.video);
      expect(vodOnly.hasActiveFilter, isTrue);
      expect(vodOnly.activeFilterCount, 1);
      expect(vodOnly.currentFilteredResults.length, 3);

      // 维度 1 + 维度 2：点播视频 + Haipee 规则 -> 剩余 2 条 (baimao, fantuan)
      final vodPlusHaipee = vodOnly.copyWith(
        ruleTypeFilter: OnlineSourceFilter.haipee,
      );
      expect(vodPlusHaipee.activeFilterCount, 2);
      expect(vodPlusHaipee.currentFilteredResults.length, 2);

      // 维度 1 + 维度 2 + 维度 3：点播视频 + Haipee 规则 + 来源站点 baimao -> 精确命中 1 条
      final vodPlusHaipeePlusSite = vodPlusHaipee.copyWith(
        sourceNameFilter: 'baimao',
      );
      expect(vodPlusHaipeePlusSite.activeFilterCount, 3);
      expect(vodPlusHaipeePlusSite.currentFilteredResults.length, 1);
      expect(
        vodPlusHaipeePlusSite.currentFilteredResults.first.title,
        '白猫点播动漫',
      );
    });
  });
}
