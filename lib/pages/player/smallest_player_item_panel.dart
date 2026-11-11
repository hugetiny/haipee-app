import 'dart:async';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:haipee/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/bean/widget/collect_button.dart';
import 'package:haipee/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:haipee/bean/widget/embedded_native_control_area.dart';
import 'package:haipee/modules/bilibili/bilibili_auth_service.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/player/player_state.dart';
import 'package:haipee/pages/player/tracks_settings_sheet.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/pages/video/video_state.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/remote.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

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
    this.changeEpisode,
    this.openMenu,
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
  final Future<void> Function(int, {int currentRoad, int offset})? changeEpisode;
  final void Function()? openMenu;
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

  Future<void> _refreshBiliStreamWithNewAuth({int? targetQuality}) async {
    await playerController.switchBiliQuality(targetQuality: targetQuality);
  }

  String _buildTitleText(VideoPageState videoState) {
    final localArgs = playerController.activeLocalVideoArgs;
    if (localArgs != null && localArgs.title.isNotEmpty) {
      return ' ${localArgs.title}';
    }
    final title = videoState.title.isNotEmpty
        ? videoState.title
        : playerController.currentTitle;
    final buffer = StringBuffer(' $title');
    if (videoState.roadList.isNotEmpty &&
        videoState.currentRoad < videoState.roadList.length) {
      final road = videoState.roadList[videoState.currentRoad];
      final episodeIndex = videoState.currentEpisode - 1;
      if (episodeIndex >= 0 && episodeIndex < road.identifier.length) {
        buffer.write(' [${road.identifier[episodeIndex]}]');
      }
    }
    return buffer.toString();
  }

  Future<void> _handleDownload(VideoPageState videoState) async {
    final downloadUrl = playerController.videoUrl.isNotEmpty
        ? playerController.videoUrl
        : videoState.src;
    if (downloadUrl.isEmpty) {
      HaipeeDialog.showToast(message: '视频地址不可用');
      return;
    }

    if (playerController.activeLocalVideoArgs != null ||
        downloadUrl.startsWith('file://')) {
      HaipeeDialog.showToast(message: '当前播放为本地文件，无需下载');
      return;
    }

    try {
      final downloadController = ref.read(downloadControllerProvider.notifier);

      String title = _buildTitleText(videoState).trim();
      if (!title.contains('.')) {
        title = '$title.mp4';
      }

      String? bangumiId = playerController.activeLocalVideoArgs != null
          ? playerController.activeLocalVideoArgs!.bangumiId
          : (playerController.isBiliPlayback && playerController.activeBiliCid != null
              ? playerController.activeBiliCid.toString()
              : videoState.bangumiItem?.id.toString());
      int? episodeNumber = playerController.activeLocalVideoArgs != null
          ? playerController.activeLocalVideoArgs!.episode
          : videoState.currentEpisode;

      final Map<String, dynamic> headers =
          Map<String, dynamic>.from(playerController.activeHttpHeaders ?? {});
      if (playerController.isBiliPlayback) {
        headers['Referer'] = 'https://www.bilibili.com/';
        headers['User-Agent'] =
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      await downloadController.addDownload(
        downloadUrl,
        title: title,
        bangumiId: bangumiId,
        episodeNumber: episodeNumber,
        options: headers.isNotEmpty ? {'header': headers} : null,
      );

      HaipeeDialog.showToast(message: '已添加到下载列表');
    } catch (e) {
      HaipeeDialog.showToast(message: '添加下载任务失败: $e');
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
    HaipeeDialog.show(builder: (context) {
      String input = '';
      return AdaptiveDialogFrame(
        maxWidth: 400,
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
            onPressed: () => HaipeeDialog.dismiss(),
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
              HaipeeDialog.dismiss();
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
    final t = context.t;
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
        if (widget.changeEpisode != null &&
            playerController.activeLocalVideoArgs == null &&
            videoState.roadList.isNotEmpty)
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: () {
              if (videoState.loading) {
                return;
              }
              if (videoState.roadList.isEmpty ||
                  videoState.currentRoad >= videoState.roadList.length) {
                HaipeeDialog.showToast(
                  message: t.playback.toast.playlistEmpty,
                );
                return;
              }
              final road = videoState.roadList[videoState.currentRoad];
              if (videoState.currentEpisode >= road.data.length) {
                HaipeeDialog.showToast(
                  message: t.playback.toast.episodeLatest,
                );
                return;
              }
              final nextIdentifier =
                  videoState.currentEpisode < road.identifier.length
                      ? road.identifier[videoState.currentEpisode]
                      : '${videoState.currentEpisode + 1}';
              HaipeeDialog.showToast(
                message: t.playback.toast.loadingEpisode
                    .replaceFirst('{identifier}', nextIdentifier),
              );
              widget.changeEpisode!(
                videoState.currentEpisode + 1,
                currentRoad: videoState.currentRoad,
              );
            },
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
      requireOffset: !videoState.isFullscreen,
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
              key: const Key('smallest_panel_pip_button'),
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
          if (!videoState.isPip && MediaQuery.sizeOf(context).width >= 420)
            IconButton(
              key: const Key('smallest_download_btn'),
              color: Colors.white,
              icon: const Icon(Icons.download_rounded),
              tooltip: '下载',
              onPressed: () async {
                await _handleDownload(videoState);
              },
            ),
          MenuAnchor(
            consumeOutsideTap: true,
            style: MenuStyle(
              maximumSize: WidgetStatePropertyAll(
                Size(
                  260,
                  (MediaQuery.sizeOf(context).height - 56)
                      .clamp(140.0, 560.0),
                ),
              ),
            ),
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
                key: const Key('smallest_panel_more_menu_button'),
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
                    final isVip = isLogin && user.isVip;
                    final activeQuality = playerState.biliQuality > 0
                        ? playerState.biliQuality
                        : (isLogin ? (isVip ? 112 : 80) : 32);
                    final qualities = playerState.biliAvailableQualities.isNotEmpty
                        ? playerState.biliAvailableQualities
                        : BiliQualityHelper.buildQualityList(
                            unlockedIds: isLogin
                                ? (isVip
                                    ? const [112, 80, 64, 32, 16]
                                    : const [80, 64, 32, 16])
                                : const [32, 16],
                          );
                    return SubmenuButton(
                      menuChildren: [
                        for (final q in qualities)
                          MenuItemButton(
                            onPressed: () {
                              if (!isLogin && q.requiresLogin) {
                                HaipeeDialog.showToast(
                                  message: '登录 B站 账号后即可切换 ${q.label}',
                                );
                                widget.cancelHideTimer();
                                playerController.setCanHidePlayerPanel(false);
                                BiliLoginDialog.show(context).then((_) {
                                  if (mounted) {
                                    widget.cancelHideTimer();
                                    widget.startHideTimer();
                                    playerController.setCanHidePlayerPanel(true);
                                    if (BiliAuthService().isLoggedIn) {
                                      _refreshBiliStreamWithNewAuth(
                                        targetQuality: q.id,
                                      );
                                    }
                                  }
                                });
                                return;
                              }
                              if (q.requiresVip && !isVip) {
                                HaipeeDialog.showToast(
                                  message: '${q.label} 为 B站 大会员专属画质',
                                );
                                return;
                              }
                              if (q.id != activeQuality) {
                                playerController.switchBiliQuality(
                                  targetQuality: q.id,
                                );
                              }
                            },
                            child: _buildMenuItem(
                              title: q.requiresVip
                                  ? '${q.label} (大会员)'
                                  : (!isLogin && q.requiresLogin
                                      ? '${q.label} (登录享)'
                                      : q.label),
                              highlighted: q.id == activeQuality,
                            ),
                          ),
                      ],
                      child: _buildMenuItem(
                        title:
                            '清晰度 (${BiliQualityHelper.getShortLabel(activeQuality)})',
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
                key: const Key('smallest_menu_danmaku_settings'),
                onPressed: () {
                  final screenSize = MediaQuery.sizeOf(context);
                  final sheetMaxWidth =
                      (Utils.isDesktop() || Utils.isTablet()) &&
                              screenSize.width >= 640
                          ? (screenSize.width * 9 / 16)
                              .clamp(420.0, screenSize.width)
                          : screenSize.width;
                  showModalBottomSheet(
                    isScrollControlled: true,
                    constraints: BoxConstraints(
                      maxHeight: (screenSize.height * 0.82)
                          .clamp(180.0, screenSize.height),
                      maxWidth: sheetMaxWidth,
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
                key: const Key('smallest_menu_video_info'),
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
                    videoPageController.currentPluginOrNull?.referer ?? '',
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
              MenuItemButton(
                key: const Key('smallest_menu_tracks'),
                onPressed: () {
                  TracksSettingsSheet.show(context);
                },
                child: _buildMenuItem(title: '音频与字幕'),
              ),
              if (widget.openMenu != null &&
                  playerController.activeLocalVideoArgs == null &&
                  videoState.roadList.isNotEmpty)
                MenuItemButton(
                  key: const Key('smallest_menu_episodes'),
                  onPressed: () {
                    videoPageController.showTabBody =
                        !videoState.showTabBody;
                    widget.openMenu!();
                  },
                  child: _buildMenuItem(title: '选集与剧集列表'),
                ),
              MenuItemButton(
                key: const Key('smallest_menu_download'),
                onPressed: () async {
                  await _handleDownload(videoState);
                },
                child: _buildMenuItem(title: '下载视频'),
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
    final isUltraShort = MediaQuery.sizeOf(context).height < 360;
    return Container(
      height: isUltraShort ? 36 : 48,
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
