import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:kazumi/ui/appbar/kazumi_app_bar.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('unified_back_button_test');
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

  group('全页面统一回退按钮与视窗控制区避让规范测试', () {
    testWidgets('AppBackButton 在不同约束下保持 34x34 视觉尺寸且居中于 48px 热区', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(),
              leadingWidth: 48.0,
            ),
            body: const Row(
              children: [
                AppBackButton(),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final backButtons = find.byType(AppBackButton);
      expect(backButtons, findsNWidgets(2));

      // 验证 AppBar leading 中的 AppBackButton 视觉容器大小
      final containers = find.descendant(
        of: backButtons.first,
        matching: find.byType(AnimatedContainer),
      );
      expect(containers, findsOneWidget);
      final size = tester.getSize(containers);
      expect(size.width, equals(34.0), reason: '视觉按钮宽度必须精确为 34.0px');
      expect(size.height, equals(34.0), reason: '视觉按钮高度必须精确为 34.0px');

      // 验证 Row 中的 AppBackButton 同样维持 34x34
      final rowContainer = find.descendant(
        of: backButtons.last,
        matching: find.byType(AnimatedContainer),
      );
      final rowSize = tester.getSize(rowContainer);
      expect(rowSize.width, equals(34.0));
      expect(rowSize.height, equals(34.0));
    });

    testWidgets('SysAppBar 在 macOS 下回退按钮横向偏移统一对齐于 76.0px，在非 macOS 下从 0.0px 起始', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: SysAppBar(
                        title: Text('测试二级页面'),
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('进入'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('进入'));
      await tester.pumpAndSettle();

      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget);

      final topLeft = tester.getTopLeft(backButton);
      if (Platform.isMacOS) {
        expect(
          topLeft.dx,
          equals(DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth),
          reason: 'macOS 上回退按钮热区槽起始横坐标必须严格等于 76.0px (完全避开红黄绿)',
        );
        final visualContainer = find.descendant(
          of: backButton,
          matching: find.byType(AnimatedContainer),
        );
        final visualTopLeft = tester.getTopLeft(visualContainer);
        // 视觉按钮居中于 [76, 124]，其左侧应位于 76 + (48 - 34)/2 = 83.0px
        expect(visualTopLeft.dx, equals(83.0));
      } else {
        expect(topLeft.dx, equals(0.0), reason: '非 macOS 平台从 0.0px 起始');
      }
    });

    testWidgets('KazumiAppBar 统一自动注入 AppBackButton 并在 macOS 避让', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: KazumiAppBar(
                        title: Text('KazumiAppBar 页面'),
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('Go KazumiAppBar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go KazumiAppBar'));
      await tester.pumpAndSettle();

      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget);

      final topLeft = tester.getTopLeft(backButton);
      if (Platform.isMacOS) {
        expect(
          topLeft.dx,
          equals(DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth),
          reason: 'KazumiAppBar 在 macOS 上的回退按钮必须避让 76.0px',
        );
      }
    });

    testWidgets('DesktopWindowControlsSafeArea.wrapLeading 使用 OverflowBox 在任意 AppBar 中免于尺寸溢出异常', (tester) async {
      // 模拟标准固定 56px 宽度的 AppBar (如 SearchAnchor / 第三方 AppBar)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leadingWidth: 56.0,
              leading: DesktopWindowControlsSafeArea.wrapLeading(
                const AppBackButton(),
              ),
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '不得发生负约束或 RenderFlex 溢出错误');
      expect(find.byType(AppBackButton), findsOneWidget);
    });

    testWidgets('SysAppBar 即使显式设置 needTopOffset: false，当 Navigator.canPop 时也必须在 macOS 上强制避让 76.0px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: SysAppBar(
                        title: Text('强制测试子页面'),
                        needTopOffset: false, // 模拟此前导致避让失效的配置
                      ),
                      body: SizedBox(),
                    ),
                  ),
                );
              },
              child: const Text('进入'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('进入'));
      await tester.pumpAndSettle();

      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget);

      final topLeft = tester.getTopLeft(backButton);
      if (Platform.isMacOS) {
        expect(
          topLeft.dx,
          equals(DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth),
          reason: '即使 needTopOffset: false，macOS 上二级页面回退按钮也必须严格等于 76.0px (完全避开红黄绿)',
        );
      } else {
        expect(topLeft.dx, equals(0.0), reason: '非 macOS 平台从 0.0px 起始');
      }
    });

    testWidgets('AppBackButton 支持自定义 icon (如 Icons.close_rounded) 且保持 34x34 视觉尺寸一致性', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppBackButton(
                  icon: Icons.close_rounded,
                  tooltip: '取消选择',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final closeButton = find.byType(AppBackButton);
      expect(closeButton, findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      final container = find.descendant(
        of: closeButton,
        matching: find.byType(AnimatedContainer),
      );
      final size = tester.getSize(container);
      expect(size.width, equals(34.0));
      expect(size.height, equals(34.0));
    });

    testWidgets('LogsPage 与 SearchPage 统一为第三方视窗注入 leadingWidth 确保回退按钮绝不与标题或搜索栏重叠', (tester) async {
      final effectiveLeadingWidth = DesktopWindowControlsSafeArea.leadingWidth(48.0);
      if (Platform.isMacOS) {
        expect(effectiveLeadingWidth, equals(124.0));
      } else {
        expect(effectiveLeadingWidth, equals(48.0));
      }

      // 测试在注入 leadingWidth 的 AppBar 中，标题文本起始横坐标严格位于 leading 槽位右侧
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: AppBarTheme(
              leadingWidth: effectiveLeadingWidth,
            ),
          ),
          home: Scaffold(
            appBar: AppBar(
              leading: DesktopWindowControlsSafeArea.wrapLeading(
                const AppBackButton(),
              ),
              title: const Text('日志与监控'),
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final backButton = find.byType(AppBackButton);
      expect(backButton, findsOneWidget);
      final titleFinder = find.text('日志与监控');
      expect(titleFinder, findsOneWidget);

      final backTopLeft = tester.getTopLeft(backButton);
      final titleTopLeft = tester.getTopLeft(titleFinder);

      if (Platform.isMacOS) {
        expect(backTopLeft.dx, equals(76.0));
        // 标题起始横坐标严格大于 124.0px，杜绝任何重叠遮挡
        expect(titleTopLeft.dx, greaterThanOrEqualTo(124.0));
      }
    });
  });
}
