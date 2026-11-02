import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/utils/storage.dart';

class ProwlarrConfigDialog extends ConsumerStatefulWidget {
  const ProwlarrConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ProwlarrConfigDialog(),
    );
  }

  @override
  ConsumerState<ProwlarrConfigDialog> createState() => _ProwlarrConfigDialogState();
}

class _ProwlarrConfigDialogState extends ConsumerState<ProwlarrConfigDialog> {
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _enabled = false;
  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;
  List<String> _discoveredIndexers = [];

  @override
  void initState() {
    super.initState();
    final setting = GStorage.setting;
    _endpointController.text =
        setting.get(SettingBoxKey.prowlarrEndpoint, defaultValue: '') as String;
    _apiKeyController.text =
        setting.get(SettingBoxKey.prowlarrApiKey, defaultValue: '') as String;
    _enabled =
        setting.get(SettingBoxKey.prowlarrEnabled, defaultValue: false) as bool;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
      _discoveredIndexers = [];
    });

    final res = await TorrentSearchService.testProwlarr(
      _endpointController.text.trim(),
      _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res.success;
        _testMessage = res.message;
        _discoveredIndexers = res.indexers;
      });
    }
  }

  Future<void> _handleSave() async {
    final endpoint = _endpointController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    await GStorage.setting.put(SettingBoxKey.prowlarrEndpoint, endpoint);
    await GStorage.setting.put(SettingBoxKey.prowlarrApiKey, apiKey);
    await GStorage.setting.put(SettingBoxKey.prowlarrEnabled, _enabled);

    ref.read(torrentSearchProvider.notifier).reloadProwlarrConfig();

    if (mounted) {
      HaipeeDialog.showToast(message: 'Prowlarr 配置已保存');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('外部 Torznab / 服务端对接 (可选)'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Haipee 默认已内置 100% 声明式 Cardigann YAML 解析引擎，零外置依赖。如果您已在 NAS 或本地服务器上部署了 Prowlarr/Torznab 服务，可在此配置 API 地址对接作为额外补充。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('启用外部 Torznab / 索引器服务'),
                subtitle: const Text('开启后，资源搜索将同时向该外部服务端发起检索请求并合并结果'),
                value: _enabled,
                onChanged: (val) => setState(() => _enabled = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: '服务器地址 (Host URL)',
                  hintText: 'http://127.0.0.1:9696',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key (密钥)',
                  hintText: '在 Prowlarr 设置 -> 常规 中获取',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _handleTest,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, size: 16),
                    label: const Text('测试连接与拉取索引器'),
                  ),
                ],
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testSuccess == true
                        ? theme.colorScheme.primaryContainer.withAlpha(80)
                        : theme.colorScheme.errorContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _testMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _testSuccess == true
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_discoveredIndexers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '已连通索引器：',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _discoveredIndexers.take(15).map((idx) {
                            return Chip(
                              label: Text(idx, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ],
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
          onPressed: _handleSave,
          child: const Text('保存配置'),
        ),
      ],
    );
  }
}
