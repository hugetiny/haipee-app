import 'package:dio/dio.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

class GofileResolvedInfo {
  final String downloadUrl;
  final String fileName;
  final int? fileSize;
  final String token;

  GofileResolvedInfo({
    required this.downloadUrl,
    required this.fileName,
    this.fileSize,
    required this.token,
  });
}

class GofileHelper {
  static final GofileHelper _instance = GofileHelper._internal();
  factory GofileHelper() => _instance;
  GofileHelper._internal();

  final HaipeeLogger _logger = HaipeeLogger();
  String? _cachedToken;
  DateTime? _tokenExpireTime;

  bool isGofileUrl(String url) {
    return url.contains('gofile.io');
  }

  /// Extracts contentId from gofile.io URL
  String? extractContentId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.contains('d')) {
        final dIdx = uri.pathSegments.indexOf('d');
        if (dIdx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[dIdx + 1];
        }
      }
      if (uri.pathSegments.contains('web')) {
        final webIdx = uri.pathSegments.indexOf('web');
        if (webIdx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[webIdx + 1];
        }
      }
    } catch (_) {}
    return null;
  }

  /// Gets a guest account token from Gofile API
  Future<String?> getGuestToken() async {
    if (_cachedToken != null &&
        _tokenExpireTime != null &&
        DateTime.now().isBefore(_tokenExpireTime!)) {
      return _cachedToken;
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        },
      ));

      final response = await dio.post('https://api.gofile.io/accounts');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data is Map && data['token'] != null) {
          _cachedToken = data['token'].toString();
          _tokenExpireTime = DateTime.now().add(const Duration(hours: 12));
          _logger.log(Level.info, '[GofileHelper] Obtained guest token: $_cachedToken');
          return _cachedToken;
        }
      }
    } catch (e) {
      _logger.log(Level.warning, '[GofileHelper] Failed to get guest token: $e');
    }
    return null;
  }

  /// Resolves direct download link and headers for a Gofile URL
  Future<GofileResolvedInfo?> resolve(String url) async {
    if (!isGofileUrl(url)) return null;

    final token = await getGuestToken();
    if (token == null) return null;

    final contentId = extractContentId(url);
    if (contentId == null) {
      // Direct store link without contentId extraction
      return GofileResolvedInfo(
        downloadUrl: url,
        fileName: url.split('/').last.split('?').first,
        token: token,
      );
    }

    // Try fetching content info from API to get direct link and filename
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.get('https://api.gofile.io/contents/$contentId');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data is Map) {
          final link = data['link']?.toString() ?? url;
          final name = data['name']?.toString() ?? url.split('/').last.split('?').first;
          final size = data['size'] is int ? data['size'] as int : null;
          return GofileResolvedInfo(
            downloadUrl: link,
            fileName: name,
            fileSize: size,
            token: token,
          );
        }
      }
    } catch (e) {
      _logger.log(Level.warning, '[GofileHelper] Failed to resolve content $contentId: $e');
    }

    // Fallback: use original url and token
    return GofileResolvedInfo(
      downloadUrl: url,
      fileName: url.split('/').last.split('?').first,
      token: token,
    );
  }
}
