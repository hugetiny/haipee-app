import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(
            home: ScaffoldMenu(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final enTabs = AppLocale.enUs.translations.navigation.tabs;
    expect(find.text(enTabs.media), findsOneWidget);
    expect(find.text(enTabs.resource), findsOneWidget);
    expect(find.text(enTabs.my), findsOneWidget);
    expect(find.text(enTabs.settings), findsOneWidget);

    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpAndSettle();

    final zhTabs = AppLocale.zhCn.translations.navigation.tabs;
    expect(find.text(zhTabs.media), findsOneWidget);
    expect(find.text(zhTabs.resource), findsOneWidget);
    expect(find.text(zhTabs.my), findsOneWidget);
    expect(find.text(zhTabs.settings), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
