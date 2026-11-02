import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/search/search_history_module.dart';
import 'package:haipee/utils/storage.dart';

class SearchHistoryNotifier extends Notifier<List<SearchHistory>> {
  @override
  List<SearchHistory> build() {
    return _loadHistories();
  }

  List<SearchHistory> _loadHistories() {
    try {
      final box = GStorage.searchHistory;
      if (!box.isOpen) return const [];
      final list = box.values.toList().cast<SearchHistory>()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return List<SearchHistory>.unmodifiable(list);
    } catch (_) {
      return const [];
    }
  }

  Future<void> addHistory(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    try {
      final bool privateMode =
          await GStorage.setting.get(SettingBoxKey.privateMode, defaultValue: false);
      if (privateMode) return;

      final box = GStorage.searchHistory;
      if (!box.isOpen) return;

      // Deduplicate existing entry with the same keyword
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final val = box.get(key);
        if (val is SearchHistory && val.keyword.trim().toLowerCase() == clean.toLowerCase()) {
          keysToDelete.add(key);
        }
      }
      for (final k in keysToDelete) {
        await box.delete(k);
      }

      // Max 25 entries
      if (box.length >= 25 && state.isNotEmpty) {
        await box.delete(state.last.key);
      }

      int timestamp = DateTime.now().millisecondsSinceEpoch;
      while (box.containsKey(timestamp.toString())) {
        timestamp++;
      }
      await box.put(timestamp.toString(), SearchHistory(clean, timestamp));
      state = _loadHistories();
    } catch (_) {}
  }

  Future<void> deleteHistory(SearchHistory item) async {
    try {
      final box = GStorage.searchHistory;
      await box.delete(item.key);
      if (box.containsKey(item.key)) {
        final fallbackKey = box.keys.firstWhere(
          (k) {
            final val = box.get(k);
            return val is SearchHistory && val.timestamp == item.timestamp;
          },
          orElse: () => null,
        );
        if (fallbackKey != null) {
          await box.delete(fallbackKey);
        }
      }
      state = _loadHistories();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final box = GStorage.searchHistory;
      await box.clear();
      state = const [];
    } catch (_) {}
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<SearchHistory>>(
  SearchHistoryNotifier.new,
);
