import 'dart:async';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:kazumi/modules/torrent_stream/torrserver_client.dart';
import 'package:kazumi/modules/torrent_stream/torrserver_process_manager.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 专为视频在线播放打造的 TorrServer 极速流式引擎。
///
/// 核心优势：
/// 1. 纯内存环形缓冲（Zero Disk IO，保护存储设备）；
/// 2. 媒体容器（MP4 moov / MKV seekhead）首尾分片智能优先拉取；
/// 3. 少做种节点极速抢占与毫秒级 Endgame 并发；
/// 4. 任意拖动进度条（Dynamic Seek）毫秒响应。
class TorrServerStreamEngine {
  static final TorrServerStreamEngine instance = TorrServerStreamEngine._internal();
  factory TorrServerStreamEngine() => instance;
  TorrServerStreamEngine._internal();

  final TorrServerProcessManager _processManager = TorrServerProcessManager.instance;
  final KazumiLogger _logger = KazumiLogger();
  String? _activeTorrentHash;

  /// 当前是否存在活跃的 TorrServer 会话
  bool get hasActiveSession => _activeTorrentHash != null;

  /// 检查 TorrServer 服务是否可用或能够拉起
  Future<bool> isAvailable() async {
    return await _processManager.start();
  }

  /// 启动在线视频流式播放流程
  Future<TorrentStreamSession> startStream({
    required String magnetUri,
    String? torrentUrl,
    String? title,
    bool isAudio = false,
    int? fileIndex,
    void Function(String statusMessage)? onProgress,
    void Function(TorrentStreamProgress progress)? onProgressUpdate,
    Duration metadataTimeout = const Duration(seconds: 30),
    Duration bufferTimeout = const Duration(seconds: 30),
    bool waitForBuffer = true,
    TorrentStreamCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    // 1. 确保 TorrServer 子进程运行并健康
    onProgress?.call('正在启动 TorrServer 内存流式核心引擎...');
    onProgressUpdate?.call(const TorrentStreamProgress(
      stage: TorrentStreamStage.connectingPeers,
      message: '正在启动 TorrServer 内存流式核心引擎...',
      engine: TorrentStreamEngine.torrserver,
    ));

    final serverReady = await _processManager.start();
    if (!serverReady) {
      throw const TorrentStreamException('TorrServer 流式核心服务启动失败，请检查环境或权限');
    }

    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    final client = TorrServerClient(baseUrl: _processManager.baseUrl);

    // 2. 默认优先种子：若提供 torrentUrl 则直接提交种子；否则注入活跃公共 Trackers 并提交磁力
    String enhancedMagnet = magnetUri;
    try {
      enhancedMagnet = await TorrentTrackerService.instance
          .rewriteMagnetWithDoh(magnetUri)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      enhancedMagnet = TorrentTrackerService.instance.injectTrackers(magnetUri);
    }
    onProgress?.call('正在通过 TorrServer 激进多源调度发现网络做种节点...');
    onProgressUpdate?.call(const TorrentStreamProgress(
      stage: TorrentStreamStage.connectingPeers,
      message: '正在通过 TorrServer 激进多源调度发现网络做种节点...',
      engine: TorrentStreamEngine.torrserver,
    ));

    TorrServerTorrent? torrent;
    if (torrentUrl != null && torrentUrl.isNotEmpty) {
      try {
        torrent = await client.addTorrent(
          link: torrentUrl,
          title: title,
          saveToDb: false,
        );
        _logger.log(Level.info, '[TorrServerStreamEngine] Successfully added torrentUrl: $torrentUrl');
      } catch (e) {
        _logger.log(Level.warning, '[TorrServerStreamEngine] Failed to add torrentUrl ($e), falling back to magnet');
      }
    }

    if (torrent == null) {
      try {
        torrent = await client.addTorrent(
          link: enhancedMagnet,
          title: title,
          saveToDb: false,
        );
      } catch (e) {
        _logger.log(Level.error, '[TorrServerStreamEngine] Failed to add magnet: $e');
        throw TorrentStreamException('TorrServer 添加磁力链失败: $e');
      }
    }

    _activeTorrentHash = torrent.hash;
    final hash = torrent.hash;

    // 3. 轮询解析文件结构与元数据
    onProgress?.call('已连接 P2P 网络，正在解析视频容器结构与文件树...');
    final metaStartTime = DateTime.now();
    TorrServerTorrent currentTorrent = torrent;

    while (DateTime.now().difference(metaStartTime) < metadataTimeout) {
      if (cancelToken?.isCancelled == true) {
        await client.removeTorrent(hash);
        throw const TorrentStreamCancelledException();
      }

      try {
        currentTorrent = await client.getTorrent(hash);
        if (currentTorrent.files.isNotEmpty) {
          break;
        }
      } catch (_) {}

      final peers = currentTorrent.effectivePeerCount;
      final speed = currentTorrent.downloadSpeed;
      final elapsedSec = DateTime.now().difference(metaStartTime).inSeconds;
      final statusMsg = peers > 0
          ? '已发现 $peers 个做种节点，正在拉取种子文件结构 ($elapsedSec s)...'
          : '正在全网 DHT 与 Tracker 搜索活跃节点 ($elapsedSec s)...';

      onProgress?.call(statusMsg);
      onProgressUpdate?.call(TorrentStreamProgress(
        stage: peers > 0
            ? TorrentStreamStage.resolvingMetadata
            : TorrentStreamStage.connectingPeers,
        message: statusMsg,
        peerCount: peers,
        downloadRate: speed,
        engine: TorrentStreamEngine.torrserver,
      ));

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (currentTorrent.files.isEmpty) {
      await client.removeTorrent(hash);
      throw TorrentMetadataTimeoutException(
        'TorrServer 无法在超时时间内解析种子元数据（当前发现节点数: ${currentTorrent.effectivePeerCount}）',
        peerCount: currentTorrent.effectivePeerCount,
      );
    }

    // 4. 智能定位最佳主音视频文件
    final files = currentTorrent.files;
    TorrServerFile chosenFile;

    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      chosenFile = files[fileIndex];
    } else {
      // 筛选并按大小倒序
      final candidates = files.where((f) {
        if (isAudio) {
          return TorrentStreamService.isAudioFile(f.name);
        } else {
          return TorrentStreamService.isVideoFile(f.name);
        }
      }).toList();

      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.length.compareTo(a.length));
        chosenFile = candidates.first;
      } else {
        // 兜底：选取最大的非压缩包文件
        final nonZip = files.where((f) {
          final lower = f.name.toLowerCase();
          return !lower.endsWith('.zip') &&
              !lower.endsWith('.rar') &&
              !lower.endsWith('.7z') &&
              !lower.endsWith('.tar') &&
              !lower.endsWith('.gz');
        }).toList();

        if (nonZip.isNotEmpty) {
          nonZip.sort((a, b) => b.length.compareTo(a.length));
          chosenFile = nonZip.first;
        } else {
          chosenFile = files.first;
        }
      }
    }

    final targetIndex = chosenFile.id;
    final streamUrl = client.buildStreamUrl(
      link: enhancedMagnet,
      hash: hash,
      fileIndex: targetIndex,
      fileName: chosenFile.name,
    );

    _logger.log(Level.info, '[TorrServerStreamEngine] Selected file: ${chosenFile.name} (id=$targetIndex), streamUrl: $streamUrl');

    // 5. 内存首尾关键分片预缓冲
    if (waitForBuffer) {
      onProgress?.call('正在触发首尾关键分片预加载...');
      // 显式触发 TorrServer 针对目标文件的 preload 抓取，使其将首尾分片和容器头写入内存环形缓冲
      await client.triggerPreload(
        hash: hash,
        fileIndex: targetIndex,
        fileName: chosenFile.name,
      );

      final bufStartTime = DateTime.now();

      while (DateTime.now().difference(bufStartTime) < bufferTimeout) {
        if (cancelToken?.isCancelled == true) {
          await client.removeTorrent(hash);
          throw const TorrentStreamCancelledException();
        }

        try {
          currentTorrent = await client.getTorrent(hash);
        } catch (_) {}

        final peers = currentTorrent.effectivePeerCount;
        final speed = currentTorrent.downloadSpeed;
        final preloaded = currentTorrent.preloadedBytes;
        final progress = currentTorrent.preloadProgress;

        // 真实预缓冲判定：
        // 1. 已下载至少 2MB 的关键帧/容器索引数据；
        // 2. 或者预加载进度达到 5% 且已缓冲至少 1MB；
        // 3. 或者 TorrServer 宣布 preload 完成（stat 回到 3 且 preloadedBytes > 0）
        final isHeaderReady = preloaded >= 2 * 1024 * 1024 ||
            (currentTorrent.stat == 3 && preloaded > 0) ||
            (progress != null && progress >= 0.05 && preloaded >= 1024 * 1024);

        final bufMsg = progress != null
            ? '内存预缓冲中 (${(progress * 100).toStringAsFixed(0)}%) - 节点: $peers, 速度: ${TorrentStreamProgress(stage: TorrentStreamStage.buffering, message: '', downloadRate: speed).formattedSpeed}'
            : (preloaded > 0
                ? '正在缓冲媒体容器头部与索引 (已缓冲 ${(preloaded / (1024 * 1024)).toStringAsFixed(1)} MB)...'
                : '正在连接做种节点并分配内存环形缓冲 (节点: $peers)...');

        onProgress?.call(bufMsg);
        onProgressUpdate?.call(TorrentStreamProgress(
          stage: TorrentStreamStage.buffering,
          message: bufMsg,
          peerCount: peers,
          downloadRate: speed,
          bufferPercent: progress,
          selectedFileName: chosenFile.name,
          selectedFileSize: chosenFile.length,
          engine: TorrentStreamEngine.torrserver,
        ));

        if (isHeaderReady) {
          _logger.log(Level.info,
              '[TorrServerStreamEngine] Buffer ready ($preloaded bytes, stat=${currentTorrent.stat}), safe to play!');
          break;
        }

        await Future.delayed(const Duration(milliseconds: 400));
      }

      // 保护性门禁：如果超时后 preloadedBytes 依然为 0，且未就绪，绝不草率开启播放器
      if (currentTorrent.preloadedBytes == 0 && currentTorrent.stat != 3) {
        await client.removeTorrent(hash);
        throw TorrentStreamException(
          'TorrServer 预缓冲超时，暂未收到视频分片数据 (节点数: ${currentTorrent.effectivePeerCount})',
        );
      }
    }

    // 6. 宣布就绪，构造并返回会话
    const readyMsg = '首帧预缓冲就绪，正在拉起内置播放器...';
    onProgress?.call(readyMsg);
    onProgressUpdate?.call(TorrentStreamProgress(
      stage: TorrentStreamStage.ready,
      message: readyMsg,
      peerCount: currentTorrent.effectivePeerCount,
      downloadRate: currentTorrent.downloadSpeed,
      selectedFileName: chosenFile.name,
      selectedFileSize: chosenFile.length,
      engine: TorrentStreamEngine.torrserver,
    ));

    // 转换 FileInfo 供上层与原有播放组件使用
    final selectedFileInfo = FileInfo(
      index: targetIndex,
      name: chosenFile.name,
      path: chosenFile.path,
      size: chosenFile.length,
      isStreamable: TorrentStreamService.isPlayableFile(chosenFile.name),
    );

    final allFileInfos = files.map((f) => FileInfo(
      index: f.id,
      name: f.name,
      path: f.path,
      size: f.length,
      isStreamable: TorrentStreamService.isPlayableFile(f.name),
    )).toList();

    return TorrentStreamSession(
      streamId: targetIndex,
      torrentId: 0,
      streamUrl: streamUrl,
      selectedFile: selectedFileInfo,
      allFiles: allFileInfos,
      isAudio: isAudio,
      title: title ?? chosenFile.name,
      engine: TorrentStreamEngine.torrserver,
    );
  }

  /// 停止流式会话并释放 TorrServer 资源
  Future<void> stopCurrentSession() async {
    if (_activeTorrentHash != null) {
      try {
        final client = TorrServerClient(baseUrl: _processManager.baseUrl);
        await client.removeTorrent(_activeTorrentHash!);
      } catch (_) {}
      _activeTorrentHash = null;
    }
  }
}
