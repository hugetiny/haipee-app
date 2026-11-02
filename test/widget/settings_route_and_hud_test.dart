import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/debug_hud_overlay.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/pages/setting/indexer/indexer_settings_page.dart';
import 'package:haipee/pages/setting/metadata/metadata_settings_page.dart';
import 'package:haipee/pages/setting/media/media_settings_page.dart';
import 'package:haipee/pages/about/license_page.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/app_back_button.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_route_and_hud_test');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    await box.put(SettingBoxKey.exitBehavior, 2);
    await box.put(SettingBoxKey.appLocale, 'zh-CN');
    await box.put(SettingBoxKey.metadataBangumiEnabled, true);
    await box.put(SettingBoxKey.metadataTmdbEnabled, true);
    GStorage.setting = box;
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('GoRouter 路由完整性与规则管理导航测试', () {
    testWidgets('验证 Routes.settingsIndexers 成功匹配 IndexerSettingsPage 无 route error', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 导航到 /settings/indexers
      router.go(Routes.settingsIndexers);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull, reason: '不得抛出 route error');
      expect(find.byType(IndexerSettingsPage), findsOneWidget);
      expect(find.text('Cardigann 规则管理'), findsOneWidget);
    });

    testWidgets('验证 Routes.settingsMetadata 成功匹配 MetadataSettingsPage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      router.go(Routes.settingsMetadata);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MetadataSettingsPage), findsOneWidget);
      expect(find.text('媒体元数据与刮削'), findsOneWidget);
    });

    testWidgets('验证 Routes.settingsMedia 成功匹配 MediaSettingsPage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      router.go(Routes.settingsMedia);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MediaSettingsPage), findsOneWidget);
      expect(find.text('视听与媒体'), findsOneWidget);
    });

    testWidgets('验证 Routes.settingsAboutLicense 成功匹配 HaipeeLicensePage 且使用 SysAppBar 与避让回退按钮', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      router.go(Routes.settingsAboutLicense);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.byType(HaipeeLicensePage), findsOneWidget);
      expect(find.byType(SysAppBar), findsWidgets);
      final licenseBackButton = find.descendant(
        of: find.byType(HaipeeLicensePage),
        matching: find.byType(AppBackButton),
      );
      expect(licenseBackButton, findsOneWidget);

      if (Platform.isMacOS) {
        expect(
          tester.getTopLeft(licenseBackButton).dx,
          equals(76.0),
          reason: 'HaipeeLicensePage 回退按钮必须精确避让 76.0px (红黄绿视窗控制区)',
        );
      }
    });
  });

  group('全局悬浮 Debug HUD (DevLog) 与运行日志诊断开关验证', () {
    testWidgets('DebugHudOverlay 在调试模式下常驻渲染并在右下角展示 DevLog 药丸', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);
      AppLog.resetErrorCount();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DebugHudOverlay), findsOneWidget);
      expect(find.text('DevLog'), findsOneWidget);
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);

      // 验证触发错误时徽标数字变更
      AppLog.recordError();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('DebugHudOverlay 在调试模式关闭时隐藏 DevLog 药丸', (tester) async {
      AppLog.setDebugMode(false);
      AppLog.setLogScreenVisible(false);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) =>
                  DebugHudOverlay(child: child ?? const SizedBox()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证 DevLog 药丸完全不渲染
      expect(find.text('DevLog'), findsNothing);
      expect(find.byIcon(Icons.terminal_rounded), findsNothing);
    });

    testWidgets('SettingPage 中运行日志与诊断开关可动态切换并控制子入口展示', (tester) async {
      AppLog.setDebugMode(false);

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: const SettingPage(initialPath: Routes.settingsStorage),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('运行日志与诊断'), findsOneWidget);
      // 当 debugMode 为 false 时，子入口不渲染
      expect(find.text('查看运行日志与诊断面板'), findsNothing);

      // 开启开关，触发 debugMode 为 true
      AppLog.setDebugMode(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 当 debugMode 开启时，子入口展示
      expect(find.text('查看运行日志与诊断面板'), findsOneWidget);
    });
  });
}
