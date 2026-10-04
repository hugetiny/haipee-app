import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:kazumi/pages/setting/setting_controller.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/shaders/providers.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/providers/translations_provider.dart';
import 'package:logger/logger.dart';

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  late final PluginsController pluginsController;
  late final CollectController collectController;
  late final ShadersController shadersController;
  late final MyController myController;
  late final Box setting;

  @override
  void initState() {
    super.initState();
    pluginsController = ref.read(pluginsProvider.notifier);
    collectController = ref.read(collectionsProvider.notifier);
    shadersController = ref.read(shadersControllerProvider);
    myController = ref.read(myControllerProvider.notifier);
    setting = GStorage.setting;

    _pluginInit();
    _webDavInit();
    _migrateStorage();
    _loadShaders();
    _update();
  }

  Future<void> _migrateStorage() async {
    await collectController.migrateCollect();
  }

  Future<void> _loadShaders() async {
    await shadersController.copyShadersToExternalDirectory();
  }

  Future<void> _webDavInit() async {
    final webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (!webDavEnable) return;

    final webDav = WebDav();
    KazumiLogger().log(Level.info, '开始从WEBDAV同步记录');
    try {
      await webDav.init();
      await webDav.downloadAndPatchHistory();
      KazumiLogger().log(Level.info, '同步观看记录完成');
    } catch (e) {
      KazumiLogger().log(Level.error, 'WebDav同步失败: $e');
      final translations = ref.read(translationsProvider);
      KazumiDialog.showToast(
        message: translations.dialogs.webdav.syncFailed
            .replaceFirst('{error}', e.toString()),
      );
    }
  }

  Future<void> _pluginInit() async {
    var statementsText = '';
    try {
      await pluginsController.init();
      statementsText =
          await rootBundle.loadString('assets/statements/statements.txt');
      await _pluginUpdate();
    } catch (_) {}

    if (!mounted) return;

    if (pluginsController.pluginList.isEmpty) {
      await KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (dialogContext) {
          final t = dialogContext.t;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(t.dialogs.disclaimer.title),
              scrollable: true,
              content: Text(statementsText),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    exit(0);
                  },
                  child: Text(
                    t.dialogs.disclaimer.exit,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.outline,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await pluginsController.copyPluginsToExternalDirectory();
                    } catch (_) {}
                    KazumiDialog.dismiss();
                    if (!Platform.isAndroid) {
                      _goHome();
                    } else {
                      await _switchUpdateMirror();
                    }
                  },
                  child: Text(t.dialogs.disclaimer.agree),
                ),
              ],
            ),
          );
        },
      );
    } else {
      _goHome();
    }
  }

  Future<void> _switchUpdateMirror() async {
    await KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(t.dialogs.updateMirror.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t.dialogs.updateMirror.question),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t.dialogs.updateMirror.description),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, true);
                  KazumiDialog.dismiss();
                  _goHome();
                },
                child: Text(t.dialogs.updateMirror.options.github),
              ),
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  KazumiDialog.dismiss();
                  _goHome();
                },
                child: Text(t.dialogs.updateMirror.options.fdroid),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _update() async {
    if (pluginsController.pluginList.isEmpty) {
      return;
    }

    final autoUpdate =
        setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (autoUpdate) {
      await myController.checkUpdate(type: 'auto');
    }
  }

  Future<void> _pluginUpdate() async {
    await pluginsController.queryPluginHTTPList();
    var count = 0;
    for (final plugin in pluginsController.pluginList) {
      if (pluginsController.pluginUpdateStatus(plugin) == 'updatable') {
        count++;
      }
    }
    if (count != 0) {
      final translations = ref.read(translationsProvider);
      KazumiDialog.showToast(
        message: translations.dialogs.pluginUpdates.toast
            .replaceFirst('{count}', '$count'),
      );
    }
  }

  void _goHome() {
    if (!mounted) return;
    context.go(Routes.popular);
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.shortestSide >= 600 &&
        (MediaQuery.of(context).size.shortestSide /
                MediaQuery.of(context).size.longestSide >=
            9 / 16);

    if (isWideScreen) {
      KazumiLogger().log(Level.info, '当前设备宽屏');
    } else {
      KazumiLogger().log(Level.info, '当前设备非宽屏');
    }
    setting.put(SettingBoxKey.isWideScreen, isWideScreen);
    return const LoadingWidget();
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
