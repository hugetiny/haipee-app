import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 专为 Aria2 顺序边下边播设计的本地 HTTP 206 Partial Content 流式代理服务器。
///
/// 核心职责：
/// 1. 监听 127.0.0.1 随机安全端口，提供标准 HTTP 206 Range 分段响应；
/// 2. 精确对接 media_kit (MPV) 的音视频解复用探测请求（包括 MP4 moov/MKV seekhead 首尾分片）；
/// 3. 当播放器请求尚未下载到磁盘的数据块时，执行非阻塞异步轮询等待，并在分片落盘后立即推送；
/// 4. 严密捕获客户端断开（如跳转拖拽、切换清晰度）并释放文件句柄，保障零内存泄漏。
class Aria2StreamServer {
  final String filePath;
  final int totalLength;
  final String mimeType;
  final Future<bool> Function(int targetByteOffset)? waitForBytesDownloaded;

  HttpServer? _server;
  bool _isClosed = false;

  Aria2StreamServer({
    required this.filePath,
    required this.totalLength,
    String? mimeType,
    this.waitForBytesDownloaded,
  }) : mimeType = mimeType ?? getMimeType(filePath);

  bool get isRunning => _server != null && !_isClosed;
  int? get port => _server?.port;

  String get streamUrl {
    if (_server == null) throw StateError('Aria2StreamServer is not running');
    return 'http://127.0.0.1:${_server!.port}/stream';
  }

  /// 依据文件扩展名推导媒体 MIME 类型
  static String getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.ts') || lower.endsWith('.m2ts')) return 'video/mp2t';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/mp4';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    return 'video/mp4';
  }

  /// 启动本地 HTTP 流式服务器
  Future<int> start() async {
    if (_server != null) return _server!.port;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _isClosed = false;
    final assignedPort = _server!.port;

    KazumiLogger().log(
      Level.info,
      '[Aria2StreamServer] Listening on http://127.0.0.1:$assignedPort/stream for $filePath ($totalLength bytes)',
    );

    _server!.listen(
      _handleRequest,
      onError: (e) {
        if (!_isClosed) {
          KazumiLogger().log(Level.warning, '[Aria2StreamServer] Server error: $e');
        }
      },
    );

    return assignedPort;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (_isClosed) {
      try {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      } catch (_) {}
      return;
    }

    final response = request.response;

    // CORS & 标准通用头部
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Range, Content-Type, Accept');
    response.headers.set('Server', 'Kazumi-Aria2-Streamer/2.0');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      response.contentLength = 0;
      await response.close();
      return;
    }

    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    final rangeHeader = request.headers.value('range');
    int start = 0;
    int end = totalLength - 1;
    bool isRange = false;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      isRange = true;
      final rangeSpec = rangeHeader.substring(6).trim();
      final commaIdx = rangeSpec.indexOf(',');
      final singleRange = commaIdx != -1 ? rangeSpec.substring(0, commaIdx) : rangeSpec;

      if (singleRange.startsWith('-')) {
        // Suffix range: bytes=-500
        final suffixLength = int.tryParse(singleRange.substring(1)) ?? 0;
        start = math.max(0, totalLength - suffixLength);
        end = totalLength - 1;
      } else {
        final parts = singleRange.split('-');
        final pStart = int.tryParse(parts[0]);
        final pEnd = parts.length > 1 && parts[1].isNotEmpty ? int.tryParse(parts[1]) : null;

        if (pStart != null) {
          start = pStart;
          end = pEnd != null ? math.min(pEnd, totalLength - 1) : totalLength - 1;
        }
      }
    }

    // 校验范围合法性
    if (start < 0 || start > end || start >= totalLength) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('Content-Range', 'bytes */$totalLength');
      await response.close();
      return;
    }

    final contentLength = end - start + 1;

    response.headers.set('Accept-Ranges', 'bytes');
    response.headers.set('Content-Type', mimeType);
    response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');

    if (isRange) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.set('Content-Range', 'bytes $start-$end/$totalLength');
      response.contentLength = contentLength;
    } else {
      response.statusCode = HttpStatus.ok;
      response.contentLength = totalLength;
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // 针对 GET 数据流进行异步分块推送
    RandomAccessFile? raf;
    try {
      final file = File(filePath);

      // 等待物理文件被 Aria2 初始化落盘
      int fileWaitCount = 0;
      while (!file.existsSync() && fileWaitCount < 40 && !_isClosed) {
        await Future.delayed(const Duration(milliseconds: 250));
        fileWaitCount++;
      }

      if (!file.existsSync() || _isClosed) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      raf = await file.open(mode: FileMode.read);
      await raf.setPosition(start);

      int bytesRemaining = contentLength;
      const int bufferChunkSize = 64 * 1024; // 64KB 吞吐缓冲区
      int stallCount = 0;
      const int maxStallIterations = 150; // 150 * 200ms = 30s 最大停顿容忍

      while (bytesRemaining > 0 && !_isClosed) {
        final toRead = math.min(bufferChunkSize, bytesRemaining);
        final currentPos = end - bytesRemaining + 1;

        // 如果该字节尚未由 Aria2 写入磁盘，则等待分片就绪
        if (waitForBytesDownloaded != null) {
          final isReady = await waitForBytesDownloaded!(currentPos + toRead - 1);
          if (!isReady && !_isClosed) {
            // 轮询超时或无法继续
            break;
          }
        }

        // 验证文件在磁盘上的实际长度
        final currentFileLen = await raf.length();
        if (currentPos >= currentFileLen) {
          stallCount++;
          if (stallCount >= maxStallIterations) {
            KazumiLogger().log(
              Level.warning,
              '[Aria2StreamServer] Stream stalled for 30s at offset $currentPos (file len: $currentFileLen)',
            );
            break;
          }
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }

        final actualToRead = math.min(toRead, currentFileLen - currentPos);
        final chunk = await raf.read(actualToRead);
        if (chunk.isEmpty) {
          stallCount++;
          if (stallCount >= maxStallIterations) break;
          await Future.delayed(const Duration(milliseconds: 150));
          continue;
        }

        stallCount = 0; // 重置停顿计数器
        response.add(chunk);
        await response.flush();
        bytesRemaining -= chunk.length;
      }
    } catch (e) {
      // 客户端断开连接或拖拽进度条引起的连接中断，属于正常流式事件
      KazumiLogger().log(Level.debug, '[Aria2StreamServer] Stream chunk transfer closed: $e');
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// 停止本地流式服务器
  Future<void> stop() async {
    _isClosed = true;
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
      KazumiLogger().log(Level.info, '[Aria2StreamServer] Stopped stream server for $filePath');
    }
  }
}
