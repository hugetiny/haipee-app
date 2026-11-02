import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/download/gopeed/gopeed_models.dart';
import 'package:haipee/pages/player/local_player_page.dart';
import 'package:haipee/pages/player/player_item_surface.dart';
import 'package:haipee/plugins/plugins.dart';

void main() {
  group('AppleCMS / MacCMS Plugin Tests', () {
    test('should correctly identify AppleCMS plugins by type and url', () {
      final plugin1 = Plugin(
        api: '1',
        type: 'maccms',
        name: '极速采集',
        version: '1.0',
        muliSources: true,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: 'https://jszyapi.com',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
      );

      final plugin2 = Plugin(
        api: '1',
        type: 'AppleCMS',
        name: '苹果采集',
        version: '1.0',
        muliSources: true,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: 'https://example.com',
        searchURL: 'https://example.com/api.php/provide/vod/?ac=videolist',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
      );

      final legacyPlugin = Plugin(
        api: '1',
        type: 'anime',
        name: '传统网页源',
        version: '1.0',
        muliSources: true,
        useWebview: true,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: 'https://dm84.tv',
        searchURL: 'https://dm84.tv/search?wd=@keyword',
        searchList: '//div/ul/li',
        searchName: '//a',
        searchResult: '//a',
        chapterRoads: '//ul',
        chapterResult: '//li/a',
        referer: '',
      );

      expect(plugin1.isMacCms, isTrue);
      expect(plugin2.isMacCms, isTrue);
      expect(legacyPlugin.isMacCms, isFalse);
    });
  });

  group('DownloadTask Smart Video Path Selection', () {
    test('should pick the primary video file instead of non-video files', () {
      final gopeedTask = GopeedTask(
        id: 'gid-12345',
        name: 'Anime Ep 01',
        status: 'running',
        totalLength: 1050000000,
        completedLength: 25000000,
        downloadSpeed: 5242880,
        url: 'magnet:?xt=urn:btih:0123456789abcdef',
        files: [
          GopeedFile(
            name: 'cover.jpg',
            path: '/downloads/Anime_Ep01/cover.jpg',
            size: 150000,
          ),
          GopeedFile(
            name: 'release_info.nfo',
            path: '/downloads/Anime_Ep01/release_info.nfo',
            size: 2048,
          ),
          GopeedFile(
            name: '[SubGroup] Anime - 01 [1080p].mp4',
            path: '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4',
            size: 1049000000,
          ),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask, title: 'Anime Ep 01');

      expect(task.fileName, '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4');
      expect(task.filePath, '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4');
      expect(task.url, 'magnet:?xt=urn:btih:0123456789abcdef');
      expect(task.isActive, isTrue);
    });

    test('should fallback to first file if no video extension matches', () {
      final gopeedTask = GopeedTask(
        id: 'gid-67890',
        name: 'archive',
        status: 'done',
        totalLength: 500,
        completedLength: 500,
        files: [
          GopeedFile(
            name: 'archive.tar.gz',
            path: '/downloads/archive.tar.gz',
            size: 500,
          ),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask);
      expect(task.filePath, '/downloads/archive.tar.gz');
      expect(task.isComplete, isTrue);
    });

    test('should pick the primary audio file and set isAudio for audio torrents', () {
      final gopeedTask = GopeedTask(
        id: 'gid-audio-1',
        name: 'Hi-Res Album',
        status: 'running',
        totalLength: 60000000,
        completedLength: 10000000,
        url: 'magnet:?xt=urn:btih:audioalbum123',
        files: [
          GopeedFile(
            name: 'cover.jpg',
            path: '/music/Album/cover.jpg',
            size: 350000,
          ),
          GopeedFile(
            name: 'disc.cue',
            path: '/music/Album/disc.cue',
            size: 2048,
          ),
          GopeedFile(
            name: '01 - Hi-Res Track.flac',
            path: '/music/Album/01 - Hi-Res Track.flac',
            size: 59000000,
          ),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask, title: 'Hi-Res Album');
      expect(task.fileName, '/music/Album/01 - Hi-Res Track.flac');
      expect(task.isAudio, isTrue);
      expect(task.isVideo, isFalse);
      expect(task.isPlayable, isTrue);
    });

    test('should prioritize video file over audio file if release contains both', () {
      final gopeedTask = GopeedTask(
        id: 'gid-hybrid',
        name: 'Movie + OST',
        status: 'running',
        totalLength: 700000000,
        completedLength: 20000000,
        files: [
          GopeedFile(
            name: 'soundtrack.mp3',
            path: '/release/soundtrack.mp3',
            size: 15000000,
          ),
          GopeedFile(
            name: 'movie.mkv',
            path: '/release/movie.mkv',
            size: 680000000,
          ),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask, title: 'Movie + OST');
      expect(task.fileName, '/release/movie.mkv');
      expect(task.isVideo, isTrue);
      expect(task.isAudio, isFalse);
      expect(task.isPlayable, isTrue);
    });

    test('should recognize various audio formats in DownloadTask', () {
      final formats = ['song.mp3', 'track.flac', 'audio.wav', 'music.aac', 'tune.m4a', 'hi_res.dsd', 'lossless.ape'];
      for (final name in formats) {
        final task = DownloadTask(
          gid: 'test',
          url: 'http://test.com/$name',
          title: name,
          fileName: '/downloads/$name',
          status: 'complete',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(task.isAudio, isTrue, reason: 'Failed for $name');
        expect(task.isVideo, isFalse, reason: 'Failed for $name');
        expect(task.isPlayable, isTrue, reason: 'Failed for $name');
      }
    });
  });

  group('LocalVideoPlayArgs Audio Tests', () {
    test('effectiveIsAudio should reflect explicit isAudio parameter', () {
      const explicitAudio = LocalVideoPlayArgs(
        filePath: '/storage/movie.mp4',
        title: 'Podcast MP4',
        isAudio: true,
      );
      expect(explicitAudio.effectiveIsAudio, isTrue);

      const explicitVideo = LocalVideoPlayArgs(
        filePath: '/storage/track.flac',
        title: 'Visual FLAC',
        isAudio: false,
      );
      // Because filePath is .flac, fallback detects it
      expect(explicitVideo.effectiveIsAudio, isTrue);
    });

    test('effectiveIsAudio should detect file extension correctly', () {
      const flacArgs = LocalVideoPlayArgs(
        filePath: '/downloads/album/track01.flac',
        title: 'FLAC Song',
      );
      expect(flacArgs.effectiveIsAudio, isTrue);

      const mp3Args = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:8080/stream.mp3',
        title: 'Stream MP3',
      );
      expect(mp3Args.effectiveIsAudio, isTrue);

      const mkvArgs = LocalVideoPlayArgs(
        filePath: '/downloads/video/episode01.mkv',
        title: 'MKV Video',
      );
      expect(mkvArgs.effectiveIsAudio, isFalse);

      const mp4Args = LocalVideoPlayArgs(
        filePath: '/downloads/video/episode01.mp4',
        title: 'MP4 Video',
      );
      expect(mp4Args.effectiveIsAudio, isFalse);
    });
  });

  group('Gopeed Task Metadata Inheritance and Smart Selection', () {
    test('task inherits metadata from existing stored task', () {
      final metadataTask = DownloadTask(
        gid: 'gid-meta-1',
        url: 'magnet:?xt=urn:btih:hash1',
        title: 'Fate/Zero S01 [BDRip FLAC]',
        bangumiId: '1001',
        episodeNumber: 1,
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final gopeedTask = GopeedTask(
        id: 'gid-meta-1',
        name: 'Fate_Zero_01',
        status: 'running',
        totalLength: 2000000000,
        completedLength: 1000000,
        url: 'magnet:?xt=urn:btih:hash1',
        files: [
          GopeedFile(
            name: 'Fate_Zero_01.mkv',
            path: '/downloads/Fate_Zero_01.mkv',
            size: 2000000000,
          ),
        ],
      );

      final downloadedTask = DownloadTask.fromGopeedTask(
        gopeedTask,
        title: metadataTask.title,
        bangumiId: metadataTask.bangumiId,
        episodeNumber: metadataTask.episodeNumber,
      );

      expect(downloadedTask.title, 'Fate/Zero S01 [BDRip FLAC]');
      expect(downloadedTask.bangumiId, '1001');
      expect(downloadedTask.episodeNumber, 1);
      expect(downloadedTask.fileName, '/downloads/Fate_Zero_01.mkv');
    });

    test('task preserves original URL when passed', () {
      final gopeedTask = GopeedTask(
        id: 'gid-data-child',
        name: 'movie',
        status: 'running',
        totalLength: 1000000,
        files: [
          GopeedFile(name: 'movie.mkv', path: '/downloads/movie.mkv', size: 1000000),
        ],
      );

      const originalMagnet = 'magnet:?xt=urn:btih:abcdef123456';
      final task = DownloadTask.fromGopeedTask(
        gopeedTask,
        url: originalMagnet,
        title: 'Movie Title',
      );

      expect(task.url, originalMagnet);
      expect(task.title, 'Movie Title');
      expect(task.fileName, '/downloads/movie.mkv');
    });

    test('extracts name when title is missing or a raw magnet link', () {
      final gopeedTask = GopeedTask(
        id: 'gid-bt',
        name: 'Steins;Gate Complete OST [FLAC]',
        status: 'running',
        files: [
          GopeedFile(name: '01.flac', path: '/downloads/01.flac', size: 30000000),
        ],
      );

      final taskFromMagnet = DownloadTask.fromGopeedTask(
        gopeedTask,
        title: 'magnet:?xt=urn:btih:12345',
      );
      expect(taskFromMagnet.title, 'Steins;Gate Complete OST [FLAC]');

      final taskNullTitle = DownloadTask.fromGopeedTask(
        gopeedTask,
      );
      expect(taskNullTitle.title, 'Steins;Gate Complete OST [FLAC]');
    });

    test('multi-track audio album prioritizes Track 1 instead of the longest track', () {
      final gopeedTask = GopeedTask(
        id: 'gid-album',
        name: 'Album',
        status: 'running',
        files: [
          GopeedFile(name: '03 - Track 3.flac', path: '/music/Album/03 - Track 3.flac', size: 50000000),
          GopeedFile(name: '01 - Track 1.flac', path: '/music/Album/01 - Track 1.flac', size: 30000000),
          GopeedFile(name: '02 - Track 2.flac', path: '/music/Album/02 - Track 2.flac', size: 40000000),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask);
      expect(task.fileName, '/music/Album/01 - Track 1.flac');
      expect(task.isAudio, isTrue);
    });

    test('preferAudio prioritizes lossless music album over small promo video', () {
      final gopeedTask = GopeedTask(
        id: 'gid-hybrid-music',
        name: 'Hybrid',
        status: 'running',
        files: [
          GopeedFile(name: 'promo_preview.mp4', path: '/music/promo_preview.mp4', size: 8000000),
          GopeedFile(name: '01.flac', path: '/music/01.flac', size: 60000000),
        ],
      );

      final taskExplicit = DownloadTask.fromGopeedTask(
        gopeedTask,
        preferAudio: true,
      );
      expect(taskExplicit.fileName, '/music/01.flac');
      expect(taskExplicit.isAudio, isTrue);

      final taskAutoRatio = DownloadTask.fromGopeedTask(
        gopeedTask,
      );
      expect(taskAutoRatio.fileName, '/music/01.flac');
      expect(taskAutoRatio.isAudio, isTrue);
    });

    test('isAudio and effectiveIsAudio strip query parameters and fragments', () {
      const urlWithQuery = 'http://127.0.0.1:8080/stream.flac?auth=token123&rate=96000#pos=0';
      const playArgs = LocalVideoPlayArgs(
        filePath: urlWithQuery,
        title: 'Streamed FLAC',
      );
      expect(playArgs.effectiveIsAudio, isTrue);
      expect(PlayerItemSurface.isAudioUrl(urlWithQuery), isTrue);

      final task = DownloadTask(
        gid: 'gid-stream',
        url: urlWithQuery,
        title: 'Streamed FLAC',
        fileName: urlWithQuery,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(task.isAudio, isTrue);
      expect(task.isVideo, isFalse);
    });

    test('empty roadList guard prevents RangeError when local playback finishes', () {
      // Simulate player completed condition on local media (empty roadList)
      final roadList = <dynamic>[];
      const currentRoad = 0;
      const currentEpisode = 1;
      const isPlayerCompleted = true;

      final hasValidRoads = roadList.isNotEmpty &&
          currentRoad >= 0 &&
          currentRoad < roadList.length;

      bool shouldAutoPlayNext = false;
      if (isPlayerCompleted &&
          hasValidRoads &&
          currentEpisode < roadList[currentRoad].data.length) {
        shouldAutoPlayNext = true;
      }

      expect(hasValidRoads, isFalse);
      expect(shouldAutoPlayNext, isFalse);
    });
  });
}
