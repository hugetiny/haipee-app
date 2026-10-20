import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/source_quality/source_quality_tracker.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('source_quality_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
    Hive.init(tempDir.path);
    GStorage.playbackProfiles = await Hive.openBox('playbackProfiles');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('SourceQualityRecord Tests', () {
    test('Resolution label resolution heuristics', () {
      final rec4k = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'mutefun',
        src: '/play/1',
        width: 3840,
        height: 2160,
        lastUpdated: DateTime.now(),
      );
      expect(rec4k.resolutionLabel, '4K');

      final rec1080 = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'mutefun',
        src: '/play/1',
        width: 1920,
        height: 1080,
        lastUpdated: DateTime.now(),
      );
      expect(rec1080.resolutionLabel, '1080P');

      final rec720 = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'dalvdm',
        src: '/play/2',
        width: 1280,
        height: 720,
        lastUpdated: DateTime.now(),
      );
      expect(rec720.resolutionLabel, '720P');

      final rec480 = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'anime7',
        src: '/play/3',
        width: 854,
        height: 480,
        lastUpdated: DateTime.now(),
      );
      expect(rec480.resolutionLabel, '480P');
    });

    test('Bitrate formatting in Mbps and kbps', () {
      final highBitrate = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'mutefun',
        src: '/play/1',
        width: 1920,
        height: 1080,
        videoBitrate: 2850000.0, // 2.85 Mbps
        lastUpdated: DateTime.now(),
      );
      expect(highBitrate.bitrateLabel, '2.9 Mbps');
      expect(highBitrate.badgeLabel, '1080P · 2.9 Mbps');

      final lowBitrate = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'DM84',
        src: '/play/2',
        width: 1280,
        height: 720,
        demuxBitrate: 750000.0, // 750 kbps
        lastUpdated: DateTime.now(),
      );
      expect(lowBitrate.bitrateLabel, '750 kbps');
      expect(lowBitrate.badgeLabel, '720P · 750 kbps');
    });

    test('Detailed label incorporates codec, dimensions and fps', () {
      final record = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'mutefun',
        src: '/play/1',
        width: 1920,
        height: 1080,
        videoBitrate: 3200000.0,
        codec: 'h264',
        fps: 60.0,
        lastUpdated: DateTime.now(),
      );
      final detailed = record.detailedLabel;
      expect(detailed, contains('1080P'));
      expect(detailed, contains('1920×1080'));
      expect(detailed, contains('3.2 Mbps'));
      expect(detailed, contains('H264'));
      expect(detailed, contains('60fps'));
    });

    test('Quality score correctly ranks higher resolution and bitrate higher', () {
      final r1080pHighBitrate = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'srcA',
        src: '/a',
        width: 1920,
        height: 1080,
        videoBitrate: 4500000.0,
        lastUpdated: DateTime.now(),
      );

      final r1080pLowBitrate = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'srcB',
        src: '/b',
        width: 1920,
        height: 1080,
        videoBitrate: 1500000.0,
        lastUpdated: DateTime.now(),
      );

      final r720p = SourceQualityRecord(
        bangumiId: 101,
        pluginName: 'srcC',
        src: '/c',
        width: 1280,
        height: 720,
        videoBitrate: 2000000.0,
        lastUpdated: DateTime.now(),
      );

      expect(r1080pHighBitrate.qualityScore > r1080pLowBitrate.qualityScore, isTrue);
      expect(r1080pLowBitrate.qualityScore > r720p.qualityScore, isTrue);
    });

    test('JSON serialization and deserialization roundtrip', () {
      final original = SourceQualityRecord(
        bangumiId: 999,
        pluginName: 'dalvdm',
        src: 'https://sbdl.cc/detail/1',
        width: 1920,
        height: 1080,
        videoBitrate: 2400000.0,
        demuxBitrate: 2600000.0,
        codec: 'hevc',
        fps: 24.0,
        lastUpdated: DateTime.parse('2026-10-18T12:00:00.000Z'),
      );

      final json = original.toJson();
      final revived = SourceQualityRecord.fromJson(json);

      expect(revived.bangumiId, original.bangumiId);
      expect(revived.pluginName, original.pluginName);
      expect(revived.src, original.src);
      expect(revived.width, original.width);
      expect(revived.height, original.height);
      expect(revived.videoBitrate, original.videoBitrate);
      expect(revived.demuxBitrate, original.demuxBitrate);
      expect(revived.codec, original.codec);
      expect(revived.fps, original.fps);
      expect(revived.badgeLabel, original.badgeLabel);
    });
  });

  group('SourceQualityTracker Persistence & Retrieval Tests', () {
    test('recordQuality stores and retrieves exact match', () async {
      await SourceQualityTracker.recordQuality(
        bangumiId: 54321,
        pluginName: 'mutefun',
        src: 'www.2kdm.com/voddetail',
        width: 1920,
        height: 1080,
        videoBitrate: 3500000.0,
        codec: 'h264',
        fps: 30.0,
      );

      final record = SourceQualityTracker.getQualityRecord(
        bangumiId: 54321,
        pluginName: 'mutefun',
        src: 'www.2kdm.com/voddetail',
      );

      expect(record, isNotNull);
      expect(record!.width, 1920);
      expect(record.height, 1080);
      expect(record.badgeLabel, '1080P · 3.5 Mbps');
    });

    test('getBestQualityForPlugin falls back to plugin record when src differs', () async {
      await SourceQualityTracker.recordQuality(
        bangumiId: 8888,
        pluginName: 'anime7',
        src: '/vod-detail/10562/',
        width: 1280,
        height: 720,
        videoBitrate: 1200000.0,
      );

      // Exact query with different episode/query URL
      final fallback = SourceQualityTracker.getBestQualityForPlugin(
        bangumiId: 8888,
        pluginName: 'anime7',
      );

      expect(fallback, isNotNull);
      expect(fallback!.resolutionLabel, '720P');
      expect(fallback.bitrateLabel, '1.2 Mbps');
    });

    test('getBangumiQualityRecords returns all played sources for the subject', () async {
      await SourceQualityTracker.recordQuality(
        bangumiId: 7777,
        pluginName: 'mutefun',
        src: '/play/a',
        width: 1920,
        height: 1080,
        videoBitrate: 2500000.0,
      );
      await SourceQualityTracker.recordQuality(
        bangumiId: 7777,
        pluginName: 'DM84',
        src: '/play/b',
        width: 1280,
        height: 720,
        videoBitrate: 900000.0,
      );

      final allRecords = SourceQualityTracker.getBangumiQualityRecords(7777);
      expect(allRecords.length, 2);
      expect(allRecords['mutefun_/play/a']?.resolutionLabel, '1080P');
      expect(allRecords['DM84_/play/b']?.resolutionLabel, '720P');
    });
  });
}
