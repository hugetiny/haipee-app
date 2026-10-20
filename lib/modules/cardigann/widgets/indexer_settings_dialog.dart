import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/cardigann/models/indexer_plugin.dart';

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
    KazumiDialog.showToast(message: '已保存索引器配置', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = widget.plugin.definition;

    return AlertDialog(
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
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
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
                if (setting.type == 'select') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectValues[setting.name] ??
                          setting.options.keys.firstOrNull,
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

                final isPassword = setting.type == 'password' ||
                    setting.name.toLowerCase().contains('pass') ||
                    setting.name.toLowerCase().contains('key');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _controllers[setting.name],
                    obscureText: isPassword,
                    decoration: InputDecoration(
                      labelText: setting.label,
                      hintText: setting.defaultValue?.toString(),
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
        ),
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
}
