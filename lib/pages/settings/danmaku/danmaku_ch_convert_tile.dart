import 'package:flutter/material.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/danmaku/danmaku_ch_convert.dart';
import 'package:haipee/services/storage/storage.dart';

const _saveFailedToast = '简繁转换设置保存失败，请重试';

extension _ConversionLabel on DanmakuChConvert {
  String label(BuildContext context) => switch (this) {
    DanmakuChConvert.none => context.t.settings.player.danmakuConvertNone,
    DanmakuChConvert.simplified =>
      context.t.settings.player.danmakuConvertSimplified,
    DanmakuChConvert.traditional =>
      context.t.settings.player.danmakuConvertTraditional,
  };
}

class DanmakuChConvertTile extends StatefulWidget {
  const DanmakuChConvertTile({super.key});

  @override
  State<DanmakuChConvertTile> createState() => _DanmakuChConvertTileState();
}

class _DanmakuChConvertTileState extends State<DanmakuChConvertTile> {
  late final _settingsChanges = GStorage.watchSettings([
    SettingsKeys.danmakuChConvert,
  ]);
  bool _saving = false;

  Future<void> _selectMode(DanmakuChConvert mode) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await GStorage.putSetting(SettingsKeys.danmakuChConvert, mode.value);
    } catch (_) {
      if (mounted) {
        HaipeeDialog.showToast(context: context, message: _saveFailedToast);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _settingsChanges,
      builder: (context, _) {
        final mode = DanmakuChConvert.fromValue(
          GStorage.getSetting(SettingsKeys.danmakuChConvert),
        );
        return SettingsDropdownTile<DanmakuChConvert>(
          leading: const Icon(Icons.translate_rounded),
          title: Text(context.t.settings.player.danmakuConvert),
          description: Text(context.t.settings.player.danmakuConvertDesc),
          enabled: !_saving,
          value: mode,
          options: {
            for (final option in DanmakuChConvert.values)
              option: option.label(context),
          },
          onChanged: _selectMode,
        );
      },
    );
  }
}
