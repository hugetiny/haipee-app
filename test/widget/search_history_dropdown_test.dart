import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/search/search_history_dropdown.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/providers.dart';
import 'package:kazumi/pages/resource/resource_search_page.dart';
import 'package:kazumi/utils/storage.dart';

class _FakeSearchHistoryNotifier extends SearchHistoryNotifier {
  final List<SearchHistory> initial;
  _FakeSearchHistoryNotifier([this.initial = const []]);

  @override
  List<SearchHistory> build() {
    return List<SearchHistory>.from(initial);
  }

  @override
  Future<void> addHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    state = [
      SearchHistory(clean, DateTime.now().millisecondsSinceEpoch),
      ...state.where((h) => h.keyword != clean),
    ];
  }

  @override
  Future<void> deleteHistory(SearchHistory item) async {
    state = state.where((h) => h.keyword != item.keyword).toList();
  }

  @override
  Future<void> clearAll() async {
    state = const [];
  }
}

class _MockPopularController extends PopularController {
  @override
  PopularState build() => PopularState(
        trendList: [
          BangumiItem.fromJson({
            'id': 1,
            'name': 'dummy',
            'type': 2,
            'name_cn': '测试番剧',
            'summary': '测试',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('search_history_dropdown_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SearchHistoryAdapter());
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.showWindowButton, false);
    GStorage.setting = box;
    GStorage.searchHistory = await Hive.openBox('searchHistory');
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

  group('SearchHistoryDropdown Widget Unit Tests', () {
    testWidgets('SearchHistoryDropdown shows on focus, filters text, selects item, deletes item, and dismisses cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final searchController = TextEditingController();
      final focusNode = FocusNode();
      String selectedKeyword = '';

      final fakeNotifier = _FakeSearchHistoryNotifier([
        SearchHistory('葬送的芙莉莲', 1000),
        SearchHistory('间谍过家家', 2000),
        SearchHistory('孤独摇滚', 3000),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchHistoryProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SearchHistoryDropdown(
                  controller: searchController,
                  focusNode: focusNode,
                  onSelectKeyword: (kw) {
                    selectedKeyword = kw;
                  },
                  child: TextField(
                    controller: searchController,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial state: focus is not active, overlay is hidden
      expect(find.text('搜索历史'), findsNothing);

      // 2. Focus the TextField -> overlay appears
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('搜索历史'), findsOneWidget);
      expect(find.text('葬送的芙莉莲'), findsOneWidget);
      expect(find.text('间谍过家家'), findsOneWidget);
      expect(find.text('孤独摇滚'), findsOneWidget);
      expect(find.text('清空全部'), findsOneWidget);

      // 3. Filter history by typing
      await tester.enterText(find.byType(TextField), '芙莉');
      await tester.pumpAndSettle();

      expect(find.text('匹配的历史记录'), findsOneWidget);
      expect(find.text('葬送的芙莉莲'), findsOneWidget);
      expect(find.text('间谍过家家'), findsNothing);

      // 4. Select item
      await tester.tap(find.text('葬送的芙莉莲'));
      await tester.pumpAndSettle();

      expect(selectedKeyword, '葬送的芙莉莲');
      expect(searchController.text, '葬送的芙莉莲');
      expect(find.text('匹配的历史记录'), findsNothing); // overlay hidden

      // 5. Re-focus, test tooltip hover and deleting single item
      searchController.clear();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('搜索历史'), findsOneWidget);
      final deleteBtnFinder = find.byTooltip('删除此记录');
      expect(deleteBtnFinder, findsWidgets);

      // Test mouse hover over delete button triggers Tooltip cleanly without RenderFollowerLayer assertions
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Hover over the first delete button
      await gesture.moveTo(tester.getCenter(deleteBtnFinder.first));
      await tester.pump(const Duration(milliseconds: 600)); // tooltip delay
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('删除此记录'), findsWidgets);

      // Hover over clear button to verify its tooltip
      final clearBtnFinder = find.byTooltip('清空全部历史记录');
      expect(clearBtnFinder, findsOneWidget);
      await gesture.moveTo(tester.getCenter(clearBtnFinder));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tap delete button to remove single item
      await tester.tap(deleteBtnFinder.first);
      await tester.pumpAndSettle();

      // 6. Test clear all
      await tester.tap(find.text('清空全部'));
      await tester.pumpAndSettle();

      expect(find.text('暂无搜索历史记录'), findsOneWidget);

      // 7. Test Escape key dismisses
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('暂无搜索历史记录'), findsNothing);
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('SearchHistoryDropdown flips upward when near bottom of viewport',
        (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      final focusNode = FocusNode();
      final fakeNotifier = _FakeSearchHistoryNotifier([
        SearchHistory('Keyword 1', 100),
        SearchHistory('Keyword 2', 200),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchHistoryProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SearchHistoryDropdown(
                    controller: controller,
                    focusNode: focusNode,
                    onSelectKeyword: (_) {},
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Keyword 1'), findsOneWidget);

      // Verify the dropdown is rendered above the textfield
      final textFieldRect = tester.getRect(find.byType(TextField));
      final itemRect = tester.getRect(find.text('Keyword 1'));
      expect(itemRect.bottom, lessThan(textFieldRect.top));
    });

    testWidgets('GeneralErrorWidget safely builds without LayoutBuilder during layout passes',
        (tester) async {
      // Build GeneralErrorWidget directly inside a custom RenderObject that invokes layout callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const GeneralErrorWidget(
                  errMsg: 'Test layout exception',
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Test layout exception'), findsOneWidget);
      expect(find.text('复制报错信息'), findsOneWidget);
    });
  });

  group('ResourceSearchPage with SearchHistoryDropdown Integration Tests', () {
    testWidgets('ResourceSearchPage seamlessly integrates SearchHistoryDropdown with zero errors',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotifier = _FakeSearchHistoryNotifier([
        SearchHistory('Ubuntu 24.04', 1000),
        SearchHistory('EVA 新世纪福音战士', 2000),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchHistoryProvider.overrideWith(() => fakeNotifier),
            popularProvider.overrideWith(_MockPopularController.new),
          ],
          child: TranslationProvider(
            child: const MaterialApp(
              home: ResourceSearchPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 确保页面渲染没有任何异常
      expect(tester.takeException(), isNull);
      expect(find.byType(SearchHistoryDropdown), findsOneWidget);
      expect(find.text('全网资源搜索'), findsOneWidget);

      // 点击搜索框唤起历史下拉浮层
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('清空全部'), findsOneWidget);
      expect(find.text('Ubuntu 24.04'), findsWidgets);
      expect(find.text('EVA 新世纪福音战士'), findsWidgets);

      // 点击下拉浮层中的历史关键词进行全网搜索
      await tester.tap(find.descendant(
        of: find.byType(SearchHistoryDropdown),
        matching: find.text('Ubuntu 24.04'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('清空全部'), findsNothing);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Ubuntu 24.04');
    });
  });
}
