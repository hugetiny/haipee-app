import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';

/// Danmaku settings state
class DanmakuSettingsState {
  final double danmakuArea;
  final double danmakuOpacity;
  final double danmakuFontSize;
  final int danmakuFontWeight;
  final bool danmakuEnabledByDefault;
  final bool danmakuBorder;
  final bool danmakuTop;
  final bool danmakuBottom;
  final bool danmakuScroll;
  final bool danmakuColor;
  final bool danmakuMassive;
  final bool danmakuBiliBiliSource;
  final bool danmakuGamerSource;
  final bool danmakuDanDanSource;
  final String danDanAppIdOverride;
  final String danDanApiKeyOverride;
  final DanmakuChConvert danmakuChConvert;

  const DanmakuSettingsState({
    required this.danmakuArea,
    required this.danmakuOpacity,
    required this.danmakuFontSize,
    required this.danmakuFontWeight,
    required this.danmakuEnabledByDefault,
    required this.danmakuBorder,
    required this.danmakuTop,
    required this.danmakuBottom,
    required this.danmakuScroll,
    required this.danmakuColor,
    required this.danmakuMassive,
    required this.danmakuBiliBiliSource,
    required this.danmakuGamerSource,
    required this.danmakuDanDanSource,
    required this.danDanAppIdOverride,
    required this.danDanApiKeyOverride,
    required this.danmakuChConvert,
  });

  DanmakuSettingsState copyWith({
    double? danmakuArea,
    double? danmakuOpacity,
    double? danmakuFontSize,
    int? danmakuFontWeight,
    bool? danmakuEnabledByDefault,
    bool? danmakuBorder,
    bool? danmakuTop,
    bool? danmakuBottom,
    bool? danmakuScroll,
    bool? danmakuColor,
    bool? danmakuMassive,
    bool? danmakuBiliBiliSource,
    bool? danmakuGamerSource,
    bool? danmakuDanDanSource,
    String? danDanAppIdOverride,
    String? danDanApiKeyOverride,
    DanmakuChConvert? danmakuChConvert,
  }) {
    return DanmakuSettingsState(
      danmakuArea: danmakuArea ?? this.danmakuArea,
      danmakuOpacity: danmakuOpacity ?? this.danmakuOpacity,
      danmakuFontSize: danmakuFontSize ?? this.danmakuFontSize,
      danmakuFontWeight: danmakuFontWeight ?? this.danmakuFontWeight,
      danmakuEnabledByDefault:
          danmakuEnabledByDefault ?? this.danmakuEnabledByDefault,
      danmakuBorder: danmakuBorder ?? this.danmakuBorder,
      danmakuTop: danmakuTop ?? this.danmakuTop,
      danmakuBottom: danmakuBottom ?? this.danmakuBottom,
      danmakuScroll: danmakuScroll ?? this.danmakuScroll,
      danmakuColor: danmakuColor ?? this.danmakuColor,
      danmakuMassive: danmakuMassive ?? this.danmakuMassive,
      danmakuBiliBiliSource:
          danmakuBiliBiliSource ?? this.danmakuBiliBiliSource,
      danmakuGamerSource: danmakuGamerSource ?? this.danmakuGamerSource,
      danmakuDanDanSource: danmakuDanDanSource ?? this.danmakuDanDanSource,
      danDanAppIdOverride: danDanAppIdOverride ?? this.danDanAppIdOverride,
      danDanApiKeyOverride:
          danDanApiKeyOverride ?? this.danDanApiKeyOverride,
      danmakuChConvert: danmakuChConvert ?? this.danmakuChConvert,
    );
  }
}

/// Danmaku settings notifier
class DanmakuSettingsNotifier extends Notifier<DanmakuSettingsState> {
  @override
  DanmakuSettingsState build() {
    final setting = GStorage.setting;

    return DanmakuSettingsState(
      danmakuArea:
          setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0) as double,
      danmakuOpacity: setting.get(SettingBoxKey.danmakuOpacity,
          defaultValue: 1.0) as double,
      danmakuFontSize: setting.get(SettingBoxKey.danmakuFontSize,
          defaultValue: (Utils.isCompact()) ? 16.0 : 25.0) as double,
      danmakuFontWeight:
          setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4) as int,
      danmakuEnabledByDefault: setting.get(
          SettingBoxKey.danmakuEnabledByDefault,
          defaultValue: false) as bool,
      danmakuBorder:
          setting.get(SettingBoxKey.danmakuBorder, defaultValue: true) as bool,
      danmakuTop:
          setting.get(SettingBoxKey.danmakuTop, defaultValue: true) as bool,
      danmakuBottom:
          setting.get(SettingBoxKey.danmakuBottom, defaultValue: false) as bool,
      danmakuScroll:
          setting.get(SettingBoxKey.danmakuScroll, defaultValue: true) as bool,
      danmakuColor:
          setting.get(SettingBoxKey.danmakuColor, defaultValue: true) as bool,
      danmakuMassive: setting.get(SettingBoxKey.danmakuMassive,
          defaultValue: false) as bool,
      danmakuBiliBiliSource: setting.get(SettingBoxKey.danmakuBiliBiliSource,
          defaultValue: true) as bool,
      danmakuGamerSource: setting.get(SettingBoxKey.danmakuGamerSource,
          defaultValue: true) as bool,
      danmakuDanDanSource: setting.get(SettingBoxKey.danmakuDanDanSource,
          defaultValue: true) as bool,
      danDanAppIdOverride:
          ((setting.get(SettingBoxKey.danDanAppId, defaultValue: '') as String?)
                  ?.trim() ??
              ''),
      danDanApiKeyOverride: ((setting.get(SettingBoxKey.danDanApiKey,
                  defaultValue: '') as String?)
              ?.trim() ??
          ''),
      danmakuChConvert: DanmakuChConvert.fromValue(
        GStorage.getSetting(SettingsKeys.danmakuChConvert),
      ),
    );
  }

  Future<void> setDanmakuArea(double value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuArea, value);
    state = state.copyWith(danmakuArea: value);
  }

  Future<void> setDanmakuOpacity(double value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuOpacity, value);
    state = state.copyWith(danmakuOpacity: value);
  }

  Future<void> setDanmakuFontSize(double value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuFontSize, value);
    state = state.copyWith(danmakuFontSize: value);
  }

  Future<void> setDanmakuFontWeight(int value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuFontWeight, value);
    state = state.copyWith(danmakuFontWeight: value);
  }

  Future<void> setDanmakuEnabledByDefault(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuEnabledByDefault, value);
    state = state.copyWith(danmakuEnabledByDefault: value);
  }

  Future<void> setDanmakuBorder(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuBorder, value);
    state = state.copyWith(danmakuBorder: value);
  }

  Future<void> setDanmakuTop(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuTop, value);
    state = state.copyWith(danmakuTop: value);
  }

  Future<void> setDanmakuBottom(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuBottom, value);
    state = state.copyWith(danmakuBottom: value);
  }

  Future<void> setDanmakuScroll(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuScroll, value);
    state = state.copyWith(danmakuScroll: value);
  }

  Future<void> setDanmakuColor(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuColor, value);
    state = state.copyWith(danmakuColor: value);
  }

  Future<void> setDanmakuMassive(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuMassive, value);
    state = state.copyWith(danmakuMassive: value);
  }

  Future<void> setDanmakuBiliBiliSource(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuBiliBiliSource, value);
    state = state.copyWith(danmakuBiliBiliSource: value);
  }

  Future<void> setDanmakuGamerSource(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuGamerSource, value);
    state = state.copyWith(danmakuGamerSource: value);
  }

  Future<void> setDanmakuDanDanSource(bool value) async {
    await GStorage.setting.put(SettingBoxKey.danmakuDanDanSource, value);
    state = state.copyWith(danmakuDanDanSource: value);
  }

  Future<void> setDanDanCredentials(String appId, String apiKey) async {
    await GStorage.setting.put(SettingBoxKey.danDanAppId, appId);
    await GStorage.setting.put(SettingBoxKey.danDanApiKey, apiKey);
    state = state.copyWith(
      danDanAppIdOverride: appId,
      danDanApiKeyOverride: apiKey,
    );
  }

  Future<void> setDanmakuChConvert(DanmakuChConvert value) async {
    await GStorage.putSetting(SettingsKeys.danmakuChConvert, value.value);
    state = state.copyWith(danmakuChConvert: value);
  }
}

/// 弹幕设置 Provider
///
/// 管理弹幕显示样式、过滤规则和数据源配置。
/// 支持 DanDanPlay、哔哩哔哩、巴哈姆特等多个弹幕源。
///
/// 示例:
/// ```dart
/// final controller = ref.read(danmakuSettingsProvider.notifier);
/// await controller.setDanmakuArea(0.5);
/// ```
final danmakuSettingsProvider =
    NotifierProvider<DanmakuSettingsNotifier, DanmakuSettingsState>(
  DanmakuSettingsNotifier.new,
);
