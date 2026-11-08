import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/plugins/rule_cover_extractor.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

enum OnlineSourceFilter {
  all(id: 'all', label: '全部', icon: Icons.auto_awesome_motion_outlined),
  video(id: 'video', label: '视频', icon: Icons.video_library_outlined),
  live(id: 'live', label: '直播', icon: Icons.live_tv_outlined),
  haipee(id: 'haipee', label: 'Haipee 规则', icon: Icons.extension_rounded),
  maccms(id: 'maccms', label: 'MacCMS 规则', icon: Icons.movie_outlined),
  tvbox(id: 'tvbox', label: 'TVBox 规则', icon: Icons.widgets_outlined),
  iptv(id: 'iptv', label: 'IPTV 规则', icon: Icons.live_tv_outlined),
  piped(id: 'piped', label: 'Piped 规则', icon: Icons.play_circle_outline_rounded),
  // Backward compatibility legacy aliases
  anime(id: 'anime', label: 'Haipee 规则', icon: Icons.extension_rounded),
  bilibili(id: 'bilibili', label: 'Piped 规则', icon: Icons.play_circle_outline_rounded),
  douyin(id: 'douyin', label: 'Piped 规则', icon: Icons.play_circle_outline_rounded);

  static OnlineSourceFilter get kazumi => haipee;

  final String id;
  final String label;
  final IconData icon;

  const OnlineSourceFilter({
    required this.id,
    required this.label,
    required this.icon,
  });

  /// 视频直播界面：内容总览筛选
  static const List<OnlineSourceFilter> overviewFilters = [
    OnlineSourceFilter.all,
    OnlineSourceFilter.video,
    OnlineSourceFilter.live,
  ];

  /// 视频直播界面：5 大视听流媒体规则协议类型
  static const List<OnlineSourceFilter> ruleProtocolFilters = [
    OnlineSourceFilter.haipee,
    OnlineSourceFilter.maccms,
    OnlineSourceFilter.tvbox,
    OnlineSourceFilter.iptv,
    OnlineSourceFilter.piped,
  ];

  /// 视频直播界面的全部主筛选列表
  static const List<OnlineSourceFilter> audiovisualFilters = [
    OnlineSourceFilter.all,
    OnlineSourceFilter.video,
    OnlineSourceFilter.live,
    OnlineSourceFilter.haipee,
    OnlineSourceFilter.maccms,
    OnlineSourceFilter.tvbox,
    OnlineSourceFilter.iptv,
    OnlineSourceFilter.piped,
  ];
}

class OnlineVideoSearchState {
  final String keyword;
  final bool isSearching;
  final int completedSources;
  final int totalSources;
  final List<BiliVideoItem> allResults;
  final OnlineSourceFilter selectedFilter;
  final int sessionId;
  final Map<String, String> synergyCovers;

  const OnlineVideoSearchState({
    this.keyword = '',
    this.isSearching = false,
    this.completedSources = 0,
    this.totalSources = 0,
    this.allResults = const [],
    this.selectedFilter = OnlineSourceFilter.all,
    this.sessionId = 0,
    this.synergyCovers = const {},
  });

  /// 解析指定条目的跨源协同备用封面（当主封面为空或第三方采集站图片 CDN 劫持失效时自动接管）
  String resolveFallbackCover(BiliVideoItem item) {
    final normTitle = RuleCoverExtractor.normalizeTitleForSynergy(item.title);
    if (normTitle.isNotEmpty) {
      final exact = synergyCovers[normTitle];
      if (exact != null && exact.isNotEmpty && exact != item.pic) {
        return exact;
      }
      for (final entry in synergyCovers.entries) {
        if (entry.key.length >= 2 &&
            entry.value != item.pic &&
            (normTitle.contains(entry.key) || entry.key.contains(normTitle))) {
          return entry.value;
        }
      }
    }
    final normKeyword = RuleCoverExtractor.normalizeTitleForSynergy(keyword);
    if (normKeyword.isNotEmpty) {
      final keywordCover = synergyCovers[normKeyword];
      if (keywordCover != null && keywordCover.isNotEmpty && keywordCover != item.pic) {
        return keywordCover;
      }
    }
    return '';
  }

  static bool isLiveItem(BiliVideoItem item) {
    return item.resolvedRuleType == 'iptv' ||
        item.ruleType == 'live' ||
        item.ruleType == 'iptv' ||
        item.tag == '电视直播' ||
        item.tag == 'IPTV 规则' ||
        item.tag.contains('IPTV') ||
        item.duration == '实时直播' ||
        (item.tag.contains('直播') && !item.tag.contains('B站'));
  }

  List<BiliVideoItem> get videoResults =>
      allResults.where((item) => !isLiveItem(item)).toList();

  List<BiliVideoItem> get liveResults =>
      allResults.where((item) => isLiveItem(item)).toList();

  List<BiliVideoItem> resultsForFilter(OnlineSourceFilter filter, [List<BiliVideoItem>? fallbackList]) {
    final list = allResults.isNotEmpty ? allResults : (fallbackList ?? const []);
    switch (filter) {
      case OnlineSourceFilter.all:
        return list;
      case OnlineSourceFilter.video:
        return list.where((item) => !isLiveItem(item)).toList();
      case OnlineSourceFilter.live:
        return list.where((item) => isLiveItem(item)).toList();
      case OnlineSourceFilter.iptv:
        return list
            .where((item) =>
                item.resolvedRuleType == 'iptv' ||
                item.ruleType == 'iptv' ||
                item.tag.contains('IPTV') ||
                item.duration == '实时直播')
            .toList();
      case OnlineSourceFilter.haipee:
      case OnlineSourceFilter.anime:
        return list
            .where((item) =>
                item.resolvedRuleType == 'haipee' ||
                item.resolvedRuleType == 'kazumi' ||
                item.ruleType == 'anime' ||
                item.ruleType == 'haipee' ||
                item.ruleType == 'kazumi')
            .toList();
      case OnlineSourceFilter.maccms:
        return list
            .where((item) =>
                item.resolvedRuleType == 'maccms' ||
                item.ruleType == 'maccms' ||
                item.tag.contains('苹果CMS') ||
                item.tag.contains('MacCMS') ||
                item.tag.contains('采集'))
            .toList();
      case OnlineSourceFilter.tvbox:
        return list
            .where((item) =>
                item.resolvedRuleType == 'tvbox' ||
                item.ruleType == 'tvbox' ||
                item.tag.contains('TVBox') ||
                item.tag.contains('tvbox') ||
                item.tag.contains('盒子'))
            .toList();
      case OnlineSourceFilter.piped:
      case OnlineSourceFilter.bilibili:
      case OnlineSourceFilter.douyin:
        return list
            .where((item) =>
                item.resolvedRuleType == 'piped' ||
                item.ruleType == 'piped' ||
                item.ruleType == 'bilibili' ||
                item.ruleType == 'douyin' ||
                item.tag.contains('Piped') ||
                item.tag.contains('哔哩哔哩') ||
                item.tag.contains('抖音'))
            .toList();
    }
  }

  List<BiliVideoItem> get currentFilteredResults => resultsForFilter(selectedFilter);

  int countForFilter(OnlineSourceFilter filter, [List<BiliVideoItem>? fallbackList]) {
    return resultsForFilter(filter, fallbackList).length;
  }

  OnlineVideoSearchState copyWith({
    String? keyword,
    bool? isSearching,
    int? completedSources,
    int? totalSources,
    List<BiliVideoItem>? allResults,
    OnlineSourceFilter? selectedFilter,
    int? sessionId,
    Map<String, String>? synergyCovers,
  }) {
    return OnlineVideoSearchState(
      keyword: keyword ?? this.keyword,
      isSearching: isSearching ?? this.isSearching,
      completedSources: completedSources ?? this.completedSources,
      totalSources: totalSources ?? this.totalSources,
      allResults: allResults ?? this.allResults,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      sessionId: sessionId ?? this.sessionId,
      synergyCovers: synergyCovers ?? this.synergyCovers,
    );
  }
}

class OnlineVideoSearchNotifier extends Notifier<OnlineVideoSearchState> {
  @override
  OnlineVideoSearchState build() {
    return const OnlineVideoSearchState();
  }

  /// 一瞬间切换分类标签，完全不影响正在后台进行的并发网络请求
  void setFilter(OnlineSourceFilter filter) {
    if (state.selectedFilter != filter) {
      state = state.copyWith(selectedFilter: filter);
    }
  }

  /// 清空搜索栏与会话
  void clear() {
    state = state.copyWith(
      keyword: '',
      isSearching: false,
      completedSources: 0,
      totalSources: 0,
      allResults: const [],
      sessionId: state.sessionId + 1,
      synergyCovers: const {},
    );
  }

  /// 发起全网多源异步并发搜索
  Future<void> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final sessionId = state.sessionId + 1;
    final pluginsState = ref.read(pluginsProvider);
    final isBiliRuleEnabled = pluginsState.enabledPlugins.any((p) => p.isBilibili) ||
        (pluginsState.isPluginEnabled('bilibili') &&
            pluginsState.pluginList.any((p) => p.isBilibili || p.name == 'bilibili'));
    final isDouyinRuleEnabled = pluginsState.enabledPlugins.any((p) => p.isDouyin) ||
        (pluginsState.isPluginEnabled('douyin') &&
            pluginsState.pluginList.any((p) => p.isDouyin || p.name == 'douyin'));
    final streamingPlugins = pluginsState.enabledPlugins
        .where((plugin) =>
            !plugin.isBilibili && !plugin.isDouyin && plugin.ruleType.isStreamingDomain)
        .toList();

    final totalSources = (isBiliRuleEnabled ? 1 : 0) +
        (isDouyinRuleEnabled ? 1 : 0) +
        streamingPlugins.length;

    // 若在直播标签下粘贴了视频直链或BV号，自动切换至视频分类以直观呈现
    final hasDirectVideo = DouyinService.hasDouyinPattern(clean) ||
        RegExp(r'BV[a-zA-Z0-9]{10}').hasMatch(clean);
    final initialFilter = (hasDirectVideo && state.selectedFilter == OnlineSourceFilter.live)
        ? OnlineSourceFilter.video
        : state.selectedFilter;

    // 立即进入搜索状态并清空旧结果
    state = state.copyWith(
      keyword: clean,
      isSearching: totalSources > 0,
      completedSources: 0,
      totalSources: totalSources,
      allResults: const [],
      selectedFilter: initialFilter,
      sessionId: sessionId,
      synergyCovers: const {},
    );

    if (totalSources == 0) return;

    // 0. 后台非阻塞 Bangumi 官方高清海报联动补全（不计入规则进度，仅用于同名无封面规则源智能补全）
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_enrichWithBangumiCovers(clean, sessionId));
    }

    // 1. 直链快捷匹配 (抖音短视频)
    if (DouyinService.hasDouyinPattern(clean)) {
      DouyinService.extractVideo(clean).then((directDouyinItem) {
        if (directDouyinItem != null && state.sessionId == sessionId) {
          final directItem = BiliVideoItem(
            bvid: 'douyin_${directDouyinItem.id}',
            title: directDouyinItem.title,
            author: directDouyinItem.author.isNotEmpty ? directDouyinItem.author : '抖音',
            pic: directDouyinItem.cover,
            duration: directDouyinItem.duration > 0
                ? '${directDouyinItem.duration}s'
                : '短视频',
            description: directDouyinItem.playUrl,
            tag: 'Piped · 抖音',
            ruleType: 'piped',
          );
          _insertDirectMatch(directItem, sessionId);
        }
      }).catchError((e) {
        HaipeeLogger().log(Level.warning, '抖音直链解析异常: $e');
      });
    }

    // 2. 直链快捷匹配 (B站 BV 号)
    final bvMatch = RegExp(r'BV[a-zA-Z0-9]{10}').firstMatch(clean);
    if (bvMatch != null) {
      BilibiliService.getVideoDetails(bvMatch.group(0)!).then((directBiliDetail) {
        if (directBiliDetail != null && state.sessionId == sessionId) {
          final directItem = BiliVideoItem(
            bvid: directBiliDetail.bvid,
            title: directBiliDetail.title,
            author: directBiliDetail.ownerName,
            pic: directBiliDetail.pic,
            play: directBiliDetail.view,
            danmaku: directBiliDetail.danmaku,
            duration: directBiliDetail.parts.length > 1
                ? '${directBiliDetail.parts.length}P'
                : (directBiliDetail.parts.isNotEmpty
                    ? '${directBiliDetail.parts.first.duration}s'
                    : ''),
            description: directBiliDetail.desc,
            tag: 'Piped · 哔哩哔哩',
            ruleType: 'piped',
          );
          _insertDirectMatch(directItem, sessionId);
        }
      }).catchError((e) {
        HaipeeLogger().log(Level.warning, 'B站直链解析异常: $e');
      });
    }

    // 3. B站并发检索
    if (isBiliRuleEnabled) {
      Future.sync(() => BilibiliService.searchVideos(clean))
          .timeout(const Duration(seconds: 8))
          .then((biliList) {
        if (state.sessionId != sessionId) return;
        final tagged = biliList.map((item) {
          return BiliVideoItem(
            bvid: item.bvid,
            title: item.title,
            author: item.author,
            pic: item.pic,
            play: item.play,
            danmaku: item.danmaku,
            duration: item.duration,
            pubdate: item.pubdate,
            description: item.description,
            tag: 'Piped · 哔哩哔哩',
            ruleType: 'piped',
          );
        }).toList();
        _appendResults(tagged, sessionId);
      }).catchError((e) {
        HaipeeLogger().log(Level.warning, 'B站搜索异常: $e');
      }).whenComplete(() {
        _onSourceCompleted(sessionId);
      });
    }

    // 4. 抖音并发检索
    if (isDouyinRuleEnabled) {
      Future.sync(() => DouyinService.searchVideos(clean))
          .timeout(const Duration(seconds: 8))
          .then((douyinList) {
        if (state.sessionId != sessionId) return;
        final tagged = douyinList.map((item) {
          return BiliVideoItem(
            bvid: 'douyin_${item.id}',
            title: item.title,
            author: item.author.isNotEmpty ? item.author : '抖音',
            pic: item.cover,
            duration: item.duration > 0
                ? '${item.duration}s'
                : '短视频',
            description: item.playUrl,
            tag: 'Piped · 抖音',
            ruleType: 'piped',
          );
        }).toList();
        _appendResults(tagged, sessionId);
      }).catchError((e) {
        HaipeeLogger().log(Level.warning, '抖音搜索异常: $e');
      }).whenComplete(() {
        _onSourceCompleted(sessionId);
      });
    }

    // 5. 第三方视听规则全并发检索 (Haipee, MacCMS, TVBox, IPTV, Piped)
    for (final plugin in streamingPlugins) {
      Future.sync(() => plugin.queryBangumi(clean))
          .timeout(const Duration(seconds: 8))
          .then((resp) {
        if (state.sessionId != sessionId) return;
        final rType = plugin.ruleType;
        String tagLabel;
        if (rType == PluginRuleType.iptv) {
          tagLabel = 'IPTV · ${plugin.name}';
        } else if (rType == PluginRuleType.tvbox) {
          tagLabel = 'TVBox · ${plugin.name}';
        } else if (rType == PluginRuleType.maccms) {
          tagLabel = 'MacCMS · ${plugin.name}';
        } else if (rType == PluginRuleType.piped) {
          tagLabel = 'Piped · ${plugin.name}';
        } else {
          tagLabel = 'Haipee · ${plugin.name}';
        }

        final items = <BiliVideoItem>[];
        for (final item in resp.data) {
          items.add(
            BiliVideoItem(
              bvid: 'web_${plugin.name}_${item.src}',
              title: item.name,
              author: plugin.name,
              pic: item.pic,
              duration: item.remarks.isNotEmpty
                  ? item.remarks
                  : (rType == PluginRuleType.iptv ? '实时直播' : '点播正片'),
              description: item.src,
              tag: tagLabel,
              ruleType: rType.id,
            ),
          );
        }
        _appendResults(items, sessionId);
      }).catchError((e) {
        HaipeeLogger().log(Level.warning, '规则源 [${plugin.name}] 搜索异常: $e');
      }).whenComplete(() {
        _onSourceCompleted(sessionId);
      });
    }
  }

  Future<void> _enrichWithBangumiCovers(String keyword, int sessionId) async {
    try {
      final bangumiList = await BangumiHTTP.bangumiSearch(keyword)
          .timeout(const Duration(seconds: 5));
      if (state.sessionId != sessionId || bangumiList.isEmpty) return;

      final mergedCovers = Map<String, String>.from(state.synergyCovers);
      for (final bgm in bangumiList) {
        final cover = (bgm.images['large'] ?? bgm.images['common'] ?? '').trim();
        if (cover.isEmpty || RuleCoverExtractor.isPlaceholderImageUrl(cover)) {
          continue;
        }
        final normCn = RuleCoverExtractor.normalizeTitleForSynergy(bgm.nameCn);
        final normJp = RuleCoverExtractor.normalizeTitleForSynergy(bgm.name);
        if (normCn.isNotEmpty) {
          mergedCovers[normCn] = cover;
        }
        if (normJp.isNotEmpty) {
          mergedCovers[normJp] = cover;
        }
      }

      if (mergedCovers.length != state.synergyCovers.length) {
        final backfilled = _backfillMissingCovers(state.allResults, mergedCovers);
        state = state.copyWith(
          allResults: List.unmodifiable(backfilled),
          synergyCovers: Map.unmodifiable(mergedCovers),
        );
      }
    } catch (_) {}
  }

  List<BiliVideoItem> _backfillMissingCovers(
    List<BiliVideoItem> list,
    Map<String, String> covers,
  ) {
    if (covers.isEmpty) return list;
    final normKeyword = RuleCoverExtractor.normalizeTitleForSynergy(state.keyword);
    return list.map((item) {
      if (item.pic.isNotEmpty && !RuleCoverExtractor.isPlaceholderImageUrl(item.pic)) {
        return item;
      }
      final normTitle = RuleCoverExtractor.normalizeTitleForSynergy(item.title);
      String? matched = covers[normTitle];
      if (matched == null && normTitle.isNotEmpty) {
        for (final entry in covers.entries) {
          if (entry.key.length >= 2 &&
              (normTitle.contains(entry.key) || entry.key.contains(normTitle))) {
            matched = entry.value;
            break;
          }
        }
      }
      matched ??= normKeyword.isNotEmpty ? covers[normKeyword] : null;
      if (matched != null && matched.isNotEmpty) {
        return item.copyWith(pic: matched);
      }
      return item;
    }).toList();
  }

  void _appendResults(List<BiliVideoItem> items, int sessionId) {
    if (state.sessionId != sessionId || items.isEmpty) return;
    final existingBvids = state.allResults.map((i) => i.bvid).toSet();
    final updated = List<BiliVideoItem>.from(state.allResults);
    final mergedCovers = Map<String, String>.from(state.synergyCovers);

    for (final item in items) {
      final cleanPic = item.pic.trim();
      if (cleanPic.isNotEmpty && !RuleCoverExtractor.isPlaceholderImageUrl(cleanPic)) {
        final normTitle = RuleCoverExtractor.normalizeTitleForSynergy(item.title);
        if (normTitle.isNotEmpty) {
          mergedCovers.putIfAbsent(normTitle, () => cleanPic);
        }
      }
      if (!existingBvids.contains(item.bvid)) {
        existingBvids.add(item.bvid);
        updated.add(item);
      }
    }

    final backfilled = _backfillMissingCovers(updated, mergedCovers);
    state = state.copyWith(
      allResults: List.unmodifiable(backfilled),
      synergyCovers: Map.unmodifiable(mergedCovers),
    );
  }

  void _insertDirectMatch(BiliVideoItem directItem, int sessionId) {
    if (state.sessionId != sessionId) return;
    final updated = List<BiliVideoItem>.from(state.allResults);
    updated.removeWhere((i) => i.bvid == directItem.bvid);
    updated.insert(0, directItem);
    final mergedCovers = Map<String, String>.from(state.synergyCovers);
    if (directItem.pic.isNotEmpty &&
        !RuleCoverExtractor.isPlaceholderImageUrl(directItem.pic)) {
      final normTitle = RuleCoverExtractor.normalizeTitleForSynergy(directItem.title);
      if (normTitle.isNotEmpty) {
        mergedCovers.putIfAbsent(normTitle, () => directItem.pic);
      }
    }
    state = state.copyWith(
      allResults: List.unmodifiable(_backfillMissingCovers(updated, mergedCovers)),
      synergyCovers: Map.unmodifiable(mergedCovers),
    );
  }

  void _onSourceCompleted(int sessionId) {
    if (state.sessionId != sessionId) return;
    final completed = state.completedSources + 1;
    final isSearching = completed < state.totalSources;
    state = state.copyWith(
      completedSources: completed,
      isSearching: isSearching,
    );
  }
}

final onlineVideoSearchProvider =
    NotifierProvider<OnlineVideoSearchNotifier, OnlineVideoSearchState>(
  () => OnlineVideoSearchNotifier(),
);
