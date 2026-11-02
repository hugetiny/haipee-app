import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/webdav_editor/webdav_setting.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('webdav_settings_test');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.webDavEnable, true);
    await box.put(SettingBoxKey.webDavEnableHistory, true);
    await box.put(SettingBoxKey.webDavEnableCollect, false);
    await box.put(SettingBoxKey.webDavEnableDanmakuShield, false);
    await box.put(SettingBoxKey.appLocale, 'zh-CN');
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

  testWidgets('WebDavSettingsPage 渲染并支持观看记录、追番收藏与弹幕屏蔽词同步配置', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const WebDavSettingsPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. 验证三大同步板块与操作入口
    expect(find.text('同步设置'), findsOneWidget);
    expect(find.text('WebDAV 同步'), findsOneWidget);
    expect(find.text('观看记录同步'), findsOneWidget);
    expect(find.byKey(const Key('webdav_tile_collect')), findsOneWidget);
    expect(find.text('追番收藏同步'), findsOneWidget);
    expect(find.byKey(const Key('webdav_tile_danmaku_shield')), findsOneWidget);
    expect(find.text('弹幕屏蔽词同步'), findsOneWidget);

    // 2. 验证观看记录与追番收藏操作卡片
    expect(find.text('观看记录'), findsOneWidget);
    expect(find.text('手动上传'), findsOneWidget);
    expect(find.text('手动下载'), findsOneWidget);
    expect(find.text('追番收藏'), findsOneWidget);
    expect(find.text('立即同步追番收藏'), findsOneWidget);
    expect(find.text('手动备份追番收藏'), findsOneWidget);

    // 3. 点击切换追番收藏同步
    await tester.tap(find.byKey(const Key('webdav_tile_collect')));
    await tester.pumpAndSettle();

    final box = GStorage.setting;
    expect(box.get(SettingBoxKey.webDavEnableCollect), isTrue);

    // 4. 点击切换弹幕屏蔽词同步
    await tester.tap(find.byKey(const Key('webdav_tile_danmaku_shield')));
    await tester.pumpAndSettle();

    expect(box.get(SettingBoxKey.webDavEnableDanmakuShield), isTrue);
  });
}
