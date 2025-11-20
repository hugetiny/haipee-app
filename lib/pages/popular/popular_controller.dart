import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

part 'popular_controller.freezed.dart';

/// Popular 页面所需的全部状态
@freezed
class PopularState with _$PopularState {
  const factory PopularState({
    @Default('') String currentTag,
    @Default([]) List<BangumiItem> bangumiList, // 按标签获取的番组
    @Default([]) List<BangumiItem> trendList, // 热门趋势番组
    @Default({}) Map<String, List<BangumiItem>> tagCache, // 标签数据缓存
    @Default(0.0) double scrollOffset,
    @Default(false) bool isLoadingMore,
    @Default(false) bool isTimeOut,
  }) = _PopularState;
}

/// 负责处理热门番组/标签番组的加载逻辑
/// 由旧的 MobX 架构迁移至 Riverpod Notifier
class PopularController extends Notifier<PopularState> {
  @override
  PopularState build() => const PopularState();

  void setCurrentTag(String tag) {
    // 尝试从缓存恢复数据，避免 UI 闪烁
    final cachedList = state.tagCache[tag] ?? [];
    state = state.copyWith(
      currentTag: tag,
      bangumiList: cachedList,
    );
  }

  void clearBangumiList() {
    state = state.copyWith(bangumiList: []);
  }

  void updateScrollOffset(double offset) {
    // 仅在数值有明显变化时更新，避免频繁 rebuild
    if ((offset - state.scrollOffset).abs() > 8) {
      state = state.copyWith(scrollOffset: offset);
    }
  }

  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    if (state.isLoadingMore) return;
    List<BangumiItem> trendList = state.trendList;
    if (type == 'init') {
      trendList = [];
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final result =
          await BangumiHTTP.getBangumiTrendsList(offset: trendList.length);
      trendList = [...trendList, ...result];
      state = state.copyWith(
        trendList: trendList,
        isLoadingMore: false,
        isTimeOut: trendList.isEmpty,
      );
    } catch (_) {
      state =
          state.copyWith(isLoadingMore: false, isTimeOut: trendList.isEmpty);
    }
  }

  Future<void> queryBangumiByTag({String type = 'add'}) async {
    if (state.isLoadingMore) return;

    // 使用局部变量处理列表逻辑，避免直接清空 state.bangumiList 导致 UI 闪烁
    List<BangumiItem> currentList = state.bangumiList;
    if (type == 'init') {
      currentList = [];
    }

    state = state.copyWith(isLoadingMore: true);
    try {
      int rank = 0;
      if (type == 'add') {
        rank = Random().nextInt(8000) + 1;
      }
      final result = await BangumiHTTP.getBangumiList(
        rank: rank,
        tag: state.currentTag,
      );

      final newList = [...currentList, ...result];

      // 更新缓存
      final newCache = Map<String, List<BangumiItem>>.from(state.tagCache);
      newCache[state.currentTag] = newList;

      state = state.copyWith(
        bangumiList: newList,
        tagCache: newCache,
        isLoadingMore: false,
        isTimeOut: newList.isEmpty,
      );
    } catch (_) {
      state =
          state.copyWith(isLoadingMore: false, isTimeOut: state.bangumiList.isEmpty);
    }
  }
}
