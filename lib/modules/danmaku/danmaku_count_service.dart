import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:haipee/request/damaku.dart';
import 'package:haipee/utils/storage.dart';

/// 根据视频标题解析弹幕热度（弹幕总数）的函数签名，便于测试注入。
typedef DanmakuCountResolver = Future<int?> Function(String title);

/// 搜索结果弹幕数异步解析服务。
///
/// - 以清洗后的番剧标题为键做进程内缓存，同名结果（多规则源同一部番）只请求一次；
/// - 并发请求上限 [maxConcurrent]，避免一次搜索几十条结果时打爆弹弹play API；
/// - 解析失败 / 未收录 / 凭据缺失均返回 null（静默降级，绝不打扰用户），且不缓存失败结果。
class DanmakuCountService {
  DanmakuCountService._();

  static final DanmakuCountService instance = DanmakuCountService._();

  /// 测试注入点：设置后替代真实的弹弹play网络解析。
  @visibleForTesting
  static DanmakuCountResolver? resolverOverride;

  static const int maxConcurrent = 3;
  static const int _maxCacheEntries = 300;
  static const Duration _perTitleTimeout = Duration(seconds: 10);

  final LinkedHashMap<String, Future<int?>> _cache = LinkedHashMap();
  final Queue<Completer<void>> _waiters = Queue();
  int _active = 0;

  /// 后台自动解析是否可用：测试环境中仅在注入了 [resolverOverride] 时启用，
  /// 避免 widget 测试中发起真实网络请求或遗留未完成的 Future。
  static bool get isEnabled =>
      resolverOverride != null ||
      !Platform.environment.containsKey('FLUTTER_TEST');

  /// 同一部作品在不同规则源下的标题归一化键。
  static String cacheKeyFor(String title) {
    var cleaned =
        DanmakuRequest.cleanAnimeTitleForSearch(title).trim().toLowerCase();
    // 移除常见括号标记
    cleaned = cleaned
        .replaceAll(RegExp(r'(\[.*?\]|【.*?】|\(.*?\)|（.*?）)'), '')
        .trim();
    // 移除集数后缀 如 - 01, 第01集, 01, E01
    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'(?:第\s*\d+\s*[话集]|[-_]\s*\d+(?:\.5)?\b|\b[Ss]\d{1,2}[Ee]\d{1,2}\b|\b\d{1,3}\b)',
          ),
          '',
        )
        .trim();
    // 若中英文并存（如 "葬送的芙莉莲 Sousou no Frieren"），优先提取中文主标题
    final cnMatch = RegExp(r'^([\u4e00-\u9fa5·]{2,})').firstMatch(cleaned);
    if (cnMatch != null) {
      return cnMatch.group(1)!.trim();
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 解析标题对应的弹幕数；同键请求复用同一个 Future。
  Future<int?> countForTitle(String title) {
    final key = cacheKeyFor(title);
    if (key.isEmpty) return Future<int?>.value(null);

    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // LRU：命中后移到队尾
      return cached;
    }

    final resolver = resolverOverride ?? _resolveFromDanDan;
    final future = _throttled(() => resolver(title).timeout(_perTitleTimeout))
        .then<int?>((value) => value, onError: (_) => null);
    _cache[key] = future;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    future.then((value) {
      // 不缓存失败结果，下次搜索可重试
      if (value == null && identical(_cache[key], future)) {
        _cache.remove(key);
      }
    });
    return future;
  }

  @visibleForTesting
  void resetForTesting() {
    _cache.clear();
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
    _active = 0;
  }

  Future<T> _throttled<T>(Future<T> Function() task) async {
    if (_active >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await task();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }

  /// 弹弹play 解析链路：标题 → 番剧ID → 分集列表 → 首集弹幕总数（作为作品热度代表值）。
  static Future<int?> _resolveFromDanDan(String title) async {
    if (!GStorage.hasValidDanDanCredentials()) return null;
    final animeId = await DanmakuRequest.getBangumiIDByTitle(title);
    if (animeId <= 0) return null;
    final episodes =
        await DanmakuRequest.getDanDanEpisodesByDanDanBangumiID(animeId);
    if (episodes.episodes.isEmpty) return null;
    return DanmakuRequest.getCommentCountByEpisodeID(
      episodes.episodes.first.episodeId,
    );
  }
}
