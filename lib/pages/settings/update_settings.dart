import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/settings/settings_list.dart';
import 'package:haipee/pages/setting/setting_controller.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/services/storage/storage.dart';

class UpdateSettingsPage extends ConsumerStatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  ConsumerState<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends ConsumerState<UpdateSettingsPage> {
  bool _autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
  bool _pluginUpdate =
      GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup);

  @override
  Widget build(BuildContext context) {
    final myController = ref.read(myControllerProvider.notifier);

    return SettingsDetailScaffold(
      title: const Text('更新设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('自动检查更新'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.update_rounded,
                title: const Text('应用更新'),
                description: const Text('启动时自动检查 Haipee 最新版本'),
                initialValue: _autoUpdate,
                onToggle: (value) async {
                  setState(() => _autoUpdate = value ?? !_autoUpdate);
                  await GStorage.putSetting(SettingsKeys.autoUpdate, _autoUpdate);
                },
              ),
              SettingsTile.switchTile(
                leading: Icons.extension_rounded,
                title: const Text('规则更新'),
                description: const Text('启动时自动检查订阅规则最新版本'),
                initialValue: _pluginUpdate,
                onToggle: (value) async {
                  setState(() => _pluginUpdate = value ?? !_pluginUpdate);
                  await GStorage.putSetting(
                    SettingsKeys.checkPluginUpdateOnStartup,
                    _pluginUpdate,
                  );
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('手动检查'),
            tiles: [
              SettingsTile(
                leading: Icons.system_update_alt_rounded,
                title: const Text('立即检查应用更新'),
                description: Text('当前版本: v${Api.version}'),
                onPressed: (_) {
                  myController.checkUpdate();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
