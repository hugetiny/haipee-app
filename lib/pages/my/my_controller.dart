import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kazumi/providers/translations_provider.dart';

part 'my_controller.freezed.dart';

@freezed
class CollectState with _$CollectState {
  const factory CollectState({
    @Default([]) List<CollectedBangumi> collectibles,
    @Default(false) bool syncing,
  }) = _CollectState;
}

class CollectController extends Notifier<CollectState> {
  static const Set<int> _visibleTypes = {1, 2, 4};

  @override
  CollectState build() {
    return CollectState(
      collectibles: _filteredCollectibles(),
    );
  }

  Box get setting => GStorage.setting;
  List<BangumiItem> get favorites => GStorage.favorites.values.toList();

  List<CollectedBangumi> _filteredCollectibles() {
    return GStorage.collectibles.values
        .whereType<CollectedBangumi>()
        .where((item) => _visibleTypes.contains(item.type))
        .toList();
  }

  void loadCollectibles() {
    state = state.copyWith(
      collectibles: _filteredCollectibles(),
    );
  }

  int getCollectType(BangumiItem bangumiItem) {
    final collectedBangumi = GStorage.collectibles.get(bangumiItem.id);
    if (collectedBangumi == null) {
      return 0;
    }
    return _visibleTypes.contains(collectedBangumi.type)
        ? collectedBangumi.type
        : 0;
  }

  Future<void> addCollect(BangumiItem bangumiItem, {int type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    final collectedBangumi =
        CollectedBangumi(bangumiItem, DateTime.now(), type);
    await GStorage.collectibles.put(bangumiItem.id, collectedBangumi);
    await GStorage.collectibles.flush();
    final collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final collectChange = CollectedBangumiChange(
      collectChangeId,
      bangumiItem.id,
      1,
      type,
      (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    await GStorage.collectChanges.put(collectChangeId, collectChange);
    await GStorage.collectChanges.flush();
    loadCollectibles();
  }

  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    await GStorage.collectibles.delete(bangumiItem.id);
    await GStorage.collectibles.flush();
    final collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final collectChange = CollectedBangumiChange(
      collectChangeId,
      bangumiItem.id,
      3,
      5,
      (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    await GStorage.collectChanges.put(collectChangeId, collectChange);
    await GStorage.collectChanges.flush();
    loadCollectibles();
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    final collectedBangumi = GStorage.collectibles.get(bangumiItem.id);
    if (collectedBangumi == null) return;
    collectedBangumi.bangumiItem = bangumiItem;
    await GStorage.collectibles.put(bangumiItem.id, collectedBangumi);
    await GStorage.collectibles.flush();
    loadCollectibles();
  }

  Future<void> syncCollectibles() async {
    final translations = ref.read(translationsProvider);
    final webDavToast = translations.settings.webdav.toast;
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: webDavToast.notConfigured);
      return;
    }
    state = state.copyWith(syncing: true);
    var ok = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().log(Level.error, 'WebDav连接失败: $e');
      KazumiDialog.showToast(
        message:
            webDavToast.connectionFailed.replaceFirst('{error}', e.toString()),
      );
      ok = false;
    }
    if (ok) {
      try {
        await WebDav().syncCollectibles();
      } catch (e) {
        KazumiDialog.showToast(
          message: webDavToast.syncFailed.replaceFirst('{error}', e.toString()),
        );
      }
      loadCollectibles();
    }
    state = state.copyWith(syncing: false);
  }

  Future<void> migrateCollect() async {
    if (favorites.isEmpty) return;
    int count = 0;
    for (final item in favorites) {
      await addCollect(item, type: 1);
      count++;
    }
    await GStorage.favorites.clear();
    await GStorage.favorites.flush();
    KazumiLogger().log(Level.debug, '检测到$count条未分类记录, 已迁移');
  }
}
