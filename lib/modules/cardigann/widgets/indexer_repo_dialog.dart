import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';

/// Dialog to manage and synchronize decentralized Cardigann indexer repositories.
class IndexerRepoDialog extends ConsumerStatefulWidget {
  const IndexerRepoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const IndexerRepoDialog(),
    );
  }

  @override
  ConsumerState<IndexerRepoDialog> createState() => _IndexerRepoDialogState();
}

class _IndexerRepoDialogState extends ConsumerState<IndexerRepoDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isAdding = false;
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
      HaipeeDialog.showToast(message: '请输入有效的 http/https 清单地址', context: context);
      return;
    }

    setState(() => _isAdding = true);
    try {
      await ref
          .read(indexerPluginsProvider.notifier)
          .addSubscription(_nameController.text.trim(), url);
      _urlController.clear();
      _nameController.clear();
      if (mounted) {
        HaipeeDialog.showToast(message: '已添加并同步仓库', context: context);
      }
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '添加仓库失败: $e', context: context);
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
      final count = await ref
          .read(indexerPluginsProvider.notifier)
          .syncSubscription(id);
      if (mounted) {
        HaipeeDialog.showToast(message: '同步完成，已更新 $count 个索引器', context: context);
      }
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '同步出错: $e', context: context);
      }
    } finally {
      if (mounted) {
        setState(() => _syncingId = null);
      }
    }
  }

  Future<void> _deleteRepo(String id) async {
    await ref.read(indexerPluginsProvider.notifier).removeSubscription(id);
    if (mounted) {
      HaipeeDialog.showToast(message: '已删除仓库订阅', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(indexerPluginsProvider);
    final subs = state.subscriptions;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.hub_outlined, size: 22),
          SizedBox(width: 8),
          Text('去中心化索引器订阅仓库'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '支持订阅第三方托管的 index.json 索引器仓库清单，自动同步最新的 Cardigann 规则。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Add form
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '仓库名称 (可选)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 7,
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: '清单地址 (index.json)',
                        hintText: 'https://.../index.json',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isAdding ? null : _addRepo,
                    child: _isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 10),

              Text(
                '已订阅仓库 (${subs.length})',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 10),

              if (subs.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '暂无订阅仓库，可通过上方地址添加',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sub = subs[index];
                    final isSyncing = _syncingId == sub.id;

                    return Card.outlined(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          sub.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.manifestUrl,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sub.lastSync != null)
                              Text(
                                '上次同步: ${sub.lastSync!.month}-${sub.lastSync!.day} ${sub.lastSync!.hour}:${sub.lastSync!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: isSyncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 20),
                              tooltip: '立即同步',
                              onPressed: isSyncing ? null : () => _syncRepo(sub.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: '删除订阅',
                              onPressed: () => _deleteRepo(sub.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
