import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/utils/storage.dart';
import 'robots/log_watcher_robot.dart';
import 'robots/navigation_robot.dart';
import 'robots/player_and_window_lifecycle_robot.dart';
import 'robots/search_and_download_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LogWatcherRobot logWatcher;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('automated_bug_discovery_test');
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
    PlayerAndWindowLifecycleRobot.installPlatformMocks();

    GStorage.setting = await Hive.openBox('setting', bytes: Uint8List(0));
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles', bytes: Uint8List(0));
    GStorage.parseFailures = await Hive.openBox<ParseFailureRecord>('parseFailures', bytes: Uint8List(0));
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins', bytes: Uint8List(0));
    GStorage.indexerRepos = await Hive.openBox('indexerRepos', bytes: Uint8List(0));
    GStorage.downloadTasks = await Hive.openBox('downloadTasks', bytes: Uint8List(0));
    GStorage.searchHistory = await Hive.openBox<SearchHistory>('searchHistory', bytes: Uint8List(0));
    GStorage.histories = await Hive.openBox('histories', bytes: Uint8List(0));
    GStorage.favorites = await Hive.openBox('favorites', bytes: Uint8List(0));
    GStorage.shieldList = await Hive.openBox('shieldList', bytes: Uint8List(0));

    TorrentTrackerService.instance.setTrackersForTesting([]);
    await GStorage.setting.put(
      SettingBoxKey.downloadDirectory,
      '${tempDir.path}/downloads',
    );

    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    TorrentTrackerService.instance.resetTrackersForTesting();
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

  group('自动化全页面巡检与 Bug 发现套件 (Desktop 布局)', () {
    const desktopSize = Size(1280, 800);

    testWidgets('1. Desktop 布局: 全量遍历所有一级菜单与二级设置子页面', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      await navRobot.setViewport(desktopSize);
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();

      // 遍历所有一级 Tab
      await navRobot.traverseAllPrimaryTabs();

      // 遍历所有二级子页面
      await navRobot.traverseAllSecondarySubpages();

      logWatcher.assertNoErrors();
    });

    testWidgets('2. Desktop 布局: 资源搜索、首项一键下载与三联树选择性下载闭环', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final searchRobot = SearchAndDownloadRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.setViewport(desktopSize);
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();
      await searchRobot.openResourceSearch();

      // 模拟键盘输入关键词并提交搜索
      await searchRobot.typeKeywordAndSearch('nds');

      const sampleItem = TorrentItem(
        title: 'Nintendo DS Pokémon HeartGold [NDS] Clean Rom v1.0',
        source: TorrentSourceType.piratebay,
        seeders: 50,
        leechers: 10,
        sizeBytes: 134217728, // 128 MB
        fileSize: '128 MB',
        customCategory: TorrentCategory.game,
        magnetUrl: 'magnet:?xt=urn:btih:3772F6578DACB15C02DC090168DF9CFA2610094A&dn=PokemonHG',
      );

      // 注入搜索结果并验证表格视图渲染
      await searchRobot.injectMockSearchResults([sampleItem]);
      searchRobot.verifyResultsRendered();

      // 执行一键下载
      await searchRobot.executeOneClickDownload(
        item: sampleItem,
        expectedDownloadDirectory: '/Volumes/HD/downloads',
      );

      // 执行选择性下载与三联文件树测试
      final testFiles = [
        TorrentFileEntry(
          index: 1,
          path: 'PokemonHG/game.nds',
          name: 'game.nds',
          sizeBytes: 130000000,
          pathSegments: const ['PokemonHG', 'game.nds'],
        ),
        TorrentFileEntry(
          index: 2,
          path: 'PokemonHG/readme.txt',
          name: 'readme.txt',
          sizeBytes: 2048,
          pathSegments: const ['PokemonHG', 'readme.txt'],
        ),
      ];
      await searchRobot.executeSelectiveDownloadDialogFlow(
        title: sampleItem.title,
        files: testFiles,
        savePath: '/Volumes/HD/downloads',
      );

      logWatcher.assertNoErrors();
    });
  });

  group('自动化全页面巡检与 Bug 发现套件 (Mobile 极窄视口布局)', () {
    const mobileSize = Size(360, 640);

    testWidgets('3. Mobile 紧凑布局: 全量遍历所有主 Tab 与二级子页面 (零溢出验证)', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      await navRobot.setViewport(mobileSize);
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();

      // 遍历所有一级 Tab
      await navRobot.traverseAllPrimaryTabs();

      // 遍历所有二级子页面（重点验证 LogsPage 等底栏无溢出）
      await navRobot.traverseAllSecondarySubpages();

      logWatcher.assertNoErrors();
    });

    testWidgets('4. Mobile 紧凑布局: 资源搜索、卡片视图一键下载与选择性下载 (零溢出闭环)', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final searchRobot = SearchAndDownloadRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.setViewport(mobileSize);
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();
      await searchRobot.openResourceSearch();

      // 模拟键盘输入关键词并提交搜索
      await searchRobot.typeKeywordAndSearch('nds');

      const sampleItem = TorrentItem(
        title: 'Nintendo DS Pokémon SoulSilver [NDS] Clean Rom v1.0',
        source: TorrentSourceType.piratebay,
        seeders: 60,
        leechers: 15,
        sizeBytes: 134217728,
        fileSize: '128 MB',
        customCategory: TorrentCategory.game,
        magnetUrl: 'magnet:?xt=urn:btih:3772F6578DACB15C02DC090168DF9CFA2610094A&dn=PokemonSS',
      );

      // 注入搜索结果并验证移动端卡片视图渲染
      await searchRobot.injectMockSearchResults([sampleItem]);
      searchRobot.verifyResultsRendered();

      // 执行移动端卡片视图一键下载（验证 FittedBox 与操作栏无溢出）
      await searchRobot.executeOneClickDownload(
        item: sampleItem,
        expectedDownloadDirectory: '/Volumes/HD/downloads',
      );

      // 执行选择性下载与三联文件树测试
      final testFiles = [
        TorrentFileEntry(
          index: 1,
          path: 'PokemonSS/game.nds',
          name: 'game.nds',
          sizeBytes: 130000000,
          pathSegments: const ['PokemonSS', 'game.nds'],
        ),
      ];
      await searchRobot.executeSelectiveDownloadDialogFlow(
        title: sampleItem.title,
        files: testFiles,
        savePath: '/Volumes/HD/downloads',
      );

      logWatcher.assertNoErrors();
    });

    testWidgets('5. 高频快速切换路由压力测试 (状态同步与空安全检测)', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      await navRobot.setViewport(mobileSize);
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();

      // 快速切换多次
      await navRobot.stressRapidNavigation(rounds: 3);

      logWatcher.assertNoErrors();
    });

    testWidgets('6. 常规高危交互巡检: 小窗(PIP)切换、无参路由防崩、迷你条往返、弹幕源与独立统计面板、分类筛选',
        (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final playerRobot = PlayerAndWindowLifecycleRobot(
        tester: tester,
        logWatcher: logWatcher,
      );

      await navRobot.setViewport(const Size(1280, 800));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();
      await playerRobot.runFullRoutinePatrol();

      logWatcher.assertNoErrors();
    });
  });
}
