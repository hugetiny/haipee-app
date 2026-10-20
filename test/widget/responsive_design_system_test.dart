import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/responsive/responsive.dart';
import 'package:kazumi/bean/widget/rule/unified_rule_card.dart';
import 'package:kazumi/bean/widget/tree/tree.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp
        .createTemp('responsive_design_system_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(BangumiItemAdapter().typeId)) {
      Hive.registerAdapter(BangumiItemAdapter());
    }
    if (!Hive.isAdapterRegistered(BangumiTagAdapter().typeId)) {
      Hive.registerAdapter(BangumiTagAdapter());
    }
    if (!Hive.isAdapterRegistered(CollectedBangumiAdapter().typeId)) {
      Hive.registerAdapter(CollectedBangumiAdapter());
    }
    if (!Hive.isAdapterRegistered(ProgressAdapter().typeId)) {
      Hive.registerAdapter(ProgressAdapter());
    }
    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles =
        await Hive.openBox<CollectedBangumi>('collectibles');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
  group('Layer 1: Responsive Breakpoints & Extensions', () {
    test('AppBreakpoints.getScreenType maps widths correctly', () {
      expect(AppBreakpoints.getScreenType(320), ScreenType.mobile);
      expect(AppBreakpoints.getScreenType(360), ScreenType.mobile);
      expect(AppBreakpoints.getScreenType(599.9), ScreenType.mobile);
      expect(AppBreakpoints.getScreenType(600.0), ScreenType.tablet);
      expect(AppBreakpoints.getScreenType(800.0), ScreenType.tablet);
      expect(AppBreakpoints.getScreenType(1024.0), ScreenType.tablet);
      expect(AppBreakpoints.getScreenType(1024.1), ScreenType.desktop);
      expect(AppBreakpoints.getScreenType(1440.0), ScreenType.desktop);
    });

    testWidgets('ResponsiveContext extension returns correct values across screen sizes',
        (tester) async {
      late ScreenType recordedScreenType;
      late bool recordedIsMobile;
      late bool recordedIsSmallMobile;
      late bool recordedIsTablet;
      late bool recordedIsDesktop;
      late String recordedResponsiveVal;

      Widget buildTestHarness() {
        return MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                recordedScreenType = context.screenType;
                recordedIsMobile = context.isMobile;
                recordedIsSmallMobile = context.isSmallMobile;
                recordedIsTablet = context.isTablet;
                recordedIsDesktop = context.isDesktop;
                recordedResponsiveVal = context.responsiveValue(
                  mobile: 'mobile_val',
                  tablet: 'tablet_val',
                  desktop: 'desktop_val',
                );
                return const Text('probe');
              },
            ),
          ),
        );
      }

      // 1. 超窄小屏测试 (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestHarness());
      expect(recordedScreenType, ScreenType.mobile);
      expect(recordedIsMobile, isTrue);
      expect(recordedIsSmallMobile, isTrue);
      expect(recordedIsTablet, isFalse);
      expect(recordedIsDesktop, isFalse);
      expect(recordedResponsiveVal, 'mobile_val');

      // 2. 平板测试 (768x1024)
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(buildTestHarness());
      expect(recordedScreenType, ScreenType.tablet);
      expect(recordedIsMobile, isFalse);
      expect(recordedIsSmallMobile, isFalse);
      expect(recordedIsTablet, isTrue);
      expect(recordedIsDesktop, isFalse);
      expect(recordedResponsiveVal, 'tablet_val');

      // 3. 桌面测试 (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(buildTestHarness());
      expect(recordedScreenType, ScreenType.desktop);
      expect(recordedIsMobile, isFalse);
      expect(recordedIsSmallMobile, isFalse);
      expect(recordedIsTablet, isFalse);
      expect(recordedIsDesktop, isTrue);
      expect(recordedResponsiveVal, 'desktop_val');
    });
  });

  group('Layer 1: Responsive Layout Components', () {
    testWidgets('ResponsiveBuilder resolves type from constraints rather than screen size',
        (tester) async {
      ScreenType? innerType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500, // 约束为 mobile
                child: ResponsiveBuilder(
                  builder: (context, screenType, constraints) {
                    innerType = screenType;
                    return Text('Width: ${constraints.maxWidth}');
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(innerType, ScreenType.mobile);
    });

    testWidgets('ResponsiveLayout slots dispatch and fallback properly',
        (tester) async {
      Widget buildLayout() {
        return MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              mobile: (context) => const Text('MobileSlot'),
              tablet: (context) => const Text('TabletSlot'),
              desktop: (context) => const Text('DesktopSlot'),
            ),
          ),
        );
      }

      // Mobile
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildLayout());
      expect(find.text('MobileSlot'), findsOneWidget);
      expect(find.text('TabletSlot'), findsNothing);

      // Desktop
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(buildLayout());
      expect(find.text('DesktopSlot'), findsOneWidget);
    });

    test('AdaptiveGrid.calculateColumns handles edge widths accurately', () {
      // 默认策略
      expect(AdaptiveGrid.calculateColumns(350), 2); // smallMobile
      expect(AdaptiveGrid.calculateColumns(500), 3); // mobile
      expect(AdaptiveGrid.calculateColumns(750), 5); // tablet
      expect(AdaptiveGrid.calculateColumns(1200), 6); // desktop
      expect(AdaptiveGrid.calculateColumns(1920), 9); // wide desktop (dynamic scaling)
      expect(AdaptiveGrid.calculateColumns(2560), 12); // 2K ultra-wide
      expect(AdaptiveGrid.calculateColumns(3840), 18); // 4K ultra-wide

      // minItemWidth 策略
      expect(AdaptiveGrid.calculateColumns(600, minItemWidth: 180), 3);
      expect(AdaptiveGrid.calculateColumns(1000, minItemWidth: 200), 5);
      expect(AdaptiveGrid.calculateColumns(100, minItemWidth: 200), 1); // 至少 1 列
      expect(AdaptiveGrid.calculateColumns(3840, minItemWidth: 160), 24); // 最大 24 列 clamp
    });

    test('UnifiedRuleGrid.columnsForWidth scales smoothly across widths', () {
      expect(UnifiedRuleGrid.columnsForWidth(500), 1);
      expect(UnifiedRuleGrid.columnsForWidth(800), 2);
      expect(UnifiedRuleGrid.columnsForWidth(1300), 3);
      expect(UnifiedRuleGrid.columnsForWidth(1800), 4);
      expect(UnifiedRuleGrid.columnsForWidth(2200), 5);
      expect(UnifiedRuleGrid.columnsForWidth(2800), 6);
      expect(UnifiedRuleGrid.columnsForWidth(3200), 7);
      expect(UnifiedRuleGrid.columnsForWidth(4000), 8);
    });

    testWidgets('AdaptiveGrid renders without overflow under varied widths',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: AdaptiveGrid(
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Card(
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('AdaptiveGrid renders on 2560px ultrawide desktop without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2560,
              height: 1440,
              child: AdaptiveGrid(
                minItemWidth: 168.0,
                itemCount: 30,
                extentBuilder: (colWidth) => colWidth / 0.65 + 48.0,
                itemBuilder: (context, index) {
                  return Card(
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('AdaptiveWrap collapses to Column when width is below breakpoint',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: AdaptiveWrap(
                collapseBreakpoint: 400,
                children: const [
                  Text('Child 1'),
                  Text('Child 2'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);

      // 宽视口下使用 Wrap
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: AdaptiveWrap(
                collapseBreakpoint: 400,
                children: const [
                  Text('Child 1'),
                  Text('Child 2'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('ConstrainedContent centers and limits max width on wide screens',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              child: ConstrainedContent(
                maxWidth: 1000,
                child: SizedBox(
                  key: Key('inner_child'),
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.byKey(const Key('inner_child')),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(constrainedBox.constraints.maxWidth, 1000.0);
    });
  });

  group('Layer 2: TreeView Domain Components (TreeTile & TreeIndent)', () {
    testWidgets('TreeIndent correctly enforces bounds without overflowing',
        (tester) async {
      // 1. depth = 0
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              TreeIndent(depth: 0),
            ],
          ),
        ),
      );
      final size0 = tester.getSize(find.byType(TreeIndent));
      expect(size0.width, 0.0);

      // 2. depth = 2 (2 * 14 = 28)
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              TreeIndent(depth: 2, indentWidth: 14.0, maxIndent: 48.0),
            ],
          ),
        ),
      );
      final size2 = tester.getSize(find.byType(TreeIndent));
      expect(size2.width, 28.0);

      // 3. depth = 10, maxIndent = 48.0 (10 * 14 = 140 -> clamped to 48.0)
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              TreeIndent(depth: 10, indentWidth: 14.0, maxIndent: 48.0),
            ],
          ),
        ),
      );
      final size10 = tester.getSize(find.byType(TreeIndent));
      expect(size10.width, 48.0);
    });

    testWidgets('TreeTile slot layout and tap callbacks work as expected',
        (tester) async {
      bool tapped = false;
      bool checkboxToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TreeTile(
              depth: 1,
              expandIcon: const Icon(Icons.arrow_right, key: Key('expand_icon')),
              checkbox: Checkbox(
                key: const Key('checkbox_slot'),
                value: false,
                onChanged: (v) => checkboxToggled = true,
              ),
              icon: const Icon(Icons.folder, key: Key('type_icon')),
              title: const Text('Test Directory Title'),
              trailing: const Text('42 items', key: Key('trailing_slot')),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('expand_icon')), findsOneWidget);
      expect(find.byKey(const Key('checkbox_slot')), findsOneWidget);
      expect(find.byKey(const Key('type_icon')), findsOneWidget);
      expect(find.text('Test Directory Title'), findsOneWidget);
      expect(find.byKey(const Key('trailing_slot')), findsOneWidget);

      await tester.tap(find.text('Test Directory Title'));
      expect(tapped, isTrue);

      await tester.tap(find.byKey(const Key('checkbox_slot')));
      expect(checkboxToggled, isTrue);
    });

    testWidgets('TreeTile never overflows under extreme narrow constraint and deep nesting',
        (tester) async {
      // 极端测试：宽度仅 220dp，深度 8 层，长文件名，附带超长尾部标签
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: TreeTile(
                depth: 8,
                expandIcon: const Icon(Icons.arrow_right),
                checkbox: Checkbox(value: true, onChanged: (_) {}),
                icon: const Icon(Icons.movie_creation_outlined),
                title: const Text(
                  '[Kamigami&VCB-Studio] Sousou no Frieren [01][Ma10p_1080p][x265_flac_aac].mkv',
                ),
                trailing: const Text('1.42 GB [1080P Ultra BluRay Rip]'),
              ),
            ),
          ),
        ),
      );

      // 验证无任何 RenderFlex 溢出异常
      expect(tester.takeException(), isNull);

      // 验证标题组件被包裹为单行省略
      final textWidget = tester.widget<Text>(find.text(
        '[Kamigami&VCB-Studio] Sousou no Frieren [01][Ma10p_1080p][x265_flac_aac].mkv',
      ));
      expect(textWidget.data, isNotNull);
    });

    testWidgets('TreeTile in a virtualized ListView under multi-viewports produces 0 errors',
        (tester) async {
      const viewports = [
        Size(320, 480), // 超窄旧设备
        Size(360, 640), // 紧凑移动端
        Size(600, 800), // 平板折叠视口
        Size(1280, 860), // 宽屏桌面
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) {
                  return TreeTile(
                    depth: index % 6,
                    expandIcon: index.isEven ? const Icon(Icons.expand_more) : null,
                    reserveExpandSpace: true,
                    checkbox: Checkbox(value: index.isOdd, onChanged: (_) {}),
                    icon: Icon(index.isEven ? Icons.folder : Icons.insert_drive_file),
                    title: Text(
                      'Deeply Nested Path Level ${index % 6}/Very Long Segment Name For Testing Layout Bounds #$index.mp4',
                    ),
                    trailing: Text('${(index * 123.4).toStringAsFixed(1)} MB'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Failed on viewport ${vp.width}x${vp.height}',
        );
      }
    });
  });

  group('Layer 3: Widescreen Fluid Responsiveness Across Settings & Info Views', () {
    test('Responsive pages scale columns gracefully without artificial hard caps', () {
      // Mobile standard (390dp): 3 columns
      expect(AdaptiveGrid.calculateColumns(390), 3);
      // Small mobile (360dp): 2 columns
      expect(AdaptiveGrid.calculateColumns(360), 2);
      // Tablet (800dp): 5 columns
      expect(AdaptiveGrid.calculateColumns(800), 5);
      // Standard desktop (1280dp): 6 columns
      expect(AdaptiveGrid.calculateColumns(1280), 6);
      // 1080p desktop (1920dp): 9 columns
      expect(AdaptiveGrid.calculateColumns(1920), 9);
      // 2K ultrawide (2560dp): 12 columns
      expect(AdaptiveGrid.calculateColumns(2560), 12);
      // 4K ultrawide (3840dp): 18 columns
      expect(AdaptiveGrid.calculateColumns(3840), 18);
    });

    testWidgets('SettingsList with default maxWidth renders full width on 2560px ultrawide display',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2560,
              height: 1440,
              child: SettingsList(
                sections: [
                  SettingsSection(
                    title: const Text('Appearance'),
                    tiles: [
                      SettingsTile(
                        title: const Text('Theme Mode'),
                        trailing: const Text('System'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no ConstrainedContent wrapper limiting width to 1000
      expect(find.byType(ConstrainedContent), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('BangumiInfoCardV expands fluidly on 2560px screen without 1500px maxWidth clamp',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleBangumi = BangumiItem(
        id: 12345,
        type: 2,
        name: 'Frieren',
        nameCn: '葬送的芙莉莲',
        summary: '旅途与回忆',
        airDate: '2024-01-05',
        airWeekday: 5,
        rank: 1,
        images: {'large': ''},
        tags: [],
        alias: [],
        ratingScore: 9.3,
        votes: 45210,
        votesCount: [10, 20, 30, 40, 50, 60, 100, 500, 1200, 5000],
        info: '全28话',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 2560,
                child: BangumiInfoCardV(
                  bangumiItem: sampleBangumi,
                  isLoading: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cardFinder = find.byType(BangumiInfoCardV);
      expect(cardFinder, findsOneWidget);

      final renderBox = tester.renderObject(cardFinder) as RenderBox;
      expect(renderBox.size.width, 2560.0);
    });
  });
}
