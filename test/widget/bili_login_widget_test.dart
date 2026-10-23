import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/online/online_video_search_page.dart';
import 'package:kazumi/pages/player/local_video_play_args.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bili_widget_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting_test_widget');
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles_test_widget');
    GStorage.collectChanges = await Hive.openBox<CollectedBangumiChange>('collect_changes_test_widget');
    GStorage.histories = await Hive.openBox<History>('histories_test_widget');
    GStorage.shieldList = await Hive.openBox<String>('shield_list_test_widget');
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    mockDio = Dio();
    mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
      if (options.uri.path.contains('/qrcode/generate')) {
        return ResponseBody.fromString(
          '{"code":0,"data":{"url":"https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=test_key","qrcode_key":"test_key"}}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString('{"code":0,"data":{"code":86101,"message":"未扫码"}}', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    });
    BiliAuthService().setCustomDio(mockDio);
  });

  group('Bilibili Login & Auth Banner Widget Tests', () {
    testWidgets('1. BiliLoginDialog mounts in unauthenticated state without overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BiliLoginDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiliLoginDialog), findsOneWidget);
      expect(find.text('登录哔哩哔哩'), findsOneWidget);
      expect(find.text('暂不登录 (保持360P)'), findsOneWidget);

      // Dismiss dialog to cancel timers
      await tester.tap(find.text('暂不登录 (保持360P)'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. OnlineVideoSearchPage no longer shows stiff banner on header', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证搜索页已彻底移除生硬的常驻横幅
      final bannerFinder = find.byKey(const Key('bili_auth_banner'));
      expect(bannerFinder, findsNothing);
      expect(find.textContaining('B站未登录 (360P)'), findsNothing);
    });

    testWidgets('3. PlayerItemPanel displays contextual Bilibili login prompt when playing Bilibili video in unauthenticated state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerProvider.notifier);
      controller.activeBiliCid = 98765;
      controller.state = controller.state.copyWith(
        showVideoController: true,
        lockPanel: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: const MaterialApp(
              home: _TestPlayerPanelHarness(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证检测到正在播放 B站 视频且未登录时，播放器浮层展示上下文登录胶囊与底部画质登录徽标
      expect(find.byKey(const Key('player_bili_login_prompt')), findsOneWidget);
      expect(find.byKey(const Key('player_bili_quality_badge')), findsOneWidget);
      expect(find.textContaining('当前为访客模式 (限360P) · 登录B站解锁 1080P/4K'), findsOneWidget);
      expect(find.text('360P · 登录享高清'), findsOneWidget);

      final loginBtn = find.byKey(const Key('bili_player_login_button'));
      expect(loginBtn, findsOneWidget);

      // 点击立即登录按钮，成功唤起登录弹窗
      await tester.tap(loginBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiliLoginDialog), findsOneWidget);

      // 关闭登录弹窗
      await tester.tap(find.text('暂不登录 (保持360P)'));
      await tester.pumpAndSettle();

      // 点击胶囊上的关闭按钮，胶囊自动消失，但底部控制栏的 360P 试看徽标依然保留以供随时登录
      final closeBtn = find.byKey(const Key('player_bili_login_prompt_close'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('player_bili_login_prompt')), findsNothing);
      expect(find.byKey(const Key('player_bili_quality_badge')), findsOneWidget);
    });

    testWidgets('5. disposeResources(disposeSyncPlayController: false) preserves Bilibili playback state and PlayerItem fills full container height', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerProvider.notifier);
      controller.activeLocalVideoArgs = const LocalVideoPlayArgs(
        filePath: 'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/test.m4s',
        title: 'B站测试视频',
        biliCid: 123456,
        biliBvid: 'BV1xx411c7mD',
      );
      controller.activeBiliCid = 123456;
      controller.activeBiliBvid = 'BV1xx411c7mD';

      // Verify disposeResources(disposeSyncPlayController: false) (called during init) does not wipe activeBiliCid
      await controller.disposeResources(disposeSyncPlayController: false);
      expect(controller.activeBiliCid, 123456);
      expect(controller.activeBiliBvid, 'BV1xx411c7mD');
      expect(controller.isBiliPlayback, isTrue);

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.black,
                body: PlayerItem(
                  disableAnimations: true,
                  keyboardFocus: focusNode,
                  onBackPressed: (_) {},
                  openMenu: () {},
                  locateEpisode: () {},
                  changeEpisode: (_, {currentRoad = 0, offset = 0}) async {},
                  sendDanmaku: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify PlayerItem occupies the full 1000x800 window height (not 1000 * 9 / 16 = 562.5)
      final playerItemSize = tester.getSize(find.byType(PlayerItem));
      expect(playerItemSize.width, 1000.0);
      expect(playerItemSize.height, 800.0);

      // Verify login prompt and quality badge are visible during initial phase
      expect(find.byKey(const Key('player_bili_login_prompt')), findsOneWidget);
      expect(find.byKey(const Key('player_bili_quality_badge')), findsOneWidget);

      // Advance past timers (4s hideTimer + 12s initialBiliPromptPhase)
      await tester.pump(const Duration(seconds: 13));

      // When user wakes up the control panel (showVideoController = true), prompt reappears
      controller.showVideoController = true;
      await tester.pump();
      expect(find.byKey(const Key('player_bili_login_prompt')), findsOneWidget);
      expect(find.byKey(const Key('player_bili_quality_badge')), findsOneWidget);
    });

    testWidgets('6. SmallestPlayerItemPanel also displays Bilibili login prompt on narrow windows', (tester) async {
      tester.view.physicalSize = const Size(700, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerProvider.notifier);
      controller.activeBiliCid = 98765;
      controller.state = controller.state.copyWith(
        showVideoController: true,
        lockPanel: false,
      );

      final anim = AnimationController(vsync: tester, duration: const Duration(milliseconds: 200));
      addTearDown(anim.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

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
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 13));

      expect(find.byKey(const Key('player_bili_login_prompt')), findsOneWidget);
      expect(find.byKey(const Key('bili_player_login_button')), findsOneWidget);
    });

    testWidgets('4. BiliLoginDialog supports switching between WebView, QR Code, and Cookie tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BiliLoginDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify 3 tab options exist in SegmentedButton
      expect(find.text('网页/短信'), findsOneWidget);
      expect(find.text('扫码登录'), findsOneWidget);
      expect(find.text('Cookie'), findsOneWidget);

      // On macOS desktop test runner, initial tab is QR Code (desktop recommended)
      expect(find.text('桌面端推荐'), findsOneWidget);

      // 2. Switch to Cookie tab
      await tester.tap(find.text('Cookie'));
      await tester.pump();

      expect(find.text('手动粘贴 B站登录凭据 (SESSDATA)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('验证并登录'), findsOneWidget);

      // 3. Switch to Webview tab
      await tester.tap(find.text('网页/短信'));
      await tester.pump();

      expect(find.text('桌面端推荐使用手机 App 扫码登录'), findsOneWidget);
      expect(find.text('在默认浏览器中打开登录页'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('暂不登录 (保持360P)'));
      await tester.pumpAndSettle();
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _TestPlayerPanelHarness extends StatefulWidget {
  const _TestPlayerPanelHarness();

  @override
  State<_TestPlayerPanelHarness> createState() => _TestPlayerPanelHarnessState();
}

class _TestPlayerPanelHarnessState extends State<_TestPlayerPanelHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _anim.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PlayerItemPanel(
        disableAnimations: true,
        animationController: _anim,
        keyboardFocus: _focusNode,
        onBackPressed: (_) {},
        setPlaybackSpeed: (_) async {},
        showDanmakuSwitch: () {},
        changeEpisode: (_, {currentRoad = 0, offset = 0}) async {},
        openMenu: () {},
        handleFullscreen: () {},
        handleProgressBarDragStart: (_) {},
        handleProgressBarDragEnd: () {},
        handleSuperResolutionChange: (_) async {},
        startHideTimer: () {},
        cancelHideTimer: () {},
        handleDanmaku: () {},
        sendDanmaku: (_) {},
        showVideoInfo: () {},
        showSyncPlayRoomCreateDialog: () {},
        showSyncPlayEndPointSwitchDialog: () {},
      ),
    );
  }
}
