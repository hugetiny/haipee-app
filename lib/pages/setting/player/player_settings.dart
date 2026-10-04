import 'dart:io';
import 'package:card_settings_ui/card_settings_ui.dart';
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
          maxWidth: 1000,
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
          ],
        ),
      ),
    );
  }
}
