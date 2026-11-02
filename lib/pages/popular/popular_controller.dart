import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';

part 'popular_controller.freezed.dart';

/// Popular 页面所需的全部状态
@freezed
class PopularState with _$PopularState {
  const factory PopularState({
    @Default('') String currentTag,
    @Default([]) List<BangumiItem> bangumiList, // 按标签获取的番组
    @Default([]) List<BangumiItem> trendList, // 热门趋势番组
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
    state = state.copyWith(currentTag: tag);
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
    List<BangumiItem> bangumiList = state.bangumiList;
    if (type == 'init') {
      bangumiList = [];
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      int randomNumber = Random().nextInt(8000) + 1;
      final result = await BangumiHTTP.getBangumiList(
        rank: randomNumber,
        tag: state.currentTag,
      );
      bangumiList = [...bangumiList, ...result];
      state = state.copyWith(
        bangumiList: bangumiList,
        isLoadingMore: false,
        isTimeOut: bangumiList.isEmpty,
      );
    } catch (_) {
      state =
          state.copyWith(isLoadingMore: false, isTimeOut: bangumiList.isEmpty);
    }
  }
}
