import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/modules/cardigann/cardigann_torznab.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/torrent_search/sources/torrent_dio_factory.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';

class ProwlarrCatalogEntry {
  final String id;
  final String name;
  final String description;
  final String language;
  final String type;
  final String encoding;
  final List<String> links;
  final List<int> categories;
  final String fileName;

  const ProwlarrCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.type,
    required this.encoding,
    required this.links,
    required this.categories,
    required this.fileName,
  });

  factory ProwlarrCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ProwlarrCatalogEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en-US',
      type: json['type']?.toString() ?? 'public',
      encoding: json['encoding']?.toString() ?? 'UTF-8',
      links: (json['links'] as List?)?.map((e) => e.toString()).toList() ?? [],
      categories: (json['categories'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          [],
      fileName: json['fileName']?.toString() ?? '',
    );
  }

  bool get isPrivate => type.toLowerCase() == 'private';
  bool get isSemiPrivate => type.toLowerCase() == 'semi-private';
  bool get isPublic => type.toLowerCase() == 'public';

  String get categoryLabels {
    if (categories.isEmpty) return '';
    final names = <String>{};
    for (final cat in categories) {
      if (cat == TorznabCategories.tvAnime || (cat >= 5070 && cat <= 5072)) {
        names.add('动漫');
      } else if (cat >= 2000 && cat < 3000) {
        names.add('电影');
      } else if (cat >= 5000 && cat < 6000) {
        names.add('剧集');
      } else if (cat >= 1000 && cat < 2000) {
        names.add('音乐');
      } else if (cat >= 4000 && cat < 5000) {
        names.add('游戏/软件');
      } else if (cat >= 3000 && cat < 4000) {
        names.add('图书');
      }
    }
    return names.join(' / ');
  }
}

class ProwlarrCatalogDialog extends ConsumerStatefulWidget {
  const ProwlarrCatalogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ProwlarrCatalogDialog(),
    );
  }

  @override
  ConsumerState<ProwlarrCatalogDialog> createState() =>
      _ProwlarrCatalogDialogState();
}

class _ProwlarrCatalogDialogState extends ConsumerState<ProwlarrCatalogDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _installingIds = {};
  List<ProwlarrCatalogEntry> _allEntries = [];
  bool _isLoading = true;
  String? _error;

  String _typeFilter = 'all'; // all, public, private, semi-private
  String _langFilter = 'all'; // all, zh, en, other

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/indexers/prowlarr_catalog.json');
      final list = jsonDecode(jsonString) as List;
      final entries = list
          .map((e) => ProwlarrCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _allEntries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载索引器库失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<ProwlarrCatalogEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    return _allEntries.where((entry) {
      // Type filter
      if (_typeFilter != 'all') {
        if (entry.type.toLowerCase() != _typeFilter) return false;
      }

      // Language filter
      if (_langFilter == 'zh') {
        if (!entry.language.toLowerCase().startsWith('zh')) return false;
      } else if (_langFilter == 'en') {
        if (!entry.language.toLowerCase().startsWith('en')) return false;
      } else if (_langFilter == 'other') {
        final l = entry.language.toLowerCase();
        if (l.startsWith('zh') || l.startsWith('en')) return false;
      }

      // Keyword query
      if (query.isNotEmpty) {
        final matchId = entry.id.toLowerCase().contains(query);
        final matchName = entry.name.toLowerCase().contains(query);
        final matchDesc = entry.description.toLowerCase().contains(query);
        if (!matchId && !matchName && !matchDesc) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _handleInstall(ProwlarrCatalogEntry entry) async {
    setState(() {
      _installingIds.add(entry.id);
    });

    try {
      String? yamlContent;

      // 1. 尝试从本地 prowlarr_indexers 目录直接读取
      final localFile =
          File('prowlarr_indexers/definitions/v11/${entry.fileName}');
      if (localFile.existsSync()) {
        yamlContent = await localFile.readAsString();
      }

      // 2. 本地不存在时（如手机打包端），在线从 GitHub raw / jsDelivr CDN 拉取
      if (yamlContent == null || yamlContent.isEmpty) {
        final dio = TorrentDioFactory.create(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        );
        dio.interceptors.add(GitProxyInterceptor());

        try {
          final url =
              'https://raw.githubusercontent.com/Prowlarr/Indexers/master/definitions/v11/${entry.fileName}';
          final resp = await dio.get<String>(url);
          yamlContent = resp.data;
        } catch (_) {
          // Fallback to jsDelivr CDN
          final cdnUrl =
              'https://fastly.jsdelivr.net/gh/Prowlarr/Indexers@master/definitions/v11/${entry.fileName}';
          final resp = await dio.get<String>(cdnUrl);
          yamlContent = resp.data;
        }
      }

      if (yamlContent != null && yamlContent.isNotEmpty) {
        await ref
            .read(indexerPluginsProvider.notifier)
            .addOrUpdatePlugin(yamlContent);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功安装并启用索引器: ${entry.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('安装 ${entry.name} 失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _installingIds.remove(entry.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final installedPlugins = ref.watch(indexerPluginsProvider).plugins;
    final installedIds = installedPlugins.map((p) => p.id).toSet();

    final filtered = _filteredEntries;

    return AdaptiveDialogFrame(
      maxWidth: 800,
      maxHeight: 720,
      expand: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.hub_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '全网索引器规则市场 (Cardigann 577+)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '收录 577+ 全网公开与私有 BT/PT 站点声明式 YAML 规则，统一由 Cardigann 引擎执行，支持一键安装与覆写',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索站点名称、ID 或关键字 (例如 nyaa, yts, 动漫, pt...)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(120),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('类型: ',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    _buildChip('全部', 'all', _typeFilter,
                        (v) => setState(() => _typeFilter = v)),
                    _buildChip('公开 Public', 'public', _typeFilter,
                        (v) => setState(() => _typeFilter = v)),
                    _buildChip('半私有 Semi', 'semi-private', _typeFilter,
                        (v) => setState(() => _typeFilter = v)),
                    _buildChip('私有 Private', 'private', _typeFilter,
                        (v) => setState(() => _typeFilter = v)),
                    const SizedBox(width: 16),
                    Text('语言: ',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    _buildChip('全部', 'all', _langFilter,
                        (v) => setState(() => _langFilter = v)),
                    _buildChip('中文', 'zh', _langFilter,
                        (v) => setState(() => _langFilter = v)),
                    _buildChip('英文', 'en', _langFilter,
                        (v) => setState(() => _langFilter = v)),
                    _buildChip('其他', 'other', _langFilter,
                        (v) => setState(() => _langFilter = v)),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Content List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : filtered.isEmpty
                            ? Center(
                                child: Text('没有找到符合条件的索引器',
                                    style: TextStyle(
                                        color: colorScheme.outline)),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  final isInstalled =
                                      installedIds.contains(entry.id);
                                  final isInstalling =
                                      _installingIds.contains(entry.id);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant
                                            .withAlpha(100),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Wrap(
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text(
                                                      entry.name,
                                                      style: theme
                                                          .textTheme.titleSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    _buildBadge(
                                                      entry.type.toUpperCase(),
                                                      entry.isPrivate
                                                          ? Colors.red
                                                          : (entry.isSemiPrivate
                                                              ? Colors.amber
                                                              : Colors.green),
                                                    ),
                                                    _buildBadge(
                                                      entry.language,
                                                      colorScheme.secondary,
                                                    ),
                                                    if (entry.categoryLabels
                                                        .isNotEmpty)
                                                      Text(
                                                        entry.categoryLabels,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (entry.description
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    entry.description,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                                if (entry.links.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    entry.links.first,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (isInstalling)
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          else if (isInstalled)
                                            FilledButton.tonalIcon(
                                              onPressed: null,
                                              icon: const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 16),
                                              label: const Text('已安装'),
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            )
                                          else
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  _handleInstall(entry),
                                              icon: const Icon(
                                                  Icons.add_rounded,
                                                  size: 16),
                                              label: const Text('安装'),
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildChip(
      String label, String value, String current, ValueChanged<String> onSelected) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onSelected(value),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
