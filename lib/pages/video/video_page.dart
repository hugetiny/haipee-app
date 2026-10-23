import 'dart:async';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_state.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:kazumi/pages/player/episode_comments_sheet.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/ui/appbar/kazumi_app_bar_actions.dart';
import 'package:kazumi/ui/appbar/kazumi_action_item.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/pages/history/providers.dart';
import 'package:kazumi/pages/webview/providers.dart';
import 'package:kazumi/pages/video/video_state.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/utils/parse_failure_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage>
    with TickerProviderStateMixin, WindowListener {
  Box setting = GStorage.setting;
  late final VideoPageController videoPageController;
  late final PlayerController playerController;
  late final HistoryController historyController;
  late final WebviewItemController webviewItemController;
  late bool playResume;
  // ✅ showDebugLog, webviewLogLines, currentRoad moved to Riverpod StateProvider
  final FocusNode keyboardFocus = FocusNode();

  ScrollController scrollController = ScrollController();
  // Dedicated controllers for debug log lists to keep Scrollbar attached
  final ScrollController _webviewLogController = ScrollController();
  final ScrollController _playerLogController = ScrollController();
  late GridObserverController observerController;
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;
  late Animation<double> _maskOpacityAnimation;
  late TabController tabController;

  // webview init events listener
  late final StreamSubscription<bool> _initSubscription;

  // webview logs events listener
  late final StreamSubscription<String> _logSubscription;

  // webview video loaded events listener
  late final StreamSubscription<bool> _videoLoadedSubscription;

  // webview video source events listener
  // The first parameter is the video source URL and the second parameter is the video offset (start position)
  late final StreamSubscription<(String, int)> _videoURLSubscription;

  // disable animation.
  late final bool disableAnimations;

  @override
  void initState() {
    super.initState();
    videoPageController = ref.read(videoProvider.notifier);
    playerController = ref.read(playerProvider.notifier);
    historyController = ref.read(historyProvider.notifier);
    webviewItemController = ref.read(webviewItemControllerProvider);
    windowManager.addListener(this);
    tabController = TabController(length: 2, vsync: this);
    observerController = GridObserverController(controller: scrollController);
    animation = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));
    _maskOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeIn,
    ));
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    disableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);
    // currentRoadProvider has a default of 0; no need to set it here to avoid lifecycle writes

    // webview events listener (must subscribe before init() to avoid dropping broadcast events)
    _initSubscription = webviewItemController.onInitialized.listen((event) {
      if (event && mounted) {
        changeEpisode(videoPageController.currentEpisode,
            currentRoad: videoPageController.currentRoad,
            offset: videoPageController.historyOffset);
      }
    });

    // Initialize video page state and trigger playback after initState completes
    Future.microtask(() async {
      if (!mounted) return;
      _initializeVideoPageState();
      if (!videoPageController.currentPlugin.useWebview) {
        await changeEpisode(
          videoPageController.currentEpisode,
          currentRoad: videoPageController.currentRoad,
          offset: videoPageController.historyOffset,
        );
      } else {
        await webviewItemController.init();
      }
    });
    _videoLoadedSubscription =
        webviewItemController.onVideoLoading.listen((event) {
      if (playerController.videoUrl.isNotEmpty ||
          (playerController.mediaPlayer?.state.playing ?? false)) {
        return;
      }
      videoPageController.loading = event;
    });
    _videoURLSubscription =
        webviewItemController.onVideoURLParser.listen((event) {
      final (mediaUrl, offset) = event;
      clearWebviewLog();
      videoPageController.loading = false;
      unawaited(webviewItemController.unloadPage());
      playerController.init(mediaUrl, offset: offset);
    });
    _logSubscription = webviewItemController.onLog.listen((event) {
      debugPrint('[kazumi webview parser]: $event');
      if (event == 'clear') {
        clearWebviewLog();
        return;
      }
      if (event == 'showDebug') {
        showDebugConsole();
        return;
      }

      // 检测解析失败并记录
      if (event.contains('解析视频资源超时')) {
        _handleParseFailure();
      }

      // ✅ Update webviewLogLines via Riverpod provider
      final currentLogs = ref.read(webviewLogLinesProvider);
      ref.read(webviewLogLinesProvider.notifier).state = [
        ...currentLogs,
        event
      ];
    });
  }

  /// 处理视频解析失败,记录到数据库
  void _handleParseFailure() {
    // 若视频流已成功定位或播放器已加载媒体，杜绝误报与误记失败
    if (webviewItemController.isVideoSourceLoaded ||
        (playerController.videoUrl.isNotEmpty &&
            !ref.read(playerProvider).loading)) {
      return;
    }
    try {
      final bangumiItem = videoPageController.bangumiItem;
      final videoState = ref.read(videoProvider);
      final plugin = videoState.currentPlugin;
      final src = videoPageController.src;

      if (plugin != null && src.isNotEmpty) {
        ParseFailureHelper.recordFailure(
          bangumiId: bangumiItem.id,
          pluginName: plugin.name,
          src: src,
          reason: 'timeout',
        );
      }
    } catch (e) {
      KazumiLogger().log(Level.error, '记录解析失败时出错: $e');
    }
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (_) {}
    try {
      observerController.controller?.dispose();
    } catch (_) {}
    try {
      animation.dispose();
    } catch (_) {}
    try {
      _initSubscription.cancel();
    } catch (_) {}
    try {
      _videoLoadedSubscription.cancel();
    } catch (_) {}
    try {
      _videoURLSubscription.cancel();
    } catch (_) {}
    try {
      _logSubscription.cancel();
    } catch (_) {}
    try {
      _webviewLogController.dispose();
    } catch (_) {}
    try {
      _playerLogController.dispose();
    } catch (_) {}
    if (!Utils.isDesktop()) {
      try {
        ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    unawaited(playerController.stop(updateState: false));
    Utils.unlockScreenRotation();
    tabController.dispose();
    super.dispose();
  }

  // Handle fullscreen change invoked by system controls
  @override
  void onWindowEnterFullScreen() {
    videoPageController.handleOnEnterFullScreen();
  }

  @override
  void onWindowLeaveFullScreen() {
    videoPageController.handleOnExitFullScreen();
  }

  void showDebugConsole() {
    // ✅ Update state via Riverpod provider
    ref.read(showDebugLogProvider.notifier).state = true;
  }

  void hideDebugConsole() {
    // ✅ Update state via Riverpod provider
    ref.read(showDebugLogProvider.notifier).state = false;
  }

  void switchDebugConsole() {
    // ✅ Update state via Riverpod provider
    final current = ref.read(showDebugLogProvider);
    ref.read(showDebugLogProvider.notifier).state = !current;
  }

  void clearWebviewLog() {
    // ✅ Update state via Riverpod provider
    ref.read(webviewLogLinesProvider.notifier).state = [];
  }

  void _initializeVideoPageState() {
    // Initialize video page state immediately instead of waiting for next frame
    videoPageController.isDesktopFullscreen();
    videoPageController.currentEpisode = 1;
    videoPageController.currentRoad = 0;
    videoPageController.historyOffset = 0;
    videoPageController.showTabBody = true;
    if (videoPageController.bangumiItemOrNull == null) {
      videoPageController.bangumiItem = BangumiItem.dummy(
        title: videoPageController.title.isNotEmpty
            ? videoPageController.title
            : '未知视频',
      );
    }

    // Try to restore playback progress from history
    try {
      final pluginName = videoPageController.currentPluginOrNull?.name ?? '';
      if (pluginName.isNotEmpty) {
        final progress = historyController.lastWatching(
          videoPageController.bangumiItem,
          pluginName,
        );
        if (progress != null &&
            videoPageController.roadList.length > progress.road &&
            videoPageController.roadList[progress.road].data.length >=
                progress.episode) {
          videoPageController.currentEpisode = progress.episode;
          videoPageController.currentRoad = progress.road;
          if (playResume) {
            videoPageController.historyOffset = progress.progress.inSeconds;
          }
        }
      }
    } catch (_) {
      // Ignore progress restoration errors
    }

    // ✅ Update currentRoad via Riverpod provider
    ref.read(currentRoadProvider.notifier).state =
        videoPageController.currentRoad;
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    clearWebviewLog();
    hideDebugConsole();
    videoPageController.loading = true;
    videoPageController.resetEpisodeInfo();
    videoPageController.clearEpisodeComments();
    await playerController.stop();
    await videoPageController.changeEpisode(episode,
        currentRoad: currentRoad, offset: offset);
  }

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () async {
      await observerController.jumpTo(
          index: videoPageController.currentEpisode > 1
              ? videoPageController.currentEpisode - 1
              : videoPageController.currentEpisode);
    });
  }

  void openTabBodyAnimated() {
    if (videoPageController.showTabBody) {
      if (!disableAnimations) {
        animation.forward();
      }
      menuJumpToCurrentEpisode();
    }
  }

  void closeTabBodyAnimated() {
    if (!disableAnimations) {
      animation.reverse();
      Future.delayed(const Duration(milliseconds: 120), () {
        videoPageController.showTabBody = false;
      });
    } else {
      videoPageController.showTabBody = false;
    }
    keyboardFocus.requestFocus();
  }

  void onBackPressed(BuildContext context) async {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (videoPageController.isPip) {
      Utils.exitDesktopPIPWindow();
      videoPageController.isPip = false;
      return;
    }
    if (videoPageController.isFullscreen && !Utils.isTablet()) {
      menuJumpToCurrentEpisode();
      await Utils.exitFullScreen();
      videoPageController.showTabBody = false;
      videoPageController.isFullscreen = false;
      return;
    }
    if (videoPageController.isFullscreen) {
      Utils.exitFullScreen();
      videoPageController.isFullscreen = false;
    }
    await playerController.stop();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 发送弹幕 由于接口限制, 暂时未提交云端
  void sendDanmaku(String msg) async {
    keyboardFocus.requestFocus();
    final t = context.t;
    final playerState = ref.read(playerProvider);
    if (playerState.danDanmakus.isEmpty) {
      KazumiDialog.showToast(
        message: t.playback.toast.danmakuUnsupported,
      );
      return;
    }
    if (msg.isEmpty) {
      KazumiDialog.showToast(message: t.playback.toast.danmakuEmpty);
      return;
    } else if (msg.length > 100) {
      KazumiDialog.showToast(message: t.playback.toast.danmakuTooLong);
      return;
    }
    // Todo 接口方限制

    playerController.danmakuController
        .addDanmaku(DanmakuContentItem(msg, selfSend: true));
  }

  void showMobileDanmakuInput() {
    final TextEditingController textController = TextEditingController();
    final t = context.t;
    showModalBottomSheet(
      shape: const BeveledRectangleBorder(),
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 34),
                  child: TextField(
                    style: const TextStyle(fontSize: 15),
                    controller: textController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      filled: true,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      hintText: t.playback.danmaku.inputHint,
                      hintStyle: const TextStyle(fontSize: 14),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onSubmitted: (msg) {
                      sendDanmaku(msg);
                      textController.clear();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  sendDanmaku(textController.text);
                  textController.clear();
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.send_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final videoState = ref.watch(videoProvider);
    final playerState = ref.watch(playerProvider);
    final debugModeFromProvider =
        ref.watch(playerSettingsProvider.select((s) => s.playerDebugMode));
    final storedDebugMode = setting.get(
      SettingBoxKey.playerDebugMode,
      defaultValue: kDebugMode,
    ) as bool;
    final debugModeEnabled = debugModeFromProvider || storedDebugMode;

    // Trigger animation when showTabBody becomes true
    ref.listen(videoProvider.select((s) => s.showTabBody), (prev, next) {
      if (next && (prev == null || !prev)) {
        // Use microtask for lighter weight than PostFrameCallback
        Future.microtask(() {
          if (mounted) {
            openTabBodyAnimated();
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: OrientationBuilder(builder: (context, orientation) {
        if (!Utils.isDesktop()) {
          if (orientation == Orientation.landscape &&
              !videoState.isFullscreen) {
            videoPageController.enterFullScreen();
          } else if (orientation == Orientation.portrait &&
              videoState.isFullscreen) {
            videoPageController.exitFullScreen();
            menuJumpToCurrentEpisode();
            videoPageController.showTabBody = true;
          }
        }
        final plugin = videoState.currentPlugin;
        final isFullscreen = videoState.isFullscreen;

        // Debug: Log plugin info
        if (debugModeEnabled && plugin != null) {
          debugPrint('[Video Page] Plugin: ${plugin.name}, useNativePlayer: ${plugin.useNativePlayer}');
        } else if (debugModeEnabled) {
          debugPrint('[Video Page] Plugin is null!');
        }

        // ✅ Watch UI state from Riverpod providers in builder scope
        final showDebugLog = ref.watch(showDebugLogProvider);
        final webviewLogLines = ref.watch(webviewLogLinesProvider);
        final currentRoad = ref.watch(currentRoadProvider);

        return Scaffold(
          appBar: ((plugin?.useNativePlayer ?? false) || isFullscreen)
              ? null
              : SysAppBar(title: Text(videoState.title)),
          body: SafeArea(
              top: !isFullscreen,
              // set iOS and Android navigation bar to immersive
              bottom: false,
              left: !isFullscreen,
              right: !isFullscreen,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      Flexible(
                        // make it unflexible when not wideScreen.
                        flex: (isWideScreen) ? 1 : 0,
                        child: Container(
                          color: Colors.black,
                          height: (isWideScreen)
                              ? MediaQuery.sizeOf(context).height
                              : MediaQuery.sizeOf(context).width * 9 / 16,
                          width: MediaQuery.sizeOf(context).width,
                          child: playerBody(
                            videoState,
                            playerState,
                            debugModeEnabled,
                            showDebugLog,
                            webviewLogLines,
                          ),
                        ),
                      ),
                      // when not wideScreen, show tabBody on the bottom
                      if (!isWideScreen)
                        Expanded(child: tabBody(videoState, playerState)),
                    ],
                  ),

                  // when is wideScreen, show tabBody on the right side with SlideTransition or direct visibility
                  if (isWideScreen && videoState.showTabBody) ...[
                    if (disableAnimations) ...[
                      sideTabMask(videoState),
                      sideTabBody(videoState, playerState,
                          currentRoad), // ✅ Pass currentRoad
                    ] else ...[
                      FadeTransition(
                        opacity: _maskOpacityAnimation,
                        child: sideTabMask(videoState),
                      ),
                      SlideTransition(
                        position: _rightOffsetAnimation,
                        child: sideTabBody(videoState, playerState,
                            currentRoad), // ✅ Pass currentRoad
                      ),
                    ],
                  ],
                  if (debugModeEnabled && showDebugLog)
                    Positioned.fill(
                      child: _buildDebugOverlay(
                        playerState: playerState,
                        videoState: videoState,
                        isLoading: videoState.loading,
                        isPlayerLoading: playerState.loading,
                        useNativePlayer: plugin?.useNativePlayer ?? false,
                        webviewLogLines:
                            webviewLogLines, // ✅ Pass webviewLogLines
                      ),
                    ),
                ],
              )),
        );
      }),
    );
  }

  Widget sideTabBody(
      VideoPageState videoState, PlayerState playerState, int currentRoad) {
    // ✅ Added currentRoad parameter
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      width: (!Utils.isDesktop() && !Utils.isTablet())
          ? MediaQuery.sizeOf(context).height
          : (MediaQuery.sizeOf(context).width / 3 > 420
              ? 420
              : MediaQuery.sizeOf(context).width / 3),
      child: Container(
        color: Theme.of(context).canvasColor,
        child: GridViewObserver(
          controller: observerController,
          child: (Utils.isDesktop() || Utils.isTablet())
              ? tabBody(videoState, playerState)
              : Column(
                  children: [
                    menuBar(videoState, currentRoad), // ✅ Pass currentRoad
                    menuBody(videoState, currentRoad), // ✅ Pass currentRoad
                  ],
                ),
        ),
      ),
    );
  }

  Widget sideTabMask(VideoPageState _) {
    return GestureDetector(
      onTap: closeTabBodyAnimated,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget playerBody(
    VideoPageState videoState,
    PlayerState playerState,
    bool debugModeEnabled,
    bool showDebugLog, // ✅ Added showDebugLog parameter
    List<String> webviewLogLines, // ✅ Added webviewLogLines parameter
  ) {
    final t = context.t;
    final plugin = videoState.currentPlugin;
    final useNativePlayer = plugin?.useNativePlayer ?? false;
    final isFullscreen = videoState.isFullscreen;
    final isLoading = videoState.loading;
    final isPlayerLoading = playerState.loading;
    final isPlayerPlaying = playerState.playing ||
        (playerController.mediaPlayer?.state.playing ?? false) ||
        playerState.currentPosition > Duration.zero ||
        playerState.playerWidth > 0;
    final isPlayerActive = (useNativePlayer &&
        playerController.videoUrl.isNotEmpty &&
        (!isPlayerLoading || isPlayerPlaying));
    final isParseTimedOut = !isPlayerActive &&
        !isPlayerPlaying &&
        playerController.videoUrl.isEmpty &&
        webviewLogLines.any((log) => log.contains('解析视频资源超时'));

    return Stack(
      children: [
        // webview log component (not player log, used for video parsing)
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: (useNativePlayer &&
                        isPlayerLoading &&
                        !isLoading &&
                        !isPlayerPlaying)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer),
                            const SizedBox(height: 10),
                            Text(t.playback.loading.player,
                                style: const TextStyle(
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      )
                    : Container(),
              ),
              // Show loading or parse failure message
              Visibility(
                visible: (isLoading || isParseTimedOut) &&
                    !isPlayerActive &&
                    !isPlayerPlaying,
                child: Container(
                  color: Colors.black,
                  child: Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isLoading)
                              CircularProgressIndicator(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .tertiaryContainer),
                            if (isLoading) const SizedBox(height: 10),
                            Text(
                                isParseTimedOut
                                    ? t.playback.loading.parseFailed
                                    : t.playback.loading.parsing,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                )),
                          ],
                        ),
                      )),
                ),
              ),
              // Top control bar: Always visible during loading or parse failure
              // (Normal fullscreen controls are managed exclusively by PlayerItemPanel to prevent duplicate back buttons)
              if ((isLoading && !isPlayerPlaying) ||
                  (isParseTimedOut && !isPlayerActive))
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DesktopWindowControlsSafeArea(
                    requireOffset: !isFullscreen,
                    child: EmbeddedNativeControlArea(
                      requireOffset: !isFullscreen,
                      child: Row(
                        children: [
                          AppBackButton(
                            color: Colors.white,
                            onPressed: () => onBackPressed(context),
                          ),
                        const Expanded(
                          child: dtb.DragToMoveArea(child: SizedBox(height: 40)),
                        ),
                        Builder(builder: (context) {
                          final items = <KazumiActionItem>[
                            KazumiActionItem(
                              icon: Icons.refresh_outlined,
                              tooltip: '刷新',
                              color: Colors.white,
                              onPressed: () {
                                changeEpisode(
                                  videoState.currentEpisode,
                                  currentRoad: videoState.currentRoad,
                                );
                              },
                            ),
                          ];
                          final isWide = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
                          if (isWide) {
                            items.add(
                              KazumiActionItem(
                                icon: videoState.showTabBody ? Icons.menu_open : Icons.menu_open_outlined,
                                tooltip: videoState.showTabBody ? '关闭侧栏' : '打开侧栏',
                                color: Colors.white,
                                onPressed: () {
                                  videoPageController.showTabBody = !videoState.showTabBody;
                                  openTabBodyAnimated();
                                },
                              ),
                            );
                          }
                          if (debugModeEnabled) {
                            items.add(
                              KazumiActionItem(
                                icon: showDebugLog ? Icons.bug_report : Icons.bug_report_outlined,
                                tooltip: '调试',
                                color: Colors.white,
                                onPressed: switchDebugConsole,
                              ),
                            );
                          }
                          return KazumiAppBarActions(items: items, iconSize: 22);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: (!useNativePlayer ||
                  (isPlayerLoading &&
                      playerController.videoUrl.isEmpty &&
                      !isPlayerPlaying))
              ? Container()
              : PlayerItem(
                  openMenu: openTabBodyAnimated,
                  locateEpisode: menuJumpToCurrentEpisode,
                  changeEpisode: changeEpisode,
                  onBackPressed: onBackPressed,
                  keyboardFocus: keyboardFocus,
                  sendDanmaku: sendDanmaku,
                  disableAnimations: disableAnimations,
                ),
        ),

        /// workaround for webview_windows
        /// The webview_windows component cannot be removed from the widget tree; otherwise, it can never be reinitialized.
        Positioned(
          child: SizedBox(
            height: (isLoading || useNativePlayer) ? 0 : null,
            child: WebviewItem(
              videoPageController: videoPageController,
              webviewController: webviewItemController,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugOverlay({
    required PlayerState playerState,
    required VideoPageState videoState,
    required bool isLoading,
    required bool isPlayerLoading,
    required bool useNativePlayer,
    required List<String> webviewLogLines, // ✅ Added parameter
  }) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        );
    final sectionHeaderStyle = theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
          height: 1.35,
        ) ??
        const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.35,
        );

    final bangumiItem = videoState.bangumiItem;
    final bangumiName = bangumiItem == null
        ? '--'
        : (bangumiItem.nameCn.isNotEmpty
            ? bangumiItem.nameCn
            : bangumiItem.name);
    final plugin = videoState.currentPlugin;
    final roadCount = videoState.roadList.length;
    final hasRoad = roadCount > 0 &&
        videoState.currentRoad >= 0 &&
        videoState.currentRoad < roadCount;
    final roadName =
        hasRoad ? videoState.roadList[videoState.currentRoad].name : '--';
    final totalEpisodes =
        hasRoad ? videoState.roadList[videoState.currentRoad].data.length : 0;
    final episodeText = totalEpisodes > 0
        ? '${videoState.currentEpisode} / $totalEpisodes'
        : '${videoState.currentEpisode}';
    final hasPlayer = playerController.mediaPlayer != null;
    final resolution =
        (playerState.playerWidth > 0 && playerState.playerHeight > 0)
            ? '${playerState.playerWidth} × ${playerState.playerHeight}'
            : '--';
    const aspectRatioLabels = {
      1: '自动',
      2: '裁剪',
      3: '拉伸',
    };
    const superResolutionLabels = {
      1: '关闭',
      2: 'Anime4K Lite',
      3: 'Anime4K HQ',
    };
    final aspectRatioLabel = aspectRatioLabels[playerState.aspectRatioType] ??
        playerState.aspectRatioType.toString();
    final superResolutionLabel =
        superResolutionLabels[playerState.superResolutionType] ??
            playerState.superResolutionType.toString();
    final volumeText = playerState.volume < 0
        ? '--'
        : '${playerState.volume.toStringAsFixed(1)}%';
    final brightnessText = playerState.brightness > 0
        ? playerState.brightness.toStringAsFixed(2)
        : '--';
    final syncRoom =
        playerState.syncplayRoom.isEmpty ? '--' : playerState.syncplayRoom;
    final syncRtt = playerState.syncplayClientRtt <= 0
        ? '--'
        : '${playerState.syncplayClientRtt} ms';

    final sourceSection = <Widget>[
      _buildKeyValue('番剧', bangumiName, labelStyle, valueStyle),
      _buildKeyValue('插件', plugin?.name ?? '--', labelStyle, valueStyle),
      _buildKeyValue('线路', roadName, labelStyle, valueStyle),
      _buildKeyValue('集数', episodeText, labelStyle, valueStyle),
      _buildKeyValue('线路数量', roadCount.toString(), labelStyle, valueStyle),
      _buildKeyValue('源标题', videoState.title, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue('解析地址', videoState.src, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue(
        '播放地址',
        playerController.videoUrl.isEmpty ? '--' : playerController.videoUrl,
        labelStyle,
        valueStyle,
        multiline: true,
      ),
      _buildKeyValue(
        'DanDan ID',
        playerController.bangumiID == 0
            ? '--'
            : playerController.bangumiID.toString(),
        labelStyle,
        valueStyle,
      ),
      _buildKeyValue('SyncPlay 房间', syncRoom, labelStyle, valueStyle),
      _buildKeyValue('SyncPlay RTT', syncRtt, labelStyle, valueStyle),
    ];

    final playbackSection = <Widget>[
      _buildKeyValue('插件名称', plugin?.name ?? '--', labelStyle, valueStyle),
      _buildKeyValue(
          '原生播放器', useNativePlayer ? '是' : '否', labelStyle, valueStyle),
      _buildKeyValue(
          '原生播放器(从插件)',
          plugin?.useNativePlayer == true ? '是' : (plugin?.useNativePlayer == false ? '否' : '--'),
          labelStyle,
          valueStyle),
      _buildKeyValue('解析中', isLoading ? '是' : '否', labelStyle, valueStyle),
      _buildKeyValue(
          '播放器加载', isPlayerLoading ? '是' : '否', labelStyle, valueStyle),
      _buildKeyValue(
          '播放器初始化', playerState.loading ? '是' : '否', labelStyle, valueStyle),
      _buildKeyValue(
        '播放中',
        hasPlayer ? (playerController.playerPlaying ? '是' : '否') : '--',
        labelStyle,
        valueStyle,
      ),
      _buildKeyValue(
        '缓冲中',
        hasPlayer ? (playerController.playerBuffering ? '是' : '否') : '--',
        labelStyle,
        valueStyle,
      ),
      _buildKeyValue(
        '播放完成',
        hasPlayer ? (playerController.playerCompleted ? '是' : '否') : '--',
        labelStyle,
        valueStyle,
      ),
      _buildKeyValue(
          '缓冲标志', playerState.isBuffering ? '是' : '否', labelStyle, valueStyle),
    ];

    final timingSection = <Widget>[
      _buildKeyValue('当前位置', _formatDuration(playerState.currentPosition),
          labelStyle, valueStyle),
      _buildKeyValue(
          '缓冲进度', _formatDuration(playerState.buffer), labelStyle, valueStyle),
      _buildKeyValue(
          '总时长', _formatDuration(playerState.duration), labelStyle, valueStyle),
      _buildKeyValue('播放速度', '${playerState.playerSpeed.toStringAsFixed(2)}x',
          labelStyle, valueStyle),
      _buildKeyValue('音量', volumeText, labelStyle, valueStyle),
      _buildKeyValue('亮度', brightnessText, labelStyle, valueStyle),
      _buildKeyValue('分辨率', resolution, labelStyle, valueStyle),
      _buildKeyValue('Aspect Ratio', aspectRatioLabel, labelStyle, valueStyle),
      _buildKeyValue('超分辨率', superResolutionLabel, labelStyle, valueStyle),
    ];

    final mediaSection = <Widget>[
      _buildKeyValue(
          '视频参数', playerState.playerVideoParams, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue(
          '音频参数', playerState.playerAudioParams, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue('播放列表', playerState.playerPlaylist, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue(
          '音频轨', playerState.playerAudioTracks, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue(
          '视频轨', playerState.playerVideoTracks, labelStyle, valueStyle,
          multiline: true),
      _buildKeyValue(
        '音频码率',
        playerState.playerAudioBitrate.isEmpty
            ? '--'
            : playerState.playerAudioBitrate,
        labelStyle,
        valueStyle,
      ),
    ];

    const maxLogLines = 200;
    final recentPlayerLogs = playerState.playerLog.length > maxLogLines
        ? playerState.playerLog
            .sublist(playerState.playerLog.length - maxLogLines)
        : List<String>.from(playerState.playerLog);
    final recentWebviewLogs = webviewLogLines.length > maxLogLines
        ? webviewLogLines.sublist(webviewLogLines.length - maxLogLines)
        : List<String>.from(webviewLogLines);

    final playerLogTitle = playerState.playerLog.isEmpty
        ? '播放器日志（0）'
        : '播放器日志（${playerState.playerLog.length} 条，展示 ${recentPlayerLogs.length} 条）';
    final webviewLogTitle = webviewLogLines.isEmpty
        ? 'WebView 日志（0）'
        : 'WebView 日志（${webviewLogLines.length} 条，展示 ${recentWebviewLogs.length} 条）';

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '调试信息',
                      style: titleStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: '复制所有调试信息',
                    onPressed: () => _copyAllDebugInfo(
                      bangumiName: bangumiName,
                      plugin: plugin,
                      roadName: roadName,
                      episodeText: episodeText,
                      roadCount: roadCount,
                      videoState: videoState,
                      playerController: playerController,
                      syncRoom: syncRoom,
                      syncRtt: syncRtt,
                      useNativePlayer: useNativePlayer,
                      isLoading: isLoading,
                      isPlayerLoading: isPlayerLoading,
                      playerState: playerState,
                      resolution: resolution,
                      aspectRatioLabel: aspectRatioLabel,
                      superResolutionLabel: superResolutionLabel,
                      volumeText: volumeText,
                      brightnessText: brightnessText,
                      recentPlayerLogs: recentPlayerLogs,
                      recentWebviewLogs: recentWebviewLogs,
                    ),
                    icon: const Icon(Icons.copy, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: '关闭调试信息',
                    onPressed: switchDebugConsole,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('播放源', sourceSection, sectionHeaderStyle),
                      _buildSection(
                          '播放器状态', playbackSection, sectionHeaderStyle),
                      _buildSection('时间与参数', timingSection, sectionHeaderStyle),
                      _buildSection('媒体轨道', mediaSection, sectionHeaderStyle),
                      _buildLogViewer(
                        webviewLogTitle,
                        recentWebviewLogs,
                        sectionHeaderStyle,
                        valueStyle,
                        controller: _webviewLogController,
                      ),
                      _buildLogViewer(
                        playerLogTitle,
                        recentPlayerLogs,
                        sectionHeaderStyle,
                        valueStyle,
                        controller: _playerLogController,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Widget> children,
    TextStyle headerStyle,
  ) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headerStyle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildKeyValue(
    String label,
    String value,
    TextStyle labelStyle,
    TextStyle valueStyle, {
    bool multiline = false,
  }) {
    final displayValue = value.isEmpty ? '--' : value;
    if (multiline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 4),
            SelectableText(displayValue, style: valueStyle),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: labelStyle),
            TextSpan(text: displayValue, style: valueStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildLogViewer(
    String title,
    List<String> lines,
    TextStyle headerStyle,
    TextStyle valueStyle, {
    ScrollController? controller,
  }) {
    if (lines.isEmpty) {
      return _buildSection(
        title,
        [SelectableText('--', style: valueStyle)],
        headerStyle,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headerStyle),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Scrollbar(
              controller: controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: controller,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    lines[index],
                    style: valueStyle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyAllDebugInfo({
    required String bangumiName,
    required Plugin? plugin,
    required String roadName,
    required String episodeText,
    required int roadCount,
    required VideoPageState videoState,
    required PlayerController playerController,
    required String syncRoom,
    required String syncRtt,
    required bool useNativePlayer,
    required bool isLoading,
    required bool isPlayerLoading,
    required PlayerState playerState,
    required String resolution,
    required String aspectRatioLabel,
    required String superResolutionLabel,
    required String volumeText,
    required String brightnessText,
    required List<String> recentPlayerLogs,
    required List<String> recentWebviewLogs,
  }) {
    final hasPlayer = playerController.mediaPlayer != null;

    final buffer = StringBuffer();
    buffer.writeln('=== Kazumi 调试信息 ===');
    buffer.writeln();

    // 播放源
    buffer.writeln('【播放源】');
    buffer.writeln('番剧: $bangumiName');
    buffer.writeln('插件: ${plugin?.name ?? '--'}');
    buffer.writeln('线路: $roadName');
    buffer.writeln('集数: $episodeText');
    buffer.writeln('线路数量: $roadCount');
    buffer.writeln('源标题: ${videoState.title}');
    buffer.writeln('解析地址: ${videoState.src}');
    buffer.writeln('播放地址: ${playerController.videoUrl.isEmpty ? '--' : playerController.videoUrl}');
    buffer.writeln('DanDan ID: ${playerController.bangumiID == 0 ? '--' : playerController.bangumiID}');
    buffer.writeln('SyncPlay 房间: $syncRoom');
    buffer.writeln('SyncPlay RTT: $syncRtt');
    buffer.writeln();

    // 播放器状态
    buffer.writeln('【播放器状态】');
    buffer.writeln('插件名称: ${plugin?.name ?? '--'}');
    buffer.writeln('原生播放器: ${useNativePlayer ? '是' : '否'}');
    buffer.writeln('原生播放器(从插件): ${plugin?.useNativePlayer == true ? '是' : (plugin?.useNativePlayer == false ? '否' : '--')}');
    buffer.writeln('解析中: ${isLoading ? '是' : '否'}');
    buffer.writeln('播放器加载: ${isPlayerLoading ? '是' : '否'}');
    buffer.writeln('播放器初始化: ${playerState.loading ? '是' : '否'}');
    buffer.writeln('播放中: ${hasPlayer ? (playerController.playerPlaying ? '是' : '否') : '--'}');
    buffer.writeln('缓冲中: ${hasPlayer ? (playerController.playerBuffering ? '是' : '否') : '--'}');
    buffer.writeln('播放完成: ${hasPlayer ? (playerController.playerCompleted ? '是' : '否') : '--'}');
    buffer.writeln('缓冲标志: ${playerState.isBuffering ? '是' : '否'}');
    buffer.writeln();

    // 时间与参数
    buffer.writeln('【时间与参数】');
    buffer.writeln('当前位置: ${_formatDuration(playerState.currentPosition)}');
    buffer.writeln('缓冲进度: ${_formatDuration(playerState.buffer)}');
    buffer.writeln('总时长: ${_formatDuration(playerState.duration)}');
    buffer.writeln('播放速度: ${playerState.playerSpeed.toStringAsFixed(2)}x');
    buffer.writeln('音量: $volumeText');
    buffer.writeln('亮度: $brightnessText');
    buffer.writeln('分辨率: $resolution');
    buffer.writeln('Aspect Ratio: $aspectRatioLabel');
    buffer.writeln('超分辨率: $superResolutionLabel');
    buffer.writeln();

    // 媒体轨道
    buffer.writeln('【媒体轨道】');
    buffer.writeln('视频参数: ${playerState.playerVideoParams}');
    buffer.writeln('音频参数: ${playerState.playerAudioParams}');
    buffer.writeln('播放列表: ${playerState.playerPlaylist}');
    buffer.writeln('音频轨: ${playerState.playerAudioTracks}');
    buffer.writeln('视频轨: ${playerState.playerVideoTracks}');
    buffer.writeln('音频码率: ${playerState.playerAudioBitrate.isEmpty ? '--' : playerState.playerAudioBitrate}');
    buffer.writeln();

    // WebView 日志
    buffer.writeln('【WebView 日志】');
    if (recentWebviewLogs.isEmpty) {
      buffer.writeln('--');
    } else {
      for (final log in recentWebviewLogs) {
        buffer.writeln(log);
      }
    }
    buffer.writeln();

    // 播放器日志
    buffer.writeln('【播放器日志】');
    if (recentPlayerLogs.isEmpty) {
      buffer.writeln('--');
    } else {
      for (final log in recentPlayerLogs) {
        buffer.writeln(log);
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    KazumiDialog.showToast(
      message: context.t.playback.toast.clipboardCopied,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return '--:--';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  Widget menuBar(VideoPageState videoState, int currentRoad) {
    // ✅ Added currentRoad parameter
    final t = context.t;
    String playlistLabel(int index) =>
        t.playback.playlist.list.replaceFirst('{index}', '$index');
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t.playback.playlist.collection),
          Expanded(
            child: Text(
              videoState.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          MenuAnchor(
            consumeOutsideTap: true,
            builder: (_, MenuController controller, __) {
              return SizedBox(
                height: 34,
                child: TextButton(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: Text(
                    playlistLabel(currentRoad + 1),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            },
            menuChildren: List<MenuItemButton>.generate(
              videoState.roadList.length,
              (int i) => MenuItemButton(
                onPressed: () {
                  // ✅ Update currentRoad via Riverpod provider
                  ref.read(currentRoadProvider.notifier).state = i;
                },
                child: Container(
                  height: 48,
                  constraints: BoxConstraints(minWidth: 112),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      playlistLabel(i + 1),
                      style: TextStyle(
                        color: i == currentRoad
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget menuBody(VideoPageState videoState, int currentRoad) {
    // ✅ Added currentRoad parameter
    final cardList = <Widget>[];
    for (var roadIndex = 0;
        roadIndex < videoState.roadList.length;
        roadIndex++) {
      if (roadIndex != currentRoad) continue;
      final road = videoState.roadList[roadIndex];
      for (var episodeIndex = 0;
          episodeIndex < road.data.length;
          episodeIndex++) {
        final currentIndex = episodeIndex + 1;
        final urlItem = road.data[episodeIndex];
        cardList.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: Theme.of(context).colorScheme.onInverseSurface,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () async {
                  final isCurrentEpisode =
                      currentIndex == videoState.currentEpisode &&
                          videoState.currentRoad == currentRoad;
                  if (isCurrentEpisode) {
                    return;
                  }
                  KazumiLogger().log(Level.info, '视频链接为 $urlItem');
                  closeTabBodyAnimated();
                  changeEpisode(currentIndex, currentRoad: currentRoad);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (currentIndex == videoState.currentEpisode &&
                              currentRoad == videoState.currentRoad) ...[
                            Image.asset(
                              'assets/images/playing.gif',
                              color: Theme.of(context).colorScheme.primary,
                              height: 12,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              road.identifier[currentIndex - 1],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: (currentIndex ==
                                            videoState.currentEpisode &&
                                        currentRoad == videoState.currentRoad)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8, left: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final int crossCount =
                (constraints.maxWidth / 120.0).floor().clamp(2, 8);
            return GridView.builder(
              scrollDirection: Axis.vertical,
              controller: scrollController,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 5,
                mainAxisExtent: 70,
              ),
              itemCount: cardList.length,
              itemBuilder: (context, index) => cardList[index],
            );
          },
        ),
      ),
    );
  }

  Widget tabBody(VideoPageState videoState, PlayerState playerState) {
    final t = context.t;

    return Container(
      color: Theme.of(context).canvasColor,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TabBar(
                  controller: tabController,
                  dividerHeight: 0,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding:
                      const EdgeInsetsDirectional.only(start: 30, end: 30),
                  onTap: (index) {
                    if (index == 0) {
                      menuJumpToCurrentEpisode();
                    }
                  },
                  tabs: [
                    Tab(text: t.playback.tabs.episodes),
                    Tab(text: t.playback.tabs.comments),
                  ],
                ),
                if (MediaQuery.sizeOf(context).width <=
                    MediaQuery.sizeOf(context).height) ...[
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: playerState.danmakuOn
                            ? Theme.of(context).hintColor
                            : Theme.of(context).disabledColor,
                        width: 0.5,
                      ),
                    ),
                    width: 120,
                    height: 31,
                    child: GestureDetector(
                      onTap: () {
                        if (playerState.danmakuOn && !videoState.loading) {
                          showMobileDanmakuInput();
                        } else if (videoState.loading) {
                          KazumiDialog.showToast(
                            message: t.playback.toast.waitForVideo,
                          );
                        } else {
                          KazumiDialog.showToast(
                            message: t.playback.toast.enableDanmakuFirst,
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            playerState.danmakuOn
                                ? t.playback.danmaku.mobileButton
                                : t.playback.danmaku.mobileButtonDisabled,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: playerState.danmakuOn
                                  ? Theme.of(context).hintColor
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                          Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: playerState.danmakuOn
                                ? Theme.of(context).hintColor
                                : Theme.of(context).disabledColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            Divider(height: Utils.isDesktop() ? 0.5 : 0.2),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  GridViewObserver(
                    controller: observerController,
                    child: Column(
                      children: [
                        menuBar(
                            videoState,
                            videoState
                                .currentRoad), // ✅ Pass videoState.currentRoad
                        menuBody(
                            videoState,
                            videoState
                                .currentRoad), // ✅ Pass videoState.currentRoad
                      ],
                    ),
                  ),
                  // ✅ No need for EpisodeInfo InheritedWidget - use Riverpod provider instead
                  const EpisodeCommentsSheet(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
