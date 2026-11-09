import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/sources/torrent_dio_factory.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/services/logging/app_log.dart';

/// Dialog to import Cardigann YAML definition from local file, clipboard, remote URL, or text entry,
/// with instant dry-run testing and conflict override detection.
class IndexerImportDialog extends ConsumerStatefulWidget {
  const IndexerImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const IndexerImportDialog(),
    );
  }

  @override
  ConsumerState<IndexerImportDialog> createState() =>
      _IndexerImportDialogState();
}

class _IndexerImportDialogState extends ConsumerState<IndexerImportDialog> {
  final TextEditingController _yamlController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _testKeywordController =
      TextEditingController(text: '1080p');

  bool _isLoading = false;
  bool _isFetchingUrl = false;
  bool _isTesting = false;
  String? _error;
  String? _testMessage;
  bool _testSuccess = false;
  List<TorrentItem> _testResults = [];

  @override
  void dispose() {
    _yamlController.dispose();
    _urlController.dispose();
    _testKeywordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (AppLog.isFirebaseTestLab) {
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yml', 'yaml'],
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final file = File(path);
          final content = await file.readAsString();
          setState(() {
            _yamlController.text = content;
            _error = null;
            _testMessage = null;
            _testResults = [];
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = '读取文件失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _yamlController.text = data.text!;
        _error = null;
        _testMessage = null;
        _testResults = [];
      });
    }
  }

  Future<void> _fetchFromUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _error = '请输入远程 YAML 的完整 URL 地址';
      });
      return;
    }

    try {
      setState(() {
        _isFetchingUrl = true;
        _error = null;
      });

      final dio = TorrentDioFactory.create(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)',
        },
      );
      dio.interceptors.add(GitProxyInterceptor());

      final response = await dio.get<String>(rawUrl);
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data!.isNotEmpty) {
        setState(() {
          _yamlController.text = response.data!;
          _isFetchingUrl = false;
          _error = null;
          _testMessage = null;
          _testResults = [];
        });
        if (mounted) {
          HaipeeDialog.showToast(message: '已成功从远程拉取规则内容', context: context);
        }
      } else {
        setState(() {
          _error = '拉取失败 (HTTP ${response.statusCode})';
          _isFetchingUrl = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '远程拉取失败: $e';
        _isFetchingUrl = false;
      });
    }
  }

  Future<void> _runDryRunTest() async {
    final keyword = _testKeywordController.text.trim();
    final yaml = _yamlController.text.trim();

    if (yaml.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testMessage = '请先输入或选择 YAML 内容后再进行测试';
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

  Future<void> _import() async {
    final text = _yamlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = '请输入或选择 Cardigann YAML 内容';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final plugin = await ref
          .read(indexerPluginsProvider.notifier)
          .addOrUpdatePlugin(text);

      if (mounted) {
        Navigator.of(context).pop();
        HaipeeDialog.showToast(
          message: '已成功导入索引器: ${plugin?.name ?? ''}',
          context: context,
        );
      }
    } catch (e) {
      setState(() {
        _error = '解析或保存失败: $e';
        _isLoading = false;
      });
    }
  }

  CardigannDefinition? _tryParseCurrentYaml() {
    final text = _yamlController.text.trim();
    if (text.isEmpty) return null;
    try {
      return CardigannParser.parseYaml(text);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsedDef = _tryParseCurrentYaml();
    final existingPlugins = ref.watch(indexerPluginsProvider).plugins;
    final isBundled =
        parsedDef != null && IndexerPluginsNotifier.isBundledId(parsedDef.id);
    final existsInUser =
        parsedDef != null && existingPlugins.any((p) => p.id == parsedDef.id);

    return AdaptiveDialogFrame(
      maxWidth: 720,
      title: const Row(
        children: [
          Icon(Icons.file_download_outlined, size: 22),
          SizedBox(width: 8),
          Text('导入 Cardigann 索引器规则'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Text(
                '支持通过本地文件、剪贴板或远程 URL 直接导入 100% 官方 Cardigann 规范规则。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // Multi-channel ingestion controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('选择本地 .yml 文件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pasteClipboard,
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('从剪贴板粘贴'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Remote URL fetch input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '输入远程规则直链 (如 GitHub raw / Gitee / CDN URL)',
                        prefixIcon: Icon(Icons.link, size: 18),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed:
                        _isFetchingUrl || _isLoading ? null : _fetchFromUrl,
                    icon: _isFetchingUrl
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 16),
                    label: Text(_isFetchingUrl ? '拉取中' : '远程拉取'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // YAML editor
              TextField(
                controller: _yamlController,
                maxLines: 12,
                onChanged: (_) {
                  setState(() {});
                },
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: '--- \nid: nyaasi\nname: Nyaa.si\n...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                ),
              ),
              if (parsedDef != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '已识别: ${parsedDef.name} (${parsedDef.id})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isBundled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚠️ 将覆写官方内置规则',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      )
                    else if (existsInUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ℹ️ 将更新现有规则',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '✨ 全新规则',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
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
                        '抓取预览 (前 ${_testResults.take(3).length} 条):',
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _import,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认导入'),
        ),
      ],
    );
  }
}
