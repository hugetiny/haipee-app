import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/player/player_providers.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:haipee/pages/settings/danmaku/providers.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';

class DanmakuSettingsSheet extends ConsumerStatefulWidget {
  final DanmakuController danmakuController;

  const DanmakuSettingsSheet({super.key, required this.danmakuController});

  @override
  ConsumerState<DanmakuSettingsSheet> createState() =>
      _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends ConsumerState<DanmakuSettingsSheet> {
  void showDanmakuShieldSheet() {
    final screenSize = MediaQuery.sizeOf(context);
    final sheetMaxWidth =
        (Utils.isDesktop() || Utils.isTablet()) && screenSize.width >= 640
            ? (screenSize.width * 9 / 16).clamp(420.0, screenSize.width)
            : screenSize.width;
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight:
                (screenSize.height * 0.82).clamp(180.0, screenSize.height),
            maxWidth: sheetMaxWidth),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return DanmakuShieldSettings();
        });
  }

  @override
  Widget build(BuildContext context) {
    final playerTexts = context.t.settings.player;
    final sourcesTexts = playerTexts.danmakuSources;
    final danmakuSettings = ref.watch(danmakuSettingsProvider);
    final playerState = ref.watch(playerProvider);
    final playerController = ref.read(playerProvider.notifier);

    int totalCount = 0;
    int biliCount = 0;
    int gamerCount = 0;
    int dandanCount = 0;
    for (final list in playerState.danDanmakus.values) {
      for (final item in list) {
        totalCount++;
        if (item.source.contains('BiliBili')) {
          biliCount++;
        } else if (item.source.contains('Gamer')) {
          gamerCount++;
        } else {
          dandanCount++;
        }
      }
    }
    final isBiliNative = playerController.activeBiliCid != null &&
        playerController.activeBiliCid! > 0;

    final sectionTitleStr = '${playerTexts.danmakuSource} (已加载 $totalCount 条)';
    final biliNativeTitleStr = '${sourcesTexts.bilibili} 官方原生弹幕';
    final biliNativeDescStr =
        'CID: ${playerController.activeBiliCid} · 共 $totalCount 条 (原生直连)';
    final biliTitleStr = '${sourcesTexts.bilibili} ($biliCount 条)';
    final gamerTitleStr = '${sourcesTexts.gamer} ($gamerCount 条)';
    final dandanTitleStr = '${sourcesTexts.dandan} ($dandanCount 条)';

    return SettingsList(
      sections: [
        SettingsSection(
          title: Text(sectionTitleStr),
          tiles: isBiliNative
              ? [
                  SettingsTile(
                    leading: Icons.verified_rounded,
                    title: Text(biliNativeTitleStr),
                    description: Text(biliNativeDescStr),
                  ),
                ]
              : [
                  SettingsTile.switchTile(
                    leading: Icons.video_collection_rounded,
                    onToggle: (value) async {
                      await ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuBiliBiliSource(
                              value ?? !danmakuSettings.danmakuBiliBiliSource);
                    },
                    title: Text(biliTitleStr),
                    initialValue: danmakuSettings.danmakuBiliBiliSource,
                  ),
                  SettingsTile.switchTile(
                    leading: Icons.sports_esports_rounded,
                    onToggle: (value) async {
                      await ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuGamerSource(
                              value ?? !danmakuSettings.danmakuGamerSource);
                    },
                    title: Text(gamerTitleStr),
                    initialValue: danmakuSettings.danmakuGamerSource,
                  ),
                  SettingsTile.switchTile(
                    leading: Icons.cloud_download_rounded,
                    onToggle: (value) async {
                      await ref
                          .read(danmakuSettingsProvider.notifier)
                          .setDanmakuDanDanSource(
                              value ?? !danmakuSettings.danmakuDanDanSource);
                    },
                    title: Text(dandanTitleStr),
                    initialValue: danmakuSettings.danmakuDanDanSource,
                  ),
                ],
        ),
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
