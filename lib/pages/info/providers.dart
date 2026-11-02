import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/pages/info/info_controller.dart';
import 'package:haipee/modules/comments/comment_item.dart';
import 'package:haipee/modules/characters/character_item.dart';
import 'package:haipee/modules/staff/staff_item.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';

// ✅ 导出 Info 页面 UI 状态管理
export 'package:haipee/pages/info/info_ui_state.dart';

/// 番剧详情页 Provider
///
/// 管理番剧详细信息、评论、角色、制作人员和元数据。
/// 支持从 Bangumi、TMDB 等源获取和合并元数据。
///
/// 示例:
/// ```dart
/// final controller = ref.read(bangumiInfoProvider.notifier);
/// await controller.queryBangumiInfoByID(12345);
/// ```
final bangumiInfoProvider =
    NotifierProvider<InfoController, InfoState>(InfoController.new);

// ✅ Bangumi Comments Provider (支持分页)
class BangumiCommentsNotifier
    extends AsyncNotifier<List<CommentItem>> {
  BangumiCommentsNotifier(this.arg);
  final (int, int) arg;

  @override
  Future<List<CommentItem>> build() async {
    final (bangumiId, offset) = arg;
    if (bangumiId <= 0) return <CommentItem>[];

    try {
      final result = await BangumiHTTP.getBangumiCommentsByID(
        bangumiId,
        offset: offset,
      );
      HaipeeLogger().log(Level.info, '已加载评论列表长度 ${result.commentList.length}');
      return result.commentList;
    } catch (error, stackTrace) {
      HaipeeLogger().log(
        Level.error,
        '加载评论失败: $error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Refresh comments
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final bangumiCommentsProvider = AsyncNotifierProvider.family<
    BangumiCommentsNotifier, List<CommentItem>, (int, int)>(
  (arg) => BangumiCommentsNotifier(arg),
);

// ✅ Bangumi Characters Provider
class BangumiCharactersNotifier
    extends AsyncNotifier<List<CharacterItem>> {
  BangumiCharactersNotifier(this.bangumiId);
  final int bangumiId;

  @override
  Future<List<CharacterItem>> build() async {
    if (bangumiId <= 0) return <CharacterItem>[];
    try {
      final result = await BangumiHTTP.getCharatersByBangumiID(bangumiId);
      final characters = result.charactersList;
      const relationValue = {'主角': 1, '配角': 2, '客串': 3};

      try {
        characters.sort((a, b) {
          final valueA = relationValue[a.relation] ?? 4;
          final valueB = relationValue[b.relation] ?? 4;
          return valueA.compareTo(valueB);
        });
      } catch (e) {
        HaipeeDialog.showToast(
          message: t.library.info.toast.characterSortFailed.replaceFirst(
            '{details}',
            e.toString(),
          ),
        );
      }

      HaipeeLogger().log(Level.info, '已加载角色列表长度 ${characters.length}');
      return characters;
    } catch (error, stackTrace) {
      HaipeeLogger().log(
        Level.error,
        '加载角色列表失败: $error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Refresh characters
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final bangumiCharactersProvider = AsyncNotifierProvider.family<
    BangumiCharactersNotifier, List<CharacterItem>, int>(
  (bangumiId) => BangumiCharactersNotifier(bangumiId),
);

// ✅ Bangumi Staff Provider
class BangumiStaffsNotifier
    extends AsyncNotifier<List<StaffFullItem>> {
  BangumiStaffsNotifier(this.bangumiId);
  final int bangumiId;

  @override
  Future<List<StaffFullItem>> build() async {
    if (bangumiId <= 0) return <StaffFullItem>[];
    try {
      final result = await BangumiHTTP.getBangumiStaffByID(bangumiId);
      final staff = result.data;
      HaipeeLogger().log(Level.info, '已加载制作人员列表长度 ${staff.length}');
      return staff;
    } catch (error, stackTrace) {
      HaipeeLogger().log(
        Level.error,
        '加载制作人员列表失败: $error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Refresh staff
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final bangumiStaffsProvider = AsyncNotifierProvider.family<
    BangumiStaffsNotifier, List<StaffFullItem>, int>(
  (bangumiId) => BangumiStaffsNotifier(bangumiId),
);
