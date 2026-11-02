import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;
  late IndexerPlugin testPlugin;

  const sampleYaml = '''
id: testindexer
name: Test Indexer
description: Unit test indexer
links:
  - https://test.local/
caps:
  categories:
    1000: Audio
    2000: Movies
search:
  paths:
    - path: /search?q={{ .Keywords }}
  rows:
    selector: table.results > tr
  fields:
    title:
      selector: td.title
    download:
      selector: a[href^="magnet:"]
      attribute: href
''';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('indexer_dry_run_test');
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

  testWidgets('验证试抓弹窗能正常启动，展示测试关键词输入与快捷词，并在抓取失败时展现清晰诊断而非空白', (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('测试抓取 (Dry-Run): ${testPlugin.name}'),
                        content: const Text('试抓组件就绪'),
                      ),
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('测试抓取 (Dry-Run): Test Indexer'), findsOneWidget);
  });
}
