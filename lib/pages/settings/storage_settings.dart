import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/settings/settings_list.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/storage/image_cache_service.dart';

class StorageSettingsPage extends ConsumerStatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  ConsumerState<StorageSettingsPage> createState() =>
      _StorageSettingsPageState();
}

class _StorageSettingsPageState extends ConsumerState<StorageSettingsPage> {
  final _cache = ImageCacheService();
  late Future<int> _cacheSize = _cache.sizeInBytes();
  bool _clearing = false;

  void _refreshSize() => setState(() => _cacheSize = _cache.sizeInBytes());

  void _message(String message) {
    HaipeeDialog.showToast(message: message);
  }

  Future<void> _confirmClear() async {
    if (_clearing) return;
    final confirmed = await HaipeeDialog.show<bool>(
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_rounded),
        title: const Text('清除图片缓存？'),
        content: const Text('图片会在下次加载时重新下载。视频、记录和设置不会删除。'),
        actions: [
          TextButton(
            onPressed: () => HaipeeDialog.dismiss(popWith: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => HaipeeDialog.dismiss(popWith: true),
            child: const Text('清除缓存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await _cache.clear();
      if (!mounted) return;
      _message('图片缓存已清除');
      _refreshSize();
    } catch (_) {
      if (mounted) _message('清除失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _cacheDescription(AsyncSnapshot<int> snapshot) {
    if (_clearing) return '正在清除…';
    if (snapshot.connectionState != ConnectionState.done) return '正在统计…';
    if (snapshot.hasError) return '统计失败';
    return '${(snapshot.requireData / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final debugLogsEnabled = ref.watch(debugLogsEnabledProvider);

    return SettingsDetailScaffold(
      title: const Text('存储与日志'),
      body: FutureBuilder<int>(
        future: _cacheSize,
        builder: (context, snapshot) => SettingsList(
          sections: [
            SettingsSection(
              title: const Text('缓存'),
              tiles: [
                SettingsTile(
                  leading: Icons.image_outlined,
                  title: const Text('清除图片缓存'),
                  description: Text(_cacheDescription(snapshot)),
                  enabled: snapshot.connectionState == ConnectionState.done &&
                      !_clearing,
                  onPressed: (_) => _confirmClear(),
                  trailing: snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasError &&
                          !_clearing
                      ? IconButton(
                          tooltip: '重新统计',
                          onPressed: _refreshSize,
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : const Icon(Icons.cleaning_services_rounded),
                ),
              ],
            ),
            SettingsSection(
              title: const Text('诊断与日志'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.bug_report_outlined,
                  title: const Text('运行日志与诊断'),
                  description: const Text('启用结构化运行日志与 Talker 诊断系统'),
                  initialValue: debugLogsEnabled,
                  onToggle: (value) async {
                    final newValue = value ?? !debugLogsEnabled;
                    ref
                        .read(debugLogsEnabledProvider.notifier)
                        .setEnabled(newValue);
                  },
                ),
                if (debugLogsEnabled)
                  SettingsTile(
                    leading: Icons.receipt_long_rounded,
                    title: const Text('查看运行日志与诊断面板'),
                    description: const Text('查看系统日志、网络请求流与错误回溯'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onPressed: (_) => context.push(Routes.settingsAboutLogs),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
