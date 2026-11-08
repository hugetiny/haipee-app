import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/card/bangumi_card.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/pages/search/providers.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

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
    if (widget.inputTag.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !searchController.isOpen) {
          searchController.openView();
        }
      });
    } else {
      _applyInputTag(widget.inputTag);
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inputTag != oldWidget.inputTag && widget.inputTag.isNotEmpty) {
      _applyInputTag(widget.inputTag);
    }
  }

  void _applyInputTag(String rawTag) {
    String decodedTag;
    try {
      decodedTag = Uri.decodeComponent(rawTag);
    } catch (_) {
      decodedTag = rawTag;
    }
    final String tagString = 'tag:$decodedTag';
    searchController.text = tagString;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(searchProvider.notifier)
            .searchBangumi(tagString, type: 'init');
      }
    });
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: Text(t.navigation.actions.search),
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
            child: SearchAnchor.bar(
              searchController: searchController,
              barHintText: t.navigation.actions.search,
              viewHintText: t.navigation.actions.search,
              barLeading: const Icon(Icons.search),
              barElevation: WidgetStateProperty<double>.fromMap(
                <WidgetStatesConstraint, double>{WidgetState.any: 0},
              ),
              viewElevation: 0,
              barTrailing: [
                ListenableBuilder(
                  listenable: searchController,
                  builder: (context, _) {
                    if (searchController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        searchController.clear();
                      },
                    );
                  },
                ),
              ],
              viewTrailing: [
                ListenableBuilder(
                  listenable: searchController,
                  builder: (context, _) {
                    if (searchController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        searchController.clear();
                      },
                    );
                  },
                ),
              ],
              viewLeading: MediaQuery.sizeOf(context).width <
                      LayoutBreakpoint.compact['width']!
                  ? DesktopWindowControlsSafeArea.wrapLeading(
                      AppBackButton(
                        onPressed: () {
                          if (searchController.isOpen) {
                            searchController.closeView(null);
                          }
                          final state = ref.read(searchProvider);
                          if (state.bangumiList.isEmpty &&
                              widget.inputTag.isEmpty &&
                              Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    )
                  : AppBackButton(
                      onPressed: () {
                        if (searchController.isOpen) {
                          searchController.closeView(null);
                        }
                        final state = ref.read(searchProvider);
                        if (state.bangumiList.isEmpty &&
                            widget.inputTag.isEmpty &&
                            Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
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
                                final kw = history.keyword;
                                if (searchController.isOpen) {
                                  searchController.closeView(kw);
                                } else {
                                  searchController.text = kw;
                                }
                                ref.read(searchProvider.notifier).searchBangumi(
                                    kw.trim(),
                                    type: 'init');
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
                  if (searchController.isOpen) {
                    searchController.closeView(value);
                  }
                  ref
                      .read(searchProvider.notifier)
                      .searchBangumi(value.trim(), type: 'init');
                },
              ),
            ),
          Expanded(
            child: Consumer(builder: (context, ref, _) {
              final state = ref.watch(searchProvider);
              if (state.isTimeOut) {
                return Center(
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
                    ],
                  ),
                );
              }
              if (state.isLoading && state.bangumiList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final bangumiList = state.bangumiList;
              return AdaptiveGrid(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                smallMobileColumns: 2,
                mobileColumns: 3,
                tabletColumns: 5,
                desktopColumns: 6,
                mainAxisSpacing: StyleString.cardSpace - 2,
                crossAxisSpacing: StyleString.cardSpace,
                extentBuilder: (columnWidth) =>
                    columnWidth / 0.65 + MediaQuery.textScalerOf(context).scale(32.0),
                itemCount: bangumiList.length,
                itemBuilder: (context, index) {
                  return BangumiCardV(
                    enableHero: false,
                    bangumiItem: bangumiList[index],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
