import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/storage/storage.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final metadataState = ref.watch(metadataSettingsProvider);
    final hasServer =
        GStorage.getSetting(SettingsKeys.webDavURL).trim().isNotEmpty;
    final webDavEnabled = GStorage.getSetting(SettingsKeys.webDavEnable);
    final hasSyncContent =
        GStorage.getSetting(SettingsKeys.webDavEnableHistory) ||
            GStorage.getSetting(SettingsKeys.webDavEnableCollect) ||
            GStorage.getSetting(SettingsKeys.webDavEnableDanmakuShield);

    final colors = Theme.of(context).colorScheme;

    final cards = [
      _SyncCard(
        title: '追番与媒体元数据',
        service: 'Bangumi & TMDB',
        description: '自动刮削剧集封面、分集简介，支持网络加速。',
        content:
            'Bangumi: ${metadataState.bangumiEnabled ? "已启用 (${metadataState.bangumiAcceleration.label})" : "已禁用"} · TMDB: ${metadataState.tmdbEnabled ? "已启用" : "已禁用"}',
        icon: Icons.auto_awesome_mosaic_rounded,
        color: colors.secondaryContainer,
        onColor: colors.onSecondaryContainer,
        statusText: metadataState.bangumiEnabled || metadataState.tmdbEnabled
            ? '已开启'
            : '已关闭',
        statusIcon: metadataState.bangumiEnabled || metadataState.tmdbEnabled
            ? Icons.check_circle_outline_rounded
            : Icons.pause_circle_outline_rounded,
        action: '管理元数据与刮削',
        onPressed: () => context.push(Routes.settingsMetadata),
      ),
      _SyncCard(
        title: '多设备数据同步',
        service: 'WebDAV',
        description: '通过私有云盘或 NAS，在不同设备间无缝同步。',
        content: '观看记录 · 追番收藏 · 弹幕屏蔽词',
        icon: Icons.cloud_sync_rounded,
        color: colors.tertiaryContainer,
        onColor: colors.onTertiaryContainer,
        statusText: !hasServer
            ? '未配置'
            : webDavEnabled
                ? (hasSyncContent ? '已开启' : '待选择内容')
                : '已关闭',
        statusIcon: !hasServer
            ? Icons.settings_outlined
            : webDavEnabled
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
        action: hasServer ? '管理多设备同步' : '配置 WebDAV',
        onPressed: () => context.push(Routes.settingsWebdav),
      ),
    ];

    return SettingsDetailScaffold(
      title: const Text('同步设置'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.sync_rounded,
                            size: 28,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '让追番与数据保持同步',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '通过元数据刮削与 WebDAV 云同步实现全端追番体验。',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 680) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 16),
                            Expanded(child: cards[1]),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 16),
                          cards[1],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.title,
    required this.service,
    required this.description,
    required this.content,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.statusText,
    required this.statusIcon,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String service;
  final String description;
  final String content;
  final IconData icon;
  final Color color;
  final Color onColor;
  final String statusText;
  final IconData statusIcon;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: onColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: colors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            service,
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}
