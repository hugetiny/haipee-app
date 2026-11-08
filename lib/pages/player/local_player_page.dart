import 'dart:async';
import 'dart:io';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/playback/subtitle_matcher.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:haipee/pages/player/player_item.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'package:haipee/pages/player/local_video_play_args.dart';
export 'package:haipee/pages/player/local_video_play_args.dart';

class LocalPlayerPage extends ConsumerStatefulWidget {
  final LocalVideoPlayArgs args;

  const LocalPlayerPage({super.key, required this.args});

  @override
  ConsumerState<LocalPlayerPage> createState() => _LocalPlayerPageState();
}

class _LocalPlayerPageState extends ConsumerState<LocalPlayerPage> {
  late final PlayerController _playerController;
  final FocusNode _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _playerController = ref.read(playerProvider.notifier);
    // 同步注入上下文参数，确保首帧 PlayerItemPanel / SmallestPlayerItemPanel 能立即识别 B站流状态与标题
    _playerController.activeLocalVideoArgs = widget.args;
    _playerController.currentTitle = widget.args.title;
    _playerController.isAudioMode = widget.args.effectiveIsAudio;
    _playerController.activeBiliCid = widget.args.biliCid;
    _playerController.activeBiliBvid = widget.args.biliBvid;

    // 启动本地视频播放
    Future.microtask(() async {
      final isHttp = widget.args.filePath.startsWith('http://') ||
          widget.args.filePath.startsWith('https://');
      if (!isHttp) {
        final file = File(widget.args.filePath);
        if (!file.existsSync()) {
          HaipeeLogger().log(
            Level.warning,
            '[LocalPlayerPage] 本地视频文件不存在: ${widget.args.filePath}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('文件不存在: ${widget.args.filePath}')),
            );
          }
          return;
        }
      }

      _playerController.activeLocalVideoArgs = widget.args;
      _playerController.currentTitle = widget.args.title;
      _playerController.isAudioMode = widget.args.effectiveIsAudio;
      _playerController.videoPageController.loading = false;

      await _playerController.init(
        widget.args.filePath,
        audioUrl: widget.args.audioUrl,
        httpHeaders: widget.args.httpHeaders,
        biliCid: widget.args.biliCid,
        biliBvid: widget.args.biliBvid,
        biliQuality: widget.args.biliQuality,
        biliAvailableQualities: widget.args.biliAvailableQualities,
      );

      if (widget.args.danmakus != null && widget.args.danmakus!.isNotEmpty) {
        _playerController.addDanmakus(widget.args.danmakus!);
      }

      // 智能同名伴飞字幕自动探测与匹配 (SubtitleMatcher)
      if (!isHttp) {
        unawaited(_autoMatchCompanionSubtitle(widget.args.filePath));
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
          if (fmt != null && const ['ass', 'srt', 'ssa', 'vtt', 'sub'].contains(fmt)) {
            final subBase = p.basenameWithoutExtension(entity.path).toLowerCase();
            double confidence = 0.5;
            if (subBase == videoBaseName) {
              confidence = 1.0;
            } else if (subBase.contains(videoBaseName) || videoBaseName.contains(subBase)) {
              confidence = 0.85;
            }
            String lang = 'zh-CN';
            if (subBase.contains('en') || subBase.contains('eng')) lang = 'en-US';
            if (subBase.contains('ja') || subBase.contains('jpn')) lang = 'ja-JP';
            if (subBase.contains('tc') || subBase.contains('cht')) lang = 'zh-TW';
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
      if (bestMatch != null && await SubtitleMatcher.validateSubtitleFile(bestMatch.url)) {
        await _playerController.loadExternalSubtitle(bestMatch.url);
        HaipeeLogger().log(
          Level.info,
          '[LocalPlayerPage] SubtitleMatcher matched companion subtitle: ${bestMatch.url}',
        );
      }
    } catch (e) {
      HaipeeLogger().log(Level.debug, '[LocalPlayerPage] Auto match subtitle error: $e');
    }
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    if (_playerController.activeLocalVideoArgs == widget.args) {
      _playerController.activeLocalVideoArgs = null;
    }
    _playerController.stop();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: PlayerItem(
          keyboardFocus: _keyboardFocus,
          onBackPressed: (ctx) => Navigator.of(ctx).maybePop(),
          openMenu: () {},
          locateEpisode: () {},
          changeEpisode: (ep, {currentRoad = 0, offset = 0}) async {},
          sendDanmaku: _sendDanmaku,
        ),
      ),
    );
  }
}
