import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/adaptive_dialog_frame.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/cardigann/widgets/indexer_web_login_dialog.dart';

/// Dynamic dialog to configure credentials (cookie, passkey, apiKey) and settings for an IndexerPlugin.
class IndexerSettingsDialog extends ConsumerStatefulWidget {
  final IndexerPlugin plugin;

  const IndexerSettingsDialog({super.key, required this.plugin});

  static Future<void> show(BuildContext context, IndexerPlugin plugin) {
    return showDialog(
      context: context,
      builder: (context) => IndexerSettingsDialog(plugin: plugin),
    );
  }

  @override
  ConsumerState<IndexerSettingsDialog> createState() =>
      _IndexerSettingsDialogState();
}

class _IndexerSettingsDialogState extends ConsumerState<IndexerSettingsDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectValues = {};
  final Set<String> _showManualCookie = {};
  late TextEditingController _customBaseUrlController;

  @override
  void initState() {
    super.initState();
    _customBaseUrlController = TextEditingController(
      text: widget.plugin.settings['customBaseUrl'] ?? '',
    );

    for (final setting in widget.plugin.definition.settings) {
      final currentVal = widget.plugin.settings[setting.name] ??
          setting.defaultValue?.toString() ??
          '';
      if (setting.type == 'select') {
        _selectValues[setting.name] = currentVal;
      } else {
        _controllers[setting.name] = TextEditingController(text: currentVal);
      }
    }
  }

  @override
  void dispose() {
    _customBaseUrlController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final updated = Map<String, String>.from(widget.plugin.settings);
    if (_customBaseUrlController.text.trim().isNotEmpty) {
      updated['customBaseUrl'] = _customBaseUrlController.text.trim();
    } else {
      updated.remove('customBaseUrl');
    }

    _controllers.forEach((k, c) {
      updated[k] = c.text.trim();
    });

    _selectValues.forEach((k, v) {
      updated[k] = v;
    });

    ref
        .read(indexerPluginsProvider.notifier)
        .updatePluginSettings(widget.plugin.id, updated);
    Navigator.of(context).pop();
    HaipeeDialog.showToast(message: '已保存索引器配置', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = widget.plugin.definition;

    return AdaptiveDialogFrame(
      maxWidth: 520,
      title: Row(
        children: [
          const Icon(Icons.settings_outlined, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${def.name} 站点设置',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (def.description.isNotEmpty) ...[
                Text(
                  def.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Mirror URL
              TextField(
                controller: _customBaseUrlController,
                decoration: InputDecoration(
                  labelText: '自定义站点镜像地址 (Base URL)',
                  hintText: def.defaultLink,
                  helperText: '默认: ${def.defaultLink}',
                  prefixIcon: const Icon(Icons.link, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Render Cardigann settings fields
              ...def.settings.map((setting) {
                if (setting.name.toLowerCase().contains('cookie')) {
                  return _buildCookieAuthField(theme, theme.colorScheme, def, setting);
                }

                if (setting.type == 'select') {
                  final isMobile = MediaQuery.sizeOf(context).width < 640;
                  final selectedValue = _selectValues[setting.name] ??
                      setting.options.keys.firstOrNull;

                  if (isMobile) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            setting.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: setting.options.entries.map((opt) {
                              final isSelected = selectedValue == opt.key;
                              return ChoiceChip(
                                label: Text(opt.value),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectValues[setting.name] = opt.key;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedValue,
                      decoration: InputDecoration(
                        labelText: setting.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: setting.options.entries.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt.key,
                          child: Text(opt.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectValues[setting.name] = val;
                          });
                        }
                      },
                    ),
                  );
                }

                final isKeyOrPass = setting.name.toLowerCase().contains('key') ||
                    setting.name.toLowerCase().contains('pass');
                final isPassword = setting.type == 'password' || isKeyOrPass;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _controllers[setting.name],
                    obscureText: isPassword,
                    decoration: InputDecoration(
                      labelText: setting.label,
                      hintText: setting.defaultValue?.toString(),
                      helperText: isKeyOrPass
                          ? '可在站点的「个人中心 -> 控制面板 -> API Keys」中一键复制粘贴'
                          : null,
                      prefixIcon: Icon(
                        isPassword ? Icons.vpn_key_outlined : Icons.edit_note,
                        size: 20,
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                );
              }),

              if (def.isPrivate) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此站点为私有追踪器 (Private Tracker)，请配置有效的认证凭据。凭据仅保存在本地设备。',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildCookieAuthField(
    ThemeData theme,
    ColorScheme colorScheme,
    CardigannDefinition def,
    CardigannSetting setting,
  ) {
    final controller = _controllers[setting.name];
    final hasCookie = controller?.text.trim().isNotEmpty == true;
    final isManualOpen = _showManualCookie.contains(setting.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasCookie
            ? colorScheme.primaryContainer.withAlpha(50)
            : colorScheme.surfaceContainerHighest.withAlpha(70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCookie
              ? colorScheme.primary.withAlpha(80)
              : colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCookie
                    ? Icons.verified_user_rounded
                    : Icons.lock_person_outlined,
                size: 20,
                color: hasCookie
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '站点登录与身份凭据 (Cookie 认证)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasCookie)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '🟢 已授权',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '🔴 待登录',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasCookie
                ? '已自动捕获并保存站点登录 Session，检索与下载时将自动携带凭据。'
                : '此私有/半私有站点需要登录账号。点击下方按钮即可在应用内登录，系统将全自动提取凭据，无需手动抓取。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final baseUrl = _customBaseUrlController.text.trim().isNotEmpty
                      ? _customBaseUrlController.text.trim()
                      : def.defaultLink;
                  final loginPath = def.login?.path ?? '';
                  final initialUrl = baseUrl.endsWith('/')
                      ? '$baseUrl${loginPath.startsWith('/') ? loginPath.substring(1) : loginPath}'
                      : '$baseUrl${loginPath.isNotEmpty ? (loginPath.startsWith('/') ? loginPath : '/$loginPath') : ''}';
                  final captured = await IndexerWebLoginDialog.show(
                    context,
                    siteName: def.name,
                    initialUrl: initialUrl.isNotEmpty ? initialUrl : baseUrl,
                  );
                  if (captured != null && captured.trim().isNotEmpty) {
                    setState(() {
                      controller?.text = captured.trim();
                    });
                  }
                },
                icon: Icon(
                  hasCookie ? Icons.sync_rounded : Icons.login_rounded,
                  size: 16,
                ),
                label: Text(hasCookie ? '重新登录更新凭据' : '在应用内登录抓取凭据'),
              ),
              if (hasCookie) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      controller?.clear();
                    });
                  },
                  child: const Text('清除凭据'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              setState(() {
                if (isManualOpen) {
                  _showManualCookie.remove(setting.name);
                } else {
                  _showManualCookie.add(setting.name);
                }
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isManualOpen
                        ? '隐藏高级手动粘贴'
                        : '高级：查看或手动粘贴 Cookie (普通用户请忽略)',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.outline,
                    ),
                  ),
                  Icon(
                    isManualOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isManualOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '手动粘贴 Cookie (包含 c_secure_uid / cf_clearance 等)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
