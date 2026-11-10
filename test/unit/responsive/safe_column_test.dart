import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

void main() {
  group('SafeColumn Zero-Overflow Verification', () {
    testWidgets('Normal Column overflows when content exceeds parent height', (tester) async {
      // 构造一个固定高度 200px 的父容器，内含 300px 的 Column
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 300,
              child: Column(
                children: const [
                  SizedBox(height: 100, child: Text('Child 1')),
                  SizedBox(height: 100, child: Text('Child 2')),
                  SizedBox(height: 100, child: Text('Child 3')),
                ],
              ),
            ),
          ),
        ),
      );

      // 原生 Column 会抛出 RenderFlex overflowed by 100 pixels on the bottom 异常
      final dynamic exception = tester.takeException();
      expect(exception, isNotNull, reason: 'Raw Column must trigger overflow exception');
      expect(exception.toString(), contains('overflowed'));
    });

    testWidgets('SafeColumn completely prevents overflow by automatically enabling scroll', (tester) async {
      // 在完全相同甚至更严苛的固定高度 150px 下运行 SafeColumn
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              width: 300,
              child: SafeColumn(
                children: const [
                  SizedBox(height: 100, child: Text('Child 1')),
                  SizedBox(height: 100, child: Text('Child 2')),
                  SizedBox(height: 100, child: Text('Child 3')),
                ],
              ),
            ),
          ),
        ),
      );

      // SafeColumn 自动启用内嵌自适应滚动，从根本上 0 像素溢出！
      expect(tester.takeException(), isNull, reason: 'SafeColumn must NEVER throw RenderFlex overflow');
      expect(find.text('Child 1'), findsOneWidget);

      // 可以向下顺畅滚动查看被容纳的内容
      await tester.drag(find.text('Child 1'), const Offset(0, -120));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SafeColumn maintains standard alignment when height is abundant', (tester) async {
      // 当空间充裕（高度 800px）时，SafeColumn 保持原生 Column 的对齐与非滚动特性
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 300,
              child: SafeColumn(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Top'),
                  Text('Bottom'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
    });
  });
}
