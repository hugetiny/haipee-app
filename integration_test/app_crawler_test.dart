import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/parse_failure/parse_failure_module.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/download/gopeed/gopeed_service.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/storage.dart';
import '../test/integration/robots/log_watcher_robot.dart';
import '../test/integration/robots/navigation_robot.dart';
import '../test/integration/robots/search_and_download_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LogWatcherRobot logWatcher;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('app_crawler_integration_test');
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
    if (!Hive.isAdapterRegistered(SearchHistoryAdapter().typeId)) {
      Hive.registerAdapter(SearchHistoryAdapter());
    }
    if (!Hive.isAdapterRegistered(HistoryAdapter().typeId)) {
      Hive.registerAdapter(HistoryAdapter());
    }
    if (!Hive.isAdapterRegistered(DownloadTaskAdapter().typeId)) {
      Hive.registerAdapter(DownloadTaskAdapter());
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getDatabasesPath') {
          return tempDir.path;
        }
        if (methodCall.method == 'openDatabase') {
          return 1;
        }
        if (methodCall.method == 'closeDatabase') {
          return null;
        }
        if (methodCall.method == 'query') {
          return <Map<String, dynamic>>[];
        }
        if (methodCall.method == 'insert' || methodCall.method == 'update' || methodCall.method == 'delete') {
          return 0;
        }
        if (methodCall.method == 'execute') {
          return null;
        }
        return null;
      },
    );

    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles');
    GStorage.parseFailures = await Hive.openBox<ParseFailureRecord>('parseFailures');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    GStorage.downloadTasks = await Hive.openBox('downloadTasks');
    GStorage.searchHistory = await Hive.openBox<SearchHistory>('searchHistory');
    GStorage.histories = await Hive.openBox('histories');
    GStorage.favorites = await Hive.openBox('favorites');
    GStorage.shieldList = await Hive.openBox('shieldList');

    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    try {
      await GopeedService().stop();
    } catch (_) {}
    try {
      Request.dio.close(force: true);
    } catch (_) {}
    try {
      await Hive.close().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() {
    logWatcher = LogWatcherRobot();
    logWatcher.attach();
  });

  tearDown(() {
    logWatcher.detach();
  });

  group('Flutter 官方 integration_test: App 自动化巡检与常用操作闭环', () {
    testWidgets('端到端全量巡检: 遍历所有主Tab与子页面并完成搜索下载闭环', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final searchRobot = SearchAndDownloadRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.setViewport(const Size(1280, 800));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();

      // 1. 遍历所有主 Tab
      await navRobot.traverseAllPrimaryTabs();

      // 2. 遍历所有二级子页面
      await navRobot.traverseAllSecondarySubpages();

      // 3. 打开全网资源搜索并执行操作
      await searchRobot.openResourceSearch();

      // 模拟键盘输入关键词并提交搜索
      await searchRobot.typeKeywordAndSearch('nds');

      const sampleItem = TorrentItem(
        title: 'Nintendo DS Pokémon Black [NDS] Clean Rom v1.0',
        source: TorrentSourceType.piratebay,
        seeders: 42,
        leechers: 8,
        sizeBytes: 134217728,
        fileSize: '128 MB',
        customCategory: TorrentCategory.game,
        magnetUrl: 'magnet:?xt=urn:btih:3772F6578DACB15C02DC090168DF9CFA2610094A&dn=PokemonBlack',
      );

      await searchRobot.injectMockSearchResults([sampleItem]);
      searchRobot.verifyResultsRendered();

      // 4. 执行一键下载
      await searchRobot.executeOneClickDownload(
        item: sampleItem,
        expectedDownloadDirectory: '/Volumes/HD/downloads',
      );

      // 5. 执行选择性下载与三联文件树解析弹窗
      final testFiles = [
        TorrentFileEntry(
          index: 1,
          path: 'PokemonBlack/game.nds',
          name: 'game.nds',
          sizeBytes: 130000000,
          pathSegments: const ['PokemonBlack', 'game.nds'],
        ),
        TorrentFileEntry(
          index: 2,
          path: 'PokemonBlack/patch.ips',
          name: 'patch.ips',
          sizeBytes: 1024,
          pathSegments: const ['PokemonBlack', 'patch.ips'],
        ),
      ];
      await searchRobot.executeSelectiveDownloadDialogFlow(
        title: sampleItem.title,
        files: testFiles,
        savePath: '/Volumes/HD/downloads',
      );

      // 6. 验证全程零异常与零溢出
      await tester.pumpAndSettle();
      logWatcher.assertNoErrors();
    });
  });
}
