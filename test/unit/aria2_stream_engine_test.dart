import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_stream/aria2_stream_engine.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/utils/aria2_client.dart';

class FakeAria2Client extends Aria2Client {
  FakeAria2Client({
    required this.targetFilePath,
    required this.targetFileSize,
  }) : super(endpoint: Uri.parse('http://127.0.0.1:6800/jsonrpc'));

  final String targetFilePath;
  final int targetFileSize;

  int tellStatusCallCount = 0;
  bool isRemoved = false;
  Map<String, dynamic>? lastOptions;
  List<String> selectedFilesChanged = [];

  @override
  Future<String?> addUri(
    List<String> uris, {
    Map<String, dynamic>? options,
    int? position,
  }) async {
    lastOptions = options;
    return 'gid-meta-100';
  }

  @override
  Future<Map<String, dynamic>?> tellStatus(
    String gid, {
    List<String>? keys,
  }) async {
    tellStatusCallCount++;
    if (gid == 'gid-meta-100') {
      // First poll indicates followedBy
      return {
        'gid': 'gid-meta-100',
        'status': 'complete',
        'followedBy': ['gid-content-200'],
      };
    }

    // gid-content-200
    return {
      'gid': 'gid-content-200',
      'status': 'active',
      'totalLength': targetFileSize.toString(),
      'completedLength': (1024 * 1024 * 3).toString(), // 3MB buffered
      'downloadSpeed': (1024 * 1024 * 2).toString(), // 2 MB/s
      'numSeeders': '18',
      'connections': '24',
      'files': [
        {
          'index': '1',
          'path': targetFilePath,
          'length': targetFileSize.toString(),
          'completedLength': (1024 * 1024 * 3).toString(),
          'selected': 'true',
        },
      ],
    };
  }

  @override
  Future<bool> changeOption(String gid, Map<String, dynamic> options) async {
    if (options.containsKey('select-file')) {
      selectedFilesChanged.add(options['select-file'].toString());
    }
    return true;
  }

  @override
  Future<bool> remove(String gid, {bool force = false}) async {
    isRemoved = true;
    return true;
  }
}

void main() {
  group('Aria2StreamEngine Tests', () {
    late Directory tempDir;
    late File dummyVideo;
    const fileSize = 1024 * 1024 * 10; // 10MB
    late FakeAria2Client fakeClient;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aria2_engine_test_');
      dummyVideo = File('${tempDir.path}/[Anime] Ep 01.mkv');
      await dummyVideo.writeAsBytes(List<int>.generate(1024 * 64, (i) => i % 256));

      fakeClient = FakeAria2Client(
        targetFilePath: dummyVideo.path,
        targetFileSize: fileSize,
      );
      Aria2StreamEngine.instance.setClientForTesting(fakeClient);
    });

    tearDown(() async {
      await Aria2StreamEngine.instance.stopAll();
      Aria2StreamEngine.instance.setClientForTesting(null);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('startStream prepares Aria2 task and returns stream session with HTTP proxy', () async {
      final progressList = <TorrentStreamProgress>[];

      final session = await Aria2StreamEngine.instance.startStream(
        magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        title: 'Test Anime',
        waitForBuffer: true,
        bufferTimeout: const Duration(seconds: 5),
        onProgressUpdate: (p) => progressList.add(p),
      );

      expect(session.streamId, greaterThanOrEqualTo(80000));
      expect(session.streamUrl, startsWith('http://127.0.0.1:'));
      expect(session.selectedFile?.name, contains('Ep 01.mkv'));
      expect(session.allFiles.length, equals(1));
      expect(session.isAudio, isFalse);

      // Verify options passed to Aria2 contain optimal piece prioritization & trackers
      expect(fakeClient.lastOptions?['bt-prioritize-piece'], equals('head=32M,tail=32M'));
      expect(fakeClient.lastOptions?['file-allocation'], equals('none'));
      expect(fakeClient.lastOptions?['enable-dht'], equals('true'));

      // Verify lifecycle stages were reported
      final stages = progressList.map((p) => p.stage).toSet();
      expect(stages, contains(TorrentStreamStage.connectingPeers));
      expect(stages, contains(TorrentStreamStage.ready));

      // Clean up session
      await Aria2StreamEngine.instance.stopStream(session.streamId);
      expect(fakeClient.isRemoved, isTrue);
    });

    test('resolveMagnetFiles parses file entries accurately via Aria2', () async {
      final entries = await Aria2StreamEngine.instance.resolveMagnetFiles(
        'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
        timeout: const Duration(seconds: 5),
      );

      expect(entries.length, equals(1));
      expect(entries.first.name, contains('Ep 01.mkv'));
      expect(entries.first.sizeBytes, equals(fileSize));
      expect(entries.first.index, equals(1));
    });

    test('User cancellation stops stream preparation immediately', () async {
      final cancelToken = TorrentStreamCancelToken();
      cancelToken.cancel();

      expect(
        () => Aria2StreamEngine.instance.startStream(
          magnetUri: 'magnet:?xt=urn:btih:da39a3ee5e6b4b0d3255bfef95601890afd80709',
          cancelToken: cancelToken,
        ),
        throwsA(isA<TorrentStreamCancelledException>()),
      );
    });
  });
}
