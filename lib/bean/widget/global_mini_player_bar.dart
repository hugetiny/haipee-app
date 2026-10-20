import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/player/local_video_play_args.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/utils.dart';

/// 全局常驻迷你播放控制条（GlobalMiniPlayerBar）
///
/// 当用户在音视频播放中回退到搜索、设置、下载等任意主界面时：
/// 1. 自动浮现于界面底部，指示当前后台音视频播放状态；
/// 2. 点击卡片或“返回”按钮可一键无缝重返全屏播放界面（保持播放进度，0秒重开）；
/// 3. 提供极速播放/暂停控制；
/// 4. 提供明确的「✕」停止按钮，彻底断开流式服务器与解码线程，杜绝幽灵漏音。
class GlobalMiniPlayerBar extends ConsumerWidget {
  const GlobalMiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerController = ref.read(playerProvider.notifier);
    final currentRoute = ref.watch(currentRouteProvider);
    final videoState = ref.watch(videoProvider);

    // 当前已处于播放器页面（本地播放或在线番剧页面）时，自动隐匿全局迷你条
    if (currentRoute == Routes.localPlayer || currentRoute == Routes.video) {
      return const SizedBox.shrink();
    }

    // 无活跃媒体会话时，自动隐藏
    if (!playerController.hasActivePlayback) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isAudio = playerController.isAudioMode ||
        (playerController.activeLocalVideoArgs?.effectiveIsAudio ?? false);

    // 提取展示标题
    String displayTitle = playerController.currentTitle;
    if (displayTitle.isEmpty && playerController.activeLocalVideoArgs != null) {
      displayTitle = playerController.activeLocalVideoArgs!.title;
    }
    if (displayTitle.isEmpty && videoState.bangumiItem != null) {
      displayTitle = videoState.bangumiItem!.nameCn.isNotEmpty
          ? videoState.bangumiItem!.nameCn
          : videoState.bangumiItem!.name;
    }
    if (displayTitle.isEmpty) {
      displayTitle = '正在播放媒体';
    }

    final currentPos = playerState.currentPosition;
    final totalDuration = playerState.duration;
    final progressFraction = (totalDuration.inMilliseconds > 0)
        ? (currentPos.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    void returnToPlayer() {
      if (playerController.activeLocalVideoArgs != null) {
        context.push(
          Routes.localPlayer,
          extra: playerController.activeLocalVideoArgs,
        );
      } else if (videoState.bangumiItem != null) {
        context.push(Routes.video);
      } else if (playerController.videoUrl.isNotEmpty) {
        context.push(
          Routes.localPlayer,
          extra: LocalVideoPlayArgs(
            filePath: playerController.videoUrl,
            title: displayTitle,
            isAudio: isAudio,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(245),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(90),
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                // 顶部细长进度条
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 2.5,
                    backgroundColor: theme.colorScheme.primary.withAlpha(35),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),

                // 主体信息与操作区
                InkWell(
                  onTap: returnToPlayer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // 左侧图标容器
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAudio
                                  ? [
                                      Colors.deepPurple.shade600,
                                      Colors.indigo.shade500
                                    ]
                                  : [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.tertiary,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (isAudio
                                        ? Colors.deepPurple
                                        : theme.colorScheme.primary)
                                    .withAlpha(70),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isAudio
                                ? Icons.music_note_rounded
                                : (playerState.playing
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 中间标题与播放时间提示
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: playerState.playing
                                          ? Colors.greenAccent.shade400
                                          : Colors.amberAccent.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    totalDuration.inSeconds > 0
                                        ? '${Utils.durationToString(currentPos)} / ${Utils.durationToString(totalDuration)} · 点击返回界面'
                                        : '后台播放中 · 点击返回全屏',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 右侧操作按钮组
                        // 1. 返回播放界面按钮
                        IconButton(
                          tooltip: '返回播放界面',
                          icon: const Icon(Icons.open_in_full_rounded, size: 20),
                          onPressed: returnToPlayer,
                          visualDensity: VisualDensity.compact,
                        ),

                        // 2. 播放 / 暂停按钮
                        IconButton(
                          tooltip: playerState.playing ? '暂停' : '继续播放',
                          icon: Icon(
                            playerState.playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 28,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => playerController.playOrPause(),
                          visualDensity: VisualDensity.compact,
                        ),

                        // 3. 彻底停止与关闭按钮
                        IconButton(
                          tooltip: '停止播放并关闭',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: theme.colorScheme.error.withAlpha(210),
                          ),
                          onPressed: () async {
                            await playerController.stopAndRelease();
                            KazumiDialog.showToast(message: '已停止播放');
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
