import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/menu/menu.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.enUs);
  });

  tearDown(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  testWidgets('navigation labels respond to locale changes', (tester) async {
    const size = Size(400, 800);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ScaffoldMenu(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
                routes: [GoRoute(path: '/home', builder: (_, __) => const SizedBox())]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/timeline', builder: (_, __) => const SizedBox())]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/my', builder: (_, __) => const SizedBox())]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/download', builder: (_, __) => const SizedBox())]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/settings', builder: (_, __) => const SizedBox())]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      ),
    );

    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('My'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpAndSettle();

    expect(find.text('热门番组'), findsOneWidget);
    expect(find.text('时间表'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
