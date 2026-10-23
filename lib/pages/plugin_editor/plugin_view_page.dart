import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/responsive/constrained_content.dart';
import 'package:kazumi/bean/widget/rule/unified_rule_card.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/pages/plugin_editor/widgets/plugin_dry_run_dialog.dart';
import 'package:kazumi/pages/plugin_editor/widgets/plugin_import_dialog.dart';
import 'package:kazumi/pages/plugin_editor/widgets/plugin_subscription_dialog.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugin_validity_tracker.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/request/plugin.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/parse_failure_helper.dart';
import 'package:kazumi/utils/utils.dart';

/// Kazumi 规则管理一级分类组 (三大核心分类：视频、直播、网盘资源【网盘与BT】及规则商店)
enum PluginCategoryGroup {
  all(id: 'all', label: '全部', icon: Icons.all_inclusive),
  video(id: 'video', label: '视频', icon: Icons.video_library_outlined),
  live(id: 'live', label: '直播', icon: Icons.live_tv_outlined),
  resource(id: 'resource', label: '网盘资源', icon: Icons.cloud_download_outlined),
  catalog(id: 'catalog', label: '规则商店', icon: Icons.storefront_outlined);

  final String id;
  final String label;
  final IconData icon;

  const PluginCategoryGroup({
    required this.id,
    required this.label,
    required this.icon,
  });
}

enum PluginSortOption {
  original,
  nameAsc,
  nameDesc,
  failureAsc,
  failureDesc,
}

final pluginSortOptionProvider = StateProvider.autoDispose<PluginSortOption>(
  (ref) => PluginSortOption.original,
);

/// Kazumi 视频规则管理页面
/// 深度对齐 Cardigann 规则设置 (IndexerSettingsPage) 的成熟架构与高质感设计系统：
/// Level 1: 顶部标准 Material 3 TabBar 分段导航 (精简为「全部」与「Kazumi 规则源」2 个核心 Tab)
/// Level 2: 搜索与快速批量控制、解析类型/播放特性/连通状态筛选器、批量并发测速与自动载入
/// Level 3: UnifiedRuleGrid 自适应网格呈现层 (共享 UnifiedRuleCard 统一视觉与操作体验)
/// Level 4: 规则源市场联动、实时试抓 (Dry-Run)、生命周期管理
class PluginViewPage extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const PluginViewPage({super.key, this.isEmbedded = false});

  @override
  ConsumerState<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends ConsumerState<PluginViewPage>
    with SingleTickerProviderStateMixin {
  late final PluginsController pluginsController;
  late final TabController _categoryTabController;

  PluginCategoryGroup _selectedGroup = PluginCategoryGroup.all;
  String _typeFilter = 'all'; // all, xpath, maccms, anime
  String _featureFilter = 'all'; // all, native, webview, multi
  String _statusFilter = 'all'; // all, passed, failed, valid, updatable
  String _marketInstallFilter = 'all'; // all, install, installed, update
  String _marketFeatureFilter = 'all'; // all, native, webview

  bool _isAutoTesting = false;
  int _testedCount = 0;
  int _totalTesting = 0;
  bool _hasRunInitialTest = false;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _installingMarketNames = {};

  @override
  void initState() {
    super.initState();
    pluginsController = ref.read(pluginsProvider.notifier);
    _categoryTabController = TabController(
      length: PluginCategoryGroup.values.length,
      vsync: this,
    );
    _categoryTabController.addListener(() {
      if (!_categoryTabController.indexIsChanging && mounted) {
        final newGroup =
            PluginCategoryGroup.values[_categoryTabController.index];
        if (newGroup != _selectedGroup) {
          setState(() {
            _selectedGroup = newGroup;
          });
          if (newGroup == PluginCategoryGroup.catalog) {
            _loadMarketIfNeeded();
          }
        }
      }
    });
    // 立即启动规则市场预载与已安装规则的自动并发健康测速
    Future.microtask(() async {
      if (!mounted) return;
      await _loadMarketIfNeeded();
      if (mounted && pluginsController.pluginList.isNotEmpty && !_hasRunInitialTest) {
        _hasRunInitialTest = true;
        _runAutoBatchTest(isInitial: true);
      }
    });
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketIfNeeded() async {
    // 1. 若当前内存中尚无规则市场数据，先立即载入离线预置规则，保证 0ms 瞬间就绪（绝不显示 0）
    if (pluginsController.pluginHTTPList.isEmpty) {
      try {
        final bundled = await PluginHTTP.loadBundledPluginList();
        if (bundled.isNotEmpty && pluginsController.pluginHTTPList.isEmpty && mounted) {
          pluginsController.setPluginHTTPList(bundled);
        }
      } catch (_) {}
    }

    // 2. 静默拉取或更新最新规则市场列表
    ref.read(pluginShopUIProvider.notifier).setLoading(true);
    try {
      await pluginsController.queryPluginHTTPList();
    } catch (_) {
    } finally {
      if (mounted) {
        ref.read(pluginShopUIProvider.notifier).setLoading(false);
      }
    }
  }

  Future<void> _openBrowserUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    try {
      final success = await launchUrlString(
        normalized,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        KazumiDialog.showToast(message: '无法在浏览器中打开链接: $normalized');
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '打开链接失败: $e');
      }
    }
  }

  Future<void> _runAutoBatchTest({bool isInitial = false}) async {
    if (_isAutoTesting || !mounted) return;
    final plugins = pluginsController.pluginList;
    if (plugins.isEmpty) {
      if (mounted && !isInitial) {
        KazumiDialog.showToast(message: '未发现可用规则，请前往「Kazumi 规则源」安装');
      }
      return;
    }

    setState(() {
      _isAutoTesting = true;
      _testedCount = 0;
      _totalTesting = plugins.length;
    });

    try {
      final results = await pluginsController.testAndAutoLoadPlugins(
        targets: plugins,
        onProgress: (name, status) {
          if (mounted) {
            setState(() {
              _testedCount = plugins.where((p) {
                final s = pluginsController.validityTracker.getStatus(p.name);
                return s == PluginHealthStatus.passed ||
                    s == PluginHealthStatus.failed;
              }).length;
            });
          }
        },
      );

      if (mounted) {
        final passedCount = results.values.where((v) => v).length;
        final failedCount = results.length - passedCount;
        if (!isInitial) {
          KazumiDialog.showToast(
            message:
                '测速完成：$passedCount 个规则可用已自动载入启用${failedCount > 0 ? "，$failedCount 个规则不可用已置为禁用" : ""}',
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isAutoTesting = false;
        });
      }
    }
  }

  Future<void> _batchInstallAndTestMarket() async {
    final market = pluginsController.pluginHTTPList;
    if (market.isEmpty) {
      KazumiDialog.showToast(message: '规则市场暂无可用规则');
      return;
    }
    KazumiDialog.showLoading(
        msg: '正在从 Kazumi 规则源并发载入所有规则 (0/${market.length})...');
    int successCount = 0;
    const chunkSize = 4;
    for (int i = 0; i < market.length; i += chunkSize) {
      if (!mounted) break;
      final chunk = market.sublist(
        i,
        (i + chunkSize > market.length) ? market.length : i + chunkSize,
      );
      await Future.wait(chunk.map((item) async {
        try {
          final res = await pluginsController.tryUpdatePluginByName(item.name);
          if (res == 0) successCount++;
        } catch (_) {}
      }));
      KazumiDialog.showLoading(
        msg: '正在从 Kazumi 规则源并发载入所有规则 ($successCount/${market.length})...',
      );
    }
    KazumiDialog.dismiss();
    if (!mounted) return;
    if (successCount == 0) {
      KazumiDialog.showToast(message: '未能成功拉取规则，请检查网络连接或镜像设置');
      return;
    }
    KazumiDialog.showToast(message: '已成功载入 $successCount 个规则，正在启动健康测速...');
    setState(() {
      _selectedGroup = PluginCategoryGroup.all;
      _categoryTabController.animateTo(PluginCategoryGroup.all.index);
    });
    await _runAutoBatchTest();
  }

  Future<void> _retestSinglePlugin(Plugin plugin) async {
    KazumiDialog.showLoading(msg: '正在测试【${plugin.name}】连通性...');
    try {
      final results = await pluginsController.testAndAutoLoadPlugins(
        targets: [plugin],
      );
      KazumiDialog.dismiss();
      final passed = results[plugin.name] ?? false;
      if (mounted) {
        setState(() {});
        if (passed) {
          KazumiDialog.showToast(message: '【${plugin.name}】测速通过，已自动启用');
        } else {
          final err = pluginsController.validityTracker.getError(plugin.name);
          KazumiDialog.showToast(
              message: '【${plugin.name}】测速未通过: ${err ?? "不可达"}');
        }
      }
    } catch (e) {
      KazumiDialog.dismiss();
      if (mounted) {
        KazumiDialog.showToast(message: '测试失败: $e');
      }
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

  Future<void> _handleUpdateAll() async {
    final pluginTexts = context.t.settings.plugins;
    KazumiDialog.showLoading(msg: pluginTexts.loading.updating);
    final count = await pluginsController.tryUpdateAllPlugin();
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

  Future<void> _handleUpdateSingle(Plugin plugin) async {
    final pluginTexts = context.t.settings.plugins;
    final state = pluginsController.pluginUpdateStatus(plugin);
    if (state == "nonexistent") {
      KazumiDialog.showToast(message: pluginTexts.toast.repoMissing);
      return;
    }
    if (state == "latest") {
      KazumiDialog.showToast(message: pluginTexts.toast.alreadyLatest);
      return;
    }
    KazumiDialog.showLoading(msg: pluginTexts.loading.updatingSingle);
    final res = await pluginsController.tryUpdatePlugin(plugin);
    KazumiDialog.dismiss();
    if (res == 0) {
      KazumiDialog.showToast(message: pluginTexts.toast.updateSuccess);
    } else if (res == 1) {
      KazumiDialog.showToast(message: pluginTexts.toast.updateIncompatible);
    } else if (res == 2) {
      KazumiDialog.showToast(message: pluginTexts.toast.updateFailed);
    }
  }

  void _sharePlugin(Plugin plugin) {
    _showExportDialog(plugin);
  }

  void _showExportDialog(Plugin plugin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '导出规则【${plugin.name}】',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('复制 Kazumi 分享口令 (Base64)'),
                  subtitle: const Text('适合社区与好友之间无缝快速导入'),
                  onTap: () {
                    final base64Str =
                        Utils.jsonToKazumiBase64(json.encode(plugin.toJson()));
                    Clipboard.setData(ClipboardData(text: base64Str));
                    Navigator.pop(ctx);
                    KazumiDialog.showToast(message: '已复制 Kazumi 规则口令到剪贴板');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('复制 YAML 规则定义'),
                  subtitle: const Text('声明式规范文本，便于阅读与版本维护'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: plugin.toYamlString()));
                    Navigator.pop(ctx);
                    KazumiDialog.showToast(message: '已复制 YAML 规则到剪贴板');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.data_object_rounded),
                  title: const Text('复制 JSON 规则定义'),
                  subtitle: const Text('标准 JSON 格式'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: const JsonEncoder.withIndent('  ')
                            .convert(plugin.toJson())));
                    Navigator.pop(ctx);
                    KazumiDialog.showToast(message: '已复制 JSON 规则到剪贴板');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Plugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确认删除 Kazumi 视频规则【${plugin.name}】吗？删除后不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await pluginsController.removePlugin(plugin);
      if (mounted) {
        KazumiDialog.showToast(message: '已删除规则: ${plugin.name}');
      }
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
                final label = switch (option) {
                  PluginSortOption.original => sortTexts.options.original,
                  PluginSortOption.nameAsc => sortTexts.options.nameAsc,
                  PluginSortOption.nameDesc => sortTexts.options.nameDesc,
                  PluginSortOption.failureAsc => sortTexts.options.failureAsc,
                  PluginSortOption.failureDesc => sortTexts.options.failureDesc,
                };
                return ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(label),
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

  void _runDryRun(Plugin plugin) {
    PluginDryRunDialog.show(context, plugin);
  }

  void _openEditor(Plugin plugin) {
    context.push(Routes.settingsPluginEditor, extra: plugin);
  }

  void _batchToggle(List<Plugin> plugins, bool enable) {
    pluginsController.batchTogglePlugins(
      plugins.map((p) => p.name),
      enable,
    );
    KazumiDialog.showToast(
      message: '已${enable ? "启用" : "禁用"}本组 ${plugins.length} 个 Kazumi 视频规则',
    );
  }

  Future<void> _installMarketItem(PluginHTTPItem item) async {
    setState(() => _installingMarketNames.add(item.name));
    final status = pluginsController.pluginStatus(item);
    final isInstall = status == 'install';

    try {
      final res = await pluginsController.tryUpdatePluginByName(item.name);
      if (mounted) {
        if (res == 0) {
          KazumiDialog.showToast(
            message: isInstall ? '规则已成功安装，正在启动自动测速...' : '规则已更新，正在启动自动测速...',
          );
          final installed = pluginsController.pluginList
              .where((p) => p.name == item.name)
              .firstOrNull;
          if (installed != null) {
            await _retestSinglePlugin(installed);
          }
        } else if (res == 1) {
          KazumiDialog.showToast(message: '该规则版本不兼容当前应用');
        } else {
          KazumiDialog.showToast(message: '安装/更新规则失败');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _installingMarketNames.remove(item.name));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Plugin>>(
      pluginsProvider.select((s) => s.pluginList),
      (previous, next) {
        if (!_hasRunInitialTest && next.isNotEmpty) {
          _hasRunInitialTest = true;
          _runAutoBatchTest(isInitial: true);
        }
      },
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pluginsState = ref.watch(pluginsProvider);
    final allPlugins = pluginsState.pluginList;
    final marketList = pluginsState.pluginHTTPList;
    final pluginTexts = context.t.settings.plugins;

    final isMultiSelectMode =
        ref.watch(pluginSelectionProvider.select((s) => s.multiSelectMode));
    final selectedNames =
        ref.watch(pluginSelectionProvider.select((s) => s.selectedNames));

    final isWide = MediaQuery.of(context).size.width >= 780;

    return PopScope(
      canPop: !isMultiSelectMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (isMultiSelectMode) {
          ref.read(pluginSelectionProvider.notifier).disableMultiSelect();
          return;
        }
      },
      child: Scaffold(
        appBar: widget.isEmbedded && !isMultiSelectMode
            ? null
            : SysAppBar(
                title: isMultiSelectMode
              ? Text('已选择 ${selectedNames.length} 项')
              : Text(
                  isWide ? 'Kazumi 视频规则管理' : 'Kazumi 视频规则',
                ),
          leading: isMultiSelectMode
              ? AppBackButton(
                  icon: Icons.close,
                  tooltip: '取消选择',
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
                tooltip: '全选 / 取消全选',
                icon: const Icon(Icons.select_all_outlined),
                onPressed: () {
                  final notifier = ref.read(pluginSelectionProvider.notifier);
                  if (selectedNames.length == allPlugins.length) {
                    notifier.clearSelection();
                  } else {
                    notifier.selectAll(allPlugins.map((p) => p.name));
                  }
                },
              ),
              IconButton(
                tooltip: '批量启用所选规则',
                icon: const Icon(Icons.check_circle_outline),
                onPressed: selectedNames.isEmpty
                    ? null
                    : () {
                        pluginsController.batchTogglePlugins(selectedNames, true);
                        ref.read(pluginSelectionProvider.notifier).disableMultiSelect();
                        KazumiDialog.showToast(message: '已批量启用所选 ${selectedNames.length} 个规则');
                      },
              ),
              IconButton(
                tooltip: '批量禁用所选规则',
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: selectedNames.isEmpty
                    ? null
                    : () {
                        pluginsController.batchTogglePlugins(selectedNames, false);
                        ref.read(pluginSelectionProvider.notifier).disableMultiSelect();
                        KazumiDialog.showToast(message: '已批量禁用所选 ${selectedNames.length} 个规则');
                      },
              ),
              IconButton(
                tooltip: '删除所选规则',
                icon: const Icon(Icons.delete),
                onPressed: selectedNames.isEmpty
                    ? null
                    : () {
                        showDialog(
                          context: context,
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
                                onPressed: () => Navigator.pop(context),
                                child: Text(pluginTexts.actions.cancel),
                              ),
                              FilledButton(
                                onPressed: () {
                                  pluginsController.removePlugins(selectedNames);
                                  ref
                                      .read(pluginSelectionProvider.notifier)
                                      .disableMultiSelect();
                                  Navigator.pop(context);
                                  KazumiDialog.showToast(message: '已批量删除所选规则');
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                child: Text(pluginTexts.actions.delete),
                              ),
                            ],
                          ),
                        );
                      },
              ),
            ] else ...[
              if (_selectedGroup == PluginCategoryGroup.all) ...[
                if (isWide) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => PluginImportDialog.show(context),
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('导入规则'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () => PluginSubscriptionDialog.show(context),
                    icon: const Icon(Icons.rss_feed_rounded, size: 16),
                    label: const Text('在线规则订阅'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '一键测速并自动载入',
                    icon: const Icon(Icons.speed_rounded),
                    onPressed: _isAutoTesting ? null : () => _runAutoBatchTest(),
                  ),
                  IconButton(
                    tooltip: '一键更新全部规则',
                    icon: const Icon(Icons.update),
                    onPressed: _handleUpdateAll,
                  ),
                  IconButton(
                    tooltip: '排序方式',
                    icon: const Icon(Icons.sort_rounded),
                    onPressed: _showSortDialog,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  IconButton(
                    tooltip: '导入规则 (支持批量 / 文件 / 剪贴板)',
                    icon: const Icon(Icons.file_upload_outlined),
                    onPressed: () => PluginImportDialog.show(context),
                  ),
                  IconButton(
                    tooltip: '在线规则订阅',
                    icon: const Icon(Icons.rss_feed_rounded),
                    onPressed: () => PluginSubscriptionDialog.show(context),
                  ),
                  IconButton(
                    tooltip: '一键测速并自动载入',
                    icon: const Icon(Icons.speed_rounded),
                    onPressed: _isAutoTesting ? null : () => _runAutoBatchTest(),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: '更多操作',
                    onSelected: (val) {
                      switch (val) {
                        case 'subscriptions':
                          PluginSubscriptionDialog.show(context);
                          break;
                        case 'test_all':
                          _runAutoBatchTest();
                          break;
                        case 'update_all':
                          _handleUpdateAll();
                          break;
                        case 'sort':
                          _showSortDialog();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'subscriptions',
                        child: ListTile(
                          leading: Icon(Icons.rss_feed_rounded),
                          title: Text('在线规则订阅'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'test_all',
                        child: ListTile(
                          leading: Icon(Icons.speed_rounded),
                          title: Text('一键测速并自动载入'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'update_all',
                        child: ListTile(
                          leading: Icon(Icons.update),
                          title: Text('一键更新全部规则'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sort',
                        child: ListTile(
                          leading: Icon(Icons.sort_rounded),
                          title: Text('排序方式'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ] else ...[
                if (isWide) ...[
                  FilledButton.tonalIcon(
                    onPressed: _batchInstallAndTestMarket,
                    icon: const Icon(Icons.download_done_rounded, size: 16),
                    label: const Text('一键载入并测速全部规则'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '刷新规则市场',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadMarketIfNeeded,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  IconButton(
                    tooltip: '一键载入并测速全部规则',
                    icon: const Icon(Icons.download_done_rounded),
                    onPressed: _batchInstallAndTestMarket,
                  ),
                  IconButton(
                    tooltip: '刷新规则市场',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadMarketIfNeeded,
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ],
          ],
        ),
        body: Column(
          children: [
            // Level 1: 顶部主品类分段/标签栏 (Material 3 TabBar 结构，全平台统一，绝不占用左侧 NavigationRail 空间)
            _buildTopCategoryBar(theme, colorScheme, allPlugins, marketList),
            const Divider(height: 1),

            // Level 2 & 3: 筛选工具栏与规则数据展示 (支持自适应表格与卡片切换)
            Expanded(
              child: _buildContentPane(
                theme,
                colorScheme,
                allPlugins,
                marketList,
                isMultiSelectMode: isMultiSelectMode,
                selectedNames: selectedNames,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Level 1: 一级主品类导航 (顶部统一 Material 3 平滑标签栏)
  // ===========================================================================

  Widget _buildTopCategoryBar(
    ThemeData theme,
    ColorScheme colorScheme,
    List<Plugin> allPlugins,
    List<PluginHTTPItem> marketList,
  ) {
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      child: TabBar(
        controller: _categoryTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        onTap: (index) {
          setState(() {
            _selectedGroup = PluginCategoryGroup.values[index];
          });
          if (_selectedGroup == PluginCategoryGroup.catalog) {
            _loadMarketIfNeeded();
          }
        },
        tabs: PluginCategoryGroup.values.map((group) {
          final isSelected = _selectedGroup == group;

          List<Plugin> categoryList = allPlugins;
          if (group == PluginCategoryGroup.video) {
            categoryList = allPlugins.where((p) => p.resolvedCategory == PluginCategory.video).toList();
          } else if (group == PluginCategoryGroup.live) {
            categoryList = allPlugins.where((p) => p.resolvedCategory == PluginCategory.live).toList();
          } else if (group == PluginCategoryGroup.resource) {
            categoryList = allPlugins.where((p) => p.resolvedCategory.isResource).toList();
          }

          final count = group == PluginCategoryGroup.catalog
              ? marketList.length
              : categoryList.length;

          final activeCount = group == PluginCategoryGroup.catalog
              ? 0
              : categoryList
                  .where((p) => pluginsController.isPluginEnabled(p.name))
                  .length;

          final countText = group == PluginCategoryGroup.catalog
              ? '$count'
              : '$activeCount/$count';

          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(group.icon, size: 16),
                const SizedBox(width: 6),
                Text(group.label),
                const SizedBox(width: 6),
                SettingsBadge(
                  label: countText,
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  textColor: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // Level 2 & 3: 二级工具栏与规则数据展现 (AdaptiveDataView)
  // ===========================================================================

  Widget _buildContentPane(
    ThemeData theme,
    ColorScheme colorScheme,
    List<Plugin> allPlugins,
    List<PluginHTTPItem> marketList, {
    required bool isMultiSelectMode,
    required Set<String> selectedNames,
  }) {
    if (_selectedGroup == PluginCategoryGroup.catalog) {
      return _buildMarketCatalogPane(
        theme,
        colorScheme,
        allPlugins,
        marketList,
      );
    }

    List<Plugin> categoryPlugins = allPlugins;
    if (_selectedGroup == PluginCategoryGroup.video) {
      categoryPlugins = allPlugins.where((p) => p.resolvedCategory == PluginCategory.video).toList();
    } else if (_selectedGroup == PluginCategoryGroup.live) {
      categoryPlugins = allPlugins.where((p) => p.resolvedCategory == PluginCategory.live).toList();
    } else if (_selectedGroup == PluginCategoryGroup.resource) {
      categoryPlugins = allPlugins.where((p) => p.resolvedCategory.isResource).toList();
    }

    // 结合 L2 属性筛选与关键字过滤
    final query = _searchController.text.trim().toLowerCase();
    final filtered = categoryPlugins.where((p) {
      // 业务大类与类型过滤
      if (_typeFilter == 'video' && p.resolvedCategory != PluginCategory.video) {
        return false;
      }
      if (_typeFilter == 'live' && p.resolvedCategory != PluginCategory.live) {
        return false;
      }
      if (_typeFilter == 'drive' && p.resolvedCategory != PluginCategory.drive) {
        return false;
      }
      if (_typeFilter == 'bt' && p.resolvedCategory != PluginCategory.bt) {
        return false;
      }
      if (_typeFilter == 'resource' && !p.isResource) {
        return false;
      }
      if (_typeFilter == 'xpath' && p.type.toLowerCase() != 'xpath') {
        return false;
      }
      if (_typeFilter == 'media' && !p.isBilibili && !p.isDouyin) {
        return false;
      }
      if (_typeFilter == 'maccms' && !p.isMacCms) return false;
      if (_typeFilter == 'anime' && p.type.toLowerCase() != 'anime') {
        return false;
      }

      // 播放特性过滤
      if (_featureFilter == 'native' && !p.useNativePlayer) return false;
      if (_featureFilter == 'webview' && !p.useWebview) return false;
      if (_featureFilter == 'multi' && !p.muliSources) return false;

      // 规则连通与健康状态过滤
      if (_statusFilter == 'valid' || _statusFilter == 'passed') {
        final status = pluginsController.validityTracker.getStatus(p.name);
        if (status != PluginHealthStatus.passed &&
            !pluginsController.validityTracker.isSearchValid(p.name)) {
          return false;
        }
      }
      if (_statusFilter == 'failed') {
        final status = pluginsController.validityTracker.getStatus(p.name);
        if (status != PluginHealthStatus.failed) {
          return false;
        }
      }
      if (_statusFilter == 'updatable' &&
          pluginsController.pluginUpdateStatus(p) != 'updatable') {
        return false;
      }

      // 搜索关键字
      if (query.isNotEmpty) {
        final hitName = p.name.toLowerCase().contains(query);
        final hitType = p.type.toLowerCase().contains(query);
        final hitBaseUrl = p.baseUrl.toLowerCase().contains(query);
        final hitSearchUrl = p.searchURL.toLowerCase().contains(query);
        if (!hitName && !hitType && !hitBaseUrl && !hitSearchUrl) {
          return false;
        }
      }

      return true;
    }).toList();

    final sortOption = ref.watch(pluginSortOptionProvider);
    final sortedFiltered = _sortedPlugins(filtered, sortOption);

    final activeCount = sortedFiltered
        .where((p) => pluginsController.isPluginEnabled(p.name))
        .length;

    return Column(
      children: [
        if (_isAutoTesting) ...[
          LinearProgressIndicator(
            value: _totalTesting > 0 ? _testedCount / _totalTesting : null,
            minHeight: 2.5,
          ),
        ],
        // Level 2: 筛选控制工具栏
        _buildL2FilterHeader(
          theme,
          colorScheme,
          sortedFiltered.length,
          activeCount,
          categoryPlugins,
        ),
        const Divider(height: 1),

        // Level 3: 规则数据展示（统一网格呈现，自适应多列，显示完全）
        Expanded(
          child: sortedFiltered.isEmpty
              ? _buildEmptyState(theme, colorScheme)
              : UnifiedRuleGrid(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedFiltered.length,
                  itemBuilder: (context, index) {
                    final plugin = sortedFiltered[index];
                    return _buildPluginCard(
                      theme,
                      colorScheme,
                      plugin,
                      isMultiSelectMode: isMultiSelectMode,
                      isSelected: selectedNames.contains(plugin.name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildL2FilterHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    int filteredCount,
    int activeCount,
    List<Plugin> categoryPlugins,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final searchField = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索规则名称、主域名或解析类型 (例如 mutefun, dalvdm, xpath...)',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor:
                        colorScheme.surfaceContainerHighest.withAlpha(120),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              );

              final actionButtons = [
                FilledButton.tonalIcon(
                  onPressed: _isAutoTesting ? null : () => _runAutoBatchTest(),
                  icon: _isAutoTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed_rounded, size: 16),
                  label: Text(_isAutoTesting
                      ? '测速中 ($_testedCount/$_totalTesting)'
                      : '一键测速并自动载入'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _batchToggle(categoryPlugins, true),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('全开'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _batchToggle(categoryPlugins, false),
                  icon: const Icon(Icons.pause_circle_outline, size: 16),
                  label: const Text('全关'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: actionButtons),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 10),
                  ...actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // 第二行：L2 类型与特性筛选 Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '四类划分: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildFilterChip('全部', 'all', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                _buildFilterChip('在线视频', 'video', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                _buildFilterChip('电视直播', 'live', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                _buildFilterChip('网盘资源 (下载类)', 'drive', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                _buildFilterChip('BT磁力 (下载类)', 'bt', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                _buildFilterChip('仅资源类', 'resource', _typeFilter,
                    (val) => setState(() => _typeFilter = val)),
                const SizedBox(width: 16),
                Text(
                  '播放特性: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildFilterChip('全部', 'all', _featureFilter,
                    (val) => setState(() => _featureFilter = val)),
                _buildFilterChip('原生播放', 'native', _featureFilter,
                    (val) => setState(() => _featureFilter = val)),
                _buildFilterChip('WebView', 'webview', _featureFilter,
                    (val) => setState(() => _featureFilter = val)),
                _buildFilterChip('多线路', 'multi', _featureFilter,
                    (val) => setState(() => _featureFilter = val)),
                const SizedBox(width: 16),
                Text(
                  '状态: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildFilterChip('全部', 'all', _statusFilter,
                    (val) => setState(() => _statusFilter = val)),
                _buildFilterChip('🟢 测试通过', 'passed', _statusFilter,
                    (val) => setState(() => _statusFilter = val)),
                _buildFilterChip('🔴 异常/失败', 'failed', _statusFilter,
                    (val) => setState(() => _statusFilter = val)),
                _buildFilterChip('⚡ 可更新', 'updatable', _statusFilter,
                    (val) => setState(() => _statusFilter = val)),
                const SizedBox(width: 16),
                Text(
                  '当前显示: $filteredCount 个 (已激活 $activeCount 个)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = currentValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        onSelected: (_) => onChanged(value),
      ),
    );
  }

  // ===========================================================================
  // Level 3: 单个规则卡片视图 (Card View)
  // ===========================================================================

  Widget _buildPluginCard(
    ThemeData theme,
    ColorScheme colorScheme,
    Plugin plugin, {
    required bool isMultiSelectMode,
    required bool isSelected,
  }) {
    final isEnabled = pluginsController.isPluginEnabled(plugin.name);
    final isBundled = pluginsController.isBundledPlugin(plugin.name);
    final failureCount =
        ParseFailureHelper.getPluginTotalFailures(plugin.name);
    final canUpdate =
        pluginsController.pluginUpdateStatus(plugin) == 'updatable';
    final healthRecord =
        pluginsController.validityTracker.getRecord(plugin.name);
    final healthStatus =
        pluginsController.validityTracker.getStatus(plugin.name);
    final latency =
        pluginsController.validityTracker.getLatency(plugin.name);

    return UnifiedRuleCard(
      title: plugin.name,
      titleBadge: SettingsBadge(
        label: 'v${plugin.version}',
        color: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.outline,
      ),
      icon: Icon(
        Icons.smart_display_outlined,
        size: 20,
        color: isEnabled ? colorScheme.primary : colorScheme.outline,
      ),
      iconColor: isEnabled ? colorScheme.primary : null,
      enabled: isEnabled,
      onEnabledChanged: isMultiSelectMode
          ? null
          : (val) {
              pluginsController.togglePluginEnabled(plugin.name, val);
            },
      url: plugin.baseUrl.isNotEmpty ? plugin.baseUrl : null,
      urlTooltip: '在浏览器中打开主页:\n${plugin.baseUrl}',
      onUrlTap: plugin.baseUrl.isNotEmpty
          ? () => _openBrowserUrl(plugin.baseUrl)
          : null,
      badges: [
        SettingsBadge(
          label: plugin.resolvedCategory.isResource
              ? '${plugin.resolvedCategory.label} · 资源下载类'
              : plugin.resolvedCategory.label,
          color: plugin.resolvedCategory == PluginCategory.live
              ? Colors.orange.withValues(alpha: 0.15)
              : (plugin.resolvedCategory == PluginCategory.drive
                  ? Colors.blue.withValues(alpha: 0.15)
                  : (plugin.resolvedCategory == PluginCategory.bt
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.purple.withValues(alpha: 0.15))),
          textColor: plugin.resolvedCategory == PluginCategory.live
              ? Colors.orange.shade800
              : (plugin.resolvedCategory == PluginCategory.drive
                  ? Colors.blue.shade800
                  : (plugin.resolvedCategory == PluginCategory.bt
                      ? Colors.green.shade800
                      : Colors.purple.shade800)),
        ),
        SettingsBadge(
          label: isBundled ? '预置精选' : '自定义规则',
          color: isBundled
              ? Colors.teal.withAlpha(25)
              : Colors.indigo.withAlpha(25),
          textColor: isBundled ? Colors.teal : Colors.indigo,
        ),
        SettingsBadge(
          label: plugin.isBilibili
              ? 'B站官方 (WBI/DASH)'
              : (plugin.isDouyin
                  ? '抖音短视频 (无水印直链)'
                  : (plugin.isMacCms
                      ? '影视 CMS'
                      : 'XPath / DOM 嗅探规则')),
        ),
        SettingsBadge(
          label: plugin.type.toUpperCase(),
        ),
        if (healthStatus == PluginHealthStatus.testing)
          SettingsBadge(
            label: '测速中...',
            color: Colors.blue.withAlpha(25),
            textColor: Colors.blue,
          )
        else if (healthStatus == PluginHealthStatus.passed)
          InkWell(
            onTap: () => _showHealthPassDialog(plugin, latency),
            borderRadius: BorderRadius.circular(4),
            child: SettingsBadge(
              label: latency != null ? '🟢 测速通过 · ${latency}ms' : '🟢 测速通过',
              color: Colors.green.withAlpha(25),
              textColor: Colors.green,
            ),
          )
        else if (healthStatus == PluginHealthStatus.failed)
          InkWell(
            onTap: () => _showHealthFailureDialog(plugin, healthRecord?.error),
            borderRadius: BorderRadius.circular(4),
            child: SettingsBadge(
              label: '🔴 测速失败 (已禁用)',
              color: colorScheme.errorContainer,
              textColor: colorScheme.onErrorContainer,
            ),
          ),
        if (failureCount > 0)
          InkWell(
            onTap: () => _showFailureDialog(plugin, failureCount),
            borderRadius: BorderRadius.circular(4),
            child: SettingsBadge(
              label: '历史失败 $failureCount 次',
              color: failureCount >= 10
                  ? colorScheme.errorContainer
                  : colorScheme.tertiaryContainer,
              textColor: failureCount >= 10
                  ? colorScheme.onErrorContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
        if (plugin.useNativePlayer) const SettingsBadge(label: '原生播放'),
        if (plugin.useWebview) const SettingsBadge(label: 'WebView'),
        if (plugin.muliSources) const SettingsBadge(label: '多线路'),
        if (canUpdate)
          SettingsBadge(
            label: '可更新',
            color: colorScheme.errorContainer,
            textColor: colorScheme.onErrorContainer,
          ),
      ],
      actions: [
        TextButton.icon(
          onPressed: () => _retestSinglePlugin(plugin),
          icon: const Icon(Icons.speed_rounded, size: 16),
          label: const Text('测速'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: () => _openEditor(plugin),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('查看/编辑规则'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: () => _runDryRun(plugin),
          icon: const Icon(Icons.play_arrow_outlined, size: 16),
          label: const Text('测试抓取 (Dry-Run)'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: () => _handleUpdateSingle(plugin),
          icon: const Icon(Icons.update_rounded, size: 16),
          label: const Text('在线更新'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: () => _sharePlugin(plugin),
          icon: const Icon(Icons.share_outlined, size: 16),
          label: const Text('分享口令'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        IconButton(
          tooltip: '删除规则',
          icon: const Icon(Icons.delete_outline,
              size: 18, color: Colors.redAccent),
          onPressed: () => _confirmDelete(plugin),
        ),
      ],
      isMultiSelectMode: isMultiSelectMode,
      isSelected: isSelected,
      onTap: isMultiSelectMode
          ? () {
              ref
                  .read(pluginSelectionProvider.notifier)
                  .toggleSelection(plugin.name);
            }
          : null,
      onLongPress: () {
        if (!isMultiSelectMode) {
          ref.read(pluginSelectionProvider.notifier).enableMultiSelect();
          ref
              .read(pluginSelectionProvider.notifier)
              .toggleSelection(plugin.name);
        }
      },
      contextMenuBuilder: (context) => [
        AppMenuAction(
          title: isEnabled ? '禁用规则' : '启用规则',
          icon: isEnabled ? Icons.toggle_on : Icons.toggle_off,
          onSelected: () {
            pluginsController.togglePluginEnabled(plugin.name, !isEnabled);
          },
        ),
        AppMenuAction(
          title: '查看/编辑规则',
          icon: Icons.edit_outlined,
          onSelected: () => _openEditor(plugin),
        ),
        AppMenuAction(
          title: '测试抓取 (Dry-Run)',
          icon: Icons.play_arrow_outlined,
          onSelected: () => _runDryRun(plugin),
        ),
        AppMenuAction(
          title: '测速检测',
          icon: Icons.speed_rounded,
          onSelected: () => _retestSinglePlugin(plugin),
        ),
        AppMenuAction(
          title: '在线更新',
          icon: Icons.update_rounded,
          onSelected: () => _handleUpdateSingle(plugin),
        ),
        const AppMenuSeparator(),
        AppMenuAction(
          title: '导出/复制 JSON 规则',
          icon: Icons.data_object_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(
                text: const JsonEncoder.withIndent('  ')
                    .convert(plugin.toJson())));
            KazumiDialog.showToast(message: '已复制 JSON 规则定义到剪贴板');
          },
        ),
        AppMenuAction(
          title: '导出/复制 YAML 规则',
          icon: Icons.code_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: plugin.toYamlString()));
            KazumiDialog.showToast(message: '已复制 YAML 规则到剪贴板');
          },
        ),
        AppMenuAction(
          title: '复制分享口令 (Base64)',
          icon: Icons.share_outlined,
          onSelected: () async {
            final base64Str =
                Utils.jsonToKazumiBase64(json.encode(plugin.toJson()));
            await Clipboard.setData(ClipboardData(text: base64Str));
            KazumiDialog.showToast(message: '已复制 Kazumi 规则口令到剪贴板');
          },
        ),
        if (plugin.baseUrl.isNotEmpty) ...[
          AppMenuAction(
            title: '复制站点主页地址',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: plugin.baseUrl));
              KazumiDialog.showToast(message: '已复制站点主页地址');
            },
          ),
          AppMenuAction(
            title: '在浏览器中打开主页',
            icon: Icons.open_in_browser_rounded,
            onSelected: () => _openBrowserUrl(plugin.baseUrl),
          ),
        ],
        const AppMenuSeparator(),
        AppMenuAction(
          title: '删除规则',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onSelected: () => _confirmDelete(plugin),
        ),
      ],
    );
  }

  // ===========================================================================
  // Level 4: 规则市场 Pane (KazumiRules 社区与官方市场联动)
  // ===========================================================================

  Widget _buildMarketCatalogPane(
    ThemeData theme,
    ColorScheme colorScheme,
    List<Plugin> installedPlugins,
    List<PluginHTTPItem> marketList,
  ) {
    final isLoading = ref.watch(pluginShopUIProvider.select((s) => s.isLoading));
    final query = _searchController.text.trim().toLowerCase();

    if (isLoading && marketList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在载入 KazumiRules 社区视频源规则市场…'),
          ],
        ),
      );
    }

    final filteredMarket = marketList.where((item) {
      final status = pluginsController.pluginStatus(item);
      if (_marketInstallFilter == 'install' && status != 'install') return false;
      if (_marketInstallFilter == 'installed' && status != 'installed') {
        return false;
      }
      if (_marketInstallFilter == 'update' && status != 'update') return false;

      if (_marketFeatureFilter == 'native' && !item.useNativePlayer) return false;
      if (_marketFeatureFilter == 'webview' && item.useNativePlayer) return false;

      if (query.isNotEmpty) {
        final hitName = item.name.toLowerCase().contains(query);
        final hitAuthor = item.author.toLowerCase().contains(query);
        if (!hitName && !hitAuthor) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 市场工具栏
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '在规则市场中搜索规则名称或作者...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor:
                              colorScheme.surfaceContainerHighest.withAlpha(120),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: '刷新市场列表',
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loadMarketIfNeeded,
                  ),

                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      '状态: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _buildFilterChip('全部', 'all', _marketInstallFilter,
                        (val) => setState(() => _marketInstallFilter = val)),
                    _buildFilterChip('🟢 未安装', 'install', _marketInstallFilter,
                        (val) => setState(() => _marketInstallFilter = val)),
                    _buildFilterChip('✅ 已安装', 'installed', _marketInstallFilter,
                        (val) => setState(() => _marketInstallFilter = val)),
                    _buildFilterChip('⚡ 可更新', 'update', _marketInstallFilter,
                        (val) => setState(() => _marketInstallFilter = val)),
                    const SizedBox(width: 14),
                    Text(
                      '特性: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _buildFilterChip('全部', 'all', _marketFeatureFilter,
                        (val) => setState(() => _marketFeatureFilter = val)),
                    _buildFilterChip('原生播放', 'native', _marketFeatureFilter,
                        (val) => setState(() => _marketFeatureFilter = val)),
                    _buildFilterChip('WebView', 'webview', _marketFeatureFilter,
                        (val) => setState(() => _marketFeatureFilter = val)),
                    const SizedBox(width: 14),
                    Text(
                      '匹配: ${filteredMarket.length} 个 (共收录 ${marketList.length} 个)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 市场列表呈现 (智能自适应：宽屏表格，窄屏卡片)
        Expanded(
          child: filteredMarket.isEmpty
              ? _buildEmptyState(
                  theme,
                  colorScheme,
                  title: '规则市场无匹配项',
                  subtitle: '请尝试更换搜索关键字或检查网络连接',
                  showButtons: false,
                )
              : UnifiedRuleGrid(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMarket.length,
                  itemBuilder: (context, index) {
                    final item = filteredMarket[index];
                    return _buildMarketCard(
                      theme,
                      colorScheme,
                      item,
                      installedPlugins,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarketCard(
    ThemeData theme,
    ColorScheme colorScheme,
    PluginHTTPItem item,
    List<Plugin> installedPlugins,
  ) {
    final status = pluginsController.pluginStatus(item);
    final isInstall = status == 'install';
    final isInstalled = status == 'installed';
    final isProcessing = _installingMarketNames.contains(item.name);

    final installed =
        installedPlugins.where((p) => p.name == item.name).firstOrNull;
    final effectiveUrl = (installed != null && installed.baseUrl.isNotEmpty)
        ? installed.baseUrl
        : item.effectiveBaseUrl;

    final formattedTimestamp = item.lastUpdate > 0
        ? DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
            .toString()
            .split('.')[0]
        : '-';

    return UnifiedRuleCard(
      title: item.name,
      titleBadge: SettingsBadge(
        label: 'v${item.version}',
        color: colorScheme.secondary.withAlpha(25),
        textColor: colorScheme.secondary,
      ),
      icon: Icon(
        Icons.extension_outlined,
        size: 20,
        color: colorScheme.primary,
      ),
      iconColor: colorScheme.primary,
      url: effectiveUrl.isNotEmpty ? effectiveUrl : null,
      urlTooltip:
          effectiveUrl.isNotEmpty ? '点击在浏览器中打开源站官网:\n$effectiveUrl' : null,
      onUrlTap: effectiveUrl.isNotEmpty
          ? () => _openBrowserUrl(effectiveUrl)
          : null,
      trailing: isInstalled
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingsBadge(
                  label: '已安装',
                  color: Colors.green.withAlpha(25),
                  textColor: Colors.green,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isProcessing ? null : () => _installMarketItem(item),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('重装'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            )
          : FilledButton.tonal(
              onPressed: isProcessing ? null : () => _installMarketItem(item),
              style:
                  FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              child: isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isInstall ? '安装' : '更新'),
            ),
      badges: [
        if (item.author.isNotEmpty) SettingsBadge(label: '作者: ${item.author}'),
        SettingsBadge(
          label: item.useNativePlayer ? '原生播放' : 'WebView',
          color: colorScheme.primary.withAlpha(20),
          textColor: colorScheme.primary,
        ),
        SettingsBadge(label: '更新: $formattedTimestamp'),
      ],
      actions: [
        if (effectiveUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () => _openBrowserUrl(effectiveUrl),
            icon: const Icon(Icons.language_rounded, size: 16),
            label: const Text('源站官网'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        TextButton.icon(
          onPressed: () => _openBrowserUrl(
            'https://github.com/hugetiny/Kazumi/blob/main/plugins/${item.name}.yaml',
          ),
          icon: const Icon(Icons.code_rounded, size: 16),
          label: const Text('规则源码'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
      contextMenuBuilder: (context) => [
        AppMenuAction(
          title: isInstalled ? '重新安装/更新' : '安装此规则',
          icon: isInstalled ? Icons.update_rounded : Icons.download_rounded,
          disabled: isProcessing,
          onSelected: () => _installMarketItem(item),
        ),
        if (effectiveUrl.isNotEmpty) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '在浏览器中打开源站官网',
            icon: Icons.open_in_browser_rounded,
            onSelected: () => _openBrowserUrl(effectiveUrl),
          ),
          AppMenuAction(
            title: '复制源站官网地址',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: effectiveUrl));
              KazumiDialog.showToast(message: '已复制源站官网地址');
            },
          ),
        ],
        AppMenuAction(
          title: '复制规则名称 (${item.name})',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: item.name));
            KazumiDialog.showToast(message: '已复制规则名称');
          },
        ),
        AppMenuAction(
          title: '在浏览器中打开 GitHub 规则源码',
          icon: Icons.code_rounded,
          onSelected: () => _openBrowserUrl(
            'https://github.com/hugetiny/Kazumi/blob/main/plugins/${item.name}.yaml',
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 空状态展示 (Empty State)
  // ===========================================================================

  Widget _buildEmptyState(
    ThemeData theme,
    ColorScheme colorScheme, {
    String? title,
    String? subtitle,
    bool showButtons = true,
  }) {
    final hasInstalledPlugins = pluginsController.pluginList.isNotEmpty;

    final resolvedTitle = title ??
        (hasInstalledPlugins ? '未找到匹配的规则' : '暂无 Kazumi 视频规则');

    final resolvedSubtitle = subtitle ??
        (hasInstalledPlugins
            ? '当前筛选或搜索条件下无匹配项，请尝试更换关键词或清除筛选。'
            : '当前没有任何视频规则。您可以一键载入官方精选规则并自动测速启用，或前往 Kazumi 规则源探索海量规则。');

    return Center(
      child: ConstrainedContent(
        maxWidth: 500,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasInstalledPlugins
                    ? Icons.search_off_rounded
                    : Icons.extension_off_rounded,
                size: 64,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                resolvedTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resolvedSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (showButtons) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (!hasInstalledPlugins) ...[
                      FilledButton.icon(
                        onPressed: () async {
                          KazumiDialog.showLoading(msg: '正在载入并检测精选规则...');
                          await pluginsController.resetAllBundledPlugins();
                          await _runAutoBatchTest();
                          KazumiDialog.dismiss();
                          if (mounted) {
                            KazumiDialog.showToast(message: '已成功载入并测试官方精选规则');
                          }
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('载入并测速精选规则'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedGroup = PluginCategoryGroup.catalog;
                            _categoryTabController
                                .animateTo(PluginCategoryGroup.catalog.index);
                          });
                          _loadMarketIfNeeded();
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('前往 Kazumi 规则源'),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          _typeFilter = 'all';
                          _featureFilter = 'all';
                          _statusFilter = 'all';
                          setState(() {});
                          KazumiDialog.showToast(message: '已重置筛选条件');
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('清空筛选条件'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showHealthPassDialog(Plugin plugin, int? latency) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${plugin.name} 测速通过',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('规则名称', plugin.name, theme),
                const SizedBox(height: 10),
                _buildDetailRow('当前状态', '🟢 测速通过 · 已自动载入启用', theme),
                const SizedBox(height: 10),
                _buildDetailRow(
                    '响应耗时', latency != null ? '${latency}ms' : '正常', theme),
                const SizedBox(height: 16),
                Text(
                  '说明:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '该规则在连通性探测中成功返回搜索结果，响应速度良好。系统已自动将其载入并保持开启状态，全局搜索时将优先并发检索此规则。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _retestSinglePlugin(plugin);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重新测速'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHealthFailureDialog(Plugin plugin, String? error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${plugin.name} 测速未通过',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('规则名称', plugin.name, theme),
                const SizedBox(height: 10),
                _buildDetailRow('当前状态', '已自动禁用', theme),
                const SizedBox(height: 10),
                _buildDetailRow('失败原因', error ?? '连接超时或未返回有效搜索结果', theme),
                const SizedBox(height: 16),
                Text(
                  '说明:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '该规则在连通性探测中未能成功返回结果。系统已自动将其置于禁用状态，以保证视频全局搜索速度与播放成功率。您可以点击下方按钮单独重测，或使用【测试抓取 (Dry-Run)】进一步排查。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _retestSinglePlugin(plugin);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重新测速'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFailureDialog(Plugin plugin, int failureCount) {
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
                const SizedBox(height: 20),
                _buildDetailRow('规则名称', plugin.name, theme),
                const SizedBox(height: 10),
                _buildDetailRow('总失败次数', '$failureCount 次', theme),
                const SizedBox(height: 10),
                _buildDetailRow('当前版本', 'v${plugin.version}', theme),
                const SizedBox(height: 10),
                Text(
                  '说明:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '此规则在所有番剧中累计解析失败 $failureCount 次。若失败次数过高，建议检查规则解析字段或尝试在线更新。',
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

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
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
