import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/roads/road_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/pages/player/local_player_page.dart';
import 'package:haipee/pages/player/player_item_panel.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/player/smallest_player_item_panel.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/router.dart';
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
    tempDir = await Directory.systemTemp.createTemp('player_panel_test');
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

  group('播放器宽窄屏自适应与细节保留全链路测试', () {
    testWidgets('1. Desktop 宽屏与缩窄窗口下均始终挂载 PlayerItemPanel 并保留完整播放控制细节', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final playerRobot = PlayerAndWindowLifecycleRobot(
        tester: tester,
        logWatcher: logWatcher,
      );

      await navRobot.setViewport(const Size(1280, 800));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp(initialRoute: Routes.onlineVideo);

      // 导航到 LocalPlayerPage
      const playArgs = LocalVideoPlayArgs(
        filePath: '',
        title: 'Details Preservation Test',
        biliBvid: 'BV1xx411c7mD',
        biliCid: 99887766,
        biliQuality: 80,
      );
      router.push(Routes.localPlayer, extra: playArgs);
      await playerRobot.settle();

      final appElement = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(appElement);
      final playerController = container.read(playerProvider.notifier);
      playerController.showVideoController = true;
      await playerRobot.settle();

      // 宽屏 (1280x800) 下确认 PlayerItemPanel 挂载
      expect(find.byType(PlayerItemPanel), findsOneWidget);
      expect(find.byType(SmallestPlayerItemPanel), findsNothing);

      // 音频与字幕按钮存在
      expect(find.byKey(const Key('full_panel_tracks_button')), findsOneWidget);
      // 下载按钮存在
      expect(find.byKey(const Key('player_download_btn')), findsOneWidget);

      // 缩窄 Desktop 窗口至 700x500 (以往逻辑会因 height>480 && width<840 错误降级为 SmallestPanel)
      tester.view.physicalSize = const Size(700, 500);
      playerController.showVideoController = true;
      await playerRobot.settle();

      // 在缩窄的桌面窗口下，仍然始终保持完整 PlayerItemPanel，不丢失播放器细节！
      expect(find.byType(PlayerItemPanel), findsOneWidget);
      expect(find.byType(SmallestPlayerItemPanel), findsNothing);
      expect(find.byKey(const Key('full_panel_tracks_button')), findsOneWidget);
      expect(find.byKey(const Key('player_download_btn')), findsOneWidget);

      logWatcher.checkTesterException(
        tester,
        contextDescription: 'PlayerItemPanel retains details on narrowed desktop window',
      );

      // 退出播放器
      final ctx = tester.element(find.byType(LocalPlayerPage));
      await Navigator.of(ctx).maybePop();
      await playerRobot.settle();
      await playerController.stopAndRelease();
      await playerRobot.settle();
    });

    testWidgets('2. SmallestPlayerItemPanel 包含选集、音频与字幕、下载等完备控制，确保极窄屏无选项丢失', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final playerCtrl = container.read(playerProvider.notifier);
      final videoCtrl = container.read(videoProvider.notifier);

      videoCtrl.state = videoCtrl.state.copyWith(
        loading: false,
        roadList: [
          Road(
            name: '默认线路',
            data: ['https://example.com/e1', 'https://example.com/e2'],
            identifier: ['第1集', '第2集'],
          ),
        ],
        currentRoad: 0,
        currentEpisode: 0,
      );

      playerCtrl.state = playerCtrl.state.copyWith(
        showVideoController: true,
        lockPanel: false,
      );

      final anim = AnimationController(vsync: tester, duration: const Duration(milliseconds: 200));
      addTearDown(anim.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      bool episodeChanged = false;
      bool menuOpened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: SmallestPlayerItemPanel(
                  disableAnimations: true,
                  animationController: anim,
                  keyboardFocus: focusNode,
                  onBackPressed: (_) {},
                  setPlaybackSpeed: (_) async {},
                  showDanmakuSwitch: () {},
                  handleFullscreen: () {},
                  handleProgressBarDragStart: (_) {},
                  handleProgressBarDragEnd: () {},
                  handleSuperResolutionChange: (_) async {},
                  handleHove: () {},
                  startHideTimer: () {},
                  cancelHideTimer: () {},
                  handleDanmaku: () {},
                  showVideoInfo: () {},
                  showSyncPlayRoomCreateDialog: () {},
                  showSyncPlayEndPointSwitchDialog: () {},
                  changeEpisode: (ep, {int currentRoad = 0, int offset = 0}) async {
                    episodeChanged = true;
                  },
                  openMenu: () {
                    menuOpened = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 下一集按钮正常展示并可点击
      final nextBtn = find.byIcon(Icons.skip_next_rounded);
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(episodeChanged, isTrue);

      // 打开更多选项菜单
      final moreMenuBtn = find.byKey(const Key('smallest_panel_more_menu_button'));
      expect(moreMenuBtn, findsOneWidget);
      await tester.tap(moreMenuBtn);
      await tester.pumpAndSettle();

      // 验证更多菜单内包含音频与字幕、选集与剧集列表、下载视频
      final episodesItem = find.byKey(const Key('smallest_menu_episodes'));
      expect(find.byKey(const Key('smallest_menu_tracks')), findsOneWidget);
      expect(episodesItem, findsOneWidget);
      expect(find.byKey(const Key('smallest_menu_download')), findsOneWidget);

      // 滚动至选集菜单项并点击
      await tester.ensureVisible(episodesItem);
      await tester.pumpAndSettle();
      await tester.tap(episodesItem);
      await tester.pumpAndSettle();
      expect(menuOpened, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. 横屏模式 (Landscape) 与紧凑视口下始终保持完整 PlayerItemPanel 并实现零像素溢出自适应', (tester) async {
      final navRobot = NavigationRobot(tester: tester, logWatcher: logWatcher);
      final playerRobot = PlayerAndWindowLifecycleRobot(
        tester: tester,
        logWatcher: logWatcher,
      );

      // 模拟移动端经典横屏视口 (iPhone 14/15 横屏: 844x390)
      await navRobot.setViewport(const Size(844, 390));
      addTearDown(navRobot.resetViewport);

      await navRobot.pumpApp(initialRoute: Routes.onlineVideo);

      const playArgs = LocalVideoPlayArgs(
        filePath: '',
        title: 'Landscape Full Controls Test',
        biliBvid: 'BV1xx411c7mD',
        biliCid: 99887766,
        biliQuality: 80,
      );
      router.push(Routes.localPlayer, extra: playArgs);
      await playerRobot.settle();

      final appElement = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(appElement);
      final playerController = container.read(playerProvider.notifier);
      playerController.showVideoController = true;
      await playerRobot.settle();

      // 横屏下必须始终挂载 PlayerItemPanel，不丢失任何细节选项
      expect(find.byType(PlayerItemPanel), findsOneWidget);
      expect(find.byType(SmallestPlayerItemPanel), findsNothing);
      expect(find.byKey(const Key('full_panel_tracks_button')), findsOneWidget);
      expect(find.byKey(const Key('player_download_btn')), findsOneWidget);

      logWatcher.checkTesterException(
        tester,
        contextDescription: 'PlayerItemPanel zero overflow at 844x390 landscape',
      );

      // 模拟紧凑横屏 (iPhone SE: 667x375)
      tester.view.physicalSize = const Size(667, 375);
      playerController.showVideoController = true;
      await playerRobot.settle();

      expect(find.byType(PlayerItemPanel), findsOneWidget);
      expect(find.byType(SmallestPlayerItemPanel), findsNothing);
      // 在 667 宽屏下，更多播放控制按钮 (Icons.tune_rounded) 优雅收敛次级菜单，避免横向挤爆
      expect(find.byKey(const Key('full_panel_compact_more_btn')), findsOneWidget);
      expect(find.byKey(const Key('full_panel_tracks_button')), findsOneWidget);

      logWatcher.checkTesterException(
        tester,
        contextDescription: 'PlayerItemPanel zero overflow at 667x375 landscape',
      );

      // 退出播放器
      final ctx = tester.element(find.byType(LocalPlayerPage));
      await Navigator.of(ctx).maybePop();
      await playerRobot.settle();
      await playerController.stopAndRelease();
      await playerRobot.settle();
    });
  });
}
