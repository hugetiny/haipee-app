import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/parse_failure_helper.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

enum PluginSortOption {
  original,     // 默认顺序
  nameAsc,      // 名称升序
  nameDesc,     // 名称降序
  failureAsc,   // 失败次数升序
  failureDesc,  // 失败次数降序
}

/// Provider for plugin sort option
final pluginSortOptionProvider = StateProvider.autoDispose<PluginSortOption>(
  (ref) => PluginSortOption.original,
);

class PluginViewPage extends ConsumerStatefulWidget {
  const PluginViewPage({super.key});

  @override
  ConsumerState<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends ConsumerState<PluginViewPage> {
  late final PluginsController pluginsController;

  Future<void> _handleUpdate() async {
    final pluginTexts = context.t.settings.plugins;
    KazumiDialog.showLoading(msg: pluginTexts.loading.updating);
    int count = await pluginsController.tryUpdateAllPlugin();
    KazumiDialog.dismiss();
    if (count == 0) {
      KazumiDialog.showToast(message: pluginTexts.toast.allUpToDate);
    } else {
      KazumiDialog.showToast(
        message: pluginTexts.toast.updateCount
            .replaceFirst('{count}', count.toString()),
      );
    }
  }

  void _handleAdd() {
    KazumiDialog.show(builder: (context) {
      final pluginTexts = context.t.settings.plugins;
      return AlertDialog(
        // contentPadding: EdgeInsets.zero, // 设置为零以减小内边距
        content: SingleChildScrollView(
          // 使用可滚动的SingleChildScrollView包装Column
          child: Column(
            mainAxisSize: MainAxisSize.min, // 设置为MainAxisSize.min以减小高度
            children: [
              ListTile(
                title: Text(pluginTexts.actions.newRule),
                onTap: () {
                  KazumiDialog.dismiss();
                  context.push(
                    '/settings/plugin/editor',
                    extra: Plugin.fromTemplate(),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: Text(pluginTexts.actions.importFromRepo),
                onTap: () {
                  KazumiDialog.dismiss();
                  context.push(Routes.settingsPluginShop);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: Text(pluginTexts.actions.importFromClipboard),
                onTap: () {
                  KazumiDialog.dismiss();
                  _showInputDialog();
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showInputDialog() {
    final TextEditingController textController = TextEditingController();
    KazumiDialog.show(builder: (context) {
      final pluginTexts = context.t.settings.plugins;
      return AlertDialog(
        title: Text(pluginTexts.dialogs.importTitle),
        content: TextField(
          controller: textController,
        ),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              pluginTexts.actions.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final String msg = textController.text;
              try {
                pluginsController.updatePlugin(Plugin.fromJson(
                    json.decode(Utils.kazumiBase64ToJson(msg))));
                KazumiDialog.showToast(
                    message: pluginTexts.toast.importSuccess);
              } catch (e) {
                KazumiDialog.dismiss();
                KazumiDialog.showToast(
                  message: pluginTexts.toast.importFailed
                      .replaceFirst('{error}', e.toString()),
                );
              }
              KazumiDialog.dismiss();
            },
            child: Text(pluginTexts.actions.import),
          ),
        ],
      );
    });
  }

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
  }

  String _sortOptionLabel(PluginSortOption option) {
    final options = context.t.settings.plugins.sort.options;
    switch (option) {
      case PluginSortOption.original:
        return options.original;
      case PluginSortOption.nameAsc:
        return options.nameAsc;
      case PluginSortOption.nameDesc:
        return options.nameDesc;
      case PluginSortOption.failureAsc:
        return options.failureAsc;
      case PluginSortOption.failureDesc:
        return options.failureDesc;
    }
  }

  List<Plugin> _sortedPlugins(List<Plugin> plugins, PluginSortOption sortOption) {
    switch (sortOption) {
      case PluginSortOption.original:
        return plugins;
      case PluginSortOption.nameAsc:
        return [...plugins]..sort((a, b) => a.name.compareTo(b.name));
      case PluginSortOption.nameDesc:
        return [...plugins]..sort((a, b) => b.name.compareTo(a.name));
      case PluginSortOption.failureAsc:
        return [...plugins]..sort((a, b) {
          final aCount = ParseFailureHelper.getPluginTotalFailures(a.name);
          final bCount = ParseFailureHelper.getPluginTotalFailures(b.name);
          return aCount.compareTo(bCount);
        });
      case PluginSortOption.failureDesc:
        return [...plugins]..sort((a, b) {
          final aCount = ParseFailureHelper.getPluginTotalFailures(a.name);
          final bCount = ParseFailureHelper.getPluginTotalFailures(b.name);
          return bCount.compareTo(aCount);
        });
    }
  }

  void _showSortDialog() {
    final sortTexts = context.t.settings.plugins.sort;
    final sortOption = ref.read(pluginSortOptionProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      sortTexts.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              ...PluginSortOption.values.map((option) {
                final selected = option == sortOption;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(_sortOptionLabel(option)),
                  selected: selected,
                  onTap: () {
                    ref.read(pluginSortOptionProvider.notifier).state = option;
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pluginsState = ref.watch(pluginsProvider);
    final pluginList = pluginsState.pluginList;
    final pluginTexts = context.t.settings.plugins;

    // ✅ Watch multi-select mode and selected names from Riverpod providers
    final isMultiSelectMode =
        ref.watch(pluginSelectionProvider.select((s) => s.multiSelectMode));
    final selectedNames =
        ref.watch(pluginSelectionProvider.select((s) => s.selectedNames));

    return PopScope(
      canPop: !isMultiSelectMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (isMultiSelectMode) {
          ref.read(pluginSelectionProvider.notifier).disableMultiSelect();
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: isMultiSelectMode
              ? Text(
                  pluginTexts.multiSelect.selectedCount.replaceFirst(
                    '{count}',
                    selectedNames.length.toString(),
                  ),
                )
              : Text(pluginTexts.title),
          leading: isMultiSelectMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref
                        .read(pluginSelectionProvider.notifier)
                        .disableMultiSelect();
                  },
                )
              : null,
          actions: [
            if (isMultiSelectMode) ...[
              IconButton(
                onPressed: selectedNames.isEmpty
                    ? null
                    : () {
                        KazumiDialog.show(
                          builder: (context) => AlertDialog(
                            title: Text(pluginTexts.dialogs.deleteTitle),
                            content: Text(
                              pluginTexts.dialogs.deleteMessage.replaceFirst(
                                '{count}',
                                selectedNames.length.toString(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  pluginTexts.actions.cancel,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  pluginsController
                                      .removePlugins(selectedNames);

                                  ref
                                      .read(pluginSelectionProvider.notifier)
                                      .disableMultiSelect();
                                  KazumiDialog.dismiss();
                                },
                                child: Text(pluginTexts.actions.delete),
                              ),
                            ],
                          ),
                        );
                      },
                icon: const Icon(Icons.delete),
              ),
            ] else ...[
              IconButton(
                onPressed: () => _showSortDialog(),
                tooltip: pluginTexts.sort.tooltip,
                icon: const Icon(Icons.sort_rounded),
              ),
              IconButton(
                onPressed: () {
                  _handleUpdate();
                },
                tooltip: pluginTexts.tooltip.updateAll,
                icon: const Icon(Icons.update),
              ),
              IconButton(
                onPressed: () {
                  _handleAdd();
                },
                tooltip: pluginTexts.tooltip.addRule,
                icon: const Icon(Icons.add),
              )
            ],
          ],
        ),
        body: pluginList.isEmpty
            ? Center(
                child: Text(pluginTexts.empty),
              )
            : Builder(builder: (context) {
                final sortOption = ref.watch(pluginSortOptionProvider);
                final sortedList = _sortedPlugins(pluginList, sortOption);

                return ListView.builder(
                    itemCount: sortedList.length,
                    itemBuilder: (context, index) {
                      final plugin = sortedList[index];
                      final bool canUpdate =
                          pluginsController.pluginUpdateStatus(plugin) ==
                              'updatable';
                      // 获取插件总失败次数
                      final failureCount = ParseFailureHelper.getPluginTotalFailures(plugin.name);

                      return Card(
                        key: ValueKey(plugin.name),
                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: ListTile(
                          trailing: pluginCardTrailing(context, plugin, failureCount),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onLongPress: () {
                            if (!isMultiSelectMode) {
                              ref
                                  .read(pluginSelectionProvider.notifier)
                                  .enableMultiSelect();
                              ref
                                  .read(pluginSelectionProvider.notifier)
                                  .toggleSelection(plugin.name);
                            }
                          },
                          onTap: () {
                            if (isMultiSelectMode) {
                              ref
                                  .read(pluginSelectionProvider.notifier)
                                  .toggleSelection(plugin.name);
                              // Check if we should exit multi-select mode
                              final currentState =
                                  ref.read(pluginSelectionProvider);
                              if (currentState.selectedNames.isEmpty) {
                                ref
                                    .read(pluginSelectionProvider.notifier)
                                    .disableMultiSelect();
                              }
                            }
                          },
                          selected: selectedNames.contains(plugin.name),
                          selectedTileColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  plugin.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (failureCount > 0) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showPluginFailureDetails(context, plugin, failureCount),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Tooltip(
                                    message: '历史解析失败 $failureCount 次,点击查看详情',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: failureCount >= 10
                                            ? Theme.of(context).colorScheme.errorContainer
                                            : Theme.of(context).colorScheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 14,
                                            color: failureCount >= 10
                                                ? Theme.of(context).colorScheme.onErrorContainer
                                                : Theme.of(context).colorScheme.onTertiaryContainer,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$failureCount',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: failureCount >= 10
                                                  ? Theme.of(context).colorScheme.onErrorContainer
                                                  : Theme.of(context).colorScheme.onTertiaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pluginTexts.labels.version.replaceFirst(
                                      '{version}',
                                      plugin.version,
                                    ),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  if (canUpdate) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pluginTexts.labels.statusUpdatable,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (pluginsController.validityTracker
                                      .isSearchValid(plugin.name)) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pluginTexts.labels.statusSearchValid,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    });
              }),
      ),
    );
  }

  Widget pluginCardTrailing(BuildContext context, Plugin plugin, int failureCount) {
    // ✅ Read providers in the method
    final isMultiSelectMode =
        ref.watch(pluginSelectionProvider.select((s) => s.multiSelectMode));
    final selectedNames =
        ref.watch(pluginSelectionProvider.select((s) => s.selectedNames));

    return Row(mainAxisSize: MainAxisSize.min, children: [
      isMultiSelectMode
          ? Checkbox(
              value: selectedNames.contains(plugin.name),
              onChanged: (bool? value) {
                ref
                    .read(pluginSelectionProvider.notifier)
                    .toggleSelection(plugin.name);
                // Check if we should exit multi-select mode
                final currentState = ref.read(pluginSelectionProvider);
                if (currentState.selectedNames.isEmpty) {
                  ref
                      .read(pluginSelectionProvider.notifier)
                      .disableMultiSelect();
                }
              },
            )
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showPluginMenu(context, plugin),
            ),
    ]);
  }

  void _showPluginMenu(BuildContext context, Plugin plugin) {
    final pluginTexts = context.t.settings.plugins;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      plugin.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.update_rounded),
                title: Text(pluginTexts.actions.update),
                onTap: () async {
                  Navigator.pop(context);
                  var state = pluginsController.pluginUpdateStatus(plugin);
                  if (state == "nonexistent") {
                    KazumiDialog.showToast(message: pluginTexts.toast.repoMissing);
                  } else if (state == "latest") {
                    KazumiDialog.showToast(message: pluginTexts.toast.alreadyLatest);
                  } else if (state == "updatable") {
                    KazumiDialog.showLoading(msg: pluginTexts.loading.updatingSingle);
                    int res = await pluginsController.tryUpdatePlugin(plugin);
                    KazumiDialog.dismiss();
                    if (res == 0) {
                      KazumiDialog.showToast(message: pluginTexts.toast.updateSuccess);
                    } else if (res == 1) {
                      KazumiDialog.showToast(message: pluginTexts.toast.updateIncompatible);
                    } else if (res == 2) {
                      KazumiDialog.showToast(message: pluginTexts.toast.updateFailed);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(pluginTexts.actions.edit),
                onTap: () {
                  Navigator.pop(context);
                  context.push(Routes.settingsPluginEditor, extra: plugin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(pluginTexts.actions.share),
                onTap: () {
                  Navigator.pop(context);
                  KazumiDialog.show(builder: (context) {
                    return AlertDialog(
                      title: Text(pluginTexts.dialogs.shareTitle),
                      content: SelectableText(
                        Utils.jsonToKazumiBase64(json.encode(plugin.toJson())),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => KazumiDialog.dismiss(),
                          child: Text(
                            pluginTexts.actions.cancel,
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: Utils.jsonToKazumiBase64(json.encode(plugin.toJson())),
                            ));
                            KazumiDialog.dismiss();
                            KazumiDialog.showToast(message: pluginTexts.toast.copySuccess);
                          },
                          child: Text(pluginTexts.actions.copyToClipboard),
                        ),
                      ],
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(pluginTexts.actions.delete),
                onTap: () async {
                  Navigator.pop(context);
                  pluginsController.removePlugin(plugin);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showPluginFailureDetails(BuildContext context, Plugin plugin, int totalFailures) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${plugin.name} 解析失败统计',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildPluginDetailRow('插件名称', plugin.name, theme),
                const SizedBox(height: 12),
                _buildPluginDetailRow('总失败次数', '$totalFailures 次', theme),
                const SizedBox(height: 12),
                _buildPluginDetailRow('插件版本', plugin.version, theme),
                const SizedBox(height: 12),
                Text(
                  '说明:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '此插件在所有番剧中累计解析失败 $totalFailures 次。如果失败次数过高,建议检查插件规则或尝试更新插件。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPluginDetailRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
