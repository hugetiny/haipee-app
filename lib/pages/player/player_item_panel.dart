import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/services/player/screenshot_candidate.dart';
import 'package:kazumi/pages/player/player_state.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/video_state.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:saver_gallery/saver_gallery.dart';

class PlayerItemPanel extends ConsumerStatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.changeEpisode,
    required this.handleFullscreen,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.handleSuperResolutionChange,
    required this.animationController,
    required this.openMenu,
    required this.keyboardFocus,
    required this.sendDanmaku,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.handleDanmaku,
    required this.showVideoInfo,
    required this.showSyncPlayRoomCreateDialog,
    required this.showSyncPlayEndPointSwitchDialog,
    this.disableAnimations = false,
  });
  final bool disableAnimations;
  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final Future<void> Function(int, {int currentRoad, int offset}) changeEpisode;
  final void Function() openMenu;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final Future<void> Function(int shaderIndex) handleSuperResolutionChange;
  final AnimationController animationController;
  final FocusNode keyboardFocus;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() handleDanmaku;
  final void Function(String) sendDanmaku;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayRoomCreateDialog;
  final void Function() showSyncPlayEndPointSwitchDialog;

  @override
  ConsumerState<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends ConsumerState<PlayerItemPanel> {
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late Animation<Offset> leftOffsetAnimation;
  late final VideoPageController videoPageController;
  late final PlayerController playerController;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  @override
  void dispose() {
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> _handleScreenshot() async {
    final t = context.t;
    final videoState = ref.read(videoProvider);
    KazumiDialog.showToast(message: t.playback.toast.screenshotProcessing);
    try {
      Uint8List? screenshot =
          await playerController.screenshot(format: 'image/png');
      if (screenshot == null) {
        throw Exception('截图数据为空');
      }

      final bangumiTitle = (videoState.bangumiItem?.nameCn.isNotEmpty == true)
          ? videoState.bangumiItem!.nameCn
          : (videoState.bangumiItem?.name ?? videoState.title);
      final candidate = ScreenshotCandidate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bytes: screenshot,
        title: bangumiTitle,
        episode: videoState.title,
        position: playerController.playerPosition,
      );

      if (Utils.isDesktop()) {
        final exportService = ref.read(screenshotExportServiceProvider);
        final destination = await exportService.chooseDestination();
        if (destination != null) {
          await exportService.write(candidate, destination);
          KazumiDialog.showToast(message: t.playback.toast.screenshotSaved);
          return;
        } else {
          return;
        }
      }

      final result = await SaverGallery.saveImage(
        screenshot,
        fileName: 'Kazumi_${candidate.title}_${candidate.id}',
        skipIfExists: false,
      );
      if (result.isSuccess) {
        KazumiDialog.showToast(message: t.playback.toast.screenshotSaved);
      } else {
        KazumiDialog.showToast(
          message: t.playback.toast.screenshotSaveFailed.replaceFirst(
            '{error}',
            result.errorMessage ?? '',
          ),
        );
      }
    } catch (e) {
      KazumiDialog.showToast(
        message: t.playback.toast.screenshotError.replaceFirst(
          '{error}',
          '$e',
        ),
      );
    }
  }

  Future<void> _handleDownload(VideoPageState videoState) async {
    if (videoState.src.isEmpty) {
      KazumiDialog.showToast(message: '视频地址不可用');
      return;
    }

    try {
      final downloadController = ref.read(downloadControllerProvider.notifier);

      // Build download title with episode info
      final title = _buildTitleText(videoState);

      // Get bangumi ID and episode number if available
      String? bangumiId = videoState.bangumiItem?.id.toString();
      int? episodeNumber = videoState.currentEpisode;

      await downloadController.addDownload(
        videoState.src,
        title: title.trim(),
        bangumiId: bangumiId,
        episodeNumber: episodeNumber,
      );

      KazumiDialog.showToast(message: '已添加到下载列表');
    } catch (e) {
      KazumiDialog.showToast(message: '添加下载失败：$e');
    }
  }

  String _buildTitleText(VideoPageState videoState) {
    final buffer = StringBuffer(' ${videoState.title}');
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

  Widget buildDanmakuTextField(PlayerState playerState) {
    final t = context.t;
    return Container(
      constraints: Utils.isDesktop()
          ? const BoxConstraints(maxWidth: 500, maxHeight: 33)
          : const BoxConstraints(maxHeight: 33),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        focusNode: textFieldFocus,
        style: TextStyle(
            fontSize: Utils.isDesktop() ? 15 : 13, color: Colors.white),
        controller: textController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          enabled: playerState.danmakuOn,
          filled: true,
          fillColor: Colors.white38,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: playerState.danmakuOn
              ? t.playback.danmaku.inputHint
              : t.playback.danmaku.inputDisabled,
          hintStyle: TextStyle(
              fontSize: Utils.isDesktop() ? 15 : 13, color: Colors.white60),
          alignLabelWithHint: true,
          contentPadding: EdgeInsets.symmetric(
              vertical: 8, horizontal: Utils.isDesktop() ? 8 : 12),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius:
                BorderRadius.all(Radius.circular(Utils.isDesktop() ? 8 : 20)),
          ),
          suffixIcon: TextButton(
            onPressed: () {
              textFieldFocus.unfocus();
              widget.sendDanmaku(textController.text);
              textController.clear();
            },
            style: TextButton.styleFrom(
              foregroundColor: playerState.danmakuOn
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.white60,
              backgroundColor: playerState.danmakuOn
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).disabledColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Utils.isDesktop() ? 8 : 20),
              ),
            ),
            child: Text(t.playback.danmaku.send),
          ),
        ),
        onTapAlwaysCalled: true,
        onTap: () {
          widget.cancelHideTimer();
          playerController.canHidePlayerPanel = false;
        },
        onSubmitted: (msg) {
          textFieldFocus.unfocus();
          widget.sendDanmaku(msg);
          widget.cancelHideTimer();
          widget.startHideTimer();
          playerController.canHidePlayerPanel = true;
          textController.clear();
        },
        onTapOutside: (_) {
          widget.cancelHideTimer();
          widget.startHideTimer();

          playerController.canHidePlayerPanel = true;
          textFieldFocus.unfocus();
          widget.keyboardFocus.requestFocus();
        },
      ),
    );
  }

  // 选择倍速
  void showSetSpeedSheet() {
    final t = context.t;
    final double currentSpeed = playerController.playerSpeed;
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: Text(t.playback.controls.speed.title),
        content: Wrap(
          spacing: 8,
          runSpacing: Utils.isDesktop() ? 8 : 0,
          children: [
            for (final double i in defaultPlaySpeedList) ...<Widget>[
              if (i == currentSpeed)
                FilledButton(
                  onPressed: () async {
                    await widget.setPlaybackSpeed(i);
                    KazumiDialog.dismiss();
                  },
                  child: Text(i.toString()),
                )
              else
                FilledButton.tonal(
                  onPressed: () async {
                    await widget.setPlaybackSpeed(i);
                    KazumiDialog.dismiss();
                  },
                  child: Text(i.toString()),
                ),
            ]
          ],
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
              await widget.setPlaybackSpeed(1.0);
              KazumiDialog.dismiss();
            },
            child: Text(t.playback.controls.speed.reset),
          ),
        ],
      );
    });
  }

  void showForwardChange() {
    final t = context.t;
    KazumiDialog.show(builder: (context) {
      String input = "";
      return AlertDialog(
        title: Text(t.playback.controls.skip.title),
        content: TextField(
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
          ],
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never, // 控制label的显示方式
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
              if (input != "") {
                playerController.setForwardTime(int.parse(input));
                KazumiDialog.dismiss();
              } else {
                KazumiDialog.dismiss();
              }
            },
            child: Text(t.app.confirm),
          ),
        ],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    playerController = ref.read(playerProvider.notifier);
    videoPageController = ref.read(videoProvider.notifier);
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
  }

  Widget forwardIcon() {
    final t = context.t;
    return Tooltip(
      message: t.playback.controls.skip.tooltip,
      child: GestureDetector(
        onLongPress: () => showForwardChange(),
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: () {
            playerController.seek(playerController.currentPosition +
                Duration(seconds: playerController.forwardTime));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final videoState = ref.watch(videoProvider);
    final t = context.t;
    return Stack(
      alignment: Alignment.center,
      children: [
        //顶部渐变区域
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: !playerState.lockPanel &&
                (widget.disableAnimations
                    ? playerState.showVideoController
                    : true),
            child: widget.disableAnimations
                ? Container(
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
                  )
                : SlideTransition(
                    position: topOffsetAnimation,
                    child: Container(
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
                    ),
                  ),
          ),
        ),

        //底部渐变区域
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          bottom: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: !playerState.lockPanel &&
                (widget.disableAnimations
                    ? playerState.showVideoController
                    : true),
            child: widget.disableAnimations
                ? Container(
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
                  )
                : SlideTransition(
                    position: bottomOffsetAnimation,
                    child: Container(
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
                    ),
                  ),
          ),
        ),
        // 顶部进度条
        Positioned(
            top: 25,
            child: playerState.showSeekTime
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0), // 圆角
                        ),
                        child: Text(
                          _buildSeekStatusText(playerState),
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Container()),
        // 顶部播放速度条
        Positioned(
            top: 25,
            child: playerState.showPlaySpeed
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0), // 圆角
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.fast_forward, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              t.playback.controls.status.speed,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Container()),
        // 亮度条
        Positioned(
            top: 25,
            child: playerState.showBrightness
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.brightness_7,
                                  color: Colors.white),
                              Text(
                                ' ${(playerState.brightness * 100).toInt()} %',
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )),
                    ],
                  )
                : Container()),
        // 音量条
        Positioned(
            top: 25,
            child: playerState.showVolume
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.volume_down,
                                  color: Colors.white),
                              Text(
                                ' ${playerState.volume.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )),
                    ],
                  )
                : Container()),
        // 右侧锁定按钮
        (Utils.isDesktop() || !videoState.isFullscreen)
            ? Container()
            : Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Visibility(
                  visible: widget.disableAnimations
                      ? playerState.showVideoController
                      : true,
                  child: widget.disableAnimations
                      ? buildLeftControlWidget(playerState, videoState)
                      : SlideTransition(
                          position: leftOffsetAnimation,
                          child:
                              buildLeftControlWidget(playerState, videoState)),
                ),
              ),
        // 自定义顶部组件
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: !playerState.lockPanel &&
                (widget.disableAnimations
                    ? playerState.showVideoController
                    : true),
            child: widget.disableAnimations
                ? buildTopControlWidget(playerState, videoState)
                : SlideTransition(
                    position: topOffsetAnimation,
                    child: buildTopControlWidget(playerState, videoState)),
          ),
        ),
        // 自定义播放器底部组件
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: !playerState.lockPanel &&
                (widget.disableAnimations
                    ? playerState.showVideoController
                    : true),
            child: widget.disableAnimations
                ? buildBottomControlWidget(playerState, videoState)
                : SlideTransition(
                    position: bottomOffsetAnimation,
                    child: buildBottomControlWidget(playerState, videoState)),
          ),
        ),
      ],
    );
  }

  Widget buildBottomControlWidget(
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
    final superResolutionOptions = <String>[
      t.playback.controls.superResolution.off,
      t.playback.controls.superResolution.balanced,
      t.playback.controls.superResolution.quality,
    ];
    final aspectRatioLabels = <int, String>{
      1: t.playback.controls.aspectRatio.options.auto,
      2: t.playback.controls.aspectRatio.options.crop,
      3: t.playback.controls.aspectRatio.options.stretch,
    };
    return SafeArea(
      top: false,
      bottom: videoState.isFullscreen,
      left: videoState.isFullscreen,
      right: videoState.isFullscreen,
      child: MouseRegion(
        cursor: (videoState.isFullscreen && !playerState.showVideoController)
            ? SystemMouseCursors.none
            : SystemMouseCursors.basic,
        onEnter: (_) {
          widget.cancelHideTimer();
        },
        onExit: (_) {
          widget.cancelHideTimer();
          widget.startHideTimer();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!Utils.isDesktop() && !Utils.isTablet())
              Container(
                padding: const EdgeInsets.only(left: 10.0, bottom: 10),
                child: Text(
                  "${Utils.durationToString(playerState.currentPosition)} / ${Utils.durationToString(playerState.duration)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontFeatures: [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ProgressBar(
                thumbRadius: 8,
                thumbGlowRadius: 18,
                timeLabelLocation: Utils.isTablet()
                    ? TimeLabelLocation.sides
                    : TimeLabelLocation.none,
                timeLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontFeatures: [
                    FontFeature.tabularFigures(),
                  ],
                ),
                progress: playerState.currentPosition,
                buffered: playerState.buffer,
                total: playerState.duration,
                onSeek: (duration) {
                  playerController.seek(duration);
                },
                onDragStart: widget.handleProgressBarDragStart,
                onDragUpdate: (details) =>
                    playerController.currentPosition = details.timeStamp,
                onDragEnd: widget.handleProgressBarDragEnd,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: Icon(playerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    onPressed: () {
                      playerController.playOrPause();
                    },
                  ),
                  if (videoState.isFullscreen ||
                      Utils.isTablet() ||
                      Utils.isDesktop())
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () {
                        if (videoState.loading) {
                          return;
                        }
                        if (videoState.roadList.isEmpty ||
                            videoState.currentRoad >=
                                videoState.roadList.length) {
                          KazumiDialog.showToast(
                            message: t.playback.toast.playlistEmpty,
                          );
                          return;
                        }
                        final road =
                            videoState.roadList[videoState.currentRoad];
                        if (videoState.currentEpisode >= road.data.length) {
                          KazumiDialog.showToast(
                            message: t.playback.toast.episodeLatest,
                          );
                          return;
                        }
                        final nextIdentifier =
                            videoState.currentEpisode < road.identifier.length
                                ? road.identifier[videoState.currentEpisode]
                                : '${videoState.currentEpisode + 1}';
                        KazumiDialog.showToast(
                          message: t.playback.toast.loadingEpisode
                              .replaceFirst('{identifier}', nextIdentifier),
                        );
                        widget.changeEpisode(
                          videoState.currentEpisode + 1,
                          currentRoad: videoState.currentRoad,
                        );
                      },
                    ),
                  if (Utils.isDesktop())
                    Container(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "${Utils.durationToString(playerState.currentPosition)} / ${Utils.durationToString(playerState.duration)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  if (Utils.isDesktop())
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSpaceEnough = constraints.maxWidth > 600;
                          return Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                                IconButton(
                                  onPressed: () {
                                    widget.keyboardFocus.requestFocus();
                                    showModalBottomSheet(
                                      isScrollControlled: true,
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                3 /
                                                4,
                                        maxWidth: (Utils.isDesktop() ||
                                                Utils.isTablet())
                                            ? MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                9 /
                                                16
                                            : MediaQuery.of(context).size.width,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      context: context,
                                      builder: (context) {
                                        return DanmakuSettingsSheet(
                                          danmakuController: playerController
                                              .danmakuController,
                                        );
                                      },
                                    );
                                  },
                                  color: Colors.white,
                                  icon: SvgPicture.asset(
                                    'assets/images/danmaku_setting.svg',
                                    height: 24,
                                  ),
                                ),
                                if (isSpaceEnough)
                                  buildDanmakuTextField(playerState),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (!Utils.isDesktop()) ...[
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
                    if (playerState.danmakuOn) ...[
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            isScrollControlled: true,
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 3 / 4,
                              maxWidth: (Utils.isDesktop() || Utils.isTablet())
                                  ? MediaQuery.of(context).size.width * 9 / 16
                                  : MediaQuery.of(context).size.width,
                            ),
                            clipBehavior: Clip.antiAlias,
                            context: context,
                            builder: (context) {
                              return DanmakuSettingsSheet(
                                danmakuController:
                                    playerController.danmakuController,
                              );
                            },
                          );
                        },
                        color: Colors.white,
                        icon: SvgPicture.asset(
                          'assets/images/danmaku_setting.svg',
                          height: 24,
                        ),
                      ),
                      Expanded(
                        child: buildDanmakuTextField(playerState),
                      ),
                    ],
                    if (!playerState.danmakuOn) const Spacer(),
                  ],
                  MenuAnchor(
                    consumeOutsideTap: true,
                    onOpen: () {
                      widget.cancelHideTimer();
                      playerController.canHidePlayerPanel = false;
                    },
                    onClose: () {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                      playerController.canHidePlayerPanel = true;
                    },
                    builder: (BuildContext context, MenuController controller,
                        Widget? child) {
                      return TextButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        child: Text(
                          t.playback.controls.superResolution.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                    menuChildren: List<MenuItemButton>.generate(
                      3,
                      (int index) => MenuItemButton(
                        onPressed: () =>
                            widget.handleSuperResolutionChange(index + 1),
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              superResolutionOptions[index],
                              style: TextStyle(
                                color:
                                    playerState.superResolutionType == index + 1
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  MenuAnchor(
                    consumeOutsideTap: true,
                    onOpen: () {
                      widget.cancelHideTimer();
                      playerController.canHidePlayerPanel = false;
                    },
                    onClose: () {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                      playerController.canHidePlayerPanel = true;
                    },
                    builder: (BuildContext context, MenuController controller,
                        Widget? child) {
                      return TextButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        child: Text(
                          playerState.playerSpeed == 1.0
                              ? t.playback.controls.speedMenu.label
                              : '${playerState.playerSpeed}x',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                    menuChildren: [
                      for (final double i in defaultPlaySpeedList)
                        MenuItemButton(
                          onPressed: () async {
                            await widget.setPlaybackSpeed(i);
                          },
                          child: SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${i}x',
                                style: TextStyle(
                                  color: i == playerState.playerSpeed
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  MenuAnchor(
                    consumeOutsideTap: true,
                    onOpen: () {
                      widget.cancelHideTimer();
                      playerController.canHidePlayerPanel = false;
                    },
                    onClose: () {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                      playerController.canHidePlayerPanel = true;
                    },
                    builder: (BuildContext context, MenuController controller,
                        Widget? child) {
                      return IconButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(
                          Icons.aspect_ratio_rounded,
                          color: Colors.white,
                        ),
                        tooltip: t.playback.controls.aspectRatio.label,
                      );
                    },
                    menuChildren: [
                      for (final entry in aspectRatioTypeMap.entries)
                        MenuItemButton(
                          onPressed: () =>
                              playerController.aspectRatioType = entry.key,
                          child: SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                aspectRatioLabels[entry.key] ?? entry.value,
                                style: TextStyle(
                                  color: entry.key ==
                                          playerState.aspectRatioType
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  (!videoState.isFullscreen &&
                          !Utils.isTablet() &&
                          !Utils.isDesktop())
                      ? const SizedBox.shrink()
                      : IconButton(
                          color: Colors.white,
                          icon: const Icon(Icons.menu_open_rounded),
                          onPressed: () {
                            videoPageController.showTabBody =
                                !videoState.showTabBody;
                            widget.openMenu();
                          },
                        ),
                  (Utils.isTablet() &&
                          videoState.isFullscreen &&
                          MediaQuery.of(context).size.height <
                              MediaQuery.of(context).size.width)
                      ? const SizedBox.shrink()
                      : IconButton(
                          color: Colors.white,
                          icon: Icon(videoState.isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded),
                          onPressed: widget.handleFullscreen,
                        ),
                ],
              ),
            ),
            if (Utils.isTablet() || Utils.isDesktop())
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget buildTopControlWidget(
    PlayerState playerState,
    VideoPageState videoState,
  ) {
    return EmbeddedNativeControlArea(
      requireOffset: !videoState.isFullscreen,
      child: SafeArea(
        top: false,
        bottom: false,
        left: videoState.isFullscreen,
        right: videoState.isFullscreen,
        child: MouseRegion(
          cursor: (videoState.isFullscreen && !playerState.showVideoController)
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          onEnter: (_) {
            widget.cancelHideTimer();
          },
          onExit: (_) {
            widget.cancelHideTimer();
            widget.startHideTimer();
          },
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  widget.onBackPressed(context);
                },
              ),
              Expanded(
                child: dtb.DragToMoveArea(
                  child: Text(
                    _buildTitleText(videoState),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          Theme.of(context).textTheme.titleMedium!.fontSize,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              forwardIcon(),
              if (Utils.isDesktop() && !videoState.isFullscreen)
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
              if (videoState.bangumiItem != null)
                CollectButton(
                  bangumiItem: videoState.bangumiItem!,
                  onOpen: () {
                    widget.cancelHideTimer();
                    playerController.canHidePlayerPanel = false;
                  },
                  onClose: () {
                    widget.cancelHideTimer();
                    widget.startHideTimer();
                    playerController.canHidePlayerPanel = true;
                  },
                ),
              // Conditionally show download button if aria2 is available
              if (Aria2FeatureManager().isAvailable)
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.download_rounded),
                  tooltip: '下载',
                  onPressed: () async {
                    await _handleDownload(videoState);
                  },
                ),
              MenuAnchor(
                consumeOutsideTap: true,
                onOpen: () {
                  widget.cancelHideTimer();
                  playerController.canHidePlayerPanel = false;
                },
                onClose: () {
                  widget.cancelHideTimer();
                  widget.startHideTimer();
                  playerController.canHidePlayerPanel = true;
                },
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
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
                  MenuItemButton(
                    onPressed: widget.showDanmakuSwitch,
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.playback.controls.menu.danmakuToggle),
                      ),
                    ),
                  ),
                  // Conditionally show download menu option if aria2 is available
                  if (Aria2FeatureManager().isAvailable)
                    MenuItemButton(
                      onPressed: () async {
                        await _handleDownload(videoState);
                      },
                      child: const SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('下载视频'),
                        ),
                      ),
                    ),
                  MenuItemButton(
                    onPressed: widget.showVideoInfo,
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.playback.controls.menu.videoInfo),
                      ),
                    ),
                  ),
                  MenuItemButton(
                    onPressed: () {
                      final needRestart = playerState.playing;
                      playerController.pause();
                      final plugin = videoState.currentPlugin;
                      final referer = plugin?.referer ?? '';
                      RemotePlay()
                          .castVideo(playerController.videoUrl, referer)
                          .whenComplete(() {
                        if (needRestart) {
                          playerController.play();
                        }
                      });
                    },
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.playback.controls.menu.cast),
                      ),
                    ),
                  ),
                  MenuItemButton(
                    onPressed: playerController.lanunchExternalPlayer,
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.playback.controls.menu.external),
                      ),
                    ),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.playback.controls.syncplay.room.replaceFirst(
                                '{name}',
                                playerState.syncplayRoom.isEmpty
                                    ? t.playback.controls.syncplay.roomEmpty
                                    : playerState.syncplayRoom,
                              ),
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.playback.controls.syncplay.latency.replaceFirst(
                                '{ms}',
                                playerState.syncplayClientRtt.toString(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        onPressed: widget.showSyncPlayRoomCreateDialog,
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t.playback.controls.syncplay.join),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        onPressed: widget.showSyncPlayEndPointSwitchDialog,
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.playback.controls.syncplay.switchServer,
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        onPressed: () async {
                          await playerController.exitSyncPlayRoom();
                        },
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.playback.controls.syncplay.disconnect,
                            ),
                          ),
                        ),
                      ),
                    ],
                    child: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.playback.controls.syncplay.label),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLeftControlWidget(
    PlayerState playerState,
    VideoPageState videoState,
  ) {
    return SafeArea(
      top: false,
      bottom: false,
      left: videoState.isFullscreen,
      right: videoState.isFullscreen,
      child: Column(
        children: [
          const Spacer(),
          playerState.lockPanel
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _handleScreenshot,
                ),
          IconButton(
            icon: Icon(
              playerState.lockPanel ? Icons.lock_outline : Icons.lock_open,
              color: Colors.white,
            ),
            onPressed: () {
              playerController.lockPanel = !playerState.lockPanel;
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
