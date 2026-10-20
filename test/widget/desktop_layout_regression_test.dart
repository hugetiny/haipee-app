import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/popular/providers.dart';
import 'package:kazumi/utils/storage.dart';

class _FakePopularController extends PopularController {
  _FakePopularController(this._initialState);

  final PopularState _initialState;

  @override
  PopularState build() => _initialState;

  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {}

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) async {}
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('desktop_layout_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('桌面端布局回归测试：无多余FAB，侧边栏置顶，标题绝不碰撞红绿灯', (tester) async {
    // 模拟桌面端横屏尺寸 1280x860
    const desktopSize = Size(1280, 860);
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1.0;

    const initialState = PopularState(isTimeOut: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularProvider
              .overrideWith(() => _FakePopularController(initialState)),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: ScaffoldMenu(child: PopularPage()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. 验证存在 NavigationRail，并且不存在突兀的绿色放大镜 FAB
    expect(find.byType(NavigationRail), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.leading, isNull, reason: 'NavigationRail 不应存在多余的 leading 搜索 FAB');

    // 2. 验证整个 PopularPage 中不存在任何 FloatingActionButton (arrow_upward)
    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'PopularPage 中不应存在回到顶部悬浮按钮');

    // 3. 验证 NavigationRail 自窗口顶端延伸 (y == 0)
    final railTopLeft = tester.getTopLeft(find.byType(NavigationRail));
    expect(railTopLeft.dy, equals(0.0), reason: 'NavigationRail 应自窗口顶端延伸');

    // 4. 验证分类下拉标题横坐标位于右侧内容区 (dx >= 76.0)，绝不与 macOS 红绿灯重叠
    final arrowDownFinder = find.byIcon(Icons.keyboard_arrow_down);
    expect(arrowDownFinder, findsOneWidget);
    final arrowDownTopLeft = tester.getTopLeft(arrowDownFinder);
    expect(
      arrowDownTopLeft.dx,
      greaterThanOrEqualTo(76.0),
      reason: '页面标题必须位于右侧内容区，绝不与 macOS 原生红绿灯按钮 (0~76px) 发生重叠穿透',
    );

    // 5. 验证 AppBar actions 中保留搜索与历史图标按钮
    expect(find.byIcon(Icons.search), findsOneWidget,
        reason: 'PopularPage 顶栏 actions 应包含搜索图标按钮');
    expect(find.byIcon(Icons.history), findsOneWidget,
        reason: 'PopularPage 顶栏 actions 应包含历史图标按钮');

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('桌面端无侧边栏模式（纵向窗口）macOS 顶栏避让原生红黄绿按钮', (tester) async {
    // 模拟桌面端纵向窗口尺寸 600x900
    const portraitSize = Size(600, 900);
    tester.view.physicalSize = portraitSize;
    tester.view.devicePixelRatio = 1.0;

    const initialState = PopularState(isTimeOut: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularProvider
              .overrideWith(() => _FakePopularController(initialState)),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: ScaffoldMenu(child: PopularPage()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 纵向模式下无 NavigationRail，使用 NavigationBar
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    if (Platform.isMacOS) {
      // 验证标题避让 macOS 红黄绿按钮 (dx >= 76.0)
      final arrowDownFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(arrowDownFinder, findsOneWidget);
      final arrowDownTopLeft = tester.getTopLeft(arrowDownFinder);
      expect(
        arrowDownTopLeft.dx,
        greaterThanOrEqualTo(76.0),
        reason: '纵向窗口无侧边栏时，标题必须避让 macOS 红黄绿三色视窗按钮 (0~76px)',
      );
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
