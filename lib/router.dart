import 'package:haipee/pages/player/local_player_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/pages/online/online_video_search_page.dart';
import 'package:haipee/pages/media_library/media_library_page.dart';
import 'package:haipee/pages/resource/resource_search_page.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/pages/about/about_page.dart';
import 'package:haipee/pages/about/license_page.dart';
import 'package:haipee/pages/my/favorites_page.dart';
import 'package:haipee/pages/my/my_page.dart';
import 'package:haipee/pages/info/info_page.dart';
import 'package:haipee/pages/init_page.dart';
import 'package:haipee/pages/menu/menu.dart';
import 'package:haipee/pages/setting/setting_page.dart';
import 'package:haipee/pages/search/search_page.dart';
import 'package:haipee/pages/settings/decoder_settings.dart';
import 'package:haipee/pages/settings/displaymode_settings.dart';
import 'package:haipee/pages/settings/player_settings.dart';
import 'package:haipee/pages/settings/super_resolution_settings.dart';
import 'package:haipee/pages/settings/theme_settings_page.dart';
import 'package:haipee/pages/setting/appearance/language_settings.dart';
import 'package:haipee/pages/setting/appearance/exit_behavior_settings.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_settings.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:haipee/pages/settings/download/download_settings.dart';
import 'package:haipee/pages/timeline/timeline_page.dart';
import 'package:haipee/pages/video/video_page.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/plugin_editor/plugin_editor_page.dart';
import 'package:haipee/pages/plugin_editor/plugin_shop_page.dart';
import 'package:haipee/pages/webdav_editor/webdav_editor_page.dart';
import 'package:haipee/pages/webdav_editor/webdav_setting.dart';
import 'package:haipee/pages/logs/logs_page.dart';
import 'package:haipee/pages/history/history_page.dart';
import 'package:haipee/pages/download/download_page.dart';
import 'package:haipee/pages/setting/indexer/indexer_settings_page.dart';
import 'package:haipee/pages/setting/media/media_settings_page.dart';
import 'package:haipee/pages/setting/metadata/metadata_settings_page.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/settings/keyboard_settings.dart';
import 'package:haipee/pages/settings/interface_settings.dart';
import 'package:haipee/pages/settings/renderer_settings.dart';
import 'package:haipee/pages/settings/sync/sync_settings_page.dart';
import 'package:haipee/pages/settings/proxy/proxy_settings_page.dart';
import 'package:haipee/pages/settings/proxy/proxy_editor_page.dart';
import 'package:haipee/pages/settings/update_settings.dart';
import 'package:haipee/pages/settings/storage_settings.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/sentry/sentry_service.dart';

/// 全局路由配置
///
/// 使用 go_router 管理应用导航
/// - 支持深度链接
/// - 统一错误处理
/// - 路由重定向
final GlobalKey<NavigatorState> rootNavigatorKey = () {
  final key = GlobalKey<NavigatorState>();
  AppLog.rootNavigatorKey = key;
  return key;
}();

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  observers: [
    HaipeeDialog.observer,
    SentryService.navigatorObserver,
  ],

  // 初始路由
  initialLocation: Routes.onlineVideo,

  // 全局错误处理
  errorBuilder: (context, state) {
    final t = context.t;
    return Scaffold(
      appBar: SysAppBar(
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
              onPressed: () => context.go(Routes.onlineVideo),
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
          path: Routes.onlineVideo,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OnlineVideoSearchPage(),
          ),
        ),
        GoRoute(
          path: Routes.resource,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ResourceSearchPage(),
          ),
        ),
        GoRoute(
          path: Routes.media,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MediaLibraryPage(),
          ),
        ),
        GoRoute(
          path: Routes.popular,
          redirect: (context, state) => Routes.onlineVideo,
        ),
        GoRoute(
          path: Routes.timeline,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TimelinePage(),
          ),
        ),
        GoRoute(
          path: Routes.download,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DownloadPage(),
          ),
        ),
        GoRoute(
          path: Routes.my,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MyPage(),
          ),
        ),
        GoRoute(
          path: Routes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingPage(),
          ),
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
      path: Routes.localPlayer,
      builder: (context, state) => LocalPlayerPage(
        args: state.extra as LocalVideoPlayArgs,
      ),
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
          return Routes.settingsPlayer;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: 'interface',
          builder: (context, state) => const InterfaceSettingsPage(),
        ),
        GoRoute(
          path: 'keyboard',
          builder: (context, state) => const KeyboardSettingsPage(),
        ),
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
              path: 'renderer',
              builder: (context, state) => const RendererSettingsPage(),
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
              builder: (context, state) => const HaipeeLicensePage(),
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
          builder: (context, state) => PluginViewPage(
            initialCategoryKey: state.uri.queryParameters['category'],
            initialRuleTypeKey: state.uri.queryParameters['type'],
          ),
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
        GoRoute(
          path: 'download-settings',
          redirect: (context, state) => Routes.settingsDownload,
        ),
        GoRoute(
          path: 'sync',
          builder: (context, state) => const SyncSettingsPage(),
        ),
        GoRoute(
          path: 'proxy',
          builder: (context, state) => const ProxySettingsPage(),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (context, state) => const ProxyEditorPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'update',
          builder: (context, state) => const UpdateSettingsPage(),
        ),
        GoRoute(
          path: 'storage',
          builder: (context, state) => const StorageSettingsPage(),
          routes: [
            GoRoute(
              path: 'logs',
              redirect: (context, state) => Routes.settingsAboutLogs,
            ),
          ],
        ),
        GoRoute(
          path: 'rules',
          redirect: (context, state) => Routes.settingsPlugin,
        ),
        GoRoute(
          path: 'indexers',
          builder: (context, state) => const IndexerSettingsPage(),
        ),
        GoRoute(
          path: 'media',
          builder: (context, state) => const MediaSettingsPage(),
        ),
        GoRoute(
          path: 'metadata',
          builder: (context, state) => const MetadataSettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: Routes.search,
      builder: (context, state) => SearchPage(
        inputTag: Routes.getSearchTag(state.uri.queryParameters),
      ),
    ),
  ],
);
