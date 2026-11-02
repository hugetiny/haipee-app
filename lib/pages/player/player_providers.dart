import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:haipee/pages/player/player_state.dart';
import 'package:haipee/services/player/audio_controller.dart';
import 'package:haipee/services/player/screenshot_export_service.dart';

/// 播放器控制 Provider
///
/// 管理 media-kit 播放器实例、弹幕、字幕和播放控制。
/// 支持画面比例、倍速、滤镜和 SyncPlay 同步。
///
/// 示例:
/// ```dart
/// final controller = ref.read(playerProvider.notifier);
/// await controller.playVideo(url, bangumiId);
/// ```
final playerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

/// 后台音频与系统媒体控制服务 Provider
final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController();
  ref.onDispose(() {
    controller.deactivate();
  });
  return controller;
});

/// 截图导出服务 Provider
final screenshotExportServiceProvider = Provider<ScreenshotExportService>((ref) {
  return const ScreenshotExportService();
});
