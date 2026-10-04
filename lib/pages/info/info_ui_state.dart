import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 番剧详情页 UI 状态
///
/// 管理详情页面各种展开/折叠等 UI 状态
class InfoUIState {
  final bool fullIntro; // 是否展开完整简介
  final bool fullTag; // 是否展开完整标签列表
  final bool showAllEpisodes; // 是否显示所有剧集

  const InfoUIState({
    this.fullIntro = false,
    this.fullTag = false,
    this.showAllEpisodes = false,
  });

  InfoUIState copyWith({
    bool? fullIntro,
    bool? fullTag,
    bool? showAllEpisodes,
  }) {
    return InfoUIState(
      fullIntro: fullIntro ?? this.fullIntro,
      fullTag: fullTag ?? this.fullTag,
      showAllEpisodes: showAllEpisodes ?? this.showAllEpisodes,
    );
  }
}

/// 番剧详情页 UI 状态 Notifier
class InfoUINotifier extends Notifier<InfoUIState> {
  @override
  InfoUIState build() => const InfoUIState();

  void toggleFullIntro() {
    state = state.copyWith(fullIntro: !state.fullIntro);
  }

  void toggleFullTag() {
    state = state.copyWith(fullTag: !state.fullTag);
  }

  void toggleShowAllEpisodes() {
    state = state.copyWith(showAllEpisodes: !state.showAllEpisodes);
  }

  void setFullIntro(bool value) {
    state = state.copyWith(fullIntro: value);
  }

  void setFullTag(bool value) {
    state = state.copyWith(fullTag: value);
  }

  void setShowAllEpisodes(bool value) {
    state = state.copyWith(showAllEpisodes: value);
  }
}

/// 番剧详情页 UI 状态 Provider
///
/// 用于管理详情页的各种 UI 展开/折叠状态。
/// 使用 autoDispose 以便页面销毁时自动清理。
///
/// 示例:
/// ```dart
/// final uiController = ref.read(infoUIProvider.notifier);
/// uiController.toggleFullIntro();
/// ```
final infoUIProvider =
    NotifierProvider.autoDispose<InfoUINotifier, InfoUIState>(
  InfoUINotifier.new,
);
