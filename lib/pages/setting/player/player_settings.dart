import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/modal_sheet/haipee_modal_sheet.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/settings/settings_list.dart';
import 'package:haipee/modules/bilibili/bilibili_auth_service.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:haipee/pages/player/controller/player_aspect_ratio.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/pages/settings/low_memory_mode_settings.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/player/pip_utils.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';

class PlayerSettingsPage extends ConsumerStatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  ConsumerState<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends ConsumerState<PlayerSettingsPage> {
  static const double _minPlayerControllerLayerDisappearSeconds = 1;
  static const double _maxPlayerControllerLayerDisappearSeconds = 10;
  static const int _playerControllerLayerDisappearDivisions = 18;

  final Box setting = GStorage.setting;
  late double defaultPlaySpeed;
  late double defaultShortcutForwardPlaySpeed;
  late PlayerAspectRatio defaultAspectRatioMode;
  late bool hAenable;
  late bool androidEnableOpenSLES;
  late bool androidAutoEnterPIP;
  late bool playResume;
  late bool showPlayerError;
  late bool privateMode;
  late bool playerDebugMode;
  late bool playerDisableAnimations;
  late bool forceAdBlocker;
  late bool autoPlayNext;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;
  late bool autoSkipOpEd;
  late int playerButtonSkipTime;
  late int playerArrowKeySkipTime;
  late int playerLogLevel;
  late int playerControllerLayerDisappearTime;

  @override
  void initState() {
    super.initState();
    _loadSettingsFromStorage();
  }

  void _loadSettingsFromStorage() {
    defaultPlaySpeed =
        GStorage.getSetting<double>(SettingsKeys.defaultPlaySpeed);
    defaultShortcutForwardPlaySpeed = GStorage.getSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed);
    defaultAspectRatioMode = PlayerAspectRatio.fromStorageValue(
      GStorage.getSetting<int>(SettingsKeys.defaultAspectRatioType),
    );
    hAenable = GStorage.getSetting<bool>(SettingsKeys.hAenable);
    androidEnableOpenSLES =
        GStorage.getSetting<bool>(SettingsKeys.androidEnableOpenSLES);
    androidAutoEnterPIP =
        GStorage.getSetting<bool>(SettingsKeys.androidAutoEnterPIP);
    playResume = GStorage.getSetting<bool>(SettingsKeys.playResume);
    privateMode = GStorage.getSetting<bool>(SettingsKeys.privateMode);
    showPlayerError = GStorage.getSetting<bool>(SettingsKeys.showPlayerError);
    playerDebugMode = GStorage.getSetting<bool>(SettingsKeys.playerDebugMode);
    autoPlayNext = GStorage.getSetting<bool>(SettingsKeys.autoPlayNext);
    backgroundPlayback =
        GStorage.getSetting<bool>(SettingsKeys.backgroundPlayback);
    playerDisableAnimations =
        GStorage.getSetting<bool>(SettingsKeys.playerDisableAnimations);
    forceAdBlocker = GStorage.getSetting<bool>(SettingsKeys.forceAdBlocker);
    playerLogLevel = GStorage.getSetting<int>(SettingsKeys.playerLogLevel);
    brightnessVolumeGesture =
        GStorage.getSetting<bool>(SettingsKeys.brightnessVolumeGesture);
    playerButtonSkipTime =
        GStorage.getSetting<int>(SettingsKeys.buttonSkipTime);
    playerArrowKeySkipTime =
        GStorage.getSetting<int>(SettingsKeys.arrowKeySkipTime);
    playerControllerLayerDisappearTime = GStorage.getSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime);
    autoSkipOpEd =
        setting.get(SettingBoxKey.autoSkipOpEd, defaultValue: false) as bool;
  }

  Future<void> resetPlayerSettings() async {
    final bool shouldReset = await HaipeeModalSheet.showConfirmation(
      context: context,
      title: '恢复默认播放设置',
      message: '播放设置、硬件解码器、视频渲染器和超分辨率设置将恢复为默认值。',
      cancelText: '取消',
      confirmText: '恢复默认',
      isDestructive: true,
      icon: Icons.restore_rounded,
    ) ?? false;
    if (!shouldReset) return;

    await GStorage.resetPlayerSettings();
    if (Platform.isAndroid) {
      await PipUtils.setAndroidAutoEnterPIPEnabled(false);
    }
    if (!mounted) return;
    setState(_loadSettingsFromStorage);
    HaipeeDialog.showToast(message: '已恢复默认播放设置');
  }

  void updateDefaultPlaySpeed(double speed) {
    GStorage.putSetting<double>(SettingsKeys.defaultPlaySpeed, speed);
    ref.read(playerSettingsProvider.notifier).setDefaultPlaySpeed(speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  void updateDefaultShortcutForwardPlaySpeed(double speed) {
    GStorage.putSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed, speed);
    setState(() {
      defaultShortcutForwardPlaySpeed = speed;
    });
  }

  void updatePlayerLogLevel(int level) {
    GStorage.putSetting<int>(SettingsKeys.playerLogLevel, level);
    setState(() {
      playerLogLevel = level;
    });
  }

  void updateDefaultAspectRatioMode(PlayerAspectRatio mode) {
    GStorage.putSetting<int>(
      SettingsKeys.defaultAspectRatioType,
      mode.storageValue,
    );
    ref
        .read(playerSettingsProvider.notifier)
        .setDefaultAspectRatioType(mode.storageValue);
    setState(() {
      defaultAspectRatioMode = mode;
    });
  }

  Future<void> updateButtonSkipTime() async {
    final int? newButtonSkipTime = await _showSkipTimeChangeDialog(
        title: '顶部按钮快进时长', initialValue: playerButtonSkipTime.toString());

    if (newButtonSkipTime != null &&
        newButtonSkipTime != playerButtonSkipTime) {
      GStorage.putSetting<int>(SettingsKeys.buttonSkipTime, newButtonSkipTime);
      setState(() {
        playerButtonSkipTime = newButtonSkipTime;
      });
    }
  }

  Future<int?> _showSkipTimeChangeDialog(
      {required String title, required String initialValue}) async {
    return HaipeeDialog.show<int>(builder: (context) {
      String input = "";
      return AdaptiveDialogFrame(
        maxWidth: 400,
        title: Text(title),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelText: initialValue,
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => HaipeeDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final int? newValue = int.tryParse(input);

              if (newValue == null) {
                HaipeeDialog.showToast(message: '请输入数字');
                return;
              }

              if (newValue <= 0) {
                HaipeeDialog.showToast(message: '请输入大于0的数字');
                return;
              }
              HaipeeDialog.dismiss(popWith: newValue);
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  double get playerControllerLayerDisappearSeconds =>
      (playerControllerLayerDisappearTime / Duration.millisecondsPerSecond)
          .clamp(_minPlayerControllerLayerDisappearSeconds,
              _maxPlayerControllerLayerDisappearSeconds)
          .toDouble();

  String formatPlayerControllerLayerDisappearSeconds(double seconds) {
    if (seconds == seconds.roundToDouble()) {
      return '${seconds.toInt()} 秒';
    }
    return '${seconds.toStringAsFixed(1)} 秒';
  }

  void updatePlayerControllerLayerDisappearSeconds(double seconds) {
    final int newDisappearTime =
        (seconds * Duration.millisecondsPerSecond).round();
    if (newDisappearTime == playerControllerLayerDisappearTime) {
      return;
    }
    GStorage.putSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime, newDisappearTime);
    setState(() {
      playerControllerLayerDisappearTime = newDisappearTime;
    });
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
          return AdaptiveDialogFrame(
            maxWidth: 480,
            title: const Text('Debrid 云端加速设置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择云加速提供商 (BYOT 自备 Key):'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('none', '关闭 (仅本地 P2P)'),
                      ('realdebrid', 'Real-Debrid'),
                      ('torbox', 'TorBox'),
                      ('pikpak', 'PikPak'),
                    ].map((item) {
                      final isSelected = selectedProvider == item.$1;
                      return ChoiceChip(
                        label: Text(item.$2),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedProvider = item.$1);
                          }
                        },
                      );
                    }).toList(),
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
                  await setting.put(
                      SettingBoxKey.debridProvider, selectedProvider);
                  await setting.put(
                      SettingBoxKey.debridApiKey, textController.text.trim());
                  if (context.mounted) {
                    setState(() {});
                    Navigator.of(ctx).pop();
                    HaipeeDialog.showToast(message: 'Debrid 配置已保存');
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

  @override
  Widget build(BuildContext context) {
    final metadataState = ref.watch(metadataSettingsProvider);

    return SettingsDetailScaffold(
      title: const Text('播放设置'),
      body: ValueListenableBuilder<BiliUserProfile?>(
        valueListenable: BiliAuthService().userNotifier,
        builder: (context, biliUser, _) {
          final isBiliLoggedIn =
              BiliAuthService().isLoggedIn && biliUser != null;
          return SettingsList(
            sections: [
              SettingsSection(
                title: const Text('平台账号与画质授权'),
                tiles: [
                  SettingsTile(
                    key: const Key('settings_bili_account_tile'),
                    leading: isBiliLoggedIn
                        ? Icons.verified_user_rounded
                        : Icons.tv_rounded,
                    title: const Text('哔哩哔哩 (Bilibili) 账号管理'),
                    description: Text(
                      isBiliLoggedIn
                          ? '已登录: ${biliUser.uname} · ${biliUser.isVip ? "大会员 (已解锁 1080P 高码率 / 4K)" : "普通用户 (已解锁 1080P 高清)"}'
                          : '未登录 (默认 360P/480P · 扫码登录解锁 1080P 高清与大会员高码率)',
                    ),
                    value: Text(isBiliLoggedIn ? '账号管理 / 退出' : '扫码登录'),
                    onPressed: (_) async {
                      await BiliLoginDialog.show(context);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              SettingsSection(
                title: const Text('解码与渲染'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.memory_rounded,
                onToggle: (value) async {
                  hAenable = value ?? !hAenable;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.hAenable, hAenable);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setHAEnable(hAenable);
                  setState(() {});
                },
                title: const Text('硬件解码'),
                initialValue: hAenable,
              ),
              SettingsTile(
                leading: Icons.developer_board_rounded,
                onPressed: (_) async {
                  await context.push(Routes.settingsPlayerDecoder);
                },
                title: const Text('硬件解码器'),
                description: const Text('仅在硬件解码启用时生效'),
              ),
              if (Platform.isAndroid) ...[
                SettingsTile(
                  leading: Icons.tv_rounded,
                  onPressed: (_) async {
                    await context.push(Routes.settingsPlayerRenderer);
                  },
                  title: const Text('视频渲染器'),
                  description: const Text('选择视频输出方式'),
                ),
              ],
              const LowMemoryModeSettingsTile(),
              if (Platform.isAndroid) ...[
                SettingsTile.switchTile(
                  leading: Icons.graphic_eq_rounded,
                  onToggle: (value) async {
                    androidEnableOpenSLES = value ?? !androidEnableOpenSLES;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.androidEnableOpenSLES,
                        androidEnableOpenSLES);
                    ref
                        .read(playerSettingsProvider.notifier)
                        .setAndroidEnableOpenSLES(androidEnableOpenSLES);
                    setState(() {});
                  },
                  title: const Text('低延迟音频'),
                  description: const Text('启用OpenSLES音频输出以降低延时'),
                  initialValue: androidEnableOpenSLES,
                ),
              ],
              SettingsTile(
                leading: Icons.auto_awesome_rounded,
                onPressed: (_) async {
                  context.push(Routes.settingsPlayerSuper);
                },
                title: const Text('超分辨率'),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('元数据与刮削'),
            tiles: [
              SettingsTile(
                leading: Icons.auto_awesome_mosaic_outlined,
                title: const Text('媒体元数据与刮削'),
                description: Text(
                  'Bangumi (${metadataState.bangumiEnabled ? "已启用 · ${metadataState.bangumiAcceleration.label}" : "已禁用"}) · TMDB (${metadataState.tmdbEnabled ? "已启用" : "已禁用"})',
                ),
                onPressed: (_) async {
                  await context.push(Routes.settingsMetadata);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('播放行为'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.headphones_rounded,
                onToggle: (value) async {
                  backgroundPlayback = value ?? !backgroundPlayback;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.backgroundPlayback, backgroundPlayback);
                  setState(() {});
                },
                title: const Text('后台播放'),
                description: const Text('应用退到后台或熄屏时继续播放音频'),
                initialValue: backgroundPlayback,
              ),
              SettingsTile.switchTile(
                leading: Icons.history_rounded,
                onToggle: (value) async {
                  playResume = value ?? !playResume;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.playResume, playResume);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setPlayResume(playResume);
                  setState(() {});
                },
                title: const Text('自动跳转'),
                description: const Text('跳转到上次播放位置'),
                initialValue: playResume,
              ),
              SettingsTile.switchTile(
                leading: Icons.playlist_play_rounded,
                onToggle: (value) async {
                  autoPlayNext = value ?? !autoPlayNext;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.autoPlayNext, autoPlayNext);
                  setState(() {});
                },
                title: const Text('自动连播'),
                description: const Text('当前视频播放完毕后自动播放下一集'),
                initialValue: autoPlayNext,
              ),
              if (Platform.isAndroid)
                SettingsTile.switchTile(
                  leading: Icons.picture_in_picture_alt_rounded,
                  onToggle: (value) async {
                    androidAutoEnterPIP = value ?? !androidAutoEnterPIP;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.androidAutoEnterPIP, androidAutoEnterPIP);
                    await PipUtils.setAndroidAutoEnterPIPEnabled(
                        androidAutoEnterPIP);
                    setState(() {});
                  },
                  title: const Text('自动进入画中画'),
                  description: const Text('切到后台时，自动进入画中画'),
                  initialValue: androidAutoEnterPIP,
                ),
              SettingsTile.switchTile(
                leading: Icons.block_rounded,
                onToggle: (value) async {
                  forceAdBlocker = value ?? !forceAdBlocker;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.forceAdBlocker, forceAdBlocker);
                  setState(() {});
                },
                title: const Text('广告过滤'),
                description: const Text('强制启用HLS广告过滤，忽略规则设置'),
                initialValue: forceAdBlocker,
              ),
              SettingsTile.switchTile(
                leading: Icons.animation_rounded,
                onToggle: (value) async {
                  playerDisableAnimations = value ?? !playerDisableAnimations;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.playerDisableAnimations,
                      playerDisableAnimations);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setPlayerDisableAnimations(playerDisableAnimations);
                  setState(() {});
                },
                title: const Text('禁用动画'),
                description: const Text('禁用播放器内的过渡动画'),
                initialValue: playerDisableAnimations,
              ),
              if (!Utils.isDesktop())
                SettingsTile.switchTile(
                  leading: Icons.swipe_vertical_rounded,
                  onToggle: (value) async {
                    brightnessVolumeGesture = value ?? !brightnessVolumeGesture;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.brightnessVolumeGesture,
                        brightnessVolumeGesture);
                    setState(() {});
                  },
                  title: const Text('滑动手势'),
                  description: const Text('竖向滑动调节音量和亮度'),
                  initialValue: brightnessVolumeGesture,
                ),
              SettingsTile.switchTile(
                leading: Icons.visibility_off_rounded,
                onToggle: (value) async {
                  privateMode = value ?? !privateMode;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.privateMode, privateMode);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setPrivateMode(privateMode);
                  setState(() {});
                },
                title: const Text('隐身模式'),
                description: const Text('不保留观看记录'),
                initialValue: privateMode,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('诊断'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.error_outline_rounded,
                onToggle: (value) async {
                  showPlayerError = value ?? !showPlayerError;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.showPlayerError, showPlayerError);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setShowPlayerError(showPlayerError);
                  setState(() {});
                },
                title: const Text('错误提示'),
                description: const Text('显示播放器内部错误提示'),
                initialValue: showPlayerError,
              ),
              SettingsTile.switchTile(
                leading: Icons.analytics_outlined,
                onToggle: (value) async {
                  playerDebugMode = value ?? !playerDebugMode;
                  await GStorage.putSetting<bool>(
                      SettingsKeys.playerDebugMode, playerDebugMode);
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setPlayerDebugMode(playerDebugMode);
                  setState(() {});
                },
                title: const Text('调试与统计模式'),
                description: const Text('启用播放器详细媒体统计与调试面板 (与系统运行日志独立)'),
                initialValue: playerDebugMode,
              ),
              SettingsDropdownTile<int>(
                leading: Icons.receipt_long_rounded,
                title: const Text('日志等级'),
                description: const Text('播放器内部日志等级'),
                value: playerLogLevel,
                options: playerLogLevelMap,
                fallbackLabel: '???',
                onChanged: updatePlayerLogLevel,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('播放参数'),
            tiles: [
              SettingsSliderTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('默认倍速'),
                value: defaultPlaySpeed,
                min: 0.25,
                max: 3,
                divisions: 11,
                valueLabel: '${defaultPlaySpeed}x',
                onChanged: (value) => updateDefaultPlaySpeed(
                    double.parse(value.toStringAsFixed(2))),
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.fast_forward_rounded),
                title: const Text('长按倍速'),
                description: const Text('长按屏幕或按住方向键时的倍速'),
                value: defaultShortcutForwardPlaySpeed,
                min: 1.25,
                max: 3,
                divisions: 7,
                valueLabel: '${defaultShortcutForwardPlaySpeed}x',
                onChanged: (value) => updateDefaultShortcutForwardPlaySpeed(
                    double.parse(value.toStringAsFixed(2))),
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('方向键跳转'),
                description: const Text('左右方向键的快进/快退秒数'),
                value: playerArrowKeySkipTime.toDouble(),
                min: 0,
                max: 15,
                divisions: 15,
                valueLabel: '$playerArrowKeySkipTime 秒',
                onChanged: (value) {
                  final newArrowKeySkipTime = value.toInt();
                  if (newArrowKeySkipTime == playerArrowKeySkipTime) {
                    return;
                  }
                  GStorage.putSetting<int>(
                      SettingsKeys.arrowKeySkipTime, newArrowKeySkipTime);
                  setState(() {
                    playerArrowKeySkipTime = newArrowKeySkipTime;
                  });
                },
              ),
              SettingsTile(
                leading: Icons.skip_next_rounded,
                onPressed: (_) async {
                  await updateButtonSkipTime();
                },
                title: const Text('跳过时长'),
                description: const Text('顶栏跳过按钮的秒数'),
                value: Text('$playerButtonSkipTime 秒'),
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.timer_rounded),
                title: const Text('控制栏消失时间'),
                description: const Text('播放控制器自动隐藏前的停留时长'),
                value: playerControllerLayerDisappearSeconds,
                min: _minPlayerControllerLayerDisappearSeconds,
                max: _maxPlayerControllerLayerDisappearSeconds,
                divisions: _playerControllerLayerDisappearDivisions,
                valueLabel: formatPlayerControllerLayerDisappearSeconds(
                    playerControllerLayerDisappearSeconds),
                onChanged: updatePlayerControllerLayerDisappearSeconds,
              ),
              SettingsDropdownTile<PlayerAspectRatio>(
                leading: Icons.aspect_ratio_rounded,
                title: const Text('默认视频比例'),
                value: defaultAspectRatioMode,
                options: {
                  for (final mode in PlayerAspectRatio.values) mode: mode.label,
                },
                onChanged: updateDefaultAspectRatioMode,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('智能跳过与云加速'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.timelapse_rounded,
                onToggle: (value) async {
                  final v = value ?? !autoSkipOpEd;
                  await setting.put(SettingBoxKey.autoSkipOpEd, v);
                  ref.read(playerSettingsProvider.notifier).setAutoSkipOpEd(v);
                  setState(() {
                    autoSkipOpEd = v;
                  });
                },
                title: const Text('自动跳过片头片尾 (AniSkip)'),
                description: const Text('播放进入 OP/ED 或总集篇区间时毫秒级自动跳过'),
                initialValue: autoSkipOpEd,
              ),
              SettingsTile(
                leading: Icons.cloud_done_rounded,
                onPressed: (_) {
                  _showDebridConfigDialog(context);
                },
                title: const Text('Debrid 云端高速离线加速'),
                description: Text(
                  (setting.get(SettingBoxKey.debridProvider,
                              defaultValue: 'none') as String) ==
                          'none'
                      ? '未启用 (默认本地 P2P)'
                      : '已启用: ${(setting.get(SettingBoxKey.debridProvider) as String).toUpperCase()}',
                ),
              ),
            ],
          ),
              SettingsSection(
                tiles: [
                  SettingsTile(
                    leading: Icons.settings_backup_restore_rounded,
                    onPressed: (_) => resetPlayerSettings(),
                    title: const Text('恢复默认设置'),
                    description: const Text('将播放相关设置恢复为默认值'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
