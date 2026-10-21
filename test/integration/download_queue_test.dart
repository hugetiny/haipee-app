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
import 'package:kazumi/modules/download/gopeed/gopeed_service.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/storage.dart';
import 'robots/download_lifecycle_robot.dart';
import 'robots/fuzz_and_invariant_hunter_robot.dart';
import 'robots/log_watcher_robot.dart';
import 'robots/navigation_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LogWatcherRobot logWatcher;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('download_queue_test_');
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

    final dylibFile = File('${Directory.current.path}/macos/Frameworks/libgopeed.dylib');
    if (dylibFile.existsSync()) {
      await GopeedService().initialize(storageDir: '${tempDir.path}/gopeed');
    }
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

  group('下载队列生命周期与 Xunlei UI 状态机闭环测试 (T037-T043)', () {
    testWidgets('1. 多类型任务分类、Xunlei统计面板与播放限制不变量验证', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final downloadRobot = DownloadLifecycleRobot(tester: tester, logWatcher: logWatcher);
      final fuzzRobot = FuzzAndInvariantHunterRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.setViewport(const Size(1280, 800));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();
      logWatcher.hookFlutterError();
      await downloadRobot.openDownloadPage();

      // 构建各类型测试任务
      final tasks = [
        // 视频文件 (正在下载中 -> 需支持边下边播)
        DownloadTask(
          gid: 'video_active_1',
          url: 'https://example.com/anime_ep01.mp4',
          title: 'Anime Episode 01.mp4',
          fileName: 'anime_ep01.mp4',
          status: 'active',
          totalLength: 500000000,
          completedLength: 250000000,
          downloadSpeed: 10485760,
          uploadSpeed: 102400,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          updatedAt: DateTime.now(),
        ),
        // 压缩包 (已完成 -> 严禁播放或边下边播，仅支持打开文件)
        DownloadTask(
          gid: 'archive_complete_1',
          url: 'https://store8.gofile.io/download/web/Romance_of_the_Three_Kingdoms_14.part7.rar',
          title: 'Romance_of_the_Three_Kingdoms_14.part7.rar',
          fileName: 'Romance_of_the_Three_Kingdoms_14.part7.rar',
          status: 'complete',
          totalLength: 300000000,
          completedLength: 300000000,
          downloadSpeed: 0,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now(),
        ),
        // 视频文件 (已完成 -> 需支持播放)
        DownloadTask(
          gid: 'video_complete_1',
          url: 'https://example.com/movie.mkv',
          title: 'Anime Movie 1080P.mkv',
          fileName: 'movie.mkv',
          status: 'complete',
          totalLength: 1500000000,
          completedLength: 1500000000,
          downloadSpeed: 0,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAt: DateTime.now(),
        ),
        // 鉴权失效/网页重定向错误任务
        DownloadTask(
          gid: 'gofile_error_1',
          url: 'https://store8.gofile.io/download/web/protected.zip',
          title: 'ProtectedArchive.zip',
          fileName: 'protected.zip',
          status: 'error',
          totalLength: 100000000,
          completedLength: 1024,
          errorMessage: '检测到下载返回的内容为重定向网页，未获得真实资源',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          updatedAt: DateTime.now(),
        ),
      ];

      // 植入任务并同步
      await downloadRobot.seedTasks(tasks);

      // 验证迅雷统计 Banner 与状态不变量
      downloadRobot.verifyGlobalStatsBanner();
      fuzzRobot.assertGlobalDownloadInvariants();

      // 验证非媒体文件严禁播放不变量
      await downloadRobot.verifyPlayabilityInvariants(tasks);

      // 验证 Gofile 鉴权失败与重新配置对话框联动
      await downloadRobot.verifyGofileReconfigureDialogFlow(tasks.last);

      logWatcher.assertNoErrors();
    });

    testWidgets('2. 批量管理、多选操作与全选状态同步测试', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final downloadRobot = DownloadLifecycleRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.setViewport(const Size(1024, 768));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp();
      logWatcher.hookFlutterError();
      await downloadRobot.openDownloadPage();

      final tasks = [
        DownloadTask(
          gid: 'batch_1',
          url: 'https://example.com/1.mp4',
          title: 'Batch Task 1.mp4',
          status: 'active',
          totalLength: 100000,
          completedLength: 50000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        DownloadTask(
          gid: 'batch_2',
          url: 'https://example.com/2.mp4',
          title: 'Batch Task 2.mp4',
          status: 'paused',
          totalLength: 200000,
          completedLength: 100000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await downloadRobot.seedTasks(tasks);
      await downloadRobot.executeBatchSelectionFlow();

      logWatcher.assertNoErrors();
    });

    testWidgets('3. 极端视口与无障碍字体缩放混沌测试 (零溢出验证)', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final downloadRobot = DownloadLifecycleRobot(tester: tester, logWatcher: logWatcher);
      final fuzzRobot = FuzzAndInvariantHunterRobot(tester: tester, logWatcher: logWatcher);

      await navRobot.pumpApp();
      logWatcher.hookFlutterError();
      await downloadRobot.openDownloadPage();

      // 测试从极小 iPhone SE 到 4K 显示器视口
      const testSizes = [
        Size(320, 480),   // 超极窄设备
        Size(360, 640),   // 主流窄屏手机
        Size(412, 915),   // 现代 Android
        Size(768, 1024),  // 平板竖屏
        Size(1280, 800),  // 标准桌面
        Size(1920, 1080), // 1080P
      ];

      await fuzzRobot.fuzzViewportsAndTextScales(
        testSizes: testSizes,
        textScales: [1.0, 1.25, 1.5],
      );

      // 搜索与排序边界值混沌模糊测试
      await fuzzRobot.fuzzSearchAndSortingFilters();

      // 状态机边界值模糊测试
      await fuzzRobot.fuzzTaskStateMutations(iterations: 20);

      logWatcher.assertNoErrors();
    });
  });
}
