import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/adaptive_dialog_frame.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/settings/download/download_settings.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;
  late String targetDownloadDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('download_settings_widget_test');
    targetDownloadDir = '${tempDir.path}/downloads';
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    await box.put(SettingBoxKey.downloadDirectory, targetDownloadDir);
    GStorage.setting = box;
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('下载设置默认下载目录 Tile 遵循 Material 3 规范且在窄屏下 0 像素溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const Scaffold(
              body: DownloadSettingsPage(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull,
        reason: '下载设置界面在窄屏 360 宽度下不得存在任何 RenderFlex 像素溢出');
    expect(find.text('默认下载目录'), findsOneWidget);
    expect(find.text(targetDownloadDir), findsWidgets);

    // 验证编辑按钮存在并点击弹出 Material 3 对话框
    final editBtn = find.byIcon(Icons.edit_outlined);
    expect(editBtn, findsOneWidget);
    await tester.ensureVisible(editBtn);
    await tester.pump();
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('设置默认下载目录'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

    // 模拟修改并保存
    final updatedDir = '${tempDir.path}/downloads/custom';
    final dialogTextField = find.descendant(
      of: find.byType(AdaptiveDialogFrame),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogTextField, updatedDir);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    expect(GStorage.setting.get(SettingBoxKey.downloadDirectory),
        equals(updatedDir));

    // 等待 SnackBar (2秒) 动画与定时器完全结束
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
