import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/cardigann/models/indexer_plugin.dart';
import 'package:kazumi/modules/parse_failure/parse_failure_module.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/online/online_video_search_page.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/providers.dart';
import 'package:kazumi/pages/resource/resource_search_page.dart';
import 'package:kazumi/pages/setting/setting_page.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/utils/storage.dart';

class MockPluginsControllerWithData extends PluginsController {
  final List<Plugin> initialPlugins;
  MockPluginsControllerWithData(this.initialPlugins);

  @override
  PluginsState build() {
    return PluginsState(pluginList: initialPlugins);
  }

  @override
  bool isPluginEnabled(String name) => true;

  @override
  String pluginUpdateStatus(Plugin plugin) => 'latest';
}

class FakeIndexerPluginsNotifierWithData extends IndexerPluginsNotifier {
  final List<IndexerPlugin> _initialPlugins;
  FakeIndexerPluginsNotifierWithData(this._initialPlugins);

  @override
  IndexerPluginState build() {
    return IndexerPluginState(plugins: _initialPlugins, isLoading: false);
  }
}

class _MockPopularController extends PopularController {
  @override
  PopularState build() => PopularState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('rule_center_nav_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ParseFailureRecordAdapter());
    }
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.enableGitProxy, false);
    await box.put(SettingBoxKey.showWindowButton, false);
    await box.put(SettingBoxKey.exitBehavior, 2);
    await box.put(SettingBoxKey.appLocale, 'zh-CN');
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    GStorage.parseFailures =
        await Hive.openBox<ParseFailureRecord>('parseFailures');
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

  group('Decoupled Rule Architecture and Navigation Tests', () {
    testWidgets('SettingPage has strictly separated rules without redundant rule center',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              navigatorObservers: [KazumiDialog.observer],
              home: const SettingPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证“统一规则管理中心”冗余项已被彻底移除
      expect(find.text('统一规则管理中心'), findsNothing);

      // 2. 验证“视听与在线媒体 (点播与直播)”中分别包含“在线视频规则”与“电视直播规则”独立入口
      expect(find.text('视听与在线媒体 (点播与直播)'), findsOneWidget);
      expect(find.text('在线视频规则'), findsOneWidget);
      expect(find.text('电视直播规则'), findsOneWidget);

      // 3. 验证“资源检索与下载 (网盘与BT)”中保留“BT / 磁力下载规则”
      expect(find.text('资源检索与下载 (网盘与BT)'), findsOneWidget);
      expect(find.text('BT / 磁力下载规则'), findsOneWidget);
    });

    testWidgets('OnlineVideoSearchPage has dedicated contextual rule button for Kazumi video rules',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginsProvider.overrideWith(() => MockPluginsControllerWithData([])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Kazumi 视频规则'), findsOneWidget);
      expect(find.byTooltip('规则管理中心'), findsNothing);
    });

    testWidgets('ResourceSearchPage has dedicated contextual rule button for Cardigann rules',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            popularProvider.overrideWith(() => _MockPopularController()),
            indexerPluginsProvider
                .overrideWith(() => FakeIndexerPluginsNotifierWithData([])),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: ResourceSearchPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Cardigann 规则'), findsOneWidget);
      expect(find.byTooltip('规则管理中心'), findsNothing);
    });
  });

  group('Universal 5-Tab Navigation Architecture Tests', () {
    testWidgets('ScaffoldMenu displays all 5 top-level search and media destinations',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: const MaterialApp(
              home: ScaffoldMenu(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 5 大一级主导航
      final tabs = AppLocale.zhCn.translations.navigation.tabs;
      expect(find.text(tabs.media), findsOneWidget);       // [ 🌐 在线视频 ]
      expect(find.text(tabs.resource), findsOneWidget);    // [ 🧲 全网资源 ]
      expect(find.text(tabs.my), findsOneWidget);          // [ 📺 媒体库 ]
      expect(find.text(tabs.download), findsOneWidget);    // [ 📥 任务与下载 ]
      expect(find.text(tabs.settings), findsOneWidget);    // [ ⚙️ 设置 ]

      // 验证初始选中第 0 项 (在线视频: Icons.language)
      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.byIcon(Icons.travel_explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    });

    testWidgets('NavigationProvider manages 5 tabs with bounds safety', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationProvider).selectedIndex, equals(0));

      container.read(navigationProvider.notifier).updateSelectedIndex(1);
      expect(container.read(navigationProvider).selectedIndex, equals(1));

      container.read(navigationProvider.notifier).updateSelectedIndex(4);
      expect(container.read(navigationProvider).selectedIndex, equals(4));

      // 验证根据路由同步索引
      container.read(navigationProvider.notifier).syncWithRoute('/tab/resource');
      expect(container.read(navigationProvider).selectedIndex, equals(1));

      container.read(navigationProvider.notifier).syncWithRoute('/settings');
      expect(container.read(navigationProvider).selectedIndex, equals(4));
    });
  });
}
