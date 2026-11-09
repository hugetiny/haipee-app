import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_ch_convert_tile.dart';
import 'package:haipee/pages/settings/danmaku/providers.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/modal_sheet/haipee_modal_sheet.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

const _dialogTitle = '恢复默认弹幕设置';
const _dialogContent = '弹幕样式和屏蔽词将恢复为默认值。';
const _cancelLabel = '取消';
const _confirmLabel = '恢复默认';
const _resetToast = '已恢复默认弹幕设置';

const _danmakuDurationLabel = '弹幕持续时间';
const _danmakuLineHeightLabel = '弹幕行高';
const _danmakuFollowSpeedLabel = '弹幕跟随视频倍速';
const _danmakuFollowSpeedDesc = '开启后弹幕速度会随视频倍速而改变';
const _danmakuDeduplicationLabel = '弹幕去重';
const _danmakuDeduplicationDesc = '相同内容弹幕过多时合并为一条弹幕';
const _danmakuBorderSizeLabel = '弹幕描边粗细';
const _danmakuResetTitle = '恢复默认设置';
const _danmakuResetDesc = '将弹幕相关设置恢复为默认值';

class DanmakuSettingsPage extends ConsumerStatefulWidget {
  const DanmakuSettingsPage({super.key});

  @override
  ConsumerState<DanmakuSettingsPage> createState() =>
      _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends ConsumerState<DanmakuSettingsPage> {
  late double _danmakuDuration;
  late double _danmakuLineHeight;
  late bool _danmakuFollowSpeed;
  late bool _danmakuDeduplication;
  late double _danmakuBorderSize;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  void _loadLocalSettings() {
    _danmakuDuration =
        GStorage.getSetting<double>(SettingsKeys.danmakuDuration);
    _danmakuLineHeight =
        GStorage.getSetting<double>(SettingsKeys.danmakuLineHeight);
    _danmakuFollowSpeed =
        GStorage.getSetting<bool>(SettingsKeys.danmakuFollowSpeed);
    _danmakuDeduplication =
        GStorage.getSetting<bool>(SettingsKeys.danmakuDeduplication);
    _danmakuBorderSize =
        GStorage.getSetting<double>(SettingsKeys.danmakuBorderSize);
  }

  void onBackPressed(BuildContext context) {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
  }

  String _maskSecret(BuildContext context, String secret) {
    if (secret.isEmpty) {
      return context.t.settings.player.danmakuCredentialNotConfigured;
    }
    if (secret.length <= 4) {
      return '*' * secret.length;
    }
    return '${secret.substring(0, 2)}****${secret.substring(secret.length - 2)}';
  }

  String _credentialModeLabel(
      BuildContext context, String appId, String apiKey) {
    final playerTexts = context.t.settings.player;
    if (appId.isNotEmpty || apiKey.isNotEmpty) {
      return playerTexts.danmakuCredentialModeCustom;
    }
    return GStorage.hasValidDanDanCredentials()
        ? playerTexts.danmakuCredentialModeBuiltIn
        : playerTexts.danmakuCredentialNotConfigured;
  }

  Future<void> _showDanDanCredentialDialog(
    BuildContext context,
    String currentAppId,
    String currentApiKey,
  ) async {
    final TextEditingController appIdController =
        TextEditingController(text: currentAppId);
    final TextEditingController apiKeyController =
        TextEditingController(text: currentApiKey);

    final playerTexts = context.t.settings.player;
    final appTexts = context.t.app;
    final toastTexts = playerTexts.toast;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AdaptiveDialogFrame(
          maxWidth: 480,
          title: Text(playerTexts.danmakuDanDanCredentials),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: appIdController,
                decoration: InputDecoration(
                  labelText: 'AppId',
                  hintText: playerTexts.danmakuCredentialHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: playerTexts.danmakuCredentialHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(appTexts.cancel),
            ),
            TextButton(
              onPressed: () async {
                final NavigatorState navigator = Navigator.of(dialogContext);
                await ref
                    .read(danmakuSettingsProvider.notifier)
                    .setDanDanCredentials('', '');
                navigator.pop();
                HaipeeDialog.showToast(
                  message: toastTexts.danmakuCredentialsRestored,
                );
              },
              child: Text(playerTexts.restoreDefault),
            ),
            FilledButton(
              onPressed: () async {
                final String appId = appIdController.text.trim();
                final String apiKey = apiKeyController.text.trim();
                final NavigatorState navigator = Navigator.of(dialogContext);
                await ref
                    .read(danmakuSettingsProvider.notifier)
                    .setDanDanCredentials(appId, apiKey);
                navigator.pop();
                HaipeeDialog.showToast(
                  message: toastTexts.danmakuCredentialsUpdated,
                );
              },
              child: Text(playerTexts.save),
            ),
          ],
        );
      },
    ).whenComplete(() {
      appIdController.dispose();
      apiKeyController.dispose();
    });
  }

  Future<void> resetDanmakuSettings() async {
    final bool shouldReset = await HaipeeModalSheet.showConfirmation(
          context: context,
          title: _dialogTitle,
          message: _dialogContent,
          cancelText: _cancelLabel,
          confirmText: _confirmLabel,
          isDestructive: true,
        ) ??
        false;
    if (!shouldReset) return;

    await GStorage.resetDanmakuSettings();
    if (!mounted) return;
    setState(() {
      _loadLocalSettings();
    });
    HaipeeDialog.showToast(message: _resetToast);
  }

  @override
  Widget build(BuildContext context) {
    final translations = context.t;
    final playerTexts = translations.settings.player;
    final sourcesTexts = playerTexts.danmakuSources;
    final danmakuSettings = ref.watch(danmakuSettingsProvider);

    final String maskedApiKey =
        _maskSecret(context, danmakuSettings.danDanApiKeyOverride);
    final String displayAppId = danmakuSettings.danDanAppIdOverride.isEmpty
        ? playerTexts.danmakuCredentialNotConfigured
        : danmakuSettings.danDanAppIdOverride;
    final String credentialSummary = playerTexts.danmakuCredentialsSummary
        .replaceFirst('{appId}', displayAppId)
        .replaceFirst('{apiKey}', maskedApiKey);

    return SettingsDetailScaffold(
      title: Text(playerTexts.danmakuSettings),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(playerTexts.danmaku),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.subtitles_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuEnabledByDefault(
                          value ?? !danmakuSettings.danmakuEnabledByDefault);
                },
                title: Text(playerTexts.danmakuDefaultOn),
                description: Text(playerTexts.danmakuDefaultOnDesc),
                initialValue: danmakuSettings.danmakuEnabledByDefault,
              ),
            ],
          ),
          SettingsSection(
            title: Text(playerTexts.danmakuSource),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.video_collection_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuBiliBiliSource(
                          value ?? !danmakuSettings.danmakuBiliBiliSource);
                },
                title: Text(sourcesTexts.bilibili),
                initialValue: danmakuSettings.danmakuBiliBiliSource,
              ),
              SettingsTile.switchTile(
                leading: Icons.sports_esports_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuGamerSource(
                          value ?? !danmakuSettings.danmakuGamerSource);
                },
                title: Text(sourcesTexts.gamer),
                initialValue: danmakuSettings.danmakuGamerSource,
              ),
              SettingsTile.switchTile(
                leading: Icons.cloud_download_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuDanDanSource(
                          value ?? !danmakuSettings.danmakuDanDanSource);
                },
                title: Text(sourcesTexts.dandan),
                initialValue: danmakuSettings.danmakuDanDanSource,
              ),
              SettingsTile(
                leading: Icons.key_rounded,
                onPressed: (_) => _showDanDanCredentialDialog(
                  context,
                  danmakuSettings.danDanAppIdOverride,
                  danmakuSettings.danDanApiKeyOverride,
                ),
                title: Text(playerTexts.danmakuDanDanCredentials),
                value: Text(_credentialModeLabel(
                  context,
                  danmakuSettings.danDanAppIdOverride,
                  danmakuSettings.danDanApiKeyOverride,
                )),
                description: Text(
                  credentialSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(playerTexts.danmakuShield),
            tiles: [
              SettingsTile(
                leading: Icons.block_rounded,
                onPressed: (_) {
                  context.push(Routes.settingsDanmakuShield);
                },
                title: Text(playerTexts.danmakuKeywordShield),
              ),
            ],
          ),
          SettingsSection(
            title: Text(playerTexts.danmakuDisplay),
            tiles: [
              const DanmakuChConvertTile(),
              SettingsSliderTile(
                leading: const Icon(Icons.crop_free_rounded),
                title: Text(playerTexts.danmakuArea),
                value: danmakuSettings.danmakuArea,
                min: 0,
                max: 1,
                divisions: 8,
                valueLabel: '${(danmakuSettings.danmakuArea * 100).round()}%',
                onChanged: (value) {
                  ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuArea(value);
                },
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.timer_rounded),
                title: const Text(_danmakuDurationLabel),
                value: _danmakuDuration,
                min: 2,
                max: 16,
                divisions: 14,
                valueLabel: '${_danmakuDuration.round()} 秒',
                onChanged: (value) {
                  final rounded = value.roundToDouble();
                  setState(() => _danmakuDuration = rounded);
                  GStorage.putSetting<double>(
                      SettingsKeys.danmakuDuration, rounded);
                },
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.format_line_spacing_rounded),
                title: const Text(_danmakuLineHeightLabel),
                value: _danmakuLineHeight,
                min: 0,
                max: 3,
                divisions: 30,
                valueLabel: _danmakuLineHeight.toStringAsFixed(1),
                onChanged: (value) {
                  final fixed = double.parse(value.toStringAsFixed(1));
                  setState(() => _danmakuLineHeight = fixed);
                  GStorage.putSetting<double>(
                      SettingsKeys.danmakuLineHeight, fixed);
                },
              ),
              SettingsTile.switchTile(
                leading: Icons.speed_rounded,
                onToggle: (value) async {
                  setState(() =>
                      _danmakuFollowSpeed = value ?? !_danmakuFollowSpeed);
                  await GStorage.putSetting<bool>(
                      SettingsKeys.danmakuFollowSpeed, _danmakuFollowSpeed);
                },
                title: const Text(_danmakuFollowSpeedLabel),
                description: const Text(_danmakuFollowSpeedDesc),
                initialValue: _danmakuFollowSpeed,
              ),
              SettingsTile.switchTile(
                leading: Icons.vertical_align_top_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuTop(value ?? !danmakuSettings.danmakuTop);
                },
                title: Text(playerTexts.danmakuTopDisplay),
                initialValue: danmakuSettings.danmakuTop,
              ),
              SettingsTile.switchTile(
                leading: Icons.vertical_align_bottom_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuBottom(
                          value ?? !danmakuSettings.danmakuBottom);
                },
                title: Text(playerTexts.danmakuBottomDisplay),
                initialValue: danmakuSettings.danmakuBottom,
              ),
              SettingsTile.switchTile(
                leading: Icons.swap_horiz_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuScroll(
                          value ?? !danmakuSettings.danmakuScroll);
                },
                title: Text(playerTexts.danmakuScrollDisplay),
                initialValue: danmakuSettings.danmakuScroll,
              ),
              SettingsTile.switchTile(
                leading: Icons.layers_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuMassive(
                          value ?? !danmakuSettings.danmakuMassive);
                },
                title: Text(playerTexts.danmakuMassiveDisplay),
                description: Text(playerTexts.danmakuMassiveDescription),
                initialValue: danmakuSettings.danmakuMassive,
              ),
              SettingsTile.switchTile(
                leading: Icons.filter_alt_rounded,
                onToggle: (value) async {
                  setState(() =>
                      _danmakuDeduplication = value ?? !_danmakuDeduplication);
                  await GStorage.putSetting<bool>(
                      SettingsKeys.danmakuDeduplication,
                      _danmakuDeduplication);
                },
                title: const Text(_danmakuDeduplicationLabel),
                description: const Text(_danmakuDeduplicationDesc),
                initialValue: _danmakuDeduplication,
              ),
            ],
          ),
          SettingsSection(
            title: Text(playerTexts.danmakuStyle),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.border_color_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuBorder(
                          value ?? !danmakuSettings.danmakuBorder);
                },
                title: Text(playerTexts.danmakuOutline),
                initialValue: danmakuSettings.danmakuBorder,
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.line_weight_rounded),
                title: const Text(_danmakuBorderSizeLabel),
                value: _danmakuBorderSize,
                min: 0.1,
                max: 3,
                divisions: 29,
                valueLabel: _danmakuBorderSize.toStringAsFixed(1),
                onChanged: (value) {
                  final fixed = double.parse(value.toStringAsFixed(1));
                  setState(() => _danmakuBorderSize = fixed);
                  GStorage.putSetting<double>(
                      SettingsKeys.danmakuBorderSize, fixed);
                },
              ),
              SettingsTile.switchTile(
                leading: Icons.palette_rounded,
                onToggle: (value) async {
                  await ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuColor(
                          value ?? !danmakuSettings.danmakuColor);
                },
                title: Text(playerTexts.danmakuColor),
                initialValue: danmakuSettings.danmakuColor,
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.format_size_rounded),
                title: Text(playerTexts.danmakuFontSize),
                value: danmakuSettings.danmakuFontSize,
                min: 10,
                max: Utils.isCompact() ? 32 : 48,
                divisions: (Utils.isCompact() ? 22 : 38),
                valueLabel: '${danmakuSettings.danmakuFontSize.floor()}',
                onChanged: (value) {
                  ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuFontSize(value.floorToDouble());
                },
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.format_bold_rounded),
                title: Text(playerTexts.danmakuFontWeight),
                value: danmakuSettings.danmakuFontWeight.toDouble(),
                min: 1,
                max: 9,
                divisions: 8,
                valueLabel: '${danmakuSettings.danmakuFontWeight}',
                onChanged: (value) {
                  ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuFontWeight(value.toInt());
                },
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.opacity_rounded),
                title: Text(playerTexts.danmakuOpacity),
                value: danmakuSettings.danmakuOpacity,
                min: 0.1,
                max: 1,
                divisions: 9,
                valueLabel:
                    '${(danmakuSettings.danmakuOpacity * 100).round()}%',
                onChanged: (value) {
                  ref.read(danmakuSettingsProvider.notifier).setDanmakuOpacity(
                      double.parse(value.toStringAsFixed(2)));
                },
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              SettingsTile(
                leading: Icons.settings_backup_restore_rounded,
                onPressed: (_) => resetDanmakuSettings(),
                title: const Text(_danmakuResetTitle),
                description: const Text(_danmakuResetDesc),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
