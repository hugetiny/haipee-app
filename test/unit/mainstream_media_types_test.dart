import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/alist/alist_service.dart';
import 'package:kazumi/modules/iptv/iptv_service.dart';
import 'package:kazumi/modules/piped/piped_service.dart';
import 'package:kazumi/modules/tvbox/tvbox_importer.dart';
import 'package:kazumi/plugins/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('主流媒体规范分类支持测试', () {
    // -------------------------------------------------------------
    // 分类 1: TVBox / FongMi 规范解析与一键规则转换
    // -------------------------------------------------------------
    group('1. TVBox / FongMi 规范解析 (TvBoxImporter)', () {
      const tvboxJsonSample = '''
      {
        "spider": "https://mirror.ghproxy.com/https://raw.githubusercontent.com/spider.jar",
        "wallpaper": "https://bing.com/img.jpg",
        "sites": [
          {
            "key": "lite_apple",
            "name": "极速影视",
            "type": 1,
            "api": "https://api.guangsuapi.com/api.php/provide/vod/",
            "searchable": 1,
            "quickSearch": 1,
            "filterable": 1
          },
          {
            "key": "wolong_xml",
            "name": "卧龙采集",
            "type": 0,
            "api": "https://collect.wolongzyw.com/api.php/provide/vod/",
            "searchable": 1
          },
          {
            "key": "alist_drive",
            "name": "小雅 AList",
            "type": 4,
            "api": "https://al.chirmyram.com",
            "searchable": 1
          },
          {
            "key": "disabled_site",
            "name": "已禁用站点",
            "type": 1,
            "api": "https://disabled.com/api",
            "searchable": 0
          }
        ]
      }
      ''';

      test('isTvBoxConfig 正确识别 TVBox 订阅格式', () {
        expect(TvBoxImporter.isTvBoxConfig(tvboxJsonSample), isTrue);
        expect(TvBoxImporter.isTvBoxConfig('{"name": "test"}'), isFalse);
        expect(TvBoxImporter.isTvBoxConfig('api: "1"\nname: "test"'), isFalse);
      });

      test('convertToPlugins 成功提取并转换为 Kazumi 标准规则', () {
        final plugins = TvBoxImporter.convertToPlugins(tvboxJsonSample);
        expect(plugins.length, 3); // 过滤了 searchable == 0 的站点

        final p1 = plugins[0];
        expect(p1.name, '极速影视');
        expect(p1.isMacCms, isTrue);
        expect(p1.searchPic, 'vod_pic');
        expect(p1.searchURL, contains('wd=@keyword'));
        expect(p1.useNativePlayer, isTrue);

        final p2 = plugins[1];
        expect(p2.name, '卧龙采集');
        expect(p2.isMacCms, isTrue);

        final p3 = plugins[2];
        expect(p3.name, '小雅 AList');
        expect(p3.isAlist, isTrue);
      });

      test('Plugin.parseMany 自动识别并批量导入 TVBox 配置', () {
        final parsed = Plugin.parseMany(tvboxJsonSample);
        expect(parsed.length, 3);
        expect(parsed.any((p) => p.name == '极速影视'), isTrue);
        expect(parsed.any((p) => p.name == '小雅 AList'), isTrue);
      });
    });

    // -------------------------------------------------------------
    // 分类 2: IPTV / M3U8 电视直播与轮播流规范
    // -------------------------------------------------------------
    group('2. IPTV / M3U8 电视直播流规范 (IptvService)', () {
      const sampleM3u = '''
#EXTM3U x-tvg-url="https://live.fanmingming.com/e.xml"
#EXTINF:-1 tvg-id="CCTV1" tvg-name="CCTV-1" tvg-logo="https://live.fanmingming.com/tv/CCTV1.png" group-title="央视频道",CCTV-1 综合
http://[ipv6]:8080/live/cctv1.m3u8
#EXTINF:-1 tvg-id="CCTV13" tvg-name="CCTV-13" tvg-logo="https://live.fanmingming.com/tv/CCTV13.png" group-title="央视频道",CCTV-13 新闻
http://[ipv6]:8080/live/cctv13.m3u8
#EXTINF:-1 tvg-id="HUNAN" tvg-name="湖南卫视" tvg-logo="https://live.fanmingming.com/tv/HUNAN.png" group-title="卫视频道",湖南卫视 4K
http://[ipv6]:8080/live/hunan.m3u8
#EXTINF:-1 tvg-id="ANIME" tvg-name="火影忍者轮播" tvg-logo="https://live.fanmingming.com/tv/naruto.png" group-title="少儿动漫",火影忍者 24小时轮播
http://[ipv6]:8080/live/naruto.m3u8
      ''';

      test('parseM3u 完整解析频道名称、分组、图标与流媒体链接', () {
        final channels = IptvService.parseM3u(sampleM3u);
        expect(channels.length, 4);

        final c1 = channels[0];
        expect(c1.name, 'CCTV-1 综合');
        expect(c1.group, '央视频道');
        expect(c1.logo, 'https://live.fanmingming.com/tv/CCTV1.png');
        expect(c1.url, 'http://[ipv6]:8080/live/cctv1.m3u8');
        expect(c1.tvgId, 'CCTV1');

        final c4 = channels[3];
        expect(c4.name, '火影忍者 24小时轮播');
        expect(c4.group, '少儿动漫');
      });

      test('iptv_live.yaml 规则文件正确识别为 IPTV 插件', () {
        final file = File('plugins/iptv_live.yaml');
        expect(file.existsSync(), isTrue);

        final yamlStr = file.readAsStringSync();
        final plugin = Plugin.fromYaml(yamlStr);
        expect(plugin.name, 'IPTV 电视直播');
        expect(plugin.isIptv, isTrue);
        expect(plugin.useNativePlayer, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 分类 3: AList / WebDAV 开放网盘挂载规范
    // -------------------------------------------------------------
    group('3. AList / WebDAV 开放网盘挂载规范 (AlistService)', () {
      test('isVideoFile 正确识别视频文件格式', () {
        expect(AlistService.isVideoFile('movie.mp4'), isTrue);
        expect(AlistService.isVideoFile('episode_01.mkv'), isTrue);
        expect(AlistService.isVideoFile('stream.m3u8'), isTrue);
        expect(AlistService.isVideoFile('readme.txt'), isFalse);
        expect(AlistService.isVideoFile('poster.jpg'), isFalse);
      });

      test('alist_public.yaml 规则文件正确识别为 AList 插件', () {
        final file = File('plugins/alist_public.yaml');
        expect(file.existsSync(), isTrue);

        final yamlStr = file.readAsStringSync();
        final plugin = Plugin.fromYaml(yamlStr);
        expect(plugin.name, 'AList 网盘聚合');
        expect(plugin.isAlist, isTrue);
        expect(plugin.useNativePlayer, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 分类 4: YouTube / Piped 开放流媒体规范
    // -------------------------------------------------------------
    group('4. YouTube / Piped 开放流媒体规范 (PipedService)', () {
      test('youtube_piped.yaml 规则文件正确识别为 Piped 插件', () {
        expect(PipedService.defaultApi, isNotEmpty);
        final file = File('plugins/youtube_piped.yaml');
        expect(file.existsSync(), isTrue);

        final yamlStr = file.readAsStringSync();
        final plugin = Plugin.fromYaml(yamlStr);
        expect(plugin.name, 'YouTube (Piped)');
        expect(plugin.isPiped, isTrue);
        expect(plugin.useNativePlayer, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 分类 5: MacCMS V10 工业采集规范 (光速/卧龙资源)
    // -------------------------------------------------------------
    group('5. MacCMS V10 工业级采集规范 (guangsu / wolong)', () {
      test('guangsu.yaml 与 wolong.yaml 解析正常且标记为 isMacCms', () {
        final gsFile = File('plugins/guangsu.yaml');
        expect(gsFile.existsSync(), isTrue);
        final gsPlugin = Plugin.fromYaml(gsFile.readAsStringSync());
        expect(gsPlugin.name, '光速资源');
        expect(gsPlugin.isMacCms, isTrue);
        expect(gsPlugin.searchPic, 'vod_pic');

        final wlFile = File('plugins/wolong.yaml');
        expect(wlFile.existsSync(), isTrue);
        final wlPlugin = Plugin.fromYaml(wlFile.readAsStringSync());
        expect(wlPlugin.name, '卧龙资源');
        expect(wlPlugin.isMacCms, isTrue);
        expect(wlPlugin.searchPic, 'vod_pic');
      });
    });

    // -------------------------------------------------------------
    // 分类 6: 全部分类代表规则覆盖与 plugins/index.json 一致性
    // -------------------------------------------------------------
    group('6. plugins/index.json 一致性与完整分类注册', () {
      test('index.json 包含全部主流分类代表插件', () {
        final indexFile = File('plugins/index.json');
        expect(indexFile.existsSync(), isTrue);

        final list = jsonDecode(indexFile.readAsStringSync()) as List;
        final names = list.map((e) => e['name'].toString()).toSet();

        // 必须覆盖所有比 Kazumi 更主流的分类代表
        expect(names.contains('哔哩哔哩'), isTrue); // 官方长视频+登录 4K
        expect(names.contains('抖音'), isTrue); // 短视频
        expect(names.contains('IPTV 电视直播'), isTrue); // IPTV / M3U8
        expect(names.contains('AList 网盘聚合'), isTrue); // AList 网盘
        expect(names.contains('YouTube (Piped)'), isTrue); // 全球开放流媒体
        expect(names.contains('光速资源'), isTrue); // MacCMS 旗舰采集
        expect(names.contains('卧龙资源'), isTrue); // MacCMS 旗舰采集
        expect(names.contains('TVBox 聚合适配器'), isTrue); // TVBox 盒装生态
      });
    });
  });
}
