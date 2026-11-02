import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/pages/setting/widgets/git_proxy_dialog.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('git_proxy_dialog_test');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
    GStorage.shieldList = await Hive.openBox<String>('shieldList');
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

  setUp(() async {
    await settingBox.clear();
    await settingBox.put(SettingBoxKey.showWindowButton, false);
    await settingBox.put(SettingBoxKey.exitBehavior, 2);
    await settingBox.put(SettingBoxKey.appLocale, 'zh-CN');
    await settingBox.put(SettingBoxKey.metadataBangumiEnabled, true);
    await settingBox.put(SettingBoxKey.metadataTmdbEnabled, true);
  });

  testWidgets('设置主页展示 GitHub 代理导航项并响应点击打开弹窗', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 开启代理并设置自定义地址 (必须在 runAsync 中执行 Hive 写入)
    await tester.runAsync(() async {
      await GitProxyInterceptor.setEnabled(true);
      await GitProxyInterceptor.setProxyUrl('https://ghfast.top/');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: const SettingPage(initialPath: Routes.settingsProxy),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 验证设置页包含 GitHub 代理项并展示已启用状态
    expect(find.text('Github 镜像'), findsOneWidget);
    expect(find.text('已启用 · ghfast.top'), findsOneWidget);
  });

  testWidgets('GitProxyDialog 组件渲染与开关联动', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            navigatorObservers: [HaipeeDialog.observer],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => GitProxyDialog.show(context),
                  child: const Text('打开代理弹窗'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // 打开弹窗
    await tester.tap(find.text('打开代理弹窗'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证标题与基本元素
    expect(find.text('GitHub 加速代理设置'), findsOneWidget);
    expect(find.text('启用 GitHub 网络代理'), findsOneWidget);

    // 默认关闭时，代理地址输入框不展示
    expect(find.text('代理服务地址 (URL 前缀)'), findsNothing);

    // 2. 开启代理开关
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 开关开启后，输入框、预置镜像与测速按钮展开
    expect(find.text('代理服务地址 (URL 前缀)'), findsOneWidget);
    expect(find.text('ghfast.top (推荐)'), findsOneWidget);
    expect(find.text('ghproxy.net'), findsOneWidget);
    expect(find.text('测试连通性'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);

    // 3. 点击切换预置镜像 ghproxy.net
    await tester.tap(find.text('ghproxy.net'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, equals('https://ghproxy.net/'));

    // 4. 输入自定义代理地址
    await tester.enterText(find.byType(TextField), 'https://custom-git-proxy.xyz/');
    await tester.pumpAndSettle();

    // 5. 点击保存并应用
    await tester.ensureVisible(find.text('保存并应用'));
    await tester.tap(find.text('保存并应用'));
    await tester.runAsync(() async {
      for (int i = 0; i < 60; i++) {
        if (GitProxyInterceptor.getEffectiveProxyUrl() ==
            'https://custom-git-proxy.xyz/') {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();

    // 验证底层存储与配置已更新
    expect(GitProxyInterceptor.isEnabled(), isTrue);
    expect(GitProxyInterceptor.getEffectiveProxyUrl(), equals('https://custom-git-proxy.xyz/'));
  });
}
