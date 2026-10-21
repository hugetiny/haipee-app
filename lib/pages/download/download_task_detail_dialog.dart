import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/download/download_file_utils.dart';
import 'package:kazumi/modules/download/download_task.dart';

/// 任务详情对话框状态 Provider (family pattern for specific task)
final taskDetailStateProvider =
    NotifierProvider.family<TaskDetailNotifier, TaskDetailState, String>(
  (gid) => TaskDetailNotifier(gid),
);

/// 任务详情状态
class TaskDetailState {
  final bool fileExists;
  final bool isDirectory;
  final int diskSize;
  final String fullPath;
  final String directory;
  final String fileName;
  final bool isChecking;
  final String? errorMessage;

  const TaskDetailState({
    this.fileExists = false,
    this.isDirectory = false,
    this.diskSize = 0,
    this.fullPath = '',
    this.directory = '',
    this.fileName = '',
    this.isChecking = false,
    this.errorMessage,
  });

  TaskDetailState copyWith({
    bool? fileExists,
    bool? isDirectory,
    int? diskSize,
    String? fullPath,
    String? directory,
    String? fileName,
    bool? isChecking,
    String? errorMessage,
  }) {
    return TaskDetailState(
      fileExists: fileExists ?? this.fileExists,
      isDirectory: isDirectory ?? this.isDirectory,
      diskSize: diskSize ?? this.diskSize,
      fullPath: fullPath ?? this.fullPath,
      directory: directory ?? this.directory,
      fileName: fileName ?? this.fileName,
      isChecking: isChecking ?? this.isChecking,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 任务详情状态管理器
class TaskDetailNotifier extends Notifier<TaskDetailState> {
  TaskDetailNotifier(this.gid);

  final String gid;

  @override
  TaskDetailState build() => const TaskDetailState();

  void checkTaskDiskInfo(DownloadTask task) {
    try {
      final info = DownloadFileUtils.resolveDiskInfo(task);
      state = TaskDetailState(
        fileExists: info.exists,
        isDirectory: info.isDirectory,
        diskSize: info.diskSize,
        fullPath: info.fullPath,
        directory: info.directory,
        fileName: info.fileName,
        isChecking: false,
      );
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 兼容旧版调用
  Future<void> checkFileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      state = state.copyWith(isChecking: false, fileExists: false);
      return;
    }

    try {
      final file = File(filePath);
      final exists = await file.exists();
      int size = 0;
      if (exists) {
        size = await file.length();
      }
      state = state.copyWith(
        fileExists: exists,
        diskSize: size,
        fullPath: filePath,
        isChecking: false,
      );
    } catch (e) {
      state = state.copyWith(
        fileExists: false,
        isChecking: false,
        errorMessage: e.toString(),
      );
    }
  }
}

class DownloadTaskDetailDialog extends ConsumerStatefulWidget {
  final DownloadTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenFile;

  const DownloadTaskDetailDialog({
    super.key,
    required this.task,
    this.onRetry,
    this.onOpenFile,
  });

  @override
  ConsumerState<DownloadTaskDetailDialog> createState() =>
      _DownloadTaskDetailDialogState();
}

class _DownloadTaskDetailDialogState
    extends ConsumerState<DownloadTaskDetailDialog> {
  @override
  void initState() {
    super.initState();
    // 异步加载磁盘文件信息
    Future.microtask(() {
      ref
          .read(taskDetailStateProvider(widget.task.gid).notifier)
          .checkTaskDiskInfo(widget.task);
    });
  }

  DownloadTask get task => widget.task;

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    return '${_formatFileSize(bytesPerSecond)}/s';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    if (seconds < 3600) return '${seconds ~/ 60} 分钟';
    return '${seconds ~/ 3600} 小时 ${(seconds % 3600) ~/ 60} 分钟';
  }

  String _getStatusText() {
    switch (task.status) {
      case 'active':
        return '下载中';
      case 'waiting':
        return '等待中';
      case 'paused':
        return '已暂停';
      case 'error':
        return '下载失败';
      case 'complete':
        return '已完成';
      case 'removed':
        return '已取消 (已从队列移除)';
      default:
        return task.status;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (task.status) {
      case 'active':
        return Colors.blue;
      case 'waiting':
        return Colors.orange;
      case 'paused':
        return Colors.grey;
      case 'error':
        return Colors.red;
      case 'complete':
        return Colors.green;
      case 'removed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (task.status) {
      case 'active':
        return Icons.arrow_downward_rounded;
      case 'waiting':
        return Icons.schedule_rounded;
      case 'paused':
        return Icons.pause_circle_outline_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'complete':
        return Icons.check_circle_outline_rounded;
      case 'removed':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(taskDetailStateProvider(task.gid));
    final int remainingBytes = task.totalLength - task.completedLength;
    final int etaSeconds =
        task.downloadSpeed > 0 ? remainingBytes ~/ task.downloadSpeed : 0;
    final theme = Theme.of(context);

    final effectivePath = detailState.fullPath.isNotEmpty
        ? detailState.fullPath
        : (task.filePath ?? task.fileName ?? '');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '下载任务详情',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 状态展示栏（状态 Chip + 磁盘存在性 Badge）
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(
                            _getStatusIcon(),
                            size: 16,
                            color: _getStatusColor(context),
                          ),
                          label: Text(_getStatusText()),
                          backgroundColor:
                              _getStatusColor(context).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: _getStatusColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (detailState.isChecking) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '正在检查磁盘...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: detailState.fileExists
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: detailState.fileExists
                                    ? Colors.green.withValues(alpha: 0.35)
                                    : Colors.orange.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  detailState.fileExists
                                      ? Icons.check_circle_rounded
                                      : Icons.help_outline_rounded,
                                  size: 14,
                                  color: detailState.fileExists
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  detailState.fileExists
                                      ? '本地文件存在 (${_formatFileSize(detailState.diskSize)})'
                                      : '本地文件不存在',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: detailState.fileExists
                                        ? Colors.green.shade800
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 2. removed（已取消/已移除）状态详细说明 Banner
                    if (task.isRemoved) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blueGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '状态说明：已从下载队列移除 (removed)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    detailState.fileExists
                                        ? '此任务已从下载引擎的执行队列中移出，但之前已下载的本地磁盘文件仍然保留完好，并未被删除。您可在下方直接打开文件或定位所在文件夹。'
                                        : '此任务已从下载引擎的执行队列中移出，当前在指定下载路径未检测到对应文件（可能在开始前取消，或已被用户清理）。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 3. 鉴权失效/网页重定向错误 Banner
                    if (task.isError && task.isRedirectOrAuthError) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.red, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '下载内容为重定向网页或鉴权失败，文件可能已失效',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '文件内容实际为网页或鉴权错误，未获得真实资源。请重新添加任务并提供网盘 Cookie / Referer，或检查链接。',
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 4. 任务基本信息
                    _buildSection('任务名称', task.displayTitle),
                    const SizedBox(height: 8),
                    _buildSection('资源类型', task.fileTypeDisplay),
                    if (task.bangumiId != null) ...[
                      const SizedBox(height: 8),
                      _buildSection('番剧 ID', task.bangumiId!),
                    ],
                    if (task.episodeNumber != null) ...[
                      const SizedBox(height: 8),
                      _buildSection('集数', '第 ${task.episodeNumber} 集'),
                    ],

                    const SizedBox(height: 16),

                    // 5. 存储路径卡片（无论何种状态均清晰展示目标目录与完整路径）
                    _buildPathCard(context, detailState),

                    const SizedBox(height: 16),

                    // 6. 下载进度与数据统计
                    _buildSection('文件大小', _formatFileSize(task.totalLength)),
                    const SizedBox(height: 8),
                    _buildSection('已下载', _formatFileSize(task.completedLength)),
                    const SizedBox(height: 8),
                    _buildSection(
                      '下载进度',
                      '${(task.progress * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 速度与剩余时间
                    if (task.isActive) ...[
                      _buildSection('下载速度', _formatSpeed(task.downloadSpeed)),
                      if (task.uploadSpeed > 0) ...[
                        const SizedBox(height: 8),
                        _buildSection('上传速度', _formatSpeed(task.uploadSpeed)),
                      ],
                      if (etaSeconds > 0) ...[
                        const SizedBox(height: 8),
                        _buildSection('预计剩余时间', _formatDuration(etaSeconds)),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // 7. 错误信息
                    if (task.isError) ...[
                      _buildSection(
                        '错误信息',
                        task.readableErrorMessage,
                        isError: true,
                      ),
                      if (task.errorCode != null) ...[
                        const SizedBox(height: 8),
                        _buildSection(
                          '错误代码',
                          task.errorCode.toString(),
                          isError: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // 8. 资源链接
                    _buildSection(
                      '资源链接',
                      task.url,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: task.url));
                          KazumiDialog.showToast(message: '已复制链接');
                        },
                        tooltip: '复制链接',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 9. 元数据时间与 GID
                    _buildSection(
                      '创建时间',
                      _formatDateTime(task.createdAt),
                    ),
                    const SizedBox(height: 8),
                    _buildSection(
                      '更新时间',
                      _formatDateTime(task.updatedAt),
                    ),
                    const SizedBox(height: 8),
                    _buildSection(
                      '任务 GID',
                      task.gid,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: task.gid));
                          KazumiDialog.showToast(message: '已复制 GID');
                        },
                        tooltip: '复制 GID',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions 底部操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 重试 / 重新下载按钮
                    if ((task.isError || task.isRemoved) &&
                        widget.onRetry != null) ...[
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(task.isRemoved ? '重新下载' : '重试'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onRetry?.call();
                        },
                      ),
                    ],

                    // 播放按钮（本地文件存在且为媒体）
                    if (detailState.fileExists &&
                        task.isPlayable &&
                        widget.onOpenFile != null) ...[
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('播放'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onOpenFile?.call();
                        },
                      ),
                    ],

                    // 打开文件按钮（本地文件存在）
                    if (detailState.fileExists) ...[
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.file_open_outlined, size: 18),
                        label: const Text('打开文件'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await DownloadFileUtils.openFile(effectivePath);
                        },
                      ),
                    ],

                    // 所在文件夹按钮（始终可用）
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('所在文件夹'),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await DownloadFileUtils.openContainingFolder(
                          effectivePath.isNotEmpty
                              ? effectivePath
                              : detailState.directory,
                        );
                      },
                    ),

                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 存储路径独立卡片：清晰显示保存目录、完整路径、本地文件状态及快速打开按钮
  Widget _buildPathCard(BuildContext context, TaskDetailState detailState) {
    final theme = Theme.of(context);
    final displayPath = detailState.fullPath.isNotEmpty
        ? detailState.fullPath
        : (task.filePath ?? task.fileName ?? '未指定保存路径');
    final displayDir = detailState.directory.isNotEmpty
        ? detailState.directory
        : '系统默认下载目录';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_special_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '文件存储路径',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('定位文件夹', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await DownloadFileUtils.openContainingFolder(displayPath);
                },
              ),
            ],
          ),
          const Divider(height: 16),

          // 保存目录
          _buildPathRow(
            context,
            label: '保存目录',
            content: displayDir,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: displayDir));
              KazumiDialog.showToast(message: '已复制保存目录');
            },
          ),
          const SizedBox(height: 8),

          // 完整绝对路径
          _buildPathRow(
            context,
            label: '完整路径',
            content: displayPath,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: displayPath));
              KazumiDialog.showToast(message: '已复制完整路径');
            },
          ),

          if (detailState.fileName.isNotEmpty &&
              detailState.fileName != task.displayTitle) ...[
            const SizedBox(height: 8),
            _buildPathRow(
              context,
              label: '保存文件名',
              content: detailState.fileName,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: detailState.fileName));
                KazumiDialog.showToast(message: '已复制文件名');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathRow(
    BuildContext context, {
    required String label,
    required String content,
    required VoidCallback onCopy,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            content,
            style: TextStyle(
              fontSize: 12,
              fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: '复制',
          onPressed: onCopy,
        ),
      ],
    );
  }

  Widget _buildSection(
    String label,
    String value, {
    Widget? trailing,
    bool isError = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : null,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isError ? Colors.red : null,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
