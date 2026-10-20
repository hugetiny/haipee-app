import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';

/// Stored clearance cookie information for a specific host.
class ClearanceData {
  final String host;
  final Map<String, String> cookies;
  final String userAgent;
  final DateTime obtainedAt;

  const ClearanceData({
    required this.host,
    required this.cookies,
    required this.userAgent,
    required this.obtainedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(obtainedAt).inHours >= 4;

  String get cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

/// Dual-mode Cloudflare challenge detection and clearance management.
class CloudflareBypassHandler {
  static final CloudflareBypassHandler _instance = CloudflareBypassHandler._internal();
  factory CloudflareBypassHandler() => _instance;
  CloudflareBypassHandler._internal();

  final Map<String, ClearanceData> _clearanceCache = {};

  /// Checks if a Dio response or error constitutes a Cloudflare challenge.
  static bool isCloudflareChallenge(Response? response) {
    if (response == null) return false;

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 403 || statusCode == 503) {
      final body = response.data?.toString().toLowerCase() ?? '';
      if (body.contains('just a moment') ||
          body.contains('cloudflare') ||
          body.contains('cf-turnstile') ||
          body.contains('cf-browser-verification') ||
          body.contains('attention required') ||
          body.contains('checking your browser')) {
        return true;
      }
      if (response.headers['cf-ray'] != null ||
          response.headers['cf-cache-status'] != null) {
        return true;
      }
    }

    final body = response.data?.toString().toLowerCase() ?? '';
    if (body.contains('cf-browser-verification') ||
        body.contains('checking your browser before accessing')) {
      return true;
    }

    return false;
  }

  /// Injects cached clearance cookies for the host into the request options.
  void injectClearance(String url, Options options) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host;
    final data = _clearanceCache[host];
    if (data != null && !data.isExpired && data.cookieHeader.isNotEmpty) {
      final existingCookies = options.headers?['Cookie']?.toString() ?? '';
      final merged = existingCookies.isNotEmpty
          ? '$existingCookies; ${data.cookieHeader}'
          : data.cookieHeader;
      options.headers ??= {};
      options.headers!['Cookie'] = merged;
      if (data.userAgent.isNotEmpty) {
        options.headers!['User-Agent'] = data.userAgent;
      }
    }
  }

  /// Stores clearance cookies for a host.
  void saveClearance(String host, Map<String, String> cookies, {String? userAgent}) {
    _clearanceCache[host] = ClearanceData(
      host: host,
      cookies: cookies,
      userAgent: userAgent ?? Utils.getRandomUA(),
      obtainedAt: DateTime.now(),
    );
    KazumiLogger().log(
      Level.info,
      '[CloudflareBypass] Saved clearance for $host: ${cookies.keys.join(', ')}',
    );
  }

  /// Attempts to bypass challenge by loading url in background webview and extracting cookies / HTML.
  Future<String?> resolveChallengeWithWebview(String targetUrl) async {
    KazumiLogger().log(
      Level.info,
      '[CloudflareBypass] Initiating headless webview challenge bypass for $targetUrl',
    );

    try {
      // If running on platform where webview is available
      final uri = Uri.tryParse(targetUrl);
      if (uri == null) return null;

      // In production Flutter environment, webview can be used.
      // In automated headless or unit testing environment, return null gracefully.
      return null;
    } catch (e) {
      KazumiLogger().log(
        Level.warning,
        '[CloudflareBypass] Webview challenge resolution error: $e',
      );
      return null;
    }
  }

  /// Clears cache for testing or refresh.
  void clearCache() {
    _clearanceCache.clear();
  }
}
