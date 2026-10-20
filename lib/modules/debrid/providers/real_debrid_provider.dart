import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/debrid/debrid_provider.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

/// Real-Debrid 云端高速离线加速中枢适配器
class RealDebridProvider implements DebridProvider {
  RealDebridProvider({Dio? dio, String? apiKey})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.real-debrid.com/rest/1.0',
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 6),
              ),
            ),
        _explicitApiKey = apiKey;

  final Dio _dio;
  final String? _explicitApiKey;

  @override
  String get name => 'Real-Debrid';

  @override
  String get identifier => 'real_debrid';

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

  /// 提取 40 字符十六进制 InfoHash
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
        '/torrents/instantAvailability/$hash',
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final hashEntry = data[hash];
        if (hashEntry is Map) {
          final rdList = hashEntry['rd'];
          if (rdList is List && rdList.isNotEmpty) {
            KazumiLogger().log(
              Level.info,
              '[RealDebrid] Hit instant cloud cache for hash $hash!',
            );
            return true;
          }
        }
      }
    } catch (e) {
      KazumiLogger().log(
        Level.debug,
        '[RealDebrid] Check instant availability failed for $hash: $e',
      );
    }

    return false;
  }

  @override
  Future<String?> resolveStreamUrl(String magnetOrInfoHash, {int targetEpisode = 1}) async {
    if (!isConfigured) return null;

    final magnet = magnetOrInfoHash.startsWith('magnet:?')
        ? magnetOrInfoHash
        : 'magnet:?xt=urn:btih:$magnetOrInfoHash';

    try {
      // 1. 添加磁力链到 Real-Debrid 云端中枢
      final addResponse = await _dio.post<Map<String, dynamic>>(
        '/torrents/addMagnet',
        data: FormData.fromMap({'magnet': magnet}),
        options: _authOptions,
      );

      if (addResponse.statusCode != 201 && addResponse.statusCode != 200) {
        return null;
      }

      final torrentId = addResponse.data?['id']?.toString();
      if (torrentId == null || torrentId.isEmpty) return null;

      // 2. 选择全部文件以激活云端解析
      await _dio.post(
        '/torrents/selectFiles/$torrentId',
        data: FormData.fromMap({'files': 'all'}),
        options: _authOptions,
      );

      // 3. 查询种子状态与已就绪的链接
      final infoResponse = await _dio.get<Map<String, dynamic>>(
        '/torrents/info/$torrentId',
        options: _authOptions,
      );

      final links = infoResponse.data?['links'] as List<dynamic>?;
      if (links == null || links.isEmpty) return null;

      // 4. 选择对应集数或第一个直链进行云端解封 (Unrestrict)
      final selectedLink = (targetEpisode > 0 && targetEpisode <= links.length)
          ? links[targetEpisode - 1].toString()
          : links.first.toString();

      final unrestrictResponse = await _dio.post<Map<String, dynamic>>(
        '/unrestrict/link',
        data: FormData.fromMap({'link': selectedLink}),
        options: _authOptions,
      );

      final streamUrl = unrestrictResponse.data?['download'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        KazumiLogger().log(
          Level.info,
          '[RealDebrid] Successfully resolved CDN stream URL: $streamUrl',
        );
        return streamUrl;
      }
    } catch (e) {
      KazumiLogger().log(
        Level.warning,
        '[RealDebrid] Failed to resolve stream link: $e',
      );
    }

    return null;
  }
}
