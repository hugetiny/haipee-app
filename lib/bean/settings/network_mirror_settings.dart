import 'package:flutter/material.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/pages/setting/widgets/git_proxy_dialog.dart';
import 'package:haipee/services/network/bangumi_acceleration.dart';
import 'package:haipee/services/network/image_acceleration.dart';
import 'package:haipee/services/storage/storage.dart';

class NetworkMirrorSettings extends StatefulWidget {
  const NetworkMirrorSettings({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<NetworkMirrorSettings> createState() => _NetworkMirrorSettingsState();
}

class _NetworkMirrorSettingsState extends State<NetworkMirrorSettings> {
  Future<void> _save<T>(SettingKey<T> key, T value) async {
    await GStorage.putSetting(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bangumiAcceleration = BangumiAcceleration.current;
    final gitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    final imageAcceleration = ImageAcceleration.fromSetting(
      GStorage.getSetting(SettingsKeys.imageAcceleration),
    );
    return SettingsSection(
      title: const Text('访问加速'),
      margin: widget.margin,
      tiles: [
        SettingsTile(
          leading: const Icon(Icons.travel_explore_rounded),
          title: const Text('番剧条目加速'),
          description: const Text(
            '番剧信息与评论',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: SizedBox(
            width: 70,
            child: Text(bangumiAcceleration.label, textAlign: TextAlign.center),
          ),
          onPressed: (context) => _selectAcceleration(
            context,
            title: '番剧条目加速',
            current: bangumiAcceleration,
            modes: BangumiAcceleration.values,
            label: (mode) => mode.label,
            description: (mode) => mode.description,
            setting: SettingsKeys.bangumiAcceleration,
          ),
        ),
        SettingsTile.switchTile(
          leading: const Icon(Icons.extension_rounded),
          title: const Text('规则仓库镜像'),
          description: const Text('加速规则的下载与更新'),
          initialValue: gitProxy,
          onToggle: (value) async {
            await _save(SettingsKeys.enableGitProxy, value ?? !gitProxy);
          },
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.alt_route_rounded),
          title: const Text('自定义规则代理域名'),
          description: const Text('配置 GitHub 规则加速镜像地址 (默认 ghfast.top)'),
          onPressed: (context) {
            GitProxyDialog.show(context);
          },
        ),
        SettingsTile(
          leading: const Icon(Icons.image_rounded),
          title: const Text('图片加速'),
          description: const Text(
            '封面与头像',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: SizedBox(
            width: 70,
            child: Text(imageAcceleration.label, textAlign: TextAlign.center),
          ),
          onPressed: (context) => _selectAcceleration(
            context,
            title: '图片加速',
            current: imageAcceleration,
            modes: ImageAcceleration.values,
            label: (mode) => mode.label,
            description: (mode) => mode.description,
            setting: SettingsKeys.imageAcceleration,
          ),
        ),
      ],
    );
  }

  Future<void> _selectAcceleration<T extends Enum>(
    BuildContext context, {
    required String title,
    required T current,
    required List<T> modes,
    required String Function(T) label,
    required String Function(T) description,
    required SettingKey<String> setting,
  }) async {
    final selected = await HaipeeDialog.show<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in modes)
                  RadioListTile<T>(
                    value: mode,
                    title: Text(label(mode)),
                    subtitle: Text(
                      description(mode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (mounted && selected != null && selected != current) {
      await _save(setting, selected.name);
    }
  }
}

extension on BangumiAcceleration {
  String get description => switch (this) {
    BangumiAcceleration.direct => '访问官方接口',
    BangumiAcceleration.ech => '启用加密握手',
    BangumiAcceleration.mirror => '镜像接口（默认）',
  };
}

extension on ImageAcceleration {
  String get label => switch (this) {
    ImageAcceleration.direct => '直连',
    ImageAcceleration.ech => 'ECH',
    ImageAcceleration.mirror => '镜像',
  };

  String get description => switch (this) {
    ImageAcceleration.direct => '加载原始图片',
    ImageAcceleration.ech => '加密握手（推荐）',
    ImageAcceleration.mirror => '使用图片镜像',
  };
}
