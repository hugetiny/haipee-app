import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive_menu_scaffold.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/about/about_page.dart';
import 'package:haipee/pages/layout/app_bar_config.dart';
import 'package:haipee/pages/menu/navigation_provider.dart';
import 'package:haipee/pages/plugin_editor/plugin_view_page.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_settings.dart';
import 'package:haipee/pages/settings/download/download_settings.dart';
import 'package:haipee/pages/settings/interface_settings.dart';
import 'package:haipee/pages/settings/keyboard_settings.dart';
import 'package:haipee/pages/settings/player_settings.dart';
import 'package:haipee/pages/settings/proxy/proxy_settings_page.dart';
import 'package:haipee/pages/settings/storage_settings.dart';
import 'package:haipee/pages/settings/sync/sync_settings_page.dart';
import 'package:haipee/pages/settings/theme_settings_page.dart';
import 'package:haipee/pages/settings/update_settings.dart';
import 'package:haipee/router_constants.dart';

const List<ResponsiveMenuGroup> _settingsGroups = [
  ResponsiveMenuGroup(
    title: '播放',
    items: [
      ResponsiveMenuItem(
        id: Routes.settingsPlayer,
        title: '播放设置',
        description: '解码、渲染与播放行为',
        icon: Icons.display_settings_rounded,
        route: Routes.settingsPlayer,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsDanmaku,
        title: '弹幕设置',
        description: '弹幕来源与显示效果',
        icon: Icons.subtitles_rounded,
        route: Routes.settingsDanmaku,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsKeyboard,
        title: '操作设置',
        description: '播放器按键映射',
        icon: Icons.keyboard_rounded,
        route: Routes.settingsKeyboard,
      ),
    ],
  ),
  ResponsiveMenuGroup(
    title: '资源',
    items: [
      ResponsiveMenuItem(
        key: Key('setting_rule_all'),
        id: Routes.settingsPlugin,
        title: '规则管理',
        description: 'Haipee、MacCMS、TVBox、IPTV、Piped、AList 与 Cardigann 7 大规则',
        icon: Icons.extension_rounded,
        route: Routes.settingsPlugin,
      ),
      ResponsiveMenuItem(
        key: Key('setting_download_settings'),
        id: Routes.settingsDownload,
        title: '下载设置',
        description: '并发数与弹幕缓存',
        icon: Icons.downloading_rounded,
        route: Routes.settingsDownload,
      ),
    ],
  ),
  ResponsiveMenuGroup(
    title: '应用',
    items: [
      ResponsiveMenuItem(
        id: Routes.settingsTheme,
        title: '外观设置',
        description: '主题、配色与字体',
        icon: Icons.palette_rounded,
        route: Routes.settingsTheme,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsInterface,
        title: '界面设置',
        description: '启动、窗口行为与展示信息',
        icon: Icons.pages_rounded,
        route: Routes.settingsInterface,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsSync,
        title: '同步设置',
        description: '追番状态与多设备同步',
        icon: Icons.cloud_rounded,
        route: Routes.settingsSync,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsProxy,
        title: '网络设置',
        description: '访问加速与代理',
        icon: Icons.language_rounded,
        route: Routes.settingsProxy,
      ),
    ],
  ),
  ResponsiveMenuGroup(
    title: '其他',
    items: [
      ResponsiveMenuItem(
        id: Routes.settingsUpdate,
        title: '更新设置',
        description: '应用与规则更新',
        icon: Icons.update_rounded,
        route: Routes.settingsUpdate,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsStorage,
        title: '存储与日志',
        description: '图片缓存与错误日志',
        icon: Icons.storage_rounded,
        route: Routes.settingsStorage,
      ),
      ResponsiveMenuItem(
        id: Routes.settingsAbout,
        title: '关于',
        description: '版本与开源信息',
        icon: Icons.info_outline_rounded,
        route: Routes.settingsAbout,
      ),
    ],
  ),
];

String _normalizePath(String? path) {
  if (path == null || path.isEmpty) return Routes.settingsPlayer;
  var p = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  if (p == '/settings' || p == '/tab/setting') {
    return Routes.settingsPlayer;
  }
  if (p == '/settings/download-settings') {
    return Routes.settingsDownload;
  }
  if (p == '/settings/webdav' ||
      p.startsWith('/settings/webdav/') ||
      p == '/settings/bangumi' ||
      p.startsWith('/settings/bangumi/')) {
    return Routes.settingsSync;
  }
  if (p == Routes.settingsLanguage ||
      p.startsWith('${Routes.settingsLanguage}/') ||
      p == Routes.settingsExitBehavior ||
      p.startsWith('${Routes.settingsExitBehavior}/')) {
    return Routes.settingsInterface;
  }
  if (p == Routes.settingsMetadata ||
      p.startsWith('${Routes.settingsMetadata}/') ||
      p == Routes.settingsMedia ||
      p.startsWith('${Routes.settingsMedia}/')) {
    return Routes.settingsPlayer;
  }
  if (p == Routes.settingsRuleCenter ||
      p == Routes.settingsIndexers ||
      p.startsWith('${Routes.settingsIndexers}/')) {
    return Routes.settingsPlugin;
  }
  if (p == '/settings/storage/logs') {
    return Routes.settingsStorage;
  }
  if (p == Routes.settingsAboutLogs ||
      p == Routes.settingsAboutLicense ||
      p.startsWith('${Routes.settingsAbout}/')) {
    return Routes.settingsAbout;
  }
  for (final group in _settingsGroups) {
    for (final item in group.items) {
      if (p == item.id || p.startsWith('${item.id}/')) {
        return item.id;
      }
    }
  }
  return Routes.settingsPlayer;
}

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key, this.location, this.initialPath});

  final String? location;
  final String? initialPath;

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  late String _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = _normalizePath(widget.initialPath ?? widget.location);
  }

  @override
  void didUpdateWidget(covariant SettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.initialPath ?? widget.location;
    final oldTarget = oldWidget.initialPath ?? oldWidget.location;
    if (target != oldTarget && target != null) {
      setState(() {
        _selectedPath = _normalizePath(target);
      });
    }
  }

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
      title: t.settings.title,
      visible: !wide,
      needTopOffset: false,
    );
  }

  Widget _buildDetailWidget(String path) {
    switch (path) {
      case Routes.settingsPlayer:
        return const PlayerSettingsPage();
      case Routes.settingsDanmaku:
        return const DanmakuSettingsPage();
      case Routes.settingsKeyboard:
        return const KeyboardSettingsPage();
      case Routes.settingsPlugin:
      case Routes.settingsRuleCenter:
        return const PluginViewPage(isEmbedded: true);
      case Routes.settingsDownload:
      case '/settings/download-settings':
        return const DownloadSettingsPage();
      case Routes.settingsTheme:
        return const ThemeSettingsPage();
      case Routes.settingsInterface:
        return const InterfaceSettingsPage();
      case Routes.settingsSync:
        return const SyncSettingsPage();
      case Routes.settingsProxy:
        return const ProxySettingsPage();
      case Routes.settingsUpdate:
        return const UpdateSettingsPage();
      case Routes.settingsStorage:
        return const StorageSettingsPage();
      case Routes.settingsAbout:
        return const AboutPage();
      default:
        return const PlayerSettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveMenuScaffold(
      groups: _settingsGroups,
      selectedId: _selectedPath,
      onSelected: (path) {
        setState(() {
          _selectedPath = path;
        });
      },
      onBackPressed: _onBackPressed,
      onWideChanged: (wide) => _updateAppBarConfig(wide: wide),
      detailBuilder: (context, path) => _buildDetailWidget(path),
    );
  }
}
