import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/pages/webdav_editor/providers.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  late final MockBox setting;
  late int exitBehavior;

  @override
  void initState() {
    super.initState();
    setting = GStorage.setting;
    exitBehavior =
        setting.get(SettingBoxKey.exitBehavior, defaultValue: 2) as int;
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.popular);
  }

  void _updateAppBarConfig() {
    if (!mounted) return;
    final t = context.t;

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: t.settings.title, // 修正翻译键
      needTopOffset: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t; // Get translations
    final webDavState = ref.watch(webDavSettingsProvider);
    final webDavController = ref.read(webDavSettingsProvider.notifier);
    final metadataState = ref.watch(metadataSettingsProvider);
    final metadataController = ref.read(metadataSettingsProvider.notifier);
    final localeState = ref.watch(localeSettingsProvider);

    // 初始化时设置 AppBar
    Future.microtask(() {
      if (mounted) {
        _updateAppBarConfig();
      }
    });

    // Exit behavior options
    final List<String> exitBehaviorTitles = [
      t.settings.general.exitApp,
      t.settings.general.minimizeToTray,
      t.settings.general.askEveryTime,
    ];

    // App locale options
    final List<_AppLocaleOption> appLocaleOptions = [
      _AppLocaleOption(
        label: t.settings.general.followSystem,
        locale: null,
      ),
      _AppLocaleOption(
        label: '简体中文 (zh-CN)',
        locale: AppLocale.zhCn,
      ),
      _AppLocaleOption(
        label: 'English (en-US)',
        locale: AppLocale.enUs,
      ),
      _AppLocaleOption(
        label: '日本語 (ja-JP)',
        locale: AppLocale.jaJp,
      ),
      _AppLocaleOption(
        label: '繁體中文 (zh-TW)',
        locale: AppLocale.zhTw,
      ),
    ];

    final String appLocaleLabel;
    if (localeState.followSystem) {
      appLocaleLabel = appLocaleOptions.first.label;
    } else {
      appLocaleLabel = appLocaleOptions
          .firstWhere(
            (option) => option.locale == localeState.appLocale,
            orElse: () => _AppLocaleOption(
              label: localeState.appLocale.flutterLocale.toLanguageTag(),
              locale: localeState.appLocale,
            ),
          )
          .label;
    }

    final isDesktop = Utils.isDesktop();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: SettingsList(
        maxWidth: 1000,
        sections: [
            SettingsSection(
              title: Text(t.settings.general.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsTheme);
                  },
                  title: Text(t.settings.general.appearance),
                  description: Text(t.settings.general.appearanceDesc),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsLanguage);
                  },
                  title: Text(t.settings.general.language),
                  description: Text(t.settings.general.languageDesc),
                  value: Text(appLocaleLabel),
                ),
                if (isDesktop)
                  SettingsTile.navigation(
                    onPressed: (_) {
                      context.push(Routes.settingsExitBehavior);
                    },
                    title: Text(t.settings.general.exitBehavior),
                    value: Text(exitBehaviorTitles[exitBehavior]),
                  ),
              ],
            ),
            SettingsSection(
              title: Text(t.settings.source.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsPlugin);
                  },
                  title: Text(t.settings.source.ruleManagement),
                  description: Text(t.settings.source.ruleManagementDesc),
                ),
                SettingsTile.switchTile(
                  enabled: webDavState.initialized,
                  onToggle: (value) async {
                    if (!webDavState.initialized) {
                      return;
                    }
                    await webDavController.toggleGitProxy(
                      value ?? !webDavState.enableGitProxy,
                    );
                  },
                  title: Text(t.settings.source.githubProxy),
                  description: Text(t.settings.source.githubProxyDesc),
                  initialValue: webDavState.enableGitProxy,
                ),
              ],
            ),
            SettingsSection(
              title: Text(t.settings.metadata.title),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await metadataController.setBangumiEnabled(
                      value ?? !metadataState.bangumiEnabled,
                    );
                  },
                  title: Text(t.settings.metadata.enableBangumi),
                  description: Text(t.settings.metadata.enableBangumiDesc),
                  initialValue: metadataState.bangumiEnabled,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await metadataController.setTmdbEnabled(
                      value ?? !metadataState.tmdbEnabled,
                    );
                  },
                  title: Text(t.settings.metadata.enableTmdb),
                  description: Text(t.settings.metadata.enableTmdbDesc),
                  initialValue: metadataState.tmdbEnabled,
                ),
              ],
            ),
            SettingsSection(
              title: Text(t.settings.player.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsPlayer);
                  },
                  title: Text(t.settings.player.playerSettings),
                  description: Text(t.settings.player.playerSettingsDesc),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsDanmaku);
                  },
                  title: Text(t.settings.player.danmakuSettings),
                  description: Text(t.settings.player.danmakuSettingsDesc),
                ),
              ],
            ),
            SettingsSection(
              title: Text(t.settings.webdav.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsWebdav);
                  },
                  title: Text(t.settings.webdav.title),
                  description: Text(t.settings.webdav.desc),
                ),
              ],
            ),
            SettingsSection(
              title: Text(t.settings.other.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsWebdav);
                  },
                  leading: const Icon(Icons.cloud),
                  title: const Text('WebDAV'),
                  description: const Text('设置同步参数'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsAbout);
                  },
                  title: Text(t.settings.other.about),
                ),
              ],
            ),
            // Conditionally show download section if aria2 is available
            if (Aria2FeatureManager().isAvailable)
              SettingsSection(
                title: const Text('下载'),
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) {
                      context.push('/settings/download');
                    },
                    leading: const Icon(Icons.download),
                    title: const Text('下载设置'),
                    description: const Text('配置 aria2 下载参数'),
                  ),
                ],
              ),
          ],
        ),
    );
  }
}

class _AppLocaleOption {
  const _AppLocaleOption({required this.label, required this.locale});

  final String label;
  final AppLocale? locale;
}
