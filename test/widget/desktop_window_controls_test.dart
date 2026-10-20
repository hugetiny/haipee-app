import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/desktop_window_controls.dart';

void main() {
  testWidgets('DesktopWindowControls 组件安全渲染测试', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Row(
              children: [
                DesktopWindowControls(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull, reason: '桌面控制组件渲染不应有任何异常');
  });
}
