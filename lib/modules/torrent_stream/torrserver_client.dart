import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:haipee/modules/torrent_stream/torrserver_process_manager.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// TorrServer 文件信息项
class TorrServerFile {
  final int id;
  final String path;
  final int length;

  const TorrServerFile({
    required this.id,
    required this.path,
    required this.length,
  });

  factory TorrServerFile.fromJson(Map<String, dynamic> json) {
    return TorrServerFile(
      id: json['id'] as int? ?? 0,
      path: json['path'] as String? ?? '',
      length: json['length'] as int? ?? 0,
    );
  }

  String get name {
    final idx = path.lastIndexOf('/');
    if (idx != -1) return path.substring(idx + 1);
    final winIdx = path.lastIndexOf('\\');
    if (winIdx != -1) return path.substring(winIdx + 1);
    return path;
  }
}

/// TorrServer 种子实时状态详情
class TorrServerTorrent {
  final String hash;
  final String title;
  final int stat;
  final String statString;
  final int totalPeers;
  final int activePeers;
  final int connectedSeeders;
  final int downloadSpeed;
  final int preloadedBytes;
  final int preloadSize;
  final List<TorrServerFile> files;

  const TorrServerTorrent({
    required this.hash,
    required this.title,
    required this.stat,
    required this.statString,
    this.totalPeers = 0,
    this.activePeers = 0,
    this.connectedSeeders = 0,
    this.downloadSpeed = 0,
    this.preloadedBytes = 0,
    this.preloadSize = 0,
    this.files = const [],
  });

  factory TorrServerTorrent.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['file_stats'] as List? ?? json['files'] as List? ?? [];
    final filesList = rawFiles
        .whereType<Map<String, dynamic>>()
        .map((f) => TorrServerFile.fromJson(f))
        .toList();

    return TorrServerTorrent(
      hash: json['hash'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      stat: json['stat'] as int? ?? 0,
      statString: json['stat_string'] as String? ?? '',
      totalPeers: json['total_peers'] as int? ?? 0,
      activePeers: json['active_peers'] as int? ?? 0,
      connectedSeeders: json['connected_seeders'] as int? ?? 0,
      downloadSpeed: json['download_speed'] as int? ?? 0,
      preloadedBytes: json['preloaded_bytes'] as int? ?? 0,
      preloadSize: json['preload_size'] as int? ?? 0,
      files: filesList,
    );
  }

  /// 计算做种健康度节点数（优先使用 total_peers 或 connected_seeders）
  int get effectivePeerCount {
    if (totalPeers > 0) return totalPeers;
    if (activePeers > 0) return activePeers;
    if (connectedSeeders > 0) return connectedSeeders;
    return 0;
  }

  /// 预加载完成百分比（0.0 ~ 1.0）
  double? get preloadProgress {
    if (preloadSize > 0 && preloadedBytes > 0) {
      return (preloadedBytes / preloadSize).clamp(0.0, 1.0);
    }
    return null;
  }
}

/// TorrServer REST API 客户端
class TorrServerClient {
  final String baseUrl;
  final http.Client _httpClient;
  final HaipeeLogger _logger = HaipeeLogger();

  TorrServerClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? TorrServerProcessManager.instance.baseUrl,
        _httpClient = httpClient ?? http.Client();

  /// 添加磁力任务到 TorrServer
  Future<TorrServerTorrent> addTorrent({
    required String link,
    String? title,
    String? poster,
    bool saveToDb = false,
  }) async {
    final uri = Uri.parse('$baseUrl/torrents');
    final payload = {
      'action': 'add',
      'link': link,
      if (title != null && title.isNotEmpty) 'title': title,
      if (poster != null && poster.isNotEmpty) 'poster': poster,
      'save_to_db': saveToDb,
    };

    final res = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('TorrServer add error [${res.statusCode}]: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TorrServerTorrent.fromJson(data);
  }

  /// 查询指定种子的实时状态与文件树
  Future<TorrServerTorrent> getTorrent(String hash) async {
    final uri = Uri.parse('$baseUrl/torrents');
    final payload = {
      'action': 'get',
      'hash': hash,
    };

    final res = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('TorrServer get error [${res.statusCode}]: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TorrServerTorrent.fromJson(data);
  }

  /// 从 TorrServer 中移除种子
  Future<void> removeTorrent(String hash) async {
    try {
      final uri = Uri.parse('$baseUrl/torrents');
      final payload = {
        'action': 'rem',
        'hash': hash,
      };

      await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      _logger.log(Level.warning, '[TorrServerClient] Failed to remove torrent $hash: $e');
    }
  }

  /// 触发 TorrServer 针对指定文件的后台内存环形预缓冲 (抓取首尾关键帧与容器头部)
  Future<void> triggerPreload({
    required String hash,
    required int fileIndex,
    String? fileName,
  }) async {
    final friendlyName = fileName != null && fileName.isNotEmpty
        ? Uri.encodeComponent(fileName)
        : 'stream.mp4';
    final url = '$baseUrl/stream/$friendlyName?link=$hash&index=$fileIndex&preload';
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(milliseconds: 1500));
      // 触发成功后断开监听，TorrServer 会在后台维持环形缓冲抓取
      response.stream.listen((_) {}).cancel();
    } catch (_) {
      // 超时或主动断开属于正常现象
    }
  }

  /// 生成供播放器 (media_kit) 播放的流地址
  String buildStreamUrl({
    required String link,
    String? hash,
    required int fileIndex,
    String? fileName,
  }) {
    // 优先使用精简的 40 字符 hash，避免长达 2500 字符的 magnet 链接导致 HTTP URL 溢出或解析异常
    final streamLink = (hash != null && hash.isNotEmpty)
        ? hash
        : Uri.encodeComponent(link);
    final friendlyName = fileName != null && fileName.isNotEmpty
        ? Uri.encodeComponent(fileName)
        : 'stream.mp4';

    return '$baseUrl/stream/$friendlyName?link=$streamLink&index=$fileIndex&play';
  }
}
