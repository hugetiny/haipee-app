import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/pages/setting/media/media_settings_page.dart';
import 'package:haipee/pages/setting/metadata/metadata_settings_page.dart';
import 'package:haipee/pages/settings/interface_settings.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_hierarchy_test');
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

  testWidgets('验证设置中心四大顶级一级分类排序与层级结构', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const SettingPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull,
        reason: '设置主页面在宽屏 1200 宽度下不得存在任何 RenderFlex 像素溢出');

    // 1. 验证四大顶级分类 (播放、资源、应用、其他)
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(find.text('应用'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);

    // 2. 验证播放分类下的核心项目 (播放设置出现在左侧导轨及默认右侧详情标题)
    expect(find.text('播放设置'), findsNWidgets(2));
    expect(find.text('弹幕设置'), findsOneWidget);
    expect(find.text('操作设置'), findsOneWidget);
    expect(find.text('媒体元数据与刮削'), findsOneWidget);

    // 3. 验证资源分类下的核心项目
    expect(find.text('规则管理'), findsOneWidget);
    expect(find.text('下载设置'), findsOneWidget);

    // 4. 验证应用分类下的核心项目
    expect(find.text('外观设置'), findsOneWidget);
    expect(find.text('界面设置'), findsOneWidget);
    expect(find.text('同步设置'), findsOneWidget);
    expect(find.text('网络设置'), findsOneWidget);

    // 5. 验证其他分类下的核心项目
    expect(find.text('更新设置'), findsOneWidget);
    expect(find.text('存储与日志'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('验证媒体元数据与刮削独立子页面 (Bangumi 与 TMDB)', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const MetadataSettingsPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('媒体元数据与刮削'), findsOneWidget);
    expect(find.text('Bangumi (番剧数据库)'), findsOneWidget);
    expect(find.text('TMDB (影视元数据)'), findsOneWidget);
    expect(find.text(AppLocale.zhCn.translations.settings.metadata.enableBangumi), findsOneWidget);
    expect(find.text(AppLocale.zhCn.translations.settings.metadata.enableTmdb), findsOneWidget);
  });

  testWidgets('验证视听与媒体二级聚合工作台页面', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const MediaSettingsPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('视听与媒体'), findsOneWidget);
    expect(find.text('播放与渲染'), findsOneWidget);
    expect(find.text('内容识别与在线源'), findsOneWidget);
    expect(find.text('播放设置'), findsOneWidget);
    expect(find.text('弹幕设置'), findsOneWidget);
    expect(find.text('媒体元数据与刮削'), findsOneWidget);
    expect(find.text('Haipee 视频规则'), findsOneWidget);
  });

  testWidgets('验证界面设置子页面包含语言设置与系统设置项', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const InterfaceSettingsPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('界面设置'), findsOneWidget);
    expect(find.text('语言设置'), findsOneWidget);
    expect(find.text('启动界面设置'), findsOneWidget);
    expect(find.text('显示评分'), findsOneWidget);
  });

  testWidgets('验证深层子路由映射与内嵌详情页渲染', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    // 1. 验证关于页及许可证路径正确激活关于详情页
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const SettingPage(initialPath: '/settings/about/license'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('关于'), findsWidgets);

    // 2. 验证外观设置内嵌渲染正常且零溢出
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const SettingPage(initialPath: Routes.settingsTheme),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('外观设置'), findsWidgets);
    expect(find.text('主题色'), findsOneWidget);
  });
}
