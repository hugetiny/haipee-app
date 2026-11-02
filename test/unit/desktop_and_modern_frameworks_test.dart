import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/bean/widget/modal_sheet/haipee_modal_sheet.dart';
import 'package:haipee/modules/desktop/global_hotkey_manager.dart';

void main() {
  group('GlobalHotKeyManager Architecture Tests', () {
    test('GlobalHotKeyManager singleton properties and default keybindings', () {
      final manager = GlobalHotKeyManager.instance;
      expect(manager, isNotNull);

      // 验证默认老板键 (H) 与媒体键 (Space) 定义
      expect(manager.toggleWindowHotKey.key, PhysicalKeyboardKey.keyH);
      expect(manager.playPauseHotKey.key, PhysicalKeyboardKey.space);
      expect(manager.toggleWindowHotKey.modifiers, contains(HotKeyModifier.shift));
    });

    test('GlobalHotKeyManager graceful execution in non-desktop / headless env', () async {
      final manager = GlobalHotKeyManager.instance;
      bool playPauseCalled = false;
      manager.onPlayPause = () {
        playPauseCalled = true;
      };

      // In flutter test runner (non-desktop platform shell), methods handle lifecycle safely without throwing
      await manager.init();
      await manager.toggleWindowVisibility();
      manager.onPlayPause?.call();
      expect(playPauseCalled, isTrue);

      await manager.dispose();
      expect(manager.onPlayPause, isNull);
    });
  });

  group('AppContextMenu Commercial-Grade Menu Tests', () {
    testWidgets('AppContextMenu renders child and mounts correctly', (tester) async {
      bool actionTriggered = false;

      final testWidget = MaterialApp(
        home: Scaffold(
          body: AppContextMenu(
            itemsBuilder: (context) => [
              AppMenuAction(
                title: '立即下载',
                icon: Icons.download,
                onSelected: () {
                  actionTriggered = true;
                },
              ),
              const AppMenuSeparator(),
              const AppMenuSubmenu(
                title: '更多操作',
                children: [
                  AppMenuAction(
                    title: '复制名称',
                    onSelected: _noop,
                  ),
                ],
              ),
            ],
            child: const Text('Test Item'),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      expect(find.text('Test Item'), findsOneWidget);
      expect(actionTriggered, isFalse);
    });

    testWidgets('AppContextMenu.show renders menu items and submenus in popup', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppContextMenu.show(
                      context,
                      const Offset(100, 100),
                      [
                        AppMenuAction(title: '下载', onSelected: _noop),
                        const AppMenuSeparator(),
                        const AppMenuSubmenu(
                          title: '子操作',
                          icon: Icons.more_horiz,
                          children: [
                            AppMenuAction(title: '子项1', onSelected: _noop),
                          ],
                        ),
                      ],
                    );
                  },
                  child: const Text('打开菜单'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开菜单'));
      await tester.pumpAndSettle();

      expect(find.text('下载'), findsOneWidget);
      expect(find.text('子操作'), findsOneWidget);
    });

    test('AppContextMenu itemsBuilder supports disabled and destructive flags', () {
      final action = AppMenuAction(
        title: '删除任务',
        icon: Icons.delete,
        destructive: true,
        disabled: true,
        onSelected: _noop,
      );

      expect(action.title, '删除任务');
      expect(action.destructive, isTrue);
      expect(action.disabled, isTrue);
    });
  });

  group('HaipeeModalSheet Wolt Modal Tests', () {
    testWidgets('HaipeeModalSheet.buildPage constructs WoltModalSheetPage correctly',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final page = HaipeeModalSheet.buildPage(
        context: capturedContext,
        title: '测试弹窗',
        child: const Text('内容区域'),
      );

      expect(page.topBarTitle, isNotNull);
      expect(page.child, isNotNull);
      expect(page.isTopBarLayerAlwaysVisible, isTrue);
    });

    testWidgets('HaipeeModalSheet.showConfirmation renders buttons and handles dismiss',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    HaipeeModalSheet.showConfirmation(
                      context: context,
                      title: '确认删除',
                      message: '确认删除当前任务吗？',
                      isDestructive: true,
                      icon: Icons.delete_outline,
                    );
                  },
                  child: const Text('打开弹窗'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开弹窗'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除'), findsOneWidget);
      expect(find.text('确认删除当前任务吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);

      // 点击取消关闭
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除当前任务吗？'), findsNothing);
    });
  });

  group('flutter_animate Fluid Motion Tests', () {
    testWidgets('Widgets animate smoothly with fadeIn and slideY', (tester) async {
      final animatedWidget = MaterialApp(
        home: Scaffold(
          body: const Text('Animated Content')
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.05, end: 0),
        ),
      );

      await tester.pumpWidget(animatedWidget);
      expect(find.text('Animated Content'), findsOneWidget);

      // Fast-forward animation clock
      await tester.pump(100.ms);
      expect(find.text('Animated Content'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Animated Content'), findsOneWidget);
    });
  });
}

void _noop() {}
