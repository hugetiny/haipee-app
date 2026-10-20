import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:kazumi/modules/torrent_stream/aria2_stream_engine.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/utils/aria2_client.dart';

class MockFailingTorrentEngineAdapter implements TorrentEngineAdapter {
  @override
  bool get isInitialized => true;

  @override
  String get libraryVersion => '2.1.0-mock';

  @override
  Future<void> init({
    String? defaultSavePath,
    bool fetchTrackers = true,
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {}

  @override
  int addMagnet(String magnetUri, {String? savePath, bool streamOnly = false}) {
    return 999;
  }

  @override
  TorrentInfo? getTorrentInfo(int torrentId) {
    // Simulate zero peers / no metadata (inducing timeout)
    return TorrentInfo(
      id: torrentId,
      name: 'Hung Torrent',
      savePath: '/tmp',
      errorMsg: '',
      state: TorrentState.downloading,
      progress: 0.0,
      downloadRate: 0,
      uploadRate: 0,
      totalDone: 0,
      totalWanted: 1000,
      totalUploaded: 0,
      numPeers: 0,
      numSeeds: 0,
      isPaused: false,
      isFinished: false,
      hasMetadata: false,
      queuePosition: 0,
    );
  }

  @override
  StreamInfo? getStreamInfo(int streamId) => null;

  @override
  List<FileInfo> getFiles(int torrentId) => [];

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {}

  @override
  StreamInfo startStream(int torrentId, {int fileIndex = -1, int maxCacheBytes = 0}) {
    throw UnimplementedError();
  }

  @override
  void stopStream(int streamId) {}

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {}

  @override
  bool preloadStream(int streamId, {int preloadBytes = 0}) => false;

  @override
  void configureSession(BtConfig config) {}

  @override
  Stream<Map<int, TorrentInfo>> get torrentUpdates => const Stream.empty();

  @override
  Stream<Map<int, StreamInfo>> get streamUpdates => const Stream.empty();
}

class FakeDualAria2Client extends Aria2Client {
  FakeDualAria2Client({required this.targetFilePath})
      : super(endpoint: Uri.parse('http://127.0.0.1:6800/jsonrpc'));

  final String targetFilePath;

  @override
  Future<String?> addUri(
    List<String> uris, {
    Map<String, dynamic>? options,
    int? position,
  }) async {
    return 'gid-fallback-1';
  }

  @override
  Future<Map<String, dynamic>?> tellStatus(
    String gid, {
    List<String>? keys,
  }) async {
    return {
      'gid': gid,
      'status': 'active',
      'totalLength': (1024 * 1024 * 50).toString(),
      'completedLength': (1024 * 1024 * 5).toString(),
      'downloadSpeed': (1024 * 1024 * 3).toString(),
      'numSeeders': '25',
      'connections': '30',
      'files': [
        {
          'index': '1',
          'path': targetFilePath,
          'length': (1024 * 1024 * 50).toString(),
          'completedLength': (1024 * 1024 * 5).toString(),
          'selected': 'true',
        },
      ],
    };
  }

  @override
  Future<bool> changeOption(String gid, Map<String, dynamic> options) async => true;

  @override
  Future<bool> remove(String gid, {bool force = false}) async => true;
}

void main() {
  group('Dual-Engine TorrentStreamService Tests', () {
    late Directory tempDir;
    late File dummyFile;
    late FakeDualAria2Client fakeAria2;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dual_engine_test_');
      dummyFile = File('${tempDir.path}/Frieren_01.mkv');
      await dummyFile.writeAsBytes(List<int>.generate(1024 * 64, (i) => i % 256));

      fakeAria2 = FakeDualAria2Client(targetFilePath: dummyFile.path);
      Aria2StreamEngine.instance.setClientForTesting(fakeAria2);
    });

    tearDown(() async {
      await TorrentStreamService.instance.stopAll();
      Aria2StreamEngine.instance.setClientForTesting(null);
      TorrentStreamService.instance.resetAdapter();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('startStream with TorrentStreamEngine.aria2 uses Aria2 directly', () async {
      final session = await TorrentStreamService.instance.startStream(
        magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        title: 'Frieren 01',
        engine: TorrentStreamEngine.aria2,
        waitForBuffer: true,
      );

      expect(session.engine, equals(TorrentStreamEngine.aria2));
      expect(session.streamId, greaterThanOrEqualTo(80000));
      expect(session.streamUrl, startsWith('http://127.0.0.1:'));
      expect(session.selectedFile?.name, contains('Frieren_01.mkv'));
    });

    test('startStream with auto mode seamlessly falls back to Aria2 when native engine hangs/fails', () async {
      // Inject failing adapter that has 0 peers and times out
      TorrentStreamService.instance.setAdapterForTesting(MockFailingTorrentEngineAdapter());

      final progressList = <TorrentStreamProgress>[];

      final session = await TorrentStreamService.instance.startStream(
        magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        title: 'Frieren Fallback Test',
        engine: TorrentStreamEngine.auto,
        metadataTimeout: const Duration(milliseconds: 600), // Fast timeout for test
        waitForBuffer: true,
        onProgressUpdate: (p) => progressList.add(p),
      );

      // Verify that session was fulfilled by Aria2 without failing!
      expect(session.engine, equals(TorrentStreamEngine.aria2));
      expect(session.streamId, greaterThanOrEqualTo(80000));
      expect(session.streamUrl, startsWith('http://127.0.0.1:'));

      // Verify fallback progress was broadcasted
      expect(progressList.any((p) => p.engine == TorrentStreamEngine.aria2), isTrue);
    });

    test('resolveMagnetFiles falls back to Aria2 when native adapter has no metadata', () async {
      TorrentStreamService.instance.setAdapterForTesting(MockFailingTorrentEngineAdapter());

      final entries = await TorrentStreamService.instance.resolveMagnetFiles(
        'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        metadataTimeout: const Duration(milliseconds: 600),
        engine: TorrentStreamEngine.auto,
      );

      expect(entries.length, equals(1));
      expect(entries.first.name, contains('Frieren_01.mkv'));
    });

    test('stopStream cleanly routes to Aria2StreamEngine for IDs >= 80000 and cleans up files', () async {
      final session = await TorrentStreamService.instance.startStream(
        magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        engine: TorrentStreamEngine.aria2,
        waitForBuffer: true,
      );

      expect(session.streamId, greaterThanOrEqualTo(80000));
      expect(dummyFile.existsSync(), isTrue);

      await TorrentStreamService.instance.stopStream(session.streamId, deleteFiles: true);
      expect(dummyFile.existsSync(), isFalse);
    });

    test('stopAll cleans up dual engine streams', () async {
      final session = await TorrentStreamService.instance.startStream(
        magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        engine: TorrentStreamEngine.aria2,
        waitForBuffer: true,
      );

      expect(session.streamId, greaterThanOrEqualTo(80000));
      await TorrentStreamService.instance.stopAll(deleteFiles: true);
      expect(dummyFile.existsSync(), isFalse);
    });
  });
}
