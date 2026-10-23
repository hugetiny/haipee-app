import 'dart:async';
import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/services/player/audio_controller.dart';
import 'package:kazumi/pages/player/player_state.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/history/providers.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:kazumi/pages/setting/setting_controller.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

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
  late bool _danmakuColor;
  late bool _danmakuBiliBiliSource;
  late bool _danmakuGamerSource;
  late bool _danmakuDanDanSource;
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

      await KazumiDialog.show(builder: (context) {
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
                  KazumiDialog.dismiss();
                },
                child: Text(t.app.cancel),
              ),
              TextButton(
                onPressed: () async {
                  confirmed = true;
                  if (dontAskAgain) {
                    await setting.put(SettingBoxKey.superResolutionWarn, true);
                  }
                  KazumiDialog.dismiss();
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
            currentDanmakus.asMap().forEach((idx, danmaku) async {
              if (!_danmakuColor) {
                danmaku.color = Colors.white;
              }
              // 对于 B站 原生视频 (activeBiliCid > 0)，以官方 CID 原生弹幕为准，严禁被第三方 DanDanPlay 弹幕源开关屏蔽
              if (!isBiliNative) {
                if (!_danmakuBiliBiliSource &&
                    danmaku.source.contains('BiliBili')) {
                  return;
                }
                if (!_danmakuGamerSource && danmaku.source.contains('Gamer')) {
                  return;
                }
                if (!_danmakuDanDanSource &&
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
                            color: danmaku.color,
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
          if (roadList.isNotEmpty &&
              currentRoad >= 0 &&
              currentRoad < roadList.length &&
              currentEpisode > 0 &&
              currentEpisode - 1 < roadList[currentRoad].identifier.length) {
            historyController.updateHistory(
                currentEpisode,
                currentRoad,
                videoPageController.currentPlugin.name,
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
        KazumiDialog.showToast(
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
      KazumiLogger().w('AudioController: failed to bind callbacks', error: e);
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
          album: videoPageController.currentPlugin.name,
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
      KazumiLogger().w('AudioController: failed to sync state', error: e);
    }
  }

  void showDanmakuSearchDialog(String keyword) async {
    final t = context.t;
    KazumiDialog.dismiss();
    KazumiDialog.showLoading(msg: t.playback.loading.danmakuSearch);
    DanmakuSearchResponse danmakuSearchResponse;
    DanmakuEpisodeResponse danmakuEpisodeResponse;
    try {
      danmakuSearchResponse =
          await DanmakuRequest.getDanmakuSearchResponse(keyword);
    } catch (error) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(
        message: t.playback.toast.danmakuSearchError.replaceFirst(
          '{error}',
          error.toString(),
        ),
      );
      return;
    }
    KazumiDialog.dismiss();
    if (danmakuSearchResponse.animes.isEmpty) {
      KazumiDialog.showToast(
        message: t.playback.toast.danmakuSearchEmpty,
      );
      return;
    }
    await KazumiDialog.show(builder: (dialogContext) {
      return Dialog(
        child: ListView(
          shrinkWrap: true,
          children: danmakuSearchResponse.animes.map((danmakuInfo) {
            return ListTile(
              title: Text(danmakuInfo.animeTitle),
              onTap: () async {
                KazumiDialog.dismiss();
                KazumiDialog.showLoading(msg: t.playback.loading.danmakuSearch);
                try {
                  danmakuEpisodeResponse =
                      await DanmakuRequest.getDanDanEpisodesByDanDanBangumiID(
                          danmakuInfo.animeId,
                          silent: false);
                } catch (error) {
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(
                    message: t.playback.toast.danmakuSearchError.replaceFirst(
                      '{error}',
                      error.toString(),
                    ),
                  );
                  return;
                }
                KazumiDialog.dismiss();
                if (danmakuEpisodeResponse.episodes.isEmpty) {
                  KazumiDialog.showToast(
                    message: t.playback.toast.danmakuSearchEmpty,
                  );
                  return;
                }
                KazumiDialog.show(builder: (episodesContext) {
                  return Dialog(
                    child: ListView(
                      shrinkWrap: true,
                      children: danmakuEpisodeResponse.episodes.map((episode) {
                        return ListTile(
                          title: Text(episode.episodeTitle),
                          onTap: () {
                            KazumiDialog.dismiss();
                            KazumiDialog.showToast(
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
      KazumiDialog.showToast(message: '当前为哔哩哔哩原生视频，以官方 CID 弹幕为准，无需外部模糊匹配');
      return;
    }
    final t = context.t;
    KazumiDialog.show(
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
                KazumiDialog.dismiss();
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

  Widget buildVideoInfoBody(PlayerState state, PlayerController controller) {
    final t = context.t;
    void copyWithToast(String content) {
      KazumiDialog.showToast(message: t.playback.toast.clipboardCopied);
      Clipboard.setData(ClipboardData(text: content));
    }

    return ListView(
      children: [
        ListTile(
          title: Text(t.playback.debug.labels.playUrl),
          subtitle: Text(controller.videoUrl),
          onTap: () => copyWithToast(controller.videoUrl),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.resolution),
          subtitle: Text('${state.playerWidth}x${state.playerHeight}'),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.resolution}\n${state.playerWidth}x${state.playerHeight}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.videoParams),
          subtitle: Text(state.playerVideoParams),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.videoParams}\n${state.playerVideoParams}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.audioParams),
          subtitle: Text(state.playerAudioParams),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.audioParams}\n${state.playerAudioParams}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.playlist),
          subtitle: Text(state.playerPlaylist),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.playlist}\n${state.playerPlaylist}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.audioTracks),
          subtitle: Text(state.playerAudioTracks),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.audioTracks}\n${state.playerAudioTracks}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.videoTracks),
          subtitle: Text(state.playerVideoTracks),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.videoTracks}\n${state.playerVideoTracks}'),
        ),
        ListTile(
          title: Text(t.playback.debug.labels.audioBitrate),
          subtitle: Text(state.playerAudioBitrate),
          onTap: () => copyWithToast(
              '${t.playback.debug.labels.audioBitrate}\n${state.playerAudioBitrate}'),
        ),
      ],
    );
  }

  Widget buildVideoDebugLogBody(PlayerState state) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
        child: ListView.builder(
          itemCount: state.playerLog.length,
          itemBuilder: (context, index) {
            return Text(state.playerLog[index]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.copy),
        onPressed: () {
          Clipboard.setData(
            ClipboardData(text: state.playerLog.join('\n')),
          );
          KazumiDialog.showToast(
            message: context.t.playback.toast.clipboardCopied,
          );
        },
      ),
    );
  }

  void showVideoInfo() async {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (Utils.isDesktop() || Utils.isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return DefaultTabController(
            length: 2,
            child: Consumer(
              builder: (context, ref, _) {
                final playerState = ref.watch(playerProvider);
                final controller = ref.read(playerProvider.notifier);
                return Scaffold(
                  body: Column(
                    children: [
                      PreferredSize(
                        preferredSize: const Size.fromHeight(kToolbarHeight),
                        child: Material(
                          child: TabBar(
                            tabs: [
                              Tab(text: context.t.playback.debug.tabs.status),
                              Tab(text: context.t.playback.debug.tabs.logs),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            buildVideoInfoBody(playerState, controller),
                            buildVideoDebugLogBody(playerState),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
  }

  void showSyncPlayEndPointSwitchDialog() {
    if (playerController.syncplayController != null) {
      KazumiDialog.showToast(
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

    KazumiDialog.show(
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
                              KazumiDialog.show(
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
                                          KazumiDialog.dismiss();
                                        },
                                      ),
                                      TextButton(
                                        child: Text(t.app.confirm),
                                        onPressed: () {
                                          if (serverTextController
                                                  .text.isNotEmpty &&
                                              !syncPlayEndPoints.contains(
                                                  serverTextController.text)) {
                                            KazumiDialog.dismiss();
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
                                            KazumiDialog.showToast(
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
                  KazumiDialog.dismiss();
                },
              ),
              TextButton(
                child: Text(t.app.confirm),
                onPressed: () {
                  setting.put(
                    SettingBoxKey.syncPlayEndPoint,
                    selectedServer,
                  );
                  KazumiDialog.dismiss();
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
    KazumiDialog.show(builder: (BuildContext context) {
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
              KazumiDialog.dismiss();
            },
            child: Text(context.t.app.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                KazumiDialog.dismiss();
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
    _danmakuColor = setting.get(SettingBoxKey.danmakuColor, defaultValue: true);
    _danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    _danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    _danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
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
                                KazumiLogger().log(
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
                                KazumiLogger().log(Level.error, e.toString());
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
                              if (videoPageController.isFullscreen &&
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
                                  KazumiLogger().log(
                                      Level.error, '播放器内部错误 ${e.toString()}');
                                }
                              }
                            }
                          }
                          return KeyEventResult.handled;
                        },
                        child: const PlayerItemSurface())),
                (playerController.isBuffering || videoPageController.loading)
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
