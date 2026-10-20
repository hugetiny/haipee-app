import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins_providers.dart';

/// 统一在线视频规则源订阅对话框 (对标 IndexerRepoDialog)
/// 支持管理远程规则仓库、一键拉取并批量导入全套主流 Web 视频规则
class PluginSubscriptionDialog extends ConsumerStatefulWidget {
  const PluginSubscriptionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PluginSubscriptionDialog(),
    );
  }

  @override
  ConsumerState<PluginSubscriptionDialog> createState() =>
      _PluginSubscriptionDialogState();
}

class _PluginSubscriptionDialogState
    extends ConsumerState<PluginSubscriptionDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isAdding = false;
  bool _isSyncingAll = false;
  String? _syncingId;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addRepo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      KazumiDialog.showToast(message: '请输入有效的 http/https 规则订阅地址');
      return;
    }

    setState(() => _isAdding = true);
    try {
      final controller = ref.read(pluginsProvider.notifier);
      await controller.addSubscription(
        _nameController.text.trim(),
        url,
        syncImmediately: true,
      );
      _urlController.clear();
      _nameController.clear();
      if (mounted) {
        KazumiDialog.showToast(message: '已成功添加并同步视频规则订阅');
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '添加订阅失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _syncRepo(String id) async {
    setState(() => _syncingId = id);
    try {
      final count =
          await ref.read(pluginsProvider.notifier).syncSubscription(id);
      if (mounted) {
        KazumiDialog.showToast(message: '同步完成，已批量导入/更新 $count 个视频规则');
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '同步订阅失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _syncingId = null);
      }
    }
  }

  Future<void> _syncAll() async {
    setState(() => _isSyncingAll = true);
    try {
      final count =
          await ref.read(pluginsProvider.notifier).syncAllSubscriptions();
      if (mounted) {
        KazumiDialog.showToast(message: '全部订阅同步完成，已更新 $count 个视频规则');
      }
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '同步订阅失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingAll = false);
      }
    }
  }

  Future<void> _deleteRepo(String id) async {
    await ref.read(pluginsProvider.notifier).removeSubscription(id);
    if (mounted) {
      KazumiDialog.showToast(message: '已删除订阅源');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(pluginsProvider);
    final subs = state.subscriptions;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.rss_feed_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '在线视频规则源订阅',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '配置远程规则清单 (index.json / rules.yaml)，支持一键拉取并批量导入',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
          if (subs.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: _isSyncingAll ? null : _syncAll,
              icon: _isSyncingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(_isSyncingAll ? '同步中...' : '全部同步'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: SizedBox(
        width: 640,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 添加新订阅行
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withAlpha(80),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '添加新订阅源',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 160,
                          height: 38,
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: '订阅名称 (选填)',
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant.withAlpha(100),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: '订阅链接 (如 https://.../index.json 或 rules.yaml)',
                                prefixIcon: const Icon(Icons.link, size: 16),
                                filled: true,
                                fillColor: colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colorScheme.outlineVariant.withAlpha(100),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isAdding ? null : _addRepo,
                          icon: _isAdding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add, size: 16),
                          label: Text(_isAdding ? '添加中...' : '添加并同步'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 已订阅源列表
            Expanded(
              child: subs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 48,
                            color: colorScheme.outline.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无在线规则订阅源',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.outline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '可从网络或社区添加 index.json / rules.yaml 订阅地址，一键批量加载影视规则',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: subs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final sub = subs[index];
                        final isSyncing = _syncingId == sub.id;
                        final syncTimeStr = sub.lastSync != null
                            ? '${sub.lastSync!.month}-${sub.lastSync!.day} ${sub.lastSync!.hour.toString().padLeft(2, '0')}:${sub.lastSync!.minute.toString().padLeft(2, '0')}'
                            : '从未同步';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: colorScheme.outlineVariant.withAlpha(60),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.language,
                                size: 18,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sub.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${sub.pluginCount} 条规则',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub.url,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '上次同步: $syncTimeStr',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.outline.withAlpha(160),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '立即同步该源',
                                  icon: isSyncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.sync, size: 18),
                                  onPressed: isSyncing ? null : () => _syncRepo(sub.id),
                                ),
                                IconButton(
                                  tooltip: '删除订阅',
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _deleteRepo(sub.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
