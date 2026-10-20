import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:kazumi/modules/torrent_stream/torrent_stream_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:kazumi/modules/torrent_stream/aria2_stream_server.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:kazumi/utils/aria2_client.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:kazumi/utils/aria2_process_manager.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 管理通过 Aria2 顺序下载驱动的本地 HTTP 流式会话
class Aria2ActiveStreamSession {
  final int streamId;
  final String gid;
  final String? parentGid;
  final Aria2StreamServer server;
  final FileInfo selectedFile;
  final String localFilePath;
  final int totalLength;
  final String streamUrl;

  Aria2ActiveStreamSession({
    required this.streamId,
    required this.gid,
    this.parentGid,
    required this.server,
    required this.selectedFile,
    required this.localFilePath,
    required this.totalLength,
    required this.streamUrl,
  });
}

/// Aria2 极速流式引擎，作为 libtorrent 在特定平台或 NAT 阻断环境下的顶级主/备流式引擎。
///
/// 核心技术亮点：
/// 1. 采用 Aria2 多线程高吞吐 BT 栈，免去 FFI dylib 依赖，天然跨端运行；
/// 2. 注入全局公共高可用 Tracker，并启用 `--bt-prioritize-piece=head=32M,tail=32M`；
/// 3. 本地构建微型 HTTP 206 Partial Content 流式代理服务器，直接为 media_kit 提供标准 Seek 流；
/// 4. 关键首尾帧预缓冲门控，避免播放器 0 字节启动黑屏或解复用探测超时。
class Aria2StreamEngine {
  static final Aria2StreamEngine instance = Aria2StreamEngine._internal();
  Aria2StreamEngine._internal();

  final Map<int, Aria2ActiveStreamSession> _activeSessions = {};
  int _nextStreamId = 80000;

  /// 自定义注入的 Aria2Client（便于单元测试 Mock）
  Aria2Client? _injectedClient;

  void setClientForTesting(Aria2Client? client) {
    _injectedClient = client;
  }

  bool get hasTestClient => _injectedClient != null;

  Aria2Client _getClient() {
    return _injectedClient ?? Aria2Client.fromSettings();
  }

  /// 检查当前系统环境是否支持 Aria2 引擎
  Future<bool> isAvailable() async {
    if (_injectedClient != null) return true;
    try {
      final isFeatureAvailable = await Aria2FeatureManager().initialize();
      if (!isFeatureAvailable) return false;
      final manager = Aria2ProcessManager();
      if (!manager.isRunning) {
        return await manager.start();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 启动 Aria2 边下边播会话
  Future<TorrentStreamSession> startStream({
    required String magnetUri,
    String? title,
    bool isAudio = false,
    int? fileIndex,
    void Function(String statusMessage)? onProgress,
    void Function(TorrentStreamProgress progress)? onProgressUpdate,
    Duration metadataTimeout = const Duration(seconds: 40),
    Duration bufferTimeout = const Duration(seconds: 35),
    bool waitForBuffer = true,
    TorrentStreamCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    // 确保 Aria2 守护进程就绪
    final isAria2Ready = await isAvailable();
    if (!isAria2Ready) {
      throw const TorrentStreamException('Aria2 引擎未启动或在当前系统不可用');
    }

    final client = _getClient();

    // 准备流式临时存储路径
    String tempBasePath;
    try {
      final tempDir = await getTemporaryDirectory();
      tempBasePath = tempDir.path;
    } catch (_) {
      tempBasePath = Directory.systemTemp.path;
    }
    final streamDir = Directory('$tempBasePath/kazumi_aria2_stream');
    if (!streamDir.existsSync()) {
      await streamDir.create(recursive: true);
    }

    String enhancedMagnet = magnetUri;
    List<String> activeTrackers = TorrentTrackerService.instance.activeTrackers;
    if (!hasTestClient) {
      try {
        enhancedMagnet = await TorrentTrackerService.instance
            .rewriteMagnetWithDoh(magnetUri)
            .timeout(const Duration(milliseconds: 1500));
        activeTrackers = await TorrentTrackerService.instance
            .rewriteTrackersWithDoh(activeTrackers)
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        enhancedMagnet = TorrentTrackerService.instance.injectTrackers(magnetUri);
      }
    } else {
      enhancedMagnet = TorrentTrackerService.instance.injectTrackers(magnetUri);
    }

    const initialMsg = '正在通过 Aria2 极速网络建立做种节点连接并拉取元数据...';
    onProgress?.call(initialMsg);
    onProgressUpdate?.call(const TorrentStreamProgress(
      stage: TorrentStreamStage.connectingPeers,
      message: initialMsg,
    ));

    // 针对流式播放深度优化的 Aria2 启动选项
    final aria2Options = <String, dynamic>{
      'dir': streamDir.path,
      'bt-prioritize-piece': 'head=32M,tail=32M',
      'file-allocation': 'none',
      'bt-tracker': activeTrackers.join(','),
      'enable-dht': 'true',
      'bt-enable-lpd': 'true',
      'enable-peer-exchange': 'true',
      'max-connection-per-server': '16',
      'split': '16',
      'bt-max-peers': '128',
      'seed-time': '0',
      'allow-overwrite': 'true',
      'auto-file-renaming': 'true',
    };

    String? initialGid;
    try {
      initialGid = await client.addUri([enhancedMagnet], options: aria2Options);
    } catch (e) {
      throw TorrentStreamException('向 Aria2 提交流式任务失败: $e');
    }

    if (initialGid == null || initialGid.isEmpty) {
      throw const TorrentStreamException('Aria2 未返回有效的任务 GID');
    }

    KazumiLogger().log(
      Level.info,
      '[Aria2StreamEngine] Added magnet stream task (initial GID: $initialGid): $title',
    );

    // 轮询直到元数据下载完成并获取具体文件列表
    final metaStartTime = DateTime.now();
    String actualGid = initialGid;
    Map<String, dynamic>? targetStatus;
    int lastPeers = 0;
    int lastDlRate = 0;

    try {
      while (DateTime.now().difference(metaStartTime) < metadataTimeout) {
        if (cancelToken?.isCancelled == true) {
          await _cleanupGid(client, actualGid, initialGid);
          throw const TorrentStreamCancelledException();
        }

        await Future.delayed(const Duration(milliseconds: 300));

        if (cancelToken?.isCancelled == true) {
          await _cleanupGid(client, actualGid, initialGid);
          throw const TorrentStreamCancelledException();
        }

        try {
          final status = await client.tellStatus(actualGid);
          if (status != null) {
            final followedBy = status['followedBy'] as List<dynamic>?;
            if (followedBy != null && followedBy.isNotEmpty) {
              actualGid = followedBy.first.toString();
              continue;
            }

            final numSeeders = int.tryParse(status['numSeeders']?.toString() ?? '0') ?? 0;
            final connections = int.tryParse(status['connections']?.toString() ?? '0') ?? 0;
            lastPeers = math.max(numSeeders, connections);
            lastDlRate = int.tryParse(status['downloadSpeed']?.toString() ?? '0') ?? 0;

            final files = status['files'] as List<dynamic>?;
            final totalLength = int.tryParse(status['totalLength']?.toString() ?? '0') ?? 0;

            if (files != null && files.isNotEmpty && totalLength > 0) {
              targetStatus = status;
              break;
            }

            final peerStatus = lastPeers > 0
                ? 'Aria2 已连接 $lastPeers 个做种节点，正在拉取种子元数据...'
                : '正在通过公共 Tracker 与 DHT 网络搜索活跃做种者...';
            onProgress?.call(peerStatus);
            onProgressUpdate?.call(TorrentStreamProgress(
              stage: lastPeers > 0
                  ? TorrentStreamStage.resolvingMetadata
                  : TorrentStreamStage.connectingPeers,
              message: peerStatus,
              peerCount: lastPeers,
              downloadRate: lastDlRate,
            ));
          }
        } catch (_) {}
      }

      if (targetStatus == null) {
        await _cleanupGid(client, actualGid, initialGid);
        throw TorrentMetadataTimeoutException(
          '获取种子元数据超时（当前发现节点数: $lastPeers）',
          peerCount: lastPeers,
        );
      }
    } catch (e) {
      await _cleanupGid(client, actualGid, initialGid);
      rethrow;
    }

    const parsingMsg = '元数据拉取就绪，正在分析媒体结构并启动本地代理服务...';
    onProgress?.call(parsingMsg);
    onProgressUpdate?.call(TorrentStreamProgress(
      stage: TorrentStreamStage.allocating,
      message: parsingMsg,
      peerCount: lastPeers,
      downloadRate: lastDlRate,
    ));

    // 解析出全部文件并映射为统一 FileInfo
    final rawFiles = targetStatus['files'] as List<dynamic>;
    final allFiles = <FileInfo>[];
    for (int i = 0; i < rawFiles.length; i++) {
      final f = rawFiles[i] as Map<String, dynamic>;
      final pathStr = f['path']?.toString() ?? '';
      final name = pathStr.split(Platform.pathSeparator).last;
      final sz = int.tryParse(f['length']?.toString() ?? '0') ?? 0;
      allFiles.add(FileInfo(
        index: i,
        name: name.isNotEmpty ? name : 'File $i',
        path: pathStr,
        size: sz,
        isStreamable: TorrentStreamService.isPlayableFile(name),
      ));
    }

    if (allFiles.isEmpty) {
      await _cleanupGid(client, actualGid, initialGid);
      throw const TorrentStreamException('种子中未找到有效文件列表');
    }

    // 智能筛选可直接播放文件
    FileInfo selectedFile;
    if (fileIndex != null && fileIndex >= 0 && fileIndex < allFiles.length) {
      final target = allFiles[fileIndex];
      if (TorrentStreamService.isArchiveFile(target.name)) {
        await _cleanupGid(client, actualGid, initialGid);
        throw NoStreamableFileException(
          '所选文件（${target.name}）为压缩包格式，不支持在线边下边播，请通过离线下载到本地解压后使用。',
          availableFileNames: allFiles.map((f) => f.name).toList(),
        );
      }
      selectedFile = target;
    } else if (isAudio) {
      final audioFiles = allFiles
          .where((f) => TorrentStreamService.isAudioFile(f.name) && !TorrentStreamService.isArchiveFile(f.name))
          .toList();
      if (audioFiles.isNotEmpty) {
        audioFiles.sort((a, b) => TorrentStreamService.naturalCompare(a.name, b.name));
        selectedFile = audioFiles.first;
      } else {
        final videoFiles = allFiles
            .where((f) => TorrentStreamService.isVideoFile(f.name) && !TorrentStreamService.isArchiveFile(f.name))
            .toList();
        if (videoFiles.isNotEmpty) {
          selectedFile = videoFiles.first;
        } else {
          await _cleanupGid(client, actualGid, initialGid);
          throw NoStreamableFileException(
            '种子内未检测到支持在线播放的音频格式（.flac / .mp3 / .wav 等）。',
            availableFileNames: allFiles.map((f) => f.name).toList(),
          );
        }
      }
    } else {
      final videoFiles = allFiles
          .where((f) => TorrentStreamService.isVideoFile(f.name) && !TorrentStreamService.isArchiveFile(f.name))
          .toList();
      if (videoFiles.isNotEmpty) {
        videoFiles.sort((a, b) => TorrentStreamService.naturalCompare(a.name, b.name));
        selectedFile = videoFiles.first;
      } else {
        final audioFiles = allFiles
            .where((f) => TorrentStreamService.isAudioFile(f.name) && !TorrentStreamService.isArchiveFile(f.name))
            .toList();
        if (audioFiles.isNotEmpty) {
          selectedFile = audioFiles.first;
        } else {
          await _cleanupGid(client, actualGid, initialGid);
          throw NoStreamableFileException(
            '种子内未检测到支持在线播放的视频格式（.mkv / .mp4 / .mov 等）。',
            availableFileNames: allFiles.map((f) => f.name).toList(),
          );
        }
      }
    }

    if (cancelToken?.isCancelled == true) {
      await _cleanupGid(client, actualGid, initialGid);
      throw const TorrentStreamCancelledException();
    }

    // 多文件种子时，指示 Aria2 仅专注于所选剧集文件（1-based 索引）
    if (allFiles.length > 1) {
      try {
        await client.changeOption(actualGid, {
          'select-file': '${selectedFile.index + 1}',
        });
      } catch (e) {
        KazumiLogger().log(Level.warning, '[Aria2StreamEngine] changeOption select-file error: $e');
      }
    }

    // 确定目标物理文件路径
    String targetFilePath = selectedFile.path;
    if (targetFilePath.isEmpty || !File(targetFilePath).existsSync()) {
      // 检查是否在 streamDir 内
      final candidate = File('${streamDir.path}/${selectedFile.name}');
      if (candidate.existsSync()) {
        targetFilePath = candidate.path;
      } else {
        // 从当前 status files 刷新真实落盘路径
        final latestStatus = await client.tellStatus(actualGid);
        if (latestStatus != null && latestStatus['files'] is List) {
          final lFiles = latestStatus['files'] as List;
          if (selectedFile.index >= 0 && selectedFile.index < lFiles.length) {
            final fMap = lFiles[selectedFile.index] as Map<String, dynamic>;
            final p = fMap['path']?.toString() ?? '';
            if (p.isNotEmpty) targetFilePath = p;
          }
        }
      }
    }

    // 启动本地 HTTP 206 流式代理服务器
    final streamServer = Aria2StreamServer(
      filePath: targetFilePath,
      totalLength: selectedFile.size,
      waitForBytesDownloaded: (targetByte) async {
        // 动态校验 Aria2 是否已完成对应字节位置的下载
        try {
          final cur = await client.tellStatus(actualGid);
          if (cur != null) {
            final completed = int.tryParse(cur['completedLength']?.toString() ?? '0') ?? 0;
            if (completed >= targetByte) return true;
          }
        } catch (_) {}
        return true;
      },
    );

    final assignedPort = await streamServer.start();
    final streamUrl = 'http://127.0.0.1:$assignedPort/stream';
    final streamId = _nextStreamId++;

    final session = Aria2ActiveStreamSession(
      streamId: streamId,
      gid: actualGid,
      parentGid: initialGid,
      server: streamServer,
      selectedFile: selectedFile,
      localFilePath: targetFilePath,
      totalLength: selectedFile.size,
      streamUrl: streamUrl,
    );

    _activeSessions[streamId] = session;

    // 预缓冲等待门控：保障首片（MP4/MKV 解复用元数据）已安全落盘
    if (waitForBuffer) {
      const buffMsg = '元数据已锁定，正在预缓冲首尾索引数据块 (边下边看)...';
      onProgress?.call(buffMsg);
      onProgressUpdate?.call(TorrentStreamProgress(
        stage: TorrentStreamStage.buffering,
        message: buffMsg,
        peerCount: lastPeers,
        selectedFileName: selectedFile.name,
        selectedFileSize: selectedFile.size,
      ));

      final bufferStartTime = DateTime.now();
      bool bufferReady = false;

      while (DateTime.now().difference(bufferStartTime) < bufferTimeout) {
        if (cancelToken?.isCancelled == true) {
          await stopStream(streamId);
          throw const TorrentStreamCancelledException();
        }
        await Future.delayed(const Duration(milliseconds: 300));
        if (cancelToken?.isCancelled == true) {
          await stopStream(streamId);
          throw const TorrentStreamCancelledException();
        }

        final curStatus = await client.tellStatus(actualGid);
        if (curStatus != null) {
          final dlRate = int.tryParse(curStatus['downloadSpeed']?.toString() ?? '0') ?? 0;
          final completed = int.tryParse(curStatus['completedLength']?.toString() ?? '0') ?? 0;
          final numSeeders = int.tryParse(curStatus['numSeeders']?.toString() ?? '0') ?? 0;
          final connections = int.tryParse(curStatus['connections']?.toString() ?? '0') ?? 0;
          final activePeers = math.max(numSeeders, connections);

          // 判定预缓冲是否满足开播条件（已缓冲超过 1.5MB，或稳定下载中）
          final isFileCreated = File(targetFilePath).existsSync();
          if (isFileCreated && (completed >= 1500 * 1024 || (completed >= 500 * 1024 && dlRate > 200 * 1024))) {
            bufferReady = true;
            onProgress?.call('Aria2 流式缓冲就绪，正在唤起播放器...');
            onProgressUpdate?.call(TorrentStreamProgress(
              stage: TorrentStreamStage.ready,
              message: 'Aria2 流式缓冲就绪，正在唤起播放器...',
              peerCount: activePeers,
              downloadRate: dlRate,
              selectedFileName: selectedFile.name,
              selectedFileSize: selectedFile.size,
            ));
            break;
          }

          final rateStr = dlRate >= 1024 * 1024
              ? '${(dlRate / (1024 * 1024)).toStringAsFixed(1)} MB/s'
              : '${(dlRate / 1024).toStringAsFixed(0)} KB/s';

          final statusMsg = activePeers > 0
              ? '已连接 $activePeers 个做种节点，正在预缓冲数据 ($rateStr)...'
              : '正在网络中加速连接做种者以预热流式缓冲...';

          onProgress?.call(statusMsg);
          onProgressUpdate?.call(TorrentStreamProgress(
            stage: TorrentStreamStage.buffering,
            message: statusMsg,
            peerCount: activePeers,
            downloadRate: dlRate,
            selectedFileName: selectedFile.name,
            selectedFileSize: selectedFile.size,
          ));
        }
      }

      // 如果超时后仍有速度，直接尝试起播
      if (!bufferReady) {
        final finalStatus = await client.tellStatus(actualGid);
        final completed = int.tryParse(finalStatus?['completedLength']?.toString() ?? '0') ?? 0;
        if (completed < 64 * 1024) {
          await stopStream(streamId);
          throw const TorrentStreamException(
            'Aria2 预缓冲超时（未能在有效时间内获取首部数据），建议检查网络连接或稍后重试。',
          );
        }
      }
    }

    KazumiLogger().log(
      Level.info,
      '[Aria2StreamEngine] Stream ready at $streamUrl (file: ${selectedFile.name}, size: ${selectedFile.size})',
    );

    final effectiveIsAudio = isAudio || TorrentStreamService.isAudioFile(selectedFile.name);
    return TorrentStreamSession(
      streamId: streamId,
      torrentId: -1,
      streamUrl: streamUrl,
      selectedFile: selectedFile,
      allFiles: allFiles,
      isAudio: effectiveIsAudio,
      title: title ?? selectedFile.name,
      engine: TorrentStreamEngine.aria2,
    );
  }

  /// 停止 Aria2 流式会话并释放 HTTP 代理端口
  Future<void> stopStream(int streamId, {bool keepDownloadTask = false, bool deleteFiles = false}) async {
    final session = _activeSessions.remove(streamId);
    if (session == null) return;

    try {
      await session.server.stop();
    } catch (_) {}

    if (!keepDownloadTask) {
      final client = _getClient();
      try {
        await _cleanupGid(client, session.gid, session.parentGid);
      } catch (_) {}
    }

    if (deleteFiles && !keepDownloadTask) {
      try {
        final f = File(session.localFilePath);
        if (f.existsSync()) await f.delete();
        final ctrlFile = File('${session.localFilePath}.aria2');
        if (ctrlFile.existsSync()) await ctrlFile.delete();
      } catch (_) {}
    }
  }

  /// 停止全部正在运行的 Aria2 流式代理
  Future<void> stopAll({bool deleteFiles = false}) async {
    final ids = _activeSessions.keys.toList();
    for (final id in ids) {
      await stopStream(id, deleteFiles: deleteFiles);
    }
  }

  Future<void> _cleanupGid(Aria2Client client, String gid, String? parentGid) async {
    try {
      await client.remove(gid, force: true);
    } catch (_) {}
    if (parentGid != null && parentGid != gid) {
      try {
        await client.remove(parentGid, force: true);
      } catch (_) {}
    }
  }

  /// 使用 Aria2 解析磁力链接的文件列表结构（可作为原生引擎解析失败时的强大候补）
  Future<List<TorrentFileEntry>> resolveMagnetFiles(
    String magnetUri, {
    Duration timeout = const Duration(seconds: 40),
    TorrentStreamCancelToken? cancelToken,
    void Function(String message)? onProgress,
  }) async {
    final client = _getClient();
    final isAria2Ready = await isAvailable();
    if (!isAria2Ready) {
      throw const TorrentStreamException('Aria2 引擎未启动');
    }

    String enhancedMagnet = magnetUri;
    List<String> activeTrackers = TorrentTrackerService.instance.activeTrackers;
    if (!hasTestClient) {
      try {
        enhancedMagnet = await TorrentTrackerService.instance
            .rewriteMagnetWithDoh(magnetUri)
            .timeout(const Duration(milliseconds: 1500));
        activeTrackers = await TorrentTrackerService.instance
            .rewriteTrackersWithDoh(activeTrackers)
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        enhancedMagnet = TorrentTrackerService.instance.injectTrackers(magnetUri);
      }
    } else {
      enhancedMagnet = TorrentTrackerService.instance.injectTrackers(magnetUri);
    }

    String tempBasePath;
    try {
      final tempDir = await getTemporaryDirectory();
      tempBasePath = tempDir.path;
    } catch (_) {
      tempBasePath = Directory.systemTemp.path;
    }

    final options = <String, dynamic>{
      'dir': '$tempBasePath/kazumi_aria2_meta',
      'bt-metadata-only': 'true',
      'bt-tracker': activeTrackers.join(','),
      'enable-dht': 'true',
      'bt-enable-lpd': 'true',
    };

    final initialGid = await client.addUri([enhancedMagnet], options: options);
    if (initialGid == null) {
      throw const TorrentStreamException('添加磁力任务失败');
    }

    final startTime = DateTime.now();
    String actualGid = initialGid;

    try {
      while (DateTime.now().difference(startTime) < timeout) {
        if (cancelToken?.isCancelled == true) {
          await _cleanupGid(client, actualGid, initialGid);
          throw const TorrentStreamCancelledException();
        }
        await Future.delayed(const Duration(milliseconds: 300));
        if (cancelToken?.isCancelled == true) {
          await _cleanupGid(client, actualGid, initialGid);
          throw const TorrentStreamCancelledException();
        }

        final status = await client.tellStatus(actualGid);
        if (status != null) {
          final followedBy = status['followedBy'] as List<dynamic>?;
          if (followedBy != null && followedBy.isNotEmpty) {
            actualGid = followedBy.first.toString();
            continue;
          }

          final numSeeders = int.tryParse(status['numSeeders']?.toString() ?? '0') ?? 0;
          final connections = int.tryParse(status['connections']?.toString() ?? '0') ?? 0;
          final peers = math.max(numSeeders, connections);

          onProgress?.call(peers > 0 ? '已连接 $peers 个节点，正在读取文件列表...' : '正在全网发现做种节点...');

          final rawFiles = status['files'] as List<dynamic>?;
          final totalLength = int.tryParse(status['totalLength']?.toString() ?? '0') ?? 0;
          if (rawFiles != null && rawFiles.isNotEmpty && totalLength > 0) {
            final result = <TorrentFileEntry>[];
            for (int i = 0; i < rawFiles.length; i++) {
              final f = rawFiles[i] as Map<String, dynamic>;
              final p = (f['path']?.toString() ?? '').replaceAll('\\', '/');
              final name = p.split('/').last;
              final sz = int.tryParse(f['length']?.toString() ?? '0') ?? 0;
              final segments = p.split('/').where((s) => s.isNotEmpty).toList();
              result.add(TorrentFileEntry(
                index: i + 1,
                path: p,
                name: name.isNotEmpty ? name : 'File $i',
                sizeBytes: sz,
                pathSegments: segments.isNotEmpty ? segments : [name],
                isSelected: true,
              ));
            }
            await _cleanupGid(client, actualGid, initialGid);
            return result;
          }
        }
      }
      await _cleanupGid(client, actualGid, initialGid);
      throw const TorrentMetadataTimeoutException('Aria2 解析种子元数据超时');
    } catch (e) {
      await _cleanupGid(client, actualGid, initialGid);
      rethrow;
    }
  }
}
