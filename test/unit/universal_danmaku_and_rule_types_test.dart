import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/utils/api_credentials.dart';

void main() {
  group('Universal DanDanPlay Danmaku & Title Cleaner Tests', () {
    test('ApiCredentials recognizes real credentials and is not treated as placeholder', () {
      expect(ApiCredentials.isPlaceholder(ApiCredentials.danDanAppId, ApiCredentials.danDanApiKey), isFalse);
      expect(ApiCredentials.danDanAppId.isNotEmpty, isTrue);
      expect(ApiCredentials.danDanApiKey.isNotEmpty, isTrue);
    });

    test('cleanAnimeTitleForSearch cleans anime title for accurate DandanPlay matching', () {
      // 常见字幕组繁杂格式清洗
      final raw1 = '[NC-Raws] 葬送的芙莉莲 - 28 [Baha][WEB-DL][1080p][AVC AAC][CHT][MP4].mp4';
      final clean1 = DanmakuRequest.cleanAnimeTitleForSearch(raw1);
      expect(clean1.contains('NC-Raws'), isFalse);
      expect(clean1.contains('1080p'), isFalse);
      expect(clean1.contains('.mp4'), isFalse);
      expect(clean1, contains('葬送的芙莉莲'));

      final raw2 = '【极影字幕社】★10月新番 胆大党 / Dandadan 第03话 1080P MP4 繁日双语';
      final clean2 = DanmakuRequest.cleanAnimeTitleForSearch(raw2);
      expect(clean2, equals('胆大党'));

      final raw3 = '进击的巨人 最终季.mkv';
      final clean3 = DanmakuRequest.cleanAnimeTitleForSearch(raw3);
      expect(clean3, equals('进击的巨人 最终季'));
    });
  });

  group('7 Plugin Rule Types Architecture Tests', () {
    test('PluginRuleType enum defines all 7 distinct rule categories', () {
      expect(PluginRuleType.values.length, equals(7));
      expect(PluginRuleType.anime.label, equals('动漫番剧'));
      expect(PluginRuleType.maccms.label, equals('影视采集'));
      expect(PluginRuleType.bilibili.label, equals('哔哩哔哩'));
      expect(PluginRuleType.douyin.label, equals('短视频'));
      expect(PluginRuleType.live.label, equals('电视直播'));
      expect(PluginRuleType.drive.label, equals('网盘资源'));
      expect(PluginRuleType.bt.label, equals('BT磁力'));
    });

    test('Plugin correctly maps type to PluginRuleType and detects Cardigann', () {
      Plugin createPlugin(String type) => Plugin(
            name: 'test_$type',
            version: '1.0.0',
            type: type,
            api: '1',
            baseUrl: '',
            searchURL: '',
            searchList: '',
            searchName: '',
            searchResult: '',
            chapterRoads: '',
            chapterResult: '',
            referer: '',
            muliSources: false,
            useWebview: false,
            useNativePlayer: true,
            usePost: false,
            useLegacyParser: false,
            userAgent: '',
          );

      final animePlugin = createPlugin('anime');
      expect(animePlugin.ruleType, equals(PluginRuleType.anime));
      expect(animePlugin.isCardigann, isFalse);

      final livePlugin = createPlugin('live');
      expect(livePlugin.ruleType, equals(PluginRuleType.live));

      final maccmsPlugin = createPlugin('maccms');
      expect(maccmsPlugin.ruleType, equals(PluginRuleType.maccms));

      final drivePlugin = createPlugin('alist');
      expect(drivePlugin.ruleType, equals(PluginRuleType.drive));

      final cardigannPlugin = createPlugin('cardigann');
      expect(cardigannPlugin.ruleType, equals(PluginRuleType.bt));
      expect(cardigannPlugin.isCardigann, isTrue);
    });
  });
}
