import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/responsive/responsive_menu_scaffold.dart';
import 'package:haipee/pages/history/history_page.dart';
import 'package:haipee/pages/history/providers.dart';
import 'package:haipee/pages/media/media_page.dart';
import 'package:haipee/pages/my/favorites_page.dart';
import 'package:haipee/pages/my/providers.dart';
import 'package:haipee/pages/timeline/timeline_page.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/utils.dart';

/// 统一媒体库主枢纽页面
///
/// 遵循全应用响应式主菜单/子菜单统一规范 (ResponsiveMenuScaffold):
/// - 宽屏 (>640px): 280px 左侧导航轨道 + 嵌入式媒体分类与探索详情面板
/// - 窄屏 (<=640px): 结构化现代化分组卡片列表，无溢出，点击平滑直达
class MediaLibraryPage extends ConsumerStatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  ConsumerState<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends ConsumerState<MediaLibraryPage> {
  String _selectedId = 'catalog';

  @override
  Widget build(BuildContext context) {
    final isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;

    final collectionsCount =
        ref.watch(collectionsProvider.select((s) => s.collectibles.length));
    final historyCount =
        ref.watch(historyProvider.select((s) => s.histories.length));

    // 获取当前星期
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final currentWeekday = weekdays[DateTime.now().weekday - 1];

    final groups = [
      ResponsiveMenuGroup(
        title: '个人媒体',
        items: [
          ResponsiveMenuItem(
            id: 'favorites',
            title: '个人收藏',
            description: '$collectionsCount 部作品',
            icon: Icons.collections_bookmark_outlined,
            route: Routes.favorites,
            detailBuilder: (_) => const FavoritesPage(),
          ),
          ResponsiveMenuItem(
            id: 'timeline',
            title: '追番日历',
            description: '今日 $currentWeekday 新番',
            icon: Icons.calendar_month_outlined,
            route: Routes.timeline,
            detailBuilder: (_) => const TimelinePage(),
          ),
          ResponsiveMenuItem(
            id: 'history',
            title: '播放历史',
            description: '$historyCount 条历史',
            icon: Icons.history_rounded,
            route: Routes.history,
            detailBuilder: (_) => const HistoryPage(),
          ),
        ],
      ),
      ResponsiveMenuGroup(
        title: '全品类媒体库',
        items: [
          ResponsiveMenuItem(
            id: 'catalog',
            title: '媒体分类探索',
            description: '动画、影视、游戏、音乐、书籍',
            icon: Icons.explore_outlined,
            detailBuilder: (_) => const MediaPage(isEmbedded: true),
          ),
        ],
      ),
    ];

    return ResponsiveMenuScaffold(
      groups: groups,
      selectedId: _selectedId,
      onSelected: (id) => setState(() => _selectedId = id),
      appBarBuilder: (context, wide) => SysAppBar(
        title: const Text('媒体库'),
        actions: [
          IconButton(
            tooltip: '追番日历',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(Routes.timeline),
          ),
          IconButton(
            tooltip: '个人收藏',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => context.push(Routes.favorites),
          ),
          IconButton(
            tooltip: '播放历史',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(Routes.history),
          ),
          IconButton(
            tooltip: 'Haipee 视频规则',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => context.push(Routes.settingsPlugin),
          ),
        ],
        needTopOffset: !isDesktopSideMenu && !wide,
      ),
    );
  }
}
