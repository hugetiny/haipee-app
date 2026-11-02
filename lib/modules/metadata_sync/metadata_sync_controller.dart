import 'dart:ui' as ui;

import 'package:haipee/modules/metadata_sync/metadata_cache_repository.dart';
import 'package:haipee/modules/metadata_sync/models/metadata_record.dart';
import 'package:haipee/request/metadata_client.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

class MetadataSyncController {
  MetadataSyncController({
    MetadataClient? client,
    MetadataCacheRepository? repository,
  })  : _client = client ?? MetadataClient(),
        _repository = repository ?? MetadataCacheRepository();

  final MetadataClient _client;
  final MetadataCacheRepository _repository;

  Future<MetadataRecord?> ensureLatest(
    String slug, {
    Map<String, String>? identifiers,
    bool forceRefresh = false,
    ui.Locale? localeOverride,
  }) async {
    final String localeLabel =
        localeOverride?.toLanguageTag() ?? 'system-default';
    HaipeeLogger().log(
      Level.info,
      '[MetadataSyncController] Ensuring metadata for $slug '
      '(forceRefresh: $forceRefresh, locale: $localeLabel)',
    );
    await _repository.purgeExpired();
    final MetadataRecord? existingRecord =
        forceRefresh ? null : _repository.getRecord(slug);
    if (existingRecord != null && !forceRefresh) {
      HaipeeLogger().log(
        Level.debug,
        '[MetadataSyncController] Using cached metadata for $slug '
        '(updated ${existingRecord.updatedAt.toIso8601String()})',
      );
      return existingRecord;
    }

    final MetadataRecord? existing =
        existingRecord ?? _repository.getRecord(slug);
    final Map<String, String> resolvedIdentifiers = <String, String>{
      'bangumi': slug,
      if (existing != null) ...existing.identifiers,
      if (identifiers != null) ...identifiers,
    };

    MetadataRecord? updated = existing;
    final ui.Locale? locale = localeOverride;

    final MetadataFetchResult? bangumi = await _maybeFetch(
      kind: MetadataSourceKind.bangumi,
      identifier: resolvedIdentifiers['bangumi'],
      localeOverride: locale,
      forceRefresh: forceRefresh,
    );
    if (bangumi != null) {
      HaipeeLogger().log(
        Level.info,
        '[MetadataSyncController] Merging Bangumi payload for $slug '
        '(${bangumi.locale.toLanguageTag()})',
      );
      updated = await _repository.upsert(
        slug: slug,
        result: bangumi,
        identifiers: resolvedIdentifiers,
      );
    }

    if (resolvedIdentifiers.containsKey('tmdb')) {
      final MetadataFetchResult? tmdb = await _maybeFetch(
        kind: MetadataSourceKind.tmdb,
        identifier: resolvedIdentifiers['tmdb'],
        localeOverride: locale,
        forceRefresh: forceRefresh,
      );
      if (tmdb != null) {
        HaipeeLogger().log(
          Level.info,
          '[MetadataSyncController] Merging TMDb payload for $slug '
          '(${tmdb.locale.toLanguageTag()})',
        );
        updated = await _repository.upsert(
          slug: slug,
          result: tmdb,
          identifiers: resolvedIdentifiers,
        );
      }
    }

    if (updated != null) {
      HaipeeLogger().log(
        Level.info,
        '[MetadataSyncController] Metadata sync complete for $slug '
        '(activeSource: ${updated.activeSource ?? 'unknown'}, '
        'updatedAt: ${updated.updatedAt.toIso8601String()})',
      );
    } else {
      HaipeeLogger().log(
        Level.warning,
        '[MetadataSyncController] No metadata updates available for $slug',
      );
    }

    return updated ?? existing;
  }

  Future<MetadataFetchResult?> _maybeFetch({
    required MetadataSourceKind kind,
    String? identifier,
    ui.Locale? localeOverride,
    required bool forceRefresh,
  }) async {
    if (identifier == null || identifier.isEmpty) {
      return null;
    }
    return _client.fetchFromSource(
      source: kind,
      identifier: identifier,
      localeOverride: localeOverride,
      forceRefresh: forceRefresh,
    );
  }
}
