import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/pages/settings/danmaku/providers.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';

class DanmakuSettingsPage extends ConsumerWidget {
  const DanmakuSettingsPage({super.key});

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
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
    WidgetRef ref,
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
        return AlertDialog(
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
                KazumiDialog.showToast(
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
                KazumiDialog.showToast(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = context.t;
    final playerTexts = translations.settings.player;
    final sourcesTexts = playerTexts.danmakuSources;

    // ✅ Watch danmaku settings from Riverpod provider
    final danmakuSettings = ref.watch(danmakuSettingsProvider);

    final String maskedApiKey =
        _maskSecret(context, danmakuSettings.danDanApiKeyOverride);
    final String displayAppId = danmakuSettings.danDanAppIdOverride.isEmpty
        ? playerTexts.danmakuCredentialNotConfigured
        : danmakuSettings.danDanAppIdOverride;
    final String credentialSummary = playerTexts.danmakuCredentialsSummary
        .replaceFirst('{appId}', displayAppId)
        .replaceFirst('{apiKey}', maskedApiKey);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(title: Text(playerTexts.danmakuSettings)),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: Text(playerTexts.danmaku),
              tiles: [
                SettingsTile.switchTile(
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
                  onToggle: (value) async {
                    await ref
                        .read(danmakuSettingsProvider.notifier)
                        .setDanmakuDanDanSource(
                            value ?? !danmakuSettings.danmakuDanDanSource);
                  },
                  title: Text(sourcesTexts.dandan),
                  initialValue: danmakuSettings.danmakuDanDanSource,
                ),
                SettingsTile.navigation(
                  onPressed: (_) => _showDanDanCredentialDialog(
                    context,
                    ref,
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
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsDanmakuShield);
                  },
                  title: Text(playerTexts.danmakuKeywordShield),
                ),
              ],
            ),
            SettingsSection(
              title: Text(playerTexts.danmakuConvert),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    showModalBottomSheet(
                      context: context,
                      builder: (bottomSheetContext) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final mode in DanmakuChConvert.values)
                                ListTile(
                                  title: Text(switch (mode) {
                                    DanmakuChConvert.none =>
                                      playerTexts.danmakuConvertNone,
                                    DanmakuChConvert.simplified =>
                                      playerTexts.danmakuConvertSimplified,
                                    DanmakuChConvert.traditional =>
                                      playerTexts.danmakuConvertTraditional,
                                  }),
                                  trailing: danmakuSettings.danmakuChConvert == mode
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () {
                                    ref
                                        .read(danmakuSettingsProvider.notifier)
                                        .setDanmakuChConvert(mode);
                                    Navigator.pop(bottomSheetContext);
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  title: Text(playerTexts.danmakuConvertTitle),
                  description: Text(playerTexts.danmakuConvertDesc),
                  value: Text(switch (danmakuSettings.danmakuChConvert) {
                    DanmakuChConvert.none => playerTexts.danmakuConvertNone,
                    DanmakuChConvert.simplified =>
                      playerTexts.danmakuConvertSimplified,
                    DanmakuChConvert.traditional =>
                      playerTexts.danmakuConvertTraditional,
                  }),
                ),
              ],
            ),
            SettingsSection(
              title: Text(playerTexts.danmakuDisplay),
              tiles: [
                SettingsTile(
                  title: Text(playerTexts.danmakuArea),
                  description: Slider(
                    value: danmakuSettings.danmakuArea,
                    min: 0,
                    max: 1,
                    divisions: 4,
                    label: '${(danmakuSettings.danmakuArea * 100).round()}%',
                    onChanged: (value) {
                      ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuArea(value);
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(danmakuSettingsProvider.notifier)
                        .setDanmakuTop(value ?? !danmakuSettings.danmakuTop);
                  },
                  title: Text(playerTexts.danmakuTopDisplay),
                  initialValue: danmakuSettings.danmakuTop,
                ),
                SettingsTile.switchTile(
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
              ],
            ),
            SettingsSection(
              title: Text(playerTexts.danmakuStyle),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(danmakuSettingsProvider.notifier)
                        .setDanmakuBorder(
                            value ?? !danmakuSettings.danmakuBorder);
                  },
                  title: Text(playerTexts.danmakuOutline),
                  initialValue: danmakuSettings.danmakuBorder,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(danmakuSettingsProvider.notifier)
                        .setDanmakuColor(
                            value ?? !danmakuSettings.danmakuColor);
                  },
                  title: Text(playerTexts.danmakuColor),
                  initialValue: danmakuSettings.danmakuColor,
                ),
                SettingsTile(
                  title: Text(playerTexts.danmakuFontSize),
                  description: Slider(
                    value: danmakuSettings.danmakuFontSize,
                    min: 10,
                    max: Utils.isCompact() ? 32 : 48,
                    label: '${danmakuSettings.danmakuFontSize.floorToDouble()}',
                    onChanged: (value) {
                      ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuFontSize(value.floorToDouble());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text(playerTexts.danmakuFontWeight),
                  description: Slider(
                    value: danmakuSettings.danmakuFontWeight.toDouble(),
                    min: 1,
                    max: 9,
                    divisions: 8,
                    label: '${danmakuSettings.danmakuFontWeight}',
                    onChanged: (value) {
                      ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuFontWeight(value.toInt());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text(playerTexts.danmakuOpacity),
                  description: Slider(
                    value: danmakuSettings.danmakuOpacity,
                    min: 0.1,
                    max: 1,
                    label: '${(danmakuSettings.danmakuOpacity * 100).round()}%',
                    onChanged: (value) {
                      ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuOpacity(
                              double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
