import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/pages/media/media_page.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('haipee_test_setting_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('MediaPage displays 5 major categories: 动画, 影视, 游戏, 音乐, 书籍 and source selector', (tester) async {
    const size = Size(1000, 800);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(
            home: MediaPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. 验证一级菜单页面标题与源站标识
    expect(find.text('资源分类'), findsOneWidget);
    expect(find.text('Bangumi'), findsWidgets);

    // 2. 验证五大子分类选项卡
    expect(find.text('动画'), findsOneWidget);
    expect(find.text('影视'), findsOneWidget);
    expect(find.text('游戏'), findsOneWidget);
    expect(find.text('音乐'), findsOneWidget);
    expect(find.text('书籍'), findsOneWidget);

    // 3. 初始在动画分类，验证动画专属操作
    expect(find.text('放送时间表'), findsOneWidget);

    // 4. 切换到影视子分类
    await tester.tap(find.text('影视'));
    await tester.pumpAndSettle();
    expect(find.text('全网影视搜索'), findsOneWidget);

    // 5. 切换到游戏子分类
    await tester.tap(find.text('游戏'));
    await tester.pumpAndSettle();
    expect(find.text('全网游戏搜索'), findsOneWidget);

    // 6. 切换到音乐子分类
    await tester.tap(find.text('音乐'));
    await tester.pumpAndSettle();
    expect(find.text('全网音乐检索'), findsOneWidget);

    // 7. 切换到书籍子分类
    await tester.tap(find.text('书籍'));
    await tester.pumpAndSettle();
    expect(find.text('全网图书检索'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('MediaPage adapts fluidly to ultra-wide desktop view without ConstrainedContent gutters', (tester) async {
    const wideSize = Size(2560, 1440);
    tester.view.physicalSize = wideSize;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(
            home: MediaPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // 验证在大屏下整个页面无异常且不被 ConstrainedContent 限制在 1280 容器留黑
    expect(find.text('资源分类'), findsOneWidget);
    expect(find.byType(ConstrainedContent), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
