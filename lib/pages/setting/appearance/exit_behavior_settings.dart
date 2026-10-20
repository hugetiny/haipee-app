import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

/// Provider for exit behavior setting
final exitBehaviorProvider = StateProvider.autoDispose<int>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.exitBehavior, defaultValue: 2) as int;
});

class ExitBehaviorSettings extends ConsumerWidget {
  const ExitBehaviorSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final setting = GStorage.setting;
    final exitBehavior = ref.watch(exitBehaviorProvider);

    final List<String> exitBehaviorTitles = [
      t.settings.general.exitApp,
      t.settings.general.minimizeToTray,
      t.settings.general.askEveryTime,
    ];

    return Scaffold(
      appBar: SysAppBar(
        title: Text(t.settings.general.exitBehavior),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            tiles: List.generate(
              exitBehaviorTitles.length,
              (index) => SettingsTile<int>.radioTile(
                title: Text(exitBehaviorTitles[index]),
                radioValue: index,
                groupValue: exitBehavior,
                onChanged: (int? value) async {
                  if (value == null) {
                    return;
                  }
                  await setting.put(SettingBoxKey.exitBehavior, value);
                  ref.read(exitBehaviorProvider.notifier).state = value;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
