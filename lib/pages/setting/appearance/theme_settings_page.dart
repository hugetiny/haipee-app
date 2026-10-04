import 'dart:io';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';

class ThemeSettingsPage extends ConsumerStatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  ConsumerState<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends ConsumerState<ThemeSettingsPage> {
  final Box setting = GStorage.setting;
  late dynamic defaultThemeColor;
  final MenuController menuController = MenuController();

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
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
      child: Scaffold(
        appBar: SysAppBar(title: Text(t.settings.appearancePage.title)),
        body: SettingsList(
          maxWidth: 1000,
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
                  enabled: !useDynamicColor,
                  onPressed: (_) async {
                    KazumiDialog.show(builder: (context) {
                      final colorThemes = colorThemeTypes;
                      return AlertDialog(
                        title: Text(
                            t.settings.appearancePage.colorScheme.dialogTitle),
                        content: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: Utils.isDesktop() ? 8 : 0,
                          children: [
                            for (final theme in colorThemes)
                              GestureDetector(
                                onTap: () {
                                  final index = colorThemes.indexOf(theme);
                                  if (index == 0) {
                                    resetTheme();
                                  } else {
                                    setTheme(theme['color']);
                                  }
                                  KazumiDialog.dismiss();
                                },
                                child: Column(
                                  children: [
                                    PaletteCard(
                                      color: theme['color'] as Color,
                                      selected: (theme['color']
                                                  .value
                                                  .toRadixString(16) ==
                                              defaultThemeColor ||
                                          (defaultThemeColor == 'default' &&
                                              colorThemes.indexOf(theme) == 0)),
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
                SettingsTile.switchTile(
                  enabled: !Platform.isIOS,
                  onToggle: (value) async {
                    final newValue = value ?? !useDynamicColor;
                    await setting.put(
                      SettingBoxKey.useDynamicColor,
                      newValue,
                    );
                    ref
                        .read(themeProvider.notifier)
                        .setUseDynamicColor(newValue);
                  },
                  title: Text(
                    t.settings.appearancePage.colorScheme.dynamicColor,
                  ),
                  initialValue: useDynamicColor,
                ),
              ],
              bottomInfo:
                  Text(t.settings.appearancePage.colorScheme.dynamicColorInfo),
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final newValue = value ?? !oledEnhance;
                    await setting.put(SettingBoxKey.oledEnhance, newValue);
                    ref.read(themeProvider.notifier).setOledEnhance(newValue);
                  },
                  title: Text(t.settings.appearancePage.oled.title),
                  description: Text(t.settings.appearancePage.oled.description),
                  initialValue: oledEnhance,
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
