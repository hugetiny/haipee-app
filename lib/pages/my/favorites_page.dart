import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/bean/widget/responsive/responsive.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage>
    with SingleTickerProviderStateMixin {
  static const List<int> _visibleTypes = [1, 2, 4];

  late final CollectController collectController;
  late final TabController tabController;
  // ✅ showDelete and syncing moved to Riverpod StateProvider
  late final Box setting;

  @override
  void initState() {
    super.initState();
    collectController = ref.read(collectionsProvider.notifier);
    tabController = TabController(vsync: this, length: _visibleTypes.length);
    setting = GStorage.setting;
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void _onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.media);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final favoritesTexts = t.library.my.favorites;
    final collectibles = ref
        .watch(collectionsProvider)
        .collectibles
        .where((item) => _visibleTypes.contains(item.type))
        .toList();

    // ✅ Watch Riverpod state providers
    final showDelete = ref.watch(favoritesShowDeleteProvider);
    final syncing = ref.watch(favoritesSyncingProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          bottom: TabBar(
            controller: tabController,
            tabs: _buildTabs(favoritesTexts.tabs),
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          title: Text(favoritesTexts.title),
          actions: [
            IconButton(
              onPressed: () {
                // ✅ Update state via Riverpod provider
                ref.read(favoritesShowDeleteProvider.notifier).state =
                    !showDelete;
              },
              icon: showDelete
                  ? const Icon(Icons.edit_outlined)
                  : const Icon(Icons.edit),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final webDavEnable = setting.get(SettingBoxKey.webDavEnable,
                    defaultValue: false) as bool? ??
                false;
            if (!webDavEnable) {
              KazumiDialog.showToast(
                message: favoritesTexts.sync.disabled,
              );
              return;
            }
            if (showDelete) {
              KazumiDialog.showToast(
                message: favoritesTexts.sync.editing,
              );
              return;
            }
            if (syncing) {
              return;
            }
            // ✅ Update state via Riverpod provider
            ref.read(favoritesSyncingProvider.notifier).state = true;
            await collectController.syncCollectibles();
            if (mounted) {
              ref.read(favoritesSyncingProvider.notifier).state = false;
            }
          },
          child: syncing
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(),
                )
              : const Icon(Icons.cloud_sync),
        ),
        body: collectibles.isEmpty
            ? Center(child: Text(favoritesTexts.empty))
            : TabBarView(
                controller: tabController,
                children: List.generate(
                  _visibleTypes.length,
                  (index) => _buildTab(
                    collectibles,
                    context,
                    _visibleTypes[index],
                    favoritesTexts.tabs.empty,
                  ),
                ),
              ),
      ),
    );
  }

  List<Tab> _buildTabs(dynamic tabs) => [
        Tab(text: tabs.watching),
        Tab(text: tabs.planned),
        Tab(text: tabs.completed),
      ];

  Widget _buildTab(
    List<CollectedBangumi> collectibles,
    BuildContext context,
    int type,
    String emptyText,
  ) {
    final filtered = collectibles.where((item) => item.type == type).toList()
      ..sort(
        (a, b) => b.time.millisecondsSinceEpoch
            .compareTo(a.time.millisecondsSinceEpoch),
      );

    if (filtered.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(emptyText)),
          ),
        ],
      );
    }

    // ✅ Watch showDelete state from Riverpod provider
    final showDelete = ref.watch(favoritesShowDeleteProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossCount = _resolveCrossCount(availableWidth);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                StyleString.cardSpace,
                StyleString.cardSpace,
                StyleString.cardSpace,
                0,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisSpacing: StyleString.cardSpace - 2,
                  crossAxisSpacing: StyleString.cardSpace,
                  crossAxisCount: crossCount,
                  mainAxisExtent: _resolveMainAxisExtent(
                    context,
                    crossCount,
                    availableWidth: availableWidth,
                  ),
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final bangumi = filtered[index];
                    return Stack(
                      children: [
                        BangumiCardV(
                          bangumiItem: bangumi.bangumiItem,
                          canTap: !showDelete,
                        ),
                        if (showDelete)
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: CollectButton(
                                bangumiItem: bangumi.bangumiItem,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _resolveCrossCount(double width) {
    return AdaptiveGrid.calculateColumns(
      width,
      smallMobile: 2,
      mobile: 3,
      tablet: 5,
      desktop: 6,
    );
  }

  double _resolveMainAxisExtent(
    BuildContext context,
    int crossCount, {
    required double availableWidth,
  }) {
    final width = availableWidth -
        StyleString.cardSpace * 2 -
        (crossCount - 1) * StyleString.cardSpace;
    final cardWidth = (width / crossCount).clamp(0.0, double.infinity);
    return cardWidth / 0.65 + MediaQuery.textScalerOf(context).scale(32.0);
  }
}
