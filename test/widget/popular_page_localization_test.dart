import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:kazumi/db/database.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/popular/providers.dart';
import 'package:kazumi/utils/storage.dart';

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
  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    GStorage.db = db;
    GStorage.setting = MockBox('setting', db);
    await GStorage.setting.put(SettingBoxKey.showWindowButton, false);
  });

  tearDownAll(() async {
    await GStorage.setting.clear();
    await GStorage.db.close();
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
            navigatorObservers: [KazumiDialog.observer],
            home: const PopularPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final enAllTag = AppLocale.enUs.translations.library.popular.allTag;
    final enEmptyState = AppLocale.enUs.translations.library.common.emptyState;
    final enRetry = AppLocale.enUs.translations.library.common.retry;

    expect(find.text(enAllTag), findsOneWidget);
    expect(find.text(enEmptyState), findsOneWidget);
    expect(find.text(enRetry), findsOneWidget);

    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpAndSettle();

    final zhAllTag = AppLocale.zhCn.translations.library.popular.allTag;
    final zhEmptyState = AppLocale.zhCn.translations.library.common.emptyState;
    final zhRetry = AppLocale.zhCn.translations.library.common.retry;

    expect(find.text(zhAllTag), findsOneWidget);
    expect(find.text(zhEmptyState), findsOneWidget);
    expect(find.text(zhRetry), findsOneWidget);
  });
}
