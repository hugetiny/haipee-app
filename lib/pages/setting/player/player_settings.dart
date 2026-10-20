import 'dart:io';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class PlayerSettingsPage extends ConsumerStatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  ConsumerState<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends ConsumerState<PlayerSettingsPage> {
  final Box setting = GStorage.setting;
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    // Provider will initialize itself from storage in its build() method.
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
    }
  }

  void updateDefaultPlaySpeed(double speed) {
    setting.put(SettingBoxKey.defaultPlaySpeed, speed);
    ref.read(playerSettingsProvider.notifier).setDefaultPlaySpeed(speed);
  }

  void updateDefaultAspectRatioType(int type) {
    setting.put(SettingBoxKey.defaultAspectRatioType, type);
    ref.read(playerSettingsProvider.notifier).setDefaultAspectRatioType(type);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final playerState = ref.watch(playerSettingsProvider);
    final aspectRatioLabels = {
      1: t.settings.player.aspectRatio.auto,
      2: t.settings.player.aspectRatio.crop,
      3: t.settings.player.aspectRatio.stretch,
    };
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(title: Text(t.settings.player.playerSettings)),
        body: SettingsList(
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.hAenable;
                    await setting.put(SettingBoxKey.hAenable, v);
                    ref.read(playerSettingsProvider.notifier).setHAEnable(v);
                  },
                  title: Text(t.settings.player.hardwareDecoding),
                  initialValue: playerState.hAenable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    context.push(Routes.settingsPlayerDecoder);
                  },
                  title: Text(t.settings.player.hardwareDecoder),
                  description: Text(t.settings.player.hardwareDecoderDesc),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.lowMemoryMode;
                    await setting.put(SettingBoxKey.lowMemoryMode, v);
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setLowMemoryMode(v);
                  },
                  title: Text(t.settings.player.lowMemoryMode),
                  description: Text(t.settings.player.lowMemoryModeDesc),
                  initialValue: playerState.lowMemoryMode,
                ),
                if (Platform.isAndroid)
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      final v = value ?? !playerState.androidEnableOpenSLES;
                      await setting.put(SettingBoxKey.androidEnableOpenSLES, v);
                      ref
                          .read(playerSettingsProvider.notifier)
                          .setAndroidEnableOpenSLES(v);
                    },
                    title: Text(t.settings.player.lowLatencyAudio),
                    description: Text(t.settings.player.lowLatencyAudioDesc),
                    initialValue: playerState.androidEnableOpenSLES,
                  ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    context.push(Routes.settingsPlayerSuper);
                  },
                  title: Text(t.settings.player.superResolution),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.playResume;
                    await setting.put(SettingBoxKey.playResume, v);
                    ref.read(playerSettingsProvider.notifier).setPlayResume(v);
                  },
                  title: Text(t.settings.player.autoJump),
                  description: Text(t.settings.player.autoJumpDesc),
                  initialValue: playerState.playResume,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.playerDisableAnimations;
                    await setting.put(SettingBoxKey.playerDisableAnimations, v);
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setPlayerDisableAnimations(v);
                  },
                  title: Text(t.settings.player.disableAnimations),
                  description: Text(t.settings.player.disableAnimationsDesc),
                  initialValue: playerState.playerDisableAnimations,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.showPlayerError;
                    await setting.put(SettingBoxKey.showPlayerError, v);
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setShowPlayerError(v);
                  },
                  title: Text(t.settings.player.errorPrompt),
                  description: Text(t.settings.player.errorPromptDesc),
                  initialValue: playerState.showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.playerDebugMode;
                    await setting.put(SettingBoxKey.playerDebugMode, v);
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setPlayerDebugMode(v);
                  },
                  title: Text(t.settings.player.debugMode),
                  description: Text(t.settings.player.debugModeDesc),
                  initialValue: playerState.playerDebugMode,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.privateMode;
                    await setting.put(SettingBoxKey.privateMode, v);
                    ref.read(playerSettingsProvider.notifier).setPrivateMode(v);
                  },
                  title: Text(t.settings.player.privateMode),
                  description: Text(t.settings.player.privateModeDesc),
                  initialValue: playerState.privateMode,
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile(
                  title: Text(t.settings.player.defaultPlaySpeed),
                  description: Slider(
                    value: playerState.defaultPlaySpeed,
                    min: 0.25,
                    max: 3,
                    divisions: 11,
                    label: '${playerState.defaultPlaySpeed}x',
                    onChanged: (value) {
                      updateDefaultPlaySpeed(
                        double.parse(value.toStringAsFixed(2)),
                      );
                    },
                  ),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  },
                  title: Text(t.settings.player.defaultVideoAspectRatio),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: menuController,
                    builder: (_, __, ___) {
                      return Text(
                        aspectRatioLabels[playerState.defaultAspectRatioType] ??
                            t.settings.player.aspectRatio.auto,
                      );
                    },
                    menuChildren: [
                      for (final entry in aspectRatioTypeMap.entries)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () =>
                              updateDefaultAspectRatioType(entry.key),
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                aspectRatioLabels[entry.key] ??
                                    t.settings.player.aspectRatio.auto,
                                style: TextStyle(
                                  color: entry.key ==
                                          playerState.defaultAspectRatioType
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: const Text('智能跳过与云加速'),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final v = value ?? !playerState.autoSkipOpEd;
                    await setting.put(SettingBoxKey.autoSkipOpEd, v);
                    ref.read(playerSettingsProvider.notifier).setAutoSkipOpEd(v);
                  },
                  title: const Text('自动跳过片头片尾 (AniSkip)'),
                  description: const Text('播放进入 OP/ED 或总集篇区间时毫秒级自动跳过'),
                  initialValue: playerState.autoSkipOpEd,
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    _showDebridConfigDialog(context);
                  },
                  title: const Text('Debrid 云端高速离线加速'),
                  description: Text(
                    (setting.get(SettingBoxKey.debridProvider, defaultValue: 'none') as String) == 'none'
                        ? '未启用 (默认本地 P2P)'
                        : '已启用: ${(setting.get(SettingBoxKey.debridProvider) as String).toUpperCase()}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDebridConfigDialog(BuildContext context) {
    final currentProvider =
        setting.get(SettingBoxKey.debridProvider, defaultValue: 'none') as String;
    final currentApiKey =
        setting.get(SettingBoxKey.debridApiKey, defaultValue: '') as String;
    String selectedProvider = currentProvider;
    final textController = TextEditingController(text: currentApiKey);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Debrid 云端加速设置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择云加速提供商 (BYOT 自备 Key):'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedProvider,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('关闭 (仅本地 P2P)')),
                      DropdownMenuItem(value: 'realdebrid', child: Text('Real-Debrid')),
                      DropdownMenuItem(value: 'torbox', child: Text('TorBox')),
                      DropdownMenuItem(value: 'pikpak', child: Text('PikPak')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedProvider = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedProvider != 'none') ...[
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        labelText: selectedProvider == 'pikpak'
                            ? 'PikPak Token / Password'
                            : 'API Token / Key',
                        hintText: '请输入您的密钥',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  await setting.put(SettingBoxKey.debridProvider, selectedProvider);
                  await setting.put(
                      SettingBoxKey.debridApiKey, textController.text.trim());
                  if (context.mounted) {
                    setState(() {});
                    Navigator.of(ctx).pop();
                    KazumiDialog.showToast(message: 'Debrid 配置已保存');
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
