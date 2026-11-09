import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/bean/widget/bottom_sheet/bottom_selector.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/bean/card/bangumi_card.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/layout/app_bar_config.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

class PopularPage extends ConsumerStatefulWidget {
  const PopularPage({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends ConsumerState<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  late PopularController popularController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    popularController = ref.read(popularProvider.notifier);

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
    _focusNode.dispose();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    final state = ref.read(popularProvider);
    popularController.updateScrollOffset(scrollController.offset);
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !state.isLoadingMore) {
      HaipeeLogger().log(Level.info, 'Popular is loading more');
      if (state.currentTag != '') {
        popularController.queryBangumiByTag();
      } else {
        popularController.queryBangumiByTrend();
      }
    }
  }

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    final t = context.t;
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      _lastPressedAt = DateTime.now();
      HaipeeDialog.showToast(
        message: t.library.common.backHint,
        context: context,
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(popularProvider);

    // Listen to provider changes to update AppBar
    ref.listen(popularProvider, (previous, next) {
      if (previous?.currentTag != next.currentTag) {
        _updateAppBarConfig();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onBackPressed(context);
      },
      child: Column(
        children: [
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
    );
  }

  Widget contentGrid(bangumiList) {
    return AdaptiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      smallMobileColumns: 2,
      mobileColumns: 3,
      tabletColumns: 5,
      desktopColumns: 6,
      mainAxisSpacing: StyleString.cardSpace - 2,
      crossAxisSpacing: StyleString.cardSpace,
      extentBuilder: (columnWidth) =>
          columnWidth / 0.65 + MediaQuery.textScalerOf(context).scale(32.0),
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
    final state = ref.read(popularProvider);
    final t = context.t;
    final bool isTrend = state.currentTag == '';

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: showTagMenu,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isTrend ? t.library.popular.allTag : state.currentTag,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
      actions: buildActions(),
      needTopOffset: false,
    );
  }

  List<Widget> buildActions() {
    final t = context.t;
    final actions = <Widget>[
      IconButton(
        tooltip: t.navigation.actions.search,
        onPressed: () => context.push(Routes.search),
        icon: const Icon(Icons.search),
      ),
      IconButton(
        tooltip: t.navigation.actions.history,
        onPressed: () => context.push(Routes.history),
        icon: const Icon(Icons.history),
      ),
    ];
    return actions;
  }

  Future<void> showTagMenu() async {
    final t = context.t;
    final state = ref.read(popularProvider);

    // Build items list with empty string representing "All"
    final items = ['', ...defaultAnimeTags];

    // Show bottom selector
    final selected = await BottomSelector.showSingleSelector<String>(
      context: context,
      title: '选择标签',
      items: items,
      currentValue: state.currentTag.isEmpty ? '' : state.currentTag,
      itemBuilder: (item) => item.isEmpty ? t.library.popular.allTag : item,
      leadingBuilder: (item) {
        if (item.isEmpty) {
          return const Icon(Icons.all_inclusive);
        }
        return const Icon(Icons.label_outline);
      },
      showSearch: defaultAnimeTags.length > 10,
      searchHint: '搜索标签...',
    );

    if (selected == null) return;
    final currentState = ref.read(popularProvider);
    if (selected == '' && currentState.currentTag != '') {
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag('');
      popularController.clearBangumiList();
      if (currentState.trendList.isEmpty) {
        await popularController.queryBangumiByTrend();
      }
    } else if (selected != '' && selected != currentState.currentTag) {
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      popularController.setCurrentTag(selected);
      await popularController.queryBangumiByTag(type: 'init');
    }
  }
}
