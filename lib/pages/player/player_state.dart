import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/playback/aniskip_model.dart';
import 'package:media_kit/media_kit.dart';

const Object _sentinel = Object();

class PlayerState {
  // 弹幕控制
  final Map<int, List<Danmaku>> danDanmakus;
  final bool danmakuOn;

  // 一起看控制器
  final String syncplayRoom;
  final int syncplayClientRtt;

  /// 视频比例类型
  /// 1. AUTO
  /// 2. COVER
  /// 3. FILL
  final int aspectRatioType;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K
  final int superResolutionType;

  // 视频音量/亮度
  final double volume;
  final double brightness;

  // 播放器界面控制
  final bool lockPanel;
  final bool showVideoController;
  final bool showSeekTime;
  final bool showBrightness;
  final bool showVolume;
  final bool showPlaySpeed;
  final bool brightnessSeeking;
  final bool volumeSeeking;
  final bool canHidePlayerPanel;

  // 播放器面板状态
  final bool loading;
  final bool playing;
  final bool isBuffering;
  final bool completed;
  final Duration currentPosition;
  final Duration buffer;
  final Duration duration;
  final double playerSpeed;

  // 播放器调试信息
  final List<String> playerLog;
  final int playerWidth;
  final int playerHeight;
  final String playerVideoParams;
  final String playerAudioParams;
  final String playerPlaylist;
  final String playerAudioTracks;
  final String playerVideoTracks;
  final String playerAudioBitrate;
  final double playerVideoBitrate;
  final double demuxBitrate;
  final String videoCodec;
  final double videoFps;

  // 轨控制与字幕延迟 (Audio & Subtitle Track Controller)
  final Tracks? playerTracks;
  final AudioTrack? currentAudioTrack;
  final SubtitleTrack? currentSubtitleTrack;
  final double subtitleDelay;

  // AniSkip 智能跳过片头片尾 (AniSkip System)
  final List<AniSkipInterval> aniSkipIntervals;
  final AniSkipInterval? currentAniSkipInterval;
  final bool autoSkipOpEd;

  const PlayerState({
    this.danDanmakus = const {},
    this.danmakuOn = false,
    this.syncplayRoom = '',
    this.syncplayClientRtt = 0,
    this.aspectRatioType = 1,
    this.superResolutionType = 1,
    this.volume = -1,
    this.brightness = 0,
    this.lockPanel = false,
    this.showVideoController = true,
    this.showSeekTime = false,
    this.showBrightness = false,
    this.showVolume = false,
    this.showPlaySpeed = false,
    this.brightnessSeeking = false,
    this.volumeSeeking = false,
    this.canHidePlayerPanel = true,
    this.loading = true,
    this.playing = false,
    this.isBuffering = true,
    this.completed = false,
    this.currentPosition = Duration.zero,
    this.buffer = Duration.zero,
    this.duration = Duration.zero,
    this.playerSpeed = 1.0,
    this.playerLog = const [],
    this.playerWidth = 0,
    this.playerHeight = 0,
    this.playerVideoParams = '',
    this.playerAudioParams = '',
    this.playerPlaylist = '',
    this.playerAudioTracks = '',
    this.playerVideoTracks = '',
    this.playerAudioBitrate = '',
    this.playerVideoBitrate = 0.0,
    this.demuxBitrate = 0.0,
    this.videoCodec = '',
    this.videoFps = 0.0,
    this.playerTracks,
    this.currentAudioTrack,
    this.currentSubtitleTrack,
    this.subtitleDelay = 0.0,
    this.aniSkipIntervals = const [],
    this.currentAniSkipInterval,
    this.autoSkipOpEd = false,
  });

  PlayerState copyWith({
    Map<int, List<Danmaku>>? danDanmakus,
    bool? danmakuOn,
    String? syncplayRoom,
    int? syncplayClientRtt,
    int? aspectRatioType,
    int? superResolutionType,
    double? volume,
    double? brightness,
    bool? lockPanel,
    bool? showVideoController,
    bool? showSeekTime,
    bool? showBrightness,
    bool? showVolume,
    bool? showPlaySpeed,
    bool? brightnessSeeking,
    bool? volumeSeeking,
    bool? canHidePlayerPanel,
    bool? loading,
    bool? playing,
    bool? isBuffering,
    bool? completed,
    Duration? currentPosition,
    Duration? buffer,
    Duration? duration,
    double? playerSpeed,
    List<String>? playerLog,
    int? playerWidth,
    int? playerHeight,
    String? playerVideoParams,
    String? playerAudioParams,
    String? playerPlaylist,
    String? playerAudioTracks,
    String? playerVideoTracks,
    String? playerAudioBitrate,
    double? playerVideoBitrate,
    double? demuxBitrate,
    String? videoCodec,
    double? videoFps,
    Object? playerTracks = _sentinel,
    Object? currentAudioTrack = _sentinel,
    Object? currentSubtitleTrack = _sentinel,
    double? subtitleDelay,
    List<AniSkipInterval>? aniSkipIntervals,
    Object? currentAniSkipInterval = _sentinel,
    bool? autoSkipOpEd,
  }) {
    return PlayerState(
      danDanmakus: danDanmakus ?? this.danDanmakus,
      danmakuOn: danmakuOn ?? this.danmakuOn,
      syncplayRoom: syncplayRoom ?? this.syncplayRoom,
      syncplayClientRtt: syncplayClientRtt ?? this.syncplayClientRtt,
      aspectRatioType: aspectRatioType ?? this.aspectRatioType,
      superResolutionType: superResolutionType ?? this.superResolutionType,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
      lockPanel: lockPanel ?? this.lockPanel,
      showVideoController: showVideoController ?? this.showVideoController,
      showSeekTime: showSeekTime ?? this.showSeekTime,
      showBrightness: showBrightness ?? this.showBrightness,
      showVolume: showVolume ?? this.showVolume,
      showPlaySpeed: showPlaySpeed ?? this.showPlaySpeed,
      brightnessSeeking: brightnessSeeking ?? this.brightnessSeeking,
      volumeSeeking: volumeSeeking ?? this.volumeSeeking,
      canHidePlayerPanel: canHidePlayerPanel ?? this.canHidePlayerPanel,
      loading: loading ?? this.loading,
      playing: playing ?? this.playing,
      isBuffering: isBuffering ?? this.isBuffering,
      completed: completed ?? this.completed,
      currentPosition: currentPosition ?? this.currentPosition,
      buffer: buffer ?? this.buffer,
      duration: duration ?? this.duration,
      playerSpeed: playerSpeed ?? this.playerSpeed,
      playerLog: playerLog ?? this.playerLog,
      playerWidth: playerWidth ?? this.playerWidth,
      playerHeight: playerHeight ?? this.playerHeight,
      playerVideoParams: playerVideoParams ?? this.playerVideoParams,
      playerAudioParams: playerAudioParams ?? this.playerAudioParams,
      playerPlaylist: playerPlaylist ?? this.playerPlaylist,
      playerAudioTracks: playerAudioTracks ?? this.playerAudioTracks,
      playerVideoTracks: playerVideoTracks ?? this.playerVideoTracks,
      playerAudioBitrate: playerAudioBitrate ?? this.playerAudioBitrate,
      playerVideoBitrate: playerVideoBitrate ?? this.playerVideoBitrate,
      demuxBitrate: demuxBitrate ?? this.demuxBitrate,
      videoCodec: videoCodec ?? this.videoCodec,
      videoFps: videoFps ?? this.videoFps,
      playerTracks: identical(playerTracks, _sentinel)
          ? this.playerTracks
          : (playerTracks as Tracks?),
      currentAudioTrack: identical(currentAudioTrack, _sentinel)
          ? this.currentAudioTrack
          : (currentAudioTrack as AudioTrack?),
      currentSubtitleTrack: identical(currentSubtitleTrack, _sentinel)
          ? this.currentSubtitleTrack
          : (currentSubtitleTrack as SubtitleTrack?),
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      aniSkipIntervals: aniSkipIntervals ?? this.aniSkipIntervals,
      currentAniSkipInterval: identical(currentAniSkipInterval, _sentinel)
          ? this.currentAniSkipInterval
          : (currentAniSkipInterval as AniSkipInterval?),
      autoSkipOpEd: autoSkipOpEd ?? this.autoSkipOpEd,
    );
  }
}
