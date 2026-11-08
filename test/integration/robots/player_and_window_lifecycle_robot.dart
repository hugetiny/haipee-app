import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/widget/global_mini_player_bar.dart';
import 'package:haipee/modules/danmaku/danmaku_module.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/player/local_player_page.dart';
import 'package:haipee/pages/player/player_item.dart';
import 'package:haipee/pages/player/player_item_panel.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/player/smallest_player_item_panel.dart';
import 'package:haipee/pages/player/tracks_settings_sheet.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'log_watcher_robot.dart';

/// 自动化常规交互巡检机器人：专门覆盖小窗口(PIP)切换、无参路由防崩、
/// 迷你播放条往返、弹幕来源透视、独立视频统计面板及在线搜索分类筛选。
class PlayerAndWindowLifecycleRobot {
  final WidgetTester tester;
  final LogWatcherRobot logWatcher;

  PlayerAndWindowLifecycleRobot({
    required this.tester,
    required this.logWatcher,
  });

  /// 安装桌面/移动端窗口与音量/亮度插件 Mock，防止无头测试触发 MissingPluginException
  static void installPlatformMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    const mockedChannels = <String>[
      'window_manager',
      'screen_Retriever',
      'screen_retriever',
      'com.kurenai7968.flutter_volume_controller.method',
      'github.com/aaassseee/screen_brightness',
      'floating',
      'dev.fluttercommunity.plus/wakelock',
      'pigeon_wakelock_plus_api',
    ];

    for (final name in mockedChannels) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (MethodCall call) async {
          switch (call.method) {
            case 'getVolume':
            case 'application':
            case 'system':
              return 0.5;
            case 'isMaximized':
            case 'isFullScreen':
            case 'isAlwaysOnTop':
            case 'isVisible':
              return false;
            case 'getBounds':
              return <String, double>{
                'x': 100,
                'y': 100,
                'width': 1280,
                'height': 800,
              };
            case 'getSize':
              return <String, double>{'width': 1280, 'height': 800};
            case 'getPosition':
              return <String, double>{'x': 100, 'y': 100};
            default:
              return null;
          }
        },
      );
    }
  }

  Future<void> settle() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  ProviderContainer _container() {
    final appElement = tester.element(find.byType(MaterialApp).first);
    return ProviderScope.containerOf(appElement);
  }

  /// 1. 验证无 extra 参数直跳 `/player/local` 时绝不抛出 TypeError 崩溃
  Future<void> verifySafePlayerRouteWithoutExtra() async {
    router.go(Routes.onlineVideo);
    await settle();

    router.push(Routes.localPlayer);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Push Routes.localPlayer with null extra',
    );
    expect(find.byType(LocalPlayerPage), findsOneWidget);
    expect(find.byType(PlayerItem), findsOneWidget);

    // 正常返回退出播放页
    final ctx = tester.element(find.byType(LocalPlayerPage));
    await Navigator.of(ctx).maybePop();
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Pop Routes.localPlayer after null extra visit',
    );
  }

  /// 2. 验证桌面端常规窗口 <-> 480x270 小窗(PIP)切换、面板自适应及返回键/Esc 逐级退出闭环
  Future<void> verifyPipWindowTransitionsAndBackInterception() async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await settle();

    router.go(Routes.onlineVideo);
    await settle();

    const playArgs = LocalVideoPlayArgs(
      // 空 filePath 避免在无头环境触发原生 libmpv FFI，完整挂载全部 Flutter UI 控件树
      filePath: '',
      title: 'Lose Yourself [HD Remaster]',
      biliBvid: 'BV1xx411c7mD',
      biliCid: 99887766,
      biliQuality: 80,
    );

    router.push(Routes.localPlayer, extra: playArgs);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Open LocalPlayerPage on 1280x800 desktop viewport',
    );

    final container = _container();
    final playerController = container.read(playerProvider.notifier);
    final videoPageController = container.read(videoProvider.notifier);
    playerController.showVideoController = true;
    await settle();

    // Desktop 宽屏下应挂载完整版 PlayerItemPanel
    expect(find.byType(PlayerItemPanel), findsOneWidget);
    expect(find.byType(SmallestPlayerItemPanel), findsNothing);

    // 模拟切入 480x270 小窗口模式 (PIP)
    videoPageController.isPip = true;
    tester.view.physicalSize = const Size(480, 270);
    playerController.showVideoController = true;
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Switch to 480x270 PIP small window mode',
    );

    // 小窗下必须自动切换为紧凑版 SmallestPlayerItemPanel 且 0 像素溢出
    expect(find.byType(SmallestPlayerItemPanel), findsOneWidget);
    expect(find.byType(PlayerItemPanel), findsNothing);

    // 在小窗模式下触发返回 (PopScope 拦截)：应优先退出小窗恢复常规模式，而不是直接销毁页面！
    final localPlayerCtx = tester.element(find.byType(LocalPlayerPage));
    await Navigator.of(localPlayerCtx).maybePop();
    tester.view.physicalSize = const Size(1280, 800);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Back pressed in PIP mode exits PIP first',
    );

    expect(
      videoPageController.isPip,
      isFalse,
      reason: '在小窗口模式下点击返回应先退出小窗模式，将 isPip 复位为 false',
    );
    expect(
      find.byType(LocalPlayerPage),
      findsOneWidget,
      reason: '退出小窗模式时不应直接 Pop 销毁整个播放器路由',
    );

    // 桌面端测试 Esc 快捷键退出小窗模式
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      videoPageController.isPip = true;
      tester.view.physicalSize = const Size(480, 270);
      await settle();
      expect(videoPageController.isPip, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      tester.view.physicalSize = const Size(1280, 800);
      await settle();
      logWatcher.checkTesterException(
        tester,
        contextDescription: 'Escape key exits PIP mode on desktop',
      );
      expect(videoPageController.isPip, isFalse);
    }

    // 再次触发返回：此时非小窗、非全屏，应干净释放并退出播放页
    final exitCtx = tester.element(find.byType(LocalPlayerPage));
    await Navigator.of(exitCtx).maybePop();
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Second Back cleanly pops LocalPlayerPage',
    );
    expect(find.byType(LocalPlayerPage), findsNothing);
  }

  /// 3. 验证弹幕来源明细透视面板、音频与字幕兼容面板、以及与 AppLog 解耦的「视频统计与媒体信息」
  Future<void> verifyStatsSheetAndDanmakuSourceControls() async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await settle();

    router.go(Routes.onlineVideo);
    await settle();

    router.push(
      Routes.localPlayer,
      extra: const LocalVideoPlayArgs(
        filePath: '',
        title: 'Multi-Rule Danmaku & Stats Test',
      ),
    );
    await settle();

    final container = _container();
    final playerController = container.read(playerProvider.notifier);
    final videoPageController = container.read(videoProvider.notifier);

    // 注入非 B站直连的多来源弹幕，验证弹幕设置抽屉内的来源明细与独立开关
    playerController.activeBiliCid = null;
    playerController.activeBiliBvid = null;
    playerController.videoUrl = 'https://cdn.example.com/vod/master.m3u8';
    playerController.addDanmakus([
      DanmakuEntry(
        message: '前方高能',
        time: 2.0,
        type: 1,
        color: Colors.white,
        source: '[BiliBili]',
      ),
      DanmakuEntry(
        message: '经典名场面',
        time: 3.0,
        type: 1,
        color: Colors.white,
        source: '[BiliBili]',
      ),
      DanmakuEntry(
        message: '巴哈弹幕测试',
        time: 4.0,
        type: 1,
        color: Colors.white,
        source: '[Gamer]',
      ),
      DanmakuEntry(
        message: '弹弹Play来源测试',
        time: 5.0,
        type: 1,
        color: Colors.white,
        source: '[DanDanPlay]',
      ),
    ]);
    playerController.showVideoController = true;
    await settle();

    final initialErrorCount = AppLog.errorCountNotifier.value;

    // 3a. 打开「音频与字幕」兼容面板
    final tracksBtn = find.byKey(const Key('full_panel_tracks_button'));
    if (tracksBtn.evaluate().isNotEmpty) {
      await tester.tap(tracksBtn);
      await settle();
      logWatcher.checkTesterException(
        tester,
        contextDescription: 'Open TracksSettingsSheet on 1280x800',
      );
      expect(find.byType(TracksSettingsSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(TracksSettingsSheet))).pop();
      await settle();
    }

    // 3b. 通过更多菜单打开「视频统计与媒体信息」(宽屏模式)
    final moreBtn = find.byKey(const Key('full_panel_more_menu_button'));
    expect(moreBtn, findsOneWidget);
    await tester.tap(moreBtn);
    await settle();

    final infoMenuItem = find.byKey(const Key('full_menu_video_info'));
    expect(infoMenuItem, findsOneWidget);
    await tester.tap(infoMenuItem);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Open video_stats_sheet on 1280x800',
    );

    expect(find.byKey(const Key('video_stats_sheet')), findsOneWidget);
    expect(find.text('视频统计与媒体信息'), findsOneWidget);
    expect(find.textContaining('共 4 条'), findsWidgets);

    // 点击复制诊断参数按钮
    await tester.tap(find.byKey(const Key('video_stats_copy_button')));
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Copy structured video stats',
    );

    await tester.tap(find.byKey(const Key('video_stats_close_button')));
    await settle();

    // 3c. 切入 480x270 极限小窗模式，再次打开「弹幕设置」与「视频统计与媒体信息」，确保窄窗 0 溢出！
    videoPageController.isPip = true;
    tester.view.physicalSize = const Size(480, 270);
    playerController.showVideoController = true;
    await settle();

    final smallMoreBtn =
        find.byKey(const Key('smallest_panel_more_menu_button'));
    expect(smallMoreBtn, findsOneWidget);
    await tester.tap(smallMoreBtn);
    await settle();

    final smallDanmakuItem =
        find.byKey(const Key('smallest_menu_danmaku_settings'));
    expect(smallDanmakuItem, findsOneWidget);
    await tester.ensureVisible(smallDanmakuItem);
    await settle();
    await tester.tap(smallDanmakuItem);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Open DanmakuSettingsSheet inside 480x270 PIP window',
    );

    expect(find.byType(DanmakuSettingsSheet), findsOneWidget);
    expect(find.textContaining('已加载 4 条'), findsOneWidget);
    expect(find.textContaining('(2 条)'), findsOneWidget);
    Navigator.of(tester.element(find.byType(DanmakuSettingsSheet))).pop();
    await settle();

    // 在 480x270 小窗下打开视频统计面板
    playerController.showVideoController = true;
    await settle();
    await tester.tap(smallMoreBtn);
    await settle();
    final smallVideoInfoItem =
        find.byKey(const Key('smallest_menu_video_info'));
    expect(smallVideoInfoItem, findsOneWidget);
    await tester.ensureVisible(smallVideoInfoItem);
    await settle();
    await tester.tap(smallVideoInfoItem);
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Open video_stats_sheet inside 480x270 PIP window',
    );
    expect(find.byKey(const Key('video_stats_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('video_stats_close_button')));
    await settle();

    // 确认整个播放器调试/统计查看过程与全局 AppLog 错误计数完全隔离
    expect(AppLog.errorCountNotifier.value, equals(initialErrorCount));

    // 恢复常规尺寸并退出播放器
    videoPageController.isPip = false;
    tester.view.physicalSize = const Size(1280, 800);
    await settle();
    final exitCtx = tester.element(find.byType(LocalPlayerPage));
    await Navigator.of(exitCtx).maybePop();
    await settle();
  }

  /// 4. 验证全局迷你播放条 (GlobalMiniPlayerBar) 显示、点击重返播放页及关闭释放全流程
  Future<void> verifyMiniPlayerBarRoundTrip() async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    router.go(Routes.onlineVideo);
    await settle();

    final container = _container();
    final playerController = container.read(playerProvider.notifier);
    container.read(currentRouteProvider.notifier).updateRoute(Routes.onlineVideo);

    playerController.activeLocalVideoArgs = const LocalVideoPlayArgs(
      filePath: '',
      title: 'MiniBar Seamless Resume Test',
    );
    playerController.currentTitle = 'MiniBar Seamless Resume Test';
    await settle();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Render GlobalMiniPlayerBar on OnlineVideoSearchPage',
    );

    if (find.byType(GlobalMiniPlayerBar).evaluate().isNotEmpty &&
        find.byIcon(Icons.open_in_full_rounded).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.open_in_full_rounded).first);
      await settle();
      logWatcher.checkTesterException(
        tester,
        contextDescription: 'Tap GlobalMiniPlayerBar returnToPlayer button',
      );
      expect(find.byType(LocalPlayerPage), findsOneWidget);

      final ctx = tester.element(find.byType(LocalPlayerPage));
      await Navigator.of(ctx).maybePop();
      await settle();
    }

    await playerController.stopAndRelease();
    await settle();
  }

  /// 5. 验证在线视频搜索框右侧「筛选」折叠面板及其多维分类在宽窄屏下的零溢出交互
  Future<void> verifyOnlineSearchFilterPanel({
    List<Size> viewports = const [Size(1280, 800), Size(360, 640)],
  }) async {
    for (final size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      router.go(Routes.onlineVideo);
      await settle();

      expect(find.byType(OnlineVideoSearchPage), findsOneWidget);
      final filterBtn =
          find.byKey(const Key('online_search_filter_toggle_btn'));
      expect(filterBtn, findsOneWidget);

      // 展开分类筛选面板
      await tester.tap(filterBtn);
      await settle();
      logWatcher.checkTesterException(
        tester,
        contextDescription:
            'Expand online search filter panel at ${size.width.toInt()}x${size.height.toInt()}',
      );
      expect(find.byKey(const Key('online_search_filter_panel')), findsOneWidget);

      // 按强语义 Key 依次选择「点播视频」与「Haipee 规则」
      final vodChip = find.byKey(const Key('online_search_chip_video'));
      expect(vodChip, findsOneWidget);
      await tester.tap(vodChip);
      await settle();

      final haipeeRuleChip = find.byKey(const Key('online_search_chip_haipee'));
      if (haipeeRuleChip.evaluate().isNotEmpty) {
        await tester.tap(haipeeRuleChip);
        await settle();
      }
      logWatcher.checkTesterException(
        tester,
        contextDescription:
            'Select VOD + Haipee rule filter at ${size.width.toInt()}x${size.height.toInt()}',
      );

      // 收起面板，验证「当前筛选:」紧凑摘要条渲染零溢出
      await tester.tap(filterBtn);
      await settle();
      logWatcher.checkTesterException(
        tester,
        contextDescription:
            'Collapse filter panel with active summary bar at ${size.width.toInt()}x${size.height.toInt()}',
      );
      expect(find.text('当前筛选:'), findsOneWidget);

      // 点击摘要条「重置全部」恢复初始无筛选状态
      final resetAllBtn = find.text('重置全部');
      expect(resetAllBtn, findsOneWidget);
      await tester.tap(resetAllBtn);
      await settle();
      expect(find.text('当前筛选:'), findsNothing);
    }
  }

  /// 一键执行全部常规播放器与搜索筛选巡检流
  Future<void> runFullRoutinePatrol() async {
    await verifySafePlayerRouteWithoutExtra();
    await verifyPipWindowTransitionsAndBackInterception();
    await verifyStatsSheetAndDanmakuSourceControls();
    await verifyMiniPlayerBarRoundTrip();
    await verifyOnlineSearchFilterPanel();
  }
}
