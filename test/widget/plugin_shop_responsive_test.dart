import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/widget/adaptive_data_view.dart';
import 'package:haipee/modules/plugin/plugin_http_module.dart';
import 'package:haipee/pages/plugin_editor/plugin_shop_page.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/utils/storage.dart';

class MockPluginsController extends PluginsController {
  final List<PluginHTTPItem> mockItems;
  MockPluginsController(this.mockItems);

  @override
  PluginsState build() {
    return PluginsState(pluginHTTPList: mockItems);
  }

  @override
  String pluginStatus(PluginHTTPItem plugin) => 'install';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_shop_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.enableGitProxy, false);
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

  final dummyList = [
    PluginHTTPItem(
      name: 'AnimeOne 超长测试视频源解析规则名称以检验文本截断与自适应排版',
      version: '1.2.3',
      lastUpdate: 1710000000000,
      useNativePlayer: true,
      author: 'Author A',
    ),
    PluginHTTPItem(
      name: 'BiliPlus Special Collector',
      version: '2.0.0',
      lastUpdate: 1710100000000,
      useNativePlayer: false,
      author: 'Author B',
    ),
    PluginHTTPItem(
      name: 'MACCMS Global Source',
      version: '3.1.4',
      lastUpdate: 1710200000000,
      useNativePlayer: true,
      author: 'Author C',
    ),
  ];

  Widget buildTestApp({required Size surfaceSize}) {
    return ProviderScope(
      overrides: [
        pluginsProvider.overrideWith(() => MockPluginsController(dummyList)),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: surfaceSize),
            child: const PluginShopPage(),
          ),
        ),
      ),
    );
  }

  group('PluginShopPage Responsive & Zero Overflow Tests', () {
    testWidgets('Mobile viewport (360x700) renders card list via AdaptiveDataView with 0 overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(surfaceSize: const Size(360, 700)));
      await tester.pumpAndSettle();

      expect(find.byType(PluginShopPage), findsOneWidget);
      expect(find.byType(AdaptiveDataView), findsOneWidget);
      // In mobile mode, AdaptiveDataView renders ListView of cards
      expect(find.byType(ListView), findsWidgets);
      expect(find.textContaining('AnimeOne'), findsOneWidget);
    });

    testWidgets('Desktop wide viewport (1440x900) renders multi-column DataTable via AdaptiveDataView',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(surfaceSize: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(find.byType(PluginShopPage), findsOneWidget);
      expect(find.byType(AdaptiveDataView), findsOneWidget);
      // In wide mode (width >= 720), AdaptiveDataView renders multi-column DataTable
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.textContaining('AnimeOne'), findsOneWidget);
      expect(find.byType(AdaptiveViewSwitcher), findsOneWidget);
    });
  });
}
