import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/modules/torrent_search/widgets/selective_download_dialog.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/bean/card/bangumi_info_card.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/pages/download/download_task_detail_dialog.dart';
import 'package:haipee/pages/download/widgets/add_download_dialog.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/utils/storage.dart';

class _FakeIndexerPluginsNotifier extends IndexerPluginsNotifier {
  final List<IndexerPlugin> _initialPlugins;
  _FakeIndexerPluginsNotifier(this._initialPlugins);

  @override
  IndexerPluginState build() {
    return IndexerPluginState(plugins: _initialPlugins, isLoading: false);
  }
}

class _FakePluginsController extends PluginsController {
  final List<Plugin> _initialPlugins;
  _FakePluginsController(this._initialPlugins);

  @override
  PluginsState build() {
    return PluginsState(pluginList: _initialPlugins);
  }
}

void main() {
  late Directory tempDir;

  const sampleYaml = '''
id: testmikan
name: Mikan 蜜柑计划
description: Mikan Project RSS
links:
  - https://mikanani.me/
caps:
  categories:
    5070: Anime
search:
  paths:
    - path: /RSS/Search?searchstr={{ .Keywords }}
  rows:
    selector: item
  fields:
    title:
      selector: title
    download:
      selector: enclosure
      attribute: url
''';

  final sampleVideoPlugin = Plugin(
    api: '4',
    type: 'anime',
    name: 'anime7',
    version: '1.0',
    muliSources: true,
    useWebview: true,
    useNativePlayer: true,
    usePost: false,
    useLegacyParser: false,
    userAgent: '',
    baseUrl: 'https://anime7.top/',
    searchURL: 'https://anime7.top/vod-search/?wd=@keyword&submit=',
    searchList: '//div/ul/li',
    searchName: '//a',
    searchResult: '//a',
    chapterRoads: '//ul',
    chapterResult: '//li/a',
    referer: 'https://anime7.top/',
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp
        .createTemp('app_responsive_overflow_smoke_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(BangumiItemAdapter().typeId)) {
      Hive.registerAdapter(BangumiItemAdapter());
    }
    if (!Hive.isAdapterRegistered(BangumiTagAdapter().typeId)) {
      Hive.registerAdapter(BangumiTagAdapter());
    }
    if (!Hive.isAdapterRegistered(CollectedBangumiAdapter().typeId)) {
      Hive.registerAdapter(CollectedBangumiAdapter());
    }
    if (!Hive.isAdapterRegistered(ProgressAdapter().typeId)) {
      Hive.registerAdapter(ProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(ParseFailureRecordAdapter().typeId)) {
      Hive.registerAdapter(ParseFailureRecordAdapter());
    }
    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles');
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

  const testViewports = [
    Size(360, 640), // 1. 超窄移动端 (低端小屏手机)
    Size(600, 800), // 2. 紧凑平板 / 手机横屏 / 桌面极窄视口
    Size(800, 600), // 3. 常见小窗口桌面 (800x600 窗口模式)
    Size(1280, 860), // 4. 标准桌面窗口
  ];

  for (final viewport in testViewports) {
    testWidgets(
      '验证 SettingPage 设置中心在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testIndexer = IndexerPlugin.fromYaml(sampleYaml);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              indexerPluginsProvider.overrideWith(
                () => _FakeIndexerPluginsNotifier([testIndexer]),
              ),
              pluginsProvider.overrideWith(
                () => _FakePluginsController([sampleVideoPlugin]),
              ),
            ],
            child: TranslationProvider(
              child: const MaterialApp(
                home: SettingPage(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 核心断言：无论在何种视口下，均不得抛出 RenderFlex overflow 或任何未捕获异常
        expect(tester.takeException(), isNull);
        expect(find.byType(SettingPage), findsOneWidget);
      },
    );

    testWidgets(
      '验证 PluginViewPage (规则管理与空状态) 在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final testIndexer = IndexerPlugin.fromYaml(sampleYaml);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              indexerPluginsProvider.overrideWith(
                () => _FakeIndexerPluginsNotifier([testIndexer]),
              ),
              pluginsProvider.overrideWith(
                () => _FakePluginsController([sampleVideoPlugin]),
              ),
            ],
            child: TranslationProvider(
              child: const MaterialApp(
                home: PluginViewPage(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证在线视频源规则渲染无溢出
        expect(tester.takeException(), isNull);
        expect(find.byType(PluginViewPage), findsOneWidget);
        expect(find.text('anime7'), findsOneWidget);
      },
    );

    testWidgets(
      '验证 SelectiveDownloadDialog (迅雷风格三联文件树弹窗) 在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleFiles = [
          TorrentFileEntry(
            index: 1,
            path: 'Season 1/Episode 01 [1080P].mp4',
            name: 'Episode 01 [1080P].mp4',
            pathSegments: ['Season 1', 'Episode 01 [1080P].mp4'],
            sizeBytes: 1024 * 1024 * 500,
            isSelected: true,
          ),
          TorrentFileEntry(
            index: 2,
            path: 'Season 1/Episode 02 [1080P].mp4',
            name: 'Episode 02 [1080P].mp4',
            pathSegments: ['Season 1', 'Episode 02 [1080P].mp4'],
            sizeBytes: 1024 * 1024 * 510,
            isSelected: false,
          ),
          TorrentFileEntry(
            index: 3,
            path: 'OST/Theme Song Lossless.flac',
            name: 'Theme Song Lossless.flac',
            pathSegments: ['OST', 'Theme Song Lossless.flac'],
            sizeBytes: 1024 * 1024 * 45,
            isSelected: true,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SelectiveDownloadDialog.show(
                        context,
                        title: '葬送的芙莉莲 S01 完整合集 [Baha][1080P]',
                        files: sampleFiles,
                        onConfirm: (indices, path) async {},
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SelectiveDownloadDialog), findsOneWidget);
        expect(find.text('新建下载 - 选择下载文件'), findsOneWidget);
        expect(find.text('全选'), findsOneWidget);

        // 点击全选芯片并再次验证
        await tester.tap(find.widgetWithText(ActionChip, '全选'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '验证 BangumiInfoCardV 在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleBangumi = BangumiItem(
          id: 12345,
          type: 2,
          name: 'Sousou no Frieren Season 2 Extra Edition',
          nameCn: '葬送的芙莉莲 第二季 勇者欣梅尔的回忆与北方诸国旅途篇 剧场先行版 超长标题测试',
          summary: '这是魔王被打倒之后的世界。千年精灵芙莉莲与新伙伴们继续踏上前往灵魂长眠之地的漫长旅途。',
          airDate: '2024-01-05',
          airWeekday: 5,
          rank: 1,
          images: {'large': ''},
          tags: [],
          alias: [],
          ratingScore: 9.3,
          votes: 45210,
          votesCount: [10, 20, 30, 40, 50, 60, 100, 500, 1200, 5000],
          info: '全28话 / 2024年1月 / Madhouse',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: viewport.width,
                      child: BangumiInfoCardV(
                        bangumiItem: sampleBangumi,
                        isLoading: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BangumiInfoCardV), findsOneWidget);
      },
    );

    testWidgets(
      '验证 DownloadTaskDetailDialog 在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleTask = DownloadTask(
          gid: 'test-gid-${viewport.width.toInt()}',
          url: 'https://example.com/anime.mp4',
          title: '葬送的芙莉莲 第01话 冒险的终点与起点 [1080P].mp4',
          fileName: '葬送的芙莉莲 第01话 冒险的终点与起点 [1080P].mp4',
          totalLength: 1024 * 1024 * 500,
          completedLength: 1024 * 1024 * 250,
          downloadSpeed: 1024 * 1024 * 5,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => DownloadTaskDetailDialog(
                          task: sampleTask,
                        ),
                      );
                    },
                    child: const Text('Open Detail Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Detail Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DownloadTaskDetailDialog), findsOneWidget);
      },
    );

    testWidgets(
      '验证 AddDownloadDialog 在视口 (${viewport.width.toInt()}x${viewport.height.toInt()}) 下 0 像素溢出',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const AddDownloadDialog(),
                      );
                    },
                    child: const Text('Open Add Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Add Dialog'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AddDownloadDialog), findsOneWidget);
      },
    );
  }
}
