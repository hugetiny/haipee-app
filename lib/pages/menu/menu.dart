import 'dart:io';
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
        } catch (_) {
          final childType = widget.child.runtimeType.toString();
          if (childType == 'OnlineVideoSearchPage') {
            ref.read(currentRouteProvider.notifier).updateRoute(Routes.onlineVideo);
          } else if (childType == 'MediaLibraryPage' ||
              childType == 'MediaPage') {
            ref.read(currentRouteProvider.notifier).updateRoute(Routes.media);
          }
        }
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
      appBar: _buildUnifiedAppBar(appBarConfig, hasLeadingRail: false),
      body: widget.child ?? const SizedBox.shrink(),
      bottomNavigationBar: state.isHidden
          ? const SizedBox(height: 0)
          : NavigationBar(
              destinations: <NavigationDestination>[
                NavigationDestination(
                  selectedIcon: const Icon(Icons.language),
                  icon: const Icon(Icons.language_outlined),
                  label: t.navigation.tabs.media,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.travel_explore),
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: t.navigation.tabs.resource,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.video_library),
                  icon: const Icon(Icons.video_library_outlined),
                  label: t.navigation.tabs.my,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.download),
                  icon: const Icon(Icons.download_outlined),
                  label: t.navigation.tabs.download,
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
  PreferredSizeWidget? _buildUnifiedAppBar(
    AppBarConfig? config, {
    bool hasLeadingRail = false,
  }) {
    if (config == null || !config.visible) {
      return null;
    }

    final currentRoute = ref.watch(currentRouteProvider);
    final isExplicitPopularChild =
        widget.child.runtimeType.toString() == 'PopularPage';
    if ((currentRoute == Routes.onlineVideo ||
            currentRoute == Routes.resource ||
            currentRoute == Routes.media) &&
        !isExplicitPopularChild) {
      return null;
    }

    PreferredSizeWidget? bottom = config.bottom;
    if (bottom is TabBar) {
      if (bottom.controller != null && bottom.controller!.animation == null) {
        bottom = null;
      }
    }

    Widget? titleWidget;
    if (config.title is String) {
      titleWidget = Text(config.title);
    } else if (config.title is Widget) {
      titleWidget = config.title;
    }

    // 在桌面端且没有左侧 NavigationRail 时（如隐藏侧边栏或纵向窗口），macOS 顶栏必须避让原生红黄绿按钮
    final bool effectiveNeedTopOffset =
        config.needTopOffset || (Platform.isMacOS && !hasLeadingRail);

    return SysAppBar(
      title: titleWidget,
      actions: config.actions,
      leading: config.leading,
      bottom: bottom,
      toolbarHeight: config.toolbarHeight,
      needTopOffset: effectiveNeedTopOffset,
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
    final bool hasLeadingRail = !state.isHidden;

    return Scaffold(
      body: Row(
        children: [
          if (hasLeadingRail)
            EmbeddedNativeControlArea(
              requireOffset: false,
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                groupAlignment: 1.0,
                labelType: NavigationRailLabelType.selected,
                destinations: <NavigationRailDestination>[
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.language),
                    icon: const Icon(Icons.language_outlined),
                    label: Text(t.navigation.tabs.media),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.travel_explore),
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: Text(t.navigation.tabs.resource),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.video_library),
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(t.navigation.tabs.my),
                  ),
                  NavigationRailDestination(
                    selectedIcon: const Icon(Icons.download),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(t.navigation.tabs.download),
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
          Expanded(
            child: Scaffold(
              appBar: _buildUnifiedAppBar(appBarConfig,
                  hasLeadingRail: hasLeadingRail),
              body: widget.child ?? const SizedBox.shrink(),
            ),
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
      Future.microtask(() {
        if (mounted) {
          ref.read(currentRouteProvider.notifier).updateRoute(location);
        }
      });
    } catch (_) {}
  }
}
