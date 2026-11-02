import 'package:flutter/material.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/constants.dart';

class RendererSettings extends StatefulWidget {
  const RendererSettings({super.key});

  @override
  State<RendererSettings> createState() => _RendererSettingsState();
}

class _RendererSettingsState extends State<RendererSettings> {
  late String _renderer =
      GStorage.getSetting(SettingsKeys.androidVideoRenderer);

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('视频渲染器'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('选择合适的渲染器以获得最佳播放体验'),
            tiles: androidVideoRenderersList.entries
                .map(
                  (e) => SettingsTile<String>.radioTile(
                    title: Text(e.key),
                    description: Text(e.value),
                    radioValue: e.key,
                    groupValue: _renderer,
                    onChanged: (String? value) {
                      if (value != null) {
                        GStorage.putSetting<String>(
                            SettingsKeys.androidVideoRenderer, value);
                        setState(() {
                          _renderer = value;
                        });
                      }
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

typedef RendererSettingsPage = RendererSettings;
