// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/playback/subtitle_matcher.dart';
import 'package:haipee/pages/player/player_controller.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:path/path.dart' as p;

/// 音频与字幕轨道控制及延迟微调面板（多规则自适应设计）
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

  /// 判断是否为 mpv 内部虚拟占位轨道 (auto / no)
  static bool isInternalPseudoTrackId(String? id) {
    if (id == null) return true;
    final normalized = id.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'auto' || normalized == 'no';
  }

  /// 将 ISO 语言代码转化为易读的中文名称
  static String? formatLanguageCode(String? rawLang) {
    if (rawLang == null) return null;
    final lang = rawLang.trim().toLowerCase();
    if (lang.isEmpty || lang == 'und' || lang == 'unknown' || lang == '未知语言') {
      return null;
    }
    switch (lang) {
      case 'zh':
      case 'chi':
      case 'zho':
      case 'cmn':
      case 'zh-cn':
      case 'zh_cn':
      case 'chs':
        return '简体中文';
      case 'zh-tw':
      case 'zh_tw':
      case 'zh-hk':
      case 'zh_hk':
      case 'cht':
      case 'tc':
        return '繁体中文';
      case 'yue':
      case 'cantonese':
        return '粤语';
      case 'ja':
      case 'jpn':
      case 'ja-jp':
        return '日语';
      case 'en':
      case 'eng':
      case 'en-us':
      case 'en-gb':
        return '英语';
      case 'ko':
      case 'kor':
        return '韩语';
      case 'ru':
      case 'rus':
        return '俄语';
      case 'fr':
      case 'fre':
      case 'fra':
        return '法语';
      case 'de':
      case 'ger':
      case 'deu':
        return '德语';
      case 'es':
      case 'spa':
        return '西班牙语';
      default:
        return rawLang.trim();
    }
  }

  /// 判断标题是否为无意义的流地址或长哈希
  static bool _isCrypticStreamTitle(String? title) {
    if (title == null) return true;
    final t = title.trim();
    if (t.isEmpty) return true;
    if (t.startsWith('http://') || t.startsWith('https://')) return true;
    if (t.contains('.m4s?') || t.contains('bilivideo.com')) return true;
    if (t.length > 64 && t.contains('&')) return true;
    return false;
  }

  /// 格式化音频轨道显示名称
  static String formatAudioTrackLabel(
    AudioTrack track,
    int index, {
    required bool isBili,
    required int totalCount,
  }) {
    final lang = formatLanguageCode(track.language);
    final rawTitle = track.title?.trim();
    final cleanTitle = _isCrypticStreamTitle(rawTitle) ? null : rawTitle;

    if (isBili && totalCount <= 1) {
      return 'B站原生高音质音频流 (DASH AAC)';
    }
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      if (lang != null && !cleanTitle.contains(lang)) {
        return '$cleanTitle ($lang)';
      }
      return cleanTitle;
    }
    if (totalCount <= 1) {
      return lang != null ? '默认原声音轨 ($lang)' : '默认原声音轨';
    }
    return lang != null ? '音轨 ${index + 1} · $lang' : '音轨 ${index + 1}';
  }

  /// 格式化字幕轨道显示名称
  static String formatSubtitleTrackLabel(SubtitleTrack track, int index) {
    final lang = formatLanguageCode(track.language);
    final rawTitle = track.title?.trim();
    final cleanTitle = _isCrypticStreamTitle(rawTitle) ? null : rawTitle;

    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      if (lang != null && !cleanTitle.contains(lang)) {
        return '$cleanTitle ($lang)';
      }
      return cleanTitle;
    }
    if (lang != null) {
      return '字幕轨 ${index + 1} · $lang';
    }
    return '内嵌字幕轨 ${index + 1}';
  }

  /// 识别当前播放所属的规则与流媒体类型标签
  static ({String badge, bool isBili, bool isLocalDisk, bool isIptv})
      _resolvePlaybackContext(PlayerController controller) {
    final isBili = controller.isBiliPlayback;
    final localPath = controller.activeLocalVideoArgs?.filePath;
    final isLocalDisk = localPath != null &&
        localPath.isNotEmpty &&
        !localPath.startsWith('http://') &&
        !localPath.startsWith('https://') &&
        !localPath.startsWith('bili://');

    bool isIptv = false;
    String pluginTypeLabel = '';
    try {
      final plugin = controller.videoPageController.currentPluginOrNull;
      if (plugin != null) {
        isIptv = plugin.isIptv;
        if (plugin.isIptv) {
          pluginTypeLabel = 'IPTV 直播流 · ${plugin.name}';
        } else if (plugin.isAlist) {
          pluginTypeLabel = 'AList 网盘直链 · ${plugin.name}';
        } else if (plugin.isCardigann) {
          pluginTypeLabel = 'BT 磁力流 · ${plugin.name}';
        } else if (plugin.type.toLowerCase() == 'tvbox') {
          pluginTypeLabel = 'TVBox 点播源 · ${plugin.name}';
        } else if (plugin.type.toLowerCase() == 'maccms') {
          pluginTypeLabel = 'MacCMS 影视源 · ${plugin.name}';
        } else if (plugin.name.isNotEmpty) {
          pluginTypeLabel = '在线影视源 · ${plugin.name}';
        }
      }
    } catch (_) {}

    if (isBili) {
      return (
        badge: 'B站 DASH 音画分离流',
        isBili: true,
        isLocalDisk: false,
        isIptv: false,
      );
    }
    if (isLocalDisk) {
      return (
        badge: '本地媒体文件',
        isBili: false,
        isLocalDisk: true,
        isIptv: false,
      );
    }
    if (controller.activeLocalVideoArgs?.torrentId != null) {
      return (
        badge: 'BT / 磁力边下边播流',
        isBili: false,
        isLocalDisk: false,
        isIptv: false,
      );
    }
    return (
      badge: pluginTypeLabel.isNotEmpty ? pluginTypeLabel : '在线流媒体 (HLS / MP4)',
      isBili: false,
      isLocalDisk: false,
      isIptv: isIptv,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerController = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final tracks = playerState.playerTracks;
    final rawAudioTracks = tracks?.audio ?? <AudioTrack>[];
    final rawSubtitleTracks = tracks?.subtitle ?? <SubtitleTrack>[];

    // 过滤掉 mpv 内部的 'auto' 与 'no' 虚拟轨道，避免展示令人困惑的 "#auto (未知语言)"
    final realAudioTracks = rawAudioTracks
        .where((t) => !isInternalPseudoTrackId(t.id))
        .toList();
    final realSubtitleTracks = rawSubtitleTracks
        .where((t) => !isInternalPseudoTrackId(t.id))
        .toList();

    final ctx = _resolvePlaybackContext(playerController);
    final currentSubId = playerState.currentSubtitleTrack?.id;
    final isSubtitleOff = isInternalPseudoTrackId(currentSubId) &&
        (currentSubId == 'no' || realSubtitleTracks.isEmpty);
    final hasActiveSubtitle = !isSubtitleOff && realSubtitleTracks.isNotEmpty;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withAlpha(102),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音频与字幕控制',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ctx.badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),

              // 1. 音频轨道 (Audio Tracks)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '音频轨道',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (realAudioTracks.length > 1)
                      Text(
                        '共 ${realAudioTracks.length} 条音轨可切换',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (realAudioTracks.length <= 1)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant.withAlpha(120),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              realAudioTracks.isEmpty
                                  ? (ctx.isBili
                                      ? 'B站原生高音质音频流 (DASH AAC)'
                                      : '默认原声音轨')
                                  : formatAudioTrackLabel(
                                      realAudioTracks.first,
                                      0,
                                      isBili: ctx.isBili,
                                      totalCount: 1,
                                    ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ctx.isBili
                                  ? '已通过双流引擎挂载独立音频流，当前源无其他多语言配音轨'
                                  : '当前视频源为单音轨流，已自动启用默认声道',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '当前生效',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...realAudioTracks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final track = entry.value;
                  final currentId = playerState.currentAudioTrack?.id;
                  final isSelected = currentId == track.id ||
                      (isInternalPseudoTrackId(currentId) && idx == 0);
                  final label = formatAudioTrackLabel(
                    track,
                    idx,
                    isBili: ctx.isBili,
                    totalCount: realAudioTracks.length,
                  );
                  return RadioListTile<AudioTrack>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
                    '字幕设置',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!ctx.isIptv)
                    Wrap(
                      spacing: 4,
                      children: [
                        if (ctx.isLocalDisk)
                          TextButton.icon(
                            onPressed: () async {
                              final videoPath =
                                  playerController.activeLocalVideoArgs!.filePath;
                              final dir = File(videoPath).parent;
                              if (!dir.existsSync()) {
                                HaipeeDialog.showToast(message: '目录不存在');
                                return;
                              }
                              final candidates = <SubtitleMatch>[];
                              final videoBase = p
                                  .basenameWithoutExtension(videoPath)
                                  .toLowerCase();
                              for (final entity in dir.listSync()) {
                                if (entity is File) {
                                  final fmt = SubtitleMatcher.extractFormat(
                                      entity.path);
                                  if (fmt != null &&
                                      const ['ass', 'srt', 'ssa', 'vtt', 'sub']
                                          .contains(fmt)) {
                                    final subBase = p
                                        .basenameWithoutExtension(entity.path)
                                        .toLowerCase();
                                    double conf = 0.5;
                                    if (subBase == videoBase) {
                                      conf = 1.0;
                                    } else if (subBase.contains(videoBase) ||
                                        videoBase.contains(subBase)) {
                                      conf = 0.85;
                                    }
                                    String lang = 'zh-CN';
                                    if (subBase.contains('en') ||
                                        subBase.contains('eng')) {
                                      lang = 'en-US';
                                    }
                                    if (subBase.contains('ja') ||
                                        subBase.contains('jpn')) {
                                      lang = 'ja-JP';
                                    }
                                    if (subBase.contains('tc') ||
                                        subBase.contains('cht')) {
                                      lang = 'zh-TW';
                                    }
                                    candidates.add(SubtitleMatch(
                                      url: entity.path,
                                      language: lang,
                                      confidence: conf,
                                      format: fmt,
                                    ));
                                  }
                                }
                              }
                              final best = SubtitleMatcher()
                                  .selectBestMatch(candidates);
                              if (best != null &&
                                  await SubtitleMatcher.validateSubtitleFile(
                                      best.url)) {
                                await playerController
                                    .loadExternalSubtitle(best.url);
                                HaipeeDialog.showToast(
                                    message:
                                        '智能匹配并挂载: ${p.basename(best.url)}');
                              } else {
                                HaipeeDialog.showToast(
                                    message: '未在同目录下找到可匹配的字幕');
                              }
                            },
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('同目录匹配'),
                          ),
                        TextButton.icon(
                          key: const Key('tracks_load_external_subtitle_btn'),
                          onPressed: () async {
                            if (AppLog.isFirebaseTestLab) {
                              return;
                            }
                            try {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowMultiple: true,
                                allowedExtensions: [
                                  'srt',
                                  'ass',
                                  'ssa',
                                  'vtt',
                                  'sub'
                                ],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                if (result.files.length == 1 &&
                                    result.files.single.path != null) {
                                  final filePath = result.files.single.path!;
                                  if (await SubtitleMatcher
                                      .validateSubtitleFile(filePath)) {
                                    await playerController
                                        .loadExternalSubtitle(filePath);
                                    HaipeeDialog.showToast(
                                        message:
                                            '已挂载外部字幕: ${p.basename(filePath)}');
                                  } else {
                                    HaipeeDialog.showToast(
                                        message: '字幕文件无效或为空');
                                  }
                                } else {
                                  final candidates = <SubtitleMatch>[];
                                  for (final file in result.files) {
                                    if (file.path != null) {
                                      final fmt =
                                          SubtitleMatcher.extractFormat(
                                              file.path!);
                                      final name = p
                                          .basenameWithoutExtension(file.path!)
                                          .toLowerCase();
                                      String lang = 'zh-CN';
                                      if (name.contains('en') ||
                                          name.contains('eng')) {
                                        lang = 'en-US';
                                      }
                                      if (name.contains('ja') ||
                                          name.contains('jpn')) {
                                        lang = 'ja-JP';
                                      }
                                      if (name.contains('tc') ||
                                          name.contains('cht')) {
                                        lang = 'zh-TW';
                                      }
                                      candidates.add(SubtitleMatch(
                                        url: file.path!,
                                        language: lang,
                                        confidence: 0.7,
                                        format: fmt,
                                      ));
                                    }
                                  }
                                  final best = SubtitleMatcher()
                                      .selectBestMatch(candidates);
                                  if (best != null &&
                                      await SubtitleMatcher
                                          .validateSubtitleFile(best.url)) {
                                    await playerController
                                        .loadExternalSubtitle(best.url);
                                    HaipeeDialog.showToast(
                                        message:
                                            '智能优选挂载: ${p.basename(best.url)}');
                                  }
                                }
                              }
                            } catch (e) {
                              HaipeeDialog.showToast(
                                  message: '加载外部字幕失败: $e');
                            }
                          },
                          icon:
                              const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('载入本地字幕'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (ctx.isIptv)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '当前为 IPTV 实时直播流，字幕由电视台画面内嵌推送。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    realSubtitleTracks.isEmpty
                        ? '无外挂软字幕 (使用视频原画内嵌字幕)'
                        : '关闭软字幕',
                  ),
                  value: 'no',
                  groupValue: isSubtitleOff ? 'no' : null,
                  onChanged: (_) {
                    playerController.setSubtitleTrack(SubtitleTrack.no());
                  },
                ),
                ...realSubtitleTracks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final track = entry.value;
                  final isSelected = !isSubtitleOff &&
                      (currentSubId == track.id ||
                          (currentSubId == 'auto' && idx == 0));
                  final label = formatSubtitleTrackLabel(track, idx);
                  return RadioListTile<SubtitleTrack>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
                if (realSubtitleTracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      ctx.isBili
                          ? '提示：B站视频默认使用原画字幕与弹幕；如需外挂字幕可点击右上角「载入本地字幕」挂载 .srt/.ass 文件。'
                          : '提示：多数在线影视源采用画面内嵌压制字幕；若播放生肉或无字幕片源，可点击「载入本地字幕」加载外部字幕。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],

              // 3. 字幕同步与延迟调节 (仅当存在外挂/软字幕或已设置偏移时展示)
              if (!ctx.isIptv &&
                  (hasActiveSubtitle || playerState.subtitleDelay != 0.0)) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '字幕时间轴微调: ${playerState.subtitleDelay >= 0 ? "+" : ""}${playerState.subtitleDelay.toStringAsFixed(1)} 秒',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
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
                  label:
                      '${playerState.subtitleDelay >= 0 ? "+" : ""}${playerState.subtitleDelay.toStringAsFixed(1)}s',
                  onChanged: (val) {
                    playerController.setSubtitleDelay((val * 10).round() / 10.0);
                  },
                ),
              ],

              // 4. AniSkip 智能跳过选项 (非直播流展示)
              if (!ctx.isIptv) ...[
                const SizedBox(height: 8),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自动跳过片头片尾 (AniSkip)'),
                  subtitle: const Text('番剧播放进入 OP/ED 区间时自动快进跳过'),
                  value: playerState.autoSkipOpEd,
                  onChanged: (val) {
                    playerController.setAutoSkipOpEd(val);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
