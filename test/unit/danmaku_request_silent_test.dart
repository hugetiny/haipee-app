import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test_danmaku_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
  });

  group('DanmakuRequest - Silent Mode & Graceful Degradation', () {
    test('getDanmakuSearchResponse in silent mode returns empty list on network failure without throwing', () async {
      final res = await DanmakuRequest.getDanmakuSearchResponse(
        'SomeNonExistentAnimeTitle_12345_!@#\$%',
        silent: true,
      );
      expect(res.animes, isNotNull);
    });

    test('getBangumiIDByTitle in silent mode returns 0 on unmatched title without throwing', () async {
      final id = await DanmakuRequest.getBangumiIDByTitle(
        'NonExistent_BT_File_Noise_400_Error',
        silent: true,
      );
      expect(id, 0);
    });

    test('getDanDanmaku with id 0 returns empty list immediately', () async {
      final danmakus = await DanmakuRequest.getDanDanmaku(0, 1, silent: true);
      expect(danmakus, isEmpty);
    });

    test('getDanDanmakuByEpisodeID with invalid id returns empty list', () async {
      final danmakus =
          await DanmakuRequest.getDanDanmakuByEpisodeID(-1, silent: true);
      expect(danmakus, isEmpty);
    });
  });
}
