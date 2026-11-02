import 'dart:io';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/card/palette_card.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/settings/color_type.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';

class ThemeSettingsPage extends ConsumerStatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  ConsumerState<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends ConsumerState<ThemeSettingsPage> {
  final Box setting = GStorage.setting;
  dynamic defaultThemeColor = 'default';
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    try {
      defaultThemeColor =
          setting.get(SettingBoxKey.themeColor, defaultValue: 'default') ??
              'default';
    } catch (_) {
      defaultThemeColor = 'default';
    }
  }

  void onBackPressed(BuildContext context) {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
    }
  }

  void setTheme(Color? color) {
    final seed = color ?? Colors.green;
    ref.read(themeProvider.notifier).setSeedColor(seed);
    defaultThemeColor =
        color != null ? color.toARGB32().toRadixString(16) : 'default';
    setting.put(SettingBoxKey.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    ref.read(themeProvider.notifier).setSeedColor(Colors.green);
    defaultThemeColor = 'default';
    setting.put(SettingBoxKey.themeColor, 'default');
  }

  Future<void> updateTheme(String theme) async {
    if (theme == 'dark') {
      ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
    } else if (theme == 'light') {
      ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
    } else {
      ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system);
    }
    await setting.put(SettingBoxKey.themeMode, theme);
  }

  void updateOledEnhance() {
    final oledEnhance =
        setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    ref.read(themeProvider.notifier).setOledEnhance(oledEnhance);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final themeState = ref.watch(themeProvider);
    final showWindowButton = ref.watch(showWindowButtonProvider);

    // ✅ Get theme mode string from ThemeState
    final defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    final useDynamicColor = themeState.useDynamicColor;
    final oledEnhance = themeState.oledEnhance;
    final useSystemFont = themeState.useSystemFont;
    String colorLabel(String key) {
      final labels = t.settings.appearancePage.colorScheme.labels;
      switch (key) {
        case 'default':
          return labels.defaultLabel;
        case 'teal':
          return labels.teal;
        case 'blue':
          return labels.blue;
        case 'indigo':
          return labels.indigo;
        case 'violet':
          return labels.violet;
        case 'pink':
          return labels.pink;
        case 'yellow':
          return labels.yellow;
        case 'orange':
          return labels.orange;
        case 'deepOrange':
          return labels.deepOrange;
        default:
          return key;
      }
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: SettingsDetailScaffold(
        title: Text(t.settings.appearancePage.title),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: Text(t.settings.general.appearance),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  },
                  title: Text(t.settings.appearancePage.mode.title),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: menuController,
                    builder: (_, __, ___) {
                      final modeLabel = switch (defaultThemeMode) {
                        'light' => t.settings.appearancePage.mode.light,
                        'dark' => t.settings.appearancePage.mode.dark,
                        _ => t.settings.appearancePage.mode.system,
                      };
                      return Text(modeLabel);
                    },
                    menuChildren: [
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('system'),
                        child: Container(
                          height: 48,
                          constraints: const BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.brightness_auto_rounded,
                                  color: defaultThemeMode == 'system'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.settings.appearancePage.mode.system,
                                  style: TextStyle(
                                    color: defaultThemeMode == 'system'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('light'),
                        child: Container(
                          height: 48,
                          constraints: const BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.light_mode_rounded,
                                  color: defaultThemeMode == 'light'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.settings.appearancePage.mode.light,
                                  style: TextStyle(
                                    color: defaultThemeMode == 'light'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('dark'),
                        child: Container(
                          height: 48,
                          constraints: const BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.dark_mode_rounded,
                                  color: defaultThemeMode == 'dark'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.settings.appearancePage.mode.dark,
                                  style: TextStyle(
                                    color: defaultThemeMode == 'dark'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    HaipeeDialog.show(builder: (context) {
                      final colorThemes = colorThemeTypes;
                      return AlertDialog(
                        title: Text(
                            t.settings.appearancePage.colorScheme.dialogTitle),
                        content: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: Utils.isDesktop() ? 8 : 0,
                          children: [
                            if (!Platform.isIOS)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setting.put(
                                    SettingBoxKey.useDynamicColor,
                                    true,
                                  );
                                  ref
                                      .read(themeProvider.notifier)
                                      .setUseDynamicColor(true);
                                  HaipeeDialog.dismiss();
                                },
                                child: Column(
                                  children: [
                                    PaletteCard(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      selected: useDynamicColor,
                                    ),
                                    Text(t.settings.appearancePage.colorScheme
                                        .dynamicColor),
                                  ],
                                ),
                              ),
                            for (final theme in colorThemes)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setting.put(
                                    SettingBoxKey.useDynamicColor,
                                    false,
                                  );
                                  ref
                                      .read(themeProvider.notifier)
                                      .setUseDynamicColor(false);
                                  final index = colorThemes.indexOf(theme);
                                  if (index == 0) {
                                    resetTheme();
                                  } else {
                                    setTheme(theme['color']);
                                  }
                                  HaipeeDialog.dismiss();
                                },
                                child: Column(
                                  children: [
                                    PaletteCard(
                                      color: theme['color'] as Color,
                                      selected: !useDynamicColor &&
                                          ((theme['color'] as Color)
                                                      .toARGB32()
                                                      .toRadixString(16) ==
                                                  defaultThemeColor ||
                                              (defaultThemeColor == 'default' &&
                                                  colorThemes.indexOf(theme) ==
                                                      0)),
                                    ),
                                    Text(colorLabel(theme['label'] as String)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    });
                  },
                  title: Text(t.settings.appearancePage.colorScheme.title),
                ),
              ],
              bottomInfo:
                  Text(t.settings.appearancePage.colorScheme.dynamicColorInfo),
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  leading: const Icon(Icons.contrast_rounded),
                  onToggle: (value) async {
                    final newValue = value ?? !oledEnhance;
                    await setting.put(SettingBoxKey.oledEnhance, newValue);
                    ref.read(themeProvider.notifier).setOledEnhance(newValue);
                  },
                  title: Text(t.settings.appearancePage.oled.title),
                  description: Text(t.settings.appearancePage.oled.description),
                  initialValue: oledEnhance,
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.font_download_rounded),
                  onToggle: (value) async {
                    final newValue = value ?? !useSystemFont;
                    await setting.put(SettingBoxKey.useSystemFont, newValue);
                    ref
                        .read(themeProvider.notifier)
                        .setUseSystemFont(newValue);
                  },
                  title: const Text('使用系统字体'),
                  description: const Text('关闭后使用 MI Sans 字体'),
                  initialValue: useSystemFont,
                ),
              ],
            ),
            if (Utils.isDesktop())
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      final newValue = value ?? !showWindowButton;
                      await setting.put(
                        SettingBoxKey.showWindowButton,
                        newValue,
                      );
                      ref.read(showWindowButtonProvider.notifier).state =
                          newValue;
                    },
                    title: Text(t.settings.appearancePage.window.title),
                    description:
                        Text(t.settings.appearancePage.window.description),
                    initialValue: showWindowButton,
                  ),
                ],
              ),
            if (Platform.isAndroid)
              SettingsSection(
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      context.push(Routes.settingsThemeDisplay);
                    },
                    title: Text(t.settings.appearancePage.refreshRate.title),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
