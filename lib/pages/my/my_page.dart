import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/menu/navigation_provider.dart';
import 'package:kazumi/pages/layout/app_bar_config.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  void _onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    ref.read(navigationProvider.notifier).updateSelectedIndex(0);
    context.go(Routes.media);
  }

  void _updateAppBarConfig() {
    if (!mounted) return;
    final t = context.t;

    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: t.library.my.title,
      needTopOffset: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // 初始化时设置 AppBar
    Future.microtask(() {
      if (mounted) {
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
      child: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.library.my.sections.video),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => context.push(Routes.favorites),
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: Text(t.library.my.favorites.title),
                description: Text(t.library.my.favorites.description),
              ),
              SettingsTile.navigation(
                onPressed: (_) => context.push(Routes.history),
                leading: const Icon(Icons.history_rounded),
                title: Text(t.library.my.history.title),
                description: Text(t.library.my.history.description),
              ),
              SettingsTile.navigation(
                onPressed: (_) => context.push('/my/download'),
                leading: const Icon(Icons.download_rounded),
                title: const Text('下载管理'),
                description: const Text('管理下载任务'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
