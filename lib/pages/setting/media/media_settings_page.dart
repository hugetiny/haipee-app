import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/responsive/responsive_menu_scaffold.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/setting/metadata/metadata_settings_page.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_settings.dart';
import 'package:haipee/pages/settings/player_settings.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/router_constants.dart';

class MediaSettingsPage extends ConsumerStatefulWidget {
  const MediaSettingsPage({super.key});

  @override
  ConsumerState<MediaSettingsPage> createState() => _MediaSettingsPageState();
}

class _MediaSettingsPageState extends ConsumerState<MediaSettingsPage> {
  String _selectedId = '';

  Widget _buildDetail(String id) {
    switch (id) {
      case Routes.settingsPlayer:
        return const PlayerSettingsPage();
      case Routes.settingsDanmaku:
        return const DanmakuSettingsPage();
      case Routes.settingsMetadata:
        return const MetadataSettingsPage();
      case Routes.settingsPlugin:
        return const PluginViewPage(isEmbedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final metadataState = ref.watch(metadataSettingsProvider);
    final videoPlugins = ref.watch(pluginsProvider).pluginList;

    final groups = [
      ResponsiveMenuGroup(
        title: '播放与渲染',
        items: [
          ResponsiveMenuItem(
            id: Routes.settingsPlayer,
            title: t.settings.player.playerSettings,
            description: t.settings.player.playerSettingsDesc,
            icon: Icons.play_circle_outline,
            route: Routes.settingsPlayer,
            detailBuilder: (_) => const PlayerSettingsPage(),
          ),
          ResponsiveMenuItem(
            id: Routes.settingsDanmaku,
            title: t.settings.player.danmakuSettings,
            description: t.settings.player.danmakuSettingsDesc,
            icon: Icons.subtitles_outlined,
            route: Routes.settingsDanmaku,
            detailBuilder: (_) => const DanmakuSettingsPage(),
          ),
        ],
      ),
      ResponsiveMenuGroup(
        title: '内容识别与在线源',
        items: [
          ResponsiveMenuItem(
            id: Routes.settingsMetadata,
            title: '媒体元数据与刮削',
            description:
                'Bangumi (${metadataState.bangumiEnabled ? "已启用 · ${metadataState.bangumiAcceleration.label}" : "已禁用"}) · TMDB (${metadataState.tmdbEnabled ? "已启用" : "已禁用"})',
            icon: Icons.auto_awesome_motion_outlined,
            route: Routes.settingsMetadata,
            detailBuilder: (_) => const MetadataSettingsPage(),
          ),
          ResponsiveMenuItem(
            id: Routes.settingsPlugin,
            title: 'Haipee 视频规则',
            description: '已安装 ${videoPlugins.length} 个 Haipee 视频规则',
            icon: Icons.extension_outlined,
            route: Routes.settingsPlugin,
            detailBuilder: (_) => const PluginViewPage(isEmbedded: true),
          ),
        ],
      ),
    ];

    return ResponsiveMenuScaffold(
      groups: groups,
      selectedId: _selectedId,
      onSelected: (id) => setState(() => _selectedId = id),
      appBarBuilder: (context, wide) => SysAppBar(
        title: const Text('视听与媒体'),
        needTopOffset: !wide,
      ),
      detailBuilder: (context, id) => _buildDetail(id),
    );
  }
}
