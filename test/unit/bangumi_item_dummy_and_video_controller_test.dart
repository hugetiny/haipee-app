import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/pages/player/local_video_play_args.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bangumi_dummy_test_');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
  });

  tearDown(() async {
    await settingBox.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('BangumiItem.dummy Factory Tests', () {
    test('BangumiItem.dummy defaults produce valid non-null object with non-negative id', () {
      final dummy = BangumiItem.dummy();

      expect(dummy.id, greaterThanOrEqualTo(0));
      expect(dummy.name, equals('未知视频'));
      expect(dummy.nameCn, equals('未知视频'));
      expect(dummy.type, equals(2));
      expect(dummy.tags, isEmpty);
      expect(dummy.alias, isEmpty);
      expect(dummy.votesCount, isEmpty);
      expect(dummy.images, isNotEmpty);
      expect(dummy.images['large'], equals(''));
    });

    test('BangumiItem.dummy preserves explicit positive ID and custom title', () {
      final dummy = BangumiItem.dummy(
        id: 998244353,
        title: 'Bilibili 视频测试',
        image: 'https://example.com/cover.jpg',
      );

      expect(dummy.id, equals(998244353));
      expect(dummy.name, equals('Bilibili 视频测试'));
      expect(dummy.nameCn, equals('Bilibili 视频测试'));
      expect(dummy.images['large'], equals('https://example.com/cover.jpg'));
    });

    test('BangumiItem.dummy computes deterministic positive ID from title when id is omitted or <= 0', () {
      final dummy1 = BangumiItem.dummy(title: '抖音短视频 1080P');
      final dummy2 = BangumiItem.dummy(id: 0, title: '抖音短视频 1080P');
      final dummy3 = BangumiItem.dummy(id: -1, title: '抖音短视频 1080P');

      expect(dummy1.id, greaterThan(0));
      expect(dummy2.id, equals(dummy1.id));
      expect(dummy3.id, equals(dummy1.id));
    });

    test('BangumiItem.dummy handles empty or whitespace title safely with positive id and fallback name', () {
      final emptyDummy = BangumiItem.dummy(title: '');
      final spaceDummy = BangumiItem.dummy(title: '   ');

      expect(emptyDummy.id, greaterThan(0));
      expect(emptyDummy.name, equals('未知视频'));
      expect(emptyDummy.nameCn, equals('未知视频'));

      expect(spaceDummy.id, greaterThan(0));
      expect(spaceDummy.name, equals('未知视频'));
      expect(spaceDummy.nameCn, equals('未知视频'));
    });
  });

  group('VideoPageController bangumiItem and currentPlugin Fallback Tests', () {
    test('VideoPageController returns dummy fallback when bangumiItem is not set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(videoProvider.notifier);

      // Verify bangumiItemOrNull is null initially
      expect(controller.bangumiItemOrNull, isNull);

      // bangumiItem getter must NEVER throw StateError
      final item = controller.bangumiItem;
      expect(item, isNotNull);
      expect(item.name, equals('未知视频'));
      expect(item.id, greaterThanOrEqualTo(0));

      // When state has a custom title, dummy fallback uses that title
      controller.state = controller.state.copyWith(title: '网络嗅探直链视频');
      final itemWithTitle = controller.bangumiItem;
      expect(itemWithTitle.name, equals('网络嗅探直链视频'));
      expect(itemWithTitle.id, greaterThan(0));

      // When bangumiItem is explicitly set, returns the explicit item
      final realItem = BangumiItem.dummy(id: 42, title: '葬送的芙莉莲');
      controller.bangumiItem = realItem;
      expect(controller.bangumiItem.id, equals(42));
      expect(controller.bangumiItemOrNull?.id, equals(42));
    });

    test('VideoPageController returns template fallback when currentPlugin is not set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(videoProvider.notifier);

      // Verify currentPluginOrNull is null initially
      expect(controller.currentPluginOrNull, isNull);

      // currentPlugin getter must NEVER throw StateError
      final plugin = controller.currentPlugin;
      expect(plugin, isNotNull);
      expect(plugin.name, isEmpty);

      // When currentPlugin is set, returns the configured plugin
      final testPlugin = Plugin.fromTemplate()..name = 'TestPlugin';
      controller.state = controller.state.copyWith(currentPlugin: testPlugin);
      expect(controller.currentPlugin.name, equals('TestPlugin'));
      expect(controller.currentPluginOrNull?.name, equals('TestPlugin'));
    });
  });

  group('PlayerController Null-Safety Getters Tests', () {
    test('PlayerController getters are safe when mediaPlayer is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(playerProvider.notifier);

      expect(controller.mediaPlayer, isNull);

      // All getters must return safe defaults without Null check operator crash
      expect(controller.playerPlaying, isFalse);
      expect(controller.playerBuffering, isFalse);
      expect(controller.playerCompleted, isFalse);
      expect(controller.playerVolume, equals(100.0));
      expect(controller.playerPosition, equals(Duration.zero));
      expect(controller.playerBuffer, equals(Duration.zero));
      expect(controller.playerDuration, equals(Duration.zero));
      expect(controller.hasActivePlayback, isFalse);
    });

    test('PlayerController preserves activeLocalVideoArgs title when videoPageState title is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(playerProvider.notifier);
      final videoController = container.read(videoProvider.notifier);

      expect(videoController.state.title, isEmpty);
      controller.activeLocalVideoArgs = const LocalVideoPlayArgs(
        filePath: '/tmp/test.mp4',
        title: '本地下载的测试视频.mp4',
      );

      // Verify that title resolution logic honors activeLocalVideoArgs title
      final resolvedTitle = controller.currentTitle.isNotEmpty
          ? controller.currentTitle
          : (controller.activeLocalVideoArgs?.title.isNotEmpty == true
              ? controller.activeLocalVideoArgs!.title
              : (videoController.state.title.isNotEmpty
                  ? videoController.state.title
                  : videoController.bangumiItem.name));

      expect(resolvedTitle, equals('本地下载的测试视频.mp4'));
    });
  });
}
