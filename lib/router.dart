import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/my/favorites_page.dart';
import 'package:kazumi/pages/my/my_page.dart';
import 'package:kazumi/pages/info/info_page.dart';
import 'package:kazumi/pages/init_page.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/setting/setting_page.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/settings/decoder_settings.dart';
import 'package:kazumi/pages/settings/displaymode_settings.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/pages/settings/super_resolution_settings.dart';
import 'package:kazumi/pages/settings/theme_settings_page.dart';
import 'package:kazumi/pages/setting/appearance/language_settings.dart';
import 'package:kazumi/pages/setting/appearance/exit_behavior_settings.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:kazumi/pages/settings/download/download_settings.dart';
import 'package:kazumi/pages/timeline/timeline_page.dart';
import 'package:kazumi/pages/video/video_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_view_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_editor_page.dart';
import 'package:kazumi/pages/plugin_editor/plugin_shop_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_editor_page.dart';
import 'package:kazumi/pages/webdav_editor/webdav_setting.dart';
import 'package:kazumi/pages/logs/logs_page.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

/// 全局路由配置
///
/// 使用 go_router 管理应用导航
/// - 支持深度链接
/// - 统一错误处理
/// - 路由重定向
final GoRouter router = GoRouter(
  observers: [KazumiDialog.observer],

  // 初始路由
  initialLocation: Routes.popular,

  // 全局错误处理
  errorBuilder: (context, state) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.app.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Route Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(Routes.popular),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  },

  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const InitPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => ScaffoldMenu(child: child),
      routes: [
        GoRoute(
          path: Routes.popular,
          builder: (context, state) => PopularPage(
            initialSearchTag: Routes.getSearchTag(state.uri.queryParameters),
          ),
        ),
        GoRoute(
          path: Routes.timeline,
          builder: (context, state) => const TimelinePage(),
        ),
        GoRoute(
          path: Routes.my,
          builder: (context, state) => const MyPage(),
        ),
        GoRoute(
          path: Routes.download,
          builder: (context, state) => const DownloadPage(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingPage(),
        ),
      ],
    ),
    GoRoute(
      path: Routes.favorites,
      builder: (context, state) => const FavoritesPage(),
    ),
    GoRoute(
      path: Routes.history,
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: Routes.video,
      builder: (context, state) => const VideoPage(),
    ),
    GoRoute(
      path: Routes.info,
      builder: (context, state) => InfoPage(
        bangumi: state.extra is BangumiItem ? state.extra as BangumiItem : null,
      ),
    ),
    GoRoute(
      path: Routes.settingsRoot,
      redirect: (context, state) {
        if (state.uri.path == Routes.settingsRoot) {
          return Routes.settingsTheme;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: 'language',
          builder: (context, state) => const LanguageSettings(),
        ),
        GoRoute(
          path: 'exit-behavior',
          builder: (context, state) => const ExitBehaviorSettings(),
        ),
        GoRoute(
          path: 'theme',
          builder: (context, state) => const ThemeSettingsPage(),
          routes: [
            GoRoute(
              path: 'display',
              builder: (context, state) => const SetDisplayMode(),
            ),
          ],
        ),
        GoRoute(
          path: 'player',
          builder: (context, state) => const PlayerSettingsPage(),
          routes: [
            GoRoute(
              path: 'decoder',
              builder: (context, state) => const DecoderSettings(),
            ),
            GoRoute(
              path: 'super',
              builder: (context, state) => const SuperResolutionSettings(),
            ),
          ],
        ),
        GoRoute(
          path: 'about',
          builder: (context, state) => const AboutPage(),
          routes: [
            GoRoute(
              path: 'logs',
              builder: (context, state) => const LogsPage(),
            ),
            GoRoute(
              path: 'license',
              builder: (context, state) => LicensePage(
                applicationName: 'Kazumi',
                applicationVersion: Api.version,
                applicationLegalese: context.t.dialogs.about.licenseLegalese,
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'danmaku',
          builder: (context, state) => const DanmakuSettingsPage(),
          routes: [
            GoRoute(
              path: 'shield',
              builder: (context, state) => const DanmakuShieldSettings(),
            ),
          ],
        ),
        GoRoute(
          path: 'webdav',
          builder: (context, state) => const WebDavSettingsPage(),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (context, state) => const WebDavEditorPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'plugin',
          builder: (context, state) => const PluginViewPage(),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (context, state) {
                final plugin = state.extra is Plugin
                    ? state.extra as Plugin
                    : Plugin.fromTemplate();
                return PluginEditorPage(plugin: plugin);
              },
            ),
            GoRoute(
              path: 'shop',
              builder: (context, state) => const PluginShopPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'download',
          builder: (context, state) => const DownloadSettingsPage(),
        ),
      ],
    ),
  ],
);
