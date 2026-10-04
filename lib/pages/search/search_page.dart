import 'package:kazumi/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/providers.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/constants.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final SearchController searchController = SearchController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchController.addListener(_handleSearchTextChanged);
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    searchController.removeListener(_handleSearchTextChanged);
    super.dispose();
  }

  void _handleSearchTextChanged() {
    if (!mounted) return;
    if (!FocusScope.of(context).hasPrimaryFocus) return;
    if (!searchController.isOpen) {
      searchController.openView();
    }
  }

  void scrollListener() {
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
    final t = context.t;
    // Handle inputTag parameter once on first build
    if (widget.inputTag.isNotEmpty && searchController.text.isEmpty) {
      final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
      searchController.text = tagString;
      // Use microtask to trigger search after build
      Future.microtask(() {
        if (mounted) {
          ref
              .read(searchProvider.notifier)
              .searchBangumi(tagString, type: 'init');
        }
      });
    }
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: Text(t.navigation.actions.search),
        actions: [
          IconButton(
            tooltip: '全网BT/磁力直搜 (Mikan/Nyaa)',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () {
              final kw = searchController.text.trim();
              TorrentSearchSheet.show(
                context,
                initialKeyword: kw,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showSortSwitcher,
        icon: const Icon(Icons.sort),
        label: Text(t.library.search.sort.label),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: FocusScope(
              descendantsAreFocusable: false,
              child: SearchAnchor.bar(
                searchController: searchController,
                barElevation: WidgetStateProperty<double>.fromMap(
                  <WidgetStatesConstraint, double>{WidgetState.any: 0},
                ),
                viewElevation: 0,
                viewTrailing: [
                  IconButton(
                    tooltip: '全网BT/磁力直搜 (Mikan/Nyaa)',
                    icon: const Icon(Icons.travel_explore_rounded),
                    onPressed: () {
                      final kw = searchController.text.trim();
                      TorrentSearchSheet.show(
                        context,
                        initialKeyword: kw,
                      );
                    },
                  ),
                ],
                viewLeading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                isFullScreen: MediaQuery.sizeOf(context).width <
                    LayoutBreakpoint.compact['width']!,
                suggestionsBuilder: (context, controller) {
                  return [
                    Consumer(builder: (context, ref, _) {
                      final state = ref.watch(searchProvider);
                      final query = controller.text.trim();
                      final histories = state.searchHistories;
                      final filtered = query.isEmpty
                          ? histories
                          : histories
                              .where((history) => history.keyword
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                      if (filtered.isEmpty) {
                        return Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Text(t.library.search.noHistory),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var history in filtered.take(10))
                            ListTile(
                              key: ValueKey(history.key),
                              title: Text(history.keyword),
                              onTap: () {
                                controller.text = history.keyword;
                                ref.read(searchProvider.notifier).searchBangumi(
                                    controller.text.trim(),
                                    type: 'init');
                                if (searchController.isOpen) {
                                  searchController.closeView(history.keyword);
                                }
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () async {
                                  await ref
                                      .read(searchProvider.notifier)
                                      .deleteSearchHistory(history);
                                },
                              ),
                            ),
                        ],
                      );
                    }),
                  ];
                },
                onSubmitted: (value) {
                  ref
                      .read(searchProvider.notifier)
                      .searchBangumi(value.trim(), type: 'init');
                  if (searchController.isOpen) {
                    searchController.closeView(value);
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: Consumer(builder: (context, ref, _) {
              final state = ref.watch(searchProvider);
              if (state.isTimeOut) {
                return Center(
                  child: SizedBox(
                    height: 400,
                    child: GeneralErrorWidget(
                      errMsg: t.library.common.emptyState,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            ref.read(searchProvider.notifier).searchBangumi(
                                searchController.text,
                                type: 'init');
                          },
                          text: t.library.common.retry,
                        ),
                        GeneralErrorButton(
                          onPressed: () {
                            TorrentSearchSheet.show(
                              context,
                              initialKeyword: searchController.text.trim(),
                            );
                          },
                          text: '搜全网BT/磁力 (Mikan/Nyaa)',
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (state.isLoading && state.bangumiList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              int crossCount = 3;
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.compact['width']!) {
                crossCount = 5;
              }
              if (MediaQuery.sizeOf(context).width >
                  LayoutBreakpoint.medium['width']!) {
                crossCount = 6;
              }
              final bangumiList = state.bangumiList;
              return GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent:
                      MediaQuery.of(context).size.width / crossCount / 0.65 +
                          MediaQuery.textScalerOf(context).scale(32.0),
                ),
                itemCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
                itemBuilder: (context, index) {
                  return bangumiList.isNotEmpty
                      ? BangumiCardV(
                          enableHero: false,
                          bangumiItem: bangumiList[index],
                        )
                      : const SizedBox.shrink();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
