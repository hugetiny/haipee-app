import 'dart:convert';

import 'package:hive_ce/hive.dart';

part 'metadata_record.g.dart';

@HiveType(typeId: 7)
class EpisodeMetadata {
  const EpisodeMetadata({
    required this.number,
    this.title,
    this.synopsis,
    this.airDate,
    this.runtimeMinutes,
    this.stillImageUrl,
  });

  @HiveField(0)
  final int number;

  @HiveField(1)
  final String? title;

  @HiveField(2)
  final String? synopsis;

  @HiveField(3)
  final DateTime? airDate;

  @HiveField(4)
  final int? runtimeMinutes;

  @HiveField(5)
  final String? stillImageUrl;

  EpisodeMetadata copyWith({
    int? number,
    String? title,
    String? synopsis,
    DateTime? airDate,
    int? runtimeMinutes,
    String? stillImageUrl,
  }) {
    return EpisodeMetadata(
      number: number ?? this.number,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      airDate: airDate ?? this.airDate,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      stillImageUrl: stillImageUrl ?? this.stillImageUrl,
    );
  }
}

@HiveType(typeId: 8)
class MetadataSourceSnapshot {
  const MetadataSourceSnapshot({
    required this.sourceId,
    required this.lastSyncedAt,
    required this.localeTag,
    this.rawPayloadJson,
  });

  @HiveField(0)
  final String sourceId;

  @HiveField(1)
  final DateTime lastSyncedAt;

  @HiveField(2)
  final String localeTag;

  @HiveField(3)
  final String? rawPayloadJson;

  Map<String, dynamic>? get rawPayload {
    if (rawPayloadJson == null || rawPayloadJson!.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(rawPayloadJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  MetadataSourceSnapshot copyWith({
    String? sourceId,
    DateTime? lastSyncedAt,
    String? localeTag,
    String? rawPayloadJson,
  }) {
    return MetadataSourceSnapshot(
      sourceId: sourceId ?? this.sourceId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      localeTag: localeTag ?? this.localeTag,
      rawPayloadJson: rawPayloadJson ?? this.rawPayloadJson,
    );
  }
}

@HiveType(typeId: 9)
class MetadataRecord extends HiveObject {
  MetadataRecord({
    required this.slug,
    required this.primaryTitle,
    required this.localeTag,
    required this.updatedAt,
    this.alternateTitles = const <String, String>{},
    this.synopsis = const <String, String>{},
    this.posterUrl,
    this.backdropUrl,
    this.episodes = const <EpisodeMetadata>[],
    this.activeSource,
    this.identifiers = const <String, String>{},
    this.sourceSnapshots = const <MetadataSourceSnapshot>[],
  });

  @HiveField(0)
  final String slug;

  @HiveField(1)
  final String primaryTitle;

  @HiveField(2)
  final Map<String, String> alternateTitles;

  @HiveField(3)
  final Map<String, String> synopsis;

  @HiveField(4)
  final String? posterUrl;

  @HiveField(5)
  final String? backdropUrl;

  @HiveField(6)
  final List<EpisodeMetadata> episodes;

  @HiveField(7)
  final String? activeSource;

  @HiveField(8)
  final String localeTag;

  @HiveField(9)
  final DateTime updatedAt;

  @HiveField(10)
  final Map<String, String> identifiers;

  @HiveField(11)
  final List<MetadataSourceSnapshot> sourceSnapshots;

  String displayTitleForLocale(String locale) {
    if (locale.isEmpty) {
      return primaryTitle;
    }
    return alternateTitles[locale] ??
        alternateTitles[locale.split('-').first] ??
        primaryTitle;
  }

  String? synopsisForLocale(String locale) {
    if (locale.isEmpty) {
      return synopsis[localeTag] ?? synopsis[locale.split('-').first];
    }
    return synopsis[locale] ?? synopsis[locale.split('-').first];
  }

  MetadataRecord copyWith({
    String? primaryTitle,
    Map<String, String>? alternateTitles,
    Map<String, String>? synopsis,
    String? posterUrl,
    String? backdropUrl,
    List<EpisodeMetadata>? episodes,
    String? activeSource,
    String? localeTag,
    DateTime? updatedAt,
    Map<String, String>? identifiers,
    List<MetadataSourceSnapshot>? sourceSnapshots,
  }) {
    return MetadataRecord(
      slug: slug,
      primaryTitle: primaryTitle ?? this.primaryTitle,
      alternateTitles: alternateTitles ?? this.alternateTitles,
      synopsis: synopsis ?? this.synopsis,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      episodes: episodes ?? this.episodes,
      activeSource: activeSource ?? this.activeSource,
      localeTag: localeTag ?? this.localeTag,
      updatedAt: updatedAt ?? this.updatedAt,
      identifiers: identifiers ?? this.identifiers,
      sourceSnapshots: sourceSnapshots ?? this.sourceSnapshots,
    );
  }
}
