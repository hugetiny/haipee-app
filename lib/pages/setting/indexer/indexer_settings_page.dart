import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/request/core/git_proxy_interceptor.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/cardigann/models/indexer_plugin.dart';
import 'package:kazumi/modules/cardigann/widgets/indexer_editor_dialog.dart';
import 'package:kazumi/modules/cardigann/widgets/indexer_import_dialog.dart';
import 'package:kazumi/modules/cardigann/widgets/indexer_settings_dialog.dart';
import 'package:kazumi/modules/cardigann/widgets/prowlarr_catalog_dialog.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/bean/widget/rule/unified_rule_card.dart';

/// 资源搜索规则一级分类组
enum IndexerCategoryGroup {
  all(id: 'all', label: '全部已装', icon: Icons.all_inclusive),
  anime(id: 'anime', label: '动漫番剧', icon: Icons.animation),
  moviesTv(id: 'movies_tv', label: '影视剧集', icon: Icons.movie_outlined),
  gamesApps(id: 'games_apps', label: '游戏软件', icon: Icons.sports_esports_outlined),
  musicAudio(id: 'music_audio', label: '音乐有声', icon: Icons.music_note_outlined),
  booksDocs(id: 'books_docs', label: '图书文档', icon: Icons.menu_book_outlined),
  general(id: 'general', label: '综合泛用', icon: Icons.public_outlined),
  custom(id: 'custom', label: '我的自定义', icon: Icons.extension_outlined),
  catalog(id: 'catalog', label: '规则市场 (577+)', icon: Icons.storefront_outlined);

  final String id;
  final String label;
  final IconData icon;

  const IndexerCategoryGroup({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// 规则设置页面（三级以上分类结构：L1 资源主品类 ➔ L2 站点访问性质/语言/搜索 ➔ L3 规则生命周期控制 ➔ L4 YAML源码与测试调试）
class IndexerSettingsPage extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const IndexerSettingsPage({super.key, this.isEmbedded = false});

  @override
  ConsumerState<IndexerSettingsPage> createState() => _IndexerSettingsPageState();
}

class _IndexerSettingsPageState extends ConsumerState<IndexerSettingsPage>
    with SingleTickerProviderStateMixin {
  IndexerCategoryGroup _selectedGroup = IndexerCategoryGroup.all;
  String _accessFilter = 'all'; // all, public, semi-private, private
  String _langFilter = 'all'; // all, zh, en, other
  final TextEditingController _searchController = TextEditingController();
  late final TabController _categoryTabController;

  // 视图显示模式（默认自动响应式：宽屏>=720为表格，窄屏<720为卡片）

  // 规则市场 577+ 缓存
  List<ProwlarrCatalogEntry> _catalogEntries = [];
  bool _isLoadingCatalog = false;
  final Set<String> _installingMarketIds = {};

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: IndexerCategoryGroup.values.length,
      vsync: this,
    );
    _categoryTabController.addListener(() {
      if (!_categoryTabController.indexIsChanging && mounted) {
        setState(() {
          _selectedGroup =
              IndexerCategoryGroup.values[_categoryTabController.index];
        });
      }
    });
    _loadCatalogIfNeeded();
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogIfNeeded() async {
    if (_catalogEntries.isNotEmpty) return;
    setState(() => _isLoadingCatalog = true);
    try {
      final jsonString =
          await rootBundle.loadString('assets/indexers/prowlarr_catalog.json');
      final list = jsonDecode(jsonString) as List;
      final entries = list
          .map((e) => ProwlarrCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _catalogEntries = entries;
          _isLoadingCatalog = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  Future<void> _openBrowserUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final success = await launchUrlString(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        KazumiDialog.showToast(message: '无法在浏览器中打开链接: $url');
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '打开链接失败: $e');
      }
    }
  }

  /// 分类映射算法：根据 Caps mapping、ID 和名称智能归类
  Set<IndexerCategoryGroup> _classifyPlugin(IndexerPlugin plugin) {
    final groups = <IndexerCategoryGroup>{IndexerCategoryGroup.all};
    if (plugin.isCustom || plugin.isOverridden) {
      groups.add(IndexerCategoryGroup.custom);
    }

    final id = plugin.id.toLowerCase();
    final name = plugin.name.toLowerCase();
    final desc = plugin.description.toLowerCase();
    final cats = plugin.definition.caps.categorymappings.map((m) => m.cat).toSet();

    // 1. 动漫番剧
    if (cats.contains(5070) ||
        id.contains('anime') ||
        id.contains('mikan') ||
        id.contains('nyaa') ||
        id.contains('dmhy') ||
        id.contains('acg') ||
        id.contains('tosho') ||
        name.contains('动漫') ||
        name.contains('蜜柑') ||
        name.contains('花园') ||
        desc.contains('anime')) {
      groups.add(IndexerCategoryGroup.anime);
    }

    // 2. 影视剧集
    if (cats.any((c) => (c >= 2000 && c < 3000) || (c >= 5000 && c < 6000 && c != 5070)) ||
        id.contains('movie') ||
        id.contains('tv') ||
        id.contains('1337x') ||
        id.contains('piratebay') ||
        id.contains('yts') ||
        id.contains('eztv') ||
        name.contains('影视') ||
        desc.contains('movie') ||
        desc.contains('tv')) {
      groups.add(IndexerCategoryGroup.moviesTv);
    }

    // 3. 游戏软件
    if (cats.any((c) => c >= 4000 && c < 5000) ||
        id.contains('game') ||
        id.contains('app') ||
        id.contains('soft') ||
        desc.contains('game') ||
        desc.contains('software')) {
      groups.add(IndexerCategoryGroup.gamesApps);
    }

    // 4. 音乐有声
    if (cats.any((c) => c >= 1000 && c < 2000) ||
        id.contains('music') ||
        id.contains('audio') ||
        id.contains('flac') ||
        desc.contains('music') ||
        desc.contains('audio')) {
      groups.add(IndexerCategoryGroup.musicAudio);
    }

    // 5. 图书文档
    if (cats.any((c) => c >= 3000 && c < 4000) ||
        id.contains('book') ||
        id.contains('comic') ||
        id.contains('manga') ||
        desc.contains('book') ||
        desc.contains('comic')) {
      groups.add(IndexerCategoryGroup.booksDocs);
    }

    // 6. 综合泛用
    if (cats.contains(7000) ||
        id.contains('csv') ||
        id.contains('dht') ||
        id.contains('0day') ||
        groups.length <= 1) {
      groups.add(IndexerCategoryGroup.general);
    }

    return groups;
  }

  /// 规则市场分类映射
  Set<IndexerCategoryGroup> _classifyCatalogEntry(ProwlarrCatalogEntry entry) {
    final groups = <IndexerCategoryGroup>{IndexerCategoryGroup.all};
    final id = entry.id.toLowerCase();
    final name = entry.name.toLowerCase();
    final desc = entry.description.toLowerCase();
    final cats = entry.categories.toSet();

    if (cats.contains(5070) ||
        id.contains('anime') ||
        name.contains('anime') ||
        desc.contains('anime')) {
      groups.add(IndexerCategoryGroup.anime);
    }
    if (cats.any((c) => (c >= 2000 && c < 3000) || (c >= 5000 && c < 6000 && c != 5070)) ||
        desc.contains('movie') ||
        desc.contains('tv')) {
      groups.add(IndexerCategoryGroup.moviesTv);
    }
    if (cats.any((c) => c >= 4000 && c < 5000) ||
        desc.contains('game') ||
        desc.contains('software')) {
      groups.add(IndexerCategoryGroup.gamesApps);
    }
    if (cats.any((c) => c >= 1000 && c < 2000) ||
        desc.contains('music') ||
        desc.contains('audio')) {
      groups.add(IndexerCategoryGroup.musicAudio);
    }
    if (cats.any((c) => c >= 3000 && c < 4000) ||
        desc.contains('book') ||
        desc.contains('comic') ||
        desc.contains('manga')) {
      groups.add(IndexerCategoryGroup.booksDocs);
    }
    if (cats.contains(7000) || groups.length <= 1) {
      groups.add(IndexerCategoryGroup.general);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indexerState = ref.watch(indexerPluginsProvider);
    final allPlugins = indexerState.plugins;

    final isWide = MediaQuery.of(context).size.width >= 780;

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : SysAppBar(
              title: Text(
          isWide ? 'Cardigann 规则管理' : 'Cardigann 规则',
        ),
        actions: [
          if (isWide)
            FilledButton.tonalIcon(
              onPressed: () => IndexerImportDialog.show(context),
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('导入 Cardigann 规则'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            IconButton(
              tooltip: '导入 YAML 规则',
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: () => IndexerImportDialog.show(context),
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '重置所有预置规则至官方初始状态',
            icon: const Icon(Icons.restore_outlined),
            onPressed: () => _confirmResetAll(allPlugins),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Level 1: 顶部主品类分段/标签栏 (Material 3 TabBar 结构，全平台统一，绝不占用左侧 NavigationRail 空间)
          _buildTopCategoryBar(theme, colorScheme, allPlugins),
          const Divider(height: 1),
          // Level 2 & 3: 筛选工具栏与规则数据展示 (支持自适应表格与卡片切换)
          Expanded(
            child: _buildContentPane(theme, colorScheme, allPlugins),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Level 1: 一级主品类导航 (顶部统一 Material 3 平滑标签栏)
  // ===========================================================================

  Widget _buildTopCategoryBar(
    ThemeData theme,
    ColorScheme colorScheme,
    List<IndexerPlugin> allPlugins,
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
            _selectedGroup = IndexerCategoryGroup.values[index];
          });
        },
        tabs: IndexerCategoryGroup.values.map((group) {
          final isSelected = _selectedGroup == group;
          final count = group == IndexerCategoryGroup.catalog
              ? _catalogEntries.length
              : allPlugins
                  .where((p) => _classifyPlugin(p).contains(group))
                  .length;

          final activeCount = group == IndexerCategoryGroup.catalog
              ? 0
              : allPlugins
                  .where(
                      (p) => p.isEnabled && _classifyPlugin(p).contains(group))
                  .length;

          final countText = group == IndexerCategoryGroup.catalog
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
  // Level 2: 二级筛选器（性质、语言、关键字）+ Level 3: 规则卡片与生命周期控制
  // ===========================================================================

  Widget _buildContentPane(
    ThemeData theme,
    ColorScheme colorScheme,
    List<IndexerPlugin> allPlugins,
  ) {
    if (_selectedGroup == IndexerCategoryGroup.catalog) {
      return _buildMarketCatalogPane(
        theme,
        colorScheme,
        allPlugins,
      );
    }

    // 1. 过滤符合当前 L1 品类的规则
    final categoryPlugins = allPlugins
        .where((p) => _classifyPlugin(p).contains(_selectedGroup))
        .toList();

    // 2. 结合 L2 属性筛选
    final query = _searchController.text.trim().toLowerCase();
    final filtered = categoryPlugins.where((p) {
      // 访问性质过滤
      if (_accessFilter == 'public' && !p.definition.isPublic) return false;
      if (_accessFilter == 'semi-private' && !p.definition.isSemiPrivate) return false;
      if (_accessFilter == 'private' && !p.definition.isPrivate) return false;

      // 语言过滤
      if (_langFilter == 'zh' && !p.language.toLowerCase().startsWith('zh')) return false;
      if (_langFilter == 'en' && !p.language.toLowerCase().startsWith('en')) return false;
      if (_langFilter == 'other' &&
          (p.language.toLowerCase().startsWith('zh') ||
              p.language.toLowerCase().startsWith('en'))) {
        return false;
      }

      // 关键字搜索过滤
      if (query.isNotEmpty) {
        final hitName = p.name.toLowerCase().contains(query);
        final hitId = p.id.toLowerCase().contains(query);
        final hitDesc = p.description.toLowerCase().contains(query);
        final hitLinks = p.definition.links.any((l) => l.toLowerCase().contains(query));
        if (!hitName && !hitId && !hitDesc && !hitLinks) return false;
      }

      return true;
    }).toList();

    final activeCount = filtered.where((p) => p.isEnabled).length;

    return Column(
      children: [
        // Level 2: 筛选控制工具栏
        _buildL2FilterHeader(
          theme,
          colorScheme,
          filtered.length,
          activeCount,
          categoryPlugins,
        ),
        const Divider(height: 1),

        // Level 3: Cardigann 规则网格展示（响应式多列网格，完整呈现，不截断）
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(theme, colorScheme)
              : UnifiedRuleGrid(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final plugin = filtered[index];
                    return _buildIndexerPluginCard(theme, colorScheme, plugin);
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
    List<IndexerPlugin> categoryPlugins,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：搜索框与快速批量控制 + 响应式视图切换器
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final searchField = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索 Cardigann 规则名称、ID 或主域名 (例如 nyaa, 1337x, dmhy...)',
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
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(120),
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

          // 第二行：L2 站点性质与语言选择 Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '性质 (L2): ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildNatureChip('全部', 'all'),
                _buildNatureChip('🟢 公开免登', 'public'),
                _buildNatureChip('🟡 半私有', 'semi-private'),
                _buildNatureChip('🔴 私有 PT', 'private'),
                const SizedBox(width: 16),
                Text(
                  '语言: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildLangChip('全部', 'all'),
                _buildLangChip('🇨🇳 中文', 'zh'),
                _buildLangChip('🌏 英文', 'en'),
                _buildLangChip('🌐 其它', 'other'),
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

  Widget _buildNatureChip(String label, String value) {
    final isSelected = _accessFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        onSelected: (_) {
          setState(() => _accessFilter = value);
        },
      ),
    );
  }

  Widget _buildLangChip(String label, String value) {
    final isSelected = _langFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        onSelected: (_) {
          setState(() => _langFilter = value);
        },
      ),
    );
  }

  // ===========================================================================
  // Level 3: 单个站点规则卡片与生命周期控制
  // ===========================================================================

  Widget _buildIndexerPluginCard(
    ThemeData theme,
    ColorScheme colorScheme,
    IndexerPlugin plugin,
  ) {
    final isOverridden = plugin.isOverridden;
    final (String sourceLabel, Color sourceColor) = isOverridden
        ? ('覆写官方', Colors.amber)
        : (plugin.isCustom ? ('自定义 YAML', Colors.indigo) : ('预置规则', Colors.teal));

    final (String accessLabel, Color accessColor) = plugin.definition.isPrivate
        ? ('私有 PT', Colors.red)
        : (plugin.definition.isSemiPrivate
            ? ('半私有', Colors.orange)
            : ('公开免登', Colors.green));

    return UnifiedRuleCard(
      title: plugin.name,
      titleBadge: SettingsBadge(
        label: plugin.id,
        color: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.outline,
      ),
      icon: Icon(
        plugin.definition.isPrivate
            ? Icons.vpn_key_outlined
            : Icons.language_rounded,
        size: 20,
        color: plugin.isEnabled ? colorScheme.primary : colorScheme.outline,
      ),
      iconColor: plugin.isEnabled ? colorScheme.primary : null,
      enabled: plugin.isEnabled,
      onEnabledChanged: (val) {
        ref.read(indexerPluginsProvider.notifier).togglePlugin(plugin.id, val);
      },
      url: plugin.definition.defaultLink.isNotEmpty ? plugin.definition.defaultLink : null,
      urlTooltip: '在浏览器中打开站点官网:\n${plugin.definition.defaultLink}',
      onUrlTap: plugin.definition.defaultLink.isNotEmpty
          ? () => _openBrowserUrl(plugin.definition.defaultLink)
          : null,
      badges: [
        _buildBadge('Torznab / Cardigann P2P 种子索引', Colors.deepPurple),
        _buildBadge(sourceLabel, sourceColor),
        _buildBadge(accessLabel, accessColor),
        _buildBadge(plugin.language, Colors.blueGrey),
      ],
      description: plugin.description.isNotEmpty ? plugin.description : null,
      actions: [
        TextButton.icon(
          onPressed: () => IndexerEditorDialog.show(context, plugin),
          icon: const Icon(Icons.code, size: 16),
          label: const Text('查看/编辑 YAML 源码'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        TextButton.icon(
          onPressed: () => _runDryRunTest(plugin),
          icon: const Icon(Icons.play_arrow_outlined, size: 16),
          label: const Text('测试抓取 (Dry-Run)'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        if (plugin.definition.defaultLink.isNotEmpty)
          TextButton.icon(
            onPressed: () => _openBrowserUrl(plugin.definition.defaultLink),
            icon: const Icon(Icons.language_rounded, size: 16),
            label: const Text('站点官网'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        TextButton.icon(
          onPressed: () => _openBrowserUrl(
            'https://github.com/Prowlarr/Indexers/blob/master/definitions/v11/${plugin.id}.yml',
          ),
          icon: const Icon(Icons.public, size: 16),
          label: const Text('YAML 来源'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        if (plugin.definition.settings.isNotEmpty || plugin.definition.isPrivate)
          TextButton.icon(
            onPressed: () => IndexerSettingsDialog.show(context, plugin),
            icon: const Icon(Icons.vpn_key_outlined, size: 16),
            label: const Text('配置凭据/参数'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        if (isOverridden)
          IconButton(
            tooltip: '恢复官方预置 YAML',
            icon: const Icon(Icons.restore_outlined, size: 18),
            onPressed: () => _confirmResetSingle(plugin),
          ),
        if (plugin.isCustom)
          IconButton(
            tooltip: '删除自定义规则',
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            onPressed: () => _confirmDeleteCustom(plugin),
          ),
      ],
      contextMenuBuilder: (context) => [
        AppMenuAction(
          title: plugin.isEnabled ? '禁用索引器' : '启用索引器',
          icon: plugin.isEnabled ? Icons.toggle_on : Icons.toggle_off,
          onSelected: () {
            ref
                .read(indexerPluginsProvider.notifier)
                .togglePlugin(plugin.id, !plugin.isEnabled);
          },
        ),
        AppMenuAction(
          title: '查看/编辑 YAML 源码',
          icon: Icons.code,
          onSelected: () => IndexerEditorDialog.show(context, plugin),
        ),
        AppMenuAction(
          title: '测试抓取 (Dry-Run)',
          icon: Icons.play_arrow_outlined,
          onSelected: () => _runDryRunTest(plugin),
        ),
        if (plugin.definition.settings.isNotEmpty || plugin.definition.isPrivate)
          AppMenuAction(
            title: '配置凭据/参数',
            icon: Icons.vpn_key_outlined,
            onSelected: () => IndexerSettingsDialog.show(context, plugin),
          ),
        const AppMenuSeparator(),
        AppMenuAction(
          title: '复制 YAML 规则源码',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: plugin.rawYaml));
            KazumiDialog.showToast(message: '已复制 YAML 规则源码');
          },
        ),
        if (plugin.definition.defaultLink.isNotEmpty) ...[
          AppMenuAction(
            title: '复制站点主页链接',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(
                  ClipboardData(text: plugin.definition.defaultLink));
              KazumiDialog.showToast(message: '已复制站点链接');
            },
          ),
          AppMenuAction(
            title: '在浏览器中打开站点官网',
            icon: Icons.open_in_browser_rounded,
            onSelected: () =>
                _openBrowserUrl(plugin.definition.defaultLink),
          ),
        ],
        AppMenuAction(
          title: '查看 GitHub 规则定义',
          icon: Icons.public,
          onSelected: () => _openBrowserUrl(
            'https://github.com/Prowlarr/Indexers/blob/master/definitions/v11/${plugin.id}.yml',
          ),
        ),
        if (isOverridden) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '恢复官方预置 YAML',
            icon: Icons.restore_outlined,
            onSelected: () => _confirmResetSingle(plugin),
          ),
        ],
        if (plugin.isCustom) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '删除自定义规则',
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onSelected: () => _confirmDeleteCustom(plugin),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return SettingsBadge(
      label: label,
      color: color.withAlpha(25),
      textColor: color,
    );
  }

  // ===========================================================================
  // Level 4: 规则市场 Pane (收录 577+ 声明式 YAML 规则)
  // ===========================================================================

  Widget _buildMarketCatalogPane(
    ThemeData theme,
    ColorScheme colorScheme,
    List<IndexerPlugin> installedPlugins,
  ) {
    if (_isLoadingCatalog) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在载入 577+ 官方 Cardigann 规则市场…'),
          ],
        ),
      );
    }

    final installedIds = installedPlugins.map((p) => p.id).toSet();
    final query = _searchController.text.trim().toLowerCase();

    final filteredCatalog = _catalogEntries.where((entry) {
      if (_selectedGroup != IndexerCategoryGroup.catalog &&
          _selectedGroup != IndexerCategoryGroup.all) {
        if (!_classifyCatalogEntry(entry).contains(_selectedGroup)) {
          return false;
        }
      }
      if (_accessFilter == 'public' && entry.type != 'public') return false;
      if (_accessFilter == 'semi-private' && entry.type != 'semi-private') return false;
      if (_accessFilter == 'private' && entry.type != 'private') return false;

      if (_langFilter == 'zh' && !entry.language.toLowerCase().startsWith('zh')) return false;
      if (_langFilter == 'en' && !entry.language.toLowerCase().startsWith('en')) return false;
      if (_langFilter == 'other' &&
          (entry.language.toLowerCase().startsWith('zh') ||
              entry.language.toLowerCase().startsWith('en'))) {
        return false;
      }

      if (query.isNotEmpty) {
        final hitName = entry.name.toLowerCase().contains(query);
        final hitId = entry.id.toLowerCase().contains(query);
        final hitDesc = entry.description.toLowerCase().contains(query);
        if (!hitName && !hitId && !hitDesc) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 市场过滤头
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
                          hintText: '在 577+ 规则市场中搜索站点名称、ID 或关键字 (例如 nyaa, yts, pt...)',
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
                          fillColor: colorScheme.surfaceContainerHighest.withAlpha(120),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      '市场性质: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _buildNatureChip('全部', 'all'),
                    _buildNatureChip('🟢 公开免登', 'public'),
                    _buildNatureChip('🟡 半私有', 'semi-private'),
                    _buildNatureChip('🔴 私有 PT', 'private'),
                    const SizedBox(width: 16),
                    Text(
                      '语言: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _buildLangChip('全部', 'all'),
                    _buildLangChip('🇨🇳 中文', 'zh'),
                    _buildLangChip('🌏 英文', 'en'),
                    _buildLangChip('🌐 其它', 'other'),
                    const SizedBox(width: 16),
                    Text(
                      '匹配规则: ${filteredCatalog.length} 个 (共收录 ${_catalogEntries.length} 个)',
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

        // 市场列表 (统一网格呈现，自适应多列)
        Expanded(
          child: filteredCatalog.isEmpty
              ? _buildEmptyState(theme, colorScheme)
              : UnifiedRuleGrid(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCatalog.length,
                  itemBuilder: (context, index) {
                    final entry = filteredCatalog[index];
                    final isInstalled = installedIds.contains(entry.id);
                    final isInstalling = _installingMarketIds.contains(entry.id);
                    return _buildMarketCatalogCard(
                      theme,
                      colorScheme,
                      entry,
                      installedPlugins,
                      isInstalled,
                      isInstalling,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarketCatalogCard(
    ThemeData theme,
    ColorScheme colorScheme,
    ProwlarrCatalogEntry entry,
    List<IndexerPlugin> installedPlugins,
    bool isInstalled,
    bool isInstalling,
  ) {
    return UnifiedRuleCard(
      title: entry.name,
      titleBadge: SettingsBadge(
        label: entry.id,
        color: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.outline,
      ),
      icon: Icon(
        entry.type == 'private'
            ? Icons.vpn_key_outlined
            : Icons.public_rounded,
        size: 20,
        color: colorScheme.primary,
      ),
      iconColor: colorScheme.primary,
      url: entry.links.isNotEmpty ? entry.links.first : null,
      urlTooltip: entry.links.isNotEmpty ? '点击在浏览器中打开站点官网:\n${entry.links.first}' : null,
      onUrlTap: entry.links.isNotEmpty ? () => _openBrowserUrl(entry.links.first) : null,
      trailing: isInstalled
          ? TextButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('已安装'),
            )
          : FilledButton.tonal(
              onPressed: isInstalling ? null : () => _installMarketEntry(entry),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              child: isInstalling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('安装'),
            ),
      badges: [
        _buildBadge('Torznab / Cardigann P2P 种子索引', Colors.deepPurple),
        _buildBadge(entry.type, Colors.blueGrey),
        _buildBadge(entry.language, Colors.teal),
      ],
      description: entry.description.isNotEmpty ? entry.description : null,
      actions: [
        if (entry.links.isNotEmpty)
          TextButton.icon(
            onPressed: () => _openBrowserUrl(entry.links.first),
            icon: const Icon(Icons.language_rounded, size: 16),
            label: const Text('站点官网'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        TextButton.icon(
          onPressed: () => _openBrowserUrl(
            'https://github.com/Prowlarr/Indexers/blob/master/definitions/v11/${entry.id}.yml',
          ),
          icon: const Icon(Icons.public, size: 16),
          label: const Text('YAML 来源'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
      contextMenuBuilder: (context) => [
        AppMenuAction(
          title: isInstalled ? '已安装此索引器' : '安装/启用此规则',
          icon: isInstalled ? Icons.check_circle_outline : Icons.download_rounded,
          disabled: isInstalled || isInstalling,
          onSelected: () => _installMarketEntry(entry),
        ),
        AppMenuAction(
          title: '查看 GitHub 规则定义',
          icon: Icons.public,
          onSelected: () => _openBrowserUrl(
            'https://github.com/Prowlarr/Indexers/blob/master/definitions/v11/${entry.id}.yml',
          ),
        ),
        if (entry.links.isNotEmpty) ...[
          const AppMenuSeparator(),
          AppMenuAction(
            title: '在浏览器中打开站点官网',
            icon: Icons.open_in_browser_rounded,
            onSelected: () => _openBrowserUrl(entry.links.first),
          ),
          AppMenuAction(
            title: '复制站点主页链接',
            icon: Icons.link_rounded,
            onSelected: () async {
              await Clipboard.setData(ClipboardData(text: entry.links.first));
              KazumiDialog.showToast(message: '已复制站点链接');
            },
          ),
        ],
        AppMenuAction(
          title: '复制索引器 ID (${entry.id})',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: entry.id));
            KazumiDialog.showToast(message: '已复制索引器 ID');
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 业务逻辑与操作助手方法
  // ===========================================================================

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '暂无 Cardigann 规则',
            style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 6),
          Text(
            '可尝试切换筛选条件，或点击右上角导入自定义 YAML',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Future<void> _batchToggle(List<IndexerPlugin> plugins, bool enable) async {
    final notifier = ref.read(indexerPluginsProvider.notifier);
    for (final p in plugins) {
      if (p.isEnabled != enable) {
        await notifier.togglePlugin(p.id, enable);
      }
    }
    if (mounted) {
      KazumiDialog.showToast(message: '已${enable ? "启用" : "禁用"}本类 ${plugins.length} 个规则');
    }
  }

  Future<void> _runDryRunTest(IndexerPlugin plugin) async {
    showDialog(
      context: context,
      builder: (ctx) => _DryRunTestDialog(plugin: plugin),
    );
  }

  Future<void> _installMarketEntry(ProwlarrCatalogEntry entry) async {
    setState(() => _installingMarketIds.add(entry.id));

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      dio.interceptors.add(GitProxyInterceptor());

      String? yamlContent;
      try {
        final url =
            'https://raw.githubusercontent.com/Prowlarr/Indexers/master/definitions/v11/${entry.fileName}';
        final resp = await dio.get<String>(url);
        yamlContent = resp.data;
      } catch (_) {
        final cdnUrl =
            'https://fastly.jsdelivr.net/gh/Prowlarr/Indexers@master/definitions/v11/${entry.fileName}';
        final resp = await dio.get<String>(cdnUrl);
        yamlContent = resp.data;
      }

      if (yamlContent != null && yamlContent.isNotEmpty) {
        await ref.read(indexerPluginsProvider.notifier).addOrUpdatePlugin(yamlContent);
        if (mounted) {
          KazumiDialog.showToast(message: '已成功安装并启用规则: ${entry.name}');
        }
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '安装规则失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _installingMarketIds.remove(entry.id));
      }
    }
  }

  Future<void> _confirmResetSingle(IndexerPlugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复官方预置规则'),
        content: Text('确认将【${plugin.name}】的 YAML 代码恢复为官方出厂预置版本吗？您的本地修改将被重置。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认恢复')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(indexerPluginsProvider.notifier).resetPlugin(plugin.id);
      if (mounted) {
        KazumiDialog.showToast(message: '已重置【${plugin.name}】至官方预置版本');
      }
    }
  }

  Future<void> _confirmDeleteCustom(IndexerPlugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除自定义规则'),
        content: Text('确认删除规则【${plugin.name}】吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(indexerPluginsProvider.notifier).removePlugin(plugin.id);
      if (mounted) {
        KazumiDialog.showToast(message: '已删除规则【${plugin.name}】');
      }
    }
  }

  Future<void> _confirmResetAll(List<IndexerPlugin> allPlugins) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置全部预置规则'),
        content: const Text('确认将所有 11 个预置规则重置为官方默认版本吗？已有的本地修改将被还原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认重置')),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(indexerPluginsProvider.notifier);
      for (final id in IndexerPluginsNotifier.bundledAssetMap.keys) {
        await notifier.resetPlugin(id);
      }
      if (mounted) {
        KazumiDialog.showToast(message: '已将全部官方预置规则重置为默认');
      }
    }
  }
}

class _DryRunTestDialog extends StatefulWidget {
  final IndexerPlugin plugin;

  const _DryRunTestDialog({required this.plugin});

  @override
  State<_DryRunTestDialog> createState() => _DryRunTestDialogState();
}

class _DryRunTestDialogState extends State<_DryRunTestDialog> {
  late final TextEditingController _textController;
  bool _isTesting = false;
  String? _errorMsg;
  List<TorrentItem>? _testResults;
  int? _elapsedMs;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: '1080p');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _doTest();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _doTest() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _errorMsg = null;
      _testResults = null;
      _elapsedMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final executor = CardigannQueryExecutor();
      final results = await executor.search(
        widget.plugin.definition,
        _textController.text.trim(),
        userConfig: widget.plugin.settings,
        customBaseUrl: widget.plugin.customBaseUrl,
        throwOnError: true,
      );
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResults = results;
          _elapsedMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _errorMsg = e.toString();
          _elapsedMs = stopwatch.elapsedMilliseconds;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBaseUrl =
        widget.plugin.customBaseUrl ?? widget.plugin.definition.defaultLink;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.network_check_rounded,
                size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '测试抓取 (Dry-Run): ${widget.plugin.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  effectiveBaseUrl,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: '测试关键词',
                      hintText: '输入关键词 (留空即测试首页)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _textController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _doTest(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isTesting ? null : _doTest,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow, size: 16),
                  label: Text(_isTesting ? '抓取中' : '执行试抓'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('快捷词: ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.outline)),
                for (final word in ['1080p', '2024', 'SPY', '全部'])
                  ActionChip(
                    label: Text(word, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: _isTesting
                        ? null
                        : () {
                            _textController.text = word == '全部' ? '' : word;
                            _doTest();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // 状态展现区
            if (_isTesting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        '正在请求站点并解析 HTML 选择器...',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '目标地址: $effectiveBaseUrl',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.error.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 18, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          '抓取失败 (${_elapsedMs ?? 0}ms)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _errorMsg!,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示: 该站点可能存在网络拦截、Cloudflare 人机校验或需要自备科学环境。您可以在设置中切换 BaseURL 或配置代理。',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              )
            else if (_testResults != null)
              if (_testResults!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'HTTP 请求成功 (${_elapsedMs ?? 0}ms)，但当前关键词未匹配到任何结果。可以尝试更换关键词或清空后重新测试。',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '抓取成功！命中 ${_testResults!.length} 条资源 (耗时 ${_elapsedMs ?? 0}ms)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.surfaceContainerHighest.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: colorScheme.outlineVariant.withAlpha(60)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        itemCount: _testResults!.take(10).length,
                        separatorBuilder: (_, __) => const Divider(height: 6),
                        itemBuilder: (context, i) {
                          final item = _testResults![i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Text(
                                    '大小: ${item.fileSize}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.outline),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '做种: ${item.seeders}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.green),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '下载: ${item.leechers}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.outline),
                                  ),
                                  if (item.publishDate.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      item.publishDate,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.outline),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            IndexerEditorDialog.show(context, widget.plugin);
          },
          child: const Text('查看/编辑 YAML 源码'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

