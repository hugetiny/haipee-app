import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/storage.dart';

/// Provider for super resolution prompt on enable setting
final superResolutionPromptProvider = StateProvider.autoDispose<bool>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.superResolutionWarn, defaultValue: false);
});

/// Provider for super resolution type
final superResolutionTypeProvider = StateProvider.autoDispose<String>((ref) {
  final setting = GStorage.setting;
  return setting
      .get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1)
      .toString();
});

class SuperResolutionSettings extends ConsumerWidget {
  const SuperResolutionSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final superOptions = t.settings.player.superResolutionOptions;
    final setting = GStorage.setting;
    final promptOnEnable = ref.watch(superResolutionPromptProvider);
    final superResolutionType = ref.watch(superResolutionTypeProvider);

    return Scaffold(
      appBar: SysAppBar(
        title: Text(t.settings.player.superResolutionTitle),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.player.superResolutionHint),
            tiles: [
              _buildOptionTile(ref, setting, '1', superOptions.off.label,
                  superOptions.off.description, superResolutionType),
              _buildOptionTile(ref, setting, '2', superOptions.efficiency.label,
                  superOptions.efficiency.description, superResolutionType),
              _buildOptionTile(ref, setting, '3', superOptions.quality.label,
                  superOptions.quality.description, superResolutionType),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.player.superResolutionDefaultBehavior),
            tiles: [
              SettingsTile.switchTile(
                title: Text(t.settings.player.superResolutionClosePrompt),
                description:
                    Text(t.settings.player.superResolutionClosePromptDesc),
                initialValue: promptOnEnable,
                onToggle: (value) async {
                  final newValue = value ?? false;
                  await setting.put(
                    SettingBoxKey.superResolutionWarn,
                    newValue,
                  );
                  ref.read(superResolutionPromptProvider.notifier).state =
                      newValue;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  SettingsTile<String> _buildOptionTile(
    WidgetRef ref,
    Box setting,
    String value,
    String title,
    String description,
    String currentType,
  ) {
    return SettingsTile<String>.radioTile(
      title: Text(title),
      description: Text(description),
      radioValue: value,
      groupValue: currentType,
      onChanged: (String? newValue) {
        if (newValue == null) {
          return;
        }
        setting.put(
          SettingBoxKey.defaultSuperResolutionType,
          int.tryParse(newValue) ?? 1,
        );
        ref.read(superResolutionTypeProvider.notifier).state = newValue;
      },
    );
  }
}
