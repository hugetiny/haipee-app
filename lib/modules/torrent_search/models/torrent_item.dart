enum TorrentSourceType {
  mikan,
  nyaa,
  torznab,
}

class TorrentItem {
  final String title;
  final String magnetUrl;
  final String? torrentUrl;
  final String fileSize;
  final String publishDate;
  final TorrentSourceType source;
  final int seeders;
  final int leechers;

  // 经过标题清洗后的结构化元数据（小白用户友好）
  final String? cleanedTitle;
  final String? episode;
  final String? subgroup;
  final String? resolution;
  final String? language;

  const TorrentItem({
    required this.title,
    required this.magnetUrl,
    this.torrentUrl,
    this.fileSize = '',
    this.publishDate = '',
    required this.source,
    this.seeders = 0,
    this.leechers = 0,
    this.cleanedTitle,
    this.episode,
    this.subgroup,
    this.resolution,
    this.language,
  });

  TorrentItem copyWith({
    String? title,
    String? magnetUrl,
    String? torrentUrl,
    String? fileSize,
    String? publishDate,
    TorrentSourceType? source,
    int? seeders,
    int? leechers,
    String? cleanedTitle,
    String? episode,
    String? subgroup,
    String? resolution,
    String? language,
  }) {
    return TorrentItem(
      title: title ?? this.title,
      magnetUrl: magnetUrl ?? this.magnetUrl,
      torrentUrl: torrentUrl ?? this.torrentUrl,
      fileSize: fileSize ?? this.fileSize,
      publishDate: publishDate ?? this.publishDate,
      source: source ?? this.source,
      seeders: seeders ?? this.seeders,
      leechers: leechers ?? this.leechers,
      cleanedTitle: cleanedTitle ?? this.cleanedTitle,
      episode: episode ?? this.episode,
      subgroup: subgroup ?? this.subgroup,
      resolution: resolution ?? this.resolution,
      language: language ?? this.language,
    );
  }

  /// 小白友好的精炼副标题，例如："爱恋字幕组 · 1080P · 简中 · 850 MB"
  String get simplifiedSubtitle {
    final parts = <String>[];
    if (subgroup != null && subgroup!.isNotEmpty) parts.add(subgroup!);
    if (resolution != null && resolution!.isNotEmpty) parts.add(resolution!);
    if (language != null && language!.isNotEmpty) parts.add(language!);
    if (fileSize.isNotEmpty) parts.add(fileSize);
    return parts.join(' · ');
  }

  /// 小白友好的主标题：如果有识别出集数，优先展示 "第 XX 集"，否则展示清洗后的标题
  String get displayTitle {
    if (episode != null && episode!.isNotEmpty) {
      return '第 $episode 集';
    }
    if (cleanedTitle != null && cleanedTitle!.isNotEmpty) {
      return cleanedTitle!;
    }
    return title;
  }
}
