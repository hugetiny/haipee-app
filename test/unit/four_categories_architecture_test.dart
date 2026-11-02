import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/plugins/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('四大分类大一统架构体系测试 (在线视频/电视直播/网盘资源/BT磁力)', () {
    // -------------------------------------------------------------
    // 1. PluginCategory 枚举与资源类 (下载类) 语义校验
    // -------------------------------------------------------------
    group('1. PluginCategory 枚举与资源类语义断言', () {
      test('四大类属性与资源类(下载类)归属严格对齐', () {
        // 网盘类与 BT 类属于资源类，也就是下载类
        expect(PluginCategory.drive.isResource, isTrue);
        expect(PluginCategory.drive.isDownloadable, isTrue);
        expect(PluginCategory.drive.groupLabel, '资源下载');

        expect(PluginCategory.bt.isResource, isTrue);
        expect(PluginCategory.bt.isDownloadable, isTrue);
        expect(PluginCategory.bt.groupLabel, '资源下载');

        // 在线视频与电视直播属于视听在线类，非下载资源类
        expect(PluginCategory.video.isResource, isFalse);
        expect(PluginCategory.video.isDownloadable, isFalse);
        expect(PluginCategory.video.groupLabel, '视听在线');

        expect(PluginCategory.live.isResource, isFalse);
        expect(PluginCategory.live.isDownloadable, isFalse);
        expect(PluginCategory.live.groupLabel, '视听在线');
      });

      test('fromString 容错解析多种别名', () {
        expect(PluginCategory.fromString('live'), PluginCategory.live);
        expect(PluginCategory.fromString('iptv'), PluginCategory.live);
        expect(PluginCategory.fromString('m3u'), PluginCategory.live);

        expect(PluginCategory.fromString('drive'), PluginCategory.drive);
        expect(PluginCategory.fromString('alist'), PluginCategory.drive);
        expect(PluginCategory.fromString('pan'), PluginCategory.drive);
        expect(PluginCategory.fromString('webdav'), PluginCategory.drive);

        expect(PluginCategory.fromString('bt'), PluginCategory.bt);
        expect(PluginCategory.fromString('torrent'), PluginCategory.bt);
        expect(PluginCategory.fromString('magnet'), PluginCategory.bt);
        expect(PluginCategory.fromString('cardigann'), PluginCategory.bt);

        expect(PluginCategory.fromString('video'), PluginCategory.video);
        expect(PluginCategory.fromString('maccms'), PluginCategory.video);
        expect(PluginCategory.fromString('unknown_xyz'), PluginCategory.video);
      });
    });

    // -------------------------------------------------------------
    // 2. Plugin 对象的分类自动解析与显式配置
    // -------------------------------------------------------------
    group('2. Plugin 对象分类与解析能力断言', () {
      test('显式 category 配置优先解析', () {
        final plugin = Plugin(
          api: '1',
          type: 'custom',
          name: '自定义网盘',
          version: '1.0',
          category: 'drive',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://pan.example.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );

        expect(plugin.resolvedCategory, PluginCategory.drive);
        expect(plugin.isResource, isTrue);
        expect(plugin.isDownloadable, isTrue);
        expect(plugin.isDrive, isTrue);
        expect(plugin.isLive, isFalse);
        expect(plugin.isVideo, isFalse);
      });

      test('未显式配置 category 时，根据协议类型自动准确推断', () {
        // 1. AList 推断为 drive (资源下载类)
        final alistPlugin = Plugin(
          api: '1',
          type: 'alist',
          name: '小雅影视',
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://al.example.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );
        expect(alistPlugin.resolvedCategory, PluginCategory.drive);
        expect(alistPlugin.isResource, isTrue);
        expect(alistPlugin.isDownloadable, isTrue);

        // 2. IPTV 推断为 live
        final iptvPlugin = Plugin(
          api: '1',
          type: 'iptv',
          name: '央视直播',
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://live.example.com/tv.m3u',
          searchURL: 'https://live.example.com/tv.m3u',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );
        expect(iptvPlugin.resolvedCategory, PluginCategory.live);
        expect(iptvPlugin.isResource, isFalse);
        expect(iptvPlugin.isLive, isTrue);

        // 3. Cardigann 推断为 bt (资源下载类)
        final btPlugin = Plugin(
          api: '1',
          type: 'cardigann',
          name: 'Nyaa Tracker',
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://nyaa.si',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );
        expect(btPlugin.resolvedCategory, PluginCategory.bt);
        expect(btPlugin.isResource, isTrue);
        expect(btPlugin.isDownloadable, isTrue);

        // 4. MacCMS 推断为 video
        final maccmsPlugin = Plugin(
          api: '1',
          type: '2',
          name: '光速资源',
          version: '1.0',
          muliSources: true,
          useWebview: false,
          useNativePlayer: true,
          usePost: false,
          useLegacyParser: false,
          userAgent: '',
          baseUrl: 'https://api.guangsuapi.com',
          searchURL: '',
          searchList: '',
          searchName: '',
          searchResult: '',
          chapterRoads: '',
          chapterResult: '',
          referer: '',
        );
        expect(maccmsPlugin.resolvedCategory, PluginCategory.video);
        expect(maccmsPlugin.isResource, isFalse);
        expect(maccmsPlugin.isVideo, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 3. SearchItem 与 PluginSearchResponse 的分类携带与资源属性
    // -------------------------------------------------------------
    group('3. 搜索条目 SearchItem 结构分类标记', () {
      test('SearchItem 正确识别资源类与在线类', () {
        final driveItem = SearchItem(
          name: '间谍过家家.S01.4K.mp4',
          src: '/Anime/SpyFamily/01.mp4',
          category: 'drive',
        );
        expect(driveItem.isResource, isTrue);
        expect(driveItem.isDownloadable, isTrue);
        expect(driveItem.isDrive, isTrue);
        expect(driveItem.isVideo, isFalse);

        final btItem = SearchItem(
          name: '[Subs] 葬送的芙莉莲 1080P HEVC',
          src: 'magnet:?xt=urn:btih:...',
          category: 'bt',
        );
        expect(btItem.isResource, isTrue);
        expect(btItem.isDownloadable, isTrue);
        expect(btItem.isBt, isTrue);

        final liveItem = SearchItem(
          name: 'CCTV-1 综合频道',
          src: 'http://live.com/cctv1.m3u8',
          category: 'live',
        );
        expect(liveItem.isResource, isFalse);
        expect(liveItem.isDownloadable, isFalse);
        expect(liveItem.isLive, isTrue);

        final videoItem = SearchItem(
          name: '孤独摇滚 第01话',
          src: 'https://www.bilibili.com/video/BV1...',
          category: 'video',
        );
        expect(videoItem.isResource, isFalse);
        expect(videoItem.isVideo, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 4. UI 枚举一致性 (PluginCategoryGroup & OnlineSourceFilter)
    // -------------------------------------------------------------
    group('4. UI 分类结构一致性校验', () {
      test('PluginCategoryGroup 包含三大分类与规则商店', () {
        final groups = PluginCategoryGroup.values.map((g) => g.id).toList();
        expect(groups, contains('all'));
        expect(groups, contains('video'));
        expect(groups, contains('live'));
        expect(groups, contains('resource'));
        expect(groups, contains('catalog'));

        // 标签明确标注网盘资源
        final resGroup = PluginCategoryGroup.values.firstWhere((g) => g.id == 'resource');
        expect(resGroup.label, equals('网盘资源'));
      });

      test('OnlineSourceFilter 专精于在线播放与视听流 (全部、视频、直播)', () {
        final filters = OnlineSourceFilter.values.map((f) => f.id).toList();
        expect(filters, contains('all'));
        expect(filters, contains('video'));
        expect(filters, contains('live'));
        // 资源类(网盘与BT)收敛至一级菜单「资源/下载」板块，不混杂在在线播放搜索页
        expect(filters, isNot(contains('resource')));
      });
    });

    // -------------------------------------------------------------
    // 5. 规则库文件与 plugins/index.json 一致性
    // -------------------------------------------------------------
    group('5. 规则库文件与 plugins/index.json 分类元数据检验', () {
      test('四大代表规则文件均具备清晰的 category 定义', () {
        // 在线视频
        final videoFile = File('plugins/guangsu.yaml');
        expect(videoFile.existsSync(), isTrue);
        final videoPlugin = Plugin.fromYaml(videoFile.readAsStringSync());
        expect(videoPlugin.resolvedCategory, PluginCategory.video);
        expect(videoPlugin.isResource, isFalse);

        // 电视直播
        final liveFile = File('plugins/iptv_live.yaml');
        expect(liveFile.existsSync(), isTrue);
        final livePlugin = Plugin.fromYaml(liveFile.readAsStringSync());
        expect(livePlugin.resolvedCategory, PluginCategory.live);
        expect(livePlugin.isLive, isTrue);
        expect(livePlugin.isResource, isFalse);

        // 网盘资源 (下载类)
        final driveFile = File('plugins/alist_public.yaml');
        expect(driveFile.existsSync(), isTrue);
        final drivePlugin = Plugin.fromYaml(driveFile.readAsStringSync());
        expect(drivePlugin.resolvedCategory, PluginCategory.drive);
        expect(drivePlugin.isDrive, isTrue);
        expect(drivePlugin.isResource, isTrue);
        expect(drivePlugin.isDownloadable, isTrue);

        // BT 磁力 (下载类)
        final btFile = File('plugins/nyaa.yaml');
        expect(btFile.existsSync(), isTrue);
        final btPlugin = Plugin.fromYaml(btFile.readAsStringSync());
        expect(btPlugin.resolvedCategory, PluginCategory.bt);
        expect(btPlugin.isBt, isTrue);
        expect(btPlugin.isResource, isTrue);
        expect(btPlugin.isDownloadable, isTrue);
      });

      test('plugins/index.json 覆盖四大分类且标注资源下载属性', () {
        final indexFile = File('plugins/index.json');
        expect(indexFile.existsSync(), isTrue);

        final list = jsonDecode(indexFile.readAsStringSync()) as List;
        final categories = list.map((e) => e['category']?.toString()).toSet();

        expect(categories, contains('video'));
        expect(categories, contains('live'));
        expect(categories, contains('drive'));
        expect(categories, contains('bt'));
      });
    });
  });
}
