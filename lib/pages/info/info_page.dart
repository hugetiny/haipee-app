import 'package:haipee/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'dart:io';
import 'dart:ui';
import 'package:haipee/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/bean/widget/collect_button.dart';
import 'package:haipee/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:haipee/bean/widget/embedded_native_control_area.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/pages/info/info_controller.dart';
import 'package:haipee/pages/info/providers.dart';
import 'package:haipee/bean/card/bangumi_info_card.dart';
import 'package:haipee/pages/info/source_sheet.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/bean/card/network_img_layer.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/pages/info/info_tabview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:haipee/l10n/generated/translations.g.dart';

class InfoPage extends ConsumerStatefulWidget {
  const InfoPage({super.key, this.bangumi});

  final BangumiItem? bangumi;

  @override
  ConsumerState<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends ConsumerState<InfoPage>
    with TickerProviderStateMixin {
  late final InfoController infoController;
  late final VideoPageController videoPageController;
  late TabController infoTabController;

  @override
  void initState() {
    super.initState();
    infoController = ref.read(bangumiInfoProvider.notifier);
    videoPageController = ref.read(videoProvider.notifier);
    final BangumiItem? initialBangumi = widget.bangumi;

    // Delay provider state modifications until after initState completes
    Future.microtask(() {
      if (!mounted) return;

      if (initialBangumi != null) {
        infoController.bangumiItem = initialBangumi;
      }
      infoController.resetListsForNewBangumi();
      videoPageController.currentEpisode = 1;

      // Query bangumi info asynchronously if needed
      if (infoController.bangumiItem.summary == '' ||
          infoController.bangumiItem.votesCount.isEmpty) {
        queryBangumiInfoByID(infoController.bangumiItem.id, type: 'attach');
      }
    });

    infoTabController = TabController(length: 5, vsync: this);
    // ✅ Riverpod providers will handle lazy loading automatically
    // No need for manual tab listener to trigger data loading
  }

  @override
  void dispose() {
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    try {
      await infoController.queryBangumiInfoByID(id, type: type);
    } catch (e) {
      HaipeeLogger().log(Level.error, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bangumiInfoProvider);
    final infoTexts = context.t.library.info;
    final metadataTexts = infoTexts.metadata;
    final List<String> tabs = <String>[
      infoTexts.tabs.overview,
      infoTexts.tabs.comments,
      infoTexts.tabs.characters,
      infoTexts.tabs.reviews,
      infoTexts.tabs.staff,
    ];
    final bool showWindowButton = GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar.medium(
                    title: EmbeddedNativeControlArea(
                      child: dtb.DragToMoveArea(
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            infoController.bangumiItem.nameCn == ''
                                ? infoController.bangumiItem.name
                                : infoController.bangumiItem.nameCn,
                          ),
                        ),
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    scrolledUnderElevation: 0.0,
                    leadingWidth:
                        DesktopWindowControlsSafeArea.leadingWidth(48.0),
                    leading: DesktopWindowControlsSafeArea.wrapLeading(
                      EmbeddedNativeControlArea(
                        child: const AppBackButton(),
                      ),
                    ),
                    actions: [
                      EmbeddedNativeControlArea(
                        child: IconButton(
                          tooltip: '搜索高清BT/磁力下载',
                          onPressed: () {
                            final searchKeyword = infoController.bangumiItem.nameCn.isNotEmpty
                                ? infoController.bangumiItem.nameCn
                                : infoController.bangumiItem.name;
                            TorrentSearchSheet.show(
                              context,
                              initialKeyword: searchKeyword,
                              bangumiId: infoController.bangumiItem.id.toString(),
                            );
                          },
                          icon: const Icon(Icons.download_for_offline_outlined),
                        ),
                      ),
                      EmbeddedNativeControlArea(
                        child: IconButton(
                          tooltip: metadataTexts.refresh,
                          onPressed: state.metadataLoading
                              ? null
                              : () {
                                  infoController.refreshMetadata(
                                    forceRefresh: true,
                                  );
                                },
                          icon: state.metadataLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      if (innerBoxIsScrolled)
                        EmbeddedNativeControlArea(
                          child: CollectButton(
                            bangumiItem: infoController.bangumiItem,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      EmbeddedNativeControlArea(
                        child: IconButton(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                  'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_browser_rounded),
                        ),
                      ),
                      if (!showWindowButton && Utils.isDesktop())
                        CloseButton(onPressed: () => windowManager.close()),
                      SizedBox(width: 8),
                    ],
                    toolbarHeight: (Platform.isMacOS && showWindowButton)
                        ? kToolbarHeight + 22
                        : kToolbarHeight,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight: (Platform.isMacOS && showWindowButton)
                        ? 308 + kTextTabBarHeight + kToolbarHeight + 22
                        : 308 + kTextTabBarHeight + kToolbarHeight,
                    collapsedHeight: (Platform.isMacOS && showWindowButton)
                        ? kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top +
                            22
                        : kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Stack(
                        children: [
                          if (!state.isLoading)
                            Positioned.fill(
                              bottom: kTextTabBarHeight,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 0.4,
                                  child: LayoutBuilder(
                                    builder: (context, boxConstraints) {
                                      return ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                            sigmaX: 15.0, sigmaY: 15.0),
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white,
                                                Colors.transparent,
                                              ],
                                              stops: [0.8, 1],
                                            ).createShader(bounds);
                                          },
                                          child: NetworkImgLayer(
                                            src: infoController.bangumiItem
                                                    .images['large'] ??
                                                '',
                                            width: boxConstraints.maxWidth,
                                            height: boxConstraints.maxHeight,
                                            fadeInDuration:
                                                const Duration(milliseconds: 0),
                                            fadeOutDuration:
                                                const Duration(milliseconds: 0),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          SafeArea(
                            bottom: false,
                            child: EmbeddedNativeControlArea(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, kToolbarHeight, 16, 0),
                                  child: BangumiInfoCardV(
                                    bangumiItem: infoController.bangumiItem,
                                    isLoading: state.isLoading,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      controller: infoTabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerHeight: 0,
                      tabs: tabs.map((name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: InfoTabView(
              tabController: infoTabController,
              bangumiItem: infoController.bangumiItem,
              commentsList: state.commentsList,
              isLoading: state.isLoading,
              metadataRecord: state.metadataRecord,
              metadataLoading: state.metadataLoading,
              onRefreshMetadata: () {
                infoController.refreshMetadata(forceRefresh: true);
              },
            ),
          ),
          floatingActionButton: _buildBottomActions(context, infoController),
        ),
      ),
    );
  }

  void _navigateToUniversalSearch(
    BuildContext context,
    InfoController controller,
  ) {
    final item = widget.bangumi ?? controller.bangumiItem;
    final searchKeyword =
        item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final TorrentCategory category = switch (item.type) {
      1 => TorrentCategory.document, // 书籍
      2 => TorrentCategory.video, // 动画
      3 => TorrentCategory.audio, // 音乐
      4 => TorrentCategory.game, // 游戏
      6 => TorrentCategory.video, // 影视
      _ => TorrentCategory.all,
    };

    // 联动设置资源搜索的单选分类和搜索词并触发搜索
    ref.read(torrentSearchProvider.notifier).setCategoryFilter(category);
    ref.read(torrentSearchProvider.notifier).search(searchKeyword);

    // 切换主导航至「全网资源」并跳转
    ref.read(navigationProvider.notifier).updateSelectedIndex(1);
    context.go(Routes.resource);
  }

  Widget _buildBottomActions(
    BuildContext context,
    InfoController controller,
  ) {
    final item = widget.bangumi ?? controller.bangumiItem;
    final isVideo = item.type == 2 || item.type == 6; // 动画或影视
    final t = context.t;

    if (!isVideo) {
      // 非视频类：书籍、音乐、游戏，单按钮全网直搜
      return FloatingActionButton.extended(
        key: const Key('info_btn_universal_search'),
        icon: const Icon(Icons.travel_explore_rounded),
        label: const Text('全网搜索资源'),
        onPressed: () => _navigateToUniversalSearch(context, controller),
      );
    }

    // 视频类（动画/影视）：左右双按钮分流
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 左按钮：全网BT资源搜索
        FloatingActionButton.extended(
          key: const Key('info_btn_search_torrent'),
          heroTag: 'info_search_torrent_fab',
          icon: const Icon(Icons.travel_explore_rounded),
          label: const Text('全网BT搜索'),
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 2,
          onPressed: () => _navigateToUniversalSearch(context, controller),
        ),
        const SizedBox(width: 12),
        // 右按钮：在线观看 (网页HTTP插件)
        FloatingActionButton.extended(
          key: const Key('info_btn_watch_online'),
          heroTag: 'info_watch_online_fab',
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(t.library.info.actions.startWatching),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SourceSheet(
                  infoController: controller,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
