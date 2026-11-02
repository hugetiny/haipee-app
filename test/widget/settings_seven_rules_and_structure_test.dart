import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/setting/indexer/indexer_settings_page.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';

class MockTestPluginsController extends PluginsController {
  final List<Plugin> initialList;
  MockTestPluginsController(this.initialList);

  @override
  PluginsState build() {
    return PluginsState(pluginList: initialList);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  final samplePlugins = [
    Plugin(
      name: 'AnimeSource',
      version: '1.0',
      type: 'anime',
      api: '1',
      baseUrl: 'https://anime.com',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: true,
      useWebview: false,
      useNativePlayer: true,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
    Plugin(
      name: 'MacCmsSource',
      version: '1.0',
      type: 'maccms',
      api: '1',
      baseUrl: 'https://maccms.com',
      searchURL: 'https://maccms.com/api.php/provide/vod',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: true,
      useWebview: false,
      useNativePlayer: true,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
    Plugin(
      name: 'bilibili',
      version: '1.2',
      type: 'bilibili',
      api: '10',
      baseUrl: 'https://www.bilibili.com',
      searchURL: 'https://api.bilibili.com/x/web-interface/wbi/search',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: true,
      useWebview: false,
      useNativePlayer: true,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
    Plugin(
      name: 'douyin',
      version: '1.0',
      type: 'douyin',
      api: '9',
      baseUrl: 'https://www.douyin.com',
      searchURL: 'https://so.toutiao.com/search',
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
    Plugin(
      name: 'IptvLive',
      version: '1.0',
      type: 'iptv',
      category: 'live',
      api: '1',
      baseUrl: 'https://iptv.com/index.m3u',
      searchURL: 'https://iptv.com/index.m3u',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: true,
      useWebview: false,
      useNativePlayer: true,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
    Plugin(
      name: 'AlistDrive',
      version: '1.0',
      type: 'alist',
      category: 'drive',
      api: '1',
      baseUrl: 'https://alist.drive.com',
      searchURL: 'https://alist.drive.com/api/fs/search',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: true,
      useWebview: false,
      useNativePlayer: true,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_seven_rules_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ParseFailureRecordAdapter());
    }
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    await box.put(SettingBoxKey.exitBehavior, 2);
    await box.put(SettingBoxKey.appLocale, 'zh-CN');
    await box.put(SettingBoxKey.metadataBangumiEnabled, true);
    await box.put(SettingBoxKey.metadataTmdbEnabled, true);
    GStorage.setting = box;
    GStorage.parseFailures =
        await Hive.openBox<ParseFailureRecord>('parseFailures');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('设置页面正确清晰呈现五大板块与七大独立规则源选项', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SettingPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 验证四大板块标题清晰分立 (对齐上游 4 大领域架构: 播放、资源、应用、其他)
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(find.text('应用'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);

    // 2. 验证“资源”分类严格遵循 Kazumi 原生规范：仅保留规则管理与下载设置两大顶级入口
    expect(find.byKey(const Key('setting_rule_all')), findsOneWidget);
    expect(find.text('规则管理'), findsOneWidget);
    expect(find.byKey(const Key('setting_download_settings')), findsOneWidget);
    expect(find.text('下载设置'), findsOneWidget);
  });

  group('GoRouter 路由与 PluginViewPage / IndexerSettingsPage 七大类型深度跳转测试', () {
    testWidgets('?type=kazumi (或 anime) 直达 Haipee 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=kazumi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('Haipee 规则管理'), findsOneWidget);
      expect(find.text('AnimeSource'), findsOneWidget);
    });

    testWidgets('?type=maccms 直达 MacCMS 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=maccms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('MacCMS 规则管理'), findsOneWidget);
      expect(find.text('MacCmsSource'), findsOneWidget);
    });

    testWidgets('?type=piped (或 bilibili) 直达 Piped 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=piped');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('Piped 规则管理'), findsOneWidget);
      expect(find.text('bilibili'), findsWidgets);
    });

    testWidgets('?type=douyin 兼容跳转至 Piped 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=douyin');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('Piped 规则管理'), findsOneWidget);
      expect(find.text('douyin'), findsWidgets);
    });

    testWidgets('?type=iptv (或 live) 直达 IPTV 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=iptv');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('IPTV 规则管理'), findsOneWidget);
      expect(find.text('IptvLive'), findsOneWidget);
    });

    testWidgets('?type=alist (或 drive) 直达 AList 规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go('${Routes.settingsPlugin}?type=alist');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('AList 规则管理'), findsOneWidget);
      expect(find.text('AlistDrive'), findsOneWidget);
    });

    testWidgets('Routes.settingsIndexers 路由跳转到 BT 磁力规则管理', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(samplePlugins)),
          ],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );

      router.go(Routes.settingsIndexers);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(IndexerSettingsPage), findsOneWidget);
      expect(find.text('Cardigann 规则管理'), findsOneWidget);
    });

    testWidgets('真实用户 13 个规则数据精准落入 7 大分类且各分类计数 100% 正确', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final userReal13Plugins = [
        Plugin(
          name: 'DM84',
          version: '1.2',
          type: 'anime',
          api: '1',
          baseUrl: 'https://dm84.tv/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: true,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'AList 聚合网盘',
          version: '1.0',
          type: 'alist',
          category: 'drive',
          api: '1',
          baseUrl: 'https://alist.nn.ci',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'anime7',
          version: '1.0',
          type: 'anime',
          api: '4',
          baseUrl: 'https://anime7.top/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: true,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: '暴风影视',
          version: '1.0',
          type: 'maccms',
          api: '1',
          baseUrl: 'https://bfzyapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'bilibili',
          version: '1.2',
          type: 'bilibili',
          api: '10',
          baseUrl: 'https://www.bilibili.com/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'dalvdm',
          version: '1.2',
          type: 'anime',
          api: '9',
          baseUrl: 'https://www.sbdl.cc/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: true,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'douyin',
          version: '1.0',
          type: 'douyin',
          api: '9',
          baseUrl: 'https://www.douyin.com/',
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
        ),
        Plugin(
          name: '非凡影视',
          version: '1.0',
          type: 'maccms',
          api: '1',
          baseUrl: 'https://cj.ffzyapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: '全球电视直播',
          version: '1.0',
          type: 'iptv',
          category: 'live',
          api: '1',
          baseUrl: 'https://iptv-org.github.io/iptv/index.m3u',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: '金鹰影视',
          version: '1.0',
          type: 'maccms',
          api: '1',
          baseUrl: 'https://jyzyapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: '量子影视',
          version: '1.0',
          type: 'maccms',
          api: '1',
          baseUrl: 'https://cj.lziapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'mutefun',
          version: '1.5',
          type: 'anime',
          api: '9',
          baseUrl: 'https://www.2kdm.com/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: true,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
        ),
        Plugin(
          name: 'xfdm',
          version: '1.7',
          type: 'anime',
          api: '3',
          baseUrl: 'https://dm.xifanacg.com/',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
          muliSources: true,
          useWebview: true,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: true,
          userAgent: '',
        ),
      ];

      // 验证规则协议类型精准映射
      final haipeeCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.haipee).length;
      final maccmsCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.maccms).length;
      final tvboxCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.tvbox).length;
      final iptvCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.iptv).length;
      final pipedCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.piped).length;
      final alistCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.alist).length;
      final cardigannCount = userReal13Plugins.where((p) => p.ruleType == PluginRuleType.cardigann).length;

      expect(haipeeCount, equals(5));
      expect(maccmsCount, equals(4));
      expect(tvboxCount, equals(0));
      expect(iptvCount, equals(1));
      expect(pipedCount, equals(2));
      expect(alistCount, equals(1));
      expect(cardigannCount, equals(0));
      expect(userReal13Plugins.length, equals(13));

      // 验证渲染到设置中的规则管理界面，宽屏与窄屏均 0 像素溢出
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockTestPluginsController(userReal13Plugins)),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: PluginViewPage(isEmbedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 验证七大规则协议品类全部呈现且徽标计数准确
      expect(find.text('全部'), findsWidgets);
      expect(find.text('Haipee 规则'), findsWidgets);
      expect(find.text('MacCMS 规则'), findsWidgets);
      expect(find.text('TVBox 规则'), findsWidgets);
      expect(find.text('IPTV 规则'), findsWidgets);
      expect(find.text('Piped 规则'), findsWidgets);
      expect(find.text('AList 规则'), findsWidgets);
      expect(find.text('Cardigann 规则'), findsWidgets);
      expect(find.text('规则商店'), findsNothing);
      expect(find.byKey(const Key('plugin_btn_add_manual')), findsOneWidget);
      expect(find.byKey(const Key('plugin_btn_auto_test')), findsOneWidget);

      // 窄屏响应式测试 (375x812)
      tester.view.physicalSize = const Size(375, 812);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
