import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/webdav_editor/providers.dart';
import 'package:haipee/providers/translations_provider.dart';

class WebDavSettingsPage extends ConsumerWidget {
  const WebDavSettingsPage({super.key});

  void _dismissDialogIfNeeded() {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webDavSettingsProvider);
    final controller = ref.read(webDavSettingsProvider.notifier);
    final t = ref.watch(translationsProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool _, Object? __) {
        _dismissDialogIfNeeded();
      },
      child: Scaffold(
        appBar: SysAppBar(title: Text(t.settings.webdav.pageTitle)),
        body: !state.initialized
            ? const Center(child: CircularProgressIndicator())
            : SettingsList(
                sections: [
                  SettingsSection(
                    title: Text(t.settings.webdav.section.webdav),
                    tiles: [
                      SettingsTile.switchTile(
                        onToggle: (value) async {
                          final result = await controller.toggleWebDav(
                            value ?? !state.webDavEnable,
                          );
                          if (!result.success && result.message.isNotEmpty) {
                            HaipeeDialog.showToast(message: result.message);
                          }
                        },
                        title: Text(t.settings.webdav.tile.webdavToggle),
                        initialValue: state.webDavEnable,
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) async {
                          final result = await controller.toggleWebDavHistory(
                            value ?? !state.webDavEnableHistory,
                          );
                          if (!result.success && result.message.isNotEmpty) {
                            HaipeeDialog.showToast(message: result.message);
                          }
                        },
                        title: Text(t.settings.webdav.tile.historyToggle),
                        description:
                            Text(t.settings.webdav.tile.historyDescription),
                        initialValue: state.webDavEnableHistory,
                      ),
                      SettingsTile.switchTile(
                        key: const Key('webdav_tile_collect'),
                        onToggle: (value) async {
                          final result = await controller.toggleWebDavCollect(
                            value ?? !state.webDavEnableCollect,
                          );
                          if (!result.success && result.message.isNotEmpty) {
                            HaipeeDialog.showToast(message: result.message);
                          }
                        },
                        title: const Text('追番收藏同步'),
                        description: const Text('在收藏页同步所有追番分类'),
                        initialValue: state.webDavEnableCollect,
                      ),
                      SettingsTile.switchTile(
                        key: const Key('webdav_tile_danmaku_shield'),
                        onToggle: (value) async {
                          final result =
                              await controller.toggleWebDavDanmakuShield(
                            value ?? !state.webDavEnableDanmakuShield,
                          );
                          if (!result.success && result.message.isNotEmpty) {
                            HaipeeDialog.showToast(message: result.message);
                          }
                        },
                        title: const Text('弹幕屏蔽词同步'),
                        description: const Text('自动同步弹幕屏蔽词列表'),
                        initialValue: state.webDavEnableDanmakuShield,
                      ),
                      SettingsTile.navigation(
                        onPressed: (_) {
                          context.push(Routes.settingsWebdavEditor);
                        },
                        title: Text(t.settings.webdav.tile.config),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: const Text('观看记录'),
                    bottomInfo: Text(t.settings.webdav.info.upload),
                    tiles: [
                      SettingsTile(
                        trailing: const Icon(Icons.cloud_upload_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          HaipeeDialog.showToast(
                              message: t.settings.webdav.toast.uploading);
                          final result = await controller.updateWebDav();
                          HaipeeDialog.showToast(message: result.message);
                        },
                        title: Text(t.settings.webdav.tile.manualUpload),
                      ),
                      SettingsTile(
                        trailing: const Icon(Icons.cloud_download_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          HaipeeDialog.showToast(
                              message: t.settings.webdav.toast.downloading);
                          final result = await controller.downloadWebDav();
                          HaipeeDialog.showToast(message: result.message);
                        },
                        title: Text(t.settings.webdav.tile.manualDownload),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: const Text('追番收藏'),
                    bottomInfo: const Text('双向合并本地与云端追番列表，并生成最新全量备份。'),
                    tiles: [
                      SettingsTile(
                        trailing: const Icon(Icons.sync_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          HaipeeDialog.showToast(
                              message: '正在同步追番收藏...');
                          final result = await controller.syncCollectibles();
                          HaipeeDialog.showToast(message: result.message);
                        },
                        title: const Text('立即同步追番收藏'),
                      ),
                      SettingsTile(
                        trailing: const Icon(Icons.backup_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          HaipeeDialog.showToast(
                              message: '正在备份追番收藏...');
                          final result = await controller.updateCollectibles();
                          HaipeeDialog.showToast(message: result.message);
                        },
                        title: const Text('手动备份追番收藏'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
