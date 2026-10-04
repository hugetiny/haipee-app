import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:kazumi/utils/syncplay.dart';
import 'package:kazumi/utils/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:kazumi/pages/player/player_state.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/shaders/providers.dart';
import 'package:kazumi/providers/translations_provider.dart';

class PlayerController extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    _initializeDependencies();
    ref.onDispose(() {
      unawaited(disposeResources());
    });
    return const PlayerState();
  }

  late final VideoPageController videoPageController;
  late final ShadersController shadersController;

  // 弹幕控制
  late DanmakuController danmakuController;

  // 一起看控制器
  SyncplayClient? syncplayController;

  // 视频地址
  String videoUrl = '';

  // DanDanPlay 弹幕ID
  int bangumiID = 0;

  // 播放器实体
  Player? mediaPlayer;
  VideoController? videoController;

  Box setting = GStorage.setting;
  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = kDebugMode;
  int forwardTime = 80;

  // 播放器实时状态
  bool get playerPlaying => mediaPlayer!.state.playing;
  bool get playerBuffering => mediaPlayer!.state.buffering;
  bool get playerCompleted => mediaPlayer!.state.completed;
  double get playerVolume => mediaPlayer!.state.volume;
  Duration get playerPosition => mediaPlayer!.state.position;
  Duration get playerBuffer => mediaPlayer!.state.buffer;
  Duration get playerDuration => mediaPlayer!.state.duration;

  // 播放器调试信息订阅
  StreamSubscription<PlayerLog>? playerLogSubscription;
  StreamSubscription<int?>? playerWidthSubscription;
  StreamSubscription<int?>? playerHeightSubscription;
  StreamSubscription<VideoParams>? playerVideoParamsSubscription;
  StreamSubscription<AudioParams>? playerAudioParamsSubscription;
  StreamSubscription<Playlist>? playerPlaylistSubscription;
  StreamSubscription<Track>? playerTracksSubscription;
  StreamSubscription<double?>? playerAudioBitrateSubscription;

  void _initializeDependencies() {
    videoPageController = ref.read(videoProvider.notifier);
    shadersController = ref.read(shadersControllerProvider);
  }

  Future<void> init(String url, {int offset = 0}) async {
    videoUrl = url;
    state = state.copyWith(
      playing: false,
      loading: true,
      isBuffering: true,
      currentPosition: Duration.zero,
      buffer: Duration.zero,
      duration: Duration.zero,
      completed: false,
    );
    try {
      await disposeResources(disposeSyncPlayController: false);
    } catch (_) {}
    int episodeFromTitle = 0;
    try {
      episodeFromTitle = Utils.extractEpisodeNumber(videoPageController
          .state
          .roadList[videoPageController.state.currentRoad]
          .identifier[videoPageController.state.currentEpisode - 1]);
    } catch (e) {
      KazumiLogger().log(Level.error, '从标题解析集数错误 ${e.toString()}');
    }
    if (episodeFromTitle == 0) {
      episodeFromTitle = videoPageController.state.currentEpisode;
    }

    // 🚀 优化：并行加载弹幕和创建播放器，不阻塞播放
    getDanDanmakuByBgmBangumiID(
        videoPageController.state.bangumiItem!.id, episodeFromTitle);
    mediaPlayer ??= await createVideoController(offset: offset);
    final playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    final aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
    state = state.copyWith(
      playerSpeed: playerSpeed,
      aspectRatioType: aspectRatioType,
    );
    if (Utils.isDesktop()) {
      final volume = state.volume != -1 ? state.volume : 100.0;
      state = state.copyWith(volume: volume);
      await setVolume(volume);
    } else {
      // mobile is using system volume, don't setVolume here,
      // or iOS will mute if system volume is too low (#732)
      await FlutterVolumeController.getVolume().then((value) {
        final volume = (value ?? 0.0) * 100;
        state = state.copyWith(volume: volume);
      });
    }
    setPlaybackSpeed(state.playerSpeed);
    KazumiLogger().log(Level.info, 'VideoURL初始化完成');
    state = state.copyWith(loading: false);
    if (syncplayController?.isConnected ?? false) {
      if (syncplayController!.currentFileName !=
          "${videoPageController.state.bangumiItem!.id}[${videoPageController.state.currentEpisode}]") {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
  }

  Future<void> setupPlayerDebugInfoSubscription() async {
    await playerLogSubscription?.cancel();
    playerLogSubscription = mediaPlayer!.stream.log.listen((event) {
      final newLog = [...state.playerLog, event.toString()];
      state = state.copyWith(playerLog: newLog);
      if (playerDebugMode) {
        KazumiLogger().simpleLog(event.toString());
      }
    });
    await playerWidthSubscription?.cancel();
    playerWidthSubscription = mediaPlayer!.stream.width.listen((event) {
      state = state.copyWith(playerWidth: event ?? 0);
    });
    await playerHeightSubscription?.cancel();
    playerHeightSubscription = mediaPlayer!.stream.height.listen((event) {
      state = state.copyWith(playerHeight: event ?? 0);
    });
    await playerVideoParamsSubscription?.cancel();
    playerVideoParamsSubscription =
        mediaPlayer!.stream.videoParams.listen((event) {
      state = state.copyWith(playerVideoParams: event.toString());
    });
    await playerAudioParamsSubscription?.cancel();
    playerAudioParamsSubscription =
        mediaPlayer!.stream.audioParams.listen((event) {
      state = state.copyWith(playerAudioParams: event.toString());
    });
    await playerPlaylistSubscription?.cancel();
    playerPlaylistSubscription = mediaPlayer!.stream.playlist.listen((event) {
      state = state.copyWith(playerPlaylist: event.toString());
    });
    await playerTracksSubscription?.cancel();
    playerTracksSubscription = mediaPlayer!.stream.track.listen((event) {
      state = state.copyWith(
        playerAudioTracks: event.audio.toString(),
        playerVideoTracks: event.video.toString(),
      );
    });
    await playerAudioBitrateSubscription?.cancel();
    playerAudioBitrateSubscription =
        mediaPlayer!.stream.audioBitrate.listen((event) {
      state = state.copyWith(playerAudioBitrate: event.toString());
    });
  }

  Future<void> cancelPlayerDebugInfoSubscription() async {
    await playerLogSubscription?.cancel();
    await playerWidthSubscription?.cancel();
    await playerHeightSubscription?.cancel();
    await playerVideoParamsSubscription?.cancel();
    await playerAudioParamsSubscription?.cancel();
    await playerPlaylistSubscription?.cancel();
    await playerTracksSubscription?.cancel();
    await playerAudioBitrateSubscription?.cancel();
  }

  Future<Player> createVideoController({int offset = 0}) async {
    String userAgent = '';
    final superResolutionType =
        setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1);
    state = state.copyWith(superResolutionType: superResolutionType);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    hardwareDecoder =
        setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
    autoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playerDebugMode = setting.get(
      SettingBoxKey.playerDebugMode,
      defaultValue: kDebugMode,
    );
    if (videoPageController.currentPlugin.userAgent == '') {
      userAgent = Utils.getRandomUA();
    } else {
      userAgent = videoPageController.currentPlugin.userAgent;
    }
    String referer = videoPageController.currentPlugin.referer;
    var httpHeaders = {
      'user-agent': userAgent,
      if (referer.isNotEmpty) 'referer': referer,
    };

    mediaPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: lowMemoryMode ? 15 * 1024 * 1024 : 1500 * 1024 * 1024,
        osc: false,
        logLevel: MPVLogLevel.info,
      ),
    );

    // 记录播放器内部日志
    state = state.copyWith(playerLog: []);
    setupPlayerDebugInfoSubscription();

    var pp = mediaPlayer!.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (androidEnableOpenSLES) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
    }

    await mediaPlayer!.setAudioTrack(
      AudioTrack.auto(),
    );

    videoController ??= VideoController(
      mediaPlayer!,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    mediaPlayer!.setPlaylistMode(PlaylistMode.none);

    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    mediaPlayer!.stream.error.listen((event) {
      if (showPlayerError) {
        final t = ref.read(translationsProvider);
        final details = '${event.toString()} $videoUrl';
        KazumiDialog.showToast(
          message:
              t.playback.toast.internalError.replaceFirst('{details}', details),
          duration: const Duration(seconds: 5),
          showActionButton: true,
        );
      }
      KazumiLogger().log(
          Level.error, 'Player intent error: ${event.toString()} $videoUrl');
    });

    if (state.superResolutionType != 1) {
      await setShader(state.superResolutionType);
    }

    await mediaPlayer!.open(
      Media(videoUrl,
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );

    return mediaPlayer!;
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    var pp = mediaPlayer!.platform as NativePlayer;
    await pp.waitForPlayerInitialization;
    await pp.waitForVideoControllerInitializationIfAttached;
    if (type == 2) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShadersLite),
      ]);
      state = state.copyWith(superResolutionType: 2);
      return;
    }
    if (type == 3) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShaders),
      ]);
      state = state.copyWith(superResolutionType: 3);
      return;
    }
    await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
    state = state.copyWith(superResolutionType: 1);
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    state = state.copyWith(playerSpeed: playerSpeed);
    try {
      mediaPlayer!.setRate(playerSpeed);
    } catch (e) {
      KazumiLogger().log(Level.error, '设置播放速度失败 ${e.toString()}');
    }
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
    state = state.copyWith(volume: value);
    try {
      if (Utils.isDesktop()) {
        await mediaPlayer!.setVolume(value);
      } else {
        await FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
  }

  Future<void> playOrPause() async {
    if (mediaPlayer!.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration duration, {bool enableSync = true}) async {
    state = state.copyWith(currentPosition: duration);
    danmakuController.clear();
    await mediaPlayer!.seek(duration);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync(doSeek: true);
      }
    }
  }

  Future<void> pause({bool enableSync = true}) async {
    danmakuController.pause();
    await mediaPlayer!.pause();
    state = state.copyWith(playing: false);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> play({bool enableSync = true}) async {
    danmakuController.resume();
    await mediaPlayer!.play();
    state = state.copyWith(playing: true);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> disposeResources({bool disposeSyncPlayController = true}) async {
    if (disposeSyncPlayController) {
      try {
        state = state.copyWith(syncplayRoom: '', syncplayClientRtt: 0);
        await syncplayController?.disconnect();
        syncplayController = null;
      } catch (_) {}
    }
    try {
      await cancelPlayerDebugInfoSubscription();
    } catch (_) {}
    await mediaPlayer?.dispose();
    mediaPlayer = null;
    videoController = null;
  }

  Future<void> stop({bool updateState = true}) async {
    try {
      await mediaPlayer?.stop();
      if (updateState) {
        state = state.copyWith(loading: true);
      }
    } catch (_) {}
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await mediaPlayer!.screenshot(format: format);
  }

  void setForwardTime(int time) {
    forwardTime = time;
  }

  Future<void> getDanDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 [BgmBangumiID] $bgmBangumiID');
    try {
      state = state.copyWith(danDanmakus: {});
      bangumiID =
          await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByTitle(String title, int episode) async {
    KazumiLogger().log(Level.info, '尝试根据标题获取弹幕: $title, 集数: $episode');
    try {
      state = state.copyWith(danDanmakus: {});
      final bId = await DanmakuRequest.getBangumiIDByTitle(title);
      if (bId > 0) {
        bangumiID = bId;
        final res = await DanmakuRequest.getDanDanmaku(bId, episode);
        addDanmakus(res);
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '根据标题获取弹幕错误: ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 $episodeID');
    try {
      state = state.copyWith(danDanmakus: {});
      var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    final newDanDanmakus = Map<int, List<Danmaku>>.from(state.danDanmakus);
    for (var element in danmakus) {
      var danmakuList =
          newDanDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      newDanDanmakus[element.time.toInt()] = danmakuList;
    }
    state = state.copyWith(danDanmakus: newDanDanmakus);
  }

  void lanunchExternalPlayer() async {
    String referer = videoPageController.currentPlugin.referer;
    final t = ref.read(translationsProvider);
    if ((Platform.isAndroid || Platform.isWindows) && referer.isEmpty) {
      if (await ExternalPlayer.launchURLWithMIME(videoUrl, 'video/mp4')) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.launchFailed,
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchURLWithReferer(videoUrl, referer)) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.launchFailed,
        );
      }
    } else if (Platform.isLinux && referer.isEmpty) {
      KazumiDialog.dismiss();
      if (await canLaunchUrlString(videoUrl)) {
        launchUrlString(videoUrl);
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.unavailable,
        );
      }
    } else {
      if (referer.isEmpty) {
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.unsupportedDevice,
        );
      } else {
        KazumiDialog.showToast(
          message: t.playback.externalPlayer.unsupportedPlugin,
        );
      }
    }
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      {bool enableTLS = false}) async {
    await syncplayController?.disconnect();
    final t = ref.read(translationsProvider);
    final String syncPlayEndPoint = setting.get(SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);
    String syncPlayEndPointHost = '';
    int syncPlayEndPointPort = 0;
    debugPrint('SyncPlay: 连接到服务器 $syncPlayEndPoint');
    try {
      final parts = syncPlayEndPoint.split(':');
      if (parts.length == 2) {
        syncPlayEndPointHost = parts[0];
        syncPlayEndPointPort = int.parse(parts[1]);
      }
    } catch (_) {}
    if (syncPlayEndPointHost == '' || syncPlayEndPointPort == 0) {
      KazumiDialog.showToast(
        message: t.playback.syncplay.invalidEndpoint
            .replaceFirst('{endpoint}', syncPlayEndPoint),
      );
      KazumiLogger().log(Level.error, 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint');
      return;
    }
    String actorName(dynamic raw) {
      final value = (raw is String ? raw.trim() : '');
      return value.isEmpty ? t.playback.syncplay.unknownUser : value;
    }

    syncplayController =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    try {
      await syncplayController!.connect(enableTLS: enableTLS);
      syncplayController!.onGeneralMessage.listen(
        (message) {
          // KazumiLogger().log(Level.debug, 'SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          KazumiLogger().log(Level.error, 'SyncPlay: error: ${error.message}');
          if (error is SyncplayConnectionException) {
            exitSyncPlayRoom();
            KazumiDialog.showToast(
              message: t.playback.syncplay.disconnected
                  .replaceFirst('{reason}', error.message),
              duration: const Duration(seconds: 5),
              showActionButton: true,
              actionLabel: t.playback.syncplay.actionReconnect,
              onActionPressed: () =>
                  createSyncPlayRoom(room, username, changeEpisode),
            );
          }
        },
      );
      syncplayController!.onRoomMessage.listen(
        (message) {
          if (message['type'] == 'init') {
            final rawUser = (message['username'] as String?) ?? '';
            if (rawUser.isEmpty) {
              KazumiDialog.showToast(
                  message: t.playback.syncplay.alone,
                  duration: const Duration(seconds: 5));
              setSyncPlayPlayingBangumi();
            } else {
              KazumiDialog.showToast(
                  message: t.playback.syncplay.followUser
                      .replaceFirst('{username}', actorName(rawUser)));
            }
          }
          if (message['type'] == 'left') {
            KazumiDialog.showToast(
                message: t.playback.syncplay.userLeft
                    .replaceFirst('{username}', actorName(message['username'])),
                duration: const Duration(seconds: 5));
          }
          if (message['type'] == 'joined') {
            KazumiDialog.showToast(
                message: t.playback.syncplay.userJoined
                    .replaceFirst('{username}', actorName(message['username'])),
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onFileChangedMessage.listen(
        (message) {
          KazumiLogger().log(Level.info,
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          RegExp regExp = RegExp(r'(\d+)\[(\d+)\]');
          Match? match = regExp.firstMatch(message['name']);
          if (match != null) {
            int bangumiID = int.tryParse(match.group(1) ?? '0') ?? 0;
            int episode = int.tryParse(match.group(2) ?? '0') ?? 0;
            if (bangumiID != 0 &&
                episode != 0 &&
                episode != videoPageController.currentEpisode) {
              KazumiDialog.showToast(
                  message: t.playback.syncplay.switchEpisode
                      .replaceFirst('{username}', actorName(message['setBy']))
                      .replaceFirst('{episode}', episode.toString()),
                  duration: const Duration(seconds: 3));
              changeEpisode(episode,
                  currentRoad: videoPageController.currentRoad);
            }
          }
        },
      );
      syncplayController!.onChatMessage.listen(
        (message) {
          if (message['username'] != username) {
            KazumiDialog.showToast(
                message: t.playback.syncplay.chat
                    .replaceFirst('{username}', actorName(message['username']))
                    .replaceFirst(
                        '{message}', (message['message'] ?? '').toString()),
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onPositionChangedMessage.listen(
        (message) {
          final syncplayClientRtt =
              (message['clientRtt'].toDouble() * 1000).toInt();
          state = state.copyWith(syncplayClientRtt: syncplayClientRtt);
          KazumiLogger().log(Level.debug,
              'SyncPlay: position changed by ${message['setBy']}: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] calculatedPosition ${message['calculatedPositon']} position: ${message['position']} doSeek: ${message['doSeek']} paused: ${message['paused']} clientRtt: ${message['clientRtt']} serverRtt: ${message['serverRtt']} fd: ${message['fd']}');
          if (message['paused'] != !state.playing) {
            if (message['paused']) {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: t.playback.syncplay.paused.replaceFirst(
                        '{username}', actorName(message['setBy'])),
                    duration: const Duration(seconds: 3));
                pause(enableSync: false);
              }
            } else {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: t.playback.syncplay.resumed.replaceFirst(
                        '{username}', actorName(message['setBy'])),
                    duration: const Duration(seconds: 3));
                play(enableSync: false);
              }
            }
          }
          if ((((playerPosition.inMilliseconds -
                              (message['calculatedPositon'].toDouble() * 1000)
                                  .toInt())
                          .abs() >
                      1000) ||
                  message['doSeek']) &&
              duration.inMilliseconds > 0) {
            seek(
                Duration(
                    milliseconds:
                        (message['calculatedPositon'].toDouble() * 1000)
                            .toInt()),
                enableSync: false);
          }
        },
      );
      await syncplayController!.joinRoom(room, username);
      state = state.copyWith(syncplayRoom: room);
    } catch (e) {
      KazumiLogger().log(Level.error, 'SyncPlay: error: $e');
    }
  }

  void setSyncPlayCurrentPosition(
      {bool? forceSyncPlaying, double? forceSyncPosition}) {
    if (syncplayController == null) {
      return;
    }
    final playing = forceSyncPlaying ?? state.playing;
    syncplayController!.setPaused(!playing);
    syncplayController!.setPosition((forceSyncPosition ??
        (((state.currentPosition.inMilliseconds - playerPosition.inMilliseconds)
                    .abs() >
                2000)
            ? state.currentPosition.inMilliseconds.toDouble() / 1000
            : playerPosition.inMilliseconds.toDouble() / 1000)));
  }

  Future<void> setSyncPlayPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplayController!.setSyncPlayPlaying(
        "${videoPageController.bangumiItem.id}[${videoPageController.currentEpisode}]",
        10800,
        220514438);
    setSyncPlayCurrentPosition(
        forceSyncPlaying: forceSyncPlaying,
        forceSyncPosition: forceSyncPosition);
    await requestSyncPlaySync();
  }

  Future<void> requestSyncPlaySync({bool? doSeek}) async {
    await syncplayController!.sendSyncPlaySyncRequest(doSeek: doSeek);
  }

  Future<void> sendSyncPlayChatMessage(String message) async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.sendChatMessage(message);
  }

  Future<void> exitSyncPlayRoom() async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.disconnect();
    syncplayController = null;
    state = state.copyWith(syncplayRoom: '', syncplayClientRtt: 0);
  }

  // --- UI state helpers ---

  void resetUiState({required bool danmakuEnabled}) {
    state = state.copyWith(
      danmakuOn: danmakuEnabled,
      lockPanel: false,
      showVideoController: true,
      showSeekTime: false,
      showBrightness: false,
      showVolume: false,
      showPlaySpeed: false,
      brightnessSeeking: false,
      volumeSeeking: false,
      canHidePlayerPanel: true,
    );
  }

  Map<int, List<Danmaku>> get danDanmakus => state.danDanmakus;
  set danDanmakus(Map<int, List<Danmaku>> value) {
    state = state.copyWith(danDanmakus: Map<int, List<Danmaku>>.from(value));
  }

  void clearDanmakus() {
    state = state.copyWith(danDanmakus: {});
  }

  bool get danmakuOn => state.danmakuOn;
  void setDanmakuOn(bool value) {
    state = state.copyWith(danmakuOn: value);
  }

  set danmakuOn(bool value) => setDanmakuOn(value);

  void setDanmakuController(DanmakuController controller) {
    danmakuController = controller;
  }

  bool get lockPanel => state.lockPanel;
  void setLockPanel(bool value) {
    state = state.copyWith(lockPanel: value);
  }

  set lockPanel(bool value) => setLockPanel(value);

  bool get showVideoController => state.showVideoController;
  void setShowVideoController(bool value) {
    state = state.copyWith(showVideoController: value);
  }

  set showVideoController(bool value) => setShowVideoController(value);

  bool get showSeekTime => state.showSeekTime;
  void setShowSeekTime(bool value) {
    state = state.copyWith(showSeekTime: value);
  }

  set showSeekTime(bool value) => setShowSeekTime(value);

  bool get showBrightness => state.showBrightness;
  void setShowBrightness(bool value) {
    state = state.copyWith(showBrightness: value);
  }

  set showBrightness(bool value) => setShowBrightness(value);

  bool get showVolume => state.showVolume;
  void setShowVolume(bool value) {
    state = state.copyWith(showVolume: value);
  }

  set showVolume(bool value) => setShowVolume(value);

  bool get showPlaySpeed => state.showPlaySpeed;
  void setShowPlaySpeed(bool value) {
    state = state.copyWith(showPlaySpeed: value);
  }

  set showPlaySpeed(bool value) => setShowPlaySpeed(value);

  bool get brightnessSeeking => state.brightnessSeeking;
  void setBrightnessSeeking(bool value) {
    state = state.copyWith(brightnessSeeking: value);
  }

  set brightnessSeeking(bool value) => setBrightnessSeeking(value);

  bool get volumeSeeking => state.volumeSeeking;
  void setVolumeSeeking(bool value) {
    state = state.copyWith(volumeSeeking: value);
  }

  set volumeSeeking(bool value) => setVolumeSeeking(value);

  bool get canHidePlayerPanel => state.canHidePlayerPanel;
  void setCanHidePlayerPanel(bool value) {
    state = state.copyWith(canHidePlayerPanel: value);
  }

  set canHidePlayerPanel(bool value) => setCanHidePlayerPanel(value);

  int get superResolutionType => state.superResolutionType;

  String get syncplayRoom => state.syncplayRoom;

  int get syncplayClientRtt => state.syncplayClientRtt;

  double get brightness => state.brightness;
  void setBrightness(double value) {
    state = state.copyWith(brightness: value);
  }

  set brightness(double value) => setBrightness(value);

  int get aspectRatioType => state.aspectRatioType;
  void setAspectRatioType(int type) {
    state = state.copyWith(aspectRatioType: type);
  }

  set aspectRatioType(int value) => setAspectRatioType(value);

  Duration get currentPosition => state.currentPosition;
  set currentPosition(Duration value) {
    state = state.copyWith(currentPosition: value);
  }

  Duration get buffer => state.buffer;
  set buffer(Duration value) {
    state = state.copyWith(buffer: value);
  }

  Duration get duration => state.duration;
  set duration(Duration value) {
    state = state.copyWith(duration: value);
  }

  bool get playing => state.playing;
  set playing(bool value) {
    state = state.copyWith(playing: value);
  }

  bool get isBuffering => state.isBuffering;
  set isBuffering(bool value) {
    state = state.copyWith(isBuffering: value);
  }

  bool get completed => state.completed;
  set completed(bool value) {
    state = state.copyWith(completed: value);
  }

  double get playerSpeed => state.playerSpeed;
  set playerSpeed(double value) {
    unawaited(setPlaybackSpeed(value));
  }

  double get volume => state.volume;
  set volume(double value) {
    unawaited(setVolume(value));
  }

  void updatePlaybackState({
    Duration? position,
    Duration? buffered,
    Duration? total,
    bool? isPlaying,
    bool? buffering,
    bool? isCompleted,
  }) {
    state = state.copyWith(
      currentPosition: position ?? state.currentPosition,
      buffer: buffered ?? state.buffer,
      duration: total ?? state.duration,
      playing: isPlaying ?? state.playing,
      isBuffering: buffering ?? state.isBuffering,
      completed: isCompleted ?? state.completed,
    );
  }
}
