import 'dart:async';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';
import 'package:kazumi/modules/bilibili/bilibili_service.dart';
import 'package:kazumi/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/pages/player/player_state.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/video_state.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:logger/logger.dart';

class SmallestPlayerItemPanel extends ConsumerStatefulWidget {
  const SmallestPlayerItemPanel({
    super.key,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.handleSuperResolutionChange,
    required this.animationController,
    required this.keyboardFocus,
    required this.handleHove,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.handleDanmaku,
    required this.showVideoInfo,
    required this.showSyncPlayRoomCreateDialog,
    required this.showSyncPlayEndPointSwitchDialog,
    this.disableAnimations = false,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final void Function() handleDanmaku;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final Future<void> Function(int shaderIndex) handleSuperResolutionChange;
  final void Function() handleHove;
  final AnimationController animationController;
  final FocusNode keyboardFocus;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayRoomCreateDialog;
  final void Function() showSyncPlayEndPointSwitchDialog;
  final bool disableAnimations;

  @override
  ConsumerState<SmallestPlayerItemPanel> createState() =>
      _SmallestPlayerItemPanelState();
}

class _SmallestPlayerItemPanelState
    extends ConsumerState<SmallestPlayerItemPanel> {
  late final VideoPageController videoPageController;
  late final PlayerController playerController;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  bool _dismissedBiliLoginPrompt = false;
  bool _initialBiliPromptPhase = true;
  Timer? _biliPromptTimer;

  @override
  void initState() {
    super.initState();
    playerController = ref.read(playerProvider.notifier);
    videoPageController = ref.read(videoProvider.notifier);
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeInOut,
      ),
    );
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeInOut,
      ),
    );
    _biliPromptTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _initialBiliPromptPhase = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _biliPromptTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBiliStreamWithNewAuth() async {
    final biliCid = playerController.activeBiliCid;
    final biliBvid = playerController.activeBiliBvid ??
        playerController.activeLocalVideoArgs?.biliBvid;
    if (biliCid == null || biliBvid == null || biliBvid.isEmpty) return;

    try {
      KazumiDialog.showToast(message: '已成功登录！正在为您切换 1080P/4K 高清画质流...');
      final playUrl = await BilibiliService.getPlayUrl(biliBvid, biliCid);
      if (playUrl != null && playUrl.videoUrl.isNotEmpty) {
        final currentPos = playerController.playerPosition;
        await playerController.init(
          playUrl.videoUrl,
          audioUrl: playUrl.audioUrl,
          httpHeaders: playUrl.headers,
          biliCid: biliCid,
          biliBvid: biliBvid,
        );
        if (currentPos > Duration.zero) {
          playerController.seek(currentPos);
        }
        playerController.play();
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '登录后切换高清流失败: $e');
    }
  }

  Widget _buildBiliLoginPrompt() {
    return ValueListenableBuilder<BiliUserProfile?>(
      valueListenable: BiliAuthService().userNotifier,
      builder: (context, user, _) {
        final isLogin = BiliAuthService().isLoggedIn && user != null;
        if (isLogin || _dismissedBiliLoginPrompt) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Colors.transparent,
          child: Container(
            key: const Key('player_bili_login_prompt'),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(210),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.pinkAccent.withAlpha(140),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tv_rounded,
                  size: 16,
                  color: Colors.pinkAccent,
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    '当前为访客模式 (限360P) · 登录解锁 1080P/4K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('bili_player_login_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    widget.cancelHideTimer();
                    playerController.canHidePlayerPanel = false;
                    BiliLoginDialog.show(context).then((_) {
                      if (mounted) {
                        widget.cancelHideTimer();
                        widget.startHideTimer();
                        playerController.canHidePlayerPanel = true;
                        if (BiliAuthService().isLoggedIn) {
                          _refreshBiliStreamWithNewAuth();
                        }
                      }
                    });
                  },
                  child: const Text('立即登录', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                InkWell(
                  key: const Key('player_bili_login_prompt_close'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _biliPromptTimer?.cancel();
                    setState(() => _dismissedBiliLoginPrompt = true);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 15, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showForwardChange() {
    final t = context.t;
    KazumiDialog.show(builder: (context) {
      String input = '';
      return AlertDialog(
        title: Text(t.playback.controls.skip.title),
        content: TextField(
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            labelText: playerController.forwardTime.toString(),
          ),
          onChanged: (value) {
            input = value;
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              t.app.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (input.isNotEmpty) {
                playerController.setForwardTime(int.parse(input));
              }
              KazumiDialog.dismiss();
            },
            child: Text(t.app.confirm),
          ),
        ],
      );
    });
  }

  Widget forwardIcon() {
    final t = context.t;
    return Tooltip(
      message: t.playback.controls.skip.tooltip,
      child: GestureDetector(
        onLongPress: showForwardChange,
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: () {
            playerController.seek(
              playerController.currentPosition +
                  Duration(seconds: playerController.forwardTime),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final videoState = ref.watch(videoProvider);
    final shouldShowOverlay =
        widget.disableAnimations ? playerState.showVideoController : true;
    final canShowControls = !playerState.lockPanel && shouldShowOverlay;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: canShowControls,
            child: widget.disableAnimations
                ? _buildTopGradient()
                : SlideTransition(
                    position: topOffsetAnimation,
                    child: _buildTopGradient(),
                  ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          bottom: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: canShowControls,
            child: widget.disableAnimations
                ? _buildBottomGradient()
                : SlideTransition(
                    position: bottomOffsetAnimation,
                    child: _buildBottomGradient(),
                  ),
          ),
        ),
        Positioned(
          top: 25,
          child: playerState.showSeekTime
              ? _buildInfoChip(
                  _buildSeekStatusText(playerState),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          top: 25,
          child: playerState.showPlaySpeed
              ? _buildInfoChipWidget(
                  Row(
                    children: [
                      const Icon(Icons.fast_forward, color: Colors.white),
                      Text(
                        ' ${context.t.playback.controls.status.speed}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          top: 25,
          child: playerState.showBrightness
              ? _buildInfoChipWidget(
                  Row(
                    children: [
                      const Icon(Icons.brightness_7, color: Colors.white),
                      Text(
                        ' ${(playerState.brightness * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          top: 25,
          child: playerState.showVolume
              ? _buildInfoChipWidget(
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white),
                      Text(
                        ' ${playerState.volume.toInt()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: canShowControls,
            child: widget.disableAnimations
                ? _buildTopControlWidget(playerState, videoState)
                : SlideTransition(
                    position: topOffsetAnimation,
                    child: _buildTopControlWidget(playerState, videoState),
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: canShowControls,
            child: widget.disableAnimations
                ? _buildBottomControlWidget(playerState, videoState)
                : SlideTransition(
                    position: bottomOffsetAnimation,
                    child: _buildBottomControlWidget(playerState, videoState),
                  ),
          ),
        ),
        if (playerController.isBiliPlayback &&
            !_dismissedBiliLoginPrompt &&
            !playerState.lockPanel &&
            (_initialBiliPromptPhase || playerState.showVideoController))
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _buildBiliLoginPrompt(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopGradient() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black45,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black45,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlWidget(
    PlayerState playerState,
    VideoPageState videoState,
  ) {
    return Row(
      children: [
        IconButton(
          color: Colors.white,
          icon: Icon(
            playerState.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
          onPressed: playerController.playOrPause,
        ),
        Expanded(
          child: ProgressBar(
            thumbRadius: 8,
            thumbGlowRadius: 18,
            timeLabelLocation: TimeLabelLocation.none,
            progress: playerState.currentPosition,
            buffered: playerState.buffer,
            total: playerState.duration,
            onSeek: playerController.seek,
            onDragStart: widget.handleProgressBarDragStart,
            onDragUpdate: (details) {
              playerController.currentPosition = details.timeStamp;
            },
            onDragEnd: widget.handleProgressBarDragEnd,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            '${Utils.durationToString(playerState.currentPosition)} / ${Utils.durationToString(playerState.duration)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.0,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
        videoState.isPip
            ? const SizedBox(width: 16)
            : IconButton(
                color: Colors.white,
                icon: Icon(
                  videoState.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
                onPressed: widget.handleFullscreen,
              ),
      ],
    );
  }

  Widget _buildTopControlWidget(
    PlayerState playerState,
    VideoPageState videoState,
  ) {
    final t = context.t;
    final svgString = danmakuOnSvg.replaceFirst(
      '00AEEC',
      Theme.of(context)
          .colorScheme
          .primary
          .toARGB32()
          .toRadixString(16)
          .substring(2),
    );

    return EmbeddedNativeControlArea(
      child: DesktopWindowControlsSafeArea(
        requireOffset: !videoState.isFullscreen,
        child: Row(
        children: [
          AppBackButton(
            color: Colors.white,
            onPressed: () {
              widget.onBackPressed(context);
            },
          ),
          Expanded(
            child: dtb.DragToMoveArea(
              child: Text(
                playerController.activeLocalVideoArgs?.title.isNotEmpty == true
                    ? ' ${playerController.activeLocalVideoArgs!.title}'
                    : ' ${videoState.title.isNotEmpty ? videoState.title : playerController.currentTitle}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Theme.of(context).textTheme.titleSmall?.fontSize ?? 14,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          forwardIcon(),
          if (Utils.isDesktop())
            IconButton(
              onPressed: () {
                if (videoState.isPip) {
                  Utils.exitDesktopPIPWindow();
                } else {
                  Utils.enterDesktopPIPWindow();
                }
                videoPageController.isPip = !videoState.isPip;
              },
              icon: const Icon(
                Icons.picture_in_picture,
                color: Colors.white,
              ),
            ),
          IconButton(
            color: Colors.white,
            icon: playerState.danmakuOn
                ? SvgPicture.string(
                    svgString,
                    height: 24,
                  )
                : SvgPicture.asset(
                    'assets/images/danmaku_off.svg',
                    height: 24,
                  ),
            onPressed: widget.handleDanmaku,
            tooltip: playerState.danmakuOn
                ? t.playback.controls.tooltips.danmakuOn
                : t.playback.controls.tooltips.danmakuOff,
          ),
          if (playerController.activeLocalVideoArgs == null &&
              videoState.bangumiItem != null &&
              !videoState.bangumiItem!.isDummyItem)
            CollectButton(
              bangumiItem: videoPageController.bangumiItem,
              onOpen: () {
                widget.cancelHideTimer();
                playerController.setCanHidePlayerPanel(false);
              },
              onClose: () {
                widget.cancelHideTimer();
                widget.startHideTimer();
                playerController.setCanHidePlayerPanel(true);
              },
            ),
          MenuAnchor(
            consumeOutsideTap: true,
            onOpen: () {
              widget.cancelHideTimer();
              playerController.setCanHidePlayerPanel(false);
            },
            onClose: () {
              widget.cancelHideTimer();
              widget.startHideTimer();
              playerController.setCanHidePlayerPanel(true);
            },
            builder:
                (BuildContext context, MenuController controller, Widget? _) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                ),
              );
            },
            menuChildren: [
              if (playerController.isBiliPlayback)
                ValueListenableBuilder<BiliUserProfile?>(
                  valueListenable: BiliAuthService().userNotifier,
                  builder: (context, user, _) {
                    final isLogin = BiliAuthService().isLoggedIn && user != null;
                    return MenuItemButton(
                      onPressed: () {
                        widget.cancelHideTimer();
                        playerController.setCanHidePlayerPanel(false);
                        BiliLoginDialog.show(context).then((_) {
                          if (mounted) {
                            widget.cancelHideTimer();
                            widget.startHideTimer();
                            playerController.setCanHidePlayerPanel(true);
                            if (BiliAuthService().isLoggedIn) {
                              _refreshBiliStreamWithNewAuth();
                            }
                          }
                        });
                      },
                      leadingIcon: Icon(
                        isLogin ? Icons.verified_user_rounded : Icons.login_rounded,
                        color: Colors.pinkAccent,
                        size: 20,
                      ),
                      child: _buildMenuItem(
                        title: isLogin
                            ? 'B站账号: ${user.uname}'
                            : '登录 B站 账号 (解锁 1080P/4K)',
                      ),
                    );
                  },
                ),
              SubmenuButton(
                menuChildren: List<MenuItemButton>.generate(
                  3,
                  (int index) => MenuItemButton(
                    onPressed: () =>
                        playerController.setAspectRatioType(index + 1),
                    child: _buildMenuItem(
                      title: index + 1 == 1
                          ? t.playback.controls.aspectRatio.options.auto
                          : index + 1 == 2
                              ? t.playback.controls.aspectRatio.options.crop
                              : t.playback.controls.aspectRatio.options.stretch,
                      highlighted: index + 1 == playerState.aspectRatioType,
                    ),
                  ),
                ),
                child: _buildMenuItem(
                    title: t.playback.controls.aspectRatio.label),
              ),
              SubmenuButton(
                menuChildren: [
                  for (final double speed in defaultPlaySpeedList)
                    MenuItemButton(
                      onPressed: () async {
                        await widget.setPlaybackSpeed(speed);
                      },
                      child: _buildMenuItem(
                        title: '${speed}x',
                        highlighted: speed == playerState.playerSpeed,
                      ),
                    ),
                ],
                child:
                    _buildMenuItem(title: t.playback.controls.speedMenu.label),
              ),
              SubmenuButton(
                menuChildren: List<MenuItemButton>.generate(
                  3,
                  (int index) => MenuItemButton(
                    onPressed: () =>
                        widget.handleSuperResolutionChange(index + 1),
                    child: _buildMenuItem(
                      title: index + 1 == 1
                          ? t.playback.controls.superResolution.off
                          : index + 1 == 2
                              ? t.playback.controls.superResolution.balanced
                              : t.playback.controls.superResolution.quality,
                      highlighted: playerState.superResolutionType == index + 1,
                    ),
                  ),
                ),
                child: _buildMenuItem(
                    title: playerState.superResolutionType == 1
                        ? t.playback.controls.superResolution.label
                        : '${t.playback.controls.superResolution.label} (${switch (playerState.superResolutionType) {
                            2 => t.playback.controls.superResolution.balanced,
                            3 => t.playback.controls.superResolution.quality,
                            _ => t.playback.controls.superResolution.off,
                          }})'),
              ),
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    child: _buildMenuItem(
                      title: t.playback.controls.syncplay.room.replaceFirst(
                        '{name}',
                        playerState.syncplayRoom.isEmpty
                            ? t.playback.controls.syncplay.roomEmpty
                            : playerState.syncplayRoom,
                      ),
                    ),
                  ),
                  MenuItemButton(
                    child: _buildMenuItem(
                      title: t.playback.controls.syncplay.latency.replaceFirst(
                        '{ms}',
                        playerState.syncplayClientRtt.toString(),
                      ),
                    ),
                  ),
                  MenuItemButton(
                    onPressed: widget.showSyncPlayRoomCreateDialog,
                    child: _buildMenuItem(
                        title: t.playback.controls.syncplay.join),
                  ),
                  MenuItemButton(
                    onPressed: widget.showSyncPlayEndPointSwitchDialog,
                    child: _buildMenuItem(
                        title: t.playback.controls.syncplay.switchServer),
                  ),
                  MenuItemButton(
                    onPressed: () async {
                      await playerController.exitSyncPlayRoom();
                    },
                    child: _buildMenuItem(
                        title: t.playback.controls.syncplay.disconnect),
                  ),
                ],
                child:
                    _buildMenuItem(title: t.playback.controls.syncplay.label),
              ),
              if (playerController.activeBiliCid == null ||
                  playerController.activeBiliCid! <= 0)
                MenuItemButton(
                  onPressed: widget.showDanmakuSwitch,
                  child: _buildMenuItem(
                      title: t.playback.controls.menu.danmakuToggle),
                ),
              MenuItemButton(
                onPressed: () {
                  showModalBottomSheet(
                    isScrollControlled: true,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                      maxWidth: (Utils.isDesktop() || Utils.isTablet())
                          ? MediaQuery.of(context).size.width * 9 / 16
                          : MediaQuery.of(context).size.width,
                    ),
                    clipBehavior: Clip.antiAlias,
                    context: context,
                    builder: (context) {
                      return DanmakuSettingsSheet(
                        danmakuController: playerController.danmakuController,
                      );
                    },
                  );
                },
                child: _buildMenuItem(title: t.settings.player.danmakuSettings),
              ),
              MenuItemButton(
                onPressed: widget.showVideoInfo,
                child:
                    _buildMenuItem(title: t.playback.controls.menu.videoInfo),
              ),
              MenuItemButton(
                onPressed: () {
                  final needRestart = playerState.playing;
                  playerController.pause();
                  RemotePlay()
                      .castVideo(
                    playerController.videoUrl,
                    videoPageController.currentPlugin.referer,
                  )
                      .whenComplete(() {
                    if (needRestart) {
                      playerController.play();
                    }
                  });
                },
                child: _buildMenuItem(title: t.playback.controls.menu.cast),
              ),
              MenuItemButton(
                onPressed: playerController.lanunchExternalPlayer,
                child: _buildMenuItem(title: t.playback.controls.menu.external),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildMenuItem({
    required String title,
    bool highlighted = false,
  }) {
    return Container(
      height: 48,
      constraints: const BoxConstraints(minWidth: 112),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: highlighted
            ? TextStyle(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
    );
  }

  String _buildSeekStatusText(PlayerState playerState) {
    final t = context.t;
    final diffSeconds =
        (playerState.currentPosition - playerController.playerPosition)
            .inSeconds
            .abs();
    final template =
        playerState.currentPosition.compareTo(playerController.playerPosition) >
                0
            ? t.playback.controls.status.fastForward
            : t.playback.controls.status.rewind;
    return template.replaceFirst('{seconds}', diffSeconds.toString());
  }

  Widget _buildInfoChip(String text) {
    return _buildInfoChipWidget(
      Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildInfoChipWidget(Widget child) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: child,
        ),
      ],
    );
  }
}
