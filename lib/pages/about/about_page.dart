import 'dart:io';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/setting/setting_controller.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

/// ✅ Provider for cache size in MB
final cacheSizeMBProvider = StateProvider.autoDispose<double>((ref) => -1);

/// ✅ Provider for auto update setting
final autoUpdateProvider = StateProvider.autoDispose<bool>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
});

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  var setting = GStorage.setting;
  late final MyController myController;

  @override
  void initState() {
    super.initState();
    myController = ref.read(myControllerProvider.notifier);
    _getCacheSize();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<Directory> _getCacheDir() async {
    Directory tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/libCachedImageData');
  }

  Future<void> _getCacheSize() async {
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
    final Directory libCacheDir = await _getCacheDir();
    await libCacheDir.delete(recursive: true);
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
                  _clearCache();
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

  @override
  Widget build(BuildContext context) {
    final String danDanAppId = GStorage.readDanDanAppId();
    final aboutTranslations = context.t.settings.about;
    final sections = aboutTranslations.sections;
    final licenses = sections.licenses;
    final links = sections.links;
    final cache = sections.cache;
    final updates = sections.updates;
    final formattedDanmakuId = links.danmakuId
        .replaceFirst('{id}', danDanAppId.isEmpty ? '-' : danDanAppId);

    // ✅ Watch providers
    final cacheSizeMB = ref.watch(cacheSizeMBProvider);
    final autoUpdate = ref.watch(autoUpdateProvider);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(title: Text(aboutTranslations.title)),
        // backgroundColor: Colors.transparent,
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    _push('/settings/about/license');
                  },
                  title: Text(licenses.title),
                  description: Text(licenses.description),
                ),
              ],
            ),
            SettingsSection(
              title: Text(links.title),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.projectUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text(links.project),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.sourceUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text(links.repository),
                  value: const Text('Github'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.iconUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text(links.icon),
                  value: const Text('Pixiv'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.bangumiIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text(links.index),
                  value: const Text('Bangumi'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.dandanIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text(links.danmaku),
                  description: Text(formattedDanmakuId),
                  value: const Text('DanDanPlay'),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    _showCacheDialog();
                  },
                  title: Text(cache.clearAction),
                  value: cacheSizeMB == -1
                      ? Text(cache.sizePending)
                      : Text(
                          cache.sizeLabel.replaceFirst(
                            '{size}',
                            cacheSizeMB.toStringAsFixed(2),
                          ),
                        ),
                ),
              ],
            ),
            SettingsSection(
              title: Text(updates.title),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final newValue = value ?? !autoUpdate;
                    await setting.put(SettingBoxKey.autoUpdate, newValue);
                    ref.read(autoUpdateProvider.notifier).state = newValue;
                  },
                  title: Text(updates.autoUpdate),
                  initialValue: autoUpdate,
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    myController.checkUpdate();
                  },
                  title: Text(updates.check),
                  value: Text(
                    updates.currentVersion
                        .replaceFirst('{version}', Api.version),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(String path) {
    if (!mounted) return;
    context.push(path);
  }
}
