import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:haipee/pages/player/player_providers.dart';

class PlayerItemSurface extends ConsumerWidget {
  const PlayerItemSurface({super.key});

  static bool isAudioUrl(String url) {
    const audioExts = [
      '.mp3',
      '.flac',
      '.wav',
      '.ape',
      '.dsd',
      '.alac',
      '.ogg',
      '.m4a',
      '.aac',
      '.opus',
      '.wma',
      '.dsf',
      '.dff',
    ];
    final clean = url.split('?').first.split('#').first.toLowerCase();
    return audioExts.any((ext) => clean.endsWith(ext));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerController = ref.watch(playerProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final videoController = playerController.videoController;

    if (videoController == null) {
      return const SizedBox.shrink();
    }

    final fit = switch (playerState.aspectRatioType) {
      1 => BoxFit.contain,
      2 => BoxFit.cover,
      _ => BoxFit.fill,
    };

    return Video(
      controller: videoController,
      controls: NoVideoControls,
      fit: fit,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style: TextStyle(
          color: Colors.pink,
          fontSize: 48.0,
          background: Paint()..color = Colors.transparent,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 3.0,
              color: Color.fromARGB(255, 255, 255, 255),
            ),
            Shadow(
              offset: Offset(-1.0, -1.0),
              blurRadius: 3.0,
              color: Color.fromARGB(125, 255, 255, 255),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        padding: EdgeInsets.all(24.0),
      ),
    );
  }
}
