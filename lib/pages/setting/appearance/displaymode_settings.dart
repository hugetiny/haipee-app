import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';

class DisplaySettingsState {
  final List<DisplayMode> modes;
  final DisplayMode? active;
  final DisplayMode? preferred;

  DisplaySettingsState({
    this.modes = const [],
    this.active,
    this.preferred,
  });
}

class DisplaySettingsNotifier
    extends AsyncNotifier<DisplaySettingsState> {
  @override
  Future<DisplaySettingsState> build() async {
    List<DisplayMode> modes = [];
    try {
      modes = await FlutterDisplayMode.supported;
    } on PlatformException catch (_) {}

    final active = await FlutterDisplayMode.active;
    final preferred = await FlutterDisplayMode.preferred;

    // Sync with storage if needed, or just rely on system
    // The original code synced to storage, let's keep that if it's useful
    // But FlutterDisplayMode.preferred is the source of truth for the system
    GStorage.setting.put(SettingBoxKey.displayMode, preferred.toString());

    return DisplaySettingsState(
      modes: modes,
      active: active,
      preferred: preferred,
    );
  }

  Future<void> setPreferred(DisplayMode mode) async {
    await FlutterDisplayMode.setPreferredMode(mode);
    // Wait a bit for system to apply
    await Future.delayed(const Duration(milliseconds: 100));
    // Refresh state
    ref.invalidateSelf();
  }
}

final displaySettingsProvider = AsyncNotifierProvider<
    DisplaySettingsNotifier, DisplaySettingsState>(
  DisplaySettingsNotifier.new,
);

class SetDisplayMode extends ConsumerWidget {
  const SetDisplayMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: const SysAppBar(title: Text('屏幕帧率设置')),
      body: stateAsync.when(
        data: (state) {
          if (state.modes.isEmpty) {
            return const Center(child: Text('不支持的设备'));
          }
          return SettingsList(
            sections: [
              SettingsSection(
                title: const Text('没有生效? 重启应用试试'),
                tiles: state.modes
                    .map(
                      (mode) => SettingsTile<DisplayMode>.radioTile(
                        radioValue: mode,
                        groupValue: state.preferred,
                        onChanged: (DisplayMode? newMode) {
                          if (newMode != null) {
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setPreferred(newMode);
                          }
                        },
                        title: mode == DisplayMode.auto
                            ? const Text('自动')
                            : Text(
                                '${mode == state.active ? "[系统] " : ""}$mode'),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
