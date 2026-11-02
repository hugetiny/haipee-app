import 'dart:io';
import 'package:flutter/gestures.dart';
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
import 'package:haipee/modules/search/search_history_dropdown.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/modules/search/search_history_provider.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/pages/resource/resource_search_page.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';

class _FakeNotifier extends SearchHistoryNotifier {
  final List<SearchHistory> initial;
  _FakeNotifier([this.initial = const []]);

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

class _MockPluginsController extends PluginsController {
  @override
  PluginsState build() => PluginsState(pluginList: []);

  @override
  bool isPluginEnabled(String name) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dropdown_click_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(BangumiItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HistoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CollectedBangumiAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ProgressAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(BangumiTagAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SearchHistoryAdapter());
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

  testWidgets('Mouse pointer click on history item selects and fills keyword', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    String clickedKeyword = '';

    final notifier = _FakeNotifier([
      SearchHistory('葬送的芙莉莲', 1000),
      SearchHistory('间谍过家家', 2000),
      SearchHistory('孤独摇滚', 3000),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SearchHistoryDropdown(
                  controller: controller,
                  focusNode: focusNode,
                  onSelectKeyword: (kw) {
                    clickedKeyword = kw;
                  },
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

    // 1. Focus the text field
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    expect(find.text('间谍过家家'), findsOneWidget);
    expect(find.text('孤独摇滚'), findsOneWidget);

    // 2. Click on single item delete button using real mouse pointer
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final deleteFinder = find.byTooltip('删除此记录');
    expect(deleteFinder, findsWidgets);

    final firstDeleteTarget = tester.getCenter(deleteFinder.first);
    await gesture.addPointer(location: firstDeleteTarget);
    await gesture.down(firstDeleteTarget);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify first item was deleted and overlay is still showing
    expect(find.text('葬送的芙莉莲'), findsNothing);
    expect(find.text('间谍过家家'), findsOneWidget);
    expect(find.text('孤独摇滚'), findsOneWidget);

    // 3. Click on history item using real mouse pointer
    final itemTarget = tester.getCenter(find.text('间谍过家家'));
    await gesture.moveTo(itemTarget);
    await gesture.down(itemTarget);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(clickedKeyword, '间谍过家家');
    expect(controller.text, '间谍过家家');
    expect(find.byType(ListTile), findsNothing); // overlay dismissed after selection

    // 4. Re-focus and test clear all with real mouse pointer
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('清空全部'), findsOneWidget);
    final clearTarget = tester.getCenter(find.text('清空全部'));
    await gesture.moveTo(clearTarget);
    await gesture.down(clearTarget);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('暂无搜索历史记录'), findsOneWidget);
  });

  testWidgets('OnlineVideoSearchPage: clicking dropdown history triggers search', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _FakeNotifier([
      SearchHistory('进击的巨人', 1000),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryProvider.overrideWith(() => notifier),
          pluginsProvider.overrideWith(() => _MockPluginsController()),
        ],
        child: const MaterialApp(
          home: OnlineVideoSearchPage(initialPopularVideos: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the search TextField
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final itemFinder = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('进击的巨人'),
    );
    expect(itemFinder, findsOneWidget);

    // Click history item
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final target = tester.getCenter(itemFinder);
    await gesture.addPointer(location: target);
    await gesture.down(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify search was initiated: text in TextField is updated and dropdown is dismissed
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '进击的巨人');
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('ResourceSearchPage: clicking dropdown history triggers torrent search', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _FakeNotifier([
      SearchHistory('死神千年血战篇', 1000),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchHistoryProvider.overrideWith(() => notifier),
          popularProvider.overrideWith(() => _MockPopularController()),
        ],
        child: const MaterialApp(
          home: ResourceSearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap search textfield
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final itemFinder = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('死神千年血战篇'),
    );
    expect(itemFinder, findsOneWidget);

    // Click history item
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final target = tester.getCenter(itemFinder);
    await gesture.addPointer(location: target);
    await gesture.down(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify search was initiated
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '死神千年血战篇');
    expect(find.byType(ListTile), findsNothing);
  });
}
