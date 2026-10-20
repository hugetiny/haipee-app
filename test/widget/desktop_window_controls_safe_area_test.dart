import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('dwc_safe_area_test');
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

  group('DesktopWindowControlsSafeArea 核心计算与渲染测试', () {
    test('静态计算方法在不同平台与配置下的表现', () {
      if (Platform.isMacOS) {
        expect(DesktopWindowControlsSafeArea.shouldAvoid(requireOffset: true), isTrue);
        expect(DesktopWindowControlsSafeArea.shouldAvoid(requireOffset: false), isFalse);
        expect(
          DesktopWindowControlsSafeArea.leadingWidth(48.0, requireOffset: true),
          48.0 + DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth,
        );
        expect(
          DesktopWindowControlsSafeArea.leadingWidth(48.0, requireOffset: false),
          48.0,
        );
      }
    });

    testWidgets('DesktopWindowControlsSafeArea 容器级避让渲染测试', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopWindowControlsSafeArea(
              requireOffset: true,
              child: const SizedBox(
                key: Key('test_content'),
                width: 100,
                height: 40,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final contentFinder = find.byKey(const Key('test_content'));
      expect(contentFinder, findsOneWidget);

      if (Platform.isMacOS) {
        final pos = tester.getTopLeft(contentFinder);
        expect(
          pos.dx,
          greaterThanOrEqualTo(DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth),
          reason: 'macOS 上容器内组件必须避开左侧 76px 原生红绿灯区域',
        );
      }
    });

    testWidgets('SysAppBar 在二级子页面下保证 leading 和标题均避开红绿灯区域', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: SysAppBar(
                        title: Text('选择播放来源'),
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('打开页面'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开页面'));
      await tester.pumpAndSettle();

      expect(find.byType(SysAppBar), findsOneWidget);
      expect(find.byType(AppBackButton), findsOneWidget);
      expect(find.text('选择播放来源'), findsOneWidget);

      if (Platform.isMacOS) {
        final backButtonPos = tester.getTopLeft(find.byType(AppBackButton));
        expect(
          backButtonPos.dx,
          greaterThanOrEqualTo(76.0),
          reason: 'macOS 上返回键必须避开 (0~76px) 红黄绿三键',
        );

        final titlePos = tester.getTopLeft(find.text('选择播放来源'));
        expect(
          titlePos.dx,
          greaterThan(backButtonPos.dx),
          reason: '标题起始位置必须位于返回键右侧，绝不与红黄绿三键重叠',
        );
      }
    });
  });
}
