import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/danmaku/danmaku_count_service.dart';

void main() {
  group('DanmakuCountService Tests', () {
    setUp(() {
      DanmakuCountService.instance.resetForTesting();
      DanmakuCountService.resolverOverride = null;
    });

    tearDown(() {
      DanmakuCountService.instance.resetForTesting();
      DanmakuCountService.resolverOverride = null;
    });

    test('cacheKeyFor cleans and normalizes anime titles across rule variants', () {
      expect(
        DanmakuCountService.cacheKeyFor('[NC-Raws] 葬送的芙莉莲 - 01 [1080P].mp4'),
        '葬送的芙莉莲',
      );
      expect(
        DanmakuCountService.cacheKeyFor('【悠哈璃羽字幕社】葬送的芙莉莲 Sousou no Frieren [01][1080p]'),
        '葬送的芙莉莲',
      );
      expect(
        DanmakuCountService.cacheKeyFor('葬送的芙莉莲 第01集'),
        '葬送的芙莉莲',
      );
    });

    test('countForTitle returns resolved count and caches subsequent calls', () async {
      int queryCount = 0;
      DanmakuCountService.resolverOverride = (title) async {
        queryCount++;
        if (title.contains('芙莉莲')) return 12345;
        return null;
      };

      final count1 = await DanmakuCountService.instance.countForTitle('葬送的芙莉莲 01');
      expect(count1, 12345);
      expect(queryCount, 1);

      // Same normalized title hits cache, resolver should not be called again
      final count2 = await DanmakuCountService.instance.countForTitle('【字幕组】葬送的芙莉莲 [1080p]');
      expect(count2, 12345);
      expect(queryCount, 1);
    });

    test('countForTitle handles resolver error gracefully without throwing', () async {
      DanmakuCountService.resolverOverride = (title) async {
        throw Exception('Simulated network timeout');
      };

      final count = await DanmakuCountService.instance.countForTitle('未知冷门视频');
      expect(count, isNull);
    });

    test('countForTitle returns null on empty title', () async {
      final count = await DanmakuCountService.instance.countForTitle('   ');
      expect(count, isNull);
    });
  });
}
