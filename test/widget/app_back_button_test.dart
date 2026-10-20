import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';

void main() {
  group('AppBackButton 商业级返回按钮组件测试', () {
    testWidgets('基本渲染与点击回调正常触发', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppBackButton(
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppBackButton), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('桌面端鼠标 Hover 动效状态响应测试', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppBackButton(),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // 移动到按钮中心触发 hover
      final buttonFinder = find.byType(AppBackButton);
      await gesture.moveTo(tester.getCenter(buttonFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // 验证未抛出任何异常且 AnimatedContainer 正常重绘
      expect(tester.takeException(), isNull);

      // 移开鼠标
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);
    });

    testWidgets('自定义尺寸、颜色与 Tooltip 渲染测试', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppBackButton(
                size: 40.0,
                color: Colors.red,
                tooltip: '自定义返回',
              ),
            ),
          ),
        ),
      );

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, '自定义返回');

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.red);
    });
  });
}
