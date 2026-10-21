import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/torrent_search/widgets/torrent_search_sheet.dart';
import 'package:kazumi/pages/history/providers.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:kazumi/pages/video/providers.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';

/// 番剧卡片右键/长按菜单通用构建器
class BangumiContextMenuHelper {
  /// 播放指定的观看历史条目
  static Future<void> playBangumiHistory(
    BuildContext context,
    WidgetRef ref,
    History historyItem,
  ) async {
    final videoPageController = ref.read(videoProvider.notifier);
    final pluginsController = ref.read(pluginsProvider.notifier);
    final router = GoRouter.of(context);

    KazumiDialog.showLoading(
      msg: '正在解析播放路线...',
      barrierDismissible: Utils.isDesktop(),
      onDismiss: () {
        videoPageController.cancelQueryRoads();
      },
    );

    bool flag = false;
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == historyItem.adapterName) {
        videoPageController.currentPlugin = plugin;
        flag = true;
        break;
      }
    }
    if (!flag) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '该视频来源规则已缺失或已卸载');
      return;
    }
    videoPageController.bangumiItem = historyItem.bangumiItem;
    videoPageController.title = historyItem.bangumiItem.nameCn.isEmpty
        ? historyItem.bangumiItem.name
        : historyItem.bangumiItem.nameCn;
    videoPageController.src = historyItem.lastSrc;
    try {
      await videoPageController.queryRoads(
        historyItem.lastSrc,
        videoPageController.currentPlugin.name,
      );
      KazumiDialog.dismiss();
      if (!context.mounted) return;
      router.push(Routes.video);
    } catch (_) {
      KazumiLogger().log(Level.warning, "获取视频播放列表失败");
      KazumiDialog.dismiss();
      if (context.mounted) {
        KazumiDialog.showToast(message: '获取视频播放列表失败', context: context);
      }
    }
  }

  /// 构建统一风格的番剧卡片右键/上下文菜单
  static List<AppMenuItem> buildMenuItems({
    required BuildContext context,
    required WidgetRef ref,
    required BangumiItem bangumiItem,
    History? explicitHistoryItem,
    VoidCallback? onDeleteHistory,
    bool showDeleteHistory = true,
  }) {
    final title = bangumiItem.nameCn.isNotEmpty
        ? bangumiItem.nameCn
        : bangumiItem.name;
    final bgmUrl = 'https://bgm.tv/subject/${bangumiItem.id}';

    // 查找历史记录 (回调中必须使用 ref.read 保持纯净无副作用)
    final historyState = ref.read(historyProvider);
    final matchedHistory = explicitHistoryItem ??
        historyState.histories
            .where((h) => h.bangumiItem.id == bangumiItem.id)
            .firstOrNull;

    // 收藏状态
    final collectController = ref.read(collectionsProvider.notifier);
    final collectType = collectController.getCollectType(bangumiItem);

    final items = <AppMenuItem>[];

    // 1. 播放与详情操作
    if (matchedHistory != null) {
      final epName = matchedHistory.lastWatchEpisodeName.isNotEmpty
          ? matchedHistory.lastWatchEpisodeName
          : '第${matchedHistory.lastWatchEpisode}话';
      items.add(
        AppMenuAction(
          title: '继续观看 ($epName)',
          icon: Icons.play_circle_filled_rounded,
          onSelected: () => playBangumiHistory(context, ref, matchedHistory),
        ),
      );
    } else {
      items.add(
        AppMenuAction(
          title: '立即观看',
          icon: Icons.play_arrow_rounded,
          onSelected: () => context.push(Routes.info, extra: bangumiItem),
        ),
      );
    }

    items.add(
      AppMenuAction(
        title: '查看番剧详情',
        icon: Icons.info_outline_rounded,
        onSelected: () => context.push(Routes.info, extra: bangumiItem),
      ),
    );

    // 2. 追番收藏管理
    if (collectType == 0) {
      items.add(
        AppMenuSubmenu(
          title: '添加追番',
          icon: Icons.favorite_border_rounded,
          children: [
            AppMenuAction(
              title: '在看 (Watching)',
              icon: Icons.favorite_rounded,
              onSelected: () {
                collectController.addCollect(bangumiItem, type: 1);
                KazumiDialog.showToast(message: '已设为【在看】', context: context);
              },
            ),
            AppMenuAction(
              title: '想看 (Wish)',
              icon: Icons.star_rounded,
              onSelected: () {
                collectController.addCollect(bangumiItem, type: 2);
                KazumiDialog.showToast(message: '已设为【想看】', context: context);
              },
            ),
            AppMenuAction(
              title: '看过 (Watched)',
              icon: Icons.done_all_rounded,
              onSelected: () {
                collectController.addCollect(bangumiItem, type: 4);
                KazumiDialog.showToast(message: '已设为【看过】', context: context);
              },
            ),
          ],
        ),
      );
    } else {
      final currentTypeLabel = switch (collectType) {
        1 => '在看',
        2 => '想看',
        4 => '看过',
        _ => '已追',
      };
      items.add(
        AppMenuSubmenu(
          title: '修改追番 ($currentTypeLabel)',
          icon: Icons.favorite_rounded,
          children: [
            if (collectType != 1)
              AppMenuAction(
                title: '设为 在看',
                icon: Icons.favorite_rounded,
                onSelected: () {
                  collectController.addCollect(bangumiItem, type: 1);
                  KazumiDialog.showToast(message: '已切换为【在看】', context: context);
                },
              ),
            if (collectType != 2)
              AppMenuAction(
                title: '设为 想看',
                icon: Icons.star_rounded,
                onSelected: () {
                  collectController.addCollect(bangumiItem, type: 2);
                  KazumiDialog.showToast(message: '已切换为【想看】', context: context);
                },
              ),
            if (collectType != 4)
              AppMenuAction(
                title: '设为 看过',
                icon: Icons.done_all_rounded,
                onSelected: () {
                  collectController.addCollect(bangumiItem, type: 4);
                  KazumiDialog.showToast(message: '已切换为【看过】', context: context);
                },
              ),
          ],
        ),
      );
      items.add(
        AppMenuAction(
          title: '取消追番',
          icon: Icons.heart_broken_outlined,
          destructive: true,
          onSelected: () {
            collectController.deleteCollect(bangumiItem);
            KazumiDialog.showToast(message: '已取消追番', context: context);
          },
        ),
      );
    }

    // 3. 移出观看历史
    if (showDeleteHistory && matchedHistory != null) {
      items.add(
        AppMenuAction(
          title: '移出观看历史',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onSelected: () {
            if (onDeleteHistory != null) {
              onDeleteHistory();
            } else {
              ref.read(historyProvider.notifier).deleteHistory(matchedHistory);
              KazumiDialog.showToast(message: '已移出观看历史', context: context);
            }
          },
        ),
      );
    }

    items.add(const AppMenuSeparator());

    // 4. 磁力与多引擎离线下载
    items.add(
      AppMenuAction(
        title: '检索磁力/离线下载...',
        icon: Icons.download_rounded,
        onSelected: () {
          TorrentSearchSheet.show(
            context,
            initialKeyword: title,
            bangumiId: bangumiItem.id.toString(),
          );
        },
      ),
    );

    items.add(const AppMenuSeparator());

    // 5. 复制元数据
    items.add(
      AppMenuAction(
        title: '复制番剧名称',
        icon: Icons.copy_rounded,
        onSelected: () async {
          await Clipboard.setData(ClipboardData(text: title));
          if (context.mounted) {
            KazumiDialog.showToast(message: '已复制番剧名称', context: context);
          }
        },
      ),
    );

    if (bangumiItem.name.isNotEmpty && bangumiItem.name != bangumiItem.nameCn) {
      items.add(
        AppMenuAction(
          title: '复制原名 (${bangumiItem.name})',
          icon: Icons.translate_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: bangumiItem.name));
            if (context.mounted) {
              KazumiDialog.showToast(message: '已复制原名', context: context);
            }
          },
        ),
      );
    }

    items.add(
      AppMenuAction(
        title: '复制 Bangumi ID (${bangumiItem.id})',
        icon: Icons.tag_rounded,
        onSelected: () async {
          await Clipboard.setData(ClipboardData(text: bangumiItem.id.toString()));
          if (context.mounted) {
            KazumiDialog.showToast(message: '已复制 Bangumi ID', context: context);
          }
        },
      ),
    );

    items.add(
      AppMenuAction(
        title: '复制 Bangumi 网页链接',
        icon: Icons.link_rounded,
        onSelected: () async {
          await Clipboard.setData(ClipboardData(text: bgmUrl));
          if (context.mounted) {
            KazumiDialog.showToast(message: '已复制 Bangumi 链接', context: context);
          }
        },
      ),
    );

    items.add(
      AppMenuAction(
        title: '在浏览器中打开 Bangumi 主页',
        icon: Icons.open_in_browser_rounded,
        onSelected: () => Utils.openUrl(bgmUrl),
      ),
    );

    return items;
  }
}
