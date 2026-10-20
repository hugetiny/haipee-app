import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/debrid/debrid_provider.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

/// TorBox 云端离线中枢适配器 (https://torbox.app)
class TorBoxProvider implements DebridProvider {
  TorBoxProvider({Dio? dio, String? apiKey})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.torbox.app/v1/api',
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 6),
              ),
            ),
        _explicitApiKey = apiKey;

  final Dio _dio;
  final String? _explicitApiKey;

  @override
  String get name => 'TorBox';

  @override
  String get identifier => 'torbox';

  String get _apiKey {
    if (_explicitApiKey != null && _explicitApiKey.isNotEmpty) {
      return _explicitApiKey;
    }
    try {
      return (GStorage.setting.get(SettingBoxKey.debridApiKey, defaultValue: '') as String).trim();
    } catch (_) {
      return '';
    }
  }

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  Options get _authOptions => Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

  static String extractInfoHash(String input) {
    if (input.startsWith('magnet:?')) {
      final match = RegExp(r'xt=urn:btih:([a-zA-Z0-9]{32,40})', caseSensitive: false).firstMatch(input);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toLowerCase();
      }
    }
    return input.trim().toLowerCase();
  }

  @override
  Future<bool> checkInstantAvailability(String infoHash) async {
    if (!isConfigured) return false;
    final hash = extractInfoHash(infoHash);
    if (hash.isEmpty) return false;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/torrents/checkcached',
        queryParameters: {'hash': hash, 'format': 'list'},
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        if (data['success'] == true) {
          final list = data['data'];
          if (list is List && list.contains(hash)) {
            KazumiLogger().log(
              Level.info,
              '[TorBox] Hit instant cloud cache for hash $hash!',
            );
            return true;
          }
        }
      }
    } catch (e) {
      KazumiLogger().log(
        Level.debug,
        '[TorBox] Check instant cache failed: $e',
      );
    }

    return false;
  }

  @override
  Future<String?> resolveStreamUrl(String magnetOrInfoHash, {int targetEpisode = 1}) async {
    if (!isConfigured) return null;
    final hash = extractInfoHash(magnetOrInfoHash);

    try {
      // 1. Create / import torrent
      final createResponse = await _dio.post<Map<String, dynamic>>(
        '/torrents/createtorrent',
        data: {'magnet': magnetOrInfoHash.startsWith('magnet:') ? magnetOrInfoHash : 'magnet:?xt=urn:btih:$hash'},
        options: _authOptions,
      );

      final torrentId = createResponse.data?['data']?['torrent_id'];
      if (torrentId == null) return null;

      // 2. Request direct download / stream link
      final dlResponse = await _dio.get<Map<String, dynamic>>(
        '/torrents/requestdl',
        queryParameters: {
          'token': _apiKey,
          'torrent_id': torrentId,
        },
        options: _authOptions,
      );

      final link = dlResponse.data?['data'] as String?;
      if (link != null && link.isNotEmpty) {
        KazumiLogger().log(
          Level.info,
          '[TorBox] Successfully resolved cloud stream URL: $link',
        );
        return link;
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '[TorBox] Stream resolve failed: $e');
    }

    return null;
  }
}
