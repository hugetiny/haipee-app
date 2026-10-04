import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/plugins/plugins.dart';

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
  });
}
