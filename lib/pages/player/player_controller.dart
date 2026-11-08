import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:haipee/modules/danmaku/danmaku_module.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:haipee/request/damaku.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/shaders/shaders_controller.dart';
import 'package:haipee/utils/syncplay.dart';
import 'package:haipee/utils/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:haipee/pages/player/player_state.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/shaders/providers.dart';
import 'package:haipee/providers/translations_provider.dart';
import 'package:haipee/modules/playback/aniskip_model.dart';
import 'package:haipee/modules/playback/aniskip_service.dart';
import 'package:haipee/modules/playback/media_selector.dart';
import 'package:haipee/pages/player/local_video_play_args.dart';
import 'package:haipee/services/player/player_error_mapper.dart';
import 'package:haipee/modules/source_quality/source_quality_tracker.dart';
import 'package:haipee/modules/bilibili/bilibili_auth_service.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';

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

  int _initGeneration = 0;
  bool _isDisposed = false;

  Box setting = GStorage.setting;
  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = kDebugMode;
  int forwardTime = 80;

  // 播放器实时状态
  bool get playerPlaying => mediaPlayer?.state.playing ?? false;
  bool get playerBuffering => mediaPlayer?.state.buffering ?? false;
  bool get playerCompleted => mediaPlayer?.state.completed ?? false;
  double get playerVolume => mediaPlayer?.state.volume ?? 100.0;
  Duration get playerPosition => mediaPlayer?.state.position ?? Duration.zero;
  Duration get playerBuffer => mediaPlayer?.state.buffer ?? Duration.zero;
  Duration get playerDuration => mediaPlayer?.state.duration ?? Duration.zero;

  // 播放器调试信息订阅
  StreamSubscription<PlayerLog>? playerLogSubscription;
  StreamSubscription<int?>? playerWidthSubscription;
  StreamSubscription<int?>? playerHeightSubscription;
  StreamSubscription<VideoParams>? playerVideoParamsSubscription;
  StreamSubscription<AudioParams>? playerAudioParamsSubscription;
  StreamSubscription<Playlist>? playerPlaylistSubscription;
  StreamSubscription<Track>? playerTracksSubscription;
  StreamSubscription<Tracks>? playerAllTracksSubscription;
  StreamSubscription<double?>? playerAudioBitrateSubscription;
  StreamSubscription<bool>? playerPlayingSubscription;
  StreamSubscription<bool>? playerBufferingSubscription;
  StreamSubscription<Duration>? playerPositionSubscription;

  LocalVideoPlayArgs? activeLocalVideoArgs;
  String currentTitle = '';
  bool isAudioMode = false;
  String? activeAudioUrl;
  Map<String, String>? activeHttpHeaders;
  int? activeBiliCid;
  String? activeBiliBvid;

  /// 检测当前播放流是否为 B站 视频
  bool get isBiliPlayback {
    if (activeBiliCid != null && activeBiliCid! > 0) return true;
    if (activeBiliBvid != null && activeBiliBvid!.isNotEmpty) return true;
    if (activeLocalVideoArgs?.biliCid != null && activeLocalVideoArgs!.biliCid! > 0) return true;
    if (activeLocalVideoArgs?.biliBvid != null && activeLocalVideoArgs!.biliBvid!.isNotEmpty) return true;
    final currentUrl = videoUrl.toLowerCase();
    if (currentUrl.startsWith('bili://') ||
        currentUrl.contains('bilivideo.com') ||
        currentUrl.contains('bilibili.com')) {
      return true;
    }
    final referer =
        (activeHttpHeaders?['Referer'] ?? activeHttpHeaders?['referer'] ?? '')
            .toLowerCase();
    if (referer.contains('bilibili.com')) return true;
    try {
      if (videoPageController.currentPluginOrNull?.isBilibili ?? false) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool get hasActivePlayback =>
      activeLocalVideoArgs != null ||
      (mediaPlayer != null &&
          (mediaPlayer!.state.playing ||
              (!mediaPlayer!.state.completed && mediaPlayer!.state.duration > Duration.zero)));

  void _initializeDependencies() {
    videoPageController = ref.read(videoProvider.notifier);
    shadersController = ref.read(shadersControllerProvider);
  }

  Future<void> init(
    String url, {
    int offset = 0,
    String? audioUrl,
    Map<String, String>? httpHeaders,
    int? biliCid,
    String? biliBvid,
    int? biliQuality,
    List<BiliStreamQuality>? biliAvailableQualities,
  }) async {
    _isDisposed = false;
    final int generation = ++_initGeneration;
    String resolvedUrl = url;
    String? resolvedAudioUrl = audioUrl;
    Map<String, String>? resolvedHeaders = httpHeaders;
    int? resolvedBiliCid = biliCid ?? activeLocalVideoArgs?.biliCid;
    String? resolvedBiliBvid = biliBvid ?? activeLocalVideoArgs?.biliBvid;
    int? resolvedBiliQuality = biliQuality ?? activeLocalVideoArgs?.biliQuality;
    List<BiliStreamQuality>? resolvedBiliQualities =
        biliAvailableQualities ?? activeLocalVideoArgs?.biliAvailableQualities;

    if (url.startsWith('bili://')) {
      final parts = url.substring('bili://'.length).split('/');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        resolvedBiliBvid = parts[0];
      }
      if (parts.length >= 2) {
        resolvedBiliCid = int.tryParse(parts[1]) ?? resolvedBiliCid;
      }
    }

    videoUrl = resolvedUrl;
    activeAudioUrl = resolvedAudioUrl;
    activeHttpHeaders = resolvedHeaders;
    activeBiliCid = resolvedBiliCid;
    activeBiliBvid = resolvedBiliBvid;
    final isBiliStream = isBiliPlayback;
    final defaultUnlocked = BiliAuthService().isLoggedIn
        ? ((BiliAuthService().userNotifier.value?.isVip ?? false)
            ? const [120, 116, 112, 80, 64, 32, 16]
            : const [80, 64, 32, 16])
        : const [32, 16];
    final initialQuality = resolvedBiliQuality ??
        (isBiliStream
            ? (BiliAuthService().isLoggedIn
                ? ((BiliAuthService().userNotifier.value?.isVip ?? false)
                    ? 112
                    : 80)
                : 32)
            : 0);
    final initialQualities = resolvedBiliQualities != null &&
            resolvedBiliQualities.isNotEmpty
        ? resolvedBiliQualities
        : (isBiliStream
            ? BiliQualityHelper.buildQualityList(unlockedIds: defaultUnlocked)
            : const <BiliStreamQuality>[]);

    state = state.copyWith(
      playing: false,
      loading: true,
      isBuffering: true,
      currentPosition: Duration.zero,
      buffer: Duration.zero,
      duration: Duration.zero,
      completed: false,
      danDanmakus: const {},
      biliQuality: initialQuality,
      biliAvailableQualities: initialQualities,
    );
    try {
      await disposeResources(
        disposeSyncPlayController: false,
        markDisposed: false,
      );
    } catch (_) {}
    if (_isDisposed || generation != _initGeneration) return;
    activeBiliCid = resolvedBiliCid;
    activeBiliBvid = resolvedBiliBvid;

    if (url.startsWith('bili://') &&
        resolvedBiliBvid != null &&
        resolvedBiliBvid.isNotEmpty &&
        resolvedBiliCid != null &&
        resolvedBiliCid > 0) {
      final streamInfo = await BilibiliService.getPlayUrl(
        resolvedBiliBvid,
        resolvedBiliCid,
        targetQuality: resolvedBiliQuality,
      );
      if (_isDisposed || generation != _initGeneration) return;
      if (streamInfo != null && streamInfo.videoUrl.isNotEmpty) {
        videoUrl = streamInfo.videoUrl;
        activeAudioUrl = streamInfo.audioUrl;
        activeHttpHeaders = streamInfo.headers;
        state = state.copyWith(
          biliQuality: streamInfo.quality,
          biliAvailableQualities: streamInfo.availableQualities,
        );
      }
    }

    final autoSkip = setting.get(SettingBoxKey.autoSkipOpEd, defaultValue: false) as bool;
    state = state.copyWith(autoSkipOpEd: autoSkip);

    // 原生官方弹幕优先直载 (B站 视频具有确定的 CID，以官方原生弹幕为准，严禁弹弹play跨站模糊盲搜)
    if (resolvedBiliCid != null && resolvedBiliCid > 0) {
      unawaited(loadBiliDanmaku(resolvedBiliCid));
    } else {
      int episodeFromTitle = 0;
      final bgmItem = videoPageController.state.bangumiItem;
      try {
        final roadList = videoPageController.state.roadList;
        final curRoad = videoPageController.state.currentRoad;
        final curEp = videoPageController.state.currentEpisode;
        if (roadList.isNotEmpty &&
            curRoad >= 0 &&
            curRoad < roadList.length &&
            curEp > 0 &&
            curEp <= roadList[curRoad].identifier.length) {
          final currentRoadData = roadList[curRoad];
          final identifier = currentRoadData.identifier[curEp - 1];
          final resolution = MediaSelector.resolve(
            rawIndex: curEp,
            identifier: identifier,
            roadName: currentRoadData.name,
            bangumiTotalEpisodes: bgmItem?.totalEpisodes,
          );
          episodeFromTitle = resolution.danmakuEpisode;
        }
      } catch (e) {
        HaipeeLogger().log(Level.error, '从标题解析集数错误 ${e.toString()}');
      }
      if (episodeFromTitle <= 0) {
        episodeFromTitle = videoPageController.state.currentEpisode > 0
            ? videoPageController.state.currentEpisode
            : 1;
      }

      if (bgmItem != null && bgmItem.id > 0) {
        currentTitle = bgmItem.nameCn.isNotEmpty ? bgmItem.nameCn : bgmItem.name;
        getDanDanmakuByBgmBangumiID(bgmItem.id, episodeFromTitle);
        unawaited(fetchAniSkipIntervals(bgmItem.id, episodeFromTitle));
      } else {
        // 无官方 Bangumi 条目的流媒体与下载视频（包括影视采集CMS、网盘直链、边下边播与本地文件），统一使用标题匹配弹弹play
        final resolvedTitle = currentTitle.isNotEmpty
            ? currentTitle
            : (activeLocalVideoArgs?.title.isNotEmpty == true
                ? activeLocalVideoArgs!.title
                : (videoPageController.state.title.isNotEmpty
                    ? videoPageController.state.title
                    : videoPageController.bangumiItem.name));
        currentTitle = resolvedTitle;
        if (currentTitle.isNotEmpty && currentTitle != '未知视频') {
          unawaited(getDanDanmakuByTitle(currentTitle, episodeFromTitle));
        }
      }
    }
    if (_isDisposed || generation != _initGeneration) return;
    final createdPlayer = await createVideoController(offset: offset);
    if (_isDisposed || generation != _initGeneration || createdPlayer == null) {
      return;
    }
    mediaPlayer ??= createdPlayer;
    final superResolutionType = (setting.get(
            SettingBoxKey.defaultSuperResolutionType,
            defaultValue: 1) as num)
        .toInt();
    shadersController.superResolutionType = superResolutionType;
    final playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    final aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
    state = state.copyWith(
      superResolutionType: superResolutionType,
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
    HaipeeLogger().log(Level.info, 'VideoURL初始化完成');
    state = state.copyWith(
      loading: false,
      isBuffering: mediaPlayer?.state.buffering ?? false,
    );
    videoPageController.loading = false;
    if (syncplayController?.isConnected ?? false) {
      final bgmId = videoPageController.bangumiItem.id;
      if (syncplayController!.currentFileName !=
          "$bgmId[${videoPageController.state.currentEpisode}]") {
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
        HaipeeLogger().simpleLog(event.toString());
      }
    });
    await playerWidthSubscription?.cancel();
    playerWidthSubscription = mediaPlayer!.stream.width.listen((event) {
      final width = event ?? 0;
      state = state.copyWith(
        playerWidth: width,
        loading: width > 0 ? false : state.loading,
      );
      if (width > 0) {
        videoPageController.loading = false;
        if (state.superResolutionType != 1) {
          unawaited(setShader(state.superResolutionType));
        }
        unawaited(syncVideoQualityMetrics());
      }
    });
    await playerHeightSubscription?.cancel();
    playerHeightSubscription = mediaPlayer!.stream.height.listen((event) {
      final height = event ?? 0;
      state = state.copyWith(
        playerHeight: height,
        loading: height > 0 ? false : state.loading,
      );
      if (height > 0) {
        videoPageController.loading = false;
        unawaited(syncVideoQualityMetrics());
      }
    });
    await playerVideoParamsSubscription?.cancel();
    playerVideoParamsSubscription =
        mediaPlayer!.stream.videoParams.listen((event) {
      state = state.copyWith(playerVideoParams: event.toString());
      unawaited(syncVideoQualityMetrics());
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
    await playerAllTracksSubscription?.cancel();
    playerAllTracksSubscription = mediaPlayer!.stream.tracks.listen((tracks) {
      state = state.copyWith(playerTracks: tracks);
    });
    await playerTracksSubscription?.cancel();
    playerTracksSubscription = mediaPlayer!.stream.track.listen((event) {
      state = state.copyWith(
        currentAudioTrack: event.audio,
        currentSubtitleTrack: event.subtitle,
        playerAudioTracks: event.audio.toString(),
        playerVideoTracks: event.video.toString(),
      );
    });
    await playerAudioBitrateSubscription?.cancel();
    playerAudioBitrateSubscription =
        mediaPlayer!.stream.audioBitrate.listen((event) {
      state = state.copyWith(playerAudioBitrate: event.toString());
    });
    await playerPlayingSubscription?.cancel();
    playerPlayingSubscription = mediaPlayer!.stream.playing.listen((isPlaying) {
      state = state.copyWith(playing: isPlaying);
      if (isPlaying) {
        state = state.copyWith(
          loading: false,
          isBuffering: mediaPlayer?.state.buffering ?? false,
        );
        videoPageController.loading = false;
        unawaited(syncVideoQualityMetrics());
      }
    });
    await playerBufferingSubscription?.cancel();
    playerBufferingSubscription = mediaPlayer!.stream.buffering.listen((isBuffering) {
      state = state.copyWith(isBuffering: isBuffering);
      if (!isBuffering && (mediaPlayer?.state.playing ?? false)) {
        state = state.copyWith(loading: false);
        videoPageController.loading = false;
        unawaited(syncVideoQualityMetrics());
      }
    });
    await playerPositionSubscription?.cancel();
    playerPositionSubscription = mediaPlayer!.stream.position.listen((pos) {
      state = state.copyWith(currentPosition: pos);
      if (pos > Duration.zero && state.loading) {
        state = state.copyWith(loading: false);
        videoPageController.loading = false;
      }
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
    await playerAllTracksSubscription?.cancel();
    await playerAudioBitrateSubscription?.cancel();
    await playerPlayingSubscription?.cancel();
    await playerBufferingSubscription?.cancel();
    await playerPositionSubscription?.cancel();
  }

  Future<Player?> createVideoController({int offset = 0}) async {
    final int generation = _initGeneration;
    if (_isDisposed) return null;
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
    final plugin = videoPageController.currentPluginOrNull;
    if (plugin == null || plugin.userAgent.isEmpty) {
      userAgent = Utils.getRandomUA();
    } else {
      userAgent = plugin.userAgent;
    }
    String referer = plugin?.referer ?? '';
    var httpHeaders = {
      'user-agent': userAgent,
      if (referer.isNotEmpty) 'referer': referer,
      if (activeHttpHeaders != null) ...activeHttpHeaders!,
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
    if (activeHttpHeaders != null && activeHttpHeaders!.isNotEmpty) {
      final headerString = activeHttpHeaders!.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\r\n');
      await pp.setProperty('http-header-fields', headerString);
      final ref = activeHttpHeaders!['referer'] ?? activeHttpHeaders!['Referer'];
      if (ref != null) {
        await pp.setProperty('referrer', ref);
      }
      final ua = activeHttpHeaders!['user-agent'] ?? activeHttpHeaders!['User-Agent'];
      if (ua != null) {
        await pp.setProperty('user-agent', ua);
      }
    }
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    await pp.setProperty("embeddedfonts", "yes");
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
    state = state.copyWith(superResolutionType: state.superResolutionType);
    try {
      if (_isDisposed || generation != _initGeneration || mediaPlayer == null) {
        return null;
      }
      if (mediaPlayer?.platform is NativePlayer &&
          (mediaPlayer!.platform as NativePlayer).disposed) {
        return null;
      }
      mediaPlayer!.setPlaylistMode(PlaylistMode.none);
    } catch (e) {
      if (e is AssertionError) {
        HaipeeLogger().log(
            Level.warning, 'Player disposed before setPlaylistMode: $e');
        return null;
      }
      rethrow;
    }

    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: false);
    mediaPlayer!.stream.error.listen((event) {
      HaipeeLogger().log(
          Level.error, 'Player intent error: ${event.toString()} $videoUrl');

      // Ignore transient network read interruptions on segments/advertisements that mpv recovers from
      if (PlayerErrorMapper.isTransientNetworkError(event)) {
        return;
      }

      final actionableMessage = PlayerErrorMapper.toActionableMessage(
        event,
        isBuffering: playerBuffering,
      );
      if (actionableMessage != null) {
        HaipeeDialog.showToast(
          message: actionableMessage,
          showActionButton: true,
        );
      } else if (showPlayerError) {
        final t = ref.read(translationsProvider);
        final details = '${event.toString()} $videoUrl';
        HaipeeDialog.showToast(
          message:
               t.playback.toast.internalError.replaceFirst('{details}', details),
          duration: const Duration(seconds: 5),
          showActionButton: true,
        );
      }
    });

    if (state.superResolutionType != 1) {
      await setShader(state.superResolutionType);
      if (_isDisposed || generation != _initGeneration) return null;
    }

    try {
      if (_isDisposed || generation != _initGeneration || mediaPlayer == null) {
        return null;
      }
      if (mediaPlayer?.platform is NativePlayer &&
          (mediaPlayer!.platform as NativePlayer).disposed) {
        return null;
      }
      await mediaPlayer!.open(
        Media(videoUrl,
            start: Duration(seconds: offset), httpHeaders: httpHeaders),
        play: autoPlay,
      );
    } catch (e) {
      if (e is AssertionError) {
        HaipeeLogger().log(Level.warning, 'Player disposed during open: $e');
        return null;
      }
      rethrow;
    }

    // B站 DASH 音画分离双流挂载：利用 mpv 原生双流能力挂载独立音频流，零损耗加载
    if (activeAudioUrl != null && activeAudioUrl!.isNotEmpty) {
      try {
        await pp.command(['audio-add', activeAudioUrl!, 'select']);
        HaipeeLogger().log(Level.info, '成功通过 mpv audio-add 挂载 DASH 独立音频流');
      } catch (e) {
        HaipeeLogger().log(Level.warning, '挂载 DASH 独立音频流失败: $e');
      }
    }

    return mediaPlayer!;
  }

  Future<void> loadBiliDanmaku(int cid) async {
    try {
      state = state.copyWith(danDanmakus: {});
      final danmakus = await BilibiliService.getDanmaku(cid);
      if (danmakus.isNotEmpty) {
        addDanmakus(danmakus);
        HaipeeLogger().log(Level.info, '成功加载 B站 原生弹幕 ${danmakus.length} 条 (cid=$cid)');
      } else {
        HaipeeLogger().log(Level.info, 'B站 该视频无原生弹幕 (cid=$cid)');
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '加载 B站 弹幕失败 cid=$cid: $e');
    }
  }

  /// 切换 B站 播放清晰度档位 (无缝保持当前播放进度)
  Future<void> switchBiliQuality({int? targetQuality}) async {
    final biliCid = activeBiliCid ?? activeLocalVideoArgs?.biliCid;
    final biliBvid = activeBiliBvid ?? activeLocalVideoArgs?.biliBvid;
    if (biliCid == null || biliBvid == null || biliBvid.isEmpty) return;

    try {
      final currentPos = playerPosition > Duration.zero
          ? playerPosition
          : state.currentPosition;
      final playUrl = await BilibiliService.getPlayUrl(
        biliBvid,
        biliCid,
        targetQuality: targetQuality,
      );
      if (playUrl == null || playUrl.videoUrl.isEmpty) {
        HaipeeDialog.showToast(message: '切换画质失败，请稍后重试');
        return;
      }

      if (activeLocalVideoArgs != null) {
        activeLocalVideoArgs = LocalVideoPlayArgs(
          filePath: playUrl.videoUrl,
          title: activeLocalVideoArgs!.title,
          bangumiId: activeLocalVideoArgs!.bangumiId,
          episode: activeLocalVideoArgs!.episode,
          isAudio: activeLocalVideoArgs!.isAudio,
          streamId: activeLocalVideoArgs!.streamId,
          torrentId: activeLocalVideoArgs!.torrentId,
          audioUrl: playUrl.audioUrl,
          httpHeaders: playUrl.headers,
          biliCid: biliCid,
          biliBvid: biliBvid,
          biliQuality: playUrl.quality,
          biliAvailableQualities: playUrl.availableQualities,
          danmakus: activeLocalVideoArgs!.danmakus,
        );
      }

      await init(
        playUrl.videoUrl,
        offset: currentPos.inSeconds,
        audioUrl: playUrl.audioUrl,
        httpHeaders: playUrl.headers,
        biliCid: biliCid,
        biliBvid: biliBvid,
        biliQuality: playUrl.quality,
        biliAvailableQualities: playUrl.availableQualities,
      );
      if (currentPos > Duration.zero) {
        await seek(currentPos);
      }
      await play();
      if (targetQuality != null && playUrl.quality < targetQuality) {
        HaipeeDialog.showToast(
          message:
              '目标画质受限，已为您切换至最高可用画质: ${BiliQualityHelper.getLabel(playUrl.quality)}',
        );
      } else {
        HaipeeDialog.showToast(
          message: '已切换至 ${BiliQualityHelper.getLabel(playUrl.quality)}',
        );
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '切换 B站 画质失败: $e');
    }
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    try {
      await shadersController.ensureInitialized();
      if (mediaPlayer != null && mediaPlayer!.platform is NativePlayer) {
        var pp = mediaPlayer!.platform as NativePlayer;
        await pp.waitForPlayerInitialization;
        await pp.waitForVideoControllerInitializationIfAttached;
        if (type == 2) {
          final shaderPath = Utils.buildShadersAbsolutePath(
              shadersController.shadersDirectory.path, mpvAnime4KShadersLite);
          await pp.setProperty('glsl-shaders', shaderPath);
          await pp.command([
            'change-list',
            'glsl-shaders',
            'set',
            shaderPath,
          ]);
        } else if (type == 3) {
          final shaderPath = Utils.buildShadersAbsolutePath(
              shadersController.shadersDirectory.path, mpvAnime4KShaders);
          await pp.setProperty('glsl-shaders', shaderPath);
          await pp.command([
            'change-list',
            'glsl-shaders',
            'set',
            shaderPath,
          ]);
        } else {
          await pp.setProperty('glsl-shaders', '');
          await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
        }
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, 'Failed to apply shader type $type: $e');
    } finally {
      shadersController.superResolutionType = type;
      await setting.put(SettingBoxKey.defaultSuperResolutionType, type);
      state = state.copyWith(superResolutionType: type);
    }
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    state = state.copyWith(playerSpeed: playerSpeed);
    try {
      mediaPlayer!.setRate(playerSpeed);
    } catch (e) {
      HaipeeLogger().log(Level.error, '设置播放速度失败 ${e.toString()}');
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

  Future<void> disposeResources({
    bool disposeSyncPlayController = true,
    bool markDisposed = true,
  }) async {
    if (markDisposed) {
      _isDisposed = true;
      _initGeneration++;
    }
    if (disposeSyncPlayController) {
      activeBiliCid = null;
      activeBiliBvid = null;
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
    activeBiliCid = null;
    activeBiliBvid = null;
    try {
      await mediaPlayer?.stop();
      if (updateState) {
        state = state.copyWith(
          loading: true,
          aniSkipIntervals: const [],
          currentAniSkipInterval: null,
          subtitleDelay: 0.0,
          danDanmakus: const {},
        );
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
    final bool enableDanDan =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true) as bool;
    if (!enableDanDan) {
      return;
    }
    HaipeeLogger().log(Level.info, '尝试获取弹幕 [BgmBangumiID] $bgmBangumiID');
    try {
      state = state.copyWith(danDanmakus: {});
      bangumiID =
          await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID, silent: true);
      if (bangumiID > 0) {
        var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode, silent: true);
        addDanmakus(res);
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByTitle(String title, int episode) async {
    final bool enableDanDan =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true) as bool;
    if (!enableDanDan) {
      return;
    }
    HaipeeLogger().log(Level.info, '尝试根据标题获取弹幕: $title, 集数: $episode');
    try {
      state = state.copyWith(danDanmakus: {});
      final bId = await DanmakuRequest.getBangumiIDByTitle(title, silent: true);
      if (bId > 0) {
        bangumiID = bId;
        final res = await DanmakuRequest.getDanDanmaku(bId, episode, silent: true);
        addDanmakus(res);
        unawaited(fetchAniSkipIntervals(bId, episode));
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '根据标题获取弹幕错误: ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    if (episodeID <= 0) return;
    HaipeeLogger().log(Level.info, '尝试获取弹幕 $episodeID');
    try {
      state = state.copyWith(danDanmakus: {});
      var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID, silent: true);
      addDanmakus(res);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
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
        HaipeeDialog.dismiss();
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.launchFailed,
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchURLWithReferer(videoUrl, referer)) {
        HaipeeDialog.dismiss();
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.launchFailed,
        );
      }
    } else if (Platform.isLinux && referer.isEmpty) {
      HaipeeDialog.dismiss();
      if (await canLaunchUrlString(videoUrl)) {
        launchUrlString(videoUrl);
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.launching,
        );
      } else {
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.unavailable,
        );
      }
    } else {
      if (referer.isEmpty) {
        HaipeeDialog.showToast(
          message: t.playback.externalPlayer.unsupportedDevice,
        );
      } else {
        HaipeeDialog.showToast(
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
      HaipeeDialog.showToast(
        message: t.playback.syncplay.invalidEndpoint
            .replaceFirst('{endpoint}', syncPlayEndPoint),
      );
      HaipeeLogger().log(Level.error, 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint');
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
          // HaipeeLogger().log(Level.debug, 'SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          HaipeeLogger().log(Level.error, 'SyncPlay: error: ${error.message}');
          if (error is SyncplayConnectionException) {
            exitSyncPlayRoom();
            HaipeeDialog.showToast(
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
              HaipeeDialog.showToast(
                  message: t.playback.syncplay.alone,
                  duration: const Duration(seconds: 5));
              setSyncPlayPlayingBangumi();
            } else {
              HaipeeDialog.showToast(
                  message: t.playback.syncplay.followUser
                      .replaceFirst('{username}', actorName(rawUser)));
            }
          }
          if (message['type'] == 'left') {
            HaipeeDialog.showToast(
                message: t.playback.syncplay.userLeft
                    .replaceFirst('{username}', actorName(message['username'])),
                duration: const Duration(seconds: 5));
          }
          if (message['type'] == 'joined') {
            HaipeeDialog.showToast(
                message: t.playback.syncplay.userJoined
                    .replaceFirst('{username}', actorName(message['username'])),
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onFileChangedMessage.listen(
        (message) {
          HaipeeLogger().log(Level.info,
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          RegExp regExp = RegExp(r'(\d+)\[(\d+)\]');
          Match? match = regExp.firstMatch(message['name']);
          if (match != null) {
            int bangumiID = int.tryParse(match.group(1) ?? '0') ?? 0;
            int episode = int.tryParse(match.group(2) ?? '0') ?? 0;
            if (bangumiID != 0 &&
                episode != 0 &&
                episode != videoPageController.currentEpisode) {
              HaipeeDialog.showToast(
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
            HaipeeDialog.showToast(
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
          HaipeeLogger().log(Level.debug,
              'SyncPlay: position changed by ${message['setBy']}: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] calculatedPosition ${message['calculatedPositon']} position: ${message['position']} doSeek: ${message['doSeek']} paused: ${message['paused']} clientRtt: ${message['clientRtt']} serverRtt: ${message['serverRtt']} fd: ${message['fd']}');
          if (message['paused'] != !state.playing) {
            if (message['paused']) {
              if (message['position'] != 0) {
                HaipeeDialog.showToast(
                    message: t.playback.syncplay.paused.replaceFirst(
                        '{username}', actorName(message['setBy'])),
                    duration: const Duration(seconds: 3));
                pause(enableSync: false);
              }
            } else {
              if (message['position'] != 0) {
                HaipeeDialog.showToast(
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
      HaipeeLogger().log(Level.error, 'SyncPlay: error: $e');
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
    _checkAniSkip(value);
  }

  Future<void> setAudioTrack(dynamic track) async {
    final AudioTrack? audioTrack = track is Track ? track.audio : (track is AudioTrack ? track : null);
    if (audioTrack == null) return;
    state = state.copyWith(currentAudioTrack: audioTrack);
    try {
      await mediaPlayer?.setAudioTrack(audioTrack);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '设置音频轨道失败: $e');
    }
  }

  Future<void> setSubtitleTrack(dynamic track) async {
    final SubtitleTrack? subtitleTrack = track is Track ? track.subtitle : (track is SubtitleTrack ? track : null);
    if (subtitleTrack == null) return;
    state = state.copyWith(currentSubtitleTrack: subtitleTrack);
    try {
      await mediaPlayer?.setSubtitleTrack(subtitleTrack);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '设置字幕轨道失败: $e');
    }
  }

  Future<void> setSubtitleDelay(double seconds) async {
    state = state.copyWith(subtitleDelay: seconds);
    try {
      final pp = mediaPlayer?.platform as NativePlayer?;
      if (pp != null) {
        await pp.setProperty("sub-delay", seconds.toString());
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '设置字幕延迟失败: $e');
    }
  }

  Future<void> loadExternalSubtitle(String path) async {
    try {
      final track = SubtitleTrack.uri(path, title: path.split(Platform.pathSeparator).last);
      await setSubtitleTrack(track);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '加载外部字幕失败: $e');
    }
  }

  void _checkAniSkip(Duration position) {
    if (state.aniSkipIntervals.isEmpty) return;
    final posSec = position.inMilliseconds / 1000.0;
    AniSkipInterval? activeInterval;
    for (final interval in state.aniSkipIntervals) {
      if (interval.containsSeconds(posSec)) {
        activeInterval = interval;
        break;
      }
    }
    if (activeInterval != state.currentAniSkipInterval) {
      state = state.copyWith(currentAniSkipInterval: activeInterval);
      if (activeInterval != null && state.autoSkipOpEd) {
        HaipeeLogger().log(
          Level.info,
          '[AniSkip] 自动跳过 ${activeInterval.typeLabel} -> ${activeInterval.endTime}s',
        );
        unawaited(seek(Duration(milliseconds: (activeInterval.endTime * 1000).toInt())));
      }
    }
  }

  Future<void> skipCurrentInterval() async {
    final interval = state.currentAniSkipInterval;
    if (interval != null) {
      HaipeeLogger().log(
        Level.info,
        '[AniSkip] 用户点击跳过 ${interval.typeLabel} -> ${interval.endTime}s',
      );
      await seek(Duration(milliseconds: (interval.endTime * 1000).toInt()));
      state = state.copyWith(currentAniSkipInterval: null);
    }
  }

  void setAutoSkipOpEd(bool value) {
    state = state.copyWith(autoSkipOpEd: value);
    setting.put(SettingBoxKey.autoSkipOpEd, value);
  }

  Future<void> fetchAniSkipIntervals(int bangumiId, int episode) async {
    if (bangumiId <= 0 || episode <= 0) {
      state = state.copyWith(aniSkipIntervals: const [], currentAniSkipInterval: null);
      return;
    }
    try {
      final intervals = await AniSkipService.instance.getSkipTimes(
        bangumiId: bangumiId,
        episode: episode,
      );
      state = state.copyWith(
        aniSkipIntervals: intervals,
        currentAniSkipInterval: null,
      );
      HaipeeLogger().log(
        Level.info,
        '[AniSkip] 已拉取条目 $bangumiId 第 $episode 集跳过区间: ${intervals.length} 个',
      );
    } catch (e) {
      HaipeeLogger().log(Level.warning, '[AniSkip] 获取跳过区间失败: $e');
    }
  }

  Future<void> stopAndRelease() async {
    try {
      await mediaPlayer?.stop();
    } catch (_) {}
    await disposeResources();
    state = const PlayerState();
    activeLocalVideoArgs = null;
    currentTitle = '';
    isAudioMode = false;
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

  /// 周期性或状态变化时同步视频流分辨率、码率、帧率与编码格式至清晰度追踪器
  Future<void> syncVideoQualityMetrics() async {
    try {
      final width = state.playerWidth;
      final height = state.playerHeight;
      if (width <= 0 && height <= 0) return;

      double vBitrate = state.playerVideoBitrate;
      double dBitrate = state.demuxBitrate;
      String codec = state.videoCodec;
      double fps = state.videoFps;

      final pp = mediaPlayer?.platform as NativePlayer?;
      if (pp != null) {
        if (vBitrate <= 0) {
          try {
            final vb = await pp.getProperty('video-bitrate');
            if (vb.isNotEmpty) {
              vBitrate = double.tryParse(vb) ?? 0.0;
            }
          } catch (_) {}
        }
        if (dBitrate <= 0) {
          try {
            final db = await pp.getProperty('demux-bitrate');
            if (db.isNotEmpty) {
              dBitrate = double.tryParse(db) ?? 0.0;
            }
          } catch (_) {}
        }
        if (codec.isEmpty) {
          try {
            codec = await pp.getProperty('video-format');
          } catch (_) {}
        }
        if (fps <= 0) {
          try {
            final fpsVal = await pp.getProperty('estimated-vf-fps');
            if (fpsVal.isNotEmpty) {
              fps = double.tryParse(fpsVal) ?? 0.0;
            }
          } catch (_) {}
        }
      }

      if (vBitrate > 0 || dBitrate > 0 || codec.isNotEmpty || fps > 0) {
        state = state.copyWith(
          playerVideoBitrate:
              vBitrate > 0 ? vBitrate : state.playerVideoBitrate,
          demuxBitrate: dBitrate > 0 ? dBitrate : state.demuxBitrate,
          videoCodec: codec.isNotEmpty ? codec : state.videoCodec,
          videoFps: fps > 0 ? fps : state.videoFps,
        );
      }

      final bItem = videoPageController.bangumiItemOrNull;
      final pName = videoPageController.currentPluginOrNull?.name;
      final pSrc = videoPageController.src;

      if (bItem != null &&
          pName != null &&
          pName.isNotEmpty &&
          pSrc.isNotEmpty) {
        await SourceQualityTracker.recordQuality(
          bangumiId: bItem.id,
          pluginName: pName,
          src: pSrc,
          width: width,
          height: height,
          videoBitrate: vBitrate,
          demuxBitrate: dBitrate,
          codec: codec,
          fps: fps,
        );
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '同步视频清晰度指标出错: $e');
    }
  }
}
