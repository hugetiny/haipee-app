import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/providers.dart';
import 'package:kazumi/pages/search/providers.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';

class PopularPage extends ConsumerStatefulWidget {
  const PopularPage({super.key, this.initialSearchTag});

  final String? initialSearchTag;

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends ConsumerState<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final SearchController searchController = SearchController();
  late PopularController popularController;
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    popularController = ref.read(popularProvider.notifier);
    searchController.addListener(_onSearchChanged);

    // Use ref.listenManual to load data after widget is built
    final state = ref.read(popularProvider);
    if (state.trendList.isEmpty) {
      // Schedule loading after initState completes
      Future.microtask(() {
        if (mounted) {
          popularController.queryBangumiByTrend();
        }
      });
    }

    if (widget.initialSearchTag != null &&
        widget.initialSearchTag!.isNotEmpty) {
      _isSearching = true;
      searchController.text = 'tag:${widget.initialSearchTag}';
      Future.microtask(() {
        if (mounted) {
          ref
              .read(searchProvider.notifier)
              .searchBangumi(searchController.text, type: 'init');
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update AppBar when dependencies change (e.g. locale)
    Future.microtask(() {
      if (mounted) {
        _updateAppBarConfig();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    scrollController.removeListener(scrollListener);
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final text = searchController.text;
    if (text.isEmpty) {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
        });
      }
      return;
    }

    if (text.length > 2) {
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _isSearching = true;
        });
        ref.read(searchProvider.notifier).searchBangumi(text, type: 'init');
      });
    }
  }

  void scrollListener() {
    if (_isSearching) {
      final state = ref.read(searchProvider);
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !state.isLoading &&
          searchController.text.isNotEmpty &&
          state.bangumiList.length >= 20) {
        ref
            .read(searchProvider.notifier)
            .searchBangumi(searchController.text, type: 'add');
      }
    } else {
      final state = ref.read(popularProvider);
      popularController.updateScrollOffset(scrollController.offset);
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !state.isLoadingMore) {
        KazumiLogger().log(Level.info, 'Popular is loading more');
        if (state.currentTag != '') {
          popularController.queryBangumiByTag();
        } else {
          popularController.queryBangumiByTrend();
        }
      }
    }
  }

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    final t = context.t;
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        searchController.clear();
      });
      return;
    }
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      _lastPressedAt = DateTime.now();
      KazumiDialog.showToast(
        message: t.library.common.backHint,
        context: context,
      );
      return;
    }
    SystemNavigator.pop();
  }

  void showSortSwitcher() {
    final t = context.t;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Wrap(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(t.library.search.sort.byHeat),
                  onTap: () {
                    Navigator.pop(context);
                    searchController.text = ref
                        .read(searchProvider.notifier)
                        .attachSortParams(searchController.text, 'heat');
                    ref
                        .read(searchProvider.notifier)
                        .searchBangumi(searchController.text, type: 'init');
                  },
                ),
                ListTile(
                  title: Text(t.library.search.sort.byRating),
                  onTap: () {
                    Navigator.pop(context);
                    searchController.text = ref
                        .read(searchProvider.notifier)
                        .attachSortParams(searchController.text, 'rank');
                    ref
                        .read(searchProvider.notifier)
                        .searchBangumi(searchController.text, type: 'init');
                  },
                ),
                ListTile(
                  title: Text(t.library.search.sort.byRelevance),
                  onTap: () {
                    Navigator.pop(context);
                    searchController.text = ref
                        .read(searchProvider.notifier)
                        .attachSortParams(searchController.text, 'match');
                    ref
                        .read(searchProvider.notifier)
                        .searchBangumi(searchController.text, type: 'init');
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final t = context.t;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onBackPressed(context);
      },
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                controller: searchController,
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHigh),
                leading: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            searchController.clear();
                          });
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.search),
                      ),
                trailing: [
                  if (_isSearching)
                    IconButton(
                      icon: const Icon(Icons.sort),
                      onPressed: showSortSwitcher,
                      tooltip: t.library.search.sort.label,
                    ),
                ],
                hintText: t.navigation.actions.search,
                onSubmitted: (value) {
                  ref
                      .read(searchProvider.notifier)
                      .searchBangumi(value.trim(), type: 'init');
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            ),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildPopularContent(),
            ),
          ],
        ),
        floatingActionButton: null,
      ),
    );
  }

  Widget _buildPopularContent() {
    final state = ref.watch(popularProvider);
    return Stack(
      children: [
        Column(
          children: [
            _buildTagSelector(),
            // 加载进度条
            AnimatedOpacity(
              opacity: state.isLoadingMore ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: state.isLoadingMore
                  ? const LinearProgressIndicator(minHeight: 4)
                  : const SizedBox(height: 4),
            ),
            // 内容区域
            Expanded(
              child: state.isTimeOut
                  ? Center(
                      child: SizedBox(
                        height: 400,
                        child: GeneralErrorWidget(
                          errMsg: context.t.library.common.emptyState,
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                if (state.trendList.isEmpty) {
                                  popularController.queryBangumiByTrend();
                                } else {
                                  popularController.queryBangumiByTag();
                                }
                              },
                              text: context.t.library.common.retry,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                          StyleString.cardSpace, 8, StyleString.cardSpace, 0),
                      children: [
                        contentGrid(
                          (state.currentTag == '')
                              ? state.trendList
                              : state.bangumiList,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final state = ref.watch(searchProvider);
    final t = context.t;

    if (state.isTimeOut) {
      return Center(
        child: SizedBox(
          height: 400,
          child: GeneralErrorWidget(
            errMsg: t.library.common.emptyState,
            actions: [
              GeneralErrorButton(
                onPressed: () {
                  ref
                      .read(searchProvider.notifier)
                      .searchBangumi(searchController.text, type: 'init');
                },
                text: t.library.common.retry,
              ),
            ],
          ),
        ),
      );
    }
    if (state.isLoading && state.bangumiList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
          StyleString.cardSpace, 8, StyleString.cardSpace, 0),
      children: [
        contentGrid(state.bangumiList),
      ],
    );
  }

  Widget contentGrid(bangumiList) {
    int crossCount = 3;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 5;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 6;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        mainAxisSpacing: StyleString.cardSpace - 2,
        crossAxisSpacing: StyleString.cardSpace,
        crossAxisCount: crossCount,
        mainAxisExtent: MediaQuery.of(context).size.width / crossCount / 0.65 +
            MediaQuery.textScalerOf(context).scale(32.0),
      ),
      itemCount: bangumiList!.isNotEmpty ? bangumiList!.length : 10,
      itemBuilder: (BuildContext context, int index) {
        return bangumiList!.isNotEmpty
            ? BangumiCardV(bangumiItem: bangumiList[index])
            : const SizedBox.shrink();
      },
    );
  }

  /// 更新 AppBar 配置
  void _updateAppBarConfig() {
    final t = context.t;

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: Text(t.navigation.tabs.popular),
      actions: buildActions(),
      needTopOffset: false,
    );
  }

  List<Widget> buildActions() {
    final t = context.t;
    final actions = <Widget>[
      IconButton(
        tooltip: '回到顶部',
        onPressed: () {
          scrollController.animateTo(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart);
        },
        icon: const Icon(Icons.vertical_align_top_rounded),
      ),
      IconButton(
        tooltip: t.navigation.actions.history,
        onPressed: () => context.push(Routes.history),
        icon: const Icon(Icons.history),
      ),
    ];
    return actions;
  }

  Widget _buildTagSelector() {
    final t = context.t;
    final state = ref.watch(popularProvider);
    final items = ['', ...defaultAnimeTags];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: items.map((tag) {
          final isSelected = state.currentTag == tag;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tag.isEmpty ? t.library.popular.allTag : tag),
              selected: isSelected,
              onSelected: (selected) async {
                if (selected) {
                  if (tag == '' && state.currentTag != '') {
                    scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                    popularController.setCurrentTag('');
                    popularController.clearBangumiList();
                    if (state.trendList.isEmpty) {
                      await popularController.queryBangumiByTrend();
                    }
                  } else if (tag != '' && tag != state.currentTag) {
                    scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                    popularController.setCurrentTag(tag);
                    // 移除 clearBangumiList，避免 UI 闪烁
                    // 如果缓存中没有数据，才发起请求
                    if (state.tagCache[tag] == null || state.tagCache[tag]!.isEmpty) {
                      await popularController.queryBangumiByTag(type: 'init');
                    }
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
