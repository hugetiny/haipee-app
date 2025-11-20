import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/timeline/providers.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

const int _weekdayCount = 7;
const List<_TimelineSeason> _seasonSelectionOrder = <_TimelineSeason>[
  _TimelineSeason.autumn,
  _TimelineSeason.summer,
  _TimelineSeason.spring,
  _TimelineSeason.winter,
];

enum _TimelineSeason { winter, spring, summer, autumn }

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage>
    with SingleTickerProviderStateMixin {
  late TimelineController timelineController;
  TabController? tabController;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday - 1;
    final initialIndex = weekday.clamp(0, _weekdayCount - 1);
    tabController = TabController(
      vsync: this,
      length: _weekdayCount,
      initialIndex: initialIndex,
    );
    timelineController = ref.read(timelineProvider.notifier);

    // Use Future.microtask instead of PostFrameCallback for initial load
    final state = ref.read(timelineProvider);
    if (state.bangumiCalendar.isEmpty) {
      Future.microtask(() {
        if (mounted) {
          timelineController.init();
        }
      });
    }
  }

  @override
  void dispose() {
    tabController?.dispose();
    super.dispose();
  }

  void _onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.popular);
  }

  void _updateAppBarConfig() {
    if (!mounted) return;
    final state = ref.read(timelineProvider);

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Text(state.seasonString),
        onTap: () => showSeasonBottomSheet(context),
      ),
      needTopOffset: false,
    );
  }

  DateTime generateDateTime(int year, _TimelineSeason season) {
    switch (season) {
      case _TimelineSeason.winter:
        return DateTime(year, 1, 1);
      case _TimelineSeason.spring:
        return DateTime(year, 4, 1);
      case _TimelineSeason.summer:
        return DateTime(year, 7, 1);
      case _TimelineSeason.autumn:
        return DateTime(year, 10, 1);
    }
  }

  List<Tab> buildWeekTabs(AppTranslations translations) {
    final weekdays = translations.library.timeline.weekdays;
    return [
      Tab(text: weekdays.mon),
      Tab(text: weekdays.tue),
      Tab(text: weekdays.wed),
      Tab(text: weekdays.thu),
      Tab(text: weekdays.fri),
      Tab(text: weekdays.sat),
      Tab(text: weekdays.sun),
    ];
  }

  void showSeasonBottomSheet(BuildContext context) {
    final t = context.t;
    final currDate = DateTime.now();
    final years = List.generate(20, (index) => currDate.year - index);

    // 按年份分组生成可用季节
    Map<int, List<DateTime>> yearSeasons = {};
    for (final year in years) {
      List<DateTime> availableSeasons = [];
      for (final season in _seasonSelectionOrder) {
        final date = generateDateTime(year, season);
        if (currDate.isAfter(date)) {
          availableSeasons.add(date);
        }
      }
      if (availableSeasons.isNotEmpty) {
        yearSeasons[year] = availableSeasons;
      }
    }

    KazumiDialog.showBottomSheet(
      // context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          t.library.timeline.seasonPicker.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  // 年份季节列表
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      itemCount: yearSeasons.keys.length,
                      itemBuilder: (context, index) {
                        final year = yearSeasons.keys.elementAt(index);
                        final availableSeasons = yearSeasons[year]!;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 年份标题
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      t.library.timeline.seasonPicker.yearLabel
                                          .replaceAll('{year}', '$year'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // 季节选择器
                              buildSeasonSegmentedButton(
                                  context, availableSeasons),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSeasonSegmentedButton(
      BuildContext context, List<DateTime> availableSeasons) {
    DateTime? selectedSeason;
    final state = ref.read(timelineProvider);
    for (final season in availableSeasons) {
      if (Utils.isSameSeason(state.selectedDate, season)) {
        selectedSeason = season;
        break;
      }
    }

    final seasonTranslations = context.t.library.timeline.season;
    final segments = availableSeasons.map((date) {
      final season = seasonFromDate(date);
      return ButtonSegment<DateTime>(
        value: date,
        label: Text(
          seasonLabel(
            seasonTranslations,
            season,
            useShort: true,
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        icon: getSeasonIcon(season),
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DateTime>(
        segments: segments,
        selected: selectedSeason != null ? {selectedSeason} : {},
        onSelectionChanged: (Set<DateTime> newSelection) {
          if (newSelection.isNotEmpty) {
            Navigator.pop(context);
            onSeasonSelected(newSelection.first);
          }
        },
        multiSelectionEnabled: false,
        showSelectedIcon: false,
        emptySelectionAllowed: true,
        style: SegmentedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedForegroundColor:
              Theme.of(context).colorScheme.onSecondaryContainer,
          selectedBackgroundColor:
              Theme.of(context).colorScheme.secondaryContainer,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  _TimelineSeason seasonFromDate(DateTime date) {
    final month = date.month;
    if (month <= 3) return _TimelineSeason.winter;
    if (month <= 6) return _TimelineSeason.spring;
    if (month <= 9) return _TimelineSeason.summer;
    return _TimelineSeason.autumn;
  }

  String seasonLabel(
    dynamic seasonTranslations,
    _TimelineSeason season, {
    bool useShort = false,
  }) {
    switch (season) {
      case _TimelineSeason.winter:
        return useShort
            ? seasonTranslations.short.winter
            : seasonTranslations.names.winter;
      case _TimelineSeason.spring:
        return useShort
            ? seasonTranslations.short.spring
            : seasonTranslations.names.spring;
      case _TimelineSeason.summer:
        return useShort
            ? seasonTranslations.short.summer
            : seasonTranslations.names.summer;
      case _TimelineSeason.autumn:
        return useShort
            ? seasonTranslations.short.autumn
            : seasonTranslations.names.autumn;
    }
  }

  Icon getSeasonIcon(_TimelineSeason season) {
    final iconData = switch (season) {
      _TimelineSeason.spring => Icons.eco,
      _TimelineSeason.summer => Icons.wb_sunny,
      _TimelineSeason.autumn => Icons.park,
      _TimelineSeason.winter => Icons.ac_unit,
    };

    return Icon(
      iconData,
      size: 18,
    );
  }

  void onSeasonSelected(DateTime date) async {
    final currDate = DateTime.now();
    final state = ref.read(timelineProvider);
    timelineController.tryEnterSeason(date);
    if (Utils.isSameSeason(state.selectedDate, currDate)) {
      await timelineController.getSchedules();
    } else {
      await timelineController.getSchedulesBySeason();
    }
    timelineController.finalizeSeasonString();
  }

  void showSortSwitcher() {
    KazumiDialog.showBottomSheet(
      // context: context,
      isScrollControlled: true,
      builder: (context) {
        final localSort = context.t.library.timeline.sort;
        return Wrap(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(localSort.byHeat),
                  onTap: () {
                    Navigator.pop(context);
                    timelineController.changeSortType(3);
                  },
                ),
                ListTile(
                  title: Text(localSort.byRating),
                  onTap: () {
                    Navigator.pop(context);
                    timelineController.changeSortType(2);
                  },
                ),
                ListTile(
                  title: Text(localSort.byTime),
                  onTap: () {
                    Navigator.pop(context);
                    timelineController.changeSortType(1);
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
    final state = ref.watch(timelineProvider);
    final translations = context.t;
    final timelineTexts = translations.library.timeline;
    final commonTexts = translations.library.common;

    // 初始化时设置 AppBar
    Future.microtask(() {
      if (mounted) {
        _updateAppBarConfig();
      }
    });

    // 监听状态变化更新 AppBar
    ref.listen<TimelineState>(timelineProvider, (previous, next) {
      if (previous?.seasonString != next.seasonString) {
        _updateAppBarConfig();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _onBackPressed(context);
      },
      child: Stack(
        children: [
          Builder(builder: (context) {
            if (state.isLoading && state.bangumiCalendar.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (state.isTimeOut) {
              return Center(
                child: SizedBox(
                  height: 400,
                  child: GeneralErrorWidget(
                      errMsg: commonTexts.emptyState,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            onSeasonSelected(state.selectedDate);
                          },
                          text: commonTexts.retry,
                        ),
                      ]),
                ),
              );
            }
            return Column(
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: tabController,
                    tabs: buildWeekTabs(translations),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: contentGrid(state.bangumiCalendar),
                  ),
                ),
              ],
            );
          }),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () {
                showSortSwitcher();
              },
              icon: const Icon(Icons.sort),
              label: Text(timelineTexts.sort.title),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> contentGrid(List<List<BangumiItem>> bangumiCalendar) {
    // Ensure tab content count matches TabController length to avoid runtime mismatches.
    final normalizedCalendar = List<List<BangumiItem>>.generate(
      _weekdayCount,
      (index) =>
          index < bangumiCalendar.length ? bangumiCalendar[index] : const [],
    );

    List<Widget> gridViewList = [];
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }
    double cardHeight =
        Utils.isDesktop() ? 160 : (Utils.isTablet() ? 140 : 120);
    for (var bangumiList in normalizedCalendar) {
      gridViewList.add(
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  StyleString.cardSpace, 8, StyleString.cardSpace, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent: cardHeight + 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (bangumiList.isEmpty) return null;
                    final item = bangumiList[index];
                    return BangumiTimelineCard(
                        bangumiItem: item, cardHeight: cardHeight);
                  },
                  childCount: bangumiList.isNotEmpty ? bangumiList.length : 10,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return gridViewList;
  }
}
