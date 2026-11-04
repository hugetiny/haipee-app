import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:haipee/modules/torrent_search/parser/torrent_file_parser.dart';
import 'package:haipee/modules/torrent_search/sources/torrent_dio_factory.dart';
import 'package:haipee/modules/torrent_stream/torrent_stream_service.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 种子文件极速网络下载与本地持久化辅助类
class TorrentDownloadHelper {
  static final HaipeeLogger _logger = HaipeeLogger();

  /// 极速下载 .torrent 种子文件字节流（默认 4 秒快速超时，若失败由上层平滑降级至磁力 DHT）
  static Future<Uint8List?> fetchTorrentBytes(
    String url, {
    Duration timeout = const Duration(seconds: 4),
    TorrentStreamCancelToken? cancelToken,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || cleanUrl.toLowerCase().startsWith('magnet:?')) {
      return null;
    }

    if (cancelToken?.isCancelled == true) {
      return null;
    }

    final dioCancelToken = CancelToken();

    final dio = TorrentDioFactory.create(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      headers: {
        'User-Agent': Utils.getRandomUA(),
        'Accept':
            'application/x-bittorrent, application/octet-stream, */*;q=0.8',
      },
    );
    dio.options.sendTimeout = timeout;
    dio.options.responseType = ResponseType.bytes;
    dio.options.followRedirects = true;
    dio.options.maxRedirects = 5;

    try {
      final response = await dio.get<List<int>>(
        cleanUrl,
        cancelToken: dioCancelToken,
      );

      if (cancelToken?.isCancelled == true) return null;

      if (response.statusCode == 200 && response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        // 校验 Bencode 规范：合法种子文件根节点必然为 Dictionary，首字节必须为 'd' (ASCII 0x64)
        if (bytes.isNotEmpty && bytes.first == 0x64) {
          _logger.log(
            Level.info,
            '[TorrentDownloadHelper] Successfully fetched .torrent (${bytes.length} bytes) from $cleanUrl',
          );
          return bytes;
        } else {
          _logger.log(
            Level.warning,
            '[TorrentDownloadHelper] Fetched data from $cleanUrl is not a valid Bencode torrent file (starts with 0x${bytes.isNotEmpty ? bytes.first.toRadixString(16) : 'empty'})',
          );
        }
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return null;
      }
      _logger.log(
        Level.warning,
        '[TorrentDownloadHelper] Failed to fetch .torrent from $cleanUrl: $e',
      );
    }
    return null;
  }

  /// 下载并立即解析种子文件结构（0ms 秒级展开目录树）
  static Future<ParsedTorrent?> fetchAndParseTorrent(
    String url, {
    Duration timeout = const Duration(seconds: 4),
    TorrentStreamCancelToken? cancelToken,
  }) async {
    final bytes = await fetchTorrentBytes(
      url,
      timeout: timeout,
      cancelToken: cancelToken,
    );
    if (bytes == null || bytes.isEmpty) return null;

    try {
      return TorrentFileParser.parseBytes(bytes);
    } catch (e) {
      _logger.log(
        Level.warning,
        '[TorrentDownloadHelper] Failed to parse torrent bytes: $e',
      );
      return null;
    }
  }

  /// 将种子字节持久化保存到本地文件
  static Future<File?> saveTorrentToFile(
    Uint8List bytes, {
    required String defaultFileName,
    String? saveDir,
  }) async {
    try {
      String targetDir = saveDir ?? '';
      if (targetDir.isEmpty) {
        final customPath = (GStorage.setting.get(
          SettingBoxKey.downloadDirectory,
          defaultValue: '',
        ) as String).trim();
        if (customPath.isNotEmpty) {
          targetDir = customPath;
        } else {
          final docDir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
          targetDir = docDir.path;
        }
      }

      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      String safeName = defaultFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!safeName.toLowerCase().endsWith('.torrent')) {
        safeName = '$safeName.torrent';
      }

      final file = File('${dir.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes);
      _logger.log(
        Level.info,
        '[TorrentDownloadHelper] Saved torrent file to ${file.path}',
      );
      return file;
    } catch (e) {
      _logger.log(
        Level.error,
        '[TorrentDownloadHelper] Failed to save torrent file: $e',
      );
      return null;
    }
  }
}
