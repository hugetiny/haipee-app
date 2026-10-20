import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_search_history_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(SearchHistoryAdapter().typeId)) {
      Hive.registerAdapter(SearchHistoryAdapter());
    }
    GStorage.searchHistory = await Hive.openBox<SearchHistory>('test_search_history');
    GStorage.setting = await Hive.openBox('test_search_setting');
  });

  tearDownAll(() async {
    await GStorage.searchHistory.close();
    await GStorage.setting.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await GStorage.searchHistory.clear();
    await GStorage.setting.clear();
  });

  test('SearchHistoryNotifier adds, deduplicates, and orders histories correctly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(searchHistoryProvider.notifier);

    // Initial state is empty
    expect(container.read(searchHistoryProvider), isEmpty);

    // Add first search
    await notifier.addHistory('Ubuntu 24.04');
    expect(container.read(searchHistoryProvider).length, 1);
    expect(container.read(searchHistoryProvider).first.keyword, 'Ubuntu 24.04');

    // Add second search
    await notifier.addHistory('Arch Linux');
    expect(container.read(searchHistoryProvider).length, 2);
    expect(container.read(searchHistoryProvider).first.keyword, 'Arch Linux');

    // Deduplicate case-insensitively and bring to top
    await notifier.addHistory('ubuntu 24.04');
    final list = container.read(searchHistoryProvider);
    expect(list.length, 2);
    expect(list.first.keyword, 'ubuntu 24.04');

    // Delete single item
    await notifier.deleteHistory(list.first);
    expect(container.read(searchHistoryProvider).length, 1);
    expect(container.read(searchHistoryProvider).first.keyword, 'Arch Linux');

    // Clear all
    await notifier.clearAll();
    expect(container.read(searchHistoryProvider), isEmpty);
  });

  test('SearchHistoryNotifier ignores adding when private mode is enabled', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await GStorage.setting.put(SettingBoxKey.privateMode, true);

    final notifier = container.read(searchHistoryProvider.notifier);
    await notifier.addHistory('Secret Keyword');

    expect(container.read(searchHistoryProvider), isEmpty);
  });
}
