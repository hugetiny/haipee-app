import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/storage.dart';

/// Provider for hardware decoder setting
final hardwareDecoderProvider = StateProvider.autoDispose<String>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
});

class DecoderSettings extends ConsumerWidget {
  const DecoderSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = GStorage.setting;
    final decoder = ref.watch(hardwareDecoderProvider);

    return Scaffold(
      appBar: const SysAppBar(
        title: Text('硬件解码器'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('选择不受支持的解码器将回退到软件解码'),
            tiles: hardwareDecodersList.entries
                .map(
                  (entry) => SettingsTile<String>.radioTile(
                    title: Text(entry.key),
                    description: Text(entry.value),
                    radioValue: entry.key,
                    groupValue: decoder,
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setting.put(SettingBoxKey.hardwareDecoder, value);
                      ref.read(hardwareDecoderProvider.notifier).state = value;
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
