import 'package:kazumi/utils/storage.dart';

class PluginStatsHelper {
  static const int _maxHistory = 3;

  // --- Sniffing Latency (Video URL Parsing) ---

  static Future<void> recordSniffingLatency(String pluginName, int latency) async {
    final key = '${pluginName}_sniffing_latency';
    final history = GStorage.pluginStats.get(key) ?? [];
    final newHistory = List<dynamic>.from(history);

    newHistory.add(latency);
    if (newHistory.length > _maxHistory) {
      newHistory.removeRange(0, newHistory.length - _maxHistory);
    }

    await GStorage.pluginStats.put(key, newHistory);
  }

  static int getDisplaySniffingLatency(String pluginName) {
    final key = '${pluginName}_sniffing_latency';
    final history = GStorage.pluginStats.get(key);
    if (history == null || history is! List || history.isEmpty) {
      return 0;
    }

    final latencies = history.cast<int>().toList();
    latencies.sort();

    if (latencies.length < 3) {
      final sum = latencies.reduce((int a, int b) => a + b);
      return (sum / latencies.length).round();
    }
    return latencies[latencies.length ~/ 2];
  }

  // --- Quality (Resolution, Codec, Bitrate) ---

  /// Records quality info and returns true if the info was updated (improved or new details added)
  static Future<bool> updateQualityInfo(String pluginName, {required int height, String? codec, double? bitrate}) async {
    if (height <= 0) return false;
    final key = '${pluginName}_max_quality';
    final current = GStorage.pluginStats.get(key);

    bool shouldUpdate = false;

    if (current == null) {
      shouldUpdate = true;
    } else {
      final currentHeight = current['height'] as int? ?? 0;
      // Update if resolution is higher
      if (height > currentHeight) {
        shouldUpdate = true;
      }
      // Update if resolution is same but we have more details now
      else if (height == currentHeight) {
        final currentCodec = current['codec'] as String?;
        final currentBitrate = current['bitrate'] as double?;

        // If we didn't have codec before but have it now
        if (currentCodec == null && codec != null) shouldUpdate = true;
        // If we didn't have bitrate before but have it now
        if (currentBitrate == null && bitrate != null) shouldUpdate = true;
        // If bitrate is higher (better quality usually)
        if (bitrate != null && currentBitrate != null && bitrate > currentBitrate) shouldUpdate = true;
      }
    }

    if (shouldUpdate) {
      await GStorage.pluginStats.put(key, {
        'height': height,
        'codec': codec,
        'bitrate': bitrate,
      });
      return true;
    }
    return false;
  }

  static Map<String, dynamic>? getMaxQuality(String pluginName) {
    final key = '${pluginName}_max_quality';
    final data = GStorage.pluginStats.get(key);
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    // Fallback for old data (int height)
    final oldKey = '${pluginName}_max_resolution';
    final oldHeight = GStorage.pluginStats.get(oldKey);
    if (oldHeight is int && oldHeight > 0) {
      return {'height': oldHeight, 'codec': null, 'bitrate': null};
    }
    return null;
  }

  static String getQualityLabel(Map<String, dynamic>? quality) {
    if (quality == null) return '未知画质';
    final height = quality['height'] as int? ?? 0;
    final codec = quality['codec'] as String?;
    final bitrate = quality['bitrate'] as double?;

    final parts = <String>[];

    // Resolution
    if (height >= 2160) parts.add('4K');
    else if (height >= 1440) parts.add('2K');
    else if (height >= 1080) parts.add('1080P');
    else if (height >= 720) parts.add('720P');
    else if (height > 0) parts.add('${height}P');
    else parts.add('未知分辨率');

    // Codec
    if (codec != null) {
      if (codec.toLowerCase().contains('av1')) parts.add('AV1');
      else if (codec.toLowerCase().contains('hevc') || codec.toLowerCase().contains('h265')) parts.add('HEVC');
      else if (codec.toLowerCase().contains('avc') || codec.toLowerCase().contains('h264')) parts.add('H.264');
      else parts.add(codec.toUpperCase());
    }

    // Bitrate
    if (bitrate != null && bitrate > 0) {
      final mbps = bitrate / 1000000.0;
      if (mbps >= 0.1) {
        parts.add('${mbps.toStringAsFixed(1)}Mbps');
      }
    }

    return parts.join(' • ');
  }

  // --- Sniffing Failures ---

  static Future<void> recordSniffingFailure(String pluginName) async {
    final key = '${pluginName}_sniffing_failures';
    final current = GStorage.pluginStats.get(key) ?? 0;
    await GStorage.pluginStats.put(key, current + 1);
  }

  static int getSniffingFailureCount(String pluginName) {
    final key = '${pluginName}_sniffing_failures';
    return GStorage.pluginStats.get(key) ?? 0;
  }

  static Future<void> clearAll() async {
    await GStorage.pluginStats.clear();
  }
}
