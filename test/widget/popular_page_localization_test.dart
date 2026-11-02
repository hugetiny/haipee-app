import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/menu/menu.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/popular_page.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/utils/storage.dart';

class _FakePopularController extends PopularController {
  _FakePopularController(this._initialState);

  final PopularState _initialState;

  @override
  PopularState build() => _initialState;

  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {}

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) async {}
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('haipee_test_setting_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.enUs);
  });

  tearDown(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  testWidgets('popular page surfaces localized tag label and error state',
      (tester) async {
    const initialState = PopularState(isTimeOut: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularProvider
              .overrideWith(() => _FakePopularController(initialState)),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const ScaffoldMenu(child: PopularPage()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final enAllTag = AppLocale.enUs.translations.library.popular.allTag;
    final enEmptyState = AppLocale.enUs.translations.library.common.emptyState;
    final enRetry = AppLocale.enUs.translations.library.common.retry;

    expect(find.text(enAllTag), findsWidgets);
    expect(find.text(enEmptyState), findsOneWidget);
    expect(find.text(enRetry), findsOneWidget);

    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpAndSettle();

    final zhAllTag = AppLocale.zhCn.translations.library.popular.allTag;
    final zhEmptyState = AppLocale.zhCn.translations.library.common.emptyState;
    final zhRetry = AppLocale.zhCn.translations.library.common.retry;

    expect(find.text(zhAllTag), findsWidgets);
    expect(find.text(zhEmptyState), findsOneWidget);
    expect(find.text(zhRetry), findsOneWidget);
  });
}
