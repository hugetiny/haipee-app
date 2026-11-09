import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

/// GitHub 加速代理底层配置弹窗
///
/// 功能：
/// 1. 独立开启/关闭 GitHub 网络代理；
/// 2. 自定义输入任意可用的反代服务器地址；
/// 3. 提供主流高可用公共镜像一键切换 (ghfast.top, ghproxy.net, mirror.ghproxy.com, gh-proxy.com)；
/// 4. 实时测试连通性与网络往返延迟 (RTT)；
/// 5. 恢复默认官方镜像源。
class GitProxyDialog extends ConsumerStatefulWidget {
  const GitProxyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const GitProxyDialog(),
    );
  }

  @override
  ConsumerState<GitProxyDialog> createState() => _GitProxyDialogState();
}

class _GitProxyDialogState extends ConsumerState<GitProxyDialog> {
  late bool _enabled;
  late TextEditingController _urlController;
  bool _isTesting = false;
  (bool success, int latencyMs, String message)? _testResult;

  @override
  void initState() {
    super.initState();
    final proxyConfig = ref.read(gitProxyProvider);
    _enabled = proxyConfig.enabled;
    _urlController = TextEditingController(text: proxyConfig.proxyUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testLatency() async {
    final target = _urlController.text.trim();
    if (target.isEmpty) {
      setState(() {
        _testResult = (false, 0, '请先输入有效的代理地址');
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await GitProxyInterceptor.testLatency(
      targetProxyUrl: target,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    }
  }

  Future<void> _save() async {
    final rawUrl = _urlController.text.trim();
    if (_enabled && rawUrl.isEmpty) {
      setState(() {
        _testResult = (false, 0, '启用代理时代理地址不能为空');
      });
      return;
    }

    await ref.read(gitProxyProvider.notifier).updateConfig(
          enabled: _enabled,
          proxyUrl: rawUrl.isNotEmpty ? rawUrl : GitProxyInterceptor.defaultProxyUrl,
        );

    if (mounted) {
      Navigator.of(context).pop();
      HaipeeDialog.showToast(
        message: 'GitHub 加速代理设置已更新',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AdaptiveDialogFrame(
      maxWidth: 580,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.alt_route_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GitHub 加速代理设置',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '底层自动重写 Haipee 视频规则、Cardigann 规则、Tracker 与更新下载',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Enable Toggle Card
              Material(
                color: colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _enabled
                          ? colorScheme.primary.withAlpha(80)
                          : colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    value: _enabled,
                    onChanged: (val) {
                      setState(() {
                        _enabled = val;
                      });
                    },
                    title: const Text(
                      '启用 GitHub 网络代理',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      '开启后，所有通过 GitHub 检索的规则文件及下载请求将自动通过代理加速',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

              // Expandable proxy configuration area
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _enabled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '代理服务地址 (URL 前缀)',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _urlController.text =
                                        GitProxyInterceptor.defaultProxyUrl;
                                    _testResult = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('恢复默认', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _urlController,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://ghfast.top/',
                              prefixIcon: const Icon(Icons.link_rounded, size: 20),
                              suffixIcon: _urlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _urlController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              helperText: '支持任意第三方 GitHub 反代服务，末尾斜杠将自动补齐',
                              helperStyle: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (_) {
                              setState(() {
                                _testResult = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Presets Wrap
                          Text(
                            '常用高可用公共镜像预置 (点击直接填入):',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: GitProxyInterceptor.defaultPresets.map((preset) {
                              final cleanPreset = preset.trim();
                              final current = _urlController.text.trim();
                              final isSelected = current == cleanPreset ||
                                  current == cleanPreset.replaceAll(RegExp(r'/+$'), '');

                              return ChoiceChip(
                                showCheckmark: false,
                                label: Text(
                                  cleanPreset == 'https://ghfast.top/'
                                      ? 'ghfast.top (推荐)'
                                      : cleanPreset.replaceAll('https://', '').replaceAll('/', ''),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                visualDensity: VisualDensity.compact,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _urlController.text = cleanPreset;
                                      _testResult = null;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Connectivity Test Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withAlpha(50),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withAlpha(70),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: _isTesting ? null : _testLatency,
                                      icon: _isTesting
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.speed_rounded, size: 16),
                                      label: Text(_isTesting ? '探测中...' : '测试连通性'),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _isTesting
                                            ? '正在向 GitHub 探测点发送测试请求...'
                                            : '点击测试当前代理地址的往返连通性与延迟',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_testResult != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _testResult!.$1
                                          ? Colors.green.withAlpha(30)
                                          : colorScheme.errorContainer.withAlpha(60),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _testResult!.$1
                                            ? Colors.green.withAlpha(80)
                                            : colorScheme.error.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _testResult!.$1
                                              ? Icons.check_circle_rounded
                                              : Icons.error_rounded,
                                          size: 16,
                                          color: _testResult!.$1
                                              ? Colors.green.shade700
                                              : colorScheme.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _testResult!.$3,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _testResult!.$1
                                                  ? Colors.green.shade800
                                                  : colorScheme.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('保存并应用'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
}
