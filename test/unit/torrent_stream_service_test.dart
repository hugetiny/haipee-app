import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';

/// Fake test adapter that simulates libtorrent engine without native C++ dylibs.
class FakeTorrentEngineAdapter implements TorrentEngineAdapter {
  bool initialized = false;
  final Map<int, TorrentInfo> fakeTorrents = {};
  final Map<int, List<FileInfo>> fakeFiles = {};
  final Map<int, List<int>> prioritiesMap = {};
  final Map<int, StreamInfo> fakeStreams = {};
  final List<int> stoppedStreams = [];
  final List<int> removedTorrents = [];
  int nextStreamId = 100;
  bool metadataAvailable = true;

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
      name: 'Test Torrent $id',
      savePath: savePath ?? '/tmp',
      errorMsg: '',
      state: TorrentState.downloading,
      progress: 0.0,
      downloadRate: 1024 * 1024,
      uploadRate: 0,
      totalDone: 0,
      totalWanted: 1000,
      totalUploaded: 0,
      numPeers: 5,
      numSeeds: 3,
      isPaused: false,
      isFinished: false,
      hasMetadata: metadataAvailable,
      queuePosition: 0,
    );
    return id;
  }

  @override
  TorrentInfo? getTorrentInfo(int torrentId) {
    return fakeTorrents[torrentId];
  }

  @override
  StreamInfo? getStreamInfo(int streamId) {
    return fakeStreams[streamId];
  }

  @override
  List<FileInfo> getFiles(int torrentId) {
    return fakeFiles[torrentId] ?? [];
  }

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {
    prioritiesMap[torrentId] = List.from(priorities);
  }

  @override
  StreamInfo startStream(int torrentId, {int fileIndex = -1, int maxCacheBytes = 0}) {
    final streamId = nextStreamId++;
    final info = StreamInfo(
      id: streamId,
      torrentId: torrentId,
      fileIndex: fileIndex,
      url: 'http://127.0.0.1:49152/stream/fakehash/$fileIndex',
      fileSize: 1024 * 1024 * 50,
      readHead: 0,
      streamState: StreamState.ready,
      bufferSeconds: 12.5,
      bufferPieces: 10,
      readaheadWindow: 20,
      activePeers: 6,
      downloadRate: 2048 * 1024,
    );
    fakeStreams[streamId] = info;
    return info;
  }

  @override
  void stopStream(int streamId) {
    stoppedStreams.add(streamId);
    fakeStreams.remove(streamId);
  }

  @override
  void removeTorrent(int torrentId, {bool deleteFiles = false}) {
    removedTorrents.add(torrentId);
    fakeTorrents.remove(torrentId);
  }

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

  group('TorrentStreamService File & Tracker Tests', () {
    test('isAudioFile accurately identifies audio extensions', () {
      expect(TorrentStreamService.isAudioFile('track.mp3'), isTrue);
      expect(TorrentStreamService.isAudioFile('music.FLAC'), isTrue);
      expect(TorrentStreamService.isAudioFile('album/song.wav'), isTrue);
      expect(TorrentStreamService.isAudioFile('audio.m4a'), isTrue);
      expect(TorrentStreamService.isAudioFile('audio.opus'), isTrue);
      expect(TorrentStreamService.isAudioFile('audio.ogg'), isTrue);
      expect(TorrentStreamService.isAudioFile('movie.mp4'), isFalse);
      expect(TorrentStreamService.isAudioFile('movie.mkv'), isFalse);
      expect(TorrentStreamService.isAudioFile('game.iso'), isFalse);
      expect(TorrentStreamService.isAudioFile('setup.exe'), isFalse);
    });

    test('isVideoFile accurately identifies video extensions', () {
      expect(TorrentStreamService.isVideoFile('episode.mp4'), isTrue);
      expect(TorrentStreamService.isVideoFile('anime.MKV'), isTrue);
      expect(TorrentStreamService.isVideoFile('film.avi'), isTrue);
      expect(TorrentStreamService.isVideoFile('video.webm'), isTrue);
      expect(TorrentStreamService.isVideoFile('clip.ts'), isTrue);
      expect(TorrentStreamService.isVideoFile('track.flac'), isFalse);
      expect(TorrentStreamService.isVideoFile('archive.rar'), isFalse);
    });

    test('isArchiveFile accurately identifies archive extensions', () {
      expect(TorrentStreamService.isArchiveFile('album.zip'), isTrue);
      expect(TorrentStreamService.isArchiveFile('disc.RAR'), isTrue);
      expect(TorrentStreamService.isArchiveFile('files.7z'), isTrue);
      expect(TorrentStreamService.isArchiveFile('backup.tar.gz'), isTrue);
      expect(TorrentStreamService.isArchiveFile('image.iso'), isTrue);
      expect(TorrentStreamService.isArchiveFile('video.mp4'), isFalse);
      expect(TorrentStreamService.isArchiveFile('track.flac'), isFalse);
    });

    test('isPlayableFile excludes archive files and non-media', () {
      expect(TorrentStreamService.isPlayableFile('video.mp4'), isTrue);
      expect(TorrentStreamService.isPlayableFile('song.flac'), isTrue);
      expect(TorrentStreamService.isPlayableFile('audio.zip'), isFalse);
      expect(TorrentStreamService.isPlayableFile('movie.rar'), isFalse);
      expect(TorrentStreamService.isPlayableFile('readme.txt'), isFalse);
    });

    test('naturalCompare accurately handles track numbering (1, 2, 10)', () {
      final tracks = [
        '10. Track Ten.flac',
        '2. Track Two.flac',
        '1. Track One.flac',
        '05. Track Five.flac',
      ];
      tracks.sort(TorrentStreamService.naturalCompare);

      expect(tracks, [
        '1. Track One.flac',
        '2. Track Two.flac',
        '05. Track Five.flac',
        '10. Track Ten.flac',
      ]);
    });

    test('injectTrackers enriches magnet URIs with high-performance trackers', () {
      const baseMagnet = 'magnet:?xt=urn:btih:d1234567890abcdef1234567890abcdef1234567';
      final enriched = TorrentStreamService.injectTrackers(baseMagnet);

      expect(enriched, contains('tr='));
      expect(enriched, contains('tracker.opentrackr.org'));
      expect(enriched, contains('open.demonii.com'));
    });
  });

  group('TorrentStreamService Streaming Orchestration Tests', () {
    late FakeTorrentEngineAdapter fakeAdapter;
    late TorrentStreamService service;

    setUp(() {
      fakeAdapter = FakeTorrentEngineAdapter();
      service = TorrentStreamService.instance;
      service.setAdapterForTesting(fakeAdapter);
    });

    tearDown(() async {
      await service.stopAll();
      service.resetAdapter();
    });

    test('startStream for audio album naturally selects Track 01 and prioritizes it', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Cover.jpg', path: 'Cover.jpg', size: 1024 * 500, isStreamable: false),
        const FileInfo(index: 1, name: '10. Finale.flac', path: '10. Finale.flac', size: 1024 * 1024 * 30, isStreamable: true),
        const FileInfo(index: 2, name: '01. Overture.flac', path: '01. Overture.flac', size: 1024 * 1024 * 20, isStreamable: true),
        const FileInfo(index: 3, name: '02. Allegro.flac', path: '02. Allegro.flac', size: 1024 * 1024 * 25, isStreamable: true),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:fakeaudiomagnet',
        title: 'Mozart Album',
        isAudio: true,
      );

      expect(session.streamId, 100);
      expect(session.isAudio, isTrue);
      expect(session.selectedFile?.name, '01. Overture.flac');
      expect(session.selectedFile?.index, 2);
      expect(session.streamUrl, contains('/stream/fakehash/2'));

      // Verify Track 01 (index 2) was given priority 7 and non-selected files priority 0
      final priorities = fakeAdapter.prioritiesMap[1];
      expect(priorities, isNotNull);
      expect(priorities![2], 7);
      expect(priorities[0], 0);
      expect(priorities[1], 0);
      expect(priorities[3], 0);
    });

    test('startStream for video selects largest video file ignoring sample clips', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Sample.mkv', path: 'Sample.mkv', size: 1024 * 1024 * 15, isStreamable: true),
        const FileInfo(index: 1, name: 'Movie.2024.1080p.mkv', path: 'Movie.2024.1080p.mkv', size: 1024 * 1024 * 1024 * 3, isStreamable: true),
        const FileInfo(index: 2, name: 'Subtitles.srt', path: 'Subtitles.srt', size: 1024 * 80, isStreamable: false),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:fakevideomagnet',
        title: 'Movie 2024',
        isAudio: false,
      );

      expect(session.isAudio, isFalse);
      expect(session.selectedFile?.name, 'Movie.2024.1080p.mkv');
      expect(session.selectedFile?.index, 1);
      expect(session.streamUrl, contains('/stream/fakehash/1'));

      final priorities = fakeAdapter.prioritiesMap[1];
      expect(priorities, isNotNull);
      expect(priorities![1], 7);
      expect(priorities[0], 0);
      expect(priorities[2], 0);
    });

    test('startStream with explicit fileIndex respects requested index', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Track01.mp3', path: 'Track01.mp3', size: 1024 * 1024 * 5, isStreamable: true),
        const FileInfo(index: 1, name: 'Track02.mp3', path: 'Track02.mp3', size: 1024 * 1024 * 5, isStreamable: true),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:fakeaudiomagnet',
        fileIndex: 1,
        isAudio: true,
      );

      expect(session.selectedFile?.index, 1);
      expect(session.selectedFile?.name, 'Track02.mp3');
    });

    test('startStream throws TorrentMetadataTimeoutException when metadata is unavailable', () async {
      fakeAdapter.metadataAvailable = false;

      expect(
        () => service.startStream(
          magnetUri: 'magnet:?xt=urn:btih:deadmagnet',
          metadataTimeout: const Duration(milliseconds: 700),
        ),
        throwsA(isA<TorrentMetadataTimeoutException>()),
      );
    });

    test('startStream throws NoStreamableFileException when torrent contains only archives', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Album_FLAC.zip', path: 'Album_FLAC.zip', size: 1024 * 1024 * 300, isStreamable: false),
        const FileInfo(index: 1, name: 'Scans.rar', path: 'Scans.rar', size: 1024 * 1024 * 50, isStreamable: false),
      ];

      await expectLater(
        service.startStream(
          magnetUri: 'magnet:?xt=urn:btih:fakearchivemagnet',
          isAudio: true,
        ),
        throwsA(isA<NoStreamableFileException>()),
      );

      // Verify the torrent is removed to prevent dangling background sessions
      expect(fakeAdapter.removedTorrents, contains(1));
    });

    test('startStream ignores archive files and streams actual playable media', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Scans_Booklet.zip', path: 'Scans_Booklet.zip', size: 1024 * 1024 * 80, isStreamable: false),
        const FileInfo(index: 1, name: '01. Intro.flac', path: '01. Intro.flac', size: 1024 * 1024 * 25, isStreamable: true),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:mixedarchivemagnet',
        isAudio: true,
      );

      expect(session.selectedFile?.name, '01. Intro.flac');
      expect(session.selectedFile?.index, 1);
    });

    test('startStream respects cancelToken and aborts immediately', () async {
      fakeAdapter.metadataAvailable = false; // keep polling

      final cancelToken = TorrentStreamCancelToken();
      // Cancel after 100ms
      Future.delayed(const Duration(milliseconds: 100), () {
        cancelToken.cancel();
      });

      await expectLater(
        service.startStream(
          magnetUri: 'magnet:?xt=urn:btih:canceltestmagnet',
          cancelToken: cancelToken,
          metadataTimeout: const Duration(seconds: 10),
        ),
        throwsA(isA<TorrentStreamCancelledException>()),
      );

      // Verify the torrent was cleanly removed
      expect(fakeAdapter.removedTorrents, contains(1));
    });

    test('resolveMagnetFiles respects cancelToken and aborts immediately', () async {
      fakeAdapter.metadataAvailable = false;

      final cancelToken = TorrentStreamCancelToken();
      Future.delayed(const Duration(milliseconds: 100), () {
        cancelToken.cancel();
      });

      await expectLater(
        service.resolveMagnetFiles(
          'magnet:?xt=urn:btih:canceltestmagnet2',
          cancelToken: cancelToken,
          metadataTimeout: const Duration(seconds: 10),
        ),
        throwsA(isA<TorrentStreamCancelledException>()),
      );

      expect(fakeAdapter.removedTorrents, contains(1));
    });

    test('TorrentStreamProgress formattedSpeed formats KB/s and MB/s correctly', () {
      const pZero = TorrentStreamProgress(
        stage: TorrentStreamStage.connectingPeers,
        message: 'testing',
        downloadRate: 0,
      );
      expect(pZero.formattedSpeed, '0 KB/s');

      const pKilo = TorrentStreamProgress(
        stage: TorrentStreamStage.buffering,
        message: 'testing',
        downloadRate: 1024 * 256,
      );
      expect(pKilo.formattedSpeed, '256 KB/s');

      const pMega = TorrentStreamProgress(
        stage: TorrentStreamStage.buffering,
        message: 'testing',
        downloadRate: 1024 * 1024 * 2 + 1024 * 512,
      );
      expect(pMega.formattedSpeed, '2.5 MB/s');
    });

    test('startStream emits rich TorrentStreamProgress through lifecycle', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(index: 0, name: 'Video.mp4', path: 'Video.mp4', size: 1024 * 1024 * 100, isStreamable: true),
      ];

      final recorded = <TorrentStreamProgress>[];
      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:progresstestmagnet',
        isAudio: false,
        waitForBuffer: true,
        onProgressUpdate: (p) {
          recorded.add(p);
        },
      );

      expect(session.selectedFile?.name, 'Video.mp4');
      expect(recorded.isNotEmpty, isTrue);

      // Verify progress includes connecting/allocating and ready stages
      expect(recorded.any((p) => p.stage == TorrentStreamStage.connectingPeers || p.stage == TorrentStreamStage.resolvingMetadata), isTrue);
      expect(recorded.any((p) => p.stage == TorrentStreamStage.allocating), isTrue);
      expect(recorded.any((p) => p.stage == TorrentStreamStage.ready), isTrue);

      // Verify getStreamInfo retrieval
      final sInfo = service.getStreamInfo(session.streamId);
      expect(sInfo, isNotNull);
      expect(sInfo?.streamState, StreamState.ready);
    });
  });
}
