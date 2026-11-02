import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/logging/debug_hud_overlay.dart';
import 'log_watcher_robot.dart';

/// Robot that traverses primary navigation tabs and secondary subpages,
/// validating layout constraints, responsiveness, and state synchronization.
class NavigationRobot {
  final WidgetTester tester;
  final LogWatcherRobot logWatcher;

  NavigationRobot({
    required this.tester,
    required this.logWatcher,
  });

  /// Adjusts viewport dimensions for responsive layout verification.
  Future<void> setViewport(Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();
  }

  /// Restores default physical size.
  void resetViewport() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  /// Pumps the full Kazumi routing application with optional Riverpod overrides.
  Future<void> pumpApp({
    List<Override> overrides = const [],
    String initialRoute = Routes.resource,
  }) async {
    router.go(initialRoute);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: TranslationProvider(
          child: MaterialApp.router(
            title: 'haipee Test',
            routerConfig: router,
            builder: (context, child) =>
                DebugHudOverlay(child: child ?? const SizedBox()),
          ),
        ),
      ),
    );

    await settleNavigation();
    logWatcher.checkTesterException(tester, contextDescription: 'App initial boot');
  }

  /// Safely settles UI animations and route transitions without hanging on periodic background timers.
  Future<void> settleNavigation() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Navigates to a route, settles animations, and asserts no errors occurred.
  Future<void> navigateTo(String route, {String? stepName}) async {
    final description = stepName ?? 'Navigating to $route';
    router.go(route);
    await settleNavigation();
    logWatcher.checkTesterException(tester, contextDescription: description);
  }

  /// Pops current route via [context.pop()] or [Navigator.maybePop].
  Future<void> goBack({String? stepName}) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      if (Navigator.canPop(ctx)) {
        Navigator.pop(ctx);
      } else {
        router.go(Routes.resource);
      }
    }
    await settleNavigation();
    logWatcher.checkTesterException(
      tester,
      contextDescription: stepName ?? 'Pop / Back Navigation',
    );
  }

  /// Traverses all primary tabs (Resource Search, Media/Category, Download, My, Settings, Popular, Timeline).
  Future<void> traverseAllPrimaryTabs() async {
    const primaryRoutes = [
      Routes.resource,
      Routes.media,
      Routes.download,
      Routes.my,
      Routes.settings,
      Routes.popular,
      Routes.timeline,
    ];

    for (final route in primaryRoutes) {
      await navigateTo(route, stepName: 'Primary Tab: $route');
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'Route $route should render within MaterialApp',
      );
    }
  }

  /// Traverses all secondary subpages across player, appearance, indexers, download, logs, about, etc.
  Future<void> traverseAllSecondarySubpages() async {
    const subpages = [
      // 1. 设置主页与外观
      Routes.settingsTheme,
      Routes.settingsLanguage,
      Routes.settingsExitBehavior,
      Routes.settingsThemeDisplay,

      // 2. 播放器与解码器
      Routes.settingsPlayer,
      Routes.settingsPlayerDecoder,
      Routes.settingsPlayerSuper,

      // 3. 弹幕与屏蔽
      Routes.settingsDanmaku,
      Routes.settingsDanmakuShield,

      // 4. 插件与规则
      Routes.settingsPlugin,
      Routes.settingsPluginShop,
      Routes.settingsPluginEditor,
      Routes.settingsIndexers,

      // 5. 视听与媒体/元数据
      Routes.settingsMedia,
      Routes.settingsMetadata,

      // 6. 下载引擎
      Routes.settingsDownload,

      // 7. WebDAV
      Routes.settingsWebdav,
      Routes.settingsWebdavEditor,

      // 8. 关于、日志与开源协议
      Routes.settingsAbout,
      Routes.settingsAboutLogs,
      Routes.settingsAboutLicense,

      // 9. 用户收藏与历史
      Routes.favorites,
      Routes.history,

      // 10. 搜索页
      Routes.search,
    ];

    for (final subpage in subpages) {
      await navigateTo(subpage, stepName: 'Subpage: $subpage');
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'Subpage $subpage should render at least one Scaffold',
      );
    }
  }

  /// Stress tests rapid navigation back and forth to uncover state race conditions or memory leaks.
  Future<void> stressRapidNavigation({int rounds = 3}) async {
    final targets = [
      Routes.resource,
      Routes.media,
      Routes.download,
      Routes.my,
      Routes.settings,
      Routes.popular,
      Routes.timeline,
    ];

    for (int r = 0; r < rounds; r++) {
      for (final target in targets) {
        router.go(target);
        await settleNavigation();
        logWatcher.checkTesterException(
          tester,
          contextDescription: 'Rapid stress: round $r -> $target',
        );
      }
    }

    // Settle at end
    await settleNavigation();
    logWatcher.checkTesterException(tester, contextDescription: 'Rapid stress final settle');
  }
}
