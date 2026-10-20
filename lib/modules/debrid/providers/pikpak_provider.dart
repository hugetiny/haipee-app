import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/debrid/debrid_provider.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

/// PikPak 私有离线云盘高速直连提供者
class PikPakProvider implements DebridProvider {
  PikPakProvider({Dio? dio, String? apiKey})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api-drive.mypikpak.com',
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 6),
              ),
            ),
        _explicitApiKey = apiKey;

  final Dio _dio;
  final String? _explicitApiKey;

  @override
  String get name => 'PikPak';

  @override
  String get identifier => 'pikpak';

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

    // PikPak 检查秒传离线
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/drive/v1/task/check',
        queryParameters: {'url': 'magnet:?xt=urn:btih:$hash'},
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data != null) {
        final phase = response.data?['phase'];
        if (phase == 'PHASE_TYPE_COMPLETE') {
          KazumiLogger().log(
            Level.info,
            '[PikPak] Hit instant cloud cache for hash $hash!',
          );
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  @override
  Future<String?> resolveStreamUrl(String magnetOrInfoHash, {int targetEpisode = 1}) async {
    if (!isConfigured) return null;
    final hash = extractInfoHash(magnetOrInfoHash);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/drive/v1/files/download',
        data: {'hash': hash, 'episode': targetEpisode},
        options: _authOptions,
      );

      final streamUrl = response.data?['web_content_link'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        KazumiLogger().log(
          Level.info,
          '[PikPak] Resolved direct cloud stream URL: $streamUrl',
        );
        return streamUrl;
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '[PikPak] Stream resolve failed: $e');
    }

    return null;
  }
}
