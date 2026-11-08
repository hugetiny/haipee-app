import 'dart:async';
import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:haipee/pages/player/player_item_panel.dart';
import 'package:haipee/pages/player/smallest_player_item_panel.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/utils/webdav.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/services/player/audio_controller.dart';
import 'package:haipee/pages/player/player_state.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:haipee/pages/history/history_controller.dart';
import 'package:haipee/pages/history/providers.dart';
import 'package:haipee/pages/my/my_controller.dart';
import 'package:haipee/pages/my/providers.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/request/damaku.dart';
import 'package:haipee/modules/danmaku/danmaku_search_response.dart';
import 'package:haipee/modules/danmaku/danmaku_episode_response.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/pages/player/player_item_surface.dart';
import 'package:haipee/pages/setting/setting_controller.dart';
import 'package:haipee/pages/settings/danmaku/providers.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

/// Provider for super resolution warning dialog "don't ask again" checkbox state
final _superResolutionDontAskAgainProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// Provider for syncplay server selection dialog state
final _syncPlaySelectedServerProvider =
    StateProvider.autoDispose<String>((ref) => '');
final _syncPlayCustomServerProvider =
    StateProvider.autoDispose<String>((ref) => '');

class PlayerItem extends ConsumerStatefulWidget {
  const PlayerItem({
    super.key,
    required this.openMenu,
    required this.locateEpisode,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.sendDanmaku,
    this.disableAnimations = false,
  });

  final VoidCallback openMenu;
  final VoidCallback locateEpisode;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final void Function(String) sendDanmaku;
  final FocusNode keyboardFocus;
  final bool disableAnimations;

  @override
  ConsumerState<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends ConsumerState<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  late final PlayerController playerController;
  late final VideoPageController videoPageController;
  late final HistoryController historyController;
  late final CollectController collectController;
  late final MyController myController;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  late bool webDavEnable;
  late bool webDavEnableHistory;

  // 弹幕
  final _danmuKey = GlobalKey();
  late bool _border;
  late double _opacity;
  late double _duration;
  late double _fontSize;
  late double danmakuArea;
  late bool _hideTop;
  late bool _hideBottom;
  late bool _hideScroll;
  late bool _massiveMode;
  late int _danmakuFontWeight;

  // 硬件解码
  late bool haEnable;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? hideVolumeUITimer;

  // 过渡动画控制器
  AnimationController? animationController;

  double lastPlayerSpeed = 1.0;
  int episodeNum = 0;
  int? _lastEmittedSecond;

  ProviderSubscription<bool>? _fullscreenSubscription;

  /// 处理 Android/iOS 应用后台或熄屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (playerController.playerPlaying) {
        playerController.danmakuController.resume();
      }
    } catch (_) {}
  }

  void _handleTap() {
    if (Utils.isDesktop()) {
      playerController.playOrPause();
    } else {
      if (playerController.showVideoController) {
        hideVideoController();
      } else {
        displayVideoController();
      }
    }
  }

  void _handleDoubleTap() {
    if (Utils.isDesktop() && !videoPageController.isPip) {
      handleFullscreen();
    } else {
      playerController.playOrPause();
    }
  }

  void _handleHove() {
    if (!playerController.showVideoController) {
      displayVideoController();
    }
    hideTimer?.cancel();
    startHideTimer();
  }

  void _handleMouseScroller() {
    playerController.showVolume = true;
    mouseScrollerTimer?.cancel();
    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      mouseScrollerTimer = null;
    });
  }

  void _handleKeyChangingVolume() {
    playerController.showVolume = true;
    hideVolumeUITimer?.cancel();
    hideVolumeUITimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      hideVolumeUITimer = null;
    });
  }

  void handleDanmaku() {
    _lastEmittedSecond = null;
    playerController.danmakuController.clear();
    // 弹幕开关纯粹切换：有即显示，无即不显示，严禁弹窗强行模糊搜寻
    playerController.danmakuOn = !playerController.danmakuOn;
  }

  Future<void> _uploadHistoryToWebDav() async {
    if (webDavEnable && webDavEnableHistory) {
      try {
        var webDav = WebDav();
        await webDav.updateHistory();
      } catch (_) {}
    }
  }

  void _handleFullscreenChange(BuildContext context) async {
    _lastEmittedSecond = null;
    playerController.lockPanel = false;
    playerController.danmakuController.clear();

    await _uploadHistoryToWebDav();
  }

  void handleProgressBarDragStart(ThumbDragDetails details) {
    playerTimer?.cancel();
    playerController.pause(enableSync: false);
    hideTimer?.cancel();
    playerController.showVideoController = true;
  }

  void handleProgressBarDragEnd() {
    playerController.play(enableSync: false);
    startHideTimer();
    playerTimer?.cancel();
    playerTimer = getPlayerTimer();
  }

  // 启用超分辨率（质量档）时弹出提示
  Future<void> handleSuperResolutionChange(int shaderIndex) async {
    if (!mounted) return;

    final bool isHighMode = shaderIndex == 3;
    final bool alreadyShown =
        setting.get(SettingBoxKey.superResolutionWarn, defaultValue: false);
    final t = context.t;

    if (isHighMode && !alreadyShown) {
      bool confirmed = false;

      await HaipeeDialog.show(builder: (context) {
        return Consumer(builder: (context, ref, child) {
          final dontAskAgain = ref.watch(_superResolutionDontAskAgainProvider);

          return AlertDialog(
            title: Text(t.playback.superResolution.warning.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.playback.superResolution.warning.message),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: dontAskAgain,
                      onChanged: (value) {
                        ref
                            .read(_superResolutionDontAskAgainProvider.notifier)
                            .state = value ?? false;
                      },
                    ),
                    Text(t.playback.superResolution.warning.dontAskAgain),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (dontAskAgain) {
                    await setting.put(SettingBoxKey.superResolutionWarn, true);
                  }
                  HaipeeDialog.dismiss();
                },
                child: Text(t.app.cancel),
              ),
              TextButton(
                onPressed: () async {
                  confirmed = true;
                  if (dontAskAgain) {
                    await setting.put(SettingBoxKey.superResolutionWarn, true);
                  }
                  HaipeeDialog.dismiss();
                },
                child: Text(t.app.confirm),
              ),
            ],
          );
        });
      });

      if (confirmed) {
        playerController.setShader(shaderIndex);
      }
    } else {
      playerController.setShader(shaderIndex);
    }
  }

  void handleFullscreen() {
    _handleFullscreenChange(context);
    if (videoPageController.isFullscreen) {
      Utils.exitFullScreen();
      if (!Utils.isDesktop()) {
        widget.locateEpisode();
        videoPageController.showTabBody = true;
      }
    } else {
      Utils.enterFullScreen();
      videoPageController.showTabBody = false;
    }
    videoPageController.isFullscreen = !videoPageController.isFullscreen;
  }

  void displayVideoController() {
    animationController?.forward();
    hideTimer?.cancel();
    startHideTimer();
    playerController.showVideoController = true;
  }

  void hideVideoController() {
    animationController?.reverse();
    hideTimer?.cancel();
    playerController.showVideoController = false;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await playerController.setPlaybackSpeed(speed);
    playerController.danmakuController.updateOption(
      playerController.danmakuController.option
          .copyWith(duration: (_duration / speed).toDouble()),
    );
  }

  Future<void> increaseVolume() async {
    await playerController.setVolume(playerController.volume + 10);
  }

  Future<void> decreaseVolume() async {
    await playerController.setVolume(playerController.volume - 10);
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightnessPlatform.instance
          .setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && playerController.canHidePlayerPanel) {
        playerController.showVideoController = false;
        animationController?.reverse();
      }
      hideTimer = null;
    });
  }

  // Used to pass hideTimer operation to panel layer
  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.playing = playerController.playerPlaying;
      playerController.isBuffering = playerController.playerBuffering;
      playerController.currentPosition = playerController.playerPosition;
      playerController.buffer = playerController.playerBuffer;
      playerController.duration = playerController.playerDuration;
      playerController.completed = playerController.playerCompleted;
      // 弹幕相关
      final currentSec = playerController.currentPosition.inSeconds;
      if (playerController.playerPlaying == true &&
          playerController.danmakuOn == true) {
        if (_lastEmittedSecond != currentSec) {
          _lastEmittedSecond = currentSec;
          final currentDanmakus = playerController.danDanmakus[currentSec];
          if (currentDanmakus != null && currentDanmakus.isNotEmpty) {
            final isBiliNative = playerController.activeBiliCid != null &&
                playerController.activeBiliCid! > 0;
            final danmakuSettings = ref.read(danmakuSettingsProvider);
            currentDanmakus.asMap().forEach((idx, danmaku) async {
              final effectiveColor =
                  danmakuSettings.danmakuColor ? danmaku.color : Colors.white;
              // 对于 B站 原生视频 (activeBiliCid > 0)，以官方 CID 原生弹幕为准，严禁被第三方 DanDanPlay 弹幕源开关屏蔽
              if (!isBiliNative) {
                if (!danmakuSettings.danmakuBiliBiliSource &&
                    danmaku.source.contains('BiliBili')) {
                  return;
                }
                if (!danmakuSettings.danmakuGamerSource &&
                    danmaku.source.contains('Gamer')) {
                  return;
                }
                if (!danmakuSettings.danmakuDanDanSource &&
                    !(danmaku.source.contains('BiliBili') ||
                        danmaku.source.contains('Gamer'))) {
                  return;
                }
              }
              await Future.delayed(
                  Duration(
                      milliseconds: idx * 1000 ~/ currentDanmakus.length),
                  () => mounted &&
                          playerController.playerPlaying &&
                          !playerController.playerBuffering &&
                          playerController.danmakuOn &&
                          !myController.isDanmakuBlocked(danmaku.message)
                      ? playerController.danmakuController.addDanmaku(
                          DanmakuContentItem(
                            danmaku.message,
                            color: effectiveColor,
                            type: danmaku.type == 4
                                ? DanmakuItemType.bottom
                                : (danmaku.type == 5
                                    ? DanmakuItemType.top
                                    : DanmakuItemType.scroll),
                          ),
                        )
                      : null);
            });
          }
        }
      }
      // 音量相关
      if (!playerController.volumeSeeking) {
        if (Utils.isDesktop()) {
          playerController.volume = playerController.playerVolume;
        } else {
          FlutterVolumeController.getVolume().then((value) {
            final volume = value ?? 0.0;
            playerController.volume = volume * 100;
          });
        }
      }
      // 亮度相关
      if (!Platform.isWindows &&
          !Platform.isMacOS &&
          !Platform.isLinux &&
          !playerController.brightnessSeeking) {
        ScreenBrightnessPlatform.instance.application.then((value) {
          playerController.brightness = value;
        });
      }
      // 历史记录相关
      if (playerController.playerPlaying && !videoPageController.loading) {
        if (!WebDav().isHistorySyncing) {
          final roadList = videoPageController.roadList;
          final currentRoad = videoPageController.currentRoad;
          final currentEpisode = videoPageController.currentEpisode;
          final pluginName = videoPageController.currentPluginOrNull?.name;
          if (pluginName != null &&
              pluginName.isNotEmpty &&
              roadList.isNotEmpty &&
              currentRoad >= 0 &&
              currentRoad < roadList.length &&
              currentEpisode > 0 &&
              currentEpisode - 1 < roadList[currentRoad].identifier.length) {
            historyController.updateHistory(
                currentEpisode,
                currentRoad,
                pluginName,
                videoPageController.bangumiItem,
                playerController.playerPosition,
                videoPageController.src,
                roadList[currentRoad].identifier[currentEpisode - 1]);
            unawaited(playerController.syncVideoQualityMetrics());
          }
        }
      }
      // 自动播放下一集
      if (playerController.completed &&
          videoPageController.roadList.isNotEmpty &&
          videoPageController.currentRoad >= 0 &&
          videoPageController.currentRoad <
              videoPageController.roadList.length &&
          videoPageController.currentEpisode > 0 &&
          videoPageController.currentEpisode <
              videoPageController
                  .roadList[videoPageController.currentRoad].data.length &&
          !videoPageController.loading) {
        final currentRoadData =
            videoPageController.roadList[videoPageController.currentRoad];
        final nextIdentifier = (videoPageController.currentEpisode <
                currentRoadData.identifier.length)
            ? currentRoadData.identifier[videoPageController.currentEpisode]
            : '${videoPageController.currentEpisode + 1}';
        HaipeeDialog.showToast(
          message: context.t.playback.toast.loadingEpisode.replaceFirst(
            '{identifier}',
            nextIdentifier,
          ),
        );
        try {
          playerTimer!.cancel();
        } catch (_) {}
        widget.changeEpisode(videoPageController.currentEpisode + 1,
            currentRoad: videoPageController.currentRoad);
      }
      // 一起去看相关
      playerController.setSyncPlayCurrentPosition();
      _syncAudioServiceState();
    });
  }

  AudioController? _cachedAudioController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedAudioController = ref.read(audioControllerProvider);
  }

  AudioController get _audioController =>
      _cachedAudioController ?? ref.read(audioControllerProvider);

  Future<void> _bindAudioService() async {
    try {
      final bangumi = videoPageController.bangumiItem;
      await _audioController.bindCallbacks(
        onPlay: () => playerController.play(),
        onPause: () => playerController.pause(),
        onSkipToNext: () async {
          final roadList = videoPageController.roadList;
          final currentRoad = videoPageController.currentRoad;
          if (roadList.isNotEmpty &&
              currentRoad >= 0 &&
              currentRoad < roadList.length &&
              videoPageController.currentEpisode > 0 &&
              videoPageController.currentEpisode <
                  roadList[currentRoad].data.length) {
            await widget.changeEpisode(videoPageController.currentEpisode + 1);
          }
        },
        onSkipToPrevious: () async {
          if (videoPageController.currentEpisode > 1) {
            await widget.changeEpisode(videoPageController.currentEpisode - 1);
          }
        },
        onSeek: (position) async {
          await playerController.mediaPlayer?.seek(position);
        },
        artworkUrl: bangumi.images['large'] ?? bangumi.images['common'],
      );
      _syncAudioServiceState();
    } catch (e) {
      HaipeeLogger().w('AudioController: failed to bind callbacks', error: e);
    }
  }

  void _syncAudioServiceState() {
    try {
      final currentRoad = videoPageController.currentRoad;
      final currentEpisode = videoPageController.currentEpisode;
      if (videoPageController.roadList.isEmpty ||
          currentRoad < 0 ||
          currentRoad >= videoPageController.roadList.length) {
        return;
      }
      final currentRoadData = videoPageController.roadList[currentRoad];
      if (currentEpisode <= 0 || currentRoadData.data.isEmpty) return;

      final duration = playerController.playerDuration;
      if (duration <= Duration.zero) return;

      final canSkipToPrevious = currentEpisode > 1;
      final canSkipToNext = currentEpisode < currentRoadData.data.length;
      final bangumi = videoPageController.bangumiItem;
      final bangumiTitle = bangumi.nameCn.isNotEmpty ? bangumi.nameCn : bangumi.name;

      unawaited(
        _audioController.updateSession(
          mediaId: '${bangumi.id}_${currentRoad}_$currentEpisode',
          title: bangumiTitle,
          album: videoPageController.currentPluginOrNull?.name ?? 'Haipee',
          artist: videoPageController.title,
          duration: duration,
          playing: playerController.playerPlaying,
          loading: videoPageController.loading,
          buffering: playerController.mediaPlayer?.state.buffering ?? false,
          completed: playerController.completed,
          updatePosition: playerController.playerPosition,
          bufferedPosition: playerController.playerBuffer,
          speed: playerController.playerSpeed,
          queueIndex: currentEpisode - 1,
          canSkipToNext: canSkipToNext,
          canSkipToPrevious: canSkipToPrevious,
        ),
      );
    } catch (e) {
      HaipeeLogger().w('AudioController: failed to sync state', error: e);
    }
  }

  void showDanmakuSearchDialog(String keyword) async {
    final t = context.t;
    HaipeeDialog.dismiss();
    HaipeeDialog.showLoading(msg: t.playback.loading.danmakuSearch);
    DanmakuSearchResponse danmakuSearchResponse;
    DanmakuEpisodeResponse danmakuEpisodeResponse;
    try {
      danmakuSearchResponse =
          await DanmakuRequest.getDanmakuSearchResponse(keyword);
    } catch (error) {
      HaipeeDialog.dismiss();
      HaipeeDialog.showToast(
        message: t.playback.toast.danmakuSearchError.replaceFirst(
          '{error}',
          error.toString(),
        ),
      );
      return;
    }
    HaipeeDialog.dismiss();
    if (danmakuSearchResponse.animes.isEmpty) {
      HaipeeDialog.showToast(
        message: t.playback.toast.danmakuSearchEmpty,
      );
      return;
    }
    await HaipeeDialog.show(builder: (dialogContext) {
      return Dialog(
        child: ListView(
          shrinkWrap: true,
          children: danmakuSearchResponse.animes.map((danmakuInfo) {
            return ListTile(
              title: Text(danmakuInfo.animeTitle),
              onTap: () async {
                HaipeeDialog.dismiss();
                HaipeeDialog.showLoading(msg: t.playback.loading.danmakuSearch);
                try {
                  danmakuEpisodeResponse =
                      await DanmakuRequest.getDanDanEpisodesByDanDanBangumiID(
                          danmakuInfo.animeId,
                          silent: false);
                } catch (error) {
                  HaipeeDialog.dismiss();
                  HaipeeDialog.showToast(
                    message: t.playback.toast.danmakuSearchError.replaceFirst(
                      '{error}',
                      error.toString(),
                    ),
                  );
                  return;
                }
                HaipeeDialog.dismiss();
                if (danmakuEpisodeResponse.episodes.isEmpty) {
                  HaipeeDialog.showToast(
                    message: t.playback.toast.danmakuSearchEmpty,
                  );
                  return;
                }
                HaipeeDialog.show(builder: (episodesContext) {
                  return Dialog(
                    child: ListView(
                      shrinkWrap: true,
                      children: danmakuEpisodeResponse.episodes.map((episode) {
                        return ListTile(
                          title: Text(episode.episodeTitle),
                          onTap: () {
                            HaipeeDialog.dismiss();
                            HaipeeDialog.showToast(
                              message: t.playback.toast.danmakuSwitching,
                            );
                            playerController
                                .getDanDanmakuByEpisodeID(episode.episodeId);
                          },
                        );
                      }).toList(),
                    ),
                  );
                });
              },
            );
          }).toList(),
        ),
      );
    });
  }

  // 弹幕查询
  void showDanmakuSwitch() {
    if (playerController.activeBiliCid != null &&
        playerController.activeBiliCid! > 0) {
      HaipeeDialog.showToast(message: '当前为哔哩哔哩原生视频，以官方 CID 弹幕为准，无需外部模糊匹配');
      return;
    }
    final t = context.t;
    HaipeeDialog.show(
      builder: (context) {
        final TextEditingController searchTextController =
            TextEditingController(text: videoPageController.title);
        return AlertDialog(
          title: Text(t.playback.danmakuSearch.title),
          content: TextField(
            controller: searchTextController,
            decoration: InputDecoration(
              hintText: t.playback.danmakuSearch.hint,
            ),
            onSubmitted: (keyword) {
              showDanmakuSearchDialog(keyword);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                HaipeeDialog.dismiss();
                widget.keyboardFocus.requestFocus();
              },
              child: Text(
                t.app.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                showDanmakuSearchDialog(searchTextController.text);
              },
              child: Text(t.playback.danmakuSearch.submit),
            ),
          ],
        );
      },
    );
  }

  String _formatBitrate(double bps) {
    if (bps <= 0) return '--';
    if (bps >= 1000 * 1000) {
      return '${(bps / (1000 * 1000)).toStringAsFixed(2)} Mbps';
    }
    return '${(bps / 1000).toStringAsFixed(0)} kbps';
  }

  String _buildStructuredStatsText(
      PlayerState state, PlayerController controller) {
    final resolution = (state.playerWidth > 0 && state.playerHeight > 0)
        ? '${state.playerWidth}x${state.playerHeight}'
        : '未知';
    final fps = state.videoFps > 0 ? '${state.videoFps.toStringAsFixed(2)} fps' : '--';
    final vBitrate = _formatBitrate(
      state.playerVideoBitrate > 0 ? state.playerVideoBitrate : state.demuxBitrate,
    );
    final superResLabel = switch (state.superResolutionType) {
      2 => 'Anime4K 均衡 (Lite)',
      3 => 'Anime4K 质量 (HQ)',
      _ => '关闭',
    };
    int totalDanmaku = 0;
    int biliCount = 0;
    int gamerCount = 0;
    int dandanCount = 0;
    for (final list in state.danDanmakus.values) {
      for (final item in list) {
        totalDanmaku++;
        if (item.source.contains('BiliBili')) {
          biliCount++;
        } else if (item.source.contains('Gamer')) {
          gamerCount++;
        } else {
          dandanCount++;
        }
      }
    }
    final isBili = controller.isBiliPlayback;
    final danmakuSummary = isBili
        ? '共 $totalDanmaku 条 (B站原生 CID: ${controller.activeBiliCid ?? "--"})'
        : '共 $totalDanmaku 条 (B站: $biliCount / 巴哈: $gamerCount / 弹弹: $dandanCount)';

    final buf = StringBuffer();
    buf.writeln('=== 视频统计与调试信息 (Stats for Nerds) ===');
    buf.writeln('标题: ${controller.currentTitle.isNotEmpty ? controller.currentTitle : videoPageController.title}');
    if (isBili) {
      buf.writeln('B站标识: BVID=${controller.activeBiliBvid ?? "--"} / CID=${controller.activeBiliCid ?? "--"} (${BiliQualityHelper.getLabel(state.biliQuality)})');
    }
    buf.writeln('播放地址: ${controller.videoUrl}');
    buf.writeln('分辨率: $resolution');
    buf.writeln('视频编码 / 帧率: ${state.videoCodec.isNotEmpty ? state.videoCodec : "--"} / $fps');
    buf.writeln('视频码率: $vBitrate');
    buf.writeln('硬件解码: ${controller.hAenable ? "已启用 (${controller.hardwareDecoder})" : "软件解码"}');
    buf.writeln('超分辨率: $superResLabel');
    buf.writeln('视频参数: ${state.playerVideoParams}');
    buf.writeln('音频参数: ${state.playerAudioParams}');
    buf.writeln('音频码率: ${state.playerAudioBitrate.isNotEmpty ? state.playerAudioBitrate : "--"}');
    buf.writeln('缓冲状态: ${Utils.durationToString(state.currentPosition)} / 缓冲 ${Utils.durationToString(state.buffer)} / 总长 ${Utils.durationToString(state.duration)}');
    buf.writeln('弹幕统计: $danmakuSummary');
    return buf.toString();
  }

  Widget buildVideoInfoBody(PlayerState state, PlayerController controller) {
    final t = context.t;
    void copyWithToast(String content) {
      HaipeeDialog.showToast(message: t.playback.toast.clipboardCopied);
      Clipboard.setData(ClipboardData(text: content));
    }

    final resolution = (state.playerWidth > 0 && state.playerHeight > 0)
        ? '${state.playerWidth}x${state.playerHeight}'
        : '未知';
    final fpsText =
        state.videoFps > 0 ? '${state.videoFps.toStringAsFixed(2)} fps' : '--';
    final vBitrateText = _formatBitrate(
      state.playerVideoBitrate > 0
          ? state.playerVideoBitrate
          : state.demuxBitrate,
    );
    final superResLabel = switch (state.superResolutionType) {
      2 => 'Anime4K 均衡 (Lite)',
      3 => 'Anime4K 质量 (HQ)',
      _ => '关闭',
    };

    int totalDanmaku = 0;
    int biliCount = 0;
    int gamerCount = 0;
    int dandanCount = 0;
    for (final list in state.danDanmakus.values) {
      for (final item in list) {
        totalDanmaku++;
        if (item.source.contains('BiliBili')) {
          biliCount++;
        } else if (item.source.contains('Gamer')) {
          gamerCount++;
        } else {
          dandanCount++;
        }
      }
    }
    final isBili = controller.isBiliPlayback;
    final danmakuSummary = isBili
        ? '共 $totalDanmaku 条 · B站官方原生弹幕 (CID: ${controller.activeBiliCid ?? "--"})'
        : '共 $totalDanmaku 条 · BiliBili $biliCount / 巴哈姆特 $gamerCount / 弹弹Play $dandanCount';

    return ListView(
      key: const Key('video_stats_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (isBili)
          ListTile(
            leading: const Icon(Icons.tv_rounded, size: 20),
            title: const Text('B站流媒体与清晰度档位'),
            subtitle: Text(
              'BVID: ${controller.activeBiliBvid ?? "--"} · CID: ${controller.activeBiliCid ?? "--"} · 当前档位: ${BiliQualityHelper.getLabel(state.biliQuality)}',
            ),
            onTap: () => copyWithToast(
              'BVID: ${controller.activeBiliBvid ?? "--"}, CID: ${controller.activeBiliCid ?? "--"}, 画质: ${BiliQualityHelper.getLabel(state.biliQuality)}',
            ),
          ),
        ListTile(
          leading: const Icon(Icons.aspect_ratio_rounded, size: 20),
          title: Text(t.playback.debug.labels.resolution),
          subtitle: Text(
            '$resolution · 编码: ${state.videoCodec.isNotEmpty ? state.videoCodec : "--"} · 帧率: $fpsText · 码率: $vBitrateText',
          ),
          onTap: () => copyWithToast(
            '${t.playback.debug.labels.resolution}\n$resolution (${state.videoCodec}, $fpsText, $vBitrateText)',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.memory_rounded, size: 20),
          title: const Text('解码器与超分辨率渲染'),
          subtitle: Text(
            '硬件解码: ${controller.hAenable ? "开启 (${controller.hardwareDecoder})" : "软件解码"} · 超分辨率: $superResLabel',
          ),
          onTap: () => copyWithToast(
            '硬件解码: ${controller.hAenable ? controller.hardwareDecoder : "off"}, 超分辨率: $superResLabel',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.subtitles_rounded, size: 20),
          title: const Text('弹幕加载与来源统计'),
          subtitle: Text(danmakuSummary),
          onTap: () => copyWithToast('弹幕统计: $danmakuSummary'),
        ),
        ListTile(
          leading: const Icon(Icons.network_check_rounded, size: 20),
          title: const Text('播放进度与缓冲区健康度'),
          subtitle: Text(
            '位置: ${Utils.durationToString(state.currentPosition)} / 缓冲至: ${Utils.durationToString(state.buffer)} / 总长: ${Utils.durationToString(state.duration)}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.link_rounded, size: 20),
          title: Text(t.playback.debug.labels.playUrl),
          subtitle: Text(
            controller.videoUrl.isNotEmpty ? controller.videoUrl : '--',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => copyWithToast(controller.videoUrl),
        ),
        ListTile(
          leading: const Icon(Icons.tune_rounded, size: 20),
          title: Text(t.playback.debug.labels.videoParams),
          subtitle: Text(
            state.playerVideoParams.isNotEmpty ? state.playerVideoParams : '--',
          ),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.videoParams}\n${state.playerVideoParams}'),
        ),
        ListTile(
          leading: const Icon(Icons.graphic_eq_rounded, size: 20),
          title: Text(t.playback.debug.labels.audioParams),
          subtitle: Text(
            '${state.playerAudioParams.isNotEmpty ? state.playerAudioParams : "--"} · 码率: ${state.playerAudioBitrate.isNotEmpty ? state.playerAudioBitrate : "--"}',
          ),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.audioParams}\n${state.playerAudioParams}'),
        ),
        ListTile(
          leading: const Icon(Icons.audiotrack_rounded, size: 20),
          title: Text(t.playback.debug.labels.audioTracks),
          subtitle: Text(
            state.playerAudioTracks.isNotEmpty ? state.playerAudioTracks : '--',
          ),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.audioTracks}\n${state.playerAudioTracks}'),
        ),
        ListTile(
          leading: const Icon(Icons.videocam_rounded, size: 20),
          title: Text(t.playback.debug.labels.videoTracks),
          subtitle: Text(
            state.playerVideoTracks.isNotEmpty ? state.playerVideoTracks : '--',
          ),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.videoTracks}\n${state.playerVideoTracks}'),
        ),
      ],
    );
  }

  void showVideoInfo() async {
    final screenSize = MediaQuery.sizeOf(context);
    final sheetMaxWidth = (Utils.isDesktop() || Utils.isTablet()) &&
            screenSize.width >= 640
        ? (screenSize.width * 9 / 16).clamp(420.0, screenSize.width)
        : screenSize.width;
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: (screenSize.height * 0.82).clamp(180.0, screenSize.height),
          maxWidth: sheetMaxWidth,
        ),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return Consumer(
            builder: (context, ref, _) {
              final playerState = ref.watch(playerProvider);
              final controller = ref.read(playerProvider.notifier);
              final theme = Theme.of(context);
              return Material(
                key: const Key('video_stats_sheet'),
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompactHeader = constraints.maxWidth < 360;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '视频统计与媒体信息',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isCompactHeader)
                                  IconButton(
                                    key: const Key('video_stats_copy_button'),
                                    tooltip: '复制诊断参数',
                                    onPressed: () {
                                      final text = _buildStructuredStatsText(
                                        playerState,
                                        controller,
                                      );
                                      Clipboard.setData(
                                          ClipboardData(text: text));
                                      HaipeeDialog.showToast(
                                        message: context
                                            .t.playback.toast.clipboardCopied,
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 18),
                                  )
                                else
                                  TextButton.icon(
                                    key: const Key('video_stats_copy_button'),
                                    onPressed: () {
                                      final text = _buildStructuredStatsText(
                                        playerState,
                                        controller,
                                      );
                                      Clipboard.setData(
                                          ClipboardData(text: text));
                                      HaipeeDialog.showToast(
                                        message: context
                                            .t.playback.toast.clipboardCopied,
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 16),
                                    label: const Text('复制诊断参数'),
                                  ),
                                IconButton(
                                  key: const Key('video_stats_close_button'),
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: buildVideoInfoBody(playerState, controller),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        });
  }

  void showSyncPlayEndPointSwitchDialog() {
    if (playerController.syncplayController != null) {
      HaipeeDialog.showToast(
        message: context.t.playback.syncplay.switchServerBlocked,
      );
      return;
    }

    final t = context.t;
    final String defaultCustomSyncPlayEndPoint =
        t.playback.syncplay.defaultCustomEndpoint;
    String customSyncPlayEndPoint = defaultCustomSyncPlayEndPoint;
    String selectedSyncPlayEndPoint = setting.get(
        SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);

    HaipeeDialog.show(
      builder: (context) {
        return Consumer(builder: (context, ref, child) {
          // Initialize providers with current values
          ref.read(_syncPlaySelectedServerProvider.notifier).state =
              selectedSyncPlayEndPoint;
          ref.read(_syncPlayCustomServerProvider.notifier).state =
              customSyncPlayEndPoint;

          final selectedServer = ref.watch(_syncPlaySelectedServerProvider);
          final customServer = ref.watch(_syncPlayCustomServerProvider);

          List<String> syncPlayEndPoints = [];
          syncPlayEndPoints.addAll(defaultSyncPlayEndPoints);
          syncPlayEndPoints.add(customServer);
          if (!syncPlayEndPoints.contains(selectedServer)) {
            syncPlayEndPoints.add(selectedServer);
          }

          return AlertDialog(
            title: Text(t.playback.syncplay.selectServer.title),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedServer,
                        isExpanded: true,
                        items: syncPlayEndPoints.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            if (newValue == defaultCustomSyncPlayEndPoint) {
                              final serverTextController =
                                  TextEditingController();
                              HaipeeDialog.show(
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text(t.playback.syncplay.selectServer
                                        .customTitle),
                                    content: TextField(
                                      controller: serverTextController,
                                      decoration: InputDecoration(
                                        hintText: t.playback.syncplay
                                            .selectServer.customHint,
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(t.app.cancel),
                                        onPressed: () {
                                          HaipeeDialog.dismiss();
                                        },
                                      ),
                                      TextButton(
                                        child: Text(t.app.confirm),
                                        onPressed: () {
                                          if (serverTextController
                                                  .text.isNotEmpty &&
                                              !syncPlayEndPoints.contains(
                                                  serverTextController.text)) {
                                            HaipeeDialog.dismiss();
                                            ref
                                                .read(
                                                    _syncPlayCustomServerProvider
                                                        .notifier)
                                                .state = serverTextController.text;
                                            ref
                                                .read(
                                                    _syncPlaySelectedServerProvider
                                                        .notifier)
                                                .state = serverTextController.text;
                                          } else {
                                            HaipeeDialog.showToast(
                                              message: t
                                                  .playback
                                                  .syncplay
                                                  .selectServer
                                                  .duplicateOrEmpty,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              ref
                                  .read(
                                      _syncPlaySelectedServerProvider.notifier)
                                  .state = newValue;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(t.app.cancel),
                onPressed: () {
                  HaipeeDialog.dismiss();
                },
              ),
              TextButton(
                child: Text(t.app.confirm),
                onPressed: () {
                  setting.put(
                    SettingBoxKey.syncPlayEndPoint,
                    selectedServer,
                  );
                  HaipeeDialog.dismiss();
                },
              ),
            ],
          );
        });
      },
    );
  }

  void showSyncPlayRoomCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController roomController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    HaipeeDialog.show(builder: (BuildContext context) {
      return AlertDialog(
        title: Text(context.t.playback.syncplay.join.title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: roomController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t.playback.syncplay.join.roomLabel,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.t.playback.syncplay.join.roomEmpty;
                  }
                  final regex = RegExp(r'^[0-9]{6,10}$');
                  if (!regex.hasMatch(value)) {
                    return context.t.playback.syncplay.join.roomInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: context.t.playback.syncplay.join.usernameLabel,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.t.playback.syncplay.join.usernameEmpty;
                  }
                  final regex = RegExp(r'^[a-zA-Z]{4,12}$');
                  if (!regex.hasMatch(value)) {
                    return context.t.playback.syncplay.join.usernameInvalid;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HaipeeDialog.dismiss();
            },
            child: Text(context.t.app.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                HaipeeDialog.dismiss();
                playerController.createSyncPlayRoom(roomController.text,
                    usernameController.text, widget.changeEpisode);
              }
            },
            child: Text(context.t.app.confirm),
          ),
        ],
      );
    });
  }

  /// Used to decide which panel is used.
  /// It's too complicated to write these in conditional sentence.
  /// * true: use [PlayerItemPanel]
  /// * false: use [SmallestPlayerItemPanel]
  bool needFullPanel(BuildContext context) {
    // windows too small, workaround for ohos floating window
    if (MediaQuery.sizeOf(context).width < LayoutBreakpoint.compact['width']!) {
      return false;
    }
    // in desktop pip mode
    if (videoPageController.isPip) {
      return false;
    }
    // does not meet Google's phone landscape height and tablet landscape width requirements.
    if (MediaQuery.sizeOf(context).height >
            LayoutBreakpoint.compact['height']! &&
        MediaQuery.sizeOf(context).width < LayoutBreakpoint.medium['width']!) {
      return false;
    }
    return true;
  }

  @override
  void onWindowRestore() {
    playerController.danmakuController.clear();
  }

  @override
  void initState() {
    super.initState();
    playerController = ref.read(playerProvider.notifier);
    videoPageController = ref.read(videoProvider.notifier);
    historyController = ref.read(historyProvider.notifier);
    collectController = ref.read(collectionsProvider.notifier);
    myController = ref.read(myControllerProvider.notifier);
    _fullscreenSubscription = ref.listenManual<bool>(
      videoProvider.select((state) => state.isFullscreen),
      (previous, next) {
        if (!mounted) return;
        _handleFullscreenChange(context);
      },
    );
    // workaround for #214
    if (Platform.isIOS) {
      FlutterVolumeController.setIOSAudioSessionCategory(
          category: AudioSessionCategory.playback);
    }
    WidgetsBinding.instance.addObserver(this);
    animationController ??= AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
    final bool defaultDanmakuEnabled = setting.get(
      SettingBoxKey.danmakuEnabledByDefault,
      defaultValue: false,
    );
    _border = setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    _opacity = setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
    _duration = 8;
    _fontSize = setting.get(SettingBoxKey.danmakuFontSize,
        defaultValue: (Utils.isCompact()) ? 16.0 : 25.0);
    danmakuArea = setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0);
    _hideTop = !setting.get(SettingBoxKey.danmakuTop, defaultValue: true);
    _hideBottom =
        !setting.get(SettingBoxKey.danmakuBottom, defaultValue: false);
    _hideScroll = !setting.get(SettingBoxKey.danmakuScroll, defaultValue: true);
    _massiveMode =
        setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
    _danmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    playerTimer = getPlayerTimer();
    windowManager.addListener(this);

    // Initialize player UI after widget is mounted
    Future.microtask(() {
      if (mounted) {
        playerController.resetUiState(
          danmakuEnabled: defaultDanmakuEnabled,
        );
        displayVideoController();
        _bindAudioService();
      }
    });
  }

  @override
  void dispose() {
    // Don't dispose player here
    // We need to reuse the player after episode is changed and player item is disposed
    // We dispose player after video page disposed
    _cachedAudioController?.deactivate();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    playerTimer?.cancel();
    hideTimer?.cancel();
    mouseScrollerTimer?.cancel();
    hideVolumeUITimer?.cancel();
    animationController?.dispose();
    animationController = null;
    _fullscreenSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final videoState = ref.watch(videoProvider);
    ref.watch(collectionsProvider);
    collectType =
        collectController.getCollectType(videoPageController.bangumiItem);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.sizeOf(context);
        final double effectiveWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : screenSize.width;
        final double effectiveHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : (videoPageController.isFullscreen
                    ? screenSize.height
                    : (effectiveWidth * 9.0 / 16.0));
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: MouseRegion(
              cursor: (videoState.isFullscreen && !playerState.showVideoController)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onHover: (PointerEvent pointerEvent) {
                // workaround for android.
                // I don't know why, but android tap event will trigger onHover event.
                if (Utils.isDesktop()) {
                  if (pointerEvent.localPosition.dy > 50 &&
                      pointerEvent.localPosition.dy < effectiveHeight - 70) {
                    _handleHove();
                  } else {
                    if (!playerController.showVideoController) {
                      animationController?.forward();
                      playerController.showVideoController = true;
                    }
                  }
                }
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    _handleMouseScroller();
                    final scrollDelta = pointerSignal.scrollDelta;
                    final double volume =
                        playerController.volume - scrollDelta.dy / 60;
                    playerController.setVolume(volume);
                  }
                },
                child: SizedBox(
                  height: effectiveHeight,
                  width: effectiveWidth,
                  child: Stack(alignment: Alignment.center, children: [
                Center(
                    child: Focus(
                        // workaround for #461
                        // I don't know why, but the focus node will break popscope.
                        focusNode:
                            Utils.isDesktop() ? widget.keyboardFocus : null,
                        autofocus: Utils.isDesktop(),
                        onKeyEvent: (focusNode, KeyEvent event) {
                          if (event is KeyDownEvent) {
                            // 当空格键被按下时
                            if (event.logicalKey == LogicalKeyboardKey.space) {
                              try {
                                playerController.playOrPause();
                              } catch (e) {
                                HaipeeLogger().log(
                                    Level.error, '播放器内部错误 ${e.toString()}');
                              }
                            }
                            // 右方向键被按下
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowRight) {
                              lastPlayerSpeed = playerController.playerSpeed;
                            }
                            // 左方向键被按下
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowLeft) {
                              int targetPosition =
                                  playerController.currentPosition.inSeconds -
                                      10;
                              if (targetPosition < 0) {
                                targetPosition = 0;
                              }
                              try {
                                playerTimer?.cancel();
                                playerController
                                    .seek(Duration(seconds: targetPosition));
                                playerTimer = getPlayerTimer();
                              } catch (e) {
                                HaipeeLogger().log(Level.error, e.toString());
                              }
                            }
                            // 上方向键被按下
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowUp) {
                              increaseVolume();
                              _handleKeyChangingVolume();
                            }
                            // 下方向键被按下
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              decreaseVolume();
                              _handleKeyChangingVolume();
                            }
                            // Esc键被按下
                            if (event.logicalKey == LogicalKeyboardKey.escape) {
                              if (videoPageController.isPip) {
                                Utils.exitDesktopPIPWindow();
                                videoPageController.isPip = false;
                              } else if (videoPageController.isFullscreen &&
                                  !Utils.isTablet()) {
                                try {
                                  playerController.danmakuController.clear();
                                } catch (_) {}
                                Utils.exitFullScreen();
                                videoPageController.isFullscreen =
                                    !videoPageController.isFullscreen;
                              } else if (!Platform.isMacOS) {
                                playerController.pause();
                                windowManager.hide();
                              }
                            }
                            // F键被按下
                            if (event.logicalKey == LogicalKeyboardKey.keyF) {
                              if (!videoPageController.isPip) {
                                handleFullscreen();
                              }
                            }
                            // D键盘被按下
                            if (event.logicalKey == LogicalKeyboardKey.keyD) {
                              handleDanmaku();
                            }
                          } else if (event is KeyRepeatEvent) {
                            // 右方向键长按
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowRight) {
                              if (playerController.playerSpeed < 2.0) {
                                playerController.showPlaySpeed = true;
                                setPlaybackSpeed(2.0);
                              }
                            }
                          } else if (event is KeyUpEvent) {
                            // 右方向键抬起
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowRight) {
                              if (playerController.showPlaySpeed) {
                                playerController.showPlaySpeed = false;
                                setPlaybackSpeed(lastPlayerSpeed);
                              } else {
                                try {
                                  playerTimer?.cancel();
                                  playerController.seek(Duration(
                                      seconds: playerController
                                              .currentPosition.inSeconds +
                                          10));
                                  playerTimer = getPlayerTimer();
                                } catch (e) {
                                  HaipeeLogger().log(
                                      Level.error, '播放器内部错误 ${e.toString()}');
                                }
                              }
                            }
                          }
                          return KeyEventResult.handled;
                        },
                        child: const PlayerItemSurface())),
                (playerState.isBuffering ||
                        playerState.loading ||
                        (playerController.activeLocalVideoArgs == null &&
                            videoState.loading))
                    ? const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Container(),
                GestureDetector(
                  onTap: () {
                    _handleTap();
                  },
                  onDoubleTap: (playerController.lockPanel)
                      ? null
                      : () {
                          _handleDoubleTap();
                        },
                  onLongPressStart: (_) {
                    if (playerController.lockPanel) {
                      return;
                    }

                    playerController.showPlaySpeed = true;
                    lastPlayerSpeed = playerController.playerSpeed;
                    setPlaybackSpeed(2.0);
                  },
                  onLongPressEnd: (_) {
                    if (playerController.lockPanel) {
                      return;
                    }

                    playerController.showPlaySpeed = false;
                    setPlaybackSpeed(lastPlayerSpeed);
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // 弹幕面板
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: effectiveHeight,
                  child: DanmakuScreen(
                    key: _danmuKey,
                    createdController: (DanmakuController e) {
                      playerController.danmakuController = e;
                    },
                    option: DanmakuOption(
                      hideTop: _hideTop,
                      hideScroll: _hideScroll,
                      hideBottom: _hideBottom,
                      area: danmakuArea,
                      opacity: _opacity,
                      fontSize: _fontSize,
                      duration: (_duration / playerController.playerSpeed).toDouble(),
                      strokeWidth: _border ? 1.5 : 0.0,
                      fontWeight: _danmakuFontWeight,
                      massiveMode: _massiveMode,
                    ),
                  ),
                ),
                // 播放器控制面板
                (needFullPanel(context))
                    ? PlayerItemPanel(
                        onBackPressed: widget.onBackPressed,
                        setPlaybackSpeed: setPlaybackSpeed,
                        showDanmakuSwitch: showDanmakuSwitch,
                        changeEpisode: widget.changeEpisode,
                        openMenu: widget.openMenu,
                        handleFullscreen: handleFullscreen,
                        handleProgressBarDragStart: handleProgressBarDragStart,
                        handleProgressBarDragEnd: handleProgressBarDragEnd,
                        handleSuperResolutionChange:
                            handleSuperResolutionChange,
                        animationController: animationController!,
                        keyboardFocus: widget.keyboardFocus,
                        sendDanmaku: widget.sendDanmaku,
                        startHideTimer: startHideTimer,
                        cancelHideTimer: cancelHideTimer,
                        handleDanmaku: handleDanmaku,
                        showVideoInfo: showVideoInfo,
                        showSyncPlayRoomCreateDialog:
                            showSyncPlayRoomCreateDialog,
                        showSyncPlayEndPointSwitchDialog:
                            showSyncPlayEndPointSwitchDialog,
                        disableAnimations: widget.disableAnimations,
                      )
                    : SmallestPlayerItemPanel(
                        onBackPressed: widget.onBackPressed,
                        setPlaybackSpeed: setPlaybackSpeed,
                        showDanmakuSwitch: showDanmakuSwitch,
                        handleFullscreen: handleFullscreen,
                        handleProgressBarDragStart: handleProgressBarDragStart,
                        handleProgressBarDragEnd: handleProgressBarDragEnd,
                        handleSuperResolutionChange:
                            handleSuperResolutionChange,
                        animationController: animationController!,
                        keyboardFocus: widget.keyboardFocus,
                        handleHove: _handleHove,
                        startHideTimer: startHideTimer,
                        cancelHideTimer: cancelHideTimer,
                        handleDanmaku: handleDanmaku,
                        showVideoInfo: showVideoInfo,
                        showSyncPlayRoomCreateDialog:
                            showSyncPlayRoomCreateDialog,
                        showSyncPlayEndPointSwitchDialog:
                            showSyncPlayEndPointSwitchDialog,
                        disableAnimations: widget.disableAnimations,
                      ),
                // 播放器手势控制
                Positioned.fill(
                  left: 16,
                  top: 25,
                  right: 15,
                  bottom: 15,
                  child: (Utils.isDesktop() || playerController.lockPanel)
                      ? Container()
                      : GestureDetector(
                          onHorizontalDragStart: (_) {
                            if (!playerController.showVideoController) {
                              animationController?.forward();
                            }
                            playerController.canHidePlayerPanel = false;
                          },
                          onHorizontalDragUpdate: (DragUpdateDetails details) {
                            playerController.showSeekTime = true;
                            playerTimer?.cancel();
                            playerController.pause(enableSync: false);
                            final double scale =
                                180000 / MediaQuery.sizeOf(context).width;
                            int ms = (playerController
                                        .currentPosition.inMilliseconds +
                                    (details.delta.dx * scale).round())
                                .clamp(0,
                                    playerController.duration.inMilliseconds);
                            playerController.currentPosition =
                                Duration(milliseconds: ms);
                          },
                          onHorizontalDragEnd: (_) {
                            playerController.play(enableSync: false);
                            playerController
                                .seek(playerController.currentPosition);
                            playerController.canHidePlayerPanel = true;
                            if (!playerController.showVideoController) {
                              animationController?.reverse();
                            } else {
                              hideTimer?.cancel();
                              startHideTimer();
                            }
                            playerTimer?.cancel();
                            playerTimer = getPlayerTimer();
                            playerController.showSeekTime = false;
                          },
                          onVerticalDragUpdate:
                              (DragUpdateDetails details) async {
                            final double totalWidth =
                                MediaQuery.sizeOf(context).width;
                            final double totalHeight =
                                MediaQuery.sizeOf(context).height;
                            final double tapPosition = details.localPosition.dx;
                            final double sectionWidth = totalWidth / 2;
                            final double delta = details.delta.dy;

                            if (tapPosition < sectionWidth) {
                              // 左边区域
                              playerController.brightnessSeeking = true;
                              playerController.showBrightness = true;
                              final double level = (totalHeight) * 2;
                              final double brightness =
                                  playerController.brightness - delta / level;
                              final double result = brightness.clamp(0.0, 1.0);
                              setBrightness(result);
                              playerController.brightness = result;
                            } else {
                              // 右边区域
                              playerController.volumeSeeking = true;
                              playerController.showVolume = true;
                              final double level = (totalHeight) * 0.03;
                              final double volume =
                                  playerController.volume - delta / level;
                              playerController.setVolume(volume);
                            }
                          },
                          onVerticalDragEnd: (_) {
                            if (playerController.volumeSeeking) {
                              playerController.volumeSeeking = false;
                              Future.delayed(const Duration(seconds: 1), () {
                                FlutterVolumeController.updateShowSystemUI(
                                    true);
                              });
                            }
                            if (playerController.brightnessSeeking) {
                              playerController.brightnessSeeking = false;
                            }
                            playerController.showVolume = false;
                            playerController.showBrightness = false;
                          },
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
