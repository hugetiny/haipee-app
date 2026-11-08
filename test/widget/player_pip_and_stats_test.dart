import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';
import '../integration/robots/log_watcher_robot.dart';
import '../integration/robots/navigation_robot.dart';
import '../integration/robots/player_and_window_lifecycle_robot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LogWatcherRobot logWatcher;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('player_pip_stats_test');
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
      (MethodCall methodCall) async => tempDir.path,
    );
    PlayerAndWindowLifecycleRobot.installPlatformMocks();

    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles =
        await Hive.openBox<CollectedBangumi>('collectibles');
    GStorage.parseFailures =
        await Hive.openBox<ParseFailureRecord>('parseFailures');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    GStorage.downloadTasks = await Hive.openBox('downloadTasks');
    GStorage.searchHistory =
        await Hive.openBox<SearchHistory>('searchHistory');
    GStorage.histories = await Hive.openBox('histories');
    GStorage.favorites = await Hive.openBox('favorites');
    GStorage.shieldList = await Hive.openBox('shieldList');

    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
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

  group('小窗切换(PIP)、无参路由、弹幕来源明细与独立视频统计全链路回归测试', () {
    testWidgets('1. 完整执行播放器小窗口切换、返回拦截、迷你条往返、弹幕源与统计面板巡检',
        (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final playerRobot = PlayerAndWindowLifecycleRobot(
        tester: tester,
        logWatcher: logWatcher,
      );

      await navRobot.setViewport(const Size(1280, 800));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp(initialRoute: Routes.onlineVideo);

      await playerRobot.runFullRoutinePatrol();

      logWatcher.assertNoErrors();
    });
  });
}
