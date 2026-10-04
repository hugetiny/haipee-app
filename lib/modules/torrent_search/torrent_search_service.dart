import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/sources/mikan_source.dart';
import 'package:kazumi/modules/torrent_search/sources/nyaa_source.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/modules/torrent_search/sources/torznab_source.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class TorrentSearchState {
  final bool isLoading;
  final String? error;
  final String keyword;
  final List<TorrentItem> items;
  final Map<TorrentSourceType, int> sourceCount;

  const TorrentSearchState({
    this.isLoading = false,
    this.error,
    this.keyword = '',
    this.items = const [],
    this.sourceCount = const {},
  });

  TorrentSearchState copyWith({
    bool? isLoading,
    String? error,
    String? keyword,
    List<TorrentItem>? items,
    Map<TorrentSourceType, int>? sourceCount,
  }) {
    return TorrentSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      sourceCount: sourceCount ?? this.sourceCount,
    );
  }
}

class TorrentSearchService {
  final List<TorrentSource> _sources;

  TorrentSearchService({
    List<TorrentSource>? sources,
  }) : _sources = sources ??
            [
              MikanSource(),
              NyaaSource(),
            ];

  void addTorznabSource({
    required String host,
    required String apiKey,
    String? name,
  }) {
    _sources.add(TorznabSource(
      host: host,
      apiKey: apiKey,
      customName: name,
    ));
  }

  Future<List<TorrentItem>> searchAll(String keyword) async {
    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty) return [];

    final activeSources = _sources.where((s) => s.enabled).toList();
    if (activeSources.isEmpty) return [];

    // 并发请求所有源，单个源出错不影响其他源
    final futures = activeSources.map((src) async {
      try {
        return await src.search(cleanKeyword);
      } catch (e) {
        KazumiLogger().log(Level.warning, '[TorrentSearch] 源 ${src.name} 异常: $e');
        return <TorrentItem>[];
      }
    });

    final nestedResults = await Future.wait(futures);
    final allItems = <TorrentItem>[];
    for (final list in nestedResults) {
      allItems.addAll(list);
    }

    // 去重（根据 magnetUrl 或标题）
    final seenMagnets = <String>{};
    final uniqueItems = <TorrentItem>[];

    for (final item in allItems) {
      final key = item.magnetUrl.isNotEmpty ? item.magnetUrl : item.title;
      if (!seenMagnets.contains(key)) {
        seenMagnets.add(key);
        uniqueItems.add(item);
      }
    }

    // 智能排序：
    // 1. 优先有清晰集数标识的
    // 2. 其次按做种数降序（seeders）
    // 3. 再次按发布日期排序
    uniqueItems.sort((a, b) {
      final aHasEp = a.episode != null ? 1 : 0;
      final bHasEp = b.episode != null ? 1 : 0;
      if (aHasEp != bHasEp) {
        return bHasEp.compareTo(aHasEp);
      }
      if (a.seeders != b.seeders) {
        return b.seeders.compareTo(a.seeders);
      }
      return b.publishDate.compareTo(a.publishDate);
    });

    return uniqueItems;
  }
}

// Riverpod 3.x 状态管理器
class TorrentSearchNotifier extends Notifier<TorrentSearchState> {
  late final TorrentSearchService _service;

  @override
  TorrentSearchState build() {
    _service = TorrentSearchService();
    return const TorrentSearchState();
  }

  Future<void> search(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) {
      state = const TorrentSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, keyword: clean, error: null);

    try {
      final results = await _service.searchAll(clean);
      final countMap = <TorrentSourceType, int>{};
      for (final item in results) {
        countMap[item.source] = (countMap[item.source] ?? 0) + 1;
      }

      state = state.copyWith(
        isLoading: false,
        items: results,
        sourceCount: countMap,
      );
    } catch (e) {
      KazumiLogger().log(Level.error, '[TorrentSearchNotifier] 搜索出错: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void configureTorznab({required String host, required String apiKey}) {
    _service.addTorznabSource(host: host, apiKey: apiKey);
  }
}

final torrentSearchProvider =
    NotifierProvider<TorrentSearchNotifier, TorrentSearchState>(
  TorrentSearchNotifier.new,
);
