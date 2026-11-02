import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive_menu_scaffold.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/download/download_page.dart';
import 'package:haipee/pages/history/history_page.dart';
import 'package:haipee/pages/layout/app_bar_config.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/pages/my/favorites_page.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/timeline/timeline_page.dart';
import 'package:haipee/router_constants.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  String _selectedId = Routes.favorites;

  void _onBackPressed() {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.onlineVideo);
  }

  void _updateAppBarConfig({required bool wide}) {
    if (!mounted) return;
    final t = context.t;

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: t.library.my.title,
      visible: !wide,
      needTopOffset: false,
    );
  }

  Widget _buildDetail(String id) {
    switch (id) {
      case Routes.favorites:
        return const FavoritesPage();
      case Routes.history:
        return const HistoryPage();
      case Routes.download:
      case '/my/download':
        return const DownloadPage();
      case Routes.timeline:
        return const TimelinePage();
      case Routes.settingsPlugin:
        return const PluginViewPage(isEmbedded: true);
      default:
        return const FavoritesPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    final groups = [
      ResponsiveMenuGroup(
        title: t.library.my.sections.video,
        items: [
          ResponsiveMenuItem(
            id: Routes.favorites,
            title: t.library.my.favorites.title,
            description: t.library.my.favorites.description,
            icon: Icons.collections_bookmark_outlined,
            route: Routes.favorites,
            detailBuilder: (_) => const FavoritesPage(),
          ),
          ResponsiveMenuItem(
            id: Routes.history,
            title: t.library.my.history.title,
            description: t.library.my.history.description,
            icon: Icons.history_rounded,
            route: Routes.history,
            detailBuilder: (_) => const HistoryPage(),
          ),
          ResponsiveMenuItem(
            id: Routes.download,
            title: '下载管理',
            description: '管理离线与下载任务',
            icon: Icons.download_rounded,
            route: Routes.download,
            detailBuilder: (_) => const DownloadPage(),
          ),
        ],
      ),
      ResponsiveMenuGroup(
        title: '发现与扩展',
        items: [
          ResponsiveMenuItem(
            id: Routes.timeline,
            title: '追番日历',
            description: '每日新番更新时间表',
            icon: Icons.calendar_month_outlined,
            route: Routes.timeline,
            detailBuilder: (_) => const TimelinePage(),
          ),
          ResponsiveMenuItem(
            id: Routes.settingsPlugin,
            title: '规则管理',
            description: '番剧、影视、直播与网盘规则',
            icon: Icons.extension_outlined,
            route: Routes.settingsPlugin,
            detailBuilder: (_) => const PluginViewPage(isEmbedded: true),
          ),
        ],
      ),
    ];

    return ResponsiveMenuScaffold(
      groups: groups,
      selectedId: _selectedId,
      onSelected: (id) {
        setState(() {
          _selectedId = id;
        });
      },
      onBackPressed: _onBackPressed,
      onWideChanged: (wide) => _updateAppBarConfig(wide: wide),
      detailBuilder: (context, id) => _buildDetail(id),
    );
  }
}
