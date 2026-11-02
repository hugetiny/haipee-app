import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
export 'package:haipee/modules/torrent_stream/torrent_stream_models.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_stream/torrserver_stream_engine.dart';
import 'package:haipee/modules/torrent_stream/torrserver_client.dart';
import 'package:haipee/modules/torrent_stream/torrent_tracker_service.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/services/logging/app_log.dart' hide HaipeeLogger;
import 'package:haipee/services/logging/log_module.dart';
import 'package:haipee/modules/debrid/debrid_service.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:logger/logger.dart';

/// Exception thrown when a torrent streaming operation fails.
class TorrentStreamException implements Exception {
  final String message;
  const TorrentStreamException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when DHT / tracker peer discovery times out resolving metadata.
class TorrentMetadataTimeoutException extends TorrentStreamException {
  final int peerCount;
  const TorrentMetadataTimeoutException(super.message, {this.peerCount = 0});
}

/// Token allowing callers to cancel ongoing torrent metadata discovery or stream connection.
class TorrentStreamCancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Exception thrown when a torrent streaming operation is cancelled by the user.
class TorrentStreamCancelledException extends TorrentStreamException {
  const TorrentStreamCancelledException([super.message = '用户已取消等待']);
}

/// Exception thrown when a torrent contains only compressed archives or non-streamable files.
class NoStreamableFileException extends TorrentStreamException {
  final List<String> availableFileNames;
  const NoStreamableFileException(super.message, {this.availableFileNames = const []});
}

/// 流式边下边播引擎类型
enum TorrentStreamEngine {
  auto,        // 智能双引擎互保
  debrid,      // Debrid 云端高速离线 Hub (Real-Debrid / TorBox / PikPak)
  torrserver,  // TorrServer 专精视频流式引擎 (纯内存环形缓冲，少节点网络穿透，MP4/MKV首尾索引预读)
  native,      // 原生 Libtorrent C++ 引擎 (内存滑窗分片调度)
}

/// 标识流式准备的不同执行阶段
enum TorrentStreamStage {
  connectingPeers,     // 正在搜索网络做种节点
  resolvingMetadata,   // 已发现节点，正在拉取种子文件结构
  allocating,          // 准备流式引擎存储与分片调度
  buffering,           // 正在预缓冲首尾关键分片 (边下边看)
  ready,               // 首帧就绪，即将唤起播放器
  failed,              // 发生错误或超时
}

/// 流式准备进度详情快照
class TorrentStreamProgress {
  final TorrentStreamStage stage;
  final String message;
  final int peerCount;
  final int downloadRate; // bytes/sec
  final double bufferSeconds;
  final int bufferPieces;
  final double? bufferPercent;
  final String? selectedFileName;
  final int? selectedFileSize;
  final TorrentStreamEngine engine;

  const TorrentStreamProgress({
    required this.stage,
    required this.message,
    this.peerCount = 0,
    this.downloadRate = 0,
    this.bufferSeconds = 0.0,
    this.bufferPieces = 0,
    this.bufferPercent,
    this.selectedFileName,
    this.selectedFileSize,
    this.engine = TorrentStreamEngine.native,
  });

  String get formattedSpeed {
    if (downloadRate <= 0) return '0 KB/s';
    if (downloadRate >= 1024 * 1024) {
      return '${(downloadRate / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(downloadRate / 1024).toStringAsFixed(0)} KB/s';
  }

  @override
  String toString() =>
      'TorrentStreamProgress(stage: $stage, msg: $message, peers: $peerCount, speed: $formattedSpeed, engine: $engine, bufSec: ${bufferSeconds.toStringAsFixed(1)}s)';
}

/// Represents an active torrent streaming session with local HTTP server endpoints.
class TorrentStreamSession {
  final int streamId;
  final int torrentId;
  final String streamUrl;
  final FileInfo? selectedFile;
  final List<FileInfo> allFiles;
  final bool isAudio;
  final String title;
  final TorrentStreamEngine engine;

  const TorrentStreamSession({
    required this.streamId,
    required this.torrentId,
    required this.streamUrl,
    this.selectedFile,
    required this.allFiles,
    required this.isAudio,
    required this.title,
    this.engine = TorrentStreamEngine.native,
  });

  @override
  String toString() =>
      'TorrentStreamSession(streamId: $streamId, torrentId: $torrentId, engine: $engine, file: ${selectedFile?.name}, url: $streamUrl)';
}

/// Abstract adapter for the underlying torrent engine to facilitate testing and mock injection.
abstract class TorrentEngineAdapter {
  bool get isInitialized;
  String get libraryVersion;

  Future<void> init({
    String? defaultSavePath,
    bool fetchTrackers = true,
    Duration pollInterval = const Duration(milliseconds: 250),
  });

  int addMagnet(String magnetUri, {String? savePath, bool streamOnly = false});
  TorrentInfo? getTorrentInfo(int torrentId);
  StreamInfo? getStreamInfo(int streamId);
  List<FileInfo> getFiles(int torrentId);
  void setFilePriorities(int torrentId, List<int> priorities);
  StreamInfo startStream(int torrentId, {int fileIndex = -1, int maxCacheBytes = 0});
  void stopStream(int streamId);
  void removeTorrent(int torrentId, {bool deleteFiles = false});
  bool preloadStream(int streamId, {int preloadBytes = 0});
  void configureSession(BtConfig config);
  Stream<Map<int, TorrentInfo>> get torrentUpdates;
  Stream<Map<int, StreamInfo>> get streamUpdates;
}

/// Default production adapter. In production, TorrServer is the primary streaming engine.
class DefaultTorrentEngineAdapter implements TorrentEngineAdapter {
  bool _initialized = false;
  final StreamController<Map<int, TorrentInfo>> _torrentUpdatesController =
      StreamController<Map<int, TorrentInfo>>.broadcast();
  final StreamController<Map<int, StreamInfo>> _streamUpdatesController =
      StreamController<Map<int, StreamInfo>>.broadcast();

  @override
  bool get isInitialized => _initialized;

  @override
  String get libraryVersion => 'haipee-embedded';

  @override
  Future<void> init({
    String? defaultSavePath,
    bool fetchTrackers = true,
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    _initialized = true;
  }

  @override
  int addMagnet(String magnetUri, {String? savePath, bool streamOnly = false}) => 1;

  @override
  TorrentInfo? getTorrentInfo(int torrentId) => const TorrentInfo();

  @override
  StreamInfo? getStreamInfo(int streamId) => const StreamInfo();

  @override
  List<FileInfo> getFiles(int torrentId) => const [];

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {}

  @override
  StreamInfo startStream(int torrentId, {int fileIndex = -1, int maxCacheBytes = 0}) =>
      const StreamInfo();

  @override
  void stopStream(int streamId) {}

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {}

  @override
  bool preloadStream(int streamId, {int preloadBytes = 0}) => true;

  @override
  void configureSession(BtConfig config) {}

  @override
  Stream<Map<int, TorrentInfo>> get torrentUpdates => _torrentUpdatesController.stream;

  @override
  Stream<Map<int, StreamInfo>> get streamUpdates => _streamUpdatesController.stream;
}


/// Service managing native libtorrent streaming sessions for on-demand online video & audio playback.
class TorrentStreamService {
  static final TorrentStreamService instance = TorrentStreamService._internal();

  TorrentStreamService._internal();

  TorrentEngineAdapter _adapter = DefaultTorrentEngineAdapter();
  bool _nativeEngineAvailable = true;

  /// 原生引擎是否可用（如动态链接库加载成功）
  bool get isNativeEngineAvailable => _nativeEngineAvailable;

  /// Inject custom adapter for unit testing.
  void setAdapterForTesting(TorrentEngineAdapter adapter) {
    _adapter = adapter;
    _nativeEngineAvailable = true;
  }

  /// Reset adapter to default.
  void resetAdapter() {
    _adapter = DefaultTorrentEngineAdapter();
    _nativeEngineAvailable = true;
  }

  final Map<int, TorrentStreamSession> _activeSessions = {};
  StreamSubscription? _torrentUpdatesSub;
  StreamSubscription? _streamUpdatesSub;

  void _listenToEngineUpdates() {
    _torrentUpdatesSub?.cancel();
    _streamUpdatesSub?.cancel();

    _torrentUpdatesSub = _adapter.torrentUpdates.listen((torrents) {
      for (final t in torrents.values) {
        if (t.errorMsg.isNotEmpty) {
          AppLog.w(LogModule.stream, '[Libtorrent] Torrent #${t.id} alert: ${t.errorMsg}');
        }
      }
    }, onError: (e) {
      AppLog.d(LogModule.stream, '[Libtorrent] torrentUpdates error: $e');
    });

    _streamUpdatesSub = _adapter.streamUpdates.listen((streams) {
      for (final s in streams.values) {
        if (s.streamState == StreamState.error) {
          AppLog.w(LogModule.stream, '[Libtorrent] Stream #${s.id} alert: stream error');
        }
      }
    }, onError: (e) {
      AppLog.d(LogModule.stream, '[Libtorrent] streamUpdates error: $e');
    });
  }

  /// 保持向后兼容的公开 Tracker 列表
  static List<String> get defaultTrackers => TorrentTrackerService.defaultTrackers;

  /// 当前所有活跃 Trackers
  List<String> get activeTrackers => TorrentTrackerService.instance.activeTrackers;

  static const Set<String> _audioExtensions = {
    '.mp3', '.flac', '.wav', '.ape', '.dsd', '.dsf', '.dff', '.alac',
    '.ogg', '.m4a', '.aac', '.opus', '.wma'
  };

  static const Set<String> _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv',
    '.webm', '.m4v', '.ts', '.m2ts', '.rmvb', '.rm', '.mpg', '.mpeg'
  };

  static bool isAudioFile(String name) {
    final lower = name.toLowerCase();
    for (final ext in _audioExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  static bool isVideoFile(String name) {
    final lower = name.toLowerCase();
    for (final ext in _videoExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  static const Set<String> _archiveExtensions = {
    '.zip', '.rar', '.7z', '.tar', '.gz', '.xz', '.bz2',
    '.tgz', '.tbz2', '.iso', '.dmg', '.bin', '.cue', '.exe',
    '.apk', '.pkg', '.7z.001', '.z01', '.r00'
  };

  /// 判定文件是否为压缩包、镜像或执行文件格式（此类格式不可直接在线边下边播）
  static bool isArchiveFile(String name) {
    final lower = name.toLowerCase().trim();
    for (final ext in _archiveExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  /// 判定文件是否属于可直接在线流式播放的音视频文件
  static bool isPlayableFile(String name) {
    return (isAudioFile(name) || isVideoFile(name)) && !isArchiveFile(name);
  }

  /// Natural/alphanumeric comparator for track filenames (e.g. "01. Song", "2. Song", "10. Song").
  static int naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+)|(\D+)');
    final matchesA = regex.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
    final matchesB = regex.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
    final len = math.min(matchesA.length, matchesB.length);
    for (int i = 0; i < len; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);
      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = partA.compareTo(partB);
        if (comp != 0) return comp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  /// Enhances magnet URI with trackers.
  static String injectTrackers(String magnetUri) {
    return TorrentTrackerService.instance.injectTrackers(magnetUri);
  }

  /// Initializes the streaming engine if not yet initialized.
  Future<void> ensureInitialized() async {
    if (_adapter.isInitialized) return;
    String tempPath;
    try {
      final tempDir = await getTemporaryDirectory();
      tempPath = tempDir.path;
    } catch (_) {
      tempPath = Directory.systemTemp.path;
    }
    final cacheDir = Directory('$tempPath/haipee_stream_cache');
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }

    AppLog.i(
      LogModule.stream,
      '[TorrentStreamService] Initializing libtorrent engine at ${cacheDir.path}',
    );

    try {
      await _adapter.init(
        defaultSavePath: cacheDir.path,
        fetchTrackers: true,
        pollInterval: const Duration(milliseconds: 250),
      );
      _nativeEngineAvailable = true;
      _listenToEngineUpdates();
    } catch (e) {
      _nativeEngineAvailable = false;
      AppLog.w(
        LogModule.stream,
        '[TorrentStreamService] Native libtorrent init failed: $e (TorrServer engine will be used)',
      );
      return;
    }

    // 应用高吞吐、低延迟的流式缓冲与网络连接配置（启用 IPv6 直连穿透与 256MB 内存滑窗）
    try {
      const config = BtConfig(
        cacheSize: 256 * 1024 * 1024,
        readerReadAhead: 95,
        preloadCache: 50,
        connectionsLimit: 120,
        torrentDisconnectTimeout: 30,
        forceEncrypt: false,
        disableTcp: false,
        disableUtp: false,
        disableUpload: false,
        disableDht: false,
        disableUpnp: false,
        enableIpv6: true,
        downloadRateLimit: 0,
        uploadRateLimit: 0,
        peersListenPort: 0,
        responsiveMode: true,
      );
      _adapter.configureSession(config);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '[TorrentStreamService] configureSession error: $e');
    }
  }

  /// 启动在线边下边播会话（支持双引擎自动互保及无缝回退）
  Future<TorrentStreamSession> startStream({
    required String magnetUri,
    String? torrentUrl,
    String? title,
    bool isAudio = false,
    int? fileIndex,
    void Function(String statusMessage)? onProgress,
    void Function(TorrentStreamProgress progress)? onProgressUpdate,
    Duration metadataTimeout = const Duration(seconds: 40),
    Duration bufferTimeout = const Duration(seconds: 35),
    bool waitForBuffer = true,
    TorrentStreamCancelToken? cancelToken,
    TorrentStreamEngine engine = TorrentStreamEngine.auto,
  }) async {
    // 0. Debrid 云端高速离线直链 Pre-check (若已配置 Debrid 或显式指定 debrid 引擎)
    final debrid = DebridService.instance;
    if ((engine == TorrentStreamEngine.debrid || engine == TorrentStreamEngine.auto) &&
        debrid.isDebridEnabled) {
      try {
        onProgress?.call('正在探测云端高速直链缓存...');
        final directUrl = await debrid.tryResolveDebridStream(
          magnetUri,
          targetEpisode: (fileIndex ?? 0) + 1,
        );
        if (directUrl != null && directUrl.isNotEmpty) {
          HaipeeLogger().log(
            Level.info,
            '[TorrentStreamService] Debrid cache HIT! Playing directly from cloud CDN: $directUrl',
          );
          onProgress?.call('云端缓存命中，高速播放直链就绪！');
          onProgressUpdate?.call(TorrentStreamProgress(
            stage: TorrentStreamStage.ready,
            message: '云端缓存直链就绪 (${debrid.activeProvider?.name ?? "Debrid"})',
            peerCount: 99,
            downloadRate: 0,
            bufferSeconds: 60,
            bufferPieces: 100,
            bufferPercent: 1.0,
            selectedFileName: title ?? 'Debrid Cloud Stream',
            selectedFileSize: 0,
          ));
          final fileInfo = FileInfo(
            index: fileIndex ?? 0,
            name: title ?? 'Debrid Cloud Stream',
            path: directUrl,
            size: 0,
            isStreamable: true,
          );
          final session = TorrentStreamSession(
            streamUrl: directUrl,
            streamId: 999999,
            torrentId: 999999,
            selectedFile: fileInfo,
            allFiles: [fileInfo],
            isAudio: isAudio,
            title: title ?? 'Debrid Cloud Stream',
            engine: TorrentStreamEngine.debrid,
          );
          _activeSessions[session.streamId] = session;
          return session;
        }
      } catch (e) {
        HaipeeLogger().log(
          Level.warning,
          '[TorrentStreamService] Debrid check failed, falling back to local engine: $e',
        );
      }
    }

    // BEP 15 UDP Tracker DoH 防污染寻轨重写
    String effectiveMagnet = magnetUri;
    if (_adapter is DefaultTorrentEngineAdapter) {
      try {
        effectiveMagnet = await TorrentTrackerService.instance
            .rewriteMagnetWithDoh(magnetUri)
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        effectiveMagnet = injectTrackers(magnetUri);
      }
    } else {
      effectiveMagnet = injectTrackers(magnetUri);
    }

    // 决定实际使用的流式引擎
    TorrentStreamEngine effectiveEngine = engine;
    if (effectiveEngine == TorrentStreamEngine.auto) {
      // 若注入了自定义适配器（单元测试环境），尊重测试适配器的原生模拟
      if (_adapter is! DefaultTorrentEngineAdapter) {
        effectiveEngine = TorrentStreamEngine.native;
      } else if (!isAudio) {
        // 生产环境用户核心指令：在线看视频只用一种方案，彻底由专精流媒体的 TorrServer 引擎接管！
        effectiveEngine = TorrentStreamEngine.torrserver;
      } else {
        try {
          final savedSetting = GStorage.setting.get(
            SettingBoxKey.defaultTorrentStreamEngine,
            defaultValue: 'torrserver',
          ) as String;
          if (savedSetting == 'native') {
            effectiveEngine = TorrentStreamEngine.native;
          } else {
            effectiveEngine = TorrentStreamEngine.torrserver;
          }
        } catch (_) {}
      }
    }

    if (effectiveEngine == TorrentStreamEngine.torrserver ||
        !_nativeEngineAvailable) {
      HaipeeLogger().log(
        Level.info,
        '[TorrentStreamService] Launching dedicated TorrServer stream: $title',
      );
      final session = await TorrServerStreamEngine.instance.startStream(
        magnetUri: effectiveMagnet,
        torrentUrl: torrentUrl,
        title: title,
        isAudio: isAudio,
        fileIndex: fileIndex,
        onProgress: onProgress,
        onProgressUpdate: onProgressUpdate,
        metadataTimeout: metadataTimeout,
        bufferTimeout: bufferTimeout,
        waitForBuffer: waitForBuffer,
        cancelToken: cancelToken,
      );
      _activeSessions[session.streamId] = session;
      return session;
    }

    // 尝试原生 libtorrent 引擎
    try {
      await ensureInitialized();
      if (!_nativeEngineAvailable) {
        throw const TorrentStreamException('原生 libtorrent 引擎在当前环境不可用');
      }

      // 在 auto 模式下，设置灵敏的元数据拉取上限（至多 15s），若无节点或被防火墙屏蔽，自动转入 TorrServer 互保
      final metaTimeoutToUse = effectiveEngine == TorrentStreamEngine.auto
          ? (metadataTimeout < const Duration(seconds: 15)
              ? metadataTimeout
              : const Duration(seconds: 15))
          : metadataTimeout;

      return await _startNativeStream(
        magnetUri: effectiveMagnet,
        title: title,
        isAudio: isAudio,
        fileIndex: fileIndex,
        onProgress: onProgress,
        onProgressUpdate: onProgressUpdate,
        metadataTimeout: metaTimeoutToUse,
        bufferTimeout: bufferTimeout,
        waitForBuffer: waitForBuffer,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (cancelToken?.isCancelled == true) rethrow;
      if (e is NoStreamableFileException) rethrow;

      // 在 auto 智能双引擎模式下，当原生引擎遇到任何异常或超时，自动无缝切换到 TorrServer
      if (effectiveEngine == TorrentStreamEngine.auto && _adapter is DefaultTorrentEngineAdapter) {
        final torrServerReady = await TorrServerStreamEngine.instance.isAvailable();
        if (torrServerReady) {
          HaipeeLogger().log(
            Level.info,
            '[TorrentStreamService] Native stream unviable ($e). Seamlessly falling back to TorrServerStreamEngine...',
          );
          const fallbackMsg = '原生引擎连接超时或无做种者，已自动无缝切换至 TorrServer 流式引擎...';
          onProgress?.call(fallbackMsg);
          onProgressUpdate?.call(const TorrentStreamProgress(
            stage: TorrentStreamStage.connectingPeers,
            message: fallbackMsg,
            engine: TorrentStreamEngine.torrserver,
          ));

          final session = await TorrServerStreamEngine.instance.startStream(
            magnetUri: magnetUri,
            torrentUrl: torrentUrl,
            title: title,
            isAudio: isAudio,
            fileIndex: fileIndex,
            onProgress: onProgress,
            onProgressUpdate: onProgressUpdate,
            metadataTimeout: metadataTimeout,
            bufferTimeout: bufferTimeout,
            waitForBuffer: waitForBuffer,
            cancelToken: cancelToken,
          );
          _activeSessions[session.streamId] = session;
          return session;
        }
      }
      rethrow;
    }
  }

  /// 原生 libtorrent 核心流式实现
  Future<TorrentStreamSession> _startNativeStream({
    required String magnetUri,
    String? title,
    bool isAudio = false,
    int? fileIndex,
    void Function(String statusMessage)? onProgress,
    void Function(TorrentStreamProgress progress)? onProgressUpdate,
    required Duration metadataTimeout,
    required Duration bufferTimeout,
    required bool waitForBuffer,
    TorrentStreamCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    await stopAll(deleteFiles: true);

    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    final enhancedMagnet = injectTrackers(magnetUri);
    const initialMsg = '正在通过分布式 DHT 与公共 Tracker 网络查找活跃做种节点...';
    onProgress?.call(initialMsg);
    onProgressUpdate?.call(const TorrentStreamProgress(
      stage: TorrentStreamStage.connectingPeers,
      message: initialMsg,
      engine: TorrentStreamEngine.native,
    ));

    final torrentId = _adapter.addMagnet(enhancedMagnet, streamOnly: true);
    HaipeeLogger().log(
      Level.info,
      '[TorrentStreamService] Added stream magnet (id=$torrentId): $title',
    );

    final startTime = DateTime.now();
    bool metadataResolved = false;
    int lastPeers = 0;

    try {
      while (DateTime.now().difference(startTime) < metadataTimeout) {
        if (cancelToken?.isCancelled == true) {
          throw const TorrentStreamCancelledException();
        }
        await Future.delayed(const Duration(milliseconds: 250));
        if (cancelToken?.isCancelled == true) {
          throw const TorrentStreamCancelledException();
        }
        final info = _adapter.getTorrentInfo(torrentId);
        if (info != null) {
          lastPeers = info.numPeers;
          if (info.hasMetadata) {
            metadataResolved = true;
            break;
          }
          if (info.errorMsg.isNotEmpty) {
            throw TorrentStreamException('种子解析错误: ${info.errorMsg}');
          }
          final peerStatus = lastPeers > 0
              ? '已连接 $lastPeers 个做种节点，正在拉取种子文件结构...'
              : '正在全网搜索活跃 Peer 做种节点...';
          onProgress?.call(peerStatus);
          onProgressUpdate?.call(TorrentStreamProgress(
            stage: lastPeers > 0 ? TorrentStreamStage.resolvingMetadata : TorrentStreamStage.connectingPeers,
            message: peerStatus,
            peerCount: lastPeers,
            downloadRate: info.downloadRate,
            engine: TorrentStreamEngine.native,
          ));
        }
      }

      if (!metadataResolved) {
        throw TorrentMetadataTimeoutException(
          '获取种子元数据超时（当前发现节点数: $lastPeers）',
          peerCount: lastPeers,
        );
      }
    } catch (e) {
      _adapter.removeTorrent(torrentId, deleteFiles: true);
      rethrow;
    }

    const parsingMsg = '元数据解析成功，正在构建媒体流分片策略...';
    onProgress?.call(parsingMsg);
    onProgressUpdate?.call(TorrentStreamProgress(
      stage: TorrentStreamStage.allocating,
      message: parsingMsg,
      peerCount: lastPeers,
      engine: TorrentStreamEngine.native,
    ));

    List<FileInfo> files = _adapter.getFiles(torrentId);
    if (files.isEmpty) {
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        files = _adapter.getFiles(torrentId);
        if (files.isNotEmpty) break;
      }
    }

    if (files.isEmpty) {
      _adapter.removeTorrent(torrentId, deleteFiles: true);
      throw const TorrentStreamException('种子中未找到有效文件列表');
    }

    FileInfo selectedFile;
    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      final target = files[fileIndex];
      if (isArchiveFile(target.name)) {
        _adapter.removeTorrent(torrentId, deleteFiles: true);
        throw NoStreamableFileException(
          '所选文件（${target.name}）为压缩包格式，不支持在线边下边播，请通过离线下载到本地解压后使用。',
          availableFileNames: files.map((f) => f.name).toList(),
        );
      }
      selectedFile = target;
    } else if (isAudio) {
      final audioFiles = files.where((f) => isAudioFile(f.name) && !isArchiveFile(f.name)).toList();
      if (audioFiles.isNotEmpty) {
        audioFiles.sort((a, b) => naturalCompare(a.name, b.name));
        selectedFile = audioFiles.first;
      } else {
        final videoFiles = files.where((f) => (isVideoFile(f.name) || f.isStreamable) && !isArchiveFile(f.name)).toList();
        if (videoFiles.isNotEmpty) {
          selectedFile = videoFiles.first;
        } else {
          _adapter.removeTorrent(torrentId, deleteFiles: true);
          throw NoStreamableFileException(
            '种子内未检测到支持在线播放的音频格式（.flac / .mp3 / .wav 等）。',
            availableFileNames: files.map((f) => f.name).toList(),
          );
        }
      }
    } else {
      final videoFiles = files.where((f) => (isVideoFile(f.name) || f.isStreamable) && !isArchiveFile(f.name)).toList();
      if (videoFiles.isNotEmpty) {
        videoFiles.sort((a, b) => naturalCompare(a.name, b.name));
        selectedFile = videoFiles.first;
      } else {
        final audioFiles = files.where((f) => isAudioFile(f.name) && !isArchiveFile(f.name)).toList();
        if (audioFiles.isNotEmpty) {
          selectedFile = audioFiles.first;
        } else {
          _adapter.removeTorrent(torrentId, deleteFiles: true);
          throw NoStreamableFileException(
            '种子内未检测到支持在线播放的视频格式（.mkv / .mp4 / .mov 等）。',
            availableFileNames: files.map((f) => f.name).toList(),
          );
        }
      }
    }

    if (cancelToken?.isCancelled == true) {
      _adapter.removeTorrent(torrentId, deleteFiles: true);
      throw const TorrentStreamCancelledException();
    }

    final priorities = List<int>.filled(files.length, 0);
    if (selectedFile.index >= 0 && selectedFile.index < priorities.length) {
      priorities[selectedFile.index] = 7;
    }
    _adapter.setFilePriorities(torrentId, priorities);

    final streamInfo = _adapter.startStream(
      torrentId,
      fileIndex: selectedFile.index,
      maxCacheBytes: 500 * 1024 * 1024,
    );

    _adapter.preloadStream(streamInfo.id, preloadBytes: 16 * 1024 * 1024);

    final effectiveIsAudio = isAudio || isAudioFile(selectedFile.name);
    final session = TorrentStreamSession(
      streamId: streamInfo.id,
      torrentId: torrentId,
      streamUrl: streamInfo.url,
      selectedFile: selectedFile,
      allFiles: files,
      isAudio: effectiveIsAudio,
      title: title ?? selectedFile.name,
      engine: TorrentStreamEngine.native,
    );

    _activeSessions[streamInfo.id] = session;

    if (waitForBuffer) {
      const buffMsg = '元数据解析成功，正在预缓冲关键分片 (首尾索引)...';
      onProgress?.call(buffMsg);
      onProgressUpdate?.call(TorrentStreamProgress(
        stage: TorrentStreamStage.buffering,
        message: buffMsg,
        peerCount: lastPeers,
        selectedFileName: selectedFile.name,
        selectedFileSize: selectedFile.size,
        engine: TorrentStreamEngine.native,
      ));

      final bufferStartTime = DateTime.now();
      bool bufferReady = false;

      while (DateTime.now().difference(bufferStartTime) < bufferTimeout) {
        if (cancelToken?.isCancelled == true) {
          await stopStream(streamInfo.id, torrentId: torrentId);
          throw const TorrentStreamCancelledException();
        }
        await Future.delayed(const Duration(milliseconds: 250));
        if (cancelToken?.isCancelled == true) {
          await stopStream(streamInfo.id, torrentId: torrentId);
          throw const TorrentStreamCancelledException();
        }

        final sInfo = _adapter.getStreamInfo(streamInfo.id);
        final tInfo = _adapter.getTorrentInfo(torrentId);

        final activePeers = sInfo?.activePeers ?? tInfo?.numPeers ?? lastPeers;
        final dlRate = sInfo?.downloadRate ?? tInfo?.downloadRate ?? 0;
        final bufPieces = sInfo?.bufferPieces ?? 0;
        final bufSeconds = sInfo?.bufferSeconds ?? 0.0;

        if (bufPieces >= 1 ||
            bufSeconds >= 1.0 ||
            sInfo?.streamState == StreamState.ready ||
            (dlRate > 300 * 1024 && DateTime.now().difference(bufferStartTime).inSeconds >= 2)) {
          bufferReady = true;
          onProgress?.call('媒体流缓冲就绪，正在启动播放器...');
          onProgressUpdate?.call(TorrentStreamProgress(
            stage: TorrentStreamStage.ready,
            message: '媒体流缓冲就绪，正在启动播放器...',
            peerCount: activePeers,
            downloadRate: dlRate,
            bufferSeconds: bufSeconds,
            bufferPieces: bufPieces,
            selectedFileName: selectedFile.name,
            selectedFileSize: selectedFile.size,
            engine: TorrentStreamEngine.native,
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
          bufferSeconds: bufSeconds,
          bufferPieces: bufPieces,
          selectedFileName: selectedFile.name,
          selectedFileSize: selectedFile.size,
          engine: TorrentStreamEngine.native,
        ));
      }

      if (!bufferReady) {
        final finalSInfo = _adapter.getStreamInfo(streamInfo.id);
        final finalTInfo = _adapter.getTorrentInfo(torrentId);
        final finalPeers = finalSInfo?.activePeers ?? finalTInfo?.numPeers ?? 0;
        final finalRate = finalSInfo?.downloadRate ?? finalTInfo?.downloadRate ?? 0;

        if (finalPeers == 0 && finalRate == 0) {
          await stopStream(streamInfo.id, torrentId: torrentId);
          throw const TorrentStreamException(
            '媒体流预缓冲超时（网络中暂无可用数据传输），建议转入离线下载队列。',
          );
        }
      }
    }

    HaipeeLogger().log(
      Level.info,
      '[TorrentStreamService] Native stream ready at ${session.streamUrl} (file: ${selectedFile.name}, size: ${selectedFile.size})',
    );

    return session;
  }

  /// 解析磁力链接元数据并提取文件列表（支持双引擎自动互保）
  Future<List<TorrentFileEntry>> resolveMagnetFiles(
    String magnetUri, {
    Duration metadataTimeout = const Duration(seconds: 35),
    void Function(String statusMessage)? onProgress,
    TorrentStreamCancelToken? cancelToken,
    TorrentStreamEngine engine = TorrentStreamEngine.auto,
  }) async {
    try {
      await ensureInitialized();
      if (!_nativeEngineAvailable) {
        throw const TorrentStreamException('原生 libtorrent 引擎不可用');
      }

      final timeoutToUse = engine == TorrentStreamEngine.auto
          ? (metadataTimeout < const Duration(seconds: 15)
              ? metadataTimeout
              : const Duration(seconds: 15))
          : metadataTimeout;

      return await _resolveNativeMagnetFiles(
        magnetUri,
        metadataTimeout: timeoutToUse,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (cancelToken?.isCancelled == true) rethrow;

      // Fallback via Gopeed engine
      try {
        if (!GopeedService().isInitialized) {
          await GopeedService().initialize();
        }
        onProgress?.call('正在通过 Gopeed 引擎解析种子文件列表...');
        final gopeedRes = await GopeedService().resolve(url: magnetUri);
        if (gopeedRes != null && gopeedRes.files.isNotEmpty) {
          return gopeedRes.files.map((f) {
            final segments = f.path.split('/').where((s) => s.isNotEmpty).toList();
            final name = segments.isNotEmpty ? segments.last : '文件 ${f.id + 1}';
            return TorrentFileEntry(
              index: f.id + 1,
              name: name,
              path: f.path,
              sizeBytes: f.size,
              pathSegments: segments.isNotEmpty ? segments : [name],
            );
          }).toList();
        }
      } catch (ge) {
        HaipeeLogger().log(
          Level.warning,
          '[TorrentStreamService] Gopeed resolve fallback failed: $ge',
        );
      }

      // Fallback via TorrServer if available
      if (_adapter is DefaultTorrentEngineAdapter) {
        try {
          final torrServerReady = await TorrServerStreamEngine.instance.isAvailable();
          if (torrServerReady) {
            onProgress?.call('正在通过 TorrServer 核心解析种子文件列表...');
            final client = TorrServerClient();
            final torrent = await client.addTorrent(link: magnetUri, title: 'resolve_files');
            if (torrent.files.isNotEmpty) {
              return torrent.files.map((f) => TorrentFileEntry(
                index: f.id,
                name: f.name,
                path: f.path,
                sizeBytes: f.length,
                pathSegments: f.path.split('/'),
              )).toList();
            }
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<TorrentFileEntry>> _resolveNativeMagnetFiles(
    String magnetUri, {
    required Duration metadataTimeout,
    void Function(String statusMessage)? onProgress,
    TorrentStreamCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const TorrentStreamCancelledException();
    }

    final enhancedMagnet = injectTrackers(magnetUri);
    onProgress?.call('正在通过 DHT 与 Tracker 搜索元数据节点...');

    final torrentId = _adapter.addMagnet(enhancedMagnet, streamOnly: true);
    HaipeeLogger().log(
      Level.info,
      '[TorrentStreamService] Resolving magnet metadata (id=$torrentId)',
    );

    try {
      final startTime = DateTime.now();
      bool metadataResolved = false;
      int lastPeers = 0;

      while (DateTime.now().difference(startTime) < metadataTimeout) {
        if (cancelToken?.isCancelled == true) {
          throw const TorrentStreamCancelledException();
        }
        await Future.delayed(const Duration(milliseconds: 250));
        if (cancelToken?.isCancelled == true) {
          throw const TorrentStreamCancelledException();
        }
        final info = _adapter.getTorrentInfo(torrentId);
        if (info != null) {
          lastPeers = info.numPeers;
          if (info.hasMetadata) {
            metadataResolved = true;
            break;
          }
          if (info.errorMsg.isNotEmpty) {
            throw TorrentStreamException('种子解析错误: ${info.errorMsg}');
          }
          final peerStatus = lastPeers > 0
              ? '已连接 $lastPeers 个节点，正在接收文件列表...'
              : '正在网络中搜索 Peer 节点...';
          onProgress?.call(peerStatus);
        }
      }

      if (!metadataResolved) {
        throw TorrentMetadataTimeoutException(
          '获取种子元数据超时（当前发现节点数: $lastPeers）',
          peerCount: lastPeers,
        );
      }

      if (cancelToken?.isCancelled == true) {
        throw const TorrentStreamCancelledException();
      }

      onProgress?.call('元数据解析成功，正在构建文件树...');

      List<FileInfo> files = _adapter.getFiles(torrentId);
      if (files.isEmpty) {
        for (int i = 0; i < 5; i++) {
          if (cancelToken?.isCancelled == true) {
            throw const TorrentStreamCancelledException();
          }
          await Future.delayed(const Duration(milliseconds: 200));
          files = _adapter.getFiles(torrentId);
          if (files.isNotEmpty) break;
        }
      }

      if (files.isEmpty) {
        throw const TorrentStreamException('种子中未找到有效文件列表');
      }

      final entries = files.map((f) {
        final normalizedPath = f.path.replaceAll('\\', '/');
        final segments = normalizedPath.split('/').where((s) => s.isNotEmpty).toList();
        return TorrentFileEntry(
          index: f.index + 1, // 1-based index
          path: normalizedPath,
          name: f.name,
          sizeBytes: f.size,
          pathSegments: segments.isNotEmpty ? segments : [f.name],
          isSelected: true,
        );
      }).toList();

      return entries;
    } finally {
      _adapter.removeTorrent(torrentId, deleteFiles: true);
    }
  }

  /// Stops an active stream and optionally deletes temporary cache files.
  Future<void> stopStream(int streamId, {int? torrentId, bool deleteFiles = true}) async {
    final session = _activeSessions.remove(streamId);
    if (session?.engine == TorrentStreamEngine.torrserver ||
        TorrServerStreamEngine.instance.hasActiveSession) {
      await TorrServerStreamEngine.instance.stopCurrentSession();
      if (session != null) return;
    }

    try {
      _adapter.stopStream(streamId);
    } catch (e) {
      HaipeeLogger().log(Level.warning, '[TorrentStreamService] stopStream error: $e');
    }

    final targetTorrentId = torrentId ?? session?.torrentId;
    if (targetTorrentId != null && targetTorrentId >= 0) {
      try {
        _adapter.removeTorrent(targetTorrentId, deleteFiles: deleteFiles);
      } catch (e) {
        HaipeeLogger().log(Level.warning, '[TorrentStreamService] removeTorrent error: $e');
      }
    }
  }

  /// Stops all active streams and removes temporary torrents.
  Future<void> stopAll({bool deleteFiles = true}) async {
    await TorrServerStreamEngine.instance.stopCurrentSession();

    final sessionList = _activeSessions.values.toList();
    _activeSessions.clear();
    for (final session in sessionList) {
      if (session.engine == TorrentStreamEngine.torrserver) continue;
      try {
        _adapter.stopStream(session.streamId);
      } catch (_) {}
      try {
        if (session.torrentId >= 0) {
          _adapter.removeTorrent(session.torrentId, deleteFiles: deleteFiles);
        }
      } catch (_) {}
    }
  }

  /// Get status snapshot for stream.
  StreamInfo? getStreamInfo(int streamId) {
    if (streamId >= 80000) return null;
    return _adapter.getStreamInfo(streamId);
  }

  /// Watch live streaming stats (buffer seconds, download rate, peers).
  Stream<StreamInfo?> watchStream(int streamId) {
    if (streamId >= 80000) return const Stream.empty();
    return _adapter.streamUpdates.map((map) => map[streamId]);
  }
}
