import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class MetadataSettingsPage extends ConsumerWidget {
  const MetadataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final metadataState = ref.watch(metadataSettingsProvider);
    final metadataController = ref.read(metadataSettingsProvider.notifier);

    return Scaffold(
      appBar: const SysAppBar(
        title: Text('媒体元数据与刮削'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Bangumi (番剧数据库)'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.animation_outlined),
                title: Text(t.settings.metadata.enableBangumi),
                description: Text(t.settings.metadata.enableBangumiDesc),
                initialValue: metadataState.bangumiEnabled,
                onToggle: (value) async {
                  await metadataController.setBangumiEnabled(
                    value ?? !metadataState.bangumiEnabled,
                  );
                },
              ),
              if (metadataState.bangumiEnabled)
                SettingsTile.navigation(
                  leading: const Icon(Icons.speed_outlined),
                  title: const Text('Bangumi 网络加速'),
                  description: const Text('选择连接 Bangumi 服务的加速方式 (直连 / ECH / 镜像)'),
                  value: Text(metadataState.bangumiAcceleration.label),
                  onPressed: (context) {
                    showModalBottomSheet(
                      context: context,
                      builder: (bottomSheetContext) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final mode in BangumiAcceleration.values)
                                ListTile(
                                  title: Text(mode.label),
                                  subtitle: Text(switch (mode) {
                                    BangumiAcceleration.direct => '直接连接官方服务器',
                                    BangumiAcceleration.ech =>
                                      'ECH (Encrypted Client Hello) 域名防嗅探加速',
                                    BangumiAcceleration.mirror => '通过反向代理镜像站连接',
                                  }),
                                  trailing:
                                      metadataState.bangumiAcceleration == mode
                                          ? const Icon(Icons.check)
                                          : null,
                                  onTap: () {
                                    metadataController
                                        .setBangumiAcceleration(mode);
                                    Navigator.pop(bottomSheetContext);
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
          SettingsSection(
            title: const Text('TMDB (影视元数据)'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: Text(t.settings.metadata.enableTmdb),
                description: Text(t.settings.metadata.enableTmdbDesc),
                initialValue: metadataState.tmdbEnabled,
                onToggle: (value) async {
                  await metadataController.setTmdbEnabled(
                    value ?? !metadataState.tmdbEnabled,
                  );
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('元数据聚合说明'),
                description: const Text(
                  '启用后，应用将在搜索与详情页自动匹配 Bangumi 番剧资料与 TMDB 电影电视剧集元数据、演职员表和精美背景海报。',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
