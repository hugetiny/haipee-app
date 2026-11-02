import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/pages/my/my_controller.dart';
import 'package:haipee/pages/my/providers.dart';
import 'package:haipee/pages/info/info_controller.dart';
import 'package:haipee/pages/info/source_search_provider.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/parse_failure_helper.dart';
import 'package:haipee/modules/source_quality/source_quality_tracker.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:logger/logger.dart';

enum SourceSortOption {
  original,
  highestQuality, // 清晰度/码率优先
  fastestResponse, // 响应速度最快
  nameAsc,
  nameDesc,
  failureAsc, // 失败次数升序 (可靠的在前)
  failureDesc, // 失败次数降序 (不可靠的在前)
}

/// Provider for source sort option
final sourceSortOptionProvider = StateProvider.autoDispose<SourceSortOption>(
  (ref) => SourceSortOption.original,
);

class SourceSheet extends ConsumerStatefulWidget {
  const SourceSheet({
    super.key,
    required this.infoController,
  });

  final InfoController infoController;

  @override
  ConsumerState<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends ConsumerState<SourceSheet> {
  late final VideoPageController videoPageController;
  late final CollectController collectController;
  late final String _originalKeyword;

  @override
  void initState() {
    super.initState();
    videoPageController = ref.read(videoProvider.notifier);
    collectController = ref.read(collectionsProvider.notifier);
    final rawName = widget.infoController.bangumiItem.nameCn.isEmpty
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    _originalKeyword = Plugin.cleanKeywordForSearch(rawName);
  }

  bool get _hasAlias => widget.infoController.bangumiItem.alias.isNotEmpty;

  void _showAliasSearchDialog(SourceSearchController searchController) {
    final sheetTexts = context.t.library.info.sourceSheet;
    final aliasTexts = sheetTexts.alias;
    final existingAlias = widget.infoController.bangumiItem.alias;
    if (existingAlias.isEmpty) {
      HaipeeDialog.showToast(message: sheetTexts.toast.aliasEmpty);
      return;
    }

    final aliasNotifier = ValueNotifier<List<String>>(
      List<String>.from(existingAlias),
    );

    HaipeeDialog.show(
      builder: (dialogContext) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 560,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: aliasNotifier,
              builder: (context, aliasList, _) {
                return ListView(
                  shrinkWrap: true,
                  children: aliasList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final alias = entry.value;
                    return ListTile(
                      title: Text(alias),
                      trailing: IconButton(
                        tooltip: aliasTexts.deleteTooltip,
                        onPressed: () {
                          HaipeeDialog.show(
                            builder: (confirmContext) {
                              final confirmTexts =
                                  confirmContext.t.library.info.sourceSheet;
                              final confirmAlias = confirmTexts.alias;
                              return AlertDialog(
                                title: Text(confirmAlias.deleteTitle),
                                content: Text(confirmAlias.deleteMessage),
                                actions: [
                                  TextButton(
                                    onPressed: HaipeeDialog.dismiss,
                                    child: Text(
                                      confirmContext.t.app.cancel,
                                      style: TextStyle(
                                        color: Theme.of(confirmContext)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      HaipeeDialog.dismiss();
                                      final updated = List<String>.from(
                                        widget.infoController.bangumiItem.alias,
                                      )..removeAt(index);
                                      widget.infoController.bangumiItem.alias =
                                          updated;
                                      aliasNotifier.value = List<String>.from(
                                        updated,
                                      );
                                      collectController.updateLocalCollect(
                                        widget.infoController.bangumiItem,
                                      );
                                      if (updated.isEmpty) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    },
                                    child: Text(confirmContext.t.app.confirm),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      onTap: () {
                        HaipeeDialog.dismiss();
                        searchController.searchWithKeyword(alias);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _sortOptionLabel(SourceSortOption option) {
    final options = context.t.library.info.sourceSheet.sort.options;
    switch (option) {
      case SourceSortOption.original:
        return options.original;
      case SourceSortOption.highestQuality:
        return '清晰度/码率最高';
      case SourceSortOption.nameAsc:
        return options.nameAsc;
      case SourceSortOption.nameDesc:
        return options.nameDesc;
      case SourceSortOption.failureAsc:
        return options.failureAsc;
      case SourceSortOption.failureDesc:
        return options.failureDesc;
      case SourceSortOption.fastestResponse:
        return '响应速度最快';
    }
  }

  List<_SourceEntry> _sortedEntries(
    List<_SourceEntry> entries,
    SourceSortOption sortOption,
    Map<String, int> responseTimes,
  ) {
    final bangumiItem = widget.infoController.bangumiItem;

    switch (sortOption) {
      case SourceSortOption.original:
        return entries;
      case SourceSortOption.highestQuality:
        return [...entries]..sort((a, b) {
          final recordA = SourceQualityTracker.getQualityRecord(
                bangumiId: bangumiItem.id,
                pluginName: a.plugin.name,
                src: a.item.src,
              ) ??
              SourceQualityTracker.getBestQualityForPlugin(
                bangumiId: bangumiItem.id,
                pluginName: a.plugin.name,
              );
          final recordB = SourceQualityTracker.getQualityRecord(
                bangumiId: bangumiItem.id,
                pluginName: b.plugin.name,
                src: b.item.src,
              ) ??
              SourceQualityTracker.getBestQualityForPlugin(
                bangumiId: bangumiItem.id,
                pluginName: b.plugin.name,
              );
          final scoreA = recordA?.qualityScore ?? -1.0;
          final scoreB = recordB?.qualityScore ?? -1.0;
          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA); // 降序：高清晰度在前
          }
          // 同画质或均无记录时，按响应时间排序
          final timeA = responseTimes[a.plugin.name] ?? 0;
          final timeB = responseTimes[b.plugin.name] ?? 0;
          if (timeA == 0) return 1;
          if (timeB == 0) return -1;
          return timeA.compareTo(timeB);
        });
      case SourceSortOption.nameAsc:
        return [...entries]..sort((a, b) => a.item.name.compareTo(b.item.name));
      case SourceSortOption.nameDesc:
        return [...entries]..sort((a, b) => b.item.name.compareTo(a.item.name));
      case SourceSortOption.failureAsc:
        // 失败次数升序 (可靠的在前)
        return [...entries]..sort((a, b) {
          final aCount = ParseFailureHelper.getFailureCount(
            bangumiId: bangumiItem.id,
            pluginName: a.plugin.name,
            src: a.item.src,
          );
          final bCount = ParseFailureHelper.getFailureCount(
            bangumiId: bangumiItem.id,
            pluginName: b.plugin.name,
            src: b.item.src,
          );
          return aCount.compareTo(bCount);
        });
      case SourceSortOption.failureDesc:
        // 失败次数降序 (不可靠的在前)
        return [...entries]..sort((a, b) {
          final aCount = ParseFailureHelper.getFailureCount(
            bangumiId: bangumiItem.id,
            pluginName: a.plugin.name,
            src: a.item.src,
          );
          final bCount = ParseFailureHelper.getFailureCount(
            bangumiId: bangumiItem.id,
            pluginName: b.plugin.name,
            src: b.item.src,
          );
          return bCount.compareTo(aCount);
        });
      case SourceSortOption.fastestResponse:
        return [...entries]..sort((a, b) {
          final timeA = responseTimes[a.plugin.name] ?? 0;
          final timeB = responseTimes[b.plugin.name] ?? 0;
          if (timeA == 0) return 1;
          if (timeB == 0) return -1;
          return timeA.compareTo(timeB);
        });
    }
  }

  String _shortenEndpoint(String src) {
    if (src.isEmpty) {
      return src;
    }
    if (src.startsWith('http')) {
      try {
        final uri = Uri.parse(src);
        final buffer = StringBuffer(uri.host);
        if (uri.pathSegments.isNotEmpty) {
          buffer.write('/${uri.pathSegments.first}');
        }
        return buffer.toString();
      } catch (_) {
        return src;
      }
    }
    return src.length > 48 ? '${src.substring(0, 47)}…' : src;
  }

  Future<void> _handleSearchItemTap(
    BuildContext context,
    Plugin plugin,
    SearchItem searchItem,
  ) async {
    final sheetTexts = context.t.library.info.sourceSheet;
    HaipeeDialog.showLoading(
      msg: context.t.app.loading,
      barrierDismissible: Utils.isDesktop(),
      onDismiss: videoPageController.cancelQueryRoads,
    );

    videoPageController.bangumiItem = widget.infoController.bangumiItem;
    videoPageController.title = searchItem.name;
    videoPageController.src = searchItem.src;

    try {
      await videoPageController.queryRoads(searchItem.src, plugin.name);
      HaipeeDialog.dismiss();
      if (!mounted) return;
      if (context.mounted) {
        context.push(Routes.video);
      }
    } catch (error) {
      HaipeeLogger().log(Level.warning, '获取视频播放列表失败: $error');
      HaipeeDialog.dismiss();
      HaipeeDialog.showToast(message: sheetTexts.toast.loadFailed);
    }
  }

  void _showFailureDetails(BuildContext context, Plugin plugin, SearchItem item) {
    final bangumiItem = widget.infoController.bangumiItem;
    final record = ParseFailureHelper.getFailureRecord(
      bangumiId: bangumiItem.id,
      pluginName: plugin.name,
      src: item.src,
    );

    if (record == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        String reasonText;
        switch (record.reason) {
          case 'timeout':
            reasonText = '解析超时 (15秒)';
            break;
          case 'connection_timeout':
            reasonText = '网络连接超时';
            break;
          case 'receive_timeout':
            reasonText = '接收数据超时';
            break;
          case 'cancelled':
            reasonText = '请求被取消';
            break;
          case 'network_error':
            reasonText = '网络错误';
            break;
          default:
            if (record.reason.startsWith('bad_response_')) {
              final code = record.reason.replaceFirst('bad_response_', '');
              reasonText = 'HTTP错误 ($code)';
            } else {
              reasonText = record.reason;
            }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '解析失败详情',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('插件名称', plugin.name, theme),
                const SizedBox(height: 12),
                _buildDetailRow('失败次数', '${record.failureCount} 次', theme),
                const SizedBox(height: 12),
                _buildDetailRow('最后失败', _formatTime(record.lastFailureTime), theme),
                const SizedBox(height: 12),
                _buildDetailRow('失败原因', reasonText, theme),
                const SizedBox(height: 12),
                _buildDetailRow('视频源', item.src, theme, maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚才';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildSourceCard(
    BuildContext context,
    Plugin plugin,
    SearchItem item,
    int responseTime,
  ) {
    final sheetTexts = context.t.library.info.sourceSheet;
    final theme = Theme.of(context);

    // 获取该源的解析失败次数与历史清晰度/码率指标
    final bangumiItem = widget.infoController.bangumiItem;
    final failureCount = ParseFailureHelper.getFailureCount(
      bangumiId: bangumiItem.id,
      pluginName: plugin.name,
      src: item.src,
    );
    final qualityRecord = SourceQualityTracker.getQualityRecord(
          bangumiId: bangumiItem.id,
          pluginName: plugin.name,
          src: item.src,
        ) ??
        SourceQualityTracker.getBestQualityForPlugin(
          bangumiId: bangumiItem.id,
          pluginName: plugin.name,
        );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleSearchItemTap(context, plugin, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sheetTexts.card.title.replaceFirst('{plugin}', plugin.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (qualityRecord != null &&
                      qualityRecord.badgeLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '历史已播清晰度: ${qualityRecord.detailedLabel}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.high_quality_rounded,
                              size: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              qualityRecord.badgeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (responseTime > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${responseTime}ms',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (failureCount > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showFailureDetails(context, plugin, item),
                      borderRadius: BorderRadius.circular(4),
                      child: Tooltip(
                        message: '历史解析失败 $failureCount 次,点击查看详情',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: failureCount >= 3
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: failureCount >= 3
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onTertiaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$failureCount',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: failureCount >= 3
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _shortenEndpoint(item.src),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              if (qualityRecord != null &&
                  qualityRecord.detailedLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.video_camera_back_outlined,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '已播画质: ${qualityRecord.detailedLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _handleSearchItemTap(context, plugin, item),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(sheetTexts.card.play),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    final sortTexts = context.t.library.info.sourceSheet.sort;
    final sortOption = ref.watch(sourceSortOptionProvider);

    return IconButton(
      tooltip: sortTexts.tooltip
          .replaceFirst('{label}', _sortOptionLabel(sortOption)),
      icon: const Icon(Icons.sort_rounded),
      onPressed: () => _showSortDialog(),
    );
  }

  void _showSortDialog() {
    final sortTexts = context.t.library.info.sourceSheet.sort;
    final sortOption = ref.read(sourceSortOptionProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      sortTexts.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              ...SourceSortOption.values.map((option) {
                final selected = option == sortOption;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(_sortOptionLabel(option)),
                  selected: selected,
                  onTap: () {
                    ref.read(sourceSortOptionProvider.notifier).state = option;
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ({
    List<_SourceEntry> entries,
    List<Plugin> pending,
    List<Plugin> errors,
    List<Plugin> empty,
  }) _aggregateResults(
    List<Plugin> plugins,
    SourceSearchState searchState,
  ) {
    final entries = <_SourceEntry>[];
    final pending = <Plugin>[];
    final errors = <Plugin>[];
    final empty = <Plugin>[];

    for (final plugin in plugins) {
      final status =
          searchState.statuses[plugin.name] ?? PluginSearchStatus.pending;
      final results = searchState.results[plugin.name] ?? const <SearchItem>[];
      switch (status) {
        case PluginSearchStatus.pending:
          pending.add(plugin);
          break;
        case PluginSearchStatus.error:
          errors.add(plugin);
          break;
        case PluginSearchStatus.success:
          if (results.isEmpty) {
            empty.add(plugin);
          } else {
            for (final item in results) {
              entries.add(_SourceEntry(plugin, item));
            }
          }
          break;
      }
    }

    return (
      entries: entries,
      pending: pending,
      errors: errors,
      empty: empty,
    );
  }

  List<Widget> _buildStatusCards({
    required List<Plugin> plugins,
    required SourceSearchState searchState,
    required SourceSearchController controller,
  }) {
    final sheetTexts = context.t.library.info.sourceSheet;
    final statusTexts = sheetTexts.status;
    final actions = sheetTexts.actions;
    final widgets = <Widget>[];

    // Maintain a stable, fixed order by plugin list to prevent cards from jumping or swapping positions on retry
    for (final plugin in plugins) {
      final status =
          searchState.statuses[plugin.name] ?? PluginSearchStatus.pending;
      final results = searchState.results[plugin.name] ?? const <SearchItem>[];

      // If plugin already succeeded with items, its items are presented in the results grid below
      if (status == PluginSearchStatus.success && results.isNotEmpty) {
        continue;
      }

      Widget leading;
      Widget? trailing;
      String titleText;
      String? errorReason;

      switch (status) {
        case PluginSearchStatus.pending:
          leading = const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
          titleText =
              statusTexts.searching.replaceFirst('{plugin}', plugin.name);
          trailing = null;
          break;

        case PluginSearchStatus.error:
          leading = Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          );
          titleText =
              statusTexts.failed.replaceFirst('{plugin}', plugin.name);
          errorReason = searchState.errors[plugin.name];
          trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: context.t.app.retry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.queryPlugin(plugin.name),
              ),
              IconButton(
                tooltip: actions.removeSource,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmRemoveSource(plugin),
              ),
            ],
          );
          break;

        case PluginSearchStatus.success:
          leading = Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.outline,
          );
          titleText =
              statusTexts.empty.replaceFirst('{plugin}', plugin.name);
          trailing = IconButton(
            tooltip: context.t.app.retry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () => controller.queryPlugin(plugin.name),
          );
          break;
      }

      widgets.add(
        Card(
          key: ValueKey('plugin_status_card_${plugin.name}'),
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        softWrap: true,
                      ),
                      if (errorReason != null && errorReason.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          errorReason,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _confirmRemoveSource(Plugin plugin) {
    HaipeeDialog.show(
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dialogTexts = dialogContext.t.library.info.sourceSheet.dialog;
        return AlertDialog(
          title: Text(dialogTexts.removeTitle),
          content: Text(
            dialogTexts.removeMessage.replaceFirst('{plugin}', plugin.name),
          ),
          actions: [
            TextButton(
              onPressed: HaipeeDialog.dismiss,
              child: Text(
                dialogContext.t.app.cancel,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                HaipeeDialog.dismiss();
                await ref.read(pluginsProvider.notifier).removePlugin(plugin);
                if (dialogContext.mounted) {
                  HaipeeDialog.showToast(
                    message: dialogContext
                        .t.library.info.sourceSheet.toast.removed
                        .replaceFirst('{plugin}', plugin.name),
                  );
                }
              },
              child: Text(dialogContext.t.app.delete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pluginState = ref.watch(pluginsProvider);
    final plugins = pluginState.pluginList;

    if (plugins.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final searchState = ref.watch(sourceSearchProvider(_originalKeyword));
    final searchController =
        ref.read(sourceSearchProvider(_originalKeyword).notifier);
    final sortOption = ref.watch(sourceSortOptionProvider);

    final aggregation = _aggregateResults(plugins, searchState);
    final sortedEntries = _sortedEntries(
      aggregation.entries,
      sortOption,
      searchState.responseTimes,
    );
    final statusCards = _buildStatusCards(
      plugins: plugins,
      searchState: searchState,
      controller: searchController,
    );

    final bangumiName = widget.infoController.bangumiItem.nameCn.isEmpty
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;

    final sheetTexts = context.t.library.info.sourceSheet;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    searchController.searchWithKeyword(_originalKeyword),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(sheetTexts.actions.searchAgain),
              ),
              OutlinedButton.icon(
                onPressed: _hasAlias
                    ? () => _showAliasSearchDialog(searchController)
                    : null,
                icon: const Icon(Icons.badge_outlined),
                label: Text(sheetTexts.actions.aliasSearch),
              ),
            ],
          ),
        ),
      ),
    ];

    if (statusCards.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(statusCards),
          ),
        ),
      );
    }

    if (sortedEntries.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minTileWidth = 280.0;
                const spacing = 16.0;
                final maxWidth = constraints.maxWidth;
                var crossAxisCount =
                    ((maxWidth + spacing) / (minTileWidth + spacing)).floor();
                crossAxisCount = math.max(1, crossAxisCount);
                final totalSpacing = spacing * (crossAxisCount - 1);
                final itemWidth = (maxWidth - totalSpacing) / crossAxisCount;

                return Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final entry in sortedEntries)
                        SizedBox(
                          width: itemWidth,
                          child: _buildSourceCard(
                            context,
                            entry.plugin,
                            entry.item,
                            searchState.responseTimes[entry.plugin.name] ?? 0,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else if (statusCards.isEmpty && aggregation.pending.isNotEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              Text(sheetTexts.empty.searching),
            ],
          ),
        ),
      );
    } else if (statusCards.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              sheetTexts.empty.noResults,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (aggregation.pending.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                sheetTexts.empty.noResults,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: SysAppBar(
        title: Text(
          sheetTexts.title.replaceFirst('{name}', bangumiName),
        ),
        actions: [
          _buildSortButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: slivers,
      ),
    );
  }
}

class _SourceEntry {
  const _SourceEntry(this.plugin, this.item);

  final Plugin plugin;
  final SearchItem item;
}
