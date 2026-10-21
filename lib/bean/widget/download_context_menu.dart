import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/download/download_file_utils.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/download/download_task_detail_dialog.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/pages/player/local_video_play_args.dart';
import 'package:kazumi/pages/download/widgets/add_download_dialog.dart';
import 'package:kazumi/router_constants.dart';

/// 下载任务卡片右键/长按菜单通用构建与操作辅助类
class DownloadContextMenuHelper {
  /// 构建下载任务状态感知右键/长按菜单条目
  static List<AppMenuItem> buildMenuItems({
    required BuildContext context,
    required WidgetRef ref,
    required DownloadTask task,
    required DownloadController controller,
    required bool isActive,
    VoidCallback? onPlay,
    VoidCallback? onStreamPlay,
    VoidCallback? onToggleSelectionMode,
    void Function(String gid)? onToggleSelection,
    void Function(BuildContext context, VoidCallback onConfirm)?
        showDeleteConfirmDialog,
  }) {
    final uiState = ref.read(downloadPageUIProvider);
    final isSelected = uiState.selectedGids.contains(task.gid);
    final diskInfo = DownloadFileUtils.resolveDiskInfo(task);
    final effectivePath = diskInfo.fullPath.isNotEmpty
        ? diskInfo.fullPath
        : (task.filePath ?? task.fileName ?? '');

    return [
      // 1. 播放 / 边下边播 / 打开文件
      if ((task.isComplete || task.isRemoved) && task.isPlayable)
        AppMenuAction(
          title: '播放视频/音频',
          icon: Icons.play_arrow_rounded,
          onSelected: () => onPlay != null ? onPlay() : playTask(context, task),
        ),
      if (isActive && task.isPlayable)
        AppMenuAction(
          title: '边下边播',
          icon: Icons.play_circle_outline_rounded,
          onSelected: () =>
              onStreamPlay != null ? onStreamPlay() : streamPlayTask(context, task),
        ),
      if ((task.isComplete || task.isRemoved) && effectivePath.isNotEmpty)
        AppMenuAction(
          title: task.isPlayable ? '使用外部程序打开文件' : '打开文件',
          icon: Icons.file_open_rounded,
          onSelected: () => DownloadFileUtils.openFile(effectivePath),
        ),

      // 2. 暂停 / 继续
      if (isActive || task.isWaiting)
        AppMenuAction(
          title: '暂停下载',
          icon: Icons.pause_rounded,
          onSelected: () => controller.pauseDownload(task.gid),
        ),
      if (task.isPaused)
        AppMenuAction(
          title: '继续下载',
          icon: Icons.play_arrow_rounded,
          onSelected: () => controller.resumeDownload(task.gid),
        ),

      // 3. 定位所在文件夹
      if (effectivePath.isNotEmpty)
        AppMenuAction(
          title: '在访达 / 资源管理器中显示',
          icon: Icons.folder_open_rounded,
          onSelected: () =>
              DownloadFileUtils.openContainingFolder(effectivePath),
        ),

      // 4. 重试 / 重新下载 / 重新配置
      if (task.isError || task.isRemoved || task.isComplete)
        AppMenuAction(
          title: task.isError ? '重试下载' : '重新下载',
          icon: Icons.refresh_rounded,
          onSelected: () => controller.retryDownload(task),
        ),
      if (task.isRedirectOrAuthError)
        AppMenuAction(
          title: '重新配置鉴权/参数...',
          icon: Icons.tune_rounded,
          onSelected: () {
            showDialog(
              context: context,
              builder: (context) => AddDownloadDialog(
                initialUrl: task.url,
                initialFileName: task.fileName,
              ),
            );
          },
        ),

      // 5. 任务详情属性
      AppMenuAction(
        title: '任务详情属性...',
        icon: Icons.info_outline_rounded,
        onSelected: () {
          showDialog(
            context: context,
            builder: (context) => DownloadTaskDetailDialog(
              task: task,
              onRetry: (task.isError || task.isRemoved)
                  ? () async {
                      await controller.retryDownload(task);
                      if (context.mounted) {
                        KazumiDialog.showToast(
                            message: t.downloads.page.toast.retrying);
                      }
                    }
                  : null,
              onOpenFile: (task.isComplete || task.isRemoved) && task.isPlayable
                  ? () => onPlay != null ? onPlay() : playTask(context, task)
                  : null,
            ),
          );
        },
      ),

      const AppMenuSeparator(),

      // 6. 复制操作
      if (effectivePath.isNotEmpty)
        AppMenuAction(
          title: '复制文件完整路径',
          icon: Icons.content_copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: effectivePath));
            if (context.mounted) {
              KazumiDialog.showToast(message: '已复制文件完整路径', context: context);
            }
          },
        ),
      if (task.url.isNotEmpty)
        AppMenuAction(
          title: '复制下载链接',
          icon: Icons.link_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: task.url));
            if (context.mounted) {
              KazumiDialog.showToast(message: '已复制下载链接', context: context);
            }
          },
        ),
      AppMenuAction(
        title: '复制任务标题',
        icon: Icons.title_rounded,
        onSelected: () async {
          await Clipboard.setData(ClipboardData(text: task.displayTitle));
          if (context.mounted) {
            KazumiDialog.showToast(message: '已复制任务标题', context: context);
          }
        },
      ),

      const AppMenuSeparator(),

      // 7. 多选状态切换
      AppMenuAction(
        title: isSelected ? '取消选中' : '选择此任务',
        icon: isSelected
            ? Icons.check_box_outlined
            : Icons.check_box_outline_blank_rounded,
        onSelected: () {
          if (onToggleSelectionMode != null && !uiState.isSelectionMode) {
            onToggleSelectionMode();
          } else if (!uiState.isSelectionMode) {
            ref.read(downloadPageUIProvider.notifier).toggleSelectionMode();
          }
          if (onToggleSelection != null) {
            onToggleSelection(task.gid);
          } else {
            ref.read(downloadPageUIProvider.notifier).toggleSelection(task.gid);
          }
        },
      ),

      // 8. 删除任务
      AppMenuAction(
        title: '删除任务',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onSelected: () {
          if (showDeleteConfirmDialog != null) {
            showDeleteConfirmDialog(
              context,
              () => controller.removeDownload(task.gid, force: true),
            );
          } else {
            defaultShowDeleteConfirmDialog(
              context,
              () => controller.removeDownload(task.gid, force: true),
            );
          }
        },
      ),
    ];
  }

  /// 默认删除确认弹窗
  static void defaultShowDeleteConfirmDialog(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.app.delete),
        content: Text(t.downloads.page.dialog.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.app.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(t.app.delete),
          ),
        ],
      ),
    );
  }

  /// 播放已下载媒体文件
  static void playTask(BuildContext context, DownloadTask task) {
    if (!task.isPlayable) {
      KazumiDialog.showToast(message: '该文件不是音视频媒体文件，无法直接播放');
      return;
    }
    final path = task.filePath ?? task.fileName;
    if (path == null || path.isEmpty) {
      KazumiDialog.showToast(message: '未找到视频文件路径');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      KazumiDialog.showToast(message: '视频文件不存在: $path');
      return;
    }

    context.push(
      Routes.localPlayer,
      extra: LocalVideoPlayArgs(
        filePath: file.absolute.path,
        title: task.title,
        bangumiId: task.bangumiId,
        episode: task.episodeNumber,
      ),
    );
  }

  /// 边下边播
  static void streamPlayTask(BuildContext context, DownloadTask task) {
    if (!task.isPlayable) {
      KazumiDialog.showToast(message: '非音视频文件不支持边下边播');
      return;
    }
    final path = task.filePath ?? task.fileName;
    if (path == null || path.isEmpty) {
      KazumiDialog.showToast(message: '正在分配本地空间与元数据，请稍候');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      KazumiDialog.showToast(message: '文件正在高速缓冲首部，请稍候点击');
      return;
    }

    if (task.completedLength < 10 * 1024 * 1024 && !task.isComplete) {
      KazumiDialog.showToast(
          message: '已缓冲 ${_formatFileSize(task.completedLength)}，正在加速首尾关键帧');
    }

    context.push(
      Routes.localPlayer,
      extra: LocalVideoPlayArgs(
        filePath: file.absolute.path,
        title: task.title,
        bangumiId: task.bangumiId,
        episode: task.episodeNumber,
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
