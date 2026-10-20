import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/search/providers.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/storage.dart';

class _FakeSearchPageController extends SearchPageController {
  final SearchPageState testState;
  _FakeSearchPageController([SearchPageState? initialState])
      : testState = initialState ?? const SearchPageState();

  @override
  SearchPageState build() => testState;

  @override
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      state = state.copyWith(bangumiList: [], isLoading: false, isTimeOut: false);
      return;
    }
    state = state.copyWith(
      isLoading: false,
      isTimeOut: false,
      keyword: normalized,
      bangumiList: state.bangumiList.isNotEmpty
          ? state.bangumiList
          : [
              BangumiItem.fromJson({
                'id': 1001,
                'name': normalized,
                'type': 2,
                'name_cn': normalized,
                'summary': '简介: $normalized',
                'date': '2024-01-01',
                'images': {
                  'large': '',
                  'common': '',
                  'medium': '',
                  'small': '',
                  'grid': '',
                },
              }),
            ],
    );
  }

  @override
  Future<void> deleteSearchHistory(SearchHistory history) async {
    state = state.copyWith(
      searchHistories: state.searchHistories
          .where((element) => element.key != history.key)
          .toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_search_page_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SearchHistoryAdapter());
    }
    GStorage.searchHistory = await Hive.openBox<SearchHistory>('test_search_history_box_${DateTime.now().millisecondsSinceEpoch}');
    GStorage.setting = await Hive.openBox('test_search_setting_box_${DateTime.now().millisecondsSinceEpoch}');
  });

  tearDownAll(() async {
    try {
      await GStorage.searchHistory.close();
      await GStorage.setting.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('SearchPage search view opens automatically, has active focus, and accepts keyboard typing on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController()),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify search view is open and has text field
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2)); // Anchor field and active overlay field

    final activeField = textFields.last;
    final editableTextFinder = find.descendant(
      of: activeField,
      matching: find.byType(EditableText),
    );
    expect(editableTextFinder, findsOneWidget);

    // Verify primary focus
    final editableWidget = tester.widget<EditableText>(editableTextFinder);
    expect(editableWidget.focusNode.hasFocus, isTrue);

    // Type smoothly
    await tester.enterText(activeField, '葬送的芙莉莲');
    await tester.pumpAndSettle();
    expect(find.text('葬送的芙莉莲'), findsWidgets);

    // Submit search
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Results rendered in AdaptiveGrid
    expect(find.byType(BangumiCardV), findsOneWidget);
    expect(find.text('葬送的芙莉莲'), findsWidgets);
  });

  testWidgets('SearchPage allows clearing text with clear button and re-typing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController()),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final activeField = find.byType(TextField).last;
    await tester.enterText(activeField, '测试关键字');
    await tester.pumpAndSettle();
    expect(find.text('测试关键字'), findsWidgets);

    // Tap clear button in trailing
    final clearButton = find.byIcon(Icons.clear);
    expect(clearButton, findsWidgets);
    await tester.tap(clearButton.last);
    await tester.pumpAndSettle();

    expect(find.text('测试关键字'), findsNothing);
  });

  testWidgets('SearchPage allows closing search view and re-tapping search bar to type again', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController()),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Close view by pressing the view leading back button
    final backButtons = find.byType(IconButton);
    expect(backButtons, findsWidgets);

    final viewBackButton = find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(SearchPage))).backButtonTooltip);
    if (viewBackButton.evaluate().isNotEmpty) {
      await tester.tap(viewBackButton.first);
    } else {
      await tester.tap(backButtons.first);
    }
    await tester.pumpAndSettle();

    // Now closed, tapping the search bar re-opens and allows typing
    final anchorField = find.byType(TextField).first;
    await tester.tap(anchorField);
    await tester.pumpAndSettle();

    final activeField = find.byType(TextField).last;
    await tester.enterText(activeField, '鬼灭之刃');
    await tester.pumpAndSettle();

    expect(find.text('鬼灭之刃'), findsWidgets);
  });

  testWidgets('SearchPage displays Bangumi results and allows tapping BangumiCardV to navigate to info', (tester) async {
    final sampleItem = BangumiItem.fromJson({
      'id': 1002,
      'name': 'Demon Slayer',
      'type': 2,
      'name_cn': '鬼灭之刃',
      'summary': '炭治郎的故事',
      'date': '2019-04-06',
      'images': {
        'large': '',
        'common': '',
        'medium': '',
        'small': '',
        'grid': '',
      },
    });

    final mockState = SearchPageState(
      isLoading: false,
      bangumiList: [sampleItem],
      searchHistories: [SearchHistory('鬼灭之刃', DateTime.now().millisecondsSinceEpoch)],
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SearchPage(inputTag: '动作'),
        ),
        GoRoute(
          path: Routes.info,
          builder: (context, state) => const Scaffold(body: Text('Bangumi Info Page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController(mockState)),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tag search mounts without auto-opening overlay view, directly displaying results
    expect(find.byType(BangumiCardV), findsOneWidget);
    expect(find.text('鬼灭之刃'), findsOneWidget);

    // Tap card to navigate into info/video details
    await tester.tap(find.byType(BangumiCardV));
    await tester.pumpAndSettle();

    expect(find.text('Bangumi Info Page'), findsOneWidget);
  });

  testWidgets('SearchPage suggestion selection triggers search and closes view without network hang', (tester) async {
    final history = SearchHistory('葬送的芙莉莲', DateTime.now().millisecondsSinceEpoch);

    final mockState = SearchPageState(
      isLoading: false,
      searchHistories: [history],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController(mockState)),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The search view auto-opens and lists the history item
    expect(find.text('葬送的芙莉莲'), findsWidgets);

    // Tap on the history ListTile
    final historyTile = find.widgetWithText(ListTile, '葬送的芙莉莲');
    expect(historyTile, findsOneWidget);
    await tester.tap(historyTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // View closes and results/anchor text are displayed
    expect(find.text('葬送的芙莉莲'), findsWidgets);
  });

  testWidgets('SearchPage deletes history item when delete icon on suggestion tile is tapped', (tester) async {
    final history = SearchHistory('进击的巨人', DateTime.now().millisecondsSinceEpoch);

    final mockState = SearchPageState(
      isLoading: false,
      searchHistories: [history],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController(mockState)),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('进击的巨人'), findsWidgets);

    // Tap the delete icon on the history ListTile
    final deleteIcon = find.descendant(
      of: find.widgetWithText(ListTile, '进击的巨人'),
      matching: find.byIcon(Icons.close),
    );
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    // State updated to remove history
    expect(find.widgetWithText(ListTile, '进击的巨人'), findsNothing);
  });

  testWidgets('SearchPage safely handles encoded and malformed inputTag', (tester) async {
    // 1. Valid percent-encoded UTF-8 tag
    const encodedTag = '%E5%8A%A8%E4%BD%9C'; // '动作'

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController()),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(
              key: ValueKey('encoded_tag'),
              inputTag: encodedTag,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tag:动作'), findsWidgets);

    // 2. Truly malformed URI sequence that causes Uri.decodeComponent to throw
    const malformedTag = '%zz_invalid';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _FakeSearchPageController()),
        ],
        child: TranslationProvider(
          child: const MaterialApp(
            home: SearchPage(
              key: ValueKey('malformed_tag'),
              inputTag: malformedTag,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tag:$malformedTag'), findsWidgets);
  });
}
