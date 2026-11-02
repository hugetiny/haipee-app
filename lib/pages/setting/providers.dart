import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/services/network/bangumi_acceleration.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

class ThemeState {
  final ThemeMode themeMode;
  final bool useDynamicColor;
  final Color seedColor;
  final bool oledEnhance;
  final bool useSystemFont;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = false,
    this.seedColor = Colors.green,
    this.oledEnhance = false,
    this.useSystemFont = false,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    Color? seedColor,
    bool? oledEnhance,
    bool? useSystemFont,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      seedColor: seedColor ?? this.seedColor,
      oledEnhance: oledEnhance ?? this.oledEnhance,
      useSystemFont: useSystemFont ?? this.useSystemFont,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final setting = GStorage.setting;

    // Load useDynamicColor
    final useDynamicColor =
        setting.get(SettingBoxKey.useDynamicColor, defaultValue: false);

    // Load themeMode
    final String savedThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    final ThemeMode themeMode;
    switch (savedThemeMode) {
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'light':
        themeMode = ThemeMode.light;
        break;
      default:
        themeMode = ThemeMode.system;
        break;
    }

    // Load seedColor
    final String colorValue =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'green');
    final Color seedColor;
    switch (colorValue) {
      case 'purple':
        seedColor = Colors.purple;
        break;
      case 'orange':
        seedColor = Colors.orange;
        break;
      default:
        seedColor = Colors.green;
        break;
    }

    // Load oledEnhance
    final bool oledEnhance =
        setting.get(SettingBoxKey.oledEnhance, defaultValue: false);

    // Load useSystemFont
    final bool useSystemFont =
        setting.get(SettingBoxKey.useSystemFont, defaultValue: false);

    return ThemeState(
      themeMode: themeMode,
      useDynamicColor: useDynamicColor,
      seedColor: seedColor,
      oledEnhance: oledEnhance,
      useSystemFont: useSystemFont,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setUseDynamicColor(bool value) {
    state = state.copyWith(useDynamicColor: value);
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
  }

  void setOledEnhance(bool value) {
    state = state.copyWith(oledEnhance: value);
  }

  void setUseSystemFont(bool value) {
    state = state.copyWith(useSystemFont: value);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

class WebDavState {
  final bool initialized;
  final bool enableGitProxy;

  const WebDavState({
    this.initialized = false,
    this.enableGitProxy = false,
  });

  WebDavState copyWith({
    bool? initialized,
    bool? enableGitProxy,
  }) {
    return WebDavState(
      initialized: initialized ?? this.initialized,
      enableGitProxy: enableGitProxy ?? this.enableGitProxy,
    );
  }
}

class WebDavNotifier extends Notifier<WebDavState> {
  @override
  WebDavState build() {
    final enableGitProxy = GitProxyInterceptor.isEnabled();
    return WebDavState(
      initialized: true,
      enableGitProxy: enableGitProxy,
    );
  }

  Future<void> toggleGitProxy(bool value) async {
    await GitProxyInterceptor.setEnabled(value);
    state = state.copyWith(enableGitProxy: value);
  }
}

final webDavProvider =
    NotifierProvider<WebDavNotifier, WebDavState>(WebDavNotifier.new);

/// 底层 GitHub 代理状态
class GitProxyState {
  final bool enabled;
  final String proxyUrl;

  const GitProxyState({
    required this.enabled,
    required this.proxyUrl,
  });

  GitProxyState copyWith({
    bool? enabled,
    String? proxyUrl,
  }) {
    return GitProxyState(
      enabled: enabled ?? this.enabled,
      proxyUrl: proxyUrl ?? this.proxyUrl,
    );
  }
}

class GitProxyNotifier extends Notifier<GitProxyState> {
  @override
  GitProxyState build() {
    return GitProxyState(
      enabled: GitProxyInterceptor.isEnabled(),
      proxyUrl: GitProxyInterceptor.getEffectiveProxyUrl(),
    );
  }

  Future<void> updateConfig({bool? enabled, String? proxyUrl}) async {
    if (enabled != null) {
      await GitProxyInterceptor.setEnabled(enabled);
    }
    if (proxyUrl != null) {
      await GitProxyInterceptor.setProxyUrl(proxyUrl);
    }
    state = GitProxyState(
      enabled: GitProxyInterceptor.isEnabled(),
      proxyUrl: GitProxyInterceptor.getEffectiveProxyUrl(),
    );
  }

  Future<void> toggleEnabled(bool value) async {
    await GitProxyInterceptor.setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setProxyUrl(String url) async {
    await GitProxyInterceptor.setProxyUrl(url);
    state = state.copyWith(proxyUrl: GitProxyInterceptor.getEffectiveProxyUrl());
  }
}

final gitProxyProvider =
    NotifierProvider<GitProxyNotifier, GitProxyState>(GitProxyNotifier.new);

class PlayerSettingsState {
  final double defaultPlaySpeed;
  final int defaultAspectRatioType;
  final bool hAenable;
  final bool androidEnableOpenSLES;
  final bool lowMemoryMode;
  final bool playResume;
  final bool showPlayerError;
  final bool privateMode;
  final bool playerDebugMode;
  final bool playerDisableAnimations;
  final bool autoSkipOpEd;

  const PlayerSettingsState({
    this.defaultPlaySpeed = 1.0,
    this.defaultAspectRatioType = 1,
    this.hAenable = true,
    this.androidEnableOpenSLES = true,
    this.lowMemoryMode = false,
    this.playResume = true,
    this.showPlayerError = false,
    this.privateMode = false,
    this.playerDebugMode = false,
    this.playerDisableAnimations = false,
    this.autoSkipOpEd = false,
  });

  PlayerSettingsState copyWith({
    double? defaultPlaySpeed,
    int? defaultAspectRatioType,
    bool? hAenable,
    bool? androidEnableOpenSLES,
    bool? lowMemoryMode,
    bool? playResume,
    bool? showPlayerError,
    bool? privateMode,
    bool? playerDebugMode,
    bool? playerDisableAnimations,
    bool? autoSkipOpEd,
  }) {
    return PlayerSettingsState(
      defaultPlaySpeed: defaultPlaySpeed ?? this.defaultPlaySpeed,
      defaultAspectRatioType:
          defaultAspectRatioType ?? this.defaultAspectRatioType,
      hAenable: hAenable ?? this.hAenable,
      androidEnableOpenSLES:
          androidEnableOpenSLES ?? this.androidEnableOpenSLES,
      lowMemoryMode: lowMemoryMode ?? this.lowMemoryMode,
      playResume: playResume ?? this.playResume,
      showPlayerError: showPlayerError ?? this.showPlayerError,
      privateMode: privateMode ?? this.privateMode,
      playerDebugMode: playerDebugMode ?? this.playerDebugMode,
      playerDisableAnimations:
          playerDisableAnimations ?? this.playerDisableAnimations,
      autoSkipOpEd: autoSkipOpEd ?? this.autoSkipOpEd,
    );
  }
}

class PlayerSettingsNotifier extends Notifier<PlayerSettingsState> {
  @override
  PlayerSettingsState build() {
    final setting = GStorage.setting;

    final defaultPlaySpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0) as double;
    final defaultAspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1) as int;
    final hAenable =
        setting.get(SettingBoxKey.hAenable, defaultValue: true) as bool;
    final androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true)
            as bool;
    final lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false) as bool;
    final playResume =
        setting.get(SettingBoxKey.playResume, defaultValue: true) as bool;
    final showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: false) as bool;
    final privateMode =
        setting.get(SettingBoxKey.privateMode, defaultValue: false) as bool;
    final playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false) as bool;
    final playerDisableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false)
            as bool;
    final autoSkipOpEd =
        setting.get(SettingBoxKey.autoSkipOpEd, defaultValue: false) as bool;

    return PlayerSettingsState(
      defaultPlaySpeed: defaultPlaySpeed,
      defaultAspectRatioType: defaultAspectRatioType,
      hAenable: hAenable,
      androidEnableOpenSLES: androidEnableOpenSLES,
      lowMemoryMode: lowMemoryMode,
      playResume: playResume,
      showPlayerError: showPlayerError,
      privateMode: privateMode,
      playerDebugMode: playerDebugMode,
      playerDisableAnimations: playerDisableAnimations,
      autoSkipOpEd: autoSkipOpEd,
    );
  }

  void setAutoSkipOpEd(bool value) {
    state = state.copyWith(autoSkipOpEd: value);
  }

  void setDefaultPlaySpeed(double speed) {
    state = state.copyWith(defaultPlaySpeed: speed);
  }

  void setDefaultAspectRatioType(int type) {
    state = state.copyWith(defaultAspectRatioType: type);
  }

  void setHAEnable(bool value) {
    state = state.copyWith(hAenable: value);
  }

  void setAndroidEnableOpenSLES(bool value) {
    state = state.copyWith(androidEnableOpenSLES: value);
  }

  void setLowMemoryMode(bool value) {
    state = state.copyWith(lowMemoryMode: value);
  }

  void setPlayResume(bool value) {
    state = state.copyWith(playResume: value);
  }

  void setShowPlayerError(bool value) {
    state = state.copyWith(showPlayerError: value);
  }

  void setPrivateMode(bool value) {
    state = state.copyWith(privateMode: value);
  }

  void setPlayerDebugMode(bool value) {
    state = state.copyWith(playerDebugMode: value);
  }

  void setPlayerDisableAnimations(bool value) {
    state = state.copyWith(playerDisableAnimations: value);
  }
}

final playerSettingsProvider =
    NotifierProvider<PlayerSettingsNotifier, PlayerSettingsState>(
  PlayerSettingsNotifier.new,
);

class _ManualLocaleSentinel {
  const _ManualLocaleSentinel();
}

class MetadataSettingsState {
  const MetadataSettingsState({
    required this.bangumiEnabled,
    required this.tmdbEnabled,
    required this.manualLocaleTag,
    required this.bangumiAcceleration,
  });

  final bool bangumiEnabled;
  final bool tmdbEnabled;
  final String? manualLocaleTag;
  final BangumiAcceleration bangumiAcceleration;

  bool get followSystemLocale => manualLocaleTag == null;

  static const _ManualLocaleSentinel _manualLocaleSentinel =
      _ManualLocaleSentinel();

  MetadataSettingsState copyWith({
    bool? bangumiEnabled,
    bool? tmdbEnabled,
    Object? manualLocaleTag = _manualLocaleSentinel,
    BangumiAcceleration? bangumiAcceleration,
  }) {
    return MetadataSettingsState(
      bangumiEnabled: bangumiEnabled ?? this.bangumiEnabled,
      tmdbEnabled: tmdbEnabled ?? this.tmdbEnabled,
      manualLocaleTag: manualLocaleTag == _manualLocaleSentinel
          ? this.manualLocaleTag
          : manualLocaleTag as String?,
      bangumiAcceleration: bangumiAcceleration ?? this.bangumiAcceleration,
    );
  }
}

class MetadataSettingsNotifier extends Notifier<MetadataSettingsState> {
  @override
  MetadataSettingsState build() {
    final bool bangumiEnabled = GStorage.setting.get(
          SettingBoxKey.metadataBangumiEnabled,
          defaultValue: true,
        ) as bool? ??
        true;
    final bool tmdbEnabled = GStorage.setting.get(
          SettingBoxKey.metadataTmdbEnabled,
          defaultValue: true,
        ) as bool? ??
        true;
    final String? rawLocaleTag = GStorage.setting.get(
      SettingBoxKey.metadataPreferredLocale,
      defaultValue: '',
    ) as String?;
    final String? manualLocaleTag =
        (rawLocaleTag == null || rawLocaleTag.isEmpty) ? null : rawLocaleTag;
    return MetadataSettingsState(
      bangumiEnabled: bangumiEnabled,
      tmdbEnabled: tmdbEnabled,
      manualLocaleTag: manualLocaleTag,
      bangumiAcceleration: BangumiAcceleration.current,
    );
  }

  Future<void> setBangumiEnabled(bool value) async {
    await GStorage.setting.put(SettingBoxKey.metadataBangumiEnabled, value);
    state = state.copyWith(bangumiEnabled: value);
  }

  Future<void> setTmdbEnabled(bool value) async {
    await GStorage.setting.put(SettingBoxKey.metadataTmdbEnabled, value);
    state = state.copyWith(tmdbEnabled: value);
  }

  Future<void> setManualLocale(String? localeTag) async {
    final String storedValue = localeTag?.trim() ?? '';
    await GStorage.setting.put(
      SettingBoxKey.metadataPreferredLocale,
      storedValue,
    );
    state = state.copyWith(
      manualLocaleTag: storedValue.isEmpty ? null : storedValue,
    );
  }

  Future<void> setBangumiAcceleration(BangumiAcceleration value) async {
    await GStorage.putSetting(SettingsKeys.bangumiAcceleration, value.name);
    state = state.copyWith(bangumiAcceleration: value);
  }
}

final metadataSettingsProvider =
    NotifierProvider<MetadataSettingsNotifier, MetadataSettingsState>(
  MetadataSettingsNotifier.new,
);

// App Locale Settings Provider
class LocaleSettingsState {
  const LocaleSettingsState({
    required this.appLocale,
    required this.followSystem,
  });

  final AppLocale appLocale;
  final bool followSystem;

  LocaleSettingsState copyWith({
    AppLocale? appLocale,
    bool? followSystem,
  }) {
    return LocaleSettingsState(
      appLocale: appLocale ?? this.appLocale,
      followSystem: followSystem ?? this.followSystem,
    );
  }
}

class LocaleSettingsNotifier extends Notifier<LocaleSettingsState> {
  @override
  LocaleSettingsState build() {
    final String? savedLocale = GStorage.setting.get(
      SettingBoxKey.appLocale,
      defaultValue: '',
    ) as String?;

    final bool followSystem = savedLocale == null || savedLocale.isEmpty;
    final AppLocale initialLocale = _resolveAppLocale(
      savedLocale,
      followSystem: followSystem,
    );

    return LocaleSettingsState(
      appLocale: initialLocale,
      followSystem: followSystem,
    );
  }

  Future<void> setLocale(AppLocale locale) async {
    await GStorage.setting.put(SettingBoxKey.appLocale, locale.languageTag);
    LocaleSettings.setLocale(locale);
    state = state.copyWith(
      appLocale: locale,
      followSystem: false,
    );
  }

  Future<void> useSystemLocale() async {
    await GStorage.setting.put(SettingBoxKey.appLocale, '');
    final AppLocale deviceLocale = AppLocaleUtils.findDeviceLocale();
    LocaleSettings.useDeviceLocale();
    state = state.copyWith(
      appLocale: deviceLocale,
      followSystem: true,
    );
  }

  AppLocale _resolveAppLocale(
    String? savedLocaleTag, {
    required bool followSystem,
  }) {
    if (!followSystem) {
      try {
        return AppLocaleUtils.parse(savedLocaleTag!);
      } catch (_) {
        // Fallback to device locale if parsing fails.
      }
    }
    return AppLocaleUtils.findDeviceLocale();
  }
}

final localeSettingsProvider =
    NotifierProvider<LocaleSettingsNotifier, LocaleSettingsState>(
  LocaleSettingsNotifier.new,
);

/// Provider for show window button setting
final showWindowButtonProvider = StateProvider<bool>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.showWindowButton, defaultValue: false);
});

/// Provider for cache size in MB
final cacheSizeMBProvider = StateProvider<double>((ref) => -1);

/// Provider for auto update setting
final autoUpdateProvider = StateProvider<bool>((ref) {
  final setting = GStorage.setting;
  return setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
});

/// Notifier and provider for diagnostic logs toggle
class DebugLogsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    void listener() {
      if (state != AppLog.isDebugMode) {
        state = AppLog.isDebugMode;
      }
    }

    AppLog.debugModeNotifier.addListener(listener);
    ref.onDispose(() {
      AppLog.debugModeNotifier.removeListener(listener);
    });
    return AppLog.isDebugMode;
  }

  Future<void> setEnabled(bool value) async {
    AppLog.setDebugMode(value);
    state = value;
  }
}

final debugLogsEnabledProvider =
    NotifierProvider<DebugLogsEnabledNotifier, bool>(
  DebugLogsEnabledNotifier.new,
);
