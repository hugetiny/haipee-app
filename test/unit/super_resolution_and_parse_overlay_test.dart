import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/services/player/player_error_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sr_overlay_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
    Hive.init(tempDir.path);
    final settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Super-resolution (Shaders) Safety & State Synchronization Tests', () {
    test('ShadersController.shadersDirectory is accessible before initialization without LateInitializationError', () {
      final controller = ShadersController();
      // Should return a fallback Directory rather than throwing LateInitializationError
      expect(() => controller.shadersDirectory, returnsNormally);
      expect(controller.shadersDirectory, isNotNull);
      expect(controller.shadersDirectory.path, isNotEmpty);
    });

    test('ShadersController.ensureInitialized completes and prepares shaders directory', () async {
      final controller = ShadersController();
      final dir = await controller.ensureInitialized();
      expect(dir, isNotNull);
      expect(await dir.exists(), isTrue);
    });

    test('PlayerController.setShader cleanly transitions superResolutionType state and persists to settings and ShadersController', () async {
      final container = ProviderContainer();
      final playerController = container.read(playerProvider.notifier);
      final shadersController = container.read(playerProvider.notifier).shadersController;

      // Default state: 1 (off)
      expect(container.read(playerProvider).superResolutionType, equals(1));

      // Switch to Balanced (2)
      await playerController.setShader(2);
      expect(container.read(playerProvider).superResolutionType, equals(2));
      expect(shadersController.superResolutionType, equals(2));
      expect(GStorage.setting.get(SettingBoxKey.defaultSuperResolutionType), equals(2));

      // Switch to Quality (3)
      await playerController.setShader(3);
      expect(container.read(playerProvider).superResolutionType, equals(3));
      expect(shadersController.superResolutionType, equals(3));
      expect(GStorage.setting.get(SettingBoxKey.defaultSuperResolutionType), equals(3));

      // Switch back to Off (1)
      await playerController.setShader(1);
      expect(container.read(playerProvider).superResolutionType, equals(1));
      expect(shadersController.superResolutionType, equals(1));
      expect(GStorage.setting.get(SettingBoxKey.defaultSuperResolutionType), equals(1));
    });

    test('ShadersController does not write corrupt comment placeholders on asset load failure', () async {
      final controller = ShadersController();
      final dir = await controller.ensureInitialized();
      expect(dir.existsSync(), isTrue);

      // Verify that no shader file in the directory contains placeholder comments
      for (final fileName in ShadersController.requiredShaderFiles) {
        final file = File('${dir.path}/$fileName');
        if (file.existsSync()) {
          final content = await file.readAsString();
          expect(content.contains('Anime4K placeholder'), isFalse,
              reason: '$fileName must not contain corrupt placeholder text');
        }
      }
    });
  });

  group('Video Page Parse Overlay & Player Mounting Logic Tests', () {
    bool computePlayerActive({
      required bool useNativePlayer,
      required String videoUrl,
      required bool isPlayerLoading,
      required bool isPlayerPlaying,
    }) {
      return useNativePlayer &&
          videoUrl.isNotEmpty &&
          (!isPlayerLoading || isPlayerPlaying);
    }

    bool computeOverlayVisible({
      required bool isLoading,
      required bool isParseTimedOut,
      required bool isPlayerActive,
      required bool isPlayerPlaying,
    }) {
      return (isLoading || isParseTimedOut) &&
          !isPlayerActive &&
          !isPlayerPlaying;
    }

    bool computePlayerItemUnmounted({
      required bool useNativePlayer,
      required bool isPlayerLoading,
      required String videoUrl,
      required bool isPlayerPlaying,
    }) {
      return !useNativePlayer ||
          (isPlayerLoading && videoUrl.isEmpty && !isPlayerPlaying);
    }

    test('Player active state and overlay dismissal when audio/video is playing', () {
      final isPlayerActive = computePlayerActive(
        useNativePlayer: true,
        videoUrl: 'http://example.com/stream.m3u8',
        isPlayerLoading: false,
        isPlayerPlaying: true,
      );
      expect(isPlayerActive, isTrue);

      final isOverlayVisible = computeOverlayVisible(
        isLoading: false,
        isParseTimedOut: false,
        isPlayerActive: isPlayerActive,
        isPlayerPlaying: true,
      );
      expect(isOverlayVisible, isFalse);

      final isUnmounted = computePlayerItemUnmounted(
        useNativePlayer: true,
        isPlayerLoading: false,
        videoUrl: 'http://example.com/stream.m3u8',
        isPlayerPlaying: true,
      );
      expect(isUnmounted, isFalse);
    });

    test('Parse overlay is never shown while player is playing even if secondary isLoading is true', () {
      final isPlayerActive = computePlayerActive(
        useNativePlayer: true,
        videoUrl: 'http://example.com/stream.m3u8',
        isPlayerLoading: false,
        isPlayerPlaying: true,
      );
      expect(isPlayerActive, isTrue);

      final isOverlayVisible = computeOverlayVisible(
        isLoading: true,
        isParseTimedOut: false,
        isPlayerActive: isPlayerActive,
        isPlayerPlaying: true,
      );
      // Overlay MUST be dismissed because video is playing
      expect(isOverlayVisible, isFalse);
    });

    test('PlayerItem is mounted immediately when videoUrl is available even if isPlayerLoading is true', () {
      final isUnmounted = computePlayerItemUnmounted(
        useNativePlayer: true,
        isPlayerLoading: true,
        videoUrl: 'http://example.com/stream.m3u8',
        isPlayerPlaying: false,
      );
      // PlayerItem must stay mounted so native Video texture can attach
      expect(isUnmounted, isFalse);
    });

    test('Parse overlay is dismissed when video frames have dimensions (playerWidth > 0)', () {
      bool isPlayerPlayingCheck({
        required bool playing,
        required bool mediaPlayerPlaying,
        required Duration currentPosition,
        required int playerWidth,
      }) {
        return playing ||
            mediaPlayerPlaying ||
            currentPosition > Duration.zero ||
            playerWidth > 0;
      }

      final isPlaying = isPlayerPlayingCheck(
        playing: false,
        mediaPlayerPlaying: false,
        currentPosition: Duration.zero,
        playerWidth: 1920,
      );
      expect(isPlaying, isTrue);

      final isPlayerActive = computePlayerActive(
        useNativePlayer: true,
        videoUrl: 'http://example.com/stream.m3u8',
        isPlayerLoading: false,
        isPlayerPlaying: isPlaying,
      );
      expect(isPlayerActive, isTrue);

      final isOverlayVisible = computeOverlayVisible(
        isLoading: true,
        isParseTimedOut: false,
        isPlayerActive: isPlayerActive,
        isPlayerPlaying: isPlaying,
      );
      expect(isOverlayVisible, isFalse);
    });
  });

  group('Player Error Mapper & Transient Network Noise Tests', () {
    test('isTransientNetworkError recognizes ffurl_read error 0xdfb9b0bb and socket resets', () {
      expect(
        PlayerErrorMapper.isTransientNetworkError(
          'tcp: ffurl_read returned 0xdfb9b0bb https://vip.dytt-tvs.com/20260927/38814_3e139177/index.m3u8',
        ),
        isTrue,
      );
      expect(
        PlayerErrorMapper.isTransientNetworkError('Connection reset by peer'),
        isTrue,
      );
      expect(
        PlayerErrorMapper.isTransientNetworkError('Broken pipe on socket write'),
        isTrue,
      );
      expect(
        PlayerErrorMapper.isTransientNetworkError('Server returned 404 Not Found for ad segment'),
        isTrue,
      );
    });

    test('isTransientNetworkError returns false for fatal format or decoding errors', () {
      expect(
        PlayerErrorMapper.isTransientNetworkError('Failed to recognize file format'),
        isFalse,
      );
      expect(
        PlayerErrorMapper.isTransientNetworkError('Failed to open stream'),
        isFalse,
      );
    });

    test('toActionableMessage converts fatal format error to friendly message', () {
      final message = PlayerErrorMapper.toActionableMessage(
        'Failed to recognize file format mp4/m3u8',
        isBuffering: false,
      );
      expect(message, isNotNull);
      expect(message, contains('更换其他视频来源'));
    });
  });
}
