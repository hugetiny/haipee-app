import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/search/search_history_dropdown.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/pages/resource/resource_search_content.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/utils.dart';

/// 全网资源搜索一级页面（支持 Mikan、Nyaa、Torznab 聚合直搜与一键下载/播放）
class ResourceSearchPage extends ConsumerStatefulWidget {
  const ResourceSearchPage({super.key});

  @override
  ConsumerState<ResourceSearchPage> createState() => _ResourceSearchPageState();
}

class _ResourceSearchPageState extends ConsumerState<ResourceSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final currentKeyword = ref.read(torrentSearchProvider).keyword;
    if (currentKeyword.isNotEmpty) {
      _searchController.text = currentKeyword;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _searchFocusNode.unfocus();
    ref.read(searchHistoryProvider.notifier).addHistory(clean);
    ref.read(torrentSearchProvider.notifier).search(clean);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;

    ref.listen<String>(torrentSearchProvider.select((s) => s.keyword), (prev, next) {
      if (next.isNotEmpty && _searchController.text != next) {
        _searchController.text = next;
      }
    });

    return Scaffold(
      appBar: SysAppBar(
        title: const Text('全网资源搜索'),
        actions: [
          IconButton(
            tooltip: 'Cardigann 规则',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.settingsIndexers),
          ),
          IconButton(
            tooltip: '下载管理',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => context.go(Routes.download),
          ),
        ],
        needTopOffset: !isDesktopSideMenu,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification) {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            }
          }
          return false;
        },
        child: Column(
          children: [
            // 搜索输入栏 (整合下拉历史记录浮层)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchHistoryDropdown(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSelectKeyword: _performSearch,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: '输入作品名称直接搜索全网资源（支持动漫、影视、游戏、音乐、图书）',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _performSearch(_searchController.text),
                    icon: const Icon(Icons.travel_explore, size: 20),
                    label: const Text('搜索'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 内容列表区域（接入完整全网搜索主体视图，包含自适应表格/卡片与三联树选择性下载）
            Expanded(
              child: ResourceSearchContent(
                onSearchKeywordSelected: (kw) {
                  _searchController.text = kw;
                  _performSearch(kw);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
