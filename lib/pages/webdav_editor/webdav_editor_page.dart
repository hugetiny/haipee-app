import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/webdav_editor/providers.dart';
import 'package:kazumi/providers/translations_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';

/// Provider for password visibility toggle
final webdavPasswordVisibleProvider =
    StateProvider.autoDispose<bool>((ref) => false);

class WebDavEditorPage extends ConsumerStatefulWidget {
  const WebDavEditorPage({
    super.key,
  });

  @override
  ConsumerState<WebDavEditorPage> createState() => _WebDavEditorPageState();
}

class _WebDavEditorPageState extends ConsumerState<WebDavEditorPage> {
  final TextEditingController webDavURLController = TextEditingController();
  final TextEditingController webDavUsernameController =
      TextEditingController();
  final TextEditingController webDavPasswordController =
      TextEditingController();
  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    webDavURLController.text =
        setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    webDavUsernameController.text =
        setting.get(SettingBoxKey.webDavUsername, defaultValue: '');
    webDavPasswordController.text =
        setting.get(SettingBoxKey.webDavPassword, defaultValue: '');
  }

  @override
  void dispose() {
    webDavURLController.dispose();
    webDavUsernameController.dispose();
    webDavPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final passwordVisible = ref.watch(webdavPasswordVisibleProvider);

    return Scaffold(
      appBar: SysAppBar(
        title: Text(t.settings.webdav.editor.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: Column(
              children: [
                TextField(
                  controller: webDavURLController,
                  decoration: InputDecoration(
                    labelText: t.settings.webdav.editor.url,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: webDavUsernameController,
                  decoration: InputDecoration(
                    labelText: t.settings.webdav.editor.username,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: webDavPasswordController,
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    labelText: t.settings.webdav.editor.password,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        ref.read(webdavPasswordVisibleProvider.notifier).state =
                            !passwordVisible;
                      },
                      icon: Icon(passwordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                // const SizedBox(height: 20),
                // ExpansionTile(
                //   title: const Text('高级选项'),
                //   children: [],
                // ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          await setting.put(SettingBoxKey.webDavURL, webDavURLController.text);
          await setting.put(
              SettingBoxKey.webDavUsername, webDavUsernameController.text);
          await setting.put(
              SettingBoxKey.webDavPassword, webDavPasswordController.text);
          final webDav = WebDav();
          try {
            await webDav.init();
          } catch (e) {
            KazumiDialog.showToast(
              message: t.settings.webdav.editor.toast.saveFailed
                  .replaceFirst('{error}', e.toString()),
            );
            await setting.put(SettingBoxKey.webDavEnable, false);
            await ref
                .read(webDavSettingsProvider.notifier)
                .refreshFromStorage();
            return;
          }
          KazumiDialog.showToast(
            message: t.settings.webdav.editor.toast.saveSuccess,
          );
          try {
            await webDav.ping();
            KazumiDialog.showToast(
              message: t.settings.webdav.editor.toast.testSuccess,
            );
          } catch (e) {
            KazumiDialog.showToast(
              message: t.settings.webdav.editor.toast.testFailed
                  .replaceFirst('{error}', e.toString()),
            );
            await setting.put(SettingBoxKey.webDavEnable, false);
          }
          await ref.read(webDavSettingsProvider.notifier).refreshFromStorage();
        },
      ),
    );
  }
}
