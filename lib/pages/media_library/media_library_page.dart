import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/history/providers.dart';
import 'package:kazumi/pages/media/media_page.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/utils.dart';

/// 统一媒体库主枢纽页面
///
/// 严格整合:
/// 1. 顶部三联个人媒体快捷卡片: [ 个人收藏 ] · [ 追番日历 (Bangumi 日历) ] · [ 播放历史 ]
/// 2. 下方嵌入全品类元数据与分类检索 (动画、影视、游戏、音乐、书籍)
class MediaLibraryPage extends ConsumerStatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  ConsumerState<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends ConsumerState<MediaLibraryPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktopSideMenu =
        Utils.isDesktop() && MediaQuery.of(context).orientation != Orientation.portrait;

    final collectionsCount =
        ref.watch(collectionsProvider.select((s) => s.collectibles.length));
    final historyCount =
        ref.watch(historyProvider.select((s) => s.histories.length));

    // 获取当前星期
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final currentWeekday = weekdays[DateTime.now().weekday - 1];

    return Scaffold(
      appBar: SysAppBar(
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
            tooltip: 'Kazumi 视频规则',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => context.push(Routes.settingsPlugin),
          ),
        ],
        needTopOffset: !isDesktopSideMenu,
      ),
      body: Column(
        children: [
          // 顶部个人媒体快速中枢栏 (三联卡片)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickCard(
                    title: '个人收藏',
                    subtitle: '$collectionsCount 部作品',
                    icon: Icons.collections_bookmark,
                    color: Colors.pinkAccent,
                    onTap: () => context.push(Routes.favorites),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(
                    title: '追番日历',
                    subtitle: '今日 $currentWeekday 新番',
                    icon: Icons.calendar_today,
                    color: Colors.blueAccent,
                    onTap: () => context.push(Routes.timeline),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(
                    title: '播放历史',
                    subtitle: '$historyCount 条历史',
                    icon: Icons.history_rounded,
                    color: Colors.orangeAccent,
                    onTap: () => context.push(Routes.history),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),

          // 下方全品类元数据与分类探索流
          const Expanded(
            child: MediaPage(isEmbedded: true),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
