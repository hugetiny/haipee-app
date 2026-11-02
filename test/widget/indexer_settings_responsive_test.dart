import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/widget/rule/unified_rule_card.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/pages/setting/indexer/indexer_settings_page.dart';
import 'package:haipee/utils/storage.dart';

class FakeIndexerPluginsNotifier extends IndexerPluginsNotifier {
  final List<IndexerPlugin> _initialPlugins;
  FakeIndexerPluginsNotifier(this._initialPlugins);

  @override
  IndexerPluginState build() {
    return IndexerPluginState(plugins: _initialPlugins, isLoading: false);
  }
}

void main() {
  late Directory tempDir;
  late IndexerPlugin testPlugin;

  const sampleYaml = '''
id: testnyaa
name: Nyaa 动漫规则
description: Nyaa anime indexer definition
links:
  - https://nyaa.si/
caps:
  categories:
    5070: Anime
search:
  paths:
    - path: /?f=0&c=0_0&q={{ .Keywords }}
  rows:
    selector: table.torrent-list > tbody > tr
  fields:
    title:
      selector: td:nth-child(2) a:not(.comments)
    download:
      selector: td:nth-child(3) a[href^="magnet:"]
      attribute: href
''';

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('indexer_responsive_test');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    GStorage.setting = box;
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    LocaleSettings.setLocale(AppLocale.zhCn);

    testPlugin = IndexerPlugin.fromYaml(sampleYaml);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('验证 Cardigann 规则管理在宽屏与窄屏均采用统一自适应网格 (UnifiedRuleGrid + UnifiedRuleCard)，所有信息与操作完整呈现',
      (tester) async {
    // 1. 初始化为大屏 (1440x900)
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          indexerPluginsProvider.overrideWith(
            () => FakeIndexerPluginsNotifier([testPlugin]),
          ),
        ],
        child: const MaterialApp(
          home: IndexerSettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 检查是否有任何 RenderFlex overflow 或其他异常
    expect(tester.takeException(), isNull);

    // 宽屏下不占用左侧空间（无 NavigationRail 二级侧边栏，无冗余规则市场二级 Tab），呈现 L2 工具栏与自适应网格视图
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('规则市场 (577+)'), findsNothing);
    expect(find.byKey(const Key('cardigann_btn_add_manual')), findsOneWidget);
    expect(find.byKey(const Key('cardigann_btn_import')), findsOneWidget);
    expect(find.byKey(const Key('cardigann_btn_auto_test')), findsOneWidget);
    expect(find.byType(UnifiedRuleGrid), findsOneWidget);
    expect(find.byType(UnifiedRuleCard), findsOneWidget);
    expect(find.text('Nyaa 动漫规则'), findsOneWidget);
    expect(find.text('testnyaa'), findsOneWidget);
    expect(find.text('https://nyaa.si/'), findsOneWidget);
    expect(find.text('Nyaa anime indexer definition'), findsOneWidget);
    expect(find.text('测速'), findsOneWidget);
    expect(find.text('查看/编辑 YAML 源码'), findsOneWidget);
    expect(find.text('测试抓取 (Dry-Run)'), findsOneWidget);
    expect(find.text('站点官网'), findsOneWidget);
    expect(find.text('YAML 来源'), findsOneWidget);

    // 2. 动态调整尺寸至窄屏 (550x800)
    tester.view.physicalSize = const Size(550, 800);
    await tester.pumpAndSettle();

    // 窄屏下单列平滑自适应，所有信息与按钮完整呈现，绝不截断
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('cardigann_btn_add_manual')), findsOneWidget);
    expect(find.byKey(const Key('cardigann_btn_import')), findsOneWidget);
    expect(find.byKey(const Key('cardigann_btn_auto_test')), findsOneWidget);
    expect(find.byType(UnifiedRuleGrid), findsOneWidget);
    expect(find.byType(UnifiedRuleCard), findsOneWidget);
    expect(find.text('Nyaa 动漫规则'), findsOneWidget);
    expect(find.text('testnyaa'), findsOneWidget);
    expect(find.text('https://nyaa.si/'), findsOneWidget);
    expect(find.text('Nyaa anime indexer definition'), findsOneWidget);
    expect(find.text('测速'), findsOneWidget);
    expect(find.text('查看/编辑 YAML 源码'), findsOneWidget);
    expect(find.text('测试抓取 (Dry-Run)'), findsOneWidget);
    expect(find.text('站点官网'), findsOneWidget);
    expect(find.text('YAML 来源'), findsOneWidget);
  });
}
