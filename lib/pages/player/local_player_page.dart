import 'dart:io';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class LocalVideoPlayArgs {
  final String filePath;
  final String title;
  final String? bangumiId;
  final int? episode;

  const LocalVideoPlayArgs({
    required this.filePath,
    required this.title,
    this.bangumiId,
    this.episode,
  });
}

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

    // 启动本地视频播放
    Future.microtask(() async {
      final file = File(widget.args.filePath);
      if (!file.existsSync()) {
        KazumiLogger().log(
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

      await _playerController.init(widget.args.filePath);

      // 自动加载弹幕
      final ep = widget.args.episode ?? 1;
      final bgmId = int.tryParse(widget.args.bangumiId ?? '');
      if (bgmId != null && bgmId > 0) {
        await _playerController.getDanDanmakuByBgmBangumiID(bgmId, ep);
      } else if (widget.args.title.isNotEmpty) {
        await _playerController.getDanDanmakuByTitle(widget.args.title, ep);
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
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
        child: Stack(
          children: [
            // 播放器本体
            Center(
              child: PlayerItem(
                keyboardFocus: _keyboardFocus,
                onBackPressed: (ctx) => Navigator.of(ctx).maybePop(),
                openMenu: () {},
                locateEpisode: () {},
                changeEpisode: (ep, {currentRoad = 0, offset = 0}) async {},
                sendDanmaku: _sendDanmaku,
              ),
            ),

            // 顶部返回按钮与标题
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.args.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
