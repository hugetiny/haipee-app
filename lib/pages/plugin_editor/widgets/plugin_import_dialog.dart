import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/pages/plugin_editor/widgets/plugin_dry_run_dialog.dart';
import 'package:haipee/pages/plugin_editor/widgets/plugin_subscription_dialog.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/services/logging/app_log.dart';

/// 统一的视频源插件规则导入对话框 (支持单条及批量导入)
/// 支持多选本地文件、剪贴板粘贴多条 JSON/YAML 规则、从远程 URL / 订阅源拉取
class PluginImportDialog extends ConsumerStatefulWidget {
  const PluginImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PluginImportDialog(),
    );
  }

  @override
  ConsumerState<PluginImportDialog> createState() => _PluginImportDialogState();
}

class _PluginImportDialogState extends ConsumerState<PluginImportDialog> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingUrl = false;
  String? _parseError;
  List<Plugin> _parsedPlugins = [];

  Plugin? get _singlePlugin =>
      _parsedPlugins.length == 1 ? _parsedPlugins.first : null;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedPlugins = [];
        _parseError = null;
      });
      return;
    }

    try {
      final list = Plugin.parseMany(text);
      if (list.isNotEmpty) {
        setState(() {
          _parsedPlugins = list;
          _parseError = null;
        });
      } else {
        setState(() {
          _parsedPlugins = [];
          _parseError = '未能识别为有效的 JSON 或 YAML 规则或规则缺少 name 字段';
        });
      }
    } catch (e) {
      setState(() {
        _parsedPlugins = [];
        _parseError = e.toString();
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      HaipeeDialog.showToast(message: '剪贴板为空');
      return;
    }
    _contentController.text = text;
  }

  Future<void> _pickFile() async {
    if (AppLog.isFirebaseTestLab) {
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _parseError = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'yaml', 'yml'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<Plugin> pickedList = [];
        final StringBuffer buffer = StringBuffer();

        for (final f in result.files) {
          if (f.path != null) {
            try {
              final content = await File(f.path!).readAsString();
              final list = Plugin.parseMany(content);
              pickedList.addAll(list);
              if (pickedList.length <= 1) {
                buffer.writeln(content);
              }
            } catch (_) {}
          }
        }

        if (pickedList.isNotEmpty) {
          setState(() {
            _parsedPlugins = pickedList;
            _parseError = null;
            if (pickedList.length > 1) {
              _contentController.text =
                  '// 已选择 ${result.files.length} 个文件，共包含 ${pickedList.length} 条有效规则：\n// ${pickedList.map((p) => p.name).join(', ')}';
            }
          });
          if (mounted) {
            HaipeeDialog.showToast(
                message: '已成功从文件读取 ${pickedList.length} 条规则');
          }
        } else {
          setState(() => _parseError = '所选文件中未解析出有效规则');
        }
      }
    } catch (e) {
      setState(() => _parseError = '选择文件失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      HaipeeDialog.showToast(message: '请输入有效的规则 URL');
      return;
    }

    setState(() {
      _isFetchingUrl = true;
      _parseError = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Haipee/Importer',
          },
        ),
      );
      dio.interceptors.add(GitProxyInterceptor());
      final resp = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final body = resp.data?.trim();
      if (body != null && body.isNotEmpty) {
        _contentController.text = body;
      } else {
        throw Exception('远程文件内容为空');
      }
    } catch (e) {
      setState(() => _parseError = '从 URL 获取规则失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingUrl = false);
      }
    }
  }

  Future<void> _doImport() async {
    if (_parsedPlugins.isEmpty) return;
    final controller = ref.read(pluginsProvider.notifier);

    if (_parsedPlugins.length == 1) {
      final p = _parsedPlugins.first;
      controller.updatePlugin(p);
      controller.togglePluginEnabled(p.name, true);
      HaipeeDialog.showToast(message: '成功导入规则: ${p.name}');
    } else {
      final count =
          await controller.addOrUpdatePlugins(_parsedPlugins, enableAll: true);
      HaipeeDialog.showToast(message: '已成功批量导入 $count 条视频规则');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allPlugins = ref.watch(pluginsProvider).pluginList;

    final singlePlugin = _singlePlugin;
    final hasSingleConflict = singlePlugin != null &&
        allPlugins.any((p) => p.name == singlePlugin.name);

    return AdaptiveDialogFrame(
      maxWidth: 700,
      maxHeight: 620,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.file_upload_outlined,
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
                  '导入 Haipee 视频规则',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '支持多选本地 .yaml/.json 文件、粘贴规则数组或远程链接批量导入',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              PluginSubscriptionDialog.show(context);
            },
            icon: const Icon(Icons.rss_feed_rounded, size: 16),
            label: const Text('在线规则订阅'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快速操作工具行
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('从剪贴板粘贴 (支持数组)'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('批量选择本地 .json / .yaml 文件'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 远程 URL 快速获取
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: '输入远程规则/清单链接 (如 https://example.com/rules.yaml 或 index.json)',
                          prefixIcon: const Icon(Icons.link, size: 16),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _isFetchingUrl ? null : _fetchUrl,
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(_isFetchingUrl ? '获取中...' : '抓取'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 源码输入与编辑区域
              Text(
                '规则数据 / JSON / YAML 源码 (单条或数组均可):',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 140,
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: '在此粘贴 Haipee 分享口令、JSON/YAML 单条或数组规则...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _parseError != null
                            ? colorScheme.error
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 错误提示
              if (_parseError != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '规则解析错误: $_parseError',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. 单条规则预览卡片
              if (singlePlugin != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasSingleConflict
                          ? Colors.amber.withAlpha(120)
                          : colorScheme.primary.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: hasSingleConflict ? Colors.amber : Colors.green,
                          ),
                          Text(
                            singlePlugin.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SettingsBadge(
                            label: 'v${singlePlugin.version}',
                          ),
                          SettingsBadge(
                            label: singlePlugin.isMacCms ? 'MACCMS' : singlePlugin.type.toUpperCase(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hasSingleConflict)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '已安装同名规则，确认导入将覆写现有版本',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (singlePlugin.baseUrl.isNotEmpty)
                        Text(
                          '基准地址: ${singlePlugin.baseUrl}',
                          style: TextStyle(fontSize: 11, color: colorScheme.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => PluginDryRunDialog.show(context, singlePlugin),
                            icon: const Icon(Icons.play_arrow_outlined, size: 14),
                            label: const Text('导入前先试抓测试 (Dry-Run)', style: TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 2. 批量规则解析成功多卡片预览
              if (_parsedPlugins.length > 1)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.library_add_check, size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            '已成功解析 ${_parsedPlugins.length} 条视频规则:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _parsedPlugins.map((p) {
                          final exists = allPlugins.any((it) => it.name == p.name);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withAlpha(120),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: exists
                                    ? Colors.amber.withAlpha(100)
                                    : colorScheme.outlineVariant.withAlpha(60),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  exists ? Icons.update : Icons.add_circle_outline,
                                  size: 14,
                                  color: exists ? Colors.amber : colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.isMacCms ? 'MACCMS' : p.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                if (exists) ...[
                                  const SizedBox(width: 4),
                                  const Text(
                                    '(更新)',
                                    style: TextStyle(fontSize: 10, color: Colors.amber),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _parsedPlugins.isEmpty ? null : _doImport,
          icon: const Icon(Icons.check, size: 16),
          label: Text(
            _parsedPlugins.length > 1
                ? '批量导入全部规则 (${_parsedPlugins.length} 条)'
                : '确认导入规则',
          ),
        ),
      ],
    );
  }
}
