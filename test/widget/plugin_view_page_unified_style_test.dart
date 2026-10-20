import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/rule/unified_rule_card.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/parse_failure/parse_failure_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/utils/storage.dart';

class MockPluginsControllerWithPlugins extends PluginsController {
  final List<Plugin> initialPlugins;
  MockPluginsControllerWithPlugins(this.initialPlugins);

  @override
  PluginsState build() {
    return PluginsState(pluginList: initialPlugins);
  }

  @override
  String pluginUpdateStatus(Plugin plugin) => 'latest';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('plugin_view_page_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ParseFailureRecordAdapter());
    }
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.enableGitProxy, false);
    GStorage.setting = box;
    GStorage.parseFailures =
        await Hive.openBox<ParseFailureRecord>('parseFailures');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  final dummyPlugins = [
    Plugin(
      name: 'AnimeTest One',
      version: '1.2.0',
      type: 'xpath',
      api: 'https://animetest.one',
      baseUrl: 'https://animetest.one',
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
      name: 'MacCms Film Hub',
      version: '2.0.1',
      type: 'maccms',
      api: 'https://maccms.film',
      baseUrl: 'https://maccms.film',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: false,
      useWebview: true,
      useNativePlayer: false,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    ),
  ];

  Widget buildTestApp({List<Plugin> plugins = const []}) {
    return ProviderScope(
      overrides: [
        pluginsProvider.overrideWith(
          () => MockPluginsControllerWithPlugins(plugins),
        ),
      ],
      child: TranslationProvider(
        child: const MaterialApp(
          home: PluginViewPage(),
        ),
      ),
    );
  }

  group('PluginViewPage Unified Settings Style Tests', () {
    testWidgets('Empty state displays standard clean empty state',
        (tester) async {
      await tester.pumpWidget(buildTestApp(plugins: []));
      await tester.pumpAndSettle();

      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.text('暂无 Kazumi 视频规则'), findsOneWidget);
      expect(find.text('载入并测速精选规则'), findsOneWidget);
      expect(find.text('前往 Kazumi 规则源'), findsOneWidget);
    });

    testWidgets(
        'Wide screen renders TabBar, L2 toolbar and UnifiedRuleGrid with UnifiedRuleCard',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.byType(SysAppBar), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(UnifiedRuleGrid), findsOneWidget);
      expect(find.byType(UnifiedRuleCard), findsNWidgets(2));

      // Verify category navigation tabs (strictly 2 tabs: 全部 and Kazumi 规则源)
      expect(find.text('全部'), findsWidgets);
      expect(find.text('Kazumi 规则源'), findsOneWidget);
      expect(find.text('动漫番剧'), findsNothing);
      expect(find.text('影视剧集'), findsNothing);
      expect(find.text('网页解析'), findsNothing);

      // Verify plugin rows and badges
      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsOneWidget);
      expect(find.text('XPATH'), findsOneWidget);
      expect(find.text('MACCMS'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('v2.0.1'), findsOneWidget);
      expect(find.text('测速'), findsNWidgets(2));
      expect(find.text('查看/编辑规则'), findsNWidgets(2));
      expect(find.text('测试抓取 (Dry-Run)'), findsNWidgets(2));
      expect(find.text('在线更新'), findsNWidgets(2));
      expect(find.text('分享口令'), findsNWidgets(2));
    });

    testWidgets(
        'Narrow screen renders responsive single-column UnifiedRuleGrid with full badges and action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(550, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      expect(find.byType(PluginViewPage), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(UnifiedRuleGrid), findsOneWidget);
      expect(find.byType(UnifiedRuleCard), findsNWidgets(2));

      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsOneWidget);
      expect(find.text('测速'), findsNWidgets(2));
      expect(find.text('查看/编辑规则'), findsNWidgets(2));
      expect(find.text('测试抓取 (Dry-Run)'), findsNWidgets(2));
      expect(find.text('在线更新'), findsNWidgets(2));
      expect(find.text('分享口令'), findsNWidgets(2));
    });

    testWidgets('Long press on card enters multi-select mode and close exits',
        (tester) async {
      tester.view.physicalSize = const Size(550, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      // Long press first item card to enter multi-select
      final firstItem = find.text('AnimeTest One');
      expect(firstItem, findsOneWidget);
      await tester.longPress(firstItem);
      await tester.pumpAndSettle();

      // In multi-select mode, app bar title updates to selection count and close icon appears
      expect(find.text('已选择 1 项'), findsOneWidget);
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      // Tap close to exit multi-select mode
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsNothing);
      expect(find.text('Kazumi 视频规则'), findsOneWidget);
    });

    testWidgets('L2 filter chips filter rule grid items accurately',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsOneWidget);

      // Filter by XPath type
      final xpathChip = find.text('网页 XPath');
      expect(xpathChip, findsOneWidget);
      await tester.tap(xpathChip);
      await tester.pumpAndSettle();

      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsNothing);

      // Reset to all
      final allTypeChip = find.widgetWithText(FilterChip, '全部');
      await tester.tap(allTypeChip.first);
      await tester.pumpAndSettle();

      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsOneWidget);
    });

    testWidgets('Search box filters plugins dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Film Hub');
      await tester.pumpAndSettle();

      expect(find.text('AnimeTest One'), findsNothing);
      expect(find.text('MacCms Film Hub'), findsOneWidget);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('AnimeTest One'), findsOneWidget);
      expect(find.text('MacCms Film Hub'), findsOneWidget);
    });

    testWidgets(
        'Switching to Kazumi 规则源 tab updates AppBar actions and displays market catalog',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(plugins: dummyPlugins));
      await tester.pumpAndSettle();

      // In Tab 1 (全部), AppBar shows '导入规则'
      expect(find.text('导入规则'), findsOneWidget);
      expect(find.text('一键载入并测速全部规则'), findsNothing);

      // Tap on Tab 2: Kazumi 规则源
      final marketTab = find.text('Kazumi 规则源');
      expect(marketTab, findsOneWidget);
      await tester.tap(marketTab);
      await tester.pumpAndSettle();

      // In Tab 2 (Kazumi 规则源), AppBar dynamically switches to '一键载入并测速全部规则' and '刷新规则市场'
      expect(find.text('一键载入并测速全部规则'), findsOneWidget);
      expect(find.text('导入规则'), findsNothing);
      expect(find.byTooltip('刷新规则市场'), findsOneWidget);
    });
  });
}
