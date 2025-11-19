import 'dart:convert';

class EpisodeMetadata {
  const EpisodeMetadata({
    required this.number,
    this.title,
    this.synopsis,
    this.airDate,
    this.runtimeMinutes,
    this.stillImageUrl,
  });

  final int number;

  final String? title;

  final String? synopsis;

  final DateTime? airDate;

  final int? runtimeMinutes;

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

  factory EpisodeMetadata.fromJson(Map<String, dynamic> json) {
    return EpisodeMetadata(
      number: json['number'] as int,
      title: json['title'] as String?,
      synopsis: json['synopsis'] as String?,
      airDate: json['airDate'] != null ? DateTime.parse(json['airDate'] as String) : null,
      runtimeMinutes: json['runtimeMinutes'] as int?,
      stillImageUrl: json['stillImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'synopsis': synopsis,
      'airDate': airDate?.toIso8601String(),
      'runtimeMinutes': runtimeMinutes,
      'stillImageUrl': stillImageUrl,
    };
  }
}

class MetadataSourceSnapshot {
  const MetadataSourceSnapshot({
    required this.sourceId,
    required this.lastSyncedAt,
    required this.localeTag,
    this.rawPayloadJson,
  });

  final String sourceId;

  final DateTime lastSyncedAt;

  final String localeTag;

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

  factory MetadataSourceSnapshot.fromJson(Map<String, dynamic> json) {
    return MetadataSourceSnapshot(
      sourceId: json['sourceId'] as String,
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
      localeTag: json['localeTag'] as String,
      rawPayloadJson: json['rawPayloadJson'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'localeTag': localeTag,
      'rawPayloadJson': rawPayloadJson,
    };
  }
}

class MetadataRecord {
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

  final String slug;

  final String primaryTitle;

  final Map<String, String> alternateTitles;

  final Map<String, String> synopsis;

  final String? posterUrl;

  final String? backdropUrl;

  final List<EpisodeMetadata> episodes;

  final String? activeSource;

  final String localeTag;

  final DateTime updatedAt;

  final Map<String, String> identifiers;

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

  factory MetadataRecord.fromJson(Map<String, dynamic> json) {
    return MetadataRecord(
      slug: json['slug'] as String,
      primaryTitle: json['primaryTitle'] as String,
      localeTag: json['localeTag'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      alternateTitles: Map<String, String>.from(json['alternateTitles'] ?? {}),
      synopsis: Map<String, String>.from(json['synopsis'] ?? {}),
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => EpisodeMetadata.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeSource: json['activeSource'] as String?,
      identifiers: Map<String, String>.from(json['identifiers'] ?? {}),
      sourceSnapshots: (json['sourceSnapshots'] as List<dynamic>?)
              ?.map((e) => MetadataSourceSnapshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'primaryTitle': primaryTitle,
      'localeTag': localeTag,
      'updatedAt': updatedAt.toIso8601String(),
      'alternateTitles': alternateTitles,
      'synopsis': synopsis,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'activeSource': activeSource,
      'identifiers': identifiers,
      'sourceSnapshots': sourceSnapshots.map((e) => e.toJson()).toList(),
    };
  }
}
