import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/error_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal Non-Intrusive Error Toast System Tests', () {
    testWidgets('showToast renders clean toast without intrusive copy button and records to logger',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [HaipeeDialog.observer],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    HaipeeDialog.showToast(
                      context: context,
                      message: '设置下载目录失败: 权限不足',
                      error: 'PlatformException(ENTITLEMENT_NOT_FOUND)',
                    );
                  },
                  child: const Text('Trigger Toast Error'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Toast Error'));
      await tester.pump(); // Start SnackBar animation
      await tester.pump(const Duration(milliseconds: 750)); // Finish animation

      // Text should be rendered cleanly
      expect(find.text('设置下载目录失败: 权限不足'), findsOneWidget);
      // Intrusive copy action button should NOT be present
      expect(find.text('复制报错'), findsNothing);
      // SelectionArea should wrap the message for optional non-intrusive user selection
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('showToast supports explicit user action button when requested',
        (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [HaipeeDialog.observer],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    HaipeeDialog.showToast(
                      context: context,
                      message: '网络异常，请重试',
                      showActionButton: true,
                      actionLabel: '重试',
                      onActionPressed: () {
                        actionTapped = true;
                      },
                    );
                  },
                  child: const Text('Trigger Action Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Action Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('showErrorDialog renders selectable text and copies error on button press',
        (tester) async {
      String? copiedString;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final args = methodCall.arguments as Map<dynamic, dynamic>?;
          copiedString = args?['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [HaipeeDialog.observer],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    HaipeeDialog.showErrorDialog(
                      context: context,
                      title: '下载错误',
                      message: '无法创建目录 /Volumes/HD/downloads',
                      error: 'FileSystemException: Permission denied',
                    );
                  },
                  child: const Text('Trigger Error Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Error Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('下载错误'), findsOneWidget);
      expect(find.text('无法创建目录 /Volumes/HD/downloads'), findsOneWidget);
      expect(find.text('FileSystemException: Permission denied'), findsOneWidget);
      expect(find.text('复制报错信息'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);

      await tester.tap(find.text('复制报错信息'));
      await tester.pump();

      expect(copiedString, contains('【下载错误】'));
      expect(copiedString, contains('无法创建目录 /Volumes/HD/downloads'));
      expect(copiedString, contains('FileSystemException: Permission denied'));
    });

    testWidgets('GeneralErrorWidget has SelectableText and copy button', (tester) async {
      String? copiedString;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final args = methodCall.arguments as Map<dynamic, dynamic>?;
          copiedString = args?['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [HaipeeDialog.observer],
          home: const Scaffold(
            body: GeneralErrorWidget(
              errMsg: '网络连接超时 (TimeoutException)',
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('网络连接超时 (TimeoutException)'), findsOneWidget);
      expect(find.text('复制报错信息'), findsOneWidget);

      await tester.tap(find.text('复制报错信息'));
      await tester.pump();

      expect(copiedString, equals('网络连接超时 (TimeoutException)'));
    });
  });
}
