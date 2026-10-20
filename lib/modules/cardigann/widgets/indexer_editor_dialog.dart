import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';
import 'package:kazumi/modules/cardigann/models/indexer_plugin.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';

/// Dialog to view, edit, test, and save Cardigann YAML definition.
class IndexerEditorDialog extends ConsumerStatefulWidget {
  final IndexerPlugin plugin;

  const IndexerEditorDialog({
    super.key,
    required this.plugin,
  });

  static Future<void> show(BuildContext context, IndexerPlugin plugin) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IndexerEditorDialog(plugin: plugin),
    );
  }

  @override
  ConsumerState<IndexerEditorDialog> createState() =>
      _IndexerEditorDialogState();
}

class _IndexerEditorDialogState extends ConsumerState<IndexerEditorDialog> {
  late final TextEditingController _yamlController;
  final TextEditingController _testKeywordController =
      TextEditingController(text: '1080p');

  bool _isSaving = false;
  bool _isTesting = false;
  String? _saveError;
  String? _testMessage;
  bool _testSuccess = false;
  List<TorrentItem> _testResults = [];

  @override
  void initState() {
    super.initState();
    _yamlController = TextEditingController(text: widget.plugin.rawYaml);
  }

  @override
  void dispose() {
    _yamlController.dispose();
    _testKeywordController.dispose();
    super.dispose();
  }

  Future<void> _runDryRunTest() async {
    final keyword = _testKeywordController.text.trim();
    final yaml = _yamlController.text.trim();

    if (yaml.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = 'YAML 内容不能为空';
        _testResults = [];
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testResults = [];
    });

    final stopwatch = Stopwatch()..start();
    try {
      final definition = CardigannParser.parseYaml(yaml);
      final executor = CardigannQueryExecutor();
      final results = await executor.search(
        definition,
        keyword.isEmpty ? '1080p' : keyword,
        userConfig: widget.plugin.settings,
        customBaseUrl: widget.plugin.customBaseUrl,
        throwOnError: true,
      );
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResults = results;
          _testMessage =
              '测试抓取成功！耗时 ${stopwatch.elapsedMilliseconds}ms，获取到 ${results.length} 条资源';
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResults = [];
          _testMessage = '测试抓取失败 (${stopwatch.elapsedMilliseconds}ms): $e';
        });
      }
    }
  }

  Future<void> _save() async {
    final text = _yamlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _saveError = 'YAML 内容不能为空';
      });
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _saveError = null;
      });

      await ref
          .read(indexerPluginsProvider.notifier)
          .addOrUpdatePlugin(text, settings: widget.plugin.settings);

      if (mounted) {
        Navigator.of(context).pop();
        KazumiDialog.showToast(
          message: '已成功保存规则: ${widget.plugin.name}',
          context: context,
        );
      }
    } catch (e) {
      setState(() {
        _saveError = '解析或保存失败: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _resetToBuiltIn() async {
    KazumiDialog.show(
      builder: (ctx) => AlertDialog(
        title: const Text('恢复官方预置规则'),
        content: Text(
          '确定要将 "${widget.plugin.name}" 恢复为官方打包的初始预置版本吗？您的所有自定义修改将被重置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(indexerPluginsProvider.notifier)
                  .resetPlugin(widget.plugin.id);
              final original = IndexerPluginsNotifier.getOriginalBundledYaml(
                widget.plugin.id,
              );
              if (original != null && mounted) {
                setState(() {
                  _yamlController.text = original;
                  _saveError = null;
                  _testMessage = null;
                  _testResults = [];
                });
              }
              if (mounted) {
                KazumiDialog.showToast(
                  message: '已恢复官方预置规则',
                  context: context,
                );
              }
            },
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyYaml() async {
    await Clipboard.setData(ClipboardData(text: _yamlController.text));
    if (mounted) {
      KazumiDialog.showToast(message: '已复制 YAML 至剪贴板', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBundled = widget.plugin.isBundled;
    final isOverridden = IndexerPluginsNotifier.isPluginOverridden(
      widget.plugin.id,
      _yamlController.text,
    );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      title: Row(
        children: [
          const Icon(Icons.code_rounded, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '编辑规则: ${widget.plugin.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBundled
                        ? (isOverridden
                            ? Colors.amber.withAlpha(40)
                            : Colors.teal.withAlpha(40))
                        : Colors.indigo.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBundled
                        ? (isOverridden ? '已覆写内置' : '官方内置')
                        : '自定义规则',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBundled
                          ? (isOverridden
                              ? Colors.amber.shade800
                              : Colors.teal.shade700)
                          : Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制 YAML',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: _copyYaml,
          ),
          if (isBundled && isOverridden)
            IconButton(
              tooltip: '恢复官方预置',
              icon: const Icon(Icons.restore, size: 18, color: Colors.amber),
              onPressed: _resetToBuiltIn,
            ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '可以直接调整选择器、链接、过滤规则。支持测试解析，修改后点击“保存修改”即时生效。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _yamlController,
                maxLines: 15,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _saveError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Dry-run testing panel
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '实时测试抓取 (Dry-Run)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 140,
                          height: 32,
                          child: TextField(
                            controller: _testKeywordController,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: '测试词 (默认 1080p)',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _isTesting ? null : _runDryRunTest,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5),
                                )
                              : const Icon(Icons.play_arrow, size: 16),
                          label: Text(_isTesting ? '抓取中...' : '测试抓取'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    if (_testMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testSuccess
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 16,
                            color: _testSuccess
                                ? Colors.green.shade700
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _testSuccess
                                    ? Colors.green.shade800
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_testResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '结果预览 (前 ${_testResults.take(3).length} 条):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._testResults.take(3).map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.fileSize,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '做种: ${item.seeders}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存修改'),
        ),
      ],
    );
  }
}
