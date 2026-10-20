import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/webdav_editor/providers.dart';
import 'package:kazumi/providers/translations_provider.dart';

class WebDavSettingsPage extends ConsumerWidget {
  const WebDavSettingsPage({super.key});

  void _dismissDialogIfNeeded() {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
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
                            KazumiDialog.showToast(message: result.message);
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
                            KazumiDialog.showToast(message: result.message);
                          }
                        },
                        title: Text(t.settings.webdav.tile.historyToggle),
                        description:
                            Text(t.settings.webdav.tile.historyDescription),
                        initialValue: state.webDavEnableHistory,
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
                    bottomInfo: Text(t.settings.webdav.info.upload),
                    tiles: [
                      SettingsTile(
                        trailing: const Icon(Icons.cloud_upload_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          KazumiDialog.showToast(
                              message: t.settings.webdav.toast.uploading);
                          final result = await controller.updateWebDav();
                          KazumiDialog.showToast(message: result.message);
                        },
                        title: Text(t.settings.webdav.tile.manualUpload),
                      ),
                    ],
                  ),
                  SettingsSection(
                    bottomInfo: Text(t.settings.webdav.info.download),
                    tiles: [
                      SettingsTile(
                        trailing: const Icon(Icons.cloud_download_rounded),
                        onPressed: (_) async {
                          if (state.isBusy) {
                            return;
                          }
                          KazumiDialog.showToast(
                              message: t.settings.webdav.toast.downloading);
                          final result = await controller.downloadWebDav();
                          KazumiDialog.showToast(message: result.message);
                        },
                        title: Text(t.settings.webdav.tile.manualDownload),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
