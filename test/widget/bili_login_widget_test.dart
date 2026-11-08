import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bilibili/bilibili_auth_service.dart';
import 'package:haipee/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:haipee/modules/collect/collect_change_module.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/player/local_video_play_args.dart';
import 'package:haipee/pages/player/player_item.dart';
import 'package:haipee/pages/player/player_item_panel.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/player/smallest_player_item_panel.dart';
import 'package:haipee/pages/player/tracks_settings_sheet.dart';
import 'package:haipee/utils/storage.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bili_widget_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting_test_widget', bytes: Uint8List(0));
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles_test_widget', bytes: Uint8List(0));
    GStorage.collectChanges = await Hive.openBox<CollectedBangumiChange>('collect_changes_test_widget', bytes: Uint8List(0));
    GStorage.histories = await Hive.openBox<History>('histories_test_widget', bytes: Uint8List(0));
    GStorage.shieldList = await Hive.openBox<String>('shield_list_test_widget', bytes: Uint8List(0));
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

      // 验证检测到正在播放 B站 视频且未登录时，播放器浮层展示上下文登录胶囊与底部画质选择器
      expect(find.byKey(const Key('player_bili_login_prompt')), findsOneWidget);
      expect(find.byKey(const Key('player_bili_quality_badge')), findsOneWidget);
      expect(find.textContaining('当前为访客模式 (限360P) · 登录B站解锁 1080P/4K'), findsOneWidget);
      expect(find.text('480P 清晰'), findsOneWidget);

      // 点击底部画质选择器，展示标准 360P / 480P / 720P / 1080P / 1080P 高码率(大会员) 档位菜单
      await tester.tap(find.byKey(const Key('player_bili_quality_badge')));
      await tester.pumpAndSettle();
      expect(find.text('1080P 高码率'), findsOneWidget);
      expect(find.text('大会员'), findsWidgets);
      expect(find.text('1080P 高清'), findsOneWidget);
      expect(find.text('720P 高清'), findsOneWidget);
      expect(find.text('360P 流畅'), findsOneWidget);

      // 关闭画质菜单
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

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

    testWidgets('4. Desktop BiliLoginDialog presents QR code only (no Web/SMS or Cookie tabs) and auto-closes on mobile confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await BiliAuthService().logout();

      int pollCount = 0;
      final confirmDio = Dio();
      confirmDio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.uri.path.contains('/qrcode/generate')) {
          return ResponseBody.fromString(
            '{"code":0,"data":{"url":"https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=desktop_qr_key","qrcode_key":"desktop_qr_key"}}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.uri.path.contains('/qrcode/poll')) {
          pollCount++;
          if (pollCount == 1) {
            return ResponseBody.fromString(
              '{"code":0,"data":{"code":86090,"message":"已扫码，请在手机端确认登录"}}',
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          }
          return ResponseBody.fromString(
            '{"code":0,"data":{"code":0,"message":"","url":"https://passport.biligame.com/crossDomain?DedeUserID=999888&SESSDATA=desktop_sess%2C1750000000%2Cabc%2A31=&bili_jct=desktop_jct"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'set-cookie': [
                'SESSDATA=desktop_sess%2C1750000000%2Cabc%2A31=; Path=/; Domain=.bilibili.com;',
                'bili_jct=desktop_jct; Path=/; Domain=.bilibili.com;',
                'DedeUserID=999888; Path=/; Domain=.bilibili.com;',
              ],
            },
          );
        }
        if (options.uri.path.contains('/x/web-interface/nav')) {
          return ResponseBody.fromString(
            '{"code":0,"data":{"isLogin":true,"mid":999888,"uname":"桌面扫码用户","face":"","vipType":2,"vip_label":{"text":"大会员"}}}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });
      BiliAuthService().setCustomDio(confirmDio);

      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await BiliLoginDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Desktop does not render Web/SMS or Cookie tabs
      expect(find.text('网页/短信'), findsNothing);
      expect(find.text('Cookie'), findsNothing);
      expect(find.text('桌面端推荐'), findsNothing);
      expect(find.text('请使用哔哩哔哩客户端扫码登录'), findsOneWidget);

      // 2. First poll tick (1.5s): phone scanned, waiting confirmation
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(find.text('已扫码，请在手机端确认登录'), findsOneWidget);

      // 3. Second poll tick (1.5s): phone confirmed -> dialog auto-closes with result=true
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(find.byType(BiliLoginDialog), findsNothing);
      expect(dialogResult, isTrue);
      expect(BiliAuthService().isLoggedIn, isTrue);
      expect(BiliAuthService().currentUser?.uname, equals('桌面扫码用户'));
      await BiliAuthService().logout();
    });

    testWidgets('7. TracksSettingsSheet filters out mpv auto/no pseudo-tracks and adapts to active rule context', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playerProvider.notifier);
      controller.activeBiliCid = 98765;
      controller.state = controller.state.copyWith(
        playerTracks: Tracks(
          audio: [
            AudioTrack.auto(),
            AudioTrack.no(),
            const AudioTrack('1', null, null),
          ],
          subtitle: [
            SubtitleTrack.auto(),
            SubtitleTrack.no(),
          ],
        ),
        currentAudioTrack: const AudioTrack('1', null, null),
        currentSubtitleTrack: SubtitleTrack.no(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TracksSettingsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 严禁出现 mpv 内部虚拟轨道 #auto 或 #no (未知语言)
      expect(find.textContaining('#auto'), findsNothing);
      expect(find.textContaining('#no'), findsNothing);
      expect(find.textContaining('未知语言'), findsNothing);

      // 清晰展示 B站 DASH 音画分离流徽标与原生高音质音频说明
      expect(find.text('B站 DASH 音画分离流'), findsOneWidget);
      expect(find.text('B站原生高音质音频流 (DASH AAC)'), findsOneWidget);
      expect(find.text('当前生效'), findsOneWidget);
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
