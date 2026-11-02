import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/utils/api_credentials.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// Represents the upstream metadata provider used for a fetch operation.
enum MetadataSourceKind {
  bangumi,
  tmdb,
}

/// Successful metadata payload returned from a provider.
class MetadataFetchResult {
  MetadataFetchResult({
    required this.source,
    required this.payload,
    required this.locale,
  });

  final MetadataSourceKind source;
  final Map<String, dynamic> payload;
  final ui.Locale locale;
}

/// HTTP client responsible for retrieving metadata from Bangumi and TMDb.
///
/// The client respects locale preferences, user-enabled source toggles, and
/// applies simple rate limiting so upstream APIs are not overwhelmed.
class MetadataClient {
  MetadataClient({
    Request? request,
    Box<dynamic>? settingBox,
  })  : _request = request ?? Request(),
        _setting = settingBox ?? GStorage.setting;

  final Request _request;
  final Box<dynamic> _setting;
  final Map<MetadataSourceKind, DateTime> _lastFetch =
      <MetadataSourceKind, DateTime>{};

  static const Duration _bangumiRateLimit = Duration(seconds: 2);
  static const Duration _tmdbRateLimit = Duration(seconds: 2);

  /// Fetches metadata for the given [identifier], returning the first successful
  /// payload that satisfies the locale and source ordering rules.
  Future<MetadataFetchResult?> fetchSubject({
    required String identifier,
    ui.Locale? localeOverride,
    bool forceRefresh = false,
  }) async {
    final ui.Locale locale = _resolveLocale(localeOverride);
    final bool bangumiEnabled = _isSourceEnabled(
      MetadataSourceKind.bangumi,
      locale: locale,
    );
    final bool tmdbEnabled = _isSourceEnabled(
      MetadataSourceKind.tmdb,
      locale: locale,
    );
    final List<MetadataSourceKind> order = _computeSourcePriority(
      locale,
      bangumiEnabled: bangumiEnabled,
      tmdbEnabled: tmdbEnabled,
    );

    for (final MetadataSourceKind source in order) {
      final MetadataFetchResult? result = await fetchFromSource(
        source: source,
        identifier: identifier,
        localeOverride: locale,
        forceRefresh: forceRefresh,
      );
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  Future<MetadataFetchResult?> fetchFromSource({
    required MetadataSourceKind source,
    required String identifier,
    ui.Locale? localeOverride,
    bool forceRefresh = false,
  }) async {
    final ui.Locale locale = _resolveLocale(localeOverride);
    if (!_isSourceEnabled(source, locale: locale)) {
      return null;
    }
    if (!forceRefresh && _isThrottled(source)) {
      return null;
    }

    try {
      final Map<String, dynamic>? payload = await _fetch(
        source,
        identifier: identifier,
        locale: locale,
      );
      if (payload != null && payload.isNotEmpty) {
        _lastFetch[source] = DateTime.now();
        return MetadataFetchResult(
          source: source,
          payload: payload,
          locale: locale,
        );
      }
    } on DioException catch (error, stackTrace) {
      HaipeeLogger().log(
        Level.error,
        '[MetadataClient] ${source.name} request failed for $identifier: ${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      HaipeeLogger().log(
        Level.error,
        '[MetadataClient] Unexpected ${source.name} failure for $identifier: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  ui.Locale _resolveLocale(ui.Locale? override) {
    if (override != null) {
      unawaited(_setting.put(
        SettingBoxKey.metadataPreferredLocale,
        override.toLanguageTag(),
      ));
      return override;
    }

    final String? storedTag =
        _setting.get(SettingBoxKey.metadataPreferredLocale, defaultValue: '')
            as String?;
    if (storedTag != null && storedTag.isNotEmpty) {
      final ui.Locale? storedLocale = _localeFromTag(storedTag);
      if (storedLocale != null) {
        return storedLocale;
      }
    }

    final ui.Locale fallback =
        WidgetsBinding.instance.platformDispatcher.locale;
    if (!_setting.containsKey(SettingBoxKey.metadataPreferredLocale)) {
      unawaited(_setting.put(
        SettingBoxKey.metadataPreferredLocale,
        fallback.toLanguageTag(),
      ));
    }
    return fallback;
  }

  List<MetadataSourceKind> _computeSourcePriority(
    ui.Locale locale, {
    required bool bangumiEnabled,
    required bool tmdbEnabled,
  }) {
    final bool bangumiPreferred =
        bangumiEnabled && _defaultBangumiEnabled(locale);
    final List<MetadataSourceKind> order = <MetadataSourceKind>[];

    if (bangumiPreferred) {
      order.add(MetadataSourceKind.bangumi);
    }
    if (tmdbEnabled) {
      order.add(MetadataSourceKind.tmdb);
    }
    if (bangumiEnabled && !bangumiPreferred) {
      order.add(MetadataSourceKind.bangumi);
    }

    if (order.isEmpty) {
      order.add(MetadataSourceKind.tmdb);
    }
    return order;
  }

  bool _isThrottled(MetadataSourceKind kind) {
    final DateTime? last = _lastFetch[kind];
    if (last == null) {
      return false;
    }
    final Duration window =
        kind == MetadataSourceKind.bangumi ? _bangumiRateLimit : _tmdbRateLimit;
    return DateTime.now().difference(last) < window;
  }

  Future<Map<String, dynamic>?> _fetch(
    MetadataSourceKind kind, {
    required String identifier,
    required ui.Locale locale,
  }) {
    switch (kind) {
      case MetadataSourceKind.bangumi:
        return _fetchBangumi(identifier, locale);
      case MetadataSourceKind.tmdb:
        return _fetchTmdb(identifier, locale);
    }
  }

  Future<Map<String, dynamic>?> _fetchBangumi(
    String identifier,
    ui.Locale locale,
  ) async {
    final int? id = int.tryParse(identifier);
    if (id == null) {
      HaipeeLogger().log(
        Level.warning,
        '[MetadataClient] Invalid Bangumi identifier: $identifier',
      );
      return null;
    }

    final String url = Api.formatUrl(
        Api.bangumiAPIDomain + Api.bangumiInfoByID, <dynamic>[id]);
    final Response<dynamic> response = await _request.get(
      url,
      options: Options(
        headers: <String, String>{
          'accept-language': _buildAcceptLanguage(
            locale,
            prioritized: const <String>['zh-CN', 'ja-JP', 'en-US'],
          ),
        },
      ),
      extra: const <String, dynamic>{'customError': true},
      shouldRethrow: true,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchTmdb(
    String identifier,
    ui.Locale locale,
  ) async {
    final String storedKey =
        (_setting.get(SettingBoxKey.tmdbApiKey, defaultValue: '') as String)
            .trim();
    final String apiKey =
        storedKey.isNotEmpty ? storedKey : ApiCredentials.tmdbApiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    final String url =
        '${Api.tmdbDomain}${Api.tmdbTvDetail}'.replaceFirst('{0}', identifier);
    final Response<dynamic> response = await _request.get(
      url,
      data: <String, dynamic>{
        'api_key': apiKey,
        'language': _tmdbLanguage(locale),
        'append_to_response': 'external_ids,translations,images',
      },
      extra: const <String, dynamic>{'customError': true},
      shouldRethrow: true,
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static bool _defaultBangumiEnabled(ui.Locale locale) {
    final String code = locale.languageCode.toLowerCase();
    return code == 'zh' || code == 'ja';
  }

  static ui.Locale? _localeFromTag(String tag) {
    if (tag.isEmpty) {
      return null;
    }
    final List<String> segments = tag.split('-');
    if (segments.length == 1) {
      return ui.Locale(segments.first);
    }
    if (segments.length == 2) {
      return ui.Locale(segments[0], segments[1]);
    }
    return ui.Locale.fromSubtags(
      languageCode: segments.first,
      countryCode: segments.length > 1 ? segments[1] : null,
      scriptCode: segments.length > 2 ? segments[2] : null,
    );
  }

  static String _buildAcceptLanguage(
    ui.Locale locale, {
    List<String> prioritized = const <String>['en-US'],
  }) {
    final List<String> codes = <String>[_localeToLanguageTag(locale)];
    for (final String value in prioritized) {
      if (!codes.contains(value)) {
        codes.add(value);
      }
    }

    final List<String> parts = <String>[];
    double quality = 1.0;
    for (final String code in codes) {
      if (parts.isEmpty) {
        parts.add(code);
      } else {
        parts.add('$code;q=${quality.clamp(0.1, 1.0).toStringAsFixed(1)}');
      }
      quality -= 0.1;
    }
    return parts.join(', ');
  }

  static String _tmdbLanguage(ui.Locale locale) {
    switch (locale.languageCode.toLowerCase()) {
      case 'zh':
        return locale.scriptCode?.toLowerCase() == 'hant' ? 'zh-TW' : 'zh-CN';
      case 'ja':
        return 'ja-JP';
      default:
        return _localeToLanguageTag(locale);
    }
  }

  static String _localeToLanguageTag(ui.Locale locale) {
    final String languageCode = locale.languageCode;
    final String? countryCode = locale.countryCode;
    final String? scriptCode = locale.scriptCode;
    if (scriptCode != null && scriptCode.isNotEmpty) {
      final String extra =
          countryCode != null && countryCode.isNotEmpty ? '-$countryCode' : '';
      return '$languageCode-$scriptCode$extra';
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      return '$languageCode-$countryCode';
    }
    return languageCode;
  }

  bool _isSourceEnabled(
    MetadataSourceKind source, {
    required ui.Locale locale,
  }) {
    switch (source) {
      case MetadataSourceKind.bangumi:
        return _setting.get(
          SettingBoxKey.metadataBangumiEnabled,
          defaultValue: _defaultBangumiEnabled(locale),
        ) as bool;
      case MetadataSourceKind.tmdb:
        return _setting.get(
          SettingBoxKey.metadataTmdbEnabled,
          defaultValue: true,
        ) as bool;
    }
  }
}
