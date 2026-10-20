import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:kazumi/pages/settings/danmaku/providers.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';

class DanmakuSettingsSheet extends ConsumerStatefulWidget {
  final DanmakuController danmakuController;

  const DanmakuSettingsSheet({super.key, required this.danmakuController});

  @override
  ConsumerState<DanmakuSettingsSheet> createState() =>
      _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends ConsumerState<DanmakuSettingsSheet> {
  void showDanmakuShieldSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (Utils.isDesktop() || Utils.isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return DanmakuShieldSettings();
        });
  }

  @override
  Widget build(BuildContext context) {
    final playerTexts = context.t.settings.player;
    return SettingsList(
      sections: [
        SettingsSection(
          title: Text(playerTexts.danmakuShield),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                showDanmakuShieldSheet();
              },
              title: Text(playerTexts.danmakuKeywordShield),
            ),
          ],
        ),
        SettingsSection(
          title: Text(playerTexts.danmakuStyle),
          tiles: [
            SettingsTile(
              title: Text(playerTexts.danmakuFontSize),
              description: Slider(
                value: widget.danmakuController.option.fontSize,
                min: 10,
                max: Utils.isCompact() ? 32 : 48,
                label:
                    '${widget.danmakuController.option.fontSize.floorToDouble()}',
                onChanged: (value) {
                  // ✅ Update DanmakuController immediately for real-time preview
                  widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      fontSize: value.floorToDouble(),
                    ),
                  );
                  // ✅ Save to Riverpod provider (which persists to storage)
                  ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuFontSize(value.floorToDouble());
                },
              ),
            ),
            SettingsTile(
              title: Text(playerTexts.danmakuOpacity),
              description: Slider(
                value: widget.danmakuController.option.opacity,
                min: 0.1,
                max: 1,
                label:
                    '${(widget.danmakuController.option.opacity * 100).round()}%',
                onChanged: (value) {
                  // ✅ Update DanmakuController immediately for real-time preview
                  widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      opacity: value,
                    ),
                  );
                  // ✅ Save to Riverpod provider (which persists to storage)
                  ref.read(danmakuSettingsProvider.notifier).setDanmakuOpacity(
                      double.parse(value.toStringAsFixed(2)));
                },
              ),
            ),
          ],
        ),
        SettingsSection(
          title: Text(playerTexts.danmakuDisplay),
          tiles: [
            SettingsTile(
              title: Text(playerTexts.danmakuArea),
              description: Slider(
                value: widget.danmakuController.option.area,
                min: 0,
                max: 1,
                divisions: 4,
                label:
                    '${(widget.danmakuController.option.area * 100).round()}%',
                onChanged: (value) {
                  // ✅ Update DanmakuController immediately for real-time preview
                  widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      area: value,
                    ),
                  );
                  // ✅ Save to Riverpod provider (which persists to storage)
                  ref
                      .read(danmakuSettingsProvider.notifier)
                      .setDanmakuArea(value);
                },
              ),
            ),
            SettingsTile.switchTile(
              onToggle: (value) async {
                bool show = value ?? widget.danmakuController.option.hideTop;
                // ✅ Update DanmakuController immediately for real-time preview
                widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    hideTop: !show,
                  ),
                );
                // ✅ Save to Riverpod provider (which persists to storage)
                await ref
                    .read(danmakuSettingsProvider.notifier)
                    .setDanmakuTop(show);
              },
              title: Text(playerTexts.danmakuTopDisplay),
              initialValue: !widget.danmakuController.option.hideTop,
            ),
            SettingsTile.switchTile(
              onToggle: (value) async {
                bool show = value ?? widget.danmakuController.option.hideBottom;
                // ✅ Update DanmakuController immediately for real-time preview
                widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    hideBottom: !show,
                  ),
                );
                // ✅ Save to Riverpod provider (which persists to storage)
                await ref
                    .read(danmakuSettingsProvider.notifier)
                    .setDanmakuBottom(show);
              },
              title: Text(playerTexts.danmakuBottomDisplay),
              initialValue: !widget.danmakuController.option.hideBottom,
            ),
            SettingsTile.switchTile(
              onToggle: (value) async {
                bool show = value ?? widget.danmakuController.option.hideScroll;
                // ✅ Update DanmakuController immediately for real-time preview
                widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    hideScroll: !show,
                  ),
                );
                // ✅ Save to Riverpod provider (which persists to storage)
                await ref
                    .read(danmakuSettingsProvider.notifier)
                    .setDanmakuScroll(show);
              },
              title: Text(playerTexts.danmakuScrollDisplay),
              initialValue: !widget.danmakuController.option.hideScroll,
            ),
          ],
        ),
      ],
    );
  }
}
