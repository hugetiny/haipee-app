import 'package:hive_ce/hive.dart';
import 'package:haipee/modules/source_quality/source_quality_record.dart';
export 'package:haipee/modules/source_quality/source_quality_record.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// 视频播放源画质追踪与持久化服务
class SourceQualityTracker {
  static const String _prefix = 'sq_';

  static Box get _box => GStorage.playbackProfiles;

  /// 记录或更新某个播放源的画质指标
  static Future<void> recordQuality({
    required int bangumiId,
    required String pluginName,
    required String src,
    required int width,
    required int height,
    double videoBitrate = 0.0,
    double demuxBitrate = 0.0,
    String codec = '',
    double fps = 0.0,
  }) async {
    if (bangumiId <= 0 || pluginName.isEmpty || src.isEmpty) return;
    if (width <= 0 && height <= 0 && videoBitrate <= 0 && demuxBitrate <= 0) return;

    try {
      final key = '$_prefix${SourceQualityRecord.buildKey(bangumiId, pluginName, src)}';
      final existing = getQualityRecord(
        bangumiId: bangumiId,
        pluginName: pluginName,
        src: src,
      );

      final finalWidth = width > 0 ? width : (existing?.width ?? 0);
      final finalHeight = height > 0 ? height : (existing?.height ?? 0);
      final finalVideoBitrate =
          videoBitrate > 0 ? videoBitrate : (existing?.videoBitrate ?? 0.0);
      final finalDemuxBitrate =
          demuxBitrate > 0 ? demuxBitrate : (existing?.demuxBitrate ?? 0.0);
      final finalCodec = codec.isNotEmpty ? codec : (existing?.codec ?? '');
      final finalFps = fps > 0 ? fps : (existing?.fps ?? 0.0);

      final record = SourceQualityRecord(
        bangumiId: bangumiId,
        pluginName: pluginName,
        src: src,
        width: finalWidth,
        height: finalHeight,
        videoBitrate: finalVideoBitrate,
        demuxBitrate: finalDemuxBitrate,
        codec: finalCodec,
        fps: finalFps,
        lastUpdated: DateTime.now(),
      );

      await _box.put(key, record.toJson());
      HaipeeLogger().log(
        Level.info,
        '已记录视频源画质: $pluginName -> ${record.detailedLabel}',
      );
    } catch (e) {
      HaipeeLogger().log(Level.warning, '记录视频画质失败: $e');
    }
  }

  /// 获取指定播放源的历史画质记录
  static SourceQualityRecord? getQualityRecord({
    required int bangumiId,
    required String pluginName,
    required String src,
  }) {
    if (bangumiId <= 0 || pluginName.isEmpty || src.isEmpty) return null;
    try {
      final key = '$_prefix${SourceQualityRecord.buildKey(bangumiId, pluginName, src)}';
      final data = _box.get(key);
      if (data is Map) {
        return SourceQualityRecord.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取该番剧下指定插件已记录的最佳画质 (作为 URL 微小差异时的兜底)
  static SourceQualityRecord? getBestQualityForPlugin({
    required int bangumiId,
    required String pluginName,
  }) {
    if (bangumiId <= 0 || pluginName.isEmpty) return null;
    try {
      SourceQualityRecord? best;
      for (final key in _box.keys) {
        if (key is String && key.startsWith('$_prefix${bangumiId}_${pluginName}_')) {
          final data = _box.get(key);
          if (data is Map) {
            final record = SourceQualityRecord.fromJson(data);
            if (best == null || record.qualityScore > best.qualityScore) {
              best = record;
            }
          }
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// 获取某个番剧下所有已播放源的画质映射表: Map<"plugin_src", SourceQualityRecord>
  static Map<String, SourceQualityRecord> getBangumiQualityRecords(int bangumiId) {
    final result = <String, SourceQualityRecord>{};
    if (bangumiId <= 0) return result;
    try {
      for (final key in _box.keys) {
        if (key is String && key.startsWith('$_prefix${bangumiId}_')) {
          final data = _box.get(key);
          if (data is Map) {
            final record = SourceQualityRecord.fromJson(data);
            result['${record.pluginName}_${record.src}'] = record;
          }
        }
      }
    } catch (_) {}
    return result;
  }
}
