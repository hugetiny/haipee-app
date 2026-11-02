import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/my/my_controller.dart';
import 'package:haipee/pages/my/providers.dart';
import 'package:haipee/pages/setting/setting_controller.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/shaders/providers.dart';
import 'package:haipee/shaders/shaders_controller.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/webdav.dart';
import 'package:haipee/providers/translations_provider.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/storage/storage.dart';
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
    HaipeeLogger().log(Level.info, '开始从WEBDAV同步记录');
    try {
      await webDav.init();
      await webDav.downloadAndPatchHistory();
      HaipeeLogger().log(Level.info, '同步观看记录完成');
    } catch (e) {
      HaipeeLogger().log(Level.error, 'WebDav同步失败: $e');
      final translations = ref.read(translationsProvider);
      HaipeeDialog.showToast(
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

    if (AppLog.isFirebaseTestLab) {
      if (pluginsController.pluginList.isEmpty) {
        try {
          await pluginsController.copyPluginsToExternalDirectory();
        } catch (_) {}
      }
      _goHome();
      return;
    }

    if (pluginsController.pluginList.isEmpty) {
      await HaipeeDialog.show(
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
                    HaipeeDialog.dismiss();
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
    await HaipeeDialog.show(
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
                  HaipeeDialog.dismiss();
                  _goHome();
                },
                child: Text(t.dialogs.updateMirror.options.github),
              ),
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  HaipeeDialog.dismiss();
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
      HaipeeDialog.showToast(
        message: translations.dialogs.pluginUpdates.toast
            .replaceFirst('{count}', '$count'),
      );
    }
  }

  void _goHome() {
    if (!mounted) return;
    String defaultStartupPage =
        GStorage.getSetting<String>(SettingsKeys.defaultStartupPage).trim();
    if (defaultStartupPage.endsWith('/') && defaultStartupPage.length > 1) {
      defaultStartupPage =
          defaultStartupPage.substring(0, defaultStartupPage.length - 1);
    }
    if (defaultStartupPage.isNotEmpty) {
      context.go(defaultStartupPage);
    } else {
      context.go(Routes.onlineVideo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.shortestSide >= 600 &&
        (MediaQuery.of(context).size.shortestSide /
                MediaQuery.of(context).size.longestSide >=
            9 / 16);

    if (isWideScreen) {
      HaipeeLogger().log(Level.info, '当前设备宽屏');
    } else {
      HaipeeLogger().log(Level.info, '当前设备非宽屏');
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
