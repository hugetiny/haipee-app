import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/bangumi_tag.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/modules/history/history_module.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chip_style_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(BangumiItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HistoryAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SearchHistoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CollectedBangumiAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ProgressAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(BangumiTagAdapter());
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(ParseFailureRecordAdapter());

    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    GStorage.histories = await Hive.openBox<History>('histories');
    GStorage.collectibles = await Hive.openBox<CollectedBangumi>('collectibles');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Selection Highlight & Zero-Checkmark Tests', () {
    testWidgets('ChoiceChip on OnlineVideoSearchPage disables checkmark and uses highlight styling',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              chipTheme: const ChipThemeData(showCheckmark: false),
            ),
            home: const Scaffold(
              body: OnlineVideoSearchPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all ChoiceChips in the header filter
      final choiceChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(choiceChips.isNotEmpty, isTrue);

      // Verify each ChoiceChip explicitly disables showCheckmark
      for (final chip in choiceChips) {
        expect(chip.showCheckmark, isFalse,
            reason: 'ChoiceChip should not display checkmark/hook when selected');
      }

      // Verify no check icon (Icons.check) is present anywhere in the chip tree
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap on the "视频" chip
      final videoTextFinder = find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.textContaining('视频'),
      );
      expect(videoTextFinder, findsOneWidget);
      await tester.tap(videoTextFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify still no checkmark icon appeared after selection
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('SegmentedButton in BiliLoginDialog has showSelectedIcon disabled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BiliLoginDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find SegmentedButton
      final segmentedButtonFinder = find.byType(SegmentedButton<BiliLoginTab>);
      expect(segmentedButtonFinder, findsOneWidget);

      final segmentedButton =
          tester.widget<SegmentedButton<BiliLoginTab>>(segmentedButtonFinder);
      expect(segmentedButton.showSelectedIcon, isFalse,
          reason: 'SegmentedButton must have showSelectedIcon set to false to avoid crude hook');

      // The 3 segments should have phone, qr, vpn icons visible
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_outlined), findsOneWidget);

      // And no checkmark icon is displayed
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
