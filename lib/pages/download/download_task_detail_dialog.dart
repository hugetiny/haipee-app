import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:open_filex/open_filex.dart';

/// 任务详情对话框状态 Provider (family pattern for specific task)
final taskDetailStateProvider =
    NotifierProvider.family<TaskDetailNotifier, TaskDetailState, String>(
  (gid) => TaskDetailNotifier(gid),
);

/// 任务详情状态
class TaskDetailState {
  final bool fileExists;
  final bool isChecking;
  final String? errorMessage;

  const TaskDetailState({
    this.fileExists = false,
    this.isChecking = true,
    this.errorMessage,
  });

  TaskDetailState copyWith({
    bool? fileExists,
    bool? isChecking,
    String? errorMessage,
  }) {
    return TaskDetailState(
      fileExists: fileExists ?? this.fileExists,
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

  Future<void> checkFileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      state = state.copyWith(isChecking: false, fileExists: false);
      return;
    }

    try {
      final file = File(filePath);
      final exists = await file.exists();
      state = state.copyWith(fileExists: exists, isChecking: false);
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
    // Check file existence on init
    Future.microtask(() {
      ref
          .read(taskDetailStateProvider(widget.task.gid).notifier)
          .checkFileExists(widget.task.filePath);
    });
  }

  DownloadTask get task => widget.task;

  Future<void> _openFile() async {
    final filePath = task.filePath;
    final detailState = ref.read(taskDetailStateProvider(task.gid));

    if (!detailState.fileExists || filePath == null || filePath.isEmpty) {
      KazumiDialog.showToast(message: '文件不存在或路径无效');
      return;
    }

    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        KazumiDialog.showToast(message: '无法打开文件: ${result.message}');
      }
    } on PlatformException catch (e) {
      KazumiDialog.showToast(message: '打开文件失败: ${e.message}');
    } catch (e) {
      KazumiDialog.showToast(message: '打开文件时发生错误');
    }
  }

  String _formatFileSize(int bytes) {
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
        return '失败';
      case 'complete':
        return '已完成';
      case 'removed':
        return '已删除';
      default:
        return '未知';
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
      default:
        return Colors.grey;
    }
  }

  String _shortenPath(String path) {
    // Shorten very long paths for display
    if (path.length <= 50) return path;

    // Try to show filename and parent directory
    final parts = path.split(Platform.pathSeparator);
    if (parts.length > 2) {
      return '...${Platform.pathSeparator}${parts[parts.length - 2]}${Platform.pathSeparator}${parts.last}';
    }

    // Fallback: show start and end
    return '${path.substring(0, 20)}...${path.substring(path.length - 20)}';
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

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '任务详情',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status chip
                    Chip(
                      label: Text(_getStatusText()),
                      backgroundColor:
                          _getStatusColor(context).withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _getStatusColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    _buildSection('任务名称', task.title),
                    const SizedBox(height: 16),

                    // File info
                    if (task.fileName != null) ...[
                      _buildSection('文件名', task.fileName!),
                      const SizedBox(height: 16),
                    ],

                    // Download info
                    _buildSection('文件大小', _formatFileSize(task.totalLength)),
                    const SizedBox(height: 8),
                    _buildSection('已下载', _formatFileSize(task.completedLength)),
                    const SizedBox(height: 8),
                    _buildSection(
                      '进度',
                      '${(task.progress * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 16),

                    // Speed and ETA
                    if (task.isActive) ...[
                      _buildSection('下载速度', _formatSpeed(task.downloadSpeed)),
                      const SizedBox(height: 8),
                      if (etaSeconds > 0)
                        _buildSection('预计剩余时间', _formatDuration(etaSeconds)),
                      const SizedBox(height: 16),
                    ],

                    // File path (for completed tasks)
                    if (task.isComplete &&
                        task.filePath != null &&
                        task.filePath!.isNotEmpty) ...[
                      _buildSection(
                        '文件路径',
                        _shortenPath(task.filePath!),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: task.filePath!));
                            KazumiDialog.showToast(message: '已复制路径');
                          },
                          tooltip: '复制路径',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // URL
                    _buildSection(
                      'URL',
                      task.url,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: task.url));
                          KazumiDialog.showToast(message: '已复制链接');
                        },
                        tooltip: '复制链接',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Error info
                    if (task.isError) ...[
                      _buildSection(
                        '错误信息',
                        task.errorMessage ?? '未知错误',
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

                    // Bangumi info
                    if (task.bangumiId != null) ...[
                      _buildSection('番剧 ID', task.bangumiId!),
                      const SizedBox(height: 8),
                    ],
                    if (task.episodeNumber != null) ...[
                      _buildSection('集数', '第 ${task.episodeNumber} 集'),
                      const SizedBox(height: 16),
                    ],

                    // Timestamps
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
                    _buildSection('任务 GID', task.gid),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (task.isError && widget.onRetry != null) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onRetry?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Use Riverpod state instead of ValueNotifier
                  if (task.isComplete && !detailState.isChecking && detailState.fileExists) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('打开文件'),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _openFile();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          width: 100,
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
