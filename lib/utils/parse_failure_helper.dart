import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:haipee/utils/storage.dart';

/// 解析失败记录辅助类
class ParseFailureHelper {
  /// 记录解析失败，自动持久化至本地数据库并写入统一全链路日志系统 (AppLog / haipee.log)
  static Future<void> recordFailure({
    required int bangumiId,
    required String pluginName,
    required String src,
    String? bangumiTitle,
    String? episodeTitle,
    String reason = 'timeout',
  }) async {
    try {
      final key = '${bangumiId}_${pluginName}_$src';
      final existing = GStorage.parseFailures.get(key);
      final count = existing != null ? existing.failureCount + 1 : 1;

      if (existing != null) {
        // 增加失败次数
        final updated = existing.incrementFailure(newReason: reason);
        await GStorage.parseFailures.put(key, updated);
      } else {
        // 创建新记录
        final record = ParseFailureRecord(
          bangumiId: bangumiId,
          pluginName: pluginName,
          src: src,
          failureCount: 1,
          lastFailureTime: DateTime.now(),
          reason: reason,
        );
        await GStorage.parseFailures.put(key, record);
      }

      final titleInfo = bangumiTitle != null && bangumiTitle.isNotEmpty ? ' 作品=[$bangumiTitle]' : '';
      final epInfo = episodeTitle != null && episodeTitle.isNotEmpty ? ' 选集=[$episodeTitle]' : '';
      AppLog.w(
        LogModule.stream,
        '视频资源解析失败 (第 $count 次): 规则=[$pluginName]$titleInfo$epInfo, 页面地址=[$src], 失败原因=[$reason]',
      );
    } catch (e, stack) {
      AppLog.e(LogModule.stream, '记录解析失败异常: $e', error: e, stackTrace: stack);
    }
  }

  /// 获取最近发生解析失败的记录列表 (按最近失败时间降序排列)
  static List<ParseFailureRecord> getRecentFailures({int limit = 20}) {
    try {
      final records = GStorage.parseFailures.values.toList();
      records.sort((a, b) => b.lastFailureTime.compareTo(a.lastFailureTime));
      return records.take(limit).toList();
    } catch (e) {
      AppLog.w(LogModule.stream, '获取最近解析失败记录出错: $e');
      return [];
    }
  }

  /// 获取指定番剧和插件的失败次数
  static int getFailureCount({
    required int bangumiId,
    required String pluginName,
    required String src,
  }) {
    try {
      final key = '${bangumiId}_${pluginName}_$src';
      final record = GStorage.parseFailures.get(key);
      return record?.failureCount ?? 0;
    } catch (e) {
      AppLog.e(LogModule.stream, '获取解析失败次数时出错: $e');
      return 0;
    }
  }

  /// 获取完整的失败记录对象
  static ParseFailureRecord? getFailureRecord({
    required int bangumiId,
    required String pluginName,
    required String src,
  }) {
    try {
      final key = '${bangumiId}_${pluginName}_$src';
      return GStorage.parseFailures.get(key);
    } catch (e) {
      AppLog.e(LogModule.stream, '获取解析失败记录时出错: $e');
      return null;
    }
  }

  /// 获取插件的总失败次数 (所有番剧)
  static int getPluginTotalFailures(String pluginName) {
    try {
      int total = 0;
      for (var record in GStorage.parseFailures.values) {
        if (record.pluginName == pluginName) {
          total += record.failureCount;
        }
      }
      return total;
    } catch (e) {
      AppLog.e(LogModule.stream, '获取插件总失败次数时出错: $e');
      return 0;
    }
  }

  /// 获取番剧所有源的失败记录
  static Map<String, int> getBangumiFailures(int bangumiId) {
    try {
      final Map<String, int> failures = {};
      for (var record in GStorage.parseFailures.values) {
        if (record.bangumiId == bangumiId) {
          failures[record.pluginName] = record.failureCount;
        }
      }
      return failures;
    } catch (e) {
      AppLog.e(LogModule.stream, '获取番剧失败记录时出错: $e');
      return {};
    }
  }

  /// 清理旧的失败记录 (超过30天的记录)
  static Future<void> cleanOldRecords({int daysThreshold = 30}) async {
    try {
      final threshold = DateTime.now().subtract(Duration(days: daysThreshold));
      final keysToDelete = <String>[];

      for (var entry in GStorage.parseFailures.toMap().entries) {
        if (entry.value.lastFailureTime.isBefore(threshold)) {
          keysToDelete.add(entry.key);
        }
      }

      for (var key in keysToDelete) {
        await GStorage.parseFailures.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        AppLog.i(
          LogModule.stream,
          '清理了 ${keysToDelete.length} 条旧的解析失败记录',
        );
      }
    } catch (e) {
      AppLog.e(LogModule.stream, '清理旧解析失败记录时出错: $e');
    }
  }

  /// 清除特定番剧和源的失败记录 (解析成功后调用)
  static Future<void> clearFailure({
    required int bangumiId,
    required String pluginName,
    required String src,
  }) async {
    try {
      final key = '${bangumiId}_${pluginName}_$src';
      await GStorage.parseFailures.delete(key);
      AppLog.i(LogModule.stream, '清除解析失败记录: $pluginName');
    } catch (e) {
      AppLog.e(LogModule.stream, '清除解析失败记录时出错: $e');
    }
  }
}
