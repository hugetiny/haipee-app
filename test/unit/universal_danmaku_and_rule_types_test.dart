import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/request/damaku.dart';
import 'package:haipee/utils/api_credentials.dart';

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
    test('PluginRuleType enum defines all 7 distinct rule protocol categories', () {
      expect(PluginRuleType.values.length, equals(7));
      expect(PluginRuleType.haipee.id, equals('haipee'));
      expect(PluginRuleType.haipee.label, equals('Haipee 规则'));
      expect(PluginRuleType.maccms.id, equals('maccms'));
      expect(PluginRuleType.maccms.label, equals('MacCMS 规则'));
      expect(PluginRuleType.tvbox.id, equals('tvbox'));
      expect(PluginRuleType.tvbox.label, equals('TVBox 规则'));
      expect(PluginRuleType.iptv.id, equals('iptv'));
      expect(PluginRuleType.iptv.label, equals('IPTV 规则'));
      expect(PluginRuleType.piped.id, equals('piped'));
      expect(PluginRuleType.piped.label, equals('Piped 规则'));
      expect(PluginRuleType.alist.id, equals('alist'));
      expect(PluginRuleType.alist.label, equals('AList 规则'));
      expect(PluginRuleType.cardigann.id, equals('cardigann'));
      expect(PluginRuleType.cardigann.label, equals('Cardigann 规则'));
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
      expect(animePlugin.ruleType, equals(PluginRuleType.haipee));
      expect(animePlugin.isCardigann, isFalse);

      final livePlugin = createPlugin('live');
      expect(livePlugin.ruleType, equals(PluginRuleType.iptv));

      final maccmsPlugin = createPlugin('maccms');
      expect(maccmsPlugin.ruleType, equals(PluginRuleType.maccms));

      final drivePlugin = createPlugin('alist');
      expect(drivePlugin.ruleType, equals(PluginRuleType.alist));

      final cardigannPlugin = createPlugin('cardigann');
      expect(cardigannPlugin.ruleType, equals(PluginRuleType.cardigann));
      expect(cardigannPlugin.isCardigann, isTrue);

      final tvboxPlugin = createPlugin('tvbox');
      expect(tvboxPlugin.ruleType, equals(PluginRuleType.tvbox));
      expect(tvboxPlugin.isTvBox, isTrue);

      final bilibiliPlugin = createPlugin('bilibili');
      expect(bilibiliPlugin.ruleType, equals(PluginRuleType.piped));

      final douyinPlugin = createPlugin('douyin');
      expect(douyinPlugin.ruleType, equals(PluginRuleType.piped));
    });
  });
}
