import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/setting/setting_page.dart';
import 'package:kazumi/pages/setting/media/media_settings_page.dart';
import 'package:kazumi/pages/setting/metadata/metadata_settings_page.dart';
import 'package:kazumi/utils/storage.dart';

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

  testWidgets('验证设置中心五大顶级一级分类排序与层级结构', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [KazumiDialog.observer],
            home: const SettingPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull,
        reason: '设置主页面在宽屏 1200 宽度下不得存在任何 RenderFlex 像素溢出');

    // 1. 验证通用在最顶部，随后是视听与媒体
    expect(find.text('通用'), findsOneWidget); // 通用在最顶部
    expect(find.text('视听与媒体'), findsOneWidget); // 音视频一级大项
    expect(find.text('资源检索与下载'), findsOneWidget);
    expect(find.text('数据与云同步'), findsOneWidget);
    expect(find.text('其他'), findsNothing, reason: '其他分类已移除，实用功能收敛入通用');

    // 2. 验证通用分类下的实用功能已成功移入
    expect(find.text('清除缓存'), findsOneWidget);
    expect(find.text('自动更新'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('开源许可证'), findsOneWidget);
    expect(find.text('运行日志与诊断'), findsOneWidget);

    // 3. 验证音视频一级分类下的核心项目
    expect(find.text('播放设置'), findsOneWidget);
    expect(find.text('弹幕设置'), findsOneWidget);
    expect(find.text('媒体元数据与刮削'), findsOneWidget);
    expect(find.text('Kazumi 视频规则'), findsOneWidget);

    // 4. 验证资源检索与下载分类下的规则项
    expect(find.text('Cardigann 规则'), findsOneWidget);
  });

  testWidgets('验证媒体元数据与刮削独立子页面 (Bangumi 与 TMDB)', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [KazumiDialog.observer],
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
            navigatorObservers: [KazumiDialog.observer],
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
    expect(find.text('Kazumi 视频规则'), findsOneWidget);
  });
}
