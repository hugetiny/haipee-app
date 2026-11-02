import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/card/palette_card.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/appearance/theme_settings_page.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_settings_test');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    await settingBox.clear();
    await settingBox.put(SettingBoxKey.themeMode, 'system');
    await settingBox.put(SettingBoxKey.useDynamicColor, false);
    await settingBox.put(SettingBoxKey.themeColor, 'default');
    await settingBox.put(SettingBoxKey.oledEnhance, false);
    await settingBox.put(SettingBoxKey.showWindowButton, false);
  });

  testWidgets('点击主题色能够正常弹出融合动态配色与预设色的统一色板并平滑切换', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const ThemeSettingsPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 校验页面进入无异常
    expect(tester.takeException(), isNull);

    // 查找主题色设置项
    final colorSchemeFinder = find.text('主题色');
    expect(colorSchemeFinder, findsOneWidget);

    // 点击“主题色”导航项，必须正常弹出弹窗，不能抛出任何 LateInitializationError
    await tester.tap(colorSchemeFinder);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '点击主题色绝不能因为 defaultThemeColor 未初始化抛出异常导致界面卡死');

    // 弹窗中应包含动态配色卡片与预设 PaletteCard
    final paletteCards = find.byType(PaletteCard);
    expect(paletteCards, findsWidgets);

    // 寻找“动态配色”选项并点击切换
    final dynamicFinder = find.text('动态配色');
    expect(dynamicFinder, findsOneWidget);

    await tester.tap(dynamicFinder);
    await tester.pumpAndSettle();

    // 弹窗应正常关闭
    expect(find.byType(AlertDialog), findsNothing);

    // 校验动态配色状态已被激活
    expect(container.read(themeProvider).useDynamicColor, isTrue);
    expect(settingBox.get(SettingBoxKey.useDynamicColor), isTrue);

    // 再次点击主题色弹窗
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();

    // 寻找“蓝色”选项并点击切换为固定种子色
    final blueFinder = find.text('蓝色');
    expect(blueFinder, findsOneWidget);

    await tester.tap(blueFinder);
    await tester.pumpAndSettle();

    // 弹窗应正常关闭
    expect(find.byType(AlertDialog), findsNothing);

    // 动态配色状态应自动关闭，seedColor 应当更新为蓝色
    final themeState = container.read(themeProvider);
    expect(themeState.useDynamicColor, isFalse);
    expect(themeState.seedColor, equals(Colors.blue));

    // Hive 持久化值应为蓝色的 ARGB32 16进制字符串
    final savedColor = settingBox.get(SettingBoxKey.themeColor);
    expect(savedColor, equals(Colors.blue.toARGB32().toRadixString(16)));

    // 再次点击主题色恢复默认
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    // 点击“默认”恢复
    final defaultFinder = find.text('默认');
    expect(defaultFinder, findsOneWidget);

    await tester.tap(defaultFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final resetThemeState = container.read(themeProvider);
    expect(resetThemeState.useDynamicColor, isFalse);
    expect(resetThemeState.seedColor, equals(Colors.green));
    expect(settingBox.get(SettingBoxKey.themeColor), equals('default'));

    expect(tester.takeException(), isNull);
  });
}
