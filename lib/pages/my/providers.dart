import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'my_controller.dart';

/// 收藏管理 Provider
///
/// 管理番剧收藏列表、分类和同步功能。
/// 支持 WebDAV 同步和本地持久化。
///
/// 示例:
/// ```dart
/// final controller = ref.read(collectionsProvider.notifier);
/// await controller.addCollect(bangumiItem, type: 1);
/// ```
final collectionsProvider =
    NotifierProvider<CollectController, CollectState>(CollectController.new);

// ✅ Favorites page UI state providers
final favoritesShowDeleteProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final favoritesSyncingProvider =
    StateProvider.autoDispose<bool>((ref) => false);
