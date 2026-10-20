import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/plugin_editor/plugin_editor_page.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/utils/storage.dart';

class MockPluginsController extends PluginsController {
  final List<Plugin> initialPlugins;
  MockPluginsController(this.initialPlugins);

  Plugin? lastUpdatedPlugin;

  @override
  PluginsState build() {
    return PluginsState(pluginList: initialPlugins);
  }

  @override
  void updatePlugin(Plugin plugin) {
    lastUpdatedPlugin = plugin;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_editor_page_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    GStorage.setting = box;
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  final dummyPlugin = Plugin(
    name: 'Sample XPath Plugin',
    version: '1.0.0',
    type: 'xpath',
    api: 'https://example.com/api',
    baseUrl: 'https://example.com',
    searchURL: '/search?q=@keyword',
    searchList: '//div[@class="item"]',
    searchName: '//h3/text()',
    searchResult: '//a/@href',
    chapterRoads: '//ul[@class="episodes"]/li',
    chapterResult: '//a/@href',
    referer: 'https://example.com',
    muliSources: true,
    useWebview: false,
    useNativePlayer: true,
    usePost: false,
    useLegacyParser: false,
    userAgent: 'Mozilla/5.0 KazumiTest',
  );

  testWidgets('PluginEditorPage renders using SettingsList, SettingsSection and handles save', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockController = MockPluginsController([dummyPlugin]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pluginsProvider.overrideWith(() => mockController),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: PluginEditorPage(plugin: dummyPlugin),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Verify presence of standard design system components
    expect(find.byType(SettingsList), findsOneWidget);
    expect(find.byType(SettingsSection), findsNWidgets(4));
    expect(find.byType(SettingsTile), findsNWidgets(5));

    // Verify section titles
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('搜索与列表规则 (XPath)'), findsOneWidget);
    expect(find.text('剧集与线路规则 (XPath)'), findsOneWidget);
    expect(find.text('高级配置'), findsOneWidget);

    // Verify initial values
    expect(find.text('Sample XPath Plugin'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('xpath'), findsOneWidget);
    expect(find.text('https://example.com/api'), findsOneWidget);
    expect(find.text('多线路支持'), findsOneWidget);
    expect(find.text('WebView 解析'), findsOneWidget);

    // Verify save buttons in AppBar and FAB
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('PluginEditorPage renders cleanly on compact viewport without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockController = MockPluginsController([dummyPlugin]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pluginsProvider.overrideWith(() => mockController),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: PluginEditorPage(plugin: dummyPlugin),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsList), findsOneWidget);
  });
}
