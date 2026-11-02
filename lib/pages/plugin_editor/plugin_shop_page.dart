import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/adaptive_data_view.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/modules/plugin/plugin_http_module.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/services.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/utils/storage.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PluginShopPage extends ConsumerStatefulWidget {
  const PluginShopPage({super.key});

  @override
  ConsumerState<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends ConsumerState<PluginShopPage> {
  final Box setting = GStorage.setting;
  late ValueNotifier<bool> enableGitProxyNotifier;
  late final PluginsController pluginsController;

  final TextEditingController _searchController = TextEditingController();
  AdaptiveViewMode _viewMode = AdaptiveViewMode.auto;
  String _statusFilter = 'all'; // all, install, installed, update
  String _featureFilter = 'all'; // all, native, webview
  final Set<String> _installingMarketNames = {};

  Future<void> _openBrowserUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final success = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        HaipeeDialog.showToast(message: '无法在外部浏览器中打开: $url');
      }
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '打开链接失败: $e');
      }
    }
  }

  void onBackPressed(BuildContext context) {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
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

  Future<void> _installMarketItem(PluginHTTPItem item) async {
    setState(() => _installingMarketNames.add(item.name));
    final status = pluginsController.pluginStatus(item);
    final isInstall = status == 'install';

    try {
      final res = await pluginsController.tryUpdatePluginByName(item.name);
      if (mounted) {
        if (res == 0) {
          HaipeeDialog.showToast(
            message: isInstall ? '规则已成功安装并启用' : '规则已更新至最新版本',
          );
        } else if (res == 1) {
          HaipeeDialog.showToast(message: '该规则版本不兼容当前应用');
        } else {
          HaipeeDialog.showToast(message: '安装/更新规则失败');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _installingMarketNames.remove(item.name));
      }
    }
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

  Widget _buildMarketCard(
    ThemeData theme,
    ColorScheme colorScheme,
    PluginHTTPItem item,
  ) {
    final status = pluginsController.pluginStatus(item);
    final isInstall = status == 'install';
    final isInstalled = status == 'installed';
    final isProcessing = _installingMarketNames.contains(item.name);

    final formattedTimestamp = item.lastUpdate > 0
        ? DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
            .toString()
            .split('.')[0]
        : '-';

    final cardWidget = Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SettingsBadge(
                        label: 'v${item.version}',
                        color: colorScheme.secondary.withAlpha(25),
                        textColor: colorScheme.secondary,
                      ),
                    ],
                  ),
                  if (item.effectiveBaseUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _openBrowserUrl(item.effectiveBaseUrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              item.effectiveBaseUrl,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.author.isNotEmpty)
                        SettingsBadge(label: '作者: ${item.author}'),
                      SettingsBadge(
                        label: item.useNativePlayer ? '原生播放' : 'WebView',
                        color: colorScheme.primary.withAlpha(20),
                        textColor: colorScheme.primary,
                      ),
                      Text(
                        '更新: $formattedTimestamp',
                        style: TextStyle(fontSize: 11, color: colorScheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isInstalled)
              TextButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('已安装'),
              )
            else
              FilledButton.tonal(
                onPressed: isProcessing ? null : () => _installMarketItem(item),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                child: isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isInstall ? '安装' : '更新'),
              ),
          ],
        ),
      ),
    );

    return AppContextMenu(
      itemsBuilder: (context) => [
        AppMenuAction(
          title: isInstalled ? '已安装此规则' : (isInstall ? '安装此规则' : '更新此规则'),
          icon: isInstalled ? Icons.check_circle_outline : Icons.download_rounded,
          disabled: isInstalled || isProcessing,
          onSelected: () => _installMarketItem(item),
        ),
        if (item.effectiveBaseUrl.isNotEmpty) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '在浏览器中打开源站官网',
            icon: Icons.open_in_browser_rounded,
            onSelected: () => _openBrowserUrl(item.effectiveBaseUrl),
          ),
          AppMenuAction(
            title: '复制源站官网地址',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: item.effectiveBaseUrl));
              HaipeeDialog.showToast(message: '已复制源站官网地址');
            },
          ),
        ],
        AppMenuAction(
          title: '复制规则名称 (${item.name})',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: item.name));
            HaipeeDialog.showToast(message: '已复制规则名称');
          },
        ),
        AppMenuAction(
          title: '在浏览器中打开 GitHub 规则源码',
          icon: Icons.code_rounded,
          onSelected: () => _openBrowserUrl(
            'https://github.com/hugetiny/haipee-app/blob/main/plugins/${item.name}.yaml',
          ),
        ),
      ],
      child: cardWidget,
    );
  }

  Widget _buildMarketTable(
    ThemeData theme,
    ColorScheme colorScheme,
    List<PluginHTTPItem> items,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              colorScheme.surfaceContainerHighest.withAlpha(90),
            ),
            horizontalMargin: 16,
            columnSpacing: 16,
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 90,
                  child: Center(
                    child: Text('安装状态',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 260,
                  child: Text('规则名称 / 作者',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text('版本',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 140,
                  child: Text('播放特性',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: Text('最后更新时间',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Text('操作',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            rows: items.map((item) {
              final status = pluginsController.pluginStatus(item);
              final isInstall = status == 'install';
              final isInstalled = status == 'installed';
              final isProcessing = _installingMarketNames.contains(item.name);
              final formattedTimestamp = item.lastUpdate > 0
                  ? DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
                      .toString()
                      .split('.')[0]
                  : '-';

              return DataRow(
                cells: [
                  DataCell(
                    Center(
                      child: SettingsBadge(
                        label: isInstalled
                            ? '已安装'
                            : (isInstall ? '未安装' : '可更新'),
                        color: isInstalled
                            ? Colors.green.withAlpha(25)
                            : (isInstall
                                ? colorScheme.surfaceContainerHighest
                                : colorScheme.errorContainer),
                        textColor: isInstalled
                            ? Colors.green
                            : (isInstall
                                ? colorScheme.outline
                                : colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.effectiveBaseUrl.isNotEmpty)
                          InkWell(
                            onTap: () => _openBrowserUrl(item.effectiveBaseUrl),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new,
                                  size: 10,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  item.effectiveBaseUrl,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (item.author.isNotEmpty)
                          Text(
                            '作者: ${item.author}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text('v${item.version}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DataCell(
                    SettingsBadge(
                      label: item.useNativePlayer ? '原生播放' : 'WebView',
                      color: colorScheme.primary.withAlpha(20),
                      textColor: colorScheme.primary,
                    ),
                  ),
                  DataCell(
                    Text(
                      formattedTimestamp,
                      style: TextStyle(fontSize: 12, color: colorScheme.outline),
                    ),
                  ),
                  DataCell(
                    isInstalled
                        ? const Text('无需操作', style: TextStyle(color: Colors.grey))
                        : FilledButton.tonal(
                            onPressed: isProcessing
                                ? null
                                : () => _installMarketItem(item),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: isProcessing
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(isInstall ? '安装' : '更新'),
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget buildPluginHTTPListBody(
    BuildContext context,
    List<PluginHTTPItem> pluginHTTPList,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortByName =
        ref.watch(pluginShopUIProvider.select((s) => s.sortByName));

    final query = _searchController.text.trim().toLowerCase();

    // 1. 过滤
    final filtered = pluginHTTPList.where((item) {
      final status = pluginsController.pluginStatus(item);
      if (_statusFilter == 'install' && status != 'install') return false;
      if (_statusFilter == 'installed' && status != 'installed') return false;
      if (_statusFilter == 'update' && status != 'update') return false;

      if (_featureFilter == 'native' && !item.useNativePlayer) return false;
      if (_featureFilter == 'webview' && item.useNativePlayer) return false;

      if (query.isNotEmpty) {
        final hitName = item.name.toLowerCase().contains(query);
        final hitAuthor = item.author.toLowerCase().contains(query);
        if (!hitName && !hitAuthor) return false;
      }
      return true;
    }).toList();

    // 2. 排序
    if (sortByName) {
      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      filtered.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTableView = AdaptiveDataView.isTableViewForWidth(
          availableWidth: constraints.maxWidth,
          viewMode: _viewMode,
          breakpoint: 720.0,
        );

        return Column(
          children: [
            // L2 筛选工具栏
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
                              hintText: '在规则仓库中搜索规则名称或作者...',
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
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withAlpha(120),
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
                        tooltip: '刷新列表',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _handleRefresh,
                      ),
                      const SizedBox(width: 8),
                      AdaptiveViewSwitcher(
                        viewMode: _viewMode,
                        isTableView: isTableView,
                        onModeChanged: (mode) {
                          setState(() {
                            _viewMode = mode;
                          });
                        },
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
                        _buildFilterChip('全部', 'all', _statusFilter,
                            (val) => setState(() => _statusFilter = val)),
                        _buildFilterChip('🟢 未安装', 'install', _statusFilter,
                            (val) => setState(() => _statusFilter = val)),
                        _buildFilterChip('✅ 已安装', 'installed', _statusFilter,
                            (val) => setState(() => _statusFilter = val)),
                        _buildFilterChip('⚡ 可更新', 'update', _statusFilter,
                            (val) => setState(() => _statusFilter = val)),
                        const SizedBox(width: 14),
                        Text(
                          '特性: ',
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
                        const SizedBox(width: 14),
                        Text(
                          '匹配: ${filtered.length} 个 (共 ${pluginHTTPList.length} 个)',
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

            // L3 数据呈现层 (自适应模式：宽屏表格，窄屏卡片)
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.extension_off_outlined,
                            size: 56,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '无匹配的视频源规则',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '请尝试调整搜索关键字或筛选状态',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : AdaptiveDataView(
                      viewMode: _viewMode,
                      breakpoint: 720.0,
                      cardBuilder: (context) => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildMarketCard(theme, colorScheme, item);
                        },
                      ),
                      tableBuilder: (context) => _buildMarketTable(
                        theme,
                        colorScheme,
                        filtered,
                      ),
                    ),
            ),
          ],
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
                                    final newValue = !enableGitProxy;
                                    await setting.put(
                                        SettingBoxKey.enableGitProxy, newValue);
                                    enableGitProxyNotifier.value = newValue;
                                    HaipeeDialog.showToast(
                                      message: newValue
                                          ? shopTexts.error.mirrorEnabled
                                          : shopTexts.error.mirrorDisabled,
                                    );
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
