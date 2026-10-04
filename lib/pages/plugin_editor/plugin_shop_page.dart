import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/storage.dart';

class PluginShopPage extends ConsumerStatefulWidget {
  const PluginShopPage({super.key});

  @override
  ConsumerState<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends ConsumerState<PluginShopPage> {
  final Box setting = GStorage.setting;
  late ValueNotifier<bool> enableGitProxyNotifier;
  late final PluginsController pluginsController;

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    pluginsController = ref.read(pluginsProvider.notifier);
    enableGitProxyNotifier = ValueNotifier<bool>(
      setting.get(SettingBoxKey.enableGitProxy, defaultValue: false),
    );

    // Load plugin list on first visit
    if (pluginsController.pluginHTTPList.isEmpty) {
      Future.microtask(() {
        if (mounted) {
          _handleRefresh();
        }
      });
    }
  }

  @override
  void dispose() {
    enableGitProxyNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // ✅ Read loading state from provider
    final loading = ref.read(pluginShopUIProvider).isLoading;
    if (loading) {
      return;
    }

    ref.read(pluginShopUIProvider.notifier).setLoading(true);
    ref.read(pluginShopUIProvider.notifier).setTimeout(false);

    enableGitProxyNotifier.value =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);

    try {
      await pluginsController.queryPluginHTTPList();
      if (!mounted) {
        return;
      }

      ref.read(pluginShopUIProvider.notifier).setLoading(false);
      ref
          .read(pluginShopUIProvider.notifier)
          .setTimeout(pluginsController.pluginHTTPList.isEmpty);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ref.read(pluginShopUIProvider.notifier).setLoading(false);
      ref.read(pluginShopUIProvider.notifier).setTimeout(true);
    }
  }

  void _toggleSort() {
    final currentSort = ref.read(pluginShopUIProvider).sortByName;
    ref.read(pluginShopUIProvider.notifier).setSortByName(!currentSort);
  }

  Widget buildPluginHTTPListBody(
      BuildContext context, List<PluginHTTPItem> pluginHTTPList) {
    final pluginTexts = context.t.settings.plugins;
    final shopTexts = pluginTexts.shop;
    final sortedList = List<PluginHTTPItem>.from(pluginHTTPList);

    // ✅ Read sort mode from provider
    final sortByName =
        ref.watch(pluginShopUIProvider.select((s) => s.sortByName));

    if (sortByName) {
      sortedList.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      sortedList.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
    }

    return ListView.builder(
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final item = sortedList[index];
        final status = pluginsController.pluginStatus(item);
        final bool isInstall = status == 'install';
        final bool isInstalled = status == 'installed';
        final formattedTimestamp =
            DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
                .toString()
                .split('.')[0];

        return Card(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: ListTile(
            title: Row(
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 1.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        item.version,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 1.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        item.useNativePlayer
                            ? shopTexts.labels.playerType.native
                            : shopTexts.labels.playerType.webview,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.lastUpdate > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    shopTexts.labels.lastUpdated
                        .replaceFirst('{timestamp}', formattedTimestamp),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
            trailing: TextButton(
              onPressed: isInstalled
                  ? null
                  : () async {
                      final loadingMessage = isInstall
                          ? pluginTexts.loading.importing
                          : pluginTexts.loading.updatingSingle;
                      KazumiDialog.showToast(
                        message: loadingMessage,
                      );
                      final res = await pluginsController
                          .tryUpdatePluginByName(item.name);
                      if (res == 0) {
                        KazumiDialog.showToast(
                          message: isInstall
                              ? pluginTexts.toast.importSuccess
                              : pluginTexts.toast.updateSuccess,
                        );
                      } else if (res == 1) {
                        KazumiDialog.showToast(
                          message: pluginTexts.toast.updateIncompatible,
                        );
                      } else if (res == 2) {
                        KazumiDialog.showToast(
                          message: isInstall
                              ? shopTexts.toast.importFailed
                              : pluginTexts.toast.updateFailed,
                        );
                      }
                    },
              child: Text(
                isInstall
                    ? shopTexts.buttons.install
                    : isInstalled
                        ? shopTexts.buttons.installed
                        : shopTexts.buttons.update,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pluginsState = ref.watch(pluginsProvider);
    final pluginHTTPList = pluginsState.pluginHTTPList;
    final pluginTexts = context.t.settings.plugins;
    final shopTexts = pluginTexts.shop;

    // ✅ Watch state from providers
    final loading = ref.watch(pluginShopUIProvider.select((s) => s.isLoading));
    final timeout = ref.watch(pluginShopUIProvider.select((s) => s.isTimeout));
    final sortByName =
        ref.watch(pluginShopUIProvider.select((s) => s.sortByName));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: Text(shopTexts.title),
          actions: [
            IconButton(
              onPressed: _toggleSort,
              tooltip: sortByName
                  ? shopTexts.tooltip.sortByName
                  : shopTexts.tooltip.sortByUpdate,
              icon: Icon(
                sortByName ? Icons.sort_by_alpha : Icons.access_time,
              ),
            ),
            IconButton(
              onPressed: _handleRefresh,
              tooltip: shopTexts.tooltip.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: enableGitProxyNotifier,
          builder: (context, enableGitProxy, child) {
            return loading
                ? const Center(child: CircularProgressIndicator())
                : pluginHTTPList.isEmpty
                    ? (timeout
                        ? Center(
                            child: GeneralErrorWidget(
                              errMsg: shopTexts.error.unreachable.replaceFirst(
                                '{status}',
                                enableGitProxy
                                    ? shopTexts.error.mirrorEnabled
                                    : shopTexts.error.mirrorDisabled,
                              ),
                              actions: [
                                GeneralErrorButton(
                                  onPressed: () async {
                                    if (!mounted) {
                                      return;
                                    }
                                    // Toggle GitHub proxy setting
                                    final newValue = !enableGitProxy;
                                    await setting.put(
                                        SettingBoxKey.enableGitProxy, newValue);
                                    enableGitProxyNotifier.value = newValue;
                                    // Show toast notification
                                    KazumiDialog.showToast(
                                      message: newValue
                                          ? shopTexts.error.mirrorEnabled
                                          : shopTexts.error.mirrorDisabled,
                                    );
                                    // Refresh plugin list with new proxy setting
                                    _handleRefresh();
                                  },
                                  text: enableGitProxy
                                      ? shopTexts.buttons.toggleMirrorDisable
                                      : shopTexts.buttons.toggleMirrorEnable,
                                ),
                                GeneralErrorButton(
                                  onPressed: () {
                                    _handleRefresh();
                                  },
                                  text: shopTexts.buttons.refresh,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink())
                    : buildPluginHTTPListBody(context, pluginHTTPList);
          },
        ),
      ),
    );
  }
}
