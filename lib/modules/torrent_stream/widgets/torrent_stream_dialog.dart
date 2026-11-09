import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_service.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

/// 专为 BT/磁力链在线边下边播设计的实时交互 HUD 对话框（支持原生与 TorrServer 极速互保）。
///
/// 核心特性：
/// 1. 结构化展示做种节点发现、元数据拉取、首尾关键帧索引预缓冲状态；
/// 2. 实时展示活跃 Peer 节点、即时下载速度、已缓冲秒数/分片数及当前驱动引擎；
/// 3. 支持随时一键在「原生 Libtorrent」与「TorrServer 极速流式」之间无缝切换；
/// 4. 支持随时一键取消或无缝切换至离线下载队列（多引擎互保，绝不无限转圈卡死）；
/// 5. 关键分片缓冲就绪后安全退出并返回 [TorrentStreamSession]，保障播放器即时首帧渲染。
class TorrentStreamDialog extends ConsumerStatefulWidget {
  final TorrentItem item;
  final String? overrideTitle;
  final int? episode;
  final String? bangumiId;
  final bool isAudio;
  final TorrentStreamEngine initialEngine;

  const TorrentStreamDialog({
    super.key,
    required this.item,
    this.overrideTitle,
    this.episode,
    this.bangumiId,
    this.isAudio = false,
    this.initialEngine = TorrentStreamEngine.auto,
  });

  /// 弹出准备对话框并在流式缓冲就绪后返回会话，若取消或转入后台下载则返回 null。
  static Future<TorrentStreamSession?> show({
    required BuildContext context,
    required WidgetRef ref,
    required TorrentItem item,
    String? overrideTitle,
    int? episode,
    String? bangumiId,
    bool isAudio = false,
    TorrentStreamEngine initialEngine = TorrentStreamEngine.auto,
  }) {
    return showDialog<TorrentStreamSession?>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: 'TorrentStreamDialog'),
      builder: (ctx) => TorrentStreamDialog(
        item: item,
        overrideTitle: overrideTitle,
        episode: episode,
        bangumiId: bangumiId,
        isAudio: isAudio,
        initialEngine: initialEngine,
      ),
    );
  }

  @override
  ConsumerState<TorrentStreamDialog> createState() => _TorrentStreamDialogState();
}

class _TorrentStreamDialogState extends ConsumerState<TorrentStreamDialog>
    with SingleTickerProviderStateMixin {
  late TorrentStreamCancelToken _cancelToken;
  late TorrentStreamEngine _currentEngine;
  TorrentStreamProgress _progress = const TorrentStreamProgress(
    stage: TorrentStreamStage.connectingPeers,
    message: '正在通过分布式 DHT 与公共 Tracker 查找活跃做种节点...',
  );

  String? _errorMessage;
  bool _isFinished = false;
  bool _isSwitchingToDownload = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentEngine = widget.initialEngine;
    _cancelToken = TorrentStreamCancelToken();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // 启动流式准备任务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreamPreparation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (!_isFinished) {
      _cancelToken.cancel();
    }
    super.dispose();
  }

  String get _displayTitle {
    if (widget.overrideTitle != null && widget.overrideTitle!.isNotEmpty) {
      return widget.overrideTitle!;
    }
    return widget.item.displayTitle.isNotEmpty
        ? widget.item.displayTitle
        : widget.item.title;
  }

  Future<void> _startStreamPreparation() async {
    final token = TorrentStreamCancelToken();
    _cancelToken = token;
    setState(() {
      _errorMessage = null;
      _progress = TorrentStreamProgress(
        stage: TorrentStreamStage.connectingPeers,
        message: '正在通过分布式 DHT 与公共 Tracker 查找活跃做种节点...',
        engine: _currentEngine,
      );
    });

    try {
      final session = await TorrentStreamService.instance.startStream(
        magnetUri: widget.item.effectiveMagnetUrl ?? widget.item.magnetUrl,
        torrentUrl: widget.item.effectiveTorrentUrl,
        title: _displayTitle,
        isAudio: widget.isAudio || widget.item.isAudio,
        cancelToken: token,
        waitForBuffer: true,
        engine: _currentEngine,
        onProgressUpdate: (progress) {
          if (mounted && !token.isCancelled && _cancelToken == token) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (!mounted || token.isCancelled || _cancelToken != token) return;

      _isFinished = true;
      setState(() {
        _progress = TorrentStreamProgress(
          stage: TorrentStreamStage.ready,
          message: '首帧索引缓冲就绪，正在启动播放器...',
          selectedFileName: session.selectedFile?.name,
          selectedFileSize: session.selectedFile?.size,
          engine: session.engine,
        );
      });

      // 简短平滑视觉反馈
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _cancelToken == token) {
        Navigator.of(context).pop(session);
      }
    } on TorrentStreamCancelledException {
      // Ignored: User clicked cancel, switched engines, or moved to background download.
      // Do not pop here to avoid double-popping or closing during engine switch.
    } on NoStreamableFileException catch (e) {
      if (mounted && _cancelToken == token) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } on TorrentMetadataTimeoutException catch (e) {
      if (mounted && _cancelToken == token) {
        setState(() {
          _errorMessage = '获取种子元数据超时（当前发现节点数: ${e.peerCount}）。\n当前网络环境下做种节点较少，建议转入后台离线下载。';
        });
      }
    } catch (e) {
      if (mounted && _cancelToken == token) {
        setState(() {
          _errorMessage = '流式准备失败: $e\n建议转入后台离线下载。';
        });
      }
    }
  }

  /// 一键转入后台离线下载队列
  Future<void> _switchToBackgroundDownload() async {
    if (_isSwitchingToDownload) return;
    _isSwitchingToDownload = true;
    _cancelToken.cancel();

    try {
      final downloadCtrl = ref.read(downloadControllerProvider.notifier);
      final magnet = widget.item.magnetUrl;
      final ep = widget.episode ??
          int.tryParse(widget.item.episode?.replaceAll('E', '') ?? '');

      await downloadCtrl.addUris(
        [magnet],
        title: _displayTitle,
        episodeNumber: widget.item.isVideo ? ep : null,
      );

      if (mounted) {
        HaipeeDialog.showToast(message: '已添加至后台下载队列: $_displayTitle');
        Navigator.of(context).pop(null);
      }
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '转入后台下载失败: $e');
        _isSwitchingToDownload = false;
      }
    }
  }

  void _handleCancel() {
    _cancelToken.cancel();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleCancel();
        }
      },
      child: AdaptiveDialogFrame(
        maxWidth: 440,
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 18),
            if (_errorMessage != null)
              _buildErrorView(theme, colorScheme)
            else
              _buildProgressView(theme, colorScheme),
            const SizedBox(height: 22),
            _buildActionButtons(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final isAudio = widget.isAudio || widget.item.isAudio;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(160),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isAudio ? Icons.music_note_rounded : Icons.play_circle_filled_rounded,
            color: colorScheme.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isAudio ? '音频边下边听' : '在线边下边播',
                    style: theme.textTheme.titleMedium?.copyWith(
                       fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _progress.engine == TorrentStreamEngine.torrserver
                          ? colorScheme.primaryContainer
                          : colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _progress.engine == TorrentStreamEngine.torrserver
                              ? Icons.rocket_launch_rounded
                              : Icons.memory_rounded,
                          size: 11,
                          color: _progress.engine == TorrentStreamEngine.torrserver
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _progress.engine == TorrentStreamEngine.torrserver
                              ? 'TorrServer 内存流式'
                              : '原生 Libtorrent',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _progress.engine == TorrentStreamEngine.torrserver
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressView(ThemeData theme, ColorScheme colorScheme) {
    final stage = _progress.stage;
    final isBuffering = stage == TorrentStreamStage.buffering;
    final isReady = stage == TorrentStreamStage.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isReady)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18)
            else
              FadeTransition(
                opacity: _pulseAnimation,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _progress.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isReady ? Colors.green.shade700 : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: isReady
              ? const LinearProgressIndicator(value: 1.0, minHeight: 6, color: Colors.green)
              : isBuffering
                  ? LinearProgressIndicator(
                      value: _progress.bufferPieces > 0
                          ? (_progress.bufferPieces / 5.0).clamp(0.1, 0.95)
                          : (_progress.downloadRate > 0 ? 0.35 : null),
                      minHeight: 6,
                    )
                  : const LinearProgressIndicator(minHeight: 6),
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildBadge(
              icon: Icons.hub_rounded,
              label: '做种节点: ${_progress.peerCount}',
              colorScheme: colorScheme,
            ),
            if (isBuffering || isReady || _progress.downloadRate > 0) ...[
              _buildBadge(
                icon: Icons.speed_rounded,
                label: '下载速度: ${_progress.formattedSpeed}',
                colorScheme: colorScheme,
              ),
              if (_progress.bufferPieces > 0 || _progress.bufferSeconds > 0)
                _buildBadge(
                  icon: Icons.timer_outlined,
                  label: '已缓冲: ${_progress.bufferSeconds > 0 ? "${_progress.bufferSeconds.toStringAsFixed(1)}s" : "${_progress.bufferPieces}分片"}',
                  colorScheme: colorScheme,
                ),
            ],
          ],
        ),

        if (_progress.selectedFileName != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isAudio ? Icons.audio_file_outlined : Icons.video_file_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _progress.selectedFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (_progress.selectedFileSize != null && _progress.selectedFileSize! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    TorrentFileEntry.formatBytes(_progress.selectedFileSize!),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(150),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '连接超时',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    if (_errorMessage != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _handleCancel,
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _startStreamPreparation,
            child: const Text('重试'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _switchToBackgroundDownload,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('转入离线下载'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: _isSwitchingToDownload ? null : _switchToBackgroundDownload,
          icon: const Icon(Icons.download_rounded, size: 15),
          label: Text(
            _isSwitchingToDownload ? '正在转入...' : '后台下载',
            style: const TextStyle(fontSize: 12),
          ),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _handleCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          child: const Text('取消', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
