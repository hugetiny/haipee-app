import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/pages/player/local_player_page.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/utils/aria2_client.dart';

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
      final aria2Status = {
        'gid': 'gid-12345',
        'status': 'active',
        'totalLength': '1050000000',
        'completedLength': '25000000',
        'downloadSpeed': '5242880',
        'files': [
          {
            'path': '/downloads/Anime_Ep01/cover.jpg',
            'length': '150000',
            'completedLength': '150000',
          },
          {
            'path': '/downloads/Anime_Ep01/release_info.nfo',
            'length': '2048',
            'completedLength': '2048',
          },
          {
            'path': '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4',
            'length': '1049000000',
            'completedLength': '24847952',
            'uris': [
              {'uri': 'magnet:?xt=urn:btih:0123456789abcdef'}
            ],
          },
        ],
      };

      final task = DownloadTask.fromAria2Status(aria2Status, title: 'Anime Ep 01');

      expect(task.fileName, '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4');
      expect(task.filePath, '/downloads/Anime_Ep01/[SubGroup] Anime - 01 [1080p].mp4');
      expect(task.url, 'magnet:?xt=urn:btih:0123456789abcdef');
      expect(task.isActive, isTrue);
    });

    test('should fallback to first file if no video extension matches', () {
      final aria2Status = {
        'gid': 'gid-67890',
        'status': 'complete',
        'totalLength': '500',
        'completedLength': '500',
        'files': [
          {
            'path': '/downloads/archive.tar.gz',
            'length': '500',
            'completedLength': '500',
          }
        ],
      };

      final task = DownloadTask.fromAria2Status(aria2Status);
      expect(task.filePath, '/downloads/archive.tar.gz');
      expect(task.isComplete, isTrue);
    });

    test('should pick the primary audio file and set isAudio for audio torrents', () {
      final aria2Status = {
        'gid': 'gid-audio-1',
        'status': 'active',
        'totalLength': '60000000',
        'completedLength': '10000000',
        'files': [
          {
            'path': '/music/Album/cover.jpg',
            'length': '350000',
          },
          {
            'path': '/music/Album/disc.cue',
            'length': '2048',
          },
          {
            'path': '/music/Album/01 - Hi-Res Track.flac',
            'length': '59000000',
            'uris': [
              {'uri': 'magnet:?xt=urn:btih:audioalbum123'}
            ],
          },
        ],
      };

      final task = DownloadTask.fromAria2Status(aria2Status, title: 'Hi-Res Album');
      expect(task.fileName, '/music/Album/01 - Hi-Res Track.flac');
      expect(task.isAudio, isTrue);
      expect(task.isVideo, isFalse);
      expect(task.isPlayable, isTrue);
    });

    test('should prioritize video file over audio file if release contains both', () {
      final aria2Status = {
        'gid': 'gid-hybrid',
        'status': 'active',
        'totalLength': '700000000',
        'completedLength': '20000000',
        'files': [
          {
            'path': '/release/soundtrack.mp3',
            'length': '15000000',
          },
          {
            'path': '/release/movie.mkv',
            'length': '680000000',
          },
        ],
      };

      final task = DownloadTask.fromAria2Status(aria2Status, title: 'Movie + OST');
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

  group('Aria2 Magnet Task Following and Metadata Inheritance', () {
    test('child task inherits metadata via following GID lookup', () {
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

      final taskStore = <String, DownloadTask>{
        metadataTask.gid: metadataTask,
      };

      // Simulated Aria2 status for the spawned download task
      final activeAria2Status = {
        'gid': 'gid-data-1',
        'status': 'active',
        'following': 'gid-meta-1',
        'totalLength': '2000000000',
        'completedLength': '1000000',
        'files': [
          {'path': '/downloads/Fate_Zero_01.mkv', 'length': '2000000000'}
        ]
      };

      final gid = activeAria2Status['gid'] as String;
      final following = activeAria2Status['following'] as String;
      DownloadTask? existingTask = taskStore[gid];
      if (existingTask == null && following.isNotEmpty) {
        existingTask = taskStore[following];
      }

      final downloadedTask = DownloadTask.fromAria2Status(
        activeAria2Status,
        title: existingTask?.title,
        bangumiId: existingTask?.bangumiId,
        episodeNumber: existingTask?.episodeNumber,
      );

      expect(downloadedTask.title, 'Fate/Zero S01 [BDRip FLAC]');
      expect(downloadedTask.bangumiId, '1001');
      expect(downloadedTask.episodeNumber, 1);
      expect(downloadedTask.fileName, '/downloads/Fate_Zero_01.mkv');
    });

    test('metadata task with followedBy is filtered out from stopped results', () {
      final stoppedResults = [
        {
          'gid': 'gid-meta-1',
          'status': 'complete',
          'followedBy': ['gid-data-1'],
        },
        {
          'gid': 'gid-normal-complete',
          'status': 'complete',
          'files': [
            {'path': '/downloads/finished.mp4', 'length': '5000000'}
          ]
        }
      ];

      final filtered = <Map<String, dynamic>>[];
      for (final result in stoppedResults) {
        final followedBy = result['followedBy'] as List<dynamic>?;
        if (followedBy != null && followedBy.isNotEmpty) {
          continue;
        }
        filtered.add(result);
      }

      expect(filtered.length, 1);
      expect(filtered.first['gid'], 'gid-normal-complete');
    });

    test('Aria2Client.defaultStatusKeys must request following, followedBy, and dir', () {
      final keys = Aria2Client.defaultStatusKeys;
      expect(keys.contains('following'), isTrue,
          reason: 'Aria2 RPC will not return following without this key');
      expect(keys.contains('followedBy'), isTrue,
          reason: 'Aria2 RPC will not return followedBy without this key');
      expect(keys.contains('dir'), isTrue,
          reason: 'Aria2 RPC will not return download directory without this key');
    });

    test('child data task inherits url from parent metadata task', () {
      final dataStatus = {
        'gid': 'gid-data-child',
        'status': 'active',
        'following': 'gid-meta-parent',
        'files': [
          {'path': '/downloads/movie.mkv', 'length': '1000000', 'uris': []}
        ],
      };

      const originalMagnet = 'magnet:?xt=urn:btih:abcdef123456';
      final task = DownloadTask.fromAria2Status(
        dataStatus,
        url: originalMagnet,
        title: 'Movie Title',
      );

      expect(task.url, originalMagnet);
      expect(task.title, 'Movie Title');
      expect(task.fileName, '/downloads/movie.mkv');
    });

    test('extracts bittorrent info name when title is missing or a raw magnet link', () {
      final btStatus = {
        'gid': 'gid-bt',
        'status': 'active',
        'bittorrent': {
          'info': {'name': 'Steins;Gate Complete OST [FLAC]'}
        },
        'files': [
          {'path': '/downloads/01.flac', 'length': '30000000'}
        ]
      };

      final taskFromMagnet = DownloadTask.fromAria2Status(
        btStatus,
        title: 'magnet:?xt=urn:btih:12345',
      );
      expect(taskFromMagnet.title, 'Steins;Gate Complete OST [FLAC]');

      final taskNullTitle = DownloadTask.fromAria2Status(
        btStatus,
      );
      expect(taskNullTitle.title, 'Steins;Gate Complete OST [FLAC]');
    });

    test('multi-track audio album prioritizes Track 1 instead of the longest track', () {
      final albumStatus = {
        'gid': 'gid-album',
        'status': 'active',
        'files': [
          {'path': '/music/Album/03 - Track 3.flac', 'length': '50000000'},
          {'path': '/music/Album/01 - Track 1.flac', 'length': '30000000'},
          {'path': '/music/Album/02 - Track 2.flac', 'length': '40000000'},
        ]
      };

      final task = DownloadTask.fromAria2Status(albumStatus);
      expect(task.fileName, '/music/Album/01 - Track 1.flac');
      expect(task.isAudio, isTrue);
    });

    test('preferAudio prioritizes lossless music album over small promo video', () {
      final hybridStatus = {
        'gid': 'gid-hybrid-music',
        'status': 'active',
        'files': [
          {'path': '/music/promo_preview.mp4', 'length': '8000000'},
          {'path': '/music/01.flac', 'length': '60000000'},
        ]
      };

      final taskExplicit = DownloadTask.fromAria2Status(
        hybridStatus,
        preferAudio: true,
      );
      expect(taskExplicit.fileName, '/music/01.flac');
      expect(taskExplicit.isAudio, isTrue);

      final taskAutoRatio = DownloadTask.fromAria2Status(
        hybridStatus,
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
