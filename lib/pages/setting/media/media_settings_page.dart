import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class MediaSettingsPage extends ConsumerWidget {
  const MediaSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final metadataState = ref.watch(metadataSettingsProvider);
    final videoPlugins = ref.watch(pluginsProvider).pluginList;

    return Scaffold(
      appBar: const SysAppBar(
        title: Text('视听与媒体'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('播放与渲染'),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(t.settings.player.playerSettings),
                description: Text(t.settings.player.playerSettingsDesc),
                onPressed: (_) => context.push(Routes.settingsPlayer),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(t.settings.player.danmakuSettings),
                description: Text(t.settings.player.danmakuSettingsDesc),
                onPressed: (_) => context.push(Routes.settingsDanmaku),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('内容识别与在线源'),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.auto_awesome_motion_outlined),
                title: const Text('媒体元数据与刮削'),
                description: Text(
                  'Bangumi (${metadataState.bangumiEnabled ? "已启用 · ${metadataState.bangumiAcceleration.label}" : "已禁用"}) · TMDB (${metadataState.tmdbEnabled ? "已启用" : "已禁用"})',
                ),
                onPressed: (_) => context.push(Routes.settingsMetadata),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.extension_outlined),
                title: const Text('Kazumi 视频规则'),
                description: Text(
                  '已安装 ${videoPlugins.length} 个 Kazumi 视频规则',
                ),
                onPressed: (_) => context.push(Routes.settingsPlugin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
