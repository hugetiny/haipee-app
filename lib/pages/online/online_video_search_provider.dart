import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/modules/danmaku/danmaku_count_service.dart';
import 'package:haipee/modules/douyin/douyin_service.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/plugins/rule_cover_extractor.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

const Object _filterSentinel = Object();

enum OnlineSourceFilter {
  all(id: 'all', label: '全部', icon: Icons.auto_awesome_motion_outlined),
  video(id: 'video', label: '点播', icon: Icons.ondemand_video_rounded),
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

  /// 第一维度：视频形态分类（全部 / 点播 / 直播）
  static const List<OnlineSourceFilter> overviewFilters = [
    OnlineSourceFilter.all,
    OnlineSourceFilter.video,
    OnlineSourceFilter.live,
  ];

  /// 第二维度：5 大视听流媒体规则协议类型
  static const List<OnlineSourceFilter> ruleProtocolFilters = [
    OnlineSourceFilter.haipee,
    OnlineSourceFilter.maccms,
    OnlineSourceFilter.tvbox,
    OnlineSourceFilter.piped,
    OnlineSourceFilter.iptv,
  ];

  /// 全部筛选项合集
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
  final OnlineSourceFilter videoModeFilter;
  final OnlineSourceFilter? ruleTypeFilter;
  final String? sourceNameFilter;
  final int sessionId;
  final Map<String, String> synergyCovers;
  final Set<String> directMatchBvids;
  final String sortMode;

  const OnlineVideoSearchState({
    this.keyword = '',
    this.isSearching = false,
    this.completedSources = 0,
    this.totalSources = 0,
    this.allResults = const [],
    this.selectedFilter = OnlineSourceFilter.all,
    this.videoModeFilter = OnlineSourceFilter.all,
    this.ruleTypeFilter,
    this.sourceNameFilter,
    this.sessionId = 0,
    this.synergyCovers = const {},
    this.directMatchBvids = const {},
    this.sortMode = 'danmaku',
  });

  bool get hasActiveFilter =>
      videoModeFilter != OnlineSourceFilter.all ||
      ruleTypeFilter != null ||
      (sourceNameFilter != null && sourceNameFilter!.isNotEmpty) ||
      selectedFilter != OnlineSourceFilter.all;

  int get activeFilterCount =>
      (videoModeFilter != OnlineSourceFilter.all ? 1 : 0) +
      (ruleTypeFilter != null ? 1 : 0) +
      (sourceNameFilter != null && sourceNameFilter!.isNotEmpty ? 1 : 0);

  static String sourceLabelForItem(BiliVideoItem item) {
    if (item.bvid.startsWith('douyin_')) return '抖音';
    if (item.bvid.startsWith('web_')) {
      return item.author.isNotEmpty
          ? item.author
          : (item.tag.isNotEmpty ? item.tag : '网络');
    }
    return 'BiliBili';
  }

  /// 当前结果中出现过的具体来源站点及数量统计
  List<({String name, int count})> get availableSourceSites {
    final counts = <String, int>{};
    for (final item in allResults) {
      final name = sourceLabelForItem(item);
      if (name.isNotEmpty) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final entries = counts.entries
        .map((e) => (name: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return entries;
  }

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

  List<BiliVideoItem> get currentFilteredResults {
    var list = allResults;
    // 1. 按视频形态筛选 (全部 / 点播 / 直播)
    if (videoModeFilter == OnlineSourceFilter.video) {
      list = list.where((item) => !isLiveItem(item)).toList();
    } else if (videoModeFilter == OnlineSourceFilter.live) {
      list = list.where((item) => isLiveItem(item)).toList();
    }

    // 2. 按规则协议类型筛选 (Haipee / MacCMS / TVBox / Piped / IPTV)
    if (ruleTypeFilter != null && ruleTypeFilter != OnlineSourceFilter.all) {
      final allowedByRule = resultsForFilter(ruleTypeFilter!).toSet();
      list = list.where(allowedByRule.contains).toList();
    } else if (videoModeFilter == OnlineSourceFilter.all &&
        ruleTypeFilter == null &&
        selectedFilter != OnlineSourceFilter.all) {
      list = resultsForFilter(selectedFilter);
    }

    // 3. 按具体来源站点筛选
    if (sourceNameFilter != null && sourceNameFilter!.isNotEmpty) {
      list = list
          .where((item) => sourceLabelForItem(item) == sourceNameFilter)
          .toList();
    }
    // 4. 排序：默认按弹幕热度高到低排序，或按设置中的规则协议类型优先排序
    return sortResults(list, sortMode: sortMode, directMatchBvids: directMatchBvids);
  }

  /// 规则协议类型优先级：Haipee原生规则(0)最前，MacCMS(1)，TVBox(2)，Piped(3)，IPTV(4)，AList(5)，Cardigann(6)，其他(10)
  static int ruleTypePriority(BiliVideoItem item) {
    final type = item.resolvedRuleType;
    switch (type) {
      case 'haipee':
      case 'anime':
      case 'kazumi':
        return 0;
      case 'maccms':
        return 1;
      case 'tvbox':
        return 2;
      case 'piped':
        return 3;
      case 'iptv':
        return 4;
      case 'alist':
        return 5;
      case 'cardigann':
        return 6;
      default:
        return 10;
    }
  }

  /// 综合排序：
  /// - 直接匹配项 (如直接搜索BV号/抖音直链) 严格置顶 (-1)
  /// - 当 [sortMode] 为 'danmaku'（默认）：优先按弹幕数量由高到低排序；弹幕数相同时按规则协议优先级排序
  /// - 当 [sortMode] 为 'ruleType'：优先按规则协议类型 (Haipee > MacCMS > TVBox...) 排序；同规则类型内按弹幕数由高到低排序
  /// - 同等优先级下保持原始发现顺序
  static List<BiliVideoItem> sortResults(
    List<BiliVideoItem> items, {
    String sortMode = 'danmaku',
    Set<String>? directMatchBvids,
  }) {
    final indexed = items.asMap().entries.toList();
    indexed.sort((a, b) {
      final isDirectA = directMatchBvids != null && directMatchBvids.contains(a.value.bvid);
      final isDirectB = directMatchBvids != null && directMatchBvids.contains(b.value.bvid);
      if (isDirectA && !isDirectB) return -1;
      if (!isDirectA && isDirectB) return 1;

      if (sortMode == 'ruleType') {
        final pa = ruleTypePriority(a.value);
        final pb = ruleTypePriority(b.value);
        final cmpRule = pa.compareTo(pb);
        if (cmpRule != 0) return cmpRule;

        final cmpDanmaku = b.value.danmaku.compareTo(a.value.danmaku);
        if (cmpDanmaku != 0) return cmpDanmaku;
      } else {
        // 默认按弹幕数量由高到低排
        final cmpDanmaku = b.value.danmaku.compareTo(a.value.danmaku);
        if (cmpDanmaku != 0) return cmpDanmaku;

        final pa = ruleTypePriority(a.value);
        final pb = ruleTypePriority(b.value);
        final cmpRule = pa.compareTo(pb);
        if (cmpRule != 0) return cmpRule;
      }

      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  /// 兼容旧接口：严格按规则协议类型排序
  static List<BiliVideoItem> sortResultsByRulePriority(
    List<BiliVideoItem> items, {
    Set<String>? directMatchBvids,
  }) {
    return sortResults(items, sortMode: 'ruleType', directMatchBvids: directMatchBvids);
  }

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
    OnlineSourceFilter? videoModeFilter,
    Object? ruleTypeFilter = _filterSentinel,
    Object? sourceNameFilter = _filterSentinel,
    int? sessionId,
    Map<String, String>? synergyCovers,
    Set<String>? directMatchBvids,
    String? sortMode,
  }) {
    return OnlineVideoSearchState(
      keyword: keyword ?? this.keyword,
      isSearching: isSearching ?? this.isSearching,
      completedSources: completedSources ?? this.completedSources,
      totalSources: totalSources ?? this.totalSources,
      allResults: allResults ?? this.allResults,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      videoModeFilter: videoModeFilter ?? this.videoModeFilter,
      ruleTypeFilter: identical(ruleTypeFilter, _filterSentinel)
          ? this.ruleTypeFilter
          : (ruleTypeFilter as OnlineSourceFilter?),
      sourceNameFilter: identical(sourceNameFilter, _filterSentinel)
          ? this.sourceNameFilter
          : (sourceNameFilter as String?),
      sessionId: sessionId ?? this.sessionId,
      synergyCovers: synergyCovers ?? this.synergyCovers,
      directMatchBvids: directMatchBvids ?? this.directMatchBvids,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

class OnlineVideoSearchNotifier extends Notifier<OnlineVideoSearchState> {
  @override
  OnlineVideoSearchState build() {
    final sortMode = GStorage.getSetting(SettingsKeys.onlineSearchSortMode);
    return OnlineVideoSearchState(sortMode: sortMode);
  }

  /// 切换排序模式：'danmaku'（弹幕热度高到低）或 'ruleType'（规则协议类型优先级）
  void setSortMode(String mode) {
    if (state.sortMode == mode) return;
    GStorage.putSetting(SettingsKeys.onlineSearchSortMode, mode);
    final sorted = OnlineVideoSearchState.sortResults(
      state.allResults,
      sortMode: mode,
      directMatchBvids: state.directMatchBvids,
    );
    state = state.copyWith(
      sortMode: mode,
      allResults: List.unmodifiable(sorted),
    );
  }

  /// 切换第一维度：视频形态（全部 / 点播 / 直播）
  void setVideoModeFilter(OnlineSourceFilter mode) {
    OnlineSourceFilter? nextRule = state.ruleTypeFilter;
    // 若选择“直播”而规则选了非IPTV点播源，或选择“点播”而规则选了IPTV，自动重置冲突的规则筛选
    if (mode == OnlineSourceFilter.live &&
        nextRule != null &&
        nextRule != OnlineSourceFilter.iptv) {
      nextRule = null;
    } else if (mode == OnlineSourceFilter.video &&
        nextRule == OnlineSourceFilter.iptv) {
      nextRule = null;
    }
    state = state.copyWith(
      videoModeFilter: mode,
      ruleTypeFilter: nextRule,
      selectedFilter: nextRule ?? mode,
    );
  }

  /// 切换第二维度：规则协议类型（全部规则 / Haipee / MacCMS / TVBox / Piped / IPTV）
  void setRuleTypeFilter(OnlineSourceFilter? rule) {
    final normalizedRule =
        (rule == OnlineSourceFilter.all) ? null : rule;
    OnlineSourceFilter nextVideoMode = state.videoModeFilter;
    if (normalizedRule == OnlineSourceFilter.iptv &&
        nextVideoMode == OnlineSourceFilter.video) {
      nextVideoMode = OnlineSourceFilter.all;
    } else if (normalizedRule != null &&
        normalizedRule != OnlineSourceFilter.iptv &&
        nextVideoMode == OnlineSourceFilter.live) {
      nextVideoMode = OnlineSourceFilter.all;
    }
    state = state.copyWith(
      videoModeFilter: nextVideoMode,
      ruleTypeFilter: normalizedRule,
      sourceNameFilter: null,
      selectedFilter: normalizedRule ?? nextVideoMode,
    );
  }

  /// 切换第三维度：具体来源站点
  void setSourceNameFilter(String? sourceName) {
    final normalized =
        (sourceName == null || sourceName.trim().isEmpty) ? null : sourceName;
    state = state.copyWith(sourceNameFilter: normalized);
  }

  /// 一键重置全部筛选条件
  void resetFilters() {
    state = state.copyWith(
      selectedFilter: OnlineSourceFilter.all,
      videoModeFilter: OnlineSourceFilter.all,
      ruleTypeFilter: null,
      sourceNameFilter: null,
    );
  }

  /// 兼容单枚举切换分类标签，完全不影响正在后台进行的并发网络请求
  void setFilter(OnlineSourceFilter filter) {
    if (filter == OnlineSourceFilter.all) {
      resetFilters();
    } else if (filter == OnlineSourceFilter.video ||
        filter == OnlineSourceFilter.live) {
      setVideoModeFilter(filter);
    } else {
      setRuleTypeFilter(filter);
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
      directMatchBvids: const {},
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

    final currentSortMode = GStorage.getSetting(SettingsKeys.onlineSearchSortMode);

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
      directMatchBvids: const {},
      sortMode: currentSortMode,
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

    final sortedUpdated = OnlineVideoSearchState.sortResults(
      updated,
      sortMode: state.sortMode,
      directMatchBvids: state.directMatchBvids,
    );
    final backfilled = _backfillMissingCovers(sortedUpdated, mergedCovers);
    state = state.copyWith(
      allResults: List.unmodifiable(backfilled),
      synergyCovers: Map.unmodifiable(mergedCovers),
    );

    // 异步检索每条搜索结果的弹幕数（弹弹play联动），智能去重并就绪后平滑排至前列
    _fetchDanmakuCountsForItems(items, sessionId);
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
    final newDirectMatchBvids = {...state.directMatchBvids, directItem.bvid};
    final sortedUpdated = OnlineVideoSearchState.sortResults(
      updated,
      sortMode: state.sortMode,
      directMatchBvids: newDirectMatchBvids,
    );
    state = state.copyWith(
      allResults: List.unmodifiable(_backfillMissingCovers(sortedUpdated, mergedCovers)),
      synergyCovers: Map.unmodifiable(mergedCovers),
      directMatchBvids: newDirectMatchBvids,
    );
    if (directItem.danmaku <= 0 && !OnlineVideoSearchState.isLiveItem(directItem)) {
      _fetchDanmakuCountsForItems([directItem], sessionId);
    }
  }

  /// 异步获取每个视频结果的弹幕数量（弹弹play联动 + 内存缓存与限流调度）
  void _fetchDanmakuCountsForItems(List<BiliVideoItem> items, int sessionId) {
    if (!DanmakuCountService.isEnabled) return;

    for (final item in items) {
      if (item.danmaku > 0 || OnlineVideoSearchState.isLiveItem(item)) {
        continue;
      }
      unawaited(
        DanmakuCountService.instance.countForTitle(item.title).then((count) {
          if (count != null && count > 0 && state.sessionId == sessionId) {
            _updateDanmakuCountForTitle(item.title, count, sessionId);
          }
        }),
      );
    }
  }

  /// 弹幕数就绪后，批量更新同标题视频结果的弹幕数并重排序
  void _updateDanmakuCountForTitle(String title, int count, int sessionId) {
    if (state.sessionId != sessionId) return;

    final targetKey = DanmakuCountService.cacheKeyFor(title);
    var hasChange = false;
    final updated = state.allResults.map((item) {
      if (DanmakuCountService.cacheKeyFor(item.title) == targetKey &&
          item.danmaku != count) {
        hasChange = true;
        return item.copyWith(danmaku: count);
      }
      return item;
    }).toList();

    if (!hasChange) return;

    final sorted = OnlineVideoSearchState.sortResults(
      updated,
      sortMode: state.sortMode,
      directMatchBvids: state.directMatchBvids,
    );
    state = state.copyWith(
      allResults: List.unmodifiable(sorted),
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
