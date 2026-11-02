import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('sys_app_bar_test');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('SysAppBar 平台自适应与 macOS 避让测试', () {
    testWidgets('二级子页面自动注入 AppBackButton 且正确避让红绿灯', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: SysAppBar(
                        title: Text('外观设置'),
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('进入子页面'),
            ),
          ),
        ),
      );

      // 进入子页面
      await tester.tap(find.text('进入子页面'));
      await tester.pumpAndSettle();

      // 验证子页面中有 SysAppBar 与 AppBackButton
      expect(find.byType(SysAppBar), findsOneWidget);
      expect(find.byType(AppBackButton), findsOneWidget);
      expect(find.text('外观设置'), findsOneWidget);

      if (Platform.isMacOS) {
        // 在 macOS 上，验证 AppBackButton 的横坐标 >= 76.0，绝不与 (0~68) 原生红绿灯重叠
        final backButtonTopLeft = tester.getTopLeft(find.byType(AppBackButton));
        expect(
          backButtonTopLeft.dx,
          greaterThanOrEqualTo(76.0),
          reason: 'macOS 上返回按钮必须位于红绿灯右侧 (>= 76.0px)',
        );

        // 验证标题的起始横坐标位于返回按钮右侧
        final titleTopLeft = tester.getTopLeft(find.text('外观设置'));
        expect(
          titleTopLeft.dx,
          greaterThan(backButtonTopLeft.dx),
          reason: '标题必须位于返回按钮右侧',
        );
      }
    });

    testWidgets('一级页面 (needTopOffset: false) 不产生多余的 76px 避让', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: SysAppBar(
              title: Text('一级设置'),
              needTopOffset: false,
            ),
            body: SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('一级设置'), findsOneWidget);
      // 一级页面没有 Navigator.canPop，无 AppBackButton
      expect(find.byType(AppBackButton), findsNothing);
    });

    testWidgets('桌面端 Escape 快捷键触发返回操作测试', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: SysAppBar(
                        title: Text('子页面'),
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('Go Subpage'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go Subpage'));
      await tester.pumpAndSettle();
      expect(find.text('子页面'), findsOneWidget);

      // 模拟按下 Escape 键
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // 验证已平滑返回上一级页面
      expect(find.text('Go Subpage'), findsOneWidget);
      expect(find.text('子页面'), findsNothing);
    });
  });
}
