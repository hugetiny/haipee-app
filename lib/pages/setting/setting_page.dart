import 'dart:io';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/pages/setting/setting_controller.dart';
import 'package:kazumi/pages/setting/widgets/git_proxy_dialog.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:path_provider/path_provider.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  late final Box setting;
  late int exitBehavior;
  late final MyController myController;

  @override
  void initState() {
    super.initState();
    setting = GStorage.setting;
    exitBehavior =
        setting.get(SettingBoxKey.exitBehavior, defaultValue: 2) as int;
    myController = ref.read(myControllerProvider.notifier);
    _getCacheSize();
  }

  Future<Directory> _getCacheDir() async {
    Directory tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/libCachedImageData');
  }

  Future<void> _getCacheSize() async {
    try {
      Directory cacheDir = await _getCacheDir();

      if (await cacheDir.exists()) {
        int totalSizeBytes = await _getTotalSizeOfFilesInDir(cacheDir);
        double totalSizeMB = (totalSizeBytes / (1024 * 1024));

        if (mounted) {
          ref.read(cacheSizeMBProvider.notifier).state = totalSizeMB;
        }
      } else {
        if (mounted) {
          ref.read(cacheSizeMBProvider.notifier).state = 0.0;
        }
      }
    } catch (_) {
      if (mounted) {
        ref.read(cacheSizeMBProvider.notifier).state = 0.0;
      }
    }
  }

  Future<int> _getTotalSizeOfFilesInDir(final Directory directory) async {
    final List<FileSystemEntity> children = directory.listSync();
    int total = 0;

    try {
      for (final FileSystemEntity child in children) {
        if (child is File) {
          final int length = await child.length();
          total += length;
        } else if (child is Directory) {
          total += await _getTotalSizeOfFilesInDir(child);
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    try {
      final Directory libCacheDir = await _getCacheDir();
      if (await libCacheDir.exists()) {
        await libCacheDir.delete(recursive: true);
      }
    } catch (_) {}
    _getCacheSize();
  }

  void _showCacheDialog() {
    KazumiDialog.show(
      builder: (context) {
        final cacheDialog = context.t.dialogs.cache;
        return AlertDialog(
          title: Text(cacheDialog.title),
          content: Text(cacheDialog.message),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                context.t.app.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _clearCache();
                } catch (_) {}
                KazumiDialog.dismiss();
              },
              child: Text(context.t.app.confirm),
            ),
          ],
        );
      },
    );
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.media);
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
    final gitProxyState = ref.watch(gitProxyProvider);
    final metadataState = ref.watch(metadataSettingsProvider);
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

    final cacheSizeMB = ref.watch(cacheSizeMBProvider);
    final autoUpdate = ref.watch(autoUpdateProvider);
    final debugLogsEnabled = ref.watch(debugLogsEnabledProvider);

    final isDesktop = Utils.isDesktop();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        onBackPressed(context);
      },
      child: SettingsList(
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
              SettingsTile.navigation(
                onPressed: (_) {
                  _showCacheDialog();
                },
                title: Text(t.settings.about.sections.cache.clearAction),
                value: cacheSizeMB == -1
                    ? Text(t.settings.about.sections.cache.sizePending)
                    : Text(
                        t.settings.about.sections.cache.sizeLabel.replaceFirst(
                          '{size}',
                          cacheSizeMB.toStringAsFixed(2),
                        ),
                      ),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  final newValue = value ?? !autoUpdate;
                  await setting.put(SettingBoxKey.autoUpdate, newValue);
                  ref.read(autoUpdateProvider.notifier).state = newValue;
                },
                title: Text(t.settings.about.sections.updates.autoUpdate),
                initialValue: autoUpdate,
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  myController.checkUpdate();
                },
                title: Text(t.settings.about.sections.updates.check),
                value: Text(
                  t.settings.about.sections.updates.currentVersion
                      .replaceFirst('{version}', Api.version),
                ),
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  context.push(Routes.settingsAboutLicense);
                },
                title: Text(t.settings.about.sections.licenses.title),
                description: Text(t.settings.about.sections.licenses.description),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  final newValue = value ?? !debugLogsEnabled;
                  ref.read(debugLogsEnabledProvider.notifier).setEnabled(newValue);
                },
                title: const Text('运行日志与诊断'),
                initialValue: debugLogsEnabled,
              ),
              if (debugLogsEnabled)
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsAboutLogs);
                  },
                  title: const Text('查看运行日志与诊断面板'),
                ),
            ],
          ),
          SettingsSection(
            title: const Text('视听与媒体'),
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
              SettingsTile.navigation(
                onPressed: (_) {
                  context.push(Routes.settingsMetadata);
                },
                title: const Text('媒体元数据与刮削'),
                description: Text(
                  'Bangumi (${metadataState.bangumiEnabled ? "已启用 · ${metadataState.bangumiAcceleration.label}" : "已禁用"}) · TMDB (${metadataState.tmdbEnabled ? "已启用" : "已禁用"})',
                ),
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  context.push(Routes.settingsPlugin);
                },
                title: const Text('Kazumi 视频规则'),
                description: Text(t.settings.source.ruleManagementDesc),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('资源检索与下载'),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) {
                  context.push(Routes.settingsIndexers);
                },
                title: const Text('Cardigann 规则'),
                description: const Text('Cardigann 规则中心与索引源管理'),
              ),
              if (Aria2FeatureManager().isAvailable)
                SettingsTile.navigation(
                  onPressed: (_) {
                    context.push(Routes.settingsDownload);
                  },
                  leading: const Icon(Icons.download),
                  title: const Text('下载设置'),
                  description: const Text('配置 aria2 下载参数'),
                ),
            ],
          ),
          SettingsSection(
            title: const Text('数据与云同步'),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) {
                  GitProxyDialog.show(context);
                },
                leading: const Icon(Icons.alt_route_rounded),
                title: Text(t.settings.source.githubProxy),
                description: const Text('底层加速 Kazumi 视频规则、Cardigann 规则与更新'),
                value: Text(
                  gitProxyState.enabled
                      ? '已启用 · ${gitProxyState.proxyUrl.replaceAll("https://", "").replaceAll("/", "")}'
                      : '未启用',
                  style: TextStyle(
                    color: gitProxyState.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    fontWeight:
                        gitProxyState.enabled ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  context.push(Routes.settingsWebdav);
                },
                leading: const Icon(Icons.cloud_sync_rounded),
                title: Text(t.settings.webdav.title),
                description: Text(t.settings.webdav.desc),
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
