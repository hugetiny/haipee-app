import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/danmaku/danmaku_title_cleaner.dart';

void main() {
  group('DanmakuTitleCleaner - extractCleanTitle', () {
    test('从全括号格式中提取纯净中文番剧名', () {
      const raw = '[DBD-Raws][葬送的芙莉莲][01-28TV全集][1080P][FLAC]';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '葬送的芙莉莲');
    });

    test('从正文夹杂双语标题中优先提取中文主标题', () {
      const raw =
          '[Lilith-Raws] 迷宫饭 / Dungeon Meshi - 01 [Baha][WEB-DL][1080p][AVC AAC][CHT][MP4]';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '迷宫饭');
    });

    test('从标准连字符分集格式中提取中文标题', () {
      const raw = '[ANi] 间谍过家家 - 05 [1080P][Baha][WEB-DL][AAC AVC][CHT].mp4';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '间谍过家家');
    });

    test('从纯英文或罗马音标题中剔除字幕组和CRC32后缀', () {
      const raw = '[SubsPlease] Sousou no Frieren - 02 (1080p) [5F2A8D9E].mkv';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, 'Sousou no Frieren');
    });

    test('从带有装饰符号和新番标签的长标题中提取真实中文名', () {
      const raw = '【极影字幕社】★10月新番 胆大党 / Dandadan 第03话 1080P MP4 繁日双语';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '胆大党');
    });

    test('从含感叹号和双语斜杠标题中提取', () {
      const raw =
          '[喵萌奶茶屋&LoliHouse] 败犬女主太多了！ / Makeine - 04 [WebRip 1080p HEVC-10bit AAC][简繁内封字幕]';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '败犬女主太多了！');
    });

    test('欧美规范点号剧集命名解析', () {
      const raw =
          'Sparks.of.Tomorrow.S01E13.To.the.Future.We.Desire.1080p.NF.WEB-DL.MULTi.AAC2.0.H.264.MSubs-ToonsHub.mkv';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, 'Sparks of Tomorrow');
    });

    test('普通本地文件名提取', () {
      const raw = '海贼王 第1000集.mp4';
      final clean = DanmakuTitleCleaner.extractCleanTitle(raw);
      expect(clean, '海贼王');
    });
  });

  group('DanmakuTitleCleaner - extractEpisodeNumber', () {
    test('提取S01E13集数', () {
      const raw =
          'Sparks.of.Tomorrow.S01E13.To.the.Future.We.Desire.1080p.NF.WEB-DL.MULTi.AAC2.0.H.264.MSubs-ToonsHub.mkv';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 13);
    });

    test('提取连字符集数 - 01', () {
      const raw = '[Lilith-Raws] 迷宫饭 - 01 [1080p].mp4';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 1);
    });

    test('提取连字符集数 - 05', () {
      const raw = '[ANi] 间谍过家家 - 05 [1080P].mp4';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 5);
    });

    test('提取第xx话', () {
      const raw = '【极影字幕社】胆大党 第03话 1080P';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 3);
    });

    test('提取第xx集', () {
      const raw = '海贼王 第1000集.mp4';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 1000);
    });

    test('提取EPxx', () {
      const raw = 'Sousou no Frieren EP12 1080p.mkv';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 12);
    });

    test('提取[02]方括号集数', () {
      const raw = '[YMDR] 葬送的芙莉莲 [02] [1080p].mkv';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, 2);
    });

    test('合集 01-28 不误识为单集', () {
      const raw = '[DBD-Raws][葬送的芙莉莲][01-28TV全集][1080P][FLAC]';
      final ep = DanmakuTitleCleaner.extractEpisodeNumber(raw);
      expect(ep, isNull);
    });
  });
}
