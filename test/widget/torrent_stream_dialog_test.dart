import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/modules/torrent_stream/widgets/torrent_stream_dialog.dart';

class _FakeDialogEngineAdapter implements TorrentEngineAdapter {
  bool initialized = false;
  final Map<int, TorrentInfo> fakeTorrents = {};
  final Map<int, List<FileInfo>> fakeFiles = {};
  final Map<int, StreamInfo> fakeStreams = {};

  @override
  bool get isInitialized => initialized;

  @override
  String get libraryVersion => '2.1.1-test';

  @override
  Future<void> init({
    String? defaultSavePath,
    bool fetchTrackers = true,
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    initialized = true;
  }

  @override
  int addMagnet(String magnetUri, {String? savePath, bool streamOnly = false}) {
    final id = fakeTorrents.length + 1;
    fakeTorrents[id] = TorrentInfo(
      id: id,
      name: 'Test Stream Video',
      savePath: savePath ?? '/tmp',
      errorMsg: '',
      state: TorrentState.downloading,
      progress: 0.1,
      downloadRate: 1024 * 1024 * 2,
      uploadRate: 0,
      totalDone: 1024 * 1024 * 10,
      totalWanted: 1024 * 1024 * 100,
      totalUploaded: 0,
      numPeers: 15,
      numSeeds: 10,
      isPaused: false,
      isFinished: false,
      hasMetadata: true,
      queuePosition: 0,
    );
    return id;
  }

  @override
  TorrentInfo? getTorrentInfo(int torrentId) => fakeTorrents[torrentId];

  @override
  StreamInfo? getStreamInfo(int streamId) => fakeStreams[streamId];

  @override
  List<FileInfo> getFiles(int torrentId) => fakeFiles[torrentId] ?? [];

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {}

  @override
  StreamInfo startStream(int torrentId, {int fileIndex = -1, int maxCacheBytes = 0}) {
    const streamId = 200;
    final info = StreamInfo(
      id: streamId,
      torrentId: torrentId,
      fileIndex: 0,
      url: 'http://127.0.0.1:49152/stream/fakehash/0',
      fileSize: 1024 * 1024 * 200,
      readHead: 0,
      streamState: StreamState.ready,
      bufferSeconds: 15.0,
      bufferPieces: 12,
      readaheadWindow: 20,
      activePeers: 12,
      downloadRate: 1024 * 1024 * 3,
    );
    fakeStreams[streamId] = info;
    return info;
  }

  @override
  void stopStream(int streamId) {}

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {}

  @override
  bool preloadStream(int streamId, {int preloadBytes = 0}) => true;

  @override
  void configureSession(BtConfig config) {}

  @override
  Stream<Map<int, TorrentInfo>> get torrentUpdates => const Stream.empty();

  @override
  Stream<Map<int, StreamInfo>> get streamUpdates => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDialogEngineAdapter fakeAdapter;

  setUp(() {
    fakeAdapter = _FakeDialogEngineAdapter();
    TorrentStreamService.instance.setAdapterForTesting(fakeAdapter);
  });

  tearDown(() async {
    await TorrentStreamService.instance.stopAll();
    TorrentStreamService.instance.resetAdapter();
  });

  const testItem = TorrentItem(
    title: '[Test-Raws] Sample Animation Episode 01 [1080p].mp4',
    magnetUrl: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
    source: TorrentSourceType.mikan,
    customCategory: TorrentCategory.video,
    sizeBytes: 1024 * 1024 * 500,
  );

  testWidgets('TorrentStreamDialog mounts and displays title, badges and actions', (tester) async {
    fakeAdapter.fakeFiles[1] = [
      const FileInfo(
        index: 0,
        name: 'Sample Animation 01.mp4',
        path: 'Sample Animation 01.mp4',
        size: 1024 * 1024 * 500,
        isStreamable: true,
      ),
    ];

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TorrentStreamDialog(
              item: testItem,
            ),
          ),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify title, dynamic engine badge, and action buttons
    expect(find.text('在线边下边播'), findsOneWidget);
    expect(find.text('原生 Libtorrent'), findsOneWidget);
    expect(find.textContaining('Sample Animation'), findsWidgets);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('后台下载'), findsOneWidget);

    // Let microtasks and postFrameCallback run
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('TorrentStreamDialog cancel button dismisses dialog', (tester) async {
    fakeAdapter.fakeFiles[1] = [
      const FileInfo(
        index: 0,
        name: 'Sample Animation 01.mp4',
        path: 'Sample Animation 01.mp4',
        size: 1024 * 1024 * 500,
        isStreamable: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => const TorrentStreamDialog(item: testItem),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TorrentStreamDialog), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(TorrentStreamDialog), findsNothing);
  });
}
