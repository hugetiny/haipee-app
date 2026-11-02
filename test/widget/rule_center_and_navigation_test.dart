import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/pages/menu/menu.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/pages/resource/resource_search_page.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';

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
              navigatorObservers: [HaipeeDialog.observer],
              home: const SettingPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证“统一规则管理中心”冗余项已被彻底移除
      expect(find.text('统一规则管理中心'), findsNothing);

      // 2. 验证“资源”分类严格遵循 Kazumi 原生规范：仅保留规则管理与下载设置两大顶级入口
      expect(find.text('资源'), findsOneWidget);
      expect(find.byKey(const Key('setting_rule_all')), findsOneWidget);
      expect(find.text('规则管理'), findsOneWidget);
      expect(find.byKey(const Key('setting_download_settings')), findsOneWidget);
      expect(find.text('下载设置'), findsOneWidget);
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

      expect(find.byTooltip('Haipee 视频规则'), findsOneWidget);
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
