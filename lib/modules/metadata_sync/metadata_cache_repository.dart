import 'dart:convert';
import 'dart:math';

import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/request/metadata_client.dart';
import 'package:kazumi/utils/storage.dart';

class MetadataCacheRepository {
  MetadataCacheRepository({
    MockBox<MetadataRecord>? metadataBox,
    MockBox<dynamic>? settingBox,
    DateTime Function()? clock,
  })  : _metadataBox = metadataBox ?? GStorage.metadataCache,
        _settings = settingBox ?? GStorage.setting,
        _clock = clock ?? DateTime.now;

  final MockBox<MetadataRecord> _metadataBox;
  final MockBox<dynamic> _settings;
  final DateTime Function() _clock;

  Duration get _retention => Duration(
        hours: (_settings.get(
              SettingBoxKey.metadataRetentionHours,
              defaultValue: 24,
            ) as int?) ??
            24,
      );

  MetadataRecord? getRecord(String slug) {
    final MetadataRecord? record = _metadataBox.get(slug);
    if (record == null) {
      return null;
    }

    if (_isExpired(record)) {
      _metadataBox.delete(slug);
      return null;
    }
    return record;
  }

  Future<MetadataRecord> upsert({
    required String slug,
    required MetadataFetchResult result,
    Map<String, String>? identifiers,
  }) async {
    final MetadataRecord? existing = _metadataBox.get(slug);
    final MetadataRecord updated = _merge(existing, slug, result, identifiers);
    await _metadataBox.put(slug, updated);
    return updated;
  }

  Future<void> purgeExpired() async {
    final List<dynamic> keysToRemove = <dynamic>[];
    for (final dynamic key in _metadataBox.keys) {
      final MetadataRecord? record = _metadataBox.get(key);
      if (record != null && _isExpired(record)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      await _metadataBox.delete(key);
    }
  }

  bool _isExpired(MetadataRecord record) {
    final DateTime threshold = _clock().subtract(_retention);
    return record.updatedAt.isBefore(threshold);
  }

  MetadataRecord _merge(
    MetadataRecord? existing,
    String slug,
    MetadataFetchResult result,
    Map<String, String>? identifiers,
  ) {
    final Map<String, String> newIdentifiers = <String, String>{}
      ..addAll(existing?.identifiers ?? <String, String>{})
      ..addAll(identifiers ?? <String, String>{});

    switch (result.source) {
      case MetadataSourceKind.bangumi:
        return _mergeBangumi(existing, slug, result, newIdentifiers);
      case MetadataSourceKind.tmdb:
        return _mergeTmdb(existing, slug, result, newIdentifiers);
    }
  }

  MetadataRecord _mergeBangumi(
    MetadataRecord? existing,
    String slug,
    MetadataFetchResult result,
    Map<String, String> identifiers,
  ) {
    final Map<String, dynamic> payload = result.payload;
    final String? nameCn = _asNonEmptyString(payload['name_cn']);
    final String? name = _asNonEmptyString(payload['name']);
    final String primaryTitle = nameCn ??
        name ??
        existing?.displayTitleForLocale(result.locale.toLanguageTag()) ??
        slug;

    final Map<String, String> titles = <String, String>{}
      ..addAll(existing?.alternateTitles ?? <String, String>{});
    if (name != null) {
      titles['ja'] = name;
    }
    if (nameCn != null) {
      titles['zh-CN'] = nameCn;
    }

    final Map<String, String> synopsis = <String, String>{}
      ..addAll(existing?.synopsis ?? <String, String>{});
    final String? summary = _asNonEmptyString(payload['summary']);
    if (summary != null) {
      synopsis[result.locale.toLanguageTag()] = summary;
    }

    final String? poster = _extractPosterUrl(payload['images']);
    final List<EpisodeMetadata> episodes = _mergeEpisodes(
      existing?.episodes ?? const <EpisodeMetadata>[],
      _bangumiEpisodes(payload['eps']),
    );

    final MetadataSourceSnapshot snapshot = MetadataSourceSnapshot(
      sourceId: MetadataSourceKind.bangumi.name,
      lastSyncedAt: _clock(),
      localeTag: result.locale.toLanguageTag(),
      rawPayloadJson: jsonEncode(payload),
    );

    return MetadataRecord(
      slug: slug,
      primaryTitle: primaryTitle,
      alternateTitles: titles,
      synopsis: synopsis,
      posterUrl: poster ?? existing?.posterUrl,
      backdropUrl: existing?.backdropUrl,
      episodes: episodes,
      activeSource: MetadataSourceKind.bangumi.name,
      localeTag: result.locale.toLanguageTag(),
      updatedAt: _clock(),
      identifiers: identifiers,
      sourceSnapshots: _mergeSnapshots(existing?.sourceSnapshots, snapshot),
    );
  }

  MetadataRecord _mergeTmdb(
    MetadataRecord? existing,
    String slug,
    MetadataFetchResult result,
    Map<String, String> identifiers,
  ) {
    final Map<String, dynamic> payload = result.payload;
    final String? localizedName = _asNonEmptyString(payload['name']);
    final String? originalName = _asNonEmptyString(payload['original_name']);
    final String? overview = _asNonEmptyString(payload['overview']);

    final String primaryTitle = localizedName ??
        existing?.displayTitleForLocale(result.locale.toLanguageTag()) ??
        originalName ??
        existing?.primaryTitle ??
        slug;

    final Map<String, String> titles = <String, String>{}
      ..addAll(existing?.alternateTitles ?? <String, String>{});
    if (localizedName != null) {
      titles[result.locale.toLanguageTag()] = localizedName;
    }
    if (originalName != null) {
      titles['original'] = originalName;
    }

    final Map<String, String> synopsis = <String, String>{}
      ..addAll(existing?.synopsis ?? <String, String>{});
    if (overview != null) {
      synopsis[result.locale.toLanguageTag()] = overview;
    }

    final String? posterPath = _asNonEmptyString(payload['poster_path']);
    final String? backdropPath = _asNonEmptyString(payload['backdrop_path']);

    final List<EpisodeMetadata> episodes = _mergeEpisodes(
      existing?.episodes ?? const <EpisodeMetadata>[],
      _tmdbEpisodes(payload['seasons']),
    );

    final MetadataSourceSnapshot snapshot = MetadataSourceSnapshot(
      sourceId: MetadataSourceKind.tmdb.name,
      lastSyncedAt: _clock(),
      localeTag: result.locale.toLanguageTag(),
      rawPayloadJson: jsonEncode(payload),
    );

    return MetadataRecord(
      slug: slug,
      primaryTitle: primaryTitle,
      alternateTitles: titles,
      synopsis: synopsis,
      posterUrl:
          posterPath != null ? _tmdbImageUrl(posterPath) : existing?.posterUrl,
      backdropUrl: backdropPath != null
          ? _tmdbImageUrl(backdropPath)
          : existing?.backdropUrl,
      episodes: episodes,
      activeSource: MetadataSourceKind.tmdb.name,
      localeTag: result.locale.toLanguageTag(),
      updatedAt: _clock(),
      identifiers: identifiers,
      sourceSnapshots: _mergeSnapshots(existing?.sourceSnapshots, snapshot),
    );
  }

  List<EpisodeMetadata> _mergeEpisodes(
    List<EpisodeMetadata> existing,
    List<EpisodeMetadata> incoming,
  ) {
    if (incoming.isEmpty) {
      return existing;
    }
    final Map<int, EpisodeMetadata> merged = <int, EpisodeMetadata>{
      for (final EpisodeMetadata episode in existing) episode.number: episode,
    };
    for (final EpisodeMetadata episode in incoming) {
      merged[episode.number] = episode;
    }
    final List<EpisodeMetadata> ordered = merged.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return ordered;
  }

  List<EpisodeMetadata> _bangumiEpisodes(dynamic raw) {
    if (raw is! List) {
      return const <EpisodeMetadata>[];
    }
    final List<EpisodeMetadata> episodes = <EpisodeMetadata>[];
    for (final dynamic entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final int? sort = _toInt(entry['sort']);
      final int number = sort ??
          _toInt(entry['ep']) ??
          _toInt(entry['id']) ??
          episodes.length + 1;
      episodes.add(
        EpisodeMetadata(
          number: max(number, 1),
          title: _asNonEmptyString(entry['name']) ??
              _asNonEmptyString(entry['name_cn']),
          synopsis: _asNonEmptyString(entry['desc']),
          airDate: _parseDate(entry['airdate']),
          runtimeMinutes: _toInt(entry['duration']),
        ),
      );
    }
    return episodes;
  }

  List<EpisodeMetadata> _tmdbEpisodes(dynamic raw) {
    if (raw is! List) {
      return const <EpisodeMetadata>[];
    }
    final List<EpisodeMetadata> episodes = <EpisodeMetadata>[];
    for (final dynamic season in raw) {
      if (season is! Map<String, dynamic>) continue;
      final dynamic episodesRaw = season['episodes'];
      if (episodesRaw is! List) continue;
      for (final dynamic episode in episodesRaw) {
        if (episode is! Map<String, dynamic>) continue;
        final int number =
            _toInt(episode['episode_number']) ?? (episodes.length + 1);
        episodes.add(
          EpisodeMetadata(
            number: max(number, 1),
            title: _asNonEmptyString(episode['name']),
            synopsis: _asNonEmptyString(episode['overview']),
            airDate: _parseDate(episode['air_date']),
            runtimeMinutes: _toInt(episode['runtime']),
            stillImageUrl: _stillUrl(episode['still_path']),
          ),
        );
      }
    }
    return episodes;
  }

  List<MetadataSourceSnapshot> _mergeSnapshots(
    List<MetadataSourceSnapshot>? existing,
    MetadataSourceSnapshot incoming,
  ) {
    final List<MetadataSourceSnapshot> snapshots = <MetadataSourceSnapshot>[
      if (existing != null) ...existing,
    ];
    snapshots.removeWhere((s) => s.sourceId == incoming.sourceId);
    snapshots.add(incoming);
    return snapshots;
  }

  String? _extractPosterUrl(dynamic rawImages) {
    if (rawImages is Map<String, dynamic>) {
      return _asNonEmptyString(rawImages['large']) ??
          _asNonEmptyString(rawImages['common']) ??
          _asNonEmptyString(rawImages['grid']);
    }
    return null;
  }

  String? _stillUrl(dynamic path) {
    final String? value = _asNonEmptyString(path);
    if (value == null) {
      return null;
    }
    return _tmdbImageUrl(value);
  }

  String _tmdbImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return 'https://image.tmdb.org/t/p/original$path';
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  String? _asNonEmptyString(dynamic value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
