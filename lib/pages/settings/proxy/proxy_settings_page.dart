import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/settings/network_mirror_settings.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/settings/settings_list.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/pages/setting/widgets/git_proxy_dialog.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/services/network/proxy_manager.dart';
import 'package:haipee/services/storage/storage.dart';

class ProxySettingsPage extends ConsumerStatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  ConsumerState<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends ConsumerState<ProxySettingsPage> {
  Future<void> _setProxyEnabled(bool value) async {
    if (value && !GStorage.getSetting(SettingsKeys.proxyConfigured)) {
      HaipeeDialog.showToast(message: '请先在代理配置中完成测试');
      return;
    }
    await GStorage.putSetting(SettingsKeys.proxyEnable, value);
    if (value) {
      ProxyManager.applyProxy();
    } else {
      ProxyManager.clearProxy();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final proxyEnabled = GStorage.getSetting(SettingsKeys.proxyEnable);
    final gitProxyState = ref.watch(gitProxyProvider);

    return SettingsDetailScaffold(
      title: const Text('网络设置'),
      body: SettingsList(
        sections: [
          const NetworkMirrorSettings(),
          SettingsSection(
            title: const Text('代理'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.vpn_key_rounded,
                onToggle: (value) => _setProxyEnabled(value ?? !proxyEnabled),
                title: const Text('启用代理'),
                description: const Text('启用后网络请求将通过代理服务器'),
                initialValue: proxyEnabled,
              ),
              SettingsTile(
                leading: Icons.tune_rounded,
                onPressed: (_) async {
                  await context.push(Routes.settingsProxyEditor);
                  if (mounted) setState(() {});
                },
                title: const Text('代理配置'),
                description: const Text('配置代理服务器地址和认证信息'),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Github 加速'),
            tiles: [
              SettingsTile(
                leading: Icons.alt_route_rounded,
                title: const Text('Github 镜像'),
                description: const Text('底层加速 Haipee 视频规则、Cardigann 规则与应用更新'),
                value: Text(
                  gitProxyState.enabled
                      ? '已启用 · ${gitProxyState.proxyUrl.replaceAll("https://", "").replaceAll("/", "")}'
                      : '未启用',
                  style: TextStyle(
                    color: gitProxyState.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    fontWeight: gitProxyState.enabled
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onPressed: (_) async {
                  await GitProxyDialog.show(context);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
