import 'dart:async';
import 'dart:io';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/playback/subtitle_matcher.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:haipee/pages/player/player_item.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'package:haipee/pages/player/local_video_play_args.dart';
export 'package:haipee/pages/player/local_video_play_args.dart';

class LocalPlayerPage extends ConsumerStatefulWidget {
  final LocalVideoPlayArgs? args;

  const LocalPlayerPage({super.key, this.args});

  @override
  ConsumerState<LocalPlayerPage> createState() => _LocalPlayerPageState();
}

class _LocalPlayerPageState extends ConsumerState<LocalPlayerPage> {
  late final PlayerController _playerController;
  late final VideoPageController _videoPageController;
  late final LocalVideoPlayArgs _effectiveArgs;
  final FocusNode _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _playerController = ref.read(playerProvider.notifier);
    _videoPageController = ref.read(videoProvider.notifier);
    _effectiveArgs = widget.args ??
        _playerController.activeLocalVideoArgs ??
        LocalVideoPlayArgs(
          filePath: _playerController.videoUrl,
          title: _playerController.currentTitle.isNotEmpty
              ? _playerController.currentTitle
              : '正在播放媒体',
          isAudio: _playerController.isAudioMode,
          audioUrl: _playerController.activeAudioUrl,
          httpHeaders: _playerController.activeHttpHeaders,
          biliCid: _playerController.activeBiliCid,
          biliBvid: _playerController.activeBiliBvid,
        );

    // 同步注入上下文参数，确保首帧 PlayerItemPanel / SmallestPlayerItemPanel 能立即识别 B站流状态与标题
    _playerController.activeLocalVideoArgs = _effectiveArgs;
    _playerController.currentTitle = _effectiveArgs.title;
    _playerController.isAudioMode = _effectiveArgs.effectiveIsAudio;
    _playerController.activeBiliCid = _effectiveArgs.biliCid;
    _playerController.activeBiliBvid = _effectiveArgs.biliBvid;

    // 启动本地或直链视频播放
    Future.microtask(() async {
      if (!mounted) return;
      if (_effectiveArgs.filePath.isEmpty) {
        return;
      }
      final isHttp = _effectiveArgs.filePath.startsWith('http://') ||
          _effectiveArgs.filePath.startsWith('https://') ||
          _effectiveArgs.filePath.startsWith('bili://');
      if (!isHttp) {
        final file = File(_effectiveArgs.filePath);
        if (!file.existsSync()) {
          HaipeeLogger().log(
            Level.warning,
            '[LocalPlayerPage] 本地视频文件不存在: ${_effectiveArgs.filePath}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('文件不存在: ${_effectiveArgs.filePath}')),
            );
          }
          return;
        }
      }

      _playerController.activeLocalVideoArgs = _effectiveArgs;
      _playerController.currentTitle = _effectiveArgs.title;
      _playerController.isAudioMode = _effectiveArgs.effectiveIsAudio;
      _videoPageController.loading = false;

      // 若当前播放器已在播放同一媒体流（如从迷你播放条重返），保持无缝续播不重置
      final alreadyPlayingSameStream = _playerController.mediaPlayer != null &&
          _playerController.videoUrl.isNotEmpty &&
          (_playerController.videoUrl == _effectiveArgs.filePath ||
              (_effectiveArgs.biliCid != null &&
                  _effectiveArgs.biliCid! > 0 &&
                  _playerController.activeBiliCid == _effectiveArgs.biliCid));
      if (alreadyPlayingSameStream) {
        return;
      }

      await _playerController.init(
        _effectiveArgs.filePath,
        audioUrl: _effectiveArgs.audioUrl,
        httpHeaders: _effectiveArgs.httpHeaders,
        biliCid: _effectiveArgs.biliCid,
        biliBvid: _effectiveArgs.biliBvid,
        biliQuality: _effectiveArgs.biliQuality,
        biliAvailableQualities: _effectiveArgs.biliAvailableQualities,
      );

      if (_effectiveArgs.danmakus != null &&
          _effectiveArgs.danmakus!.isNotEmpty) {
        _playerController.addDanmakus(_effectiveArgs.danmakus!);
      }

      // 智能同名伴飞字幕自动探测与匹配 (SubtitleMatcher)
      if (!isHttp) {
        unawaited(_autoMatchCompanionSubtitle(_effectiveArgs.filePath));
      }
    });
  }

  Future<void> _autoMatchCompanionSubtitle(String videoPath) async {
    try {
      final videoFile = File(videoPath);
      final parentDir = videoFile.parent;
      if (!parentDir.existsSync()) return;

      final videoBaseName = p.basenameWithoutExtension(videoPath).toLowerCase();
      final candidates = <SubtitleMatch>[];

      for (final entity in parentDir.listSync()) {
        if (entity is File) {
          final fmt = SubtitleMatcher.extractFormat(entity.path);
          if (fmt != null &&
              const ['ass', 'srt', 'ssa', 'vtt', 'sub'].contains(fmt)) {
            final subBase =
                p.basenameWithoutExtension(entity.path).toLowerCase();
            double confidence = 0.5;
            if (subBase == videoBaseName) {
              confidence = 1.0;
            } else if (subBase.contains(videoBaseName) ||
                videoBaseName.contains(subBase)) {
              confidence = 0.85;
            }
            String lang = 'zh-CN';
            if (subBase.contains('en') || subBase.contains('eng')) {
              lang = 'en-US';
            }
            if (subBase.contains('ja') || subBase.contains('jpn')) {
              lang = 'ja-JP';
            }
            if (subBase.contains('tc') || subBase.contains('cht')) {
              lang = 'zh-TW';
            }
            candidates.add(SubtitleMatch(
              url: entity.path,
              language: lang,
              confidence: confidence,
              format: fmt,
            ));
          }
        }
      }

      final bestMatch = SubtitleMatcher().selectBestMatch(candidates);
      if (bestMatch != null &&
          await SubtitleMatcher.validateSubtitleFile(bestMatch.url)) {
        await _playerController.loadExternalSubtitle(bestMatch.url);
        HaipeeLogger().log(
          Level.info,
          '[LocalPlayerPage] SubtitleMatcher matched companion subtitle: ${bestMatch.url}',
        );
      }
    } catch (e) {
      HaipeeLogger()
          .log(Level.debug, '[LocalPlayerPage] Auto match subtitle error: $e');
    }
  }

  Future<void> _handleBackPressed(BuildContext ctx) async {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
    if (_videoPageController.isPip) {
      _videoPageController.isPip = false;
      if (Utils.isDesktop()) {
        await Utils.exitDesktopPIPWindow();
      }
      return;
    }
    if (_videoPageController.isFullscreen) {
      _videoPageController.isFullscreen = false;
      await Utils.exitFullScreen();
      return;
    }
    await _playerController.stopAndRelease();
    if (ctx.mounted) {
      // 注意：PopScope(canPop: false) 下严禁调用 maybePop()，否则会再次触发 onPopInvokedWithResult 死循环！
      if (ctx.canPop()) {
        ctx.pop();
      } else {
        ctx.go(Routes.onlineVideo);
      }
    }
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    if (_videoPageController.isPip) {
      unawaited(Utils.exitDesktopPIPWindow());
      _videoPageController.isPip = false;
    }
    if (_videoPageController.isFullscreen) {
      unawaited(Utils.exitFullScreen());
      _videoPageController.isFullscreen = false;
    }
    if (_playerController.activeLocalVideoArgs == _effectiveArgs ||
        _playerController.activeLocalVideoArgs == widget.args) {
      _playerController.activeLocalVideoArgs = null;
    }
    unawaited(_playerController.stop());
    super.dispose();
  }

  void _sendDanmaku(String msg) {
    if (msg.trim().isEmpty) return;
    _playerController.danmakuController.addDanmaku(
      DanmakuContentItem(msg, selfSend: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBackPressed(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          bottom: false,
          child: PlayerItem(
            keyboardFocus: _keyboardFocus,
            onBackPressed: _handleBackPressed,
            openMenu: () {},
            locateEpisode: () {},
            changeEpisode: (ep, {currentRoad = 0, offset = 0}) async {},
            sendDanmaku: _sendDanmaku,
          ),
        ),
      ),
    );
  }
}
