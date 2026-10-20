// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/playback/subtitle_matcher.dart';
import 'package:kazumi/pages/player/player_providers.dart';
import 'package:path/path.dart' as p;

/// 音频与字幕轨道控制及延迟微调面板
class TracksSettingsSheet extends ConsumerWidget {
  const TracksSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TracksSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerController = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);

    final tracks = playerState.playerTracks;
    final audioTracks = tracks?.audio ?? <AudioTrack>[];
    final subtitleTracks = tracks?.subtitle ?? <SubtitleTrack>[];

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '音频与字幕控制',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),

              // 1. 音频轨道 (Audio Tracks)
              Text(
                '音频轨道',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (audioTracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '默认音频 (无多音轨)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...audioTracks.map((track) {
                  final isSelected = playerState.currentAudioTrack == track ||
                      (playerState.currentAudioTrack is AudioTrack &&
                          (playerState.currentAudioTrack as AudioTrack).id == track.id);
                  final label = track.title?.isNotEmpty == true
                      ? '${track.title} (${track.language ?? "未知语言"})'
                      : '音轨 #${track.id} (${track.language ?? "未知语言"})';
                  return RadioListTile<AudioTrack>(
                    dense: true,
                    title: Text(label),
                    value: track,
                    groupValue: isSelected ? track : null,
                    onChanged: (val) {
                      if (val != null) {
                        playerController.setAudioTrack(val);
                      }
                    },
                  );
                }),

              const SizedBox(height: 12),
              const Divider(),

              // 2. 字幕轨道 (Subtitle Tracks)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '字幕轨道',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (playerController.activeLocalVideoArgs?.filePath != null &&
                          !playerController.activeLocalVideoArgs!.filePath.startsWith('http'))
                        TextButton.icon(
                          onPressed: () async {
                            final videoPath = playerController.activeLocalVideoArgs!.filePath;
                            final dir = File(videoPath).parent;
                            if (!dir.existsSync()) {
                              KazumiDialog.showToast(message: '目录不存在');
                              return;
                            }
                            final candidates = <SubtitleMatch>[];
                            final videoBase = p.basenameWithoutExtension(videoPath).toLowerCase();
                            for (final entity in dir.listSync()) {
                              if (entity is File) {
                                final fmt = SubtitleMatcher.extractFormat(entity.path);
                                if (fmt != null && const ['ass', 'srt', 'ssa', 'vtt', 'sub'].contains(fmt)) {
                                  final subBase = p.basenameWithoutExtension(entity.path).toLowerCase();
                                  double conf = 0.5;
                                  if (subBase == videoBase) {
                                    conf = 1.0;
                                  } else if (subBase.contains(videoBase) || videoBase.contains(subBase)) {
                                    conf = 0.85;
                                  }
                                  String lang = 'zh-CN';
                                  if (subBase.contains('en') || subBase.contains('eng')) lang = 'en-US';
                                  if (subBase.contains('ja') || subBase.contains('jpn')) lang = 'ja-JP';
                                  if (subBase.contains('tc') || subBase.contains('cht')) lang = 'zh-TW';
                                  candidates.add(SubtitleMatch(
                                    url: entity.path,
                                    language: lang,
                                    confidence: conf,
                                    format: fmt,
                                  ));
                                }
                              }
                            }
                            final best = SubtitleMatcher().selectBestMatch(candidates);
                            if (best != null && await SubtitleMatcher.validateSubtitleFile(best.url)) {
                              await playerController.loadExternalSubtitle(best.url);
                              KazumiDialog.showToast(message: '智能匹配并挂载: ${p.basename(best.url)}');
                            } else {
                              KazumiDialog.showToast(message: '未在同目录下找到可匹配的字幕');
                            }
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('同目录匹配'),
                        ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowMultiple: true,
                              allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              if (result.files.length == 1 && result.files.single.path != null) {
                                final filePath = result.files.single.path!;
                                if (await SubtitleMatcher.validateSubtitleFile(filePath)) {
                                  await playerController.loadExternalSubtitle(filePath);
                                  KazumiDialog.showToast(message: '已挂载外部字幕: ${p.basename(filePath)}');
                                } else {
                                  KazumiDialog.showToast(message: '字幕文件无效或为空');
                                }
                              } else {
                                final candidates = <SubtitleMatch>[];
                                for (final file in result.files) {
                                  if (file.path != null) {
                                    final fmt = SubtitleMatcher.extractFormat(file.path!);
                                    final name = p.basenameWithoutExtension(file.path!).toLowerCase();
                                    String lang = 'zh-CN';
                                    if (name.contains('en') || name.contains('eng')) lang = 'en-US';
                                    if (name.contains('ja') || name.contains('jpn')) lang = 'ja-JP';
                                    if (name.contains('tc') || name.contains('cht')) lang = 'zh-TW';
                                    candidates.add(SubtitleMatch(
                                      url: file.path!,
                                      language: lang,
                                      confidence: 0.7,
                                      format: fmt,
                                    ));
                                  }
                                }
                                final best = SubtitleMatcher().selectBestMatch(candidates);
                                if (best != null && await SubtitleMatcher.validateSubtitleFile(best.url)) {
                                  await playerController.loadExternalSubtitle(best.url);
                                  KazumiDialog.showToast(message: '智能优选挂载: ${p.basename(best.url)}');
                                }
                              }
                            }
                          } catch (e) {
                            KazumiDialog.showToast(message: '加载外部字幕失败: $e');
                          }
                        },
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('载入字幕'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RadioListTile<String>(
                dense: true,
                title: const Text('关闭字幕'),
                value: 'no',
                groupValue: (playerState.currentSubtitleTrack is SubtitleTrack &&
                        (playerState.currentSubtitleTrack as SubtitleTrack).id == 'no')
                    ? 'no'
                    : null,
                onChanged: (_) {
                  playerController.setSubtitleTrack(SubtitleTrack.no());
                },
              ),
              ...subtitleTracks.map((track) {
                final isSelected = playerState.currentSubtitleTrack == track ||
                    (playerState.currentSubtitleTrack is SubtitleTrack &&
                        (playerState.currentSubtitleTrack as SubtitleTrack).id == track.id);
                final label = track.title?.isNotEmpty == true
                    ? '${track.title} (${track.language ?? "未知语言"})'
                    : '字幕 #${track.id} (${track.language ?? "未知语言"})';
                return RadioListTile<SubtitleTrack>(
                  dense: true,
                  title: Text(label),
                  value: track,
                  groupValue: isSelected ? track : null,
                  onChanged: (val) {
                    if (val != null) {
                      playerController.setSubtitleTrack(val);
                    }
                  },
                );
              }),

              const SizedBox(height: 12),
              const Divider(),

              // 3. 字幕同步与延迟调节 (Subtitle Delay)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '字幕同步调节: ${playerState.subtitleDelay >= 0 ? "+" : ""}${playerState.subtitleDelay.toStringAsFixed(1)} 秒',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (playerState.subtitleDelay != 0.0)
                    TextButton(
                      onPressed: () => playerController.setSubtitleDelay(0.0),
                      child: const Text('重置为 0s'),
                    ),
                ],
              ),
              Slider(
                min: -5.0,
                max: 5.0,
                divisions: 100,
                value: playerState.subtitleDelay.clamp(-5.0, 5.0),
                label: '${playerState.subtitleDelay >= 0 ? "+" : ""}${playerState.subtitleDelay.toStringAsFixed(1)}s',
                onChanged: (val) {
                  playerController.setSubtitleDelay((val * 10).round() / 10.0);
                },
              ),

              const SizedBox(height: 8),
              const Divider(),

              // 4. AniSkip 智能跳过选项
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动跳过片头片尾 (AniSkip)'),
                subtitle: const Text('播放进入 OP/ED 区间时毫秒级自动快进'),
                value: playerState.autoSkipOpEd,
                onChanged: (val) {
                  playerController.setAutoSkipOpEd(val);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
