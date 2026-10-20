import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/sources/mikan_source.dart';
import 'package:kazumi/modules/torrent_search/sources/nyaa_source.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/modules/torrent_search/sources/torznab_source.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class TorrentSearchState {
  final bool isLoading;
  final String? error;
  final String keyword;
  final List<TorrentItem> items;
  final Map<TorrentSourceType, int> sourceCount;
  final Map<TorrentCategory, int> categoryCounts;
  final TorrentCategory categoryFilter;
  final TorrentSortMode sortMode;
  final bool sortAscending;
  final bool hideCam;
  final String? resolutionFilter;
  final String? indexerFilter;

  const TorrentSearchState({
    this.isLoading = false,
    this.error,
    this.keyword = '',
    this.items = const [],
    this.sourceCount = const {},
    this.categoryCounts = const {},
    this.categoryFilter = TorrentCategory.all,
    this.sortMode = TorrentSortMode.seeders,
    this.sortAscending = false,
    this.hideCam = false,
    this.resolutionFilter,
    this.indexerFilter,
  });

  List<dynamic> get bangumiItems => const [];
  dynamic get activeBangumiItem => null;

  List<TorrentItem> get filteredItems {
    var list = items;
    if (categoryFilter != TorrentCategory.all) {
      list = list.where((i) => i.category == categoryFilter).toList();
    }
    if (hideCam) {
      list = list.where((i) => !i.isCam).toList();
    }
    if (resolutionFilter != null &&
        resolutionFilter!.isNotEmpty &&
        resolutionFilter != '全部') {
      list = list
          .where((i) =>
              i.resolution?.toLowerCase() == resolutionFilter!.toLowerCase())
          .toList();
    }
    if (indexerFilter != null &&
        indexerFilter!.isNotEmpty &&
        indexerFilter != '全部') {
      list = list.where((i) => i.effectiveSourceName == indexerFilter).toList();
    }
    return TorrentSearchService.sortItems(list, sortMode,
        ascending: sortAscending);
  }

  TorrentSearchState copyWith({
    bool? isLoading,
    String? error,
    String? keyword,
    List<TorrentItem>? items,
    Map<TorrentSourceType, int>? sourceCount,
    Map<TorrentCategory, int>? categoryCounts,
    TorrentCategory? categoryFilter,
    TorrentSortMode? sortMode,
    bool? sortAscending,
    bool? hideCam,
    String? resolutionFilter,
    String? indexerFilter,
  }) {
    return TorrentSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      sourceCount: sourceCount ?? this.sourceCount,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      sortMode: sortMode ?? this.sortMode,
      sortAscending: sortAscending ?? this.sortAscending,
      hideCam: hideCam ?? this.hideCam,
      resolutionFilter: resolutionFilter ?? this.resolutionFilter,
      indexerFilter: indexerFilter ?? this.indexerFilter,
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

  static Future<({bool success, String message, List<String> indexers})> testProwlarr(
    String endpoint,
    String apiKey,
  ) async {
    if (endpoint.isEmpty) {
      return (success: false, message: 'Endpoint不能为空', indexers: <String>[]);
    }
    try {
      final dio = Dio(BaseOptions(
        baseUrl: endpoint.endsWith('/') ? endpoint : '$endpoint/',
        headers: {'X-Api-Key': apiKey},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get('api/v1/indexer');
      if (res.statusCode == 200 && res.data is List) {
        final names = (res.data as List)
            .map((e) => (e is Map ? e['name']?.toString() : null) ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        return (
          success: true,
          message: '连接成功，发现 ${names.length} 个索引器',
          indexers: names,
        );
      }
      return (
        success: false,
        message: '连接失败: HTTP ${res.statusCode}',
        indexers: <String>[],
      );
    } catch (e) {
      return (
        success: false,
        message: '连接错误: $e',
        indexers: <String>[],
      );
    }
  }

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

  List<TorrentSource> get sources => List.unmodifiable(_sources);

  static List<TorrentItem> sortItems(
    List<TorrentItem> items,
    TorrentSortMode sortMode, {
    bool ascending = false,
  }) {
    final list = List<TorrentItem>.from(items);
    switch (sortMode) {
      case TorrentSortMode.seeders:
        list.sort((a, b) => ascending
            ? a.seeders.compareTo(b.seeders)
            : b.seeders.compareTo(a.seeders));
        break;
      case TorrentSortMode.leechers:
        list.sort((a, b) => ascending
            ? a.leechers.compareTo(b.leechers)
            : b.leechers.compareTo(a.leechers));
        break;
      case TorrentSortMode.size:
        list.sort((a, b) {
          final sizeA = a.effectiveSizeBytes;
          final sizeB = b.effectiveSizeBytes;

          // 未知大小（<= 0）的项目，无论升序还是降序，都绝不能浮到上面，必须沉底！
          if (sizeA <= 0 && sizeB <= 0) return 0;
          if (sizeA <= 0) return 1; // a 没有大小 -> 沉底（排在 b 后面）
          if (sizeB <= 0) return -1; // b 没有大小 -> 沉底（a 排在前面）

          return ascending ? sizeA.compareTo(sizeB) : sizeB.compareTo(sizeA);
        });
        break;
      case TorrentSortMode.age:
        list.sort((a, b) {
          final dateA = a.effectivePublishDate;
          final dateB = b.effectivePublishDate;

          // 没有有效日期的项目，无论升序还是降序，都绝不能浮到上面，必须沉底！
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1; // a 没有日期 -> 沉底（排在 b 后面）
          if (dateB == null) return -1; // b 没有日期 -> 沉底（a 排在前面）

          return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
        break;
      case TorrentSortMode.title:
        list.sort((a, b) {
          final cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return ascending ? cmp : -cmp;
        });
        break;
      case TorrentSortMode.source:
        list.sort((a, b) {
          final cmp = a.effectiveSourceName
              .toLowerCase()
              .compareTo(b.effectiveSourceName.toLowerCase());
          return ascending ? cmp : -cmp;
        });
        break;
      case TorrentSortMode.smart:
        list.sort((a, b) {
          final aHasEp = a.episode != null ? 1 : 0;
          final bHasEp = b.episode != null ? 1 : 0;
          if (aHasEp != bHasEp) {
            final cmp = bHasEp.compareTo(aHasEp);
            return ascending ? -cmp : cmp;
          }
          if (a.seeders != b.seeders) {
            final cmp = b.seeders.compareTo(a.seeders);
            return ascending ? -cmp : cmp;
          }
          final dateA = a.effectivePublishDate;
          final dateB = b.effectivePublishDate;
          if (dateA != null && dateB != null) {
            final cmp = dateB.compareTo(dateA);
            return ascending ? -cmp : cmp;
          }
          if (dateA != null) return -1;
          if (dateB != null) return 1;
          return 0;
        });
        break;
    }
    return list;
  }

  static List<TorrentItem> _sortItems(
    List<TorrentItem> items,
    TorrentSortMode sortMode, {
    bool ascending = false,
  }) =>
      sortItems(items, sortMode, ascending: ascending);

  Stream<List<TorrentItem>> searchStream(
    String keyword, {
    int concurrency = 4,
    TorrentSortMode sortMode = TorrentSortMode.seeders,
    Duration sourceTimeout = const Duration(seconds: 15),
  }) async* {
    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty) return;

    final activeSources = _sources.where((s) => s.enabled).toList();
    if (activeSources.isEmpty) return;

    final allItems = <TorrentItem>[];
    final seenKeys = <String>{};
    final controller = StreamController<List<TorrentItem>>();

    Future.wait(activeSources.map((src) async {
      try {
        final list = await src.search(cleanKeyword).timeout(sourceTimeout);
        if (list.isNotEmpty) {
          bool added = false;
          for (final item in list) {
            final key = item.magnetUrl.isNotEmpty ? item.magnetUrl : item.title;
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              allItems.add(item);
              added = true;
            }
          }
          if (added) {
            controller.add(_sortItems(allItems, sortMode));
          }
        }
      } catch (e) {
        KazumiLogger().log(Level.warning, '[TorrentSearch] 源 ${src.name} 异常: $e');
      }
    })).whenComplete(() {
      controller.close();
    });

    yield* controller.stream;
  }

  Future<List<TorrentItem>> searchAll(
    String keyword, {
    TorrentSortMode sortMode = TorrentSortMode.smart,
    Duration sourceTimeout = const Duration(seconds: 15),
  }) async {
    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty) return [];

    final activeSources = _sources.where((s) => s.enabled).toList();
    if (activeSources.isEmpty) return [];

    // 并发请求所有源，单个源出错不影响其他源
    final futures = activeSources.map((src) async {
      try {
        return await src.search(cleanKeyword).timeout(sourceTimeout);
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

    return _sortItems(uniqueItems, sortMode);
  }
}

// Riverpod 3.x 状态管理器
class TorrentSearchNotifier extends Notifier<TorrentSearchState> {
  final TorrentSearchService? _initialService;
  late final TorrentSearchService _service;
  int _searchRequestId = 0;

  TorrentSearchNotifier({TorrentSearchService? service})
      : _initialService = service;

  @override
  TorrentSearchState build() {
    _service = _initialService ?? TorrentSearchService();
    return const TorrentSearchState();
  }

  Future<void> search(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) {
      state = const TorrentSearchState();
      return;
    }

    // Prevent duplicate redundant searches for the exact same query when already loading
    if (state.isLoading && state.keyword == clean) {
      return;
    }

    final currentRequestId = ++_searchRequestId;
    state = state.copyWith(isLoading: true, keyword: clean, error: null);
    ref.read(searchHistoryProvider.notifier).addHistory(clean);

    try {
      final activePlugins = ref
          .read(indexerPluginsProvider)
          .plugins
          .where((p) => p.isEnabled)
          .toList();

      final sources = <TorrentSource>[
        ..._service.sources,
        ...activePlugins,
      ];
      final service = TorrentSearchService(sources: sources);

      final results = await service.searchAll(clean, sortMode: state.sortMode);
      if (currentRequestId != _searchRequestId) {
        // Discard superseded search response
        return;
      }
      final countMap = <TorrentSourceType, int>{};
      final catCount = <TorrentCategory, int>{};
      for (final item in results) {
        countMap[item.source] = (countMap[item.source] ?? 0) + 1;
        catCount[item.category] = (catCount[item.category] ?? 0) + 1;
      }

      state = state.copyWith(
        isLoading: false,
        items: results,
        sourceCount: countMap,
        categoryCounts: catCount,
      );
    } catch (e) {
      if (currentRequestId != _searchRequestId) return;
      KazumiLogger().log(Level.warning, '[TorrentSearchNotifier] 搜索异常: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCategoryFilter(TorrentCategory category) {
    state = state.copyWith(categoryFilter: category);
  }

  void setSortMode(TorrentSortMode mode, {bool? ascending}) {
    final bool defaultAsc =
        (mode == TorrentSortMode.title || mode == TorrentSortMode.source);
    state = state.copyWith(
      sortMode: mode,
      sortAscending: ascending ??
          (state.sortMode == mode ? !state.sortAscending : defaultAsc),
    );
  }

  void toggleHideCam() {
    state = state.copyWith(hideCam: !state.hideCam);
  }

  void setResolutionFilter(String? res) {
    state = state.copyWith(resolutionFilter: res);
  }

  void setIndexerFilter(String? idx) {
    state = state.copyWith(indexerFilter: idx);
  }

  void reloadProwlarrConfig() {
    // 重新加载配置
  }

  void configureTorznab({required String host, required String apiKey}) {
    _service.addTorznabSource(host: host, apiKey: apiKey);
  }
}

final torrentSearchProvider =
    NotifierProvider<TorrentSearchNotifier, TorrentSearchState>(
  TorrentSearchNotifier.new,
);
