import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/pages/search/search_controller.dart';

/// 搜索页面 Provider
///
/// 管理番剧搜索功能和搜索历史。
/// 支持多源搜索和搜索记录管理。
///
/// 示例:
/// ```dart
/// final controller = ref.read(searchProvider.notifier);
/// await controller.search(keyword);
/// ```
final searchProvider =
    NotifierProvider<SearchPageController, SearchPageState>(
  SearchPageController.new,
);
