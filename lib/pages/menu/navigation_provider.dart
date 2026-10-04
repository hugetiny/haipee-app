import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/router_constants.dart';

class NavigationBarStateData {
  final int selectedIndex;
  final bool isHidden;
  final bool isBottom;

  const NavigationBarStateData({
    this.selectedIndex = 0,
    this.isHidden = false,
    this.isBottom = false,
  });

  NavigationBarStateData copyWith({
    int? selectedIndex,
    bool? isHidden,
    bool? isBottom,
  }) {
    return NavigationBarStateData(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isHidden: isHidden ?? this.isHidden,
      isBottom: isBottom ?? this.isBottom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationBarStateData &&
          runtimeType == other.runtimeType &&
          selectedIndex == other.selectedIndex &&
          isHidden == other.isHidden &&
          isBottom == other.isBottom;

  @override
  int get hashCode =>
      selectedIndex.hashCode ^ isHidden.hashCode ^ isBottom.hashCode;
}

class NavigationBarController extends Notifier<NavigationBarStateData> {
  @override
  NavigationBarStateData build() => const NavigationBarStateData();

  void updateSelectedIndex(int index) {
    if (state.selectedIndex == index) return;
    state = state.copyWith(selectedIndex: index);
  }

  void hideNavigate() {
    if (state.isHidden) return;
    state = state.copyWith(isHidden: true);
  }

  void showNavigate() {
    if (!state.isHidden) return;
    state = state.copyWith(isHidden: false);
  }

  void setIsBottom(bool isBottom) {
    if (state.isBottom == isBottom) return;
    state = state.copyWith(isBottom: isBottom);
  }

  /// 根据路由路径同步导航索引
  void syncWithRoute(String path) {
    final newIndex = _getIndexFromRoute(path);
    if (newIndex != null && newIndex != state.selectedIndex) {
      state = state.copyWith(selectedIndex: newIndex);
    }
  }

  /// 根据路由路径获取对应的导航索引
  int? _getIndexFromRoute(String path) {
    switch (path) {
      case Routes.popular:
        return 0;
      case Routes.timeline:
        return 1;
      case Routes.resource:
        return 2;
      case Routes.download:
        return 3;
      case Routes.my:
        return 4;
      case Routes.settings:
        return 5;
      default:
        return null; // 非主导航路由，不更新索引
    }
  }

  /// 根据索引获取对应的路由
  String getRouteFromIndex(int index) {
    switch (index) {
      case 0:
        return Routes.popular;
      case 1:
        return Routes.timeline;
      case 2:
        return Routes.resource;
      case 3:
        return Routes.download;
      case 4:
        return Routes.my;
      case 5:
        return Routes.settings;
      default:
        return Routes.popular;
    }
  }
}

/// 底部导航栏 Provider
///
/// 管理底部导航栏的选中状态、显示/隐藏和位置。
/// 使用 Riverpod 的响应式机制自动同步路由状态。
///
/// 示例:
/// ```dart
/// final controller = ref.read(navigationProvider.notifier);
/// controller.updateSelectedIndex(1);
/// ```
final navigationProvider =
    NotifierProvider<NavigationBarController, NavigationBarStateData>(
  NavigationBarController.new,
);

/// 当前路由路径 Provider
///
/// 用于监听路由变化，自动同步导航状态
class CurrentRouteNotifier extends Notifier<String> {
  @override
  String build() => Routes.popular;

  void updateRoute(String path) {
    if (state != path) {
      state = path;
    }
  }
}

final currentRouteProvider = NotifierProvider<CurrentRouteNotifier, String>(
  CurrentRouteNotifier.new,
);

/// 屏幕方向 Provider
///
/// 用于响应式更新导航栏位置（底部/侧边）
class OrientationStateNotifier extends Notifier<bool> {
  @override
  bool build() => true; // 默认竖屏

  void updateOrientation(bool isPortrait) {
    if (state != isPortrait) {
      state = isPortrait;
    }
  }
}

final orientationProvider = NotifierProvider<OrientationStateNotifier, bool>(
  OrientationStateNotifier.new,
);
