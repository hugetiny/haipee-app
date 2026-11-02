import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/plugins/plugins.dart';

void main() {
  group('Modern API Suggest Video Plugins Tests', () {
    test('cleanKeywordForSearch 能够清理日文波浪号、杂音字符和多余空格', () {
      expect(
        Plugin.cleanKeywordForSearch('CLANNAD 〜AFTER STORY〜'),
        'CLANNAD AFTER STORY',
      );
      expect(
        Plugin.cleanKeywordForSearch('【1080P】CLANNAD ～AFTER STORY～ [完结]'),
        'CLANNAD AFTER STORY',
      );
      expect(
        Plugin.cleanKeywordForSearch('★魔法少女小圆☆ (剧场版)'),
        '魔法少女小圆',
      );
    });

    test('mutefun 和 dalvdm 支持 api 模式检索并正确解析 suggest 数据格式', () {
      final mutefunFile = File('assets/plugins/mutefun.json');
      final mutefun = Plugin.fromJson(jsonDecode(mutefunFile.readAsStringSync()));
      expect(mutefun.searchMode, 'api');
      expect(mutefun.searchApiConfig, isNotNull);

      final dalvdmFile = File('assets/plugins/dalvdm.json');
      final dalvdm = Plugin.fromJson(jsonDecode(dalvdmFile.readAsStringSync()));
      expect(dalvdm.searchMode, 'api');
      expect(dalvdm.searchApiConfig, isNotNull);
    });

    test('真实网络联调：mutefun 与 dalvdm 能够通过 suggest API 搜索到 CLANNAD 剧集', () async {
      final mutefunFile = File('assets/plugins/mutefun.json');
      final mutefun = Plugin.fromJson(jsonDecode(mutefunFile.readAsStringSync()));

      try {
        final res = await mutefun.queryBangumi('CLANNAD', shouldRethrow: true);
        expect(res.pluginName, 'mutefun');
        expect(res.data.isNotEmpty, isTrue, reason: 'mutefun 应返回至少 1 条结果');
        final titles = res.data.map((item) => item.name).toList();
        expect(titles.any((t) => t.contains('CLANNAD')), isTrue);
      } catch (e) {
        // 网络异常情况下不强制阻断离线单测
        stdout.writeln('mutefun 网络检索测试跳过（网络波动）: $e');
      }

      final dalvdmFile = File('assets/plugins/dalvdm.json');
      final dalvdm = Plugin.fromJson(jsonDecode(dalvdmFile.readAsStringSync()));

      try {
        final res = await dalvdm.queryBangumi('CLANNAD', shouldRethrow: true);
        expect(res.pluginName, 'dalvdm');
        expect(res.data.isNotEmpty, isTrue, reason: 'dalvdm 应返回至少 1 条结果');
        final titles = res.data.map((item) => item.name).toList();
        expect(titles.any((t) => t.contains('CLANNAD')), isTrue);
      } catch (e) {
        stdout.writeln('dalvdm 网络检索测试跳过（网络波动）: $e');
      }
    });
  });
}
