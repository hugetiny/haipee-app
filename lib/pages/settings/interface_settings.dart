import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/collect/collect_layout.dart';
import 'package:haipee/pages/online/online_video_search_provider.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/utils.dart';

class InterfaceSettingsPage extends ConsumerStatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  ConsumerState<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends ConsumerState<InterfaceSettingsPage> {
  late bool showRating;
  late String defaultPage;
  late CollectLayout _defaultCollectLayout;
  late String _onlineSearchSortMode;
  bool _savingCollectLayout = false;
  static const _exitBehaviorTitles = ['退出 Haipee', '最小化至托盘', '每次都询问'];
  int _exitBehavior = GStorage.getSetting(SettingsKeys.exitBehavior)
      .clamp(0, _exitBehaviorTitles.length - 1);

  static const Map<String, String> _searchSortModeMap = {
    'danmaku': '弹幕热度优先 (默认)',
    'ruleType': '规则协议优先 (Haipee / MacCMS / TVBox...)',
  };

  static const Map<String, String> defaultPageMap = {
    '/tab/online': '在线搜索',
    '/tab/popular': '推荐',
    '/tab/timeline': '时间表',
    '/tab/media': '媒体库与追番',
    '/tab/resource': '资源搜索',
    '/tab/my': '我的',
  };

  @override
  void initState() {
    super.initState();
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    _onlineSearchSortMode =
        GStorage.getSetting(SettingsKeys.onlineSearchSortMode);
    var storedPage =
        GStorage.getSetting<String>(SettingsKeys.defaultStartupPage).trim();
    if (storedPage.endsWith('/') && storedPage.length > 1) {
      storedPage = storedPage.substring(0, storedPage.length - 1);
    }
    if (!defaultPageMap.containsKey(storedPage)) {
      storedPage = '/tab/online';
    }
    defaultPage = storedPage;
    _defaultCollectLayout = CollectLayout.fromValue(
      GStorage.getSetting(SettingsKeys.defaultCollectLayout),
    );
  }

  void updateDefaultPage(String page) {
    GStorage.putSetting(SettingsKeys.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  Future<void> _updateDefaultCollectLayout(CollectLayout layout) async {
    if (_savingCollectLayout || layout == _defaultCollectLayout) return;
    setState(() => _savingCollectLayout = true);
    try {
      await GStorage.putSetting(SettingsKeys.defaultCollectLayout, layout.name);
      if (mounted) setState(() => _defaultCollectLayout = layout);
    } catch (_) {
      if (mounted) HaipeeDialog.showToast(message: '追番默认布局保存失败，请重试');
    } finally {
      if (mounted) setState(() => _savingCollectLayout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeState = ref.watch(localeSettingsProvider);
    final String appLocaleLabel;
    if (localeState.followSystem) {
      appLocaleLabel = '跟随系统';
    } else {
      appLocaleLabel = switch (localeState.appLocale) {
        AppLocale.zhCn => '简体中文 (zh-CN)',
        AppLocale.enUs => 'English (en-US)',
        AppLocale.jaJp => '日本語 (ja-JP)',
        AppLocale.zhTw => '繁體中文 (zh-TW)',
      };
    }

    return SettingsDetailScaffold(
      title: const Text('界面设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('启动'),
            tiles: [
              SettingsDropdownTile<String>(
                leading: const Icon(Icons.home_rounded),
                title: const Text('启动界面设置'),
                description: const Text('设置应用开启时的默认页面'),
                value: defaultPage,
                options: defaultPageMap,
                fallbackLabel: '推荐',
                onChanged: updateDefaultPage,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('展示信息'),
            tiles: [
              SettingsDropdownTile<String>(
                leading: const Icon(Icons.sort_rounded),
                title: const Text('视频搜索排序'),
                description: const Text('默认按弹幕热度高到低排序，或按规则协议类型优先排序'),
                value: _onlineSearchSortMode,
                options: _searchSortModeMap,
                fallbackLabel: '弹幕热度优先 (默认)',
                onChanged: (mode) {
                  setState(() => _onlineSearchSortMode = mode);
                  GStorage.putSetting(SettingsKeys.onlineSearchSortMode, mode);
                  ref
                      .read(onlineVideoSearchProvider.notifier)
                      .setSortMode(mode);
                },
              ),
              SettingsDropdownTile<CollectLayout>(
                leading: const Icon(Icons.view_agenda_rounded),
                title: const Text('追番默认布局'),
                description: const Text('下次打开追番页时使用，页面内切换不会改变此设置'),
                enabled: !_savingCollectLayout,
                value: _defaultCollectLayout,
                options: {
                  for (final layout in CollectLayout.values) layout: layout.label,
                },
                onChanged: _updateDefaultCollectLayout,
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.star_rounded),
                onToggle: (value) async {
                  showRating = value ?? !showRating;
                  await GStorage.putSetting(SettingsKeys.showRating, showRating);
                  setState(() {});
                },
                title: const Text('显示评分'),
                description: const Text('关闭后隐藏概览和番剧列表中的评分信息'),
                initialValue: showRating,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('语言与地区'),
            tiles: [
              SettingsTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('语言设置'),
                description: const Text('选择应用界面语言 (简体中文 / English / 日本語 / 繁體中文)'),
                value: Text(appLocaleLabel),
                onPressed: (context) => context.push(Routes.settingsLanguage),
              ),
            ],
          ),
          if (Utils.isDesktop())
            SettingsSection(
              title: const Text('窗口行为'),
              tiles: [
                SettingsDropdownTile<int>(
                  leading: const Icon(Icons.exit_to_app_rounded),
                  title: const Text('关闭窗口时'),
                  description: const Text('设置点击窗口关闭按钮后的行为'),
                  value: _exitBehavior,
                  options: {
                    for (var i = 0; i < _exitBehaviorTitles.length; i++)
                      i: _exitBehaviorTitles[i],
                  },
                  onChanged: (value) {
                    setState(() => _exitBehavior = value);
                    GStorage.putSetting(SettingsKeys.exitBehavior, value);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
