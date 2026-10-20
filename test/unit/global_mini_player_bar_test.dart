import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/global_mini_player_bar.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/player/local_video_play_args.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/modules/torrent_stream/torrserver_stream_engine.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mini_player_hive_test');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting_test');
  });

  tearDownAll(() async {
    try {
      await GStorage.setting.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('LocalVideoPlayArgs Audio/Video Differentiation Tests', () {
    test('Identifies video and audio extensions correctly', () {
      const videoArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:8090/stream/Sparks.of.Tomorrow.S01E13.1080p.mkv',
        title: 'Sparks of Tomorrow S01E13',
      );
      expect(videoArgs.effectiveIsAudio, isFalse);

      const audioArgs = LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:8090/stream/OST.Album.flac',
        title: 'Soundtrack Album [FLAC]',
        isAudio: true,
      );
      expect(audioArgs.effectiveIsAudio, isTrue);

      const inferredAudioArgs = LocalVideoPlayArgs(
        filePath: '/storage/music/theme.mp3',
        title: 'Anime Opening Theme',
      );
      expect(inferredAudioArgs.effectiveIsAudio, isTrue);
    });
  });

  group('TorrServerStreamEngine Session Tests', () {
    test('hasActiveSession starts as false when idle', () {
      expect(TorrServerStreamEngine.instance.hasActiveSession, isFalse);
    });
  });

  group('GlobalMiniPlayerBar Widget State & Lifecycle Tests', () {
    testWidgets('GlobalMiniPlayerBar renders SizedBox.shrink when no active playback',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GlobalMiniPlayerBar(),
            ),
          ),
        ),
      );

      // 当无活跃播放时，应完全不占用空间或渲染内容
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('GlobalMiniPlayerBar renders on main tabs and hides on player routes',
        (tester) async {
      final container = ProviderContainer();
      final playerController = container.read(playerProvider.notifier);

      // 设置活跃的本地播放参数
      playerController.activeLocalVideoArgs = const LocalVideoPlayArgs(
        filePath: 'http://127.0.0.1:8090/stream/TestVideo.mkv',
        title: 'Test Streaming Anime Episode',
      );

      // 1. 在主界面路由 (/resource) 下渲染
      container.read(currentRouteProvider.notifier).updateRoute(Routes.resource);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalMiniPlayerBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 应显示视频标题、进度条、返回与关闭按钮
      expect(find.text('Test Streaming Anime Episode'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);

      // 2. 当路由切换到播放页面 (/player/local) 时，应自动隐藏
      container.read(currentRouteProvider.notifier).updateRoute(Routes.localPlayer);
      await tester.pump();
      expect(find.text('Test Streaming Anime Episode'), findsNothing);

      // 3. 当路由切回主界面 (/download)，再次显现
      container.read(currentRouteProvider.notifier).updateRoute(Routes.download);
      await tester.pump();
      expect(find.text('Test Streaming Anime Episode'), findsOneWidget);

      // 4. 点击停止按钮彻底清除
      final closeButton = find.byTooltip('停止播放并关闭');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(playerController.hasActivePlayback, isFalse);
      expect(playerController.activeLocalVideoArgs, isNull);
      expect(find.text('Test Streaming Anime Episode'), findsNothing);
    });
  });
}
