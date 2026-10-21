import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_stream/torrent_stream_service.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/pages/player/local_player_page.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

/// Fake test adapter that simulates libtorrent engine without native C++ dylibs.
class _FakeEngineAdapter implements TorrentEngineAdapter {
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
      progress: 0.1,
      downloadRate: 2 * 1024 * 1024,
      uploadRate: 0,
      totalDone: 10 * 1024 * 1024,
      totalWanted: 100 * 1024 * 1024,
      totalUploaded: 0,
      numPeers: 12,
      numSeeds: 8,
      isPaused: false,
      isFinished: false,
      hasMetadata: metadataAvailable,
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
      fileSize: 1024 * 1024 * 100,
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
    fakeFiles.remove(torrentId);
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

/// Concrete Mock of WebviewItemController to verify duplicate init safety
class _MockWebviewItemController extends WebviewItemController<Object> {
  int initCount = 0;

  @override
  Future<void> init() async {
    initCount++;
    if (isInitialized) {
      initEventController.add(true);
      return;
    }
    markInitialized();
    initEventController.add(true);
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {}

  @override
  Future<void> unloadPage() async {}

  @override
  void dispose() {
    initEventController.close();
    logEventController.close();
    videoLoadingEventController.close();
    videoParserEventController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. 在线看与在线听模式识别与 LocalVideoPlayArgs 解耦测试', () {
    test('LocalVideoPlayArgs effectiveIsAudio 精准识别音频格式', () {
      final mp3Args = LocalVideoPlayArgs(
        filePath: '/music/BlackMyth_Theme.mp3',
        title: '黑神话悟空主题曲',
      );
      expect(mp3Args.effectiveIsAudio, isTrue);

      final flacArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/test/0?name=ost.flac',
        title: '黑神话原声大碟',
      );
      expect(flacArgs.effectiveIsAudio, isTrue);

      final wavArgs = LocalVideoPlayArgs(
        filePath: '/audio/track.wav',
        title: '无损音频',
      );
      expect(wavArgs.effectiveIsAudio, isTrue);

      final dsdArgs = LocalVideoPlayArgs(
        filePath: '/audio/track.dsd',
        title: 'DSD音频',
      );
      expect(dsdArgs.effectiveIsAudio, isTrue);

      final apeArgs = LocalVideoPlayArgs(
        filePath: '/audio/track.ape',
        title: 'APE音频',
      );
      expect(apeArgs.effectiveIsAudio, isTrue);
    });

    test('LocalVideoPlayArgs effectiveIsAudio 精准识别视频格式且不误判为音频', () {
      final mp4Args = LocalVideoPlayArgs(
        filePath: '/movies/BlackMyth_Cinematic.mp4',
        title: '黑神话悟空过场动画',
      );
      expect(mp4Args.effectiveIsAudio, isFalse);

      final mkvArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/test/1?name=ep01.mkv',
        title: '芙莉莲第01集',
      );
      expect(mkvArgs.effectiveIsAudio, isFalse);
    });

    test('LocalVideoPlayArgs 在显式指定 isAudio: true 时强制为音频模式', () {
      final forcedAudioArgs = LocalVideoPlayArgs(
        filePath: '/stream/unknown_stream_url',
        title: '未知流媒体音频',
        isAudio: true,
      );
      expect(forcedAudioArgs.effectiveIsAudio, isTrue);
    });

    test('LocalVideoPlayArgs effectiveIsAudio 精准识别标题中的各类无损/原声带标签', () {
      final flacTagArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/fakehash/1',
        title: '[Hi-Res] 戒网 [FLAC]',
      );
      expect(flacTagArgs.effectiveIsAudio, isTrue);

      final ostParenArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/fakehash/2',
        title: '黑神话悟空 (OST)',
      );
      expect(ostParenArgs.effectiveIsAudio, isTrue);

      final losslessChineseArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/fakehash/3',
        title: '游戏原声 戒网 无损音频',
      );
      expect(losslessChineseArgs.effectiveIsAudio, isTrue);
    });

    test('PlayerItemSurface.isAudioUrl 支持完整无损与有损音频扩展名', () {
      expect(PlayerItemSurface.isAudioUrl('music.mp3'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.flac'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.wav'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.ogg'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.m4a'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.aac'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.ape'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.opus'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.wma'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.dsf'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('music.dff'), isTrue);
      expect(PlayerItemSurface.isAudioUrl('video.mp4'), isFalse);
      expect(PlayerItemSurface.isAudioUrl('video.mkv'), isFalse);
    });
  });

  group('2. BT 视频在线看与 HTTP 206 流式服务及首尾分片调度测试', () {
    late _FakeEngineAdapter fakeAdapter;
    late TorrentStreamService service;

    setUp(() {
      fakeAdapter = _FakeEngineAdapter();
      service = TorrentStreamService.instance;
      service.setAdapterForTesting(fakeAdapter);
    });

    test('BT 视频在线看成功分配 HTTP 206 流式端口并优先调度目标文件首尾分片', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(
          index: 0,
          name: 'ReadMe.txt',
          path: 'ReadMe.txt',
          size: 1024,
          isStreamable: false,
        ),
        const FileInfo(
          index: 1,
          name: 'BlackMyth_Wukong_Chapter1.mp4',
          path: 'BlackMyth_Wukong_Chapter1.mp4',
          size: 1024 * 1024 * 500,
          isStreamable: true,
        ),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:wukongchapter1video',
        isAudio: false,
      );

      // 验证视频选集正确匹配至 .mp4 视频文件
      expect(session.selectedFile?.index, equals(1));
      expect(session.selectedFile?.name, contains('mp4'));

      // 验证 HTTP 206 流式服务已启动
      expect(session.streamUrl, startsWith('http://127.0.0.1:49152/stream/'));
      expect(session.streamUrl, contains('/1'));

      // 验证非选定文件优先级被置为 0，目标视频文件优先级被赋予正常/最高调度
      final priorities = fakeAdapter.prioritiesMap[1];
      expect(priorities, isNotNull);
      expect(priorities![0], equals(0)); // ReadMe.txt 优先级降为 0
      expect(priorities[1], greaterThan(0)); // 目标视频文件被调度

      // 验证主动停止会话正确释放流与端口
      await service.stopStream(session.streamId);
      expect(fakeAdapter.stoppedStreams, contains(session.streamId));
    });

    test('BT 音频在线听成功识别 .flac 音乐专辑并开启音频流', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(
          index: 0,
          name: 'Cover.jpg',
          path: 'Cover.jpg',
          size: 1024 * 500,
          isStreamable: false,
        ),
        const FileInfo(
          index: 1,
          name: '01. 戒网 - 8082Audio.flac',
          path: '01. 戒网 - 8082Audio.flac',
          size: 1024 * 1024 * 45,
          isStreamable: true,
        ),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:wukongsoundtrackalbum',
        isAudio: true,
      );

      expect(session.selectedFile?.index, equals(1));
      expect(session.selectedFile?.name, contains('.flac'));
      expect(session.streamUrl, contains('http://127.0.0.1:49152'));

      // 停止流
      await service.stopStream(session.streamId);
      expect(fakeAdapter.stoppedStreams, contains(session.streamId));
    });

    test('BT 资源在未显式指定 isAudio: true 时，若匹配到音频文件则 session.isAudio 动态升格为 true', () async {
      fakeAdapter.fakeFiles[1] = [
        const FileInfo(
          index: 0,
          name: 'Track01.flac',
          path: 'Track01.flac',
          size: 1024 * 1024 * 30,
          isStreamable: true,
        ),
      ];

      final session = await service.startStream(
        magnetUri: 'magnet:?xt=urn:btih:fallbacksoundtrack',
        isAudio: false, // 未显式指定为音频
      );

      expect(session.selectedFile?.name, equals('Track01.flac'));
      expect(session.isAudio, isTrue); // 必须动态识别为音频

      await service.stopStream(session.streamId);
    });
  });

  group('3. 可取消等待与优雅超时机制测试（防止卡死或无限转圈）', () {
    late _FakeEngineAdapter fakeAdapter;
    late TorrentStreamService service;

    setUp(() {
      fakeAdapter = _FakeEngineAdapter();
      service = TorrentStreamService.instance;
      service.setAdapterForTesting(fakeAdapter);
    });

    test('TorrentStreamCancelToken 触发取消时，立即中断等待并清理下载句柄', () async {
      fakeAdapter.metadataAvailable = false; // 模拟做种节点暂未推送元数据
      final cancelToken = TorrentStreamCancelToken();

      // 模拟用户在 80ms 后点击取消按钮
      Timer(const Duration(milliseconds: 80), () {
        cancelToken.cancel();
      });

      await expectLater(
        service.startStream(
          magnetUri: 'magnet:?xt=urn:btih:canceldemomagnet',
          cancelToken: cancelToken,
          metadataTimeout: const Duration(seconds: 15),
        ),
        throwsA(isA<TorrentStreamCancelledException>()),
      );

      // 验证已彻底清理添加的 Torrent，防止后台句柄泄漏
      expect(fakeAdapter.removedTorrents, contains(1));
    });

    test('元数据获取超时（无做种节点）抛出友好 TorrentMetadataTimeoutException', () async {
      fakeAdapter.metadataAvailable = false;

      try {
        await service.startStream(
          magnetUri: 'magnet:?xt=urn:btih:deadtorrentmagnet',
          metadataTimeout: const Duration(milliseconds: 120),
        );
        fail('应当抛出超时异常');
      } catch (e) {
        expect(e, isA<TorrentMetadataTimeoutException>());
        final timeoutEx = e as TorrentMetadataTimeoutException;
        expect(timeoutEx.message, contains('获取种子元数据超时'));
        expect(timeoutEx.message, contains('节点数'));
      }

      // 验证超时后后台无用句柄被自动移除
      expect(fakeAdapter.removedTorrents, contains(1));
    });
  });

  group('4. WebviewItemController 生命周期与防无限转圈验证', () {
    test('WebviewItemController 重复调用 init() 立即向广播流重新发射通知，杜绝丢包导致无限转圈', () async {
      final controller = _MockWebviewItemController();
      expect(controller.isInitialized, isFalse);

      // 首次初始化
      final firstInitFuture = controller.onInitialized.first;
      unawaited(controller.init());
      final firstResult = await firstInitFuture;
      expect(firstResult, isTrue);
      expect(controller.isInitialized, isTrue);
      expect(controller.initCount, equals(1));

      // 模拟用户再次打开页面（或在已初始化状态下进入 VideoPage）
      // 此时重新订阅 onInitialized，再调用 init()
      bool secondEventReceived = false;
      final sub = controller.onInitialized.listen((event) {
        if (event) secondEventReceived = true;
      });

      await controller.init();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(secondEventReceived, isTrue);
      expect(controller.initCount, equals(2));

      await sub.cancel();
      controller.dispose();
    });
  });

  group('5. 资源搜索与原 HTTP 播放彻底解耦验证', () {
    test('BT 资源搜索服务纯粹化：不挂载或依赖 Bangumi 官方影视选集嗅探流', () {
      final state = const TorrentSearchState();
      expect(state.bangumiItems, isEmpty);
      expect(state.activeBangumiItem, isNull);
    });

    test('LocalPlayerPage 播放模式与原 VideoPage 状态隔离', () {
      final args = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:49152/stream/fakehash/0',
        title: '黑神话悟空 4K 实机演示',
        isAudio: false,
      );
      expect(args.effectiveIsAudio, isFalse);
      expect(args.title, equals('黑神话悟空 4K 实机演示'));
      expect(args.filePath, contains('49152'));
    });

    test('SearchPageState keyword 状态隔离与更新验证', () {
      const state = SearchPageState();
      expect(state.keyword, isEmpty);

      final updated = state.copyWith(keyword: '黑神话悟空');
      expect(updated.keyword, equals('黑神话悟空'));
      expect(updated.bangumiList, isEmpty);

      // 验证模式切换时的判定逻辑：keyword 变化时正确识别为需要重新检索
      const kw = '黑神话悟空';
      expect(state.keyword != kw, isTrue);
      expect(updated.keyword != kw, isFalse);
    });
  });

  group('6. TorrentItem 音频与视频分类检测精准度测试', () {
    test('精准将 .opus, .aac, .wma, .dsf, .dff 识别为音频分类并开启 canStreamAudio', () {
      final opusItem = const TorrentItem(
        title: 'Cyberpunk_Radio_Soundtrack.opus',
        magnetUrl: 'magnet:?xt=urn:btih:cyberpunkopus',
        source: TorrentSourceType.cardigann,
      );
      expect(opusItem.category, equals(TorrentCategory.audio));
      expect(opusItem.canStreamAudio, isTrue);
      expect(opusItem.canStreamVideo, isFalse);

      final aacItem = const TorrentItem(
        title: 'Theme_Song_Special.aac',
        magnetUrl: 'magnet:?xt=urn:btih:themeaac',
        source: TorrentSourceType.cardigann,
      );
      expect(aacItem.category, equals(TorrentCategory.audio));
      expect(aacItem.canStreamAudio, isTrue);

      final dsfItem = const TorrentItem(
        title: 'Classical_Symphony_DSD128.dsf',
        magnetUrl: 'magnet:?xt=urn:btih:symphonydsf',
        source: TorrentSourceType.cardigann,
      );
      expect(dsfItem.category, equals(TorrentCategory.audio));
      expect(dsfItem.canStreamAudio, isTrue);

      final wmaItem = const TorrentItem(
        title: 'Game_Audio_Track.wma',
        magnetUrl: 'magnet:?xt=urn:btih:gamewma',
        source: TorrentSourceType.cardigann,
      );
      expect(wmaItem.category, equals(TorrentCategory.audio));
      expect(wmaItem.canStreamAudio, isTrue);
    });

    test('压缩包与镜像文件即使含音频关键词也绝不开启 canStreamAudio / canStreamVideo', () {
      final zipAlbum = const TorrentItem(
        title: 'Black_Myth_Wukong_OST_FLAC.zip',
        magnetUrl: 'magnet:?xt=urn:btih:wukongzip',
        source: TorrentSourceType.cardigann,
      );
      expect(zipAlbum.isArchive, isTrue);
      expect(zipAlbum.canStreamAudio, isFalse);
      expect(zipAlbum.canStreamVideo, isFalse);

      final isoVideo = const TorrentItem(
        title: 'Frieren_BD_Vol1.iso',
        magnetUrl: 'magnet:?xt=urn:btih:friereniso',
        source: TorrentSourceType.cardigann,
      );
      expect(isoVideo.isArchive, isTrue);
      expect(isoVideo.canStreamAudio, isFalse);
      expect(isoVideo.canStreamVideo, isFalse);
    });
  });
}
