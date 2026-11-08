import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/widget/image/rule_cover_image.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';

/// 视频源规则实时试抓测试对话框 (Dry-Run Test Dialog)
/// 对齐 Cardigann 规则设置中的 _DryRunTestDialog，支持实时请求、耗时统计与解析结果展示
class PluginDryRunDialog extends ConsumerStatefulWidget {
  final Plugin plugin;

  const PluginDryRunDialog({
    super.key,
    required this.plugin,
  });

  static Future<void> show(BuildContext context, Plugin plugin) {
    return showDialog(
      context: context,
      builder: (context) => PluginDryRunDialog(plugin: plugin),
    );
  }

  @override
  ConsumerState<PluginDryRunDialog> createState() => _PluginDryRunDialogState();
}

class _PluginDryRunDialogState extends ConsumerState<PluginDryRunDialog> {
  late final TextEditingController _keywordController;
  bool _isTesting = false;
  String? _errorMsg;
  List<SearchItem>? _testResults;
  int? _elapsedMs;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: '海贼王');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _doTest();
      }
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _doTest() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _errorMsg = null;
      _testResults = null;
      _elapsedMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final keyword = _keywordController.text.trim();
      final response = await widget.plugin.queryBangumi(
        keyword.isEmpty ? '海贼王' : keyword,
        shouldRethrow: true,
      );
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResults = response.data;
          _elapsedMs = stopwatch.elapsedMilliseconds;
        });

        final controller = ref.read(pluginsProvider.notifier);
        if (response.data.isNotEmpty) {
          controller.validityTracker.markValid(
            widget.plugin.name,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
          controller.togglePluginEnabled(widget.plugin.name, true);
        } else {
          controller.validityTracker.markInvalid(
            widget.plugin.name,
            error: '搜索返回 0 项结果',
            latencyMs: stopwatch.elapsedMilliseconds,
          );
          controller.togglePluginEnabled(widget.plugin.name, false);
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _errorMsg = e.toString();
          _elapsedMs = stopwatch.elapsedMilliseconds;
        });
        final controller = ref.read(pluginsProvider.notifier);
        controller.validityTracker.markInvalid(
          widget.plugin.name,
          error: e.toString(),
          latencyMs: stopwatch.elapsedMilliseconds,
        );
        controller.togglePluginEnabled(widget.plugin.name, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              Icons.play_circle_outline_rounded,
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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '测试抓取: ${widget.plugin.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SettingsBadge(
                      label: 'v${widget.plugin.version}',
                      color: colorScheme.surfaceContainerHighest,
                      textColor: colorScheme.outline,
                    ),
                    SettingsBadge(
                      label: widget.plugin.type.toUpperCase(),
                      color: colorScheme.primary.withAlpha(25),
                      textColor: colorScheme.primary,
                    ),
                  ],
                ),
                if (widget.plugin.baseUrl.isNotEmpty)
                  Text(
                    widget.plugin.baseUrl,
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SizedBox(
          width: 640,
          height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索关键字输入与立即测试按钮
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: '输入测试搜索关键词 (如 海贼王, 柯南, 咒术回战...)',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withAlpha(120),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onSubmitted: (_) => _doTest(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isTesting ? null : _doTest,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined, size: 16),
                  label: Text(_isTesting ? '正在抓取' : '立即测试'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 抓取状态及耗时横幅
            if (_isTesting)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('正在向视频源发送请求并解析数据，请稍候…'),
                  ],
                ),
              )
            else if (_errorMsg != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withAlpha(100),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '解析/请求失败 (耗时 ${_elapsedMs ?? 0}ms)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _errorMsg!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_testResults != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _testResults!.isEmpty
                      ? Colors.amber.withAlpha(25)
                      : Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResults!.isEmpty
                        ? Colors.amber.withAlpha(100)
                        : Colors.green.withAlpha(100),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResults!.isEmpty
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _testResults!.isEmpty ? Colors.amber : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResults!.isEmpty
                            ? '请求完成 (耗时 ${_elapsedMs ?? 0}ms)，但未匹配到搜索结果，建议更换关键词'
                            : '抓取成功！耗时 ${_elapsedMs ?? 0}ms，成功解析出 ${_testResults!.length} 条资源 (含封面 ${_testResults!.where((e) => e.pic.isNotEmpty).length} 条)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _testResults!.isEmpty ? Colors.amber.shade800 : Colors.green,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // 结果列表
            Expanded(
              child: _testResults == null || _testResults!.isEmpty
                  ? Center(
                      child: Text(
                        _isTesting
                            ? '正在请求...'
                            : (_errorMsg != null ? '解析遇到错误' : '无返回数据或尚未测试'),
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _testResults!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _testResults![index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 40,
                              height: 52,
                              child: RuleCoverImage(
                                imageUrl: item.pic,
                                iconSize: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.src.isNotEmpty)
                                Text(
                                  '地址: ${item.src}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                item.pic.isNotEmpty
                                    ? '封面: ${item.pic}'
                                    : '封面: 未提取到 (将使用跨源协同兜底)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: item.pic.isNotEmpty
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: SettingsBadge(
                            label: widget.plugin.type.toUpperCase(),
                            color: colorScheme.surfaceContainerHighest,
                            textColor: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
