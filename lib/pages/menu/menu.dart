import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'navigation_provider.dart';

class ScaffoldMenu extends ConsumerStatefulWidget {
  const ScaffoldMenu({super.key, this.child});

  final Widget? child;

  @override
  ConsumerState<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends ConsumerState<ScaffoldMenu> {
  @override
  void initState() {
    super.initState();

    // 使用 Riverpod 的 ref.listen 监听路由变化
    // 在下一帧自动同步导航索引，无需 addPostFrameCallback
    Future.microtask(() {
      if (mounted) {
        try {
          final location = GoRouterState.of(context).uri.path;
          ref.read(currentRouteProvider.notifier).updateRoute(location);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationProvider);
    final navigationController = ref.read(navigationProvider.notifier);

    // 在 build 方法顶层使用 ref.listen
    // 监听路由变化，自动同步导航索引
    ref.listen<String>(currentRouteProvider, (previous, next) {
      navigationController.syncWithRoute(next);
    });

    // 监听方向状态变化，自动同步导航位置
    ref.listen<bool>(orientationProvider, (previous, next) {
      navigationController.setIsBottom(next);
    });

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isPortrait = orientation == Orientation.portrait;

        // 更新方向状态（响应式）
        if (ref.read(orientationProvider) != isPortrait) {
          // 使用 Riverpod 的异步更新，不需要 addPostFrameCallback
          Future.microtask(() {
            if (mounted) {
              ref
                  .read(orientationProvider.notifier)
                  .updateOrientation(isPortrait);
            }
          });
        }

        return isPortrait
            ? bottomMenuWidget(context, navigationState, navigationController)
            : sideMenuWidget(context, navigationState, navigationController);
      },
    );
  }

  Widget bottomMenuWidget(
    BuildContext context,
    NavigationBarStateData state,
    NavigationBarController controller,
  ) {
    final t = context.t;
    final appBarConfig = ref.watch(appBarConfigProvider);

    return Scaffold(
      appBar: _buildUnifiedAppBar(appBarConfig),
      body: widget.child ?? const SizedBox.shrink(),
      bottomNavigationBar: state.isHidden
          ? const SizedBox(height: 0)
          : NavigationBar(
              destinations: <NavigationDestination>[
                NavigationDestination(
                  selectedIcon: const Icon(Icons.home),
                  icon: const Icon(Icons.home_outlined),
                  label: t.navigation.tabs.popular,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.timeline),
                  icon: const Icon(Icons.timeline_outlined),
                  label: t.navigation.tabs.timeline,
                ),
                const NavigationDestination(
                  selectedIcon: Icon(Icons.travel_explore),
                  icon: Icon(Icons.travel_explore_outlined),
                  label: '资源搜索',
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.download),
                  icon: const Icon(Icons.download_outlined),
                  label: t.navigation.tabs.download,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.person),
                  icon: const Icon(Icons.person_outline),
                  label: t.navigation.tabs.my,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.settings),
                  icon: const Icon(Icons.settings_outlined),
                  label: t.navigation.tabs.settings,
                ),
              ],
              selectedIndex: state.selectedIndex,
              onDestinationSelected: (int index) {
                _onNavigationSelected(index, controller);
              },
            ),
    );
  }

  /// 构建统一的 AppBar
  PreferredSizeWidget? _buildUnifiedAppBar(AppBarConfig? config) {
    if (config == null || !config.visible) {
      return null;
    }

    Widget? titleWidget;
    if (config.title is String) {
      titleWidget = Text(config.title);
    } else if (config.title is Widget) {
      titleWidget = config.title;
    }

    return SysAppBar(
      title: titleWidget,
      actions: config.actions,
      leading: config.leading,
      bottom: config.bottom,
      toolbarHeight: config.toolbarHeight,
      needTopOffset: config.needTopOffset,
      leadingWidth: config.leadingWidth,
    );
  }

  Widget sideMenuWidget(
    BuildContext context,
    NavigationBarStateData state,
    NavigationBarController controller,
  ) {
    final t = context.t;
    final appBarConfig = ref.watch(appBarConfigProvider);

    return Scaffold(
      appBar: _buildUnifiedAppBar(appBarConfig),
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: Visibility(
              visible: !state.isHidden,
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                groupAlignment: 1.0,
                leading: FloatingActionButton(
                  elevation: 0,
                  heroTag: null,
                  onPressed: () {
                    context.push(Routes.search);
                  },
                  tooltip: t.navigation.actions.search,
                  child: const Icon(Icons.search),
                ),
                labelType: NavigationRailLabelType.selected,
                destinations: <NavigationRailDestination>[
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.home),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(t.navigation.tabs.popular),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.timeline),
                    icon: const Icon(Icons.timeline_outlined),
                    label: Text(t.navigation.tabs.timeline),
                  ),
                  const NavigationRailDestination(
                    selectedIcon: Icon(Icons.travel_explore),
                    icon: Icon(Icons.travel_explore_outlined),
                    label: Text('资源搜索'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.download),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(t.navigation.tabs.download),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.person),
                    icon: const Icon(Icons.person_outline),
                    label: Text(t.navigation.tabs.my),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.settings),
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(t.navigation.tabs.settings),
                  ),
                ],
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  _onNavigationSelected(index, controller);
                },
              ),
            ),
          ),
          Expanded(
            child: widget.child ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 统一的导航选择处理
  void _onNavigationSelected(int index, NavigationBarController controller) {
    // 防止重复导航
    if (ref.read(navigationProvider).selectedIndex == index) {
      return;
    }

    // 先更新状态
    controller.updateSelectedIndex(index);

    // 再执行导航
    final route = controller.getRouteFromIndex(index);
    context.go(route);

    // 更新当前路由（Riverpod 会自动响应）
    ref.read(currentRouteProvider.notifier).updateRoute(route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 使用 Riverpod 同步路由状态
    try {
      final location = GoRouterState.of(context).uri.path;
      ref.read(currentRouteProvider.notifier).updateRoute(location);
    } catch (_) {}
  }
}
