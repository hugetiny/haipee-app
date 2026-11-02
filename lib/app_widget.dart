import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/router.dart';
import 'package:haipee/pages/setting/providers.dart';
import 'package:haipee/utils/tray_localization.dart';
import 'package:haipee/services/logging/debug_hud_overlay.dart';
import 'package:haipee/shaders/providers.dart';

/// Provider for exit dialog "don't ask again" checkbox state
final _exitDialogSavePreferenceProvider =
    StateProvider.autoDispose<bool>((ref) => false);

class AppWidget extends ConsumerStatefulWidget {
  const AppWidget({super.key});

  @override
  ConsumerState<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends ConsumerState<AppWidget>
    with TrayListener, WidgetsBindingObserver, WindowListener {
  Box setting = GStorage.setting;

  final TrayManager trayManager = TrayManager.instance;
  bool showingExitDialog = false;
  ProviderSubscription<LocaleSettingsState>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    setPreventClose();
    WidgetsBinding.instance.addObserver(this);
    _localeSubscription = ref.listenManual<LocaleSettingsState>(
      localeSettingsProvider,
      (_, localeState) {
        // Sync global slang locale when provider changes
        if (localeState.followSystem) {
          LocaleSettings.useDeviceLocale();
        } else {
          LocaleSettings.setLocale(localeState.appLocale);
        }
        if (Utils.isDesktop()) {
          _handleTray();
        }
      },
    );

    // Initialize locale from provider on startup
    final initialLocaleState = ref.read(localeSettingsProvider);
    if (initialLocaleState.followSystem) {
      LocaleSettings.useDeviceLocale();
    } else {
      LocaleSettings.setLocale(initialLocaleState.appLocale);
    }

    if (Utils.isDesktop()) {
      _handleTray();
    }

    Future.microtask(() async {
      try {
        await ref.read(shadersControllerProvider).copyShadersToExternalDirectory();
      } catch (_) {}
    });
  }

  void setPreventClose() async {
    if (Utils.isDesktop()) {
      await windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    _localeSubscription?.close();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    // Stop download engine when app is disposed
    GopeedService().stop();
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
      case 'exit':
        // Stop download engine before exit
        GopeedService().stop();
        exit(0);
    }
  }

  /// 处理窗口关闭事件，
  /// 需要使用 `windowManager.close()` 来触发，`exit(0)` 会直接退出程序
  @override
  void onWindowClose() {
    final setting = GStorage.setting;
    final exitBehavior =
        setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);

    switch (exitBehavior) {
      case 0:
        // Stop download engine before exit
        GopeedService().stop();
        exit(0);
      case 1:
        HaipeeDialog.dismiss();
        windowManager.hide();
        break;
      default:
        if (showingExitDialog) return;
        showingExitDialog = true;
        HaipeeDialog.show(onDismiss: () {
          showingExitDialog = false;
        }, builder: (context) {
          final t = context.t;

          return Consumer(builder: (context, ref, child) {
            final saveExitBehavior =
                ref.watch(_exitDialogSavePreferenceProvider);

            return AlertDialog(
              title: Text(t.exitDialog.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.exitDialog.message),
                  const SizedBox(height: 24),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Checkbox(
                        value: saveExitBehavior,
                        onChanged: (value) {
                          ref
                              .read(_exitDialogSavePreferenceProvider.notifier)
                              .state = value ?? false;
                        },
                      ),
                      Text(t.exitDialog.dontAskAgain),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () async {
                      if (saveExitBehavior) {
                        await setting.put(SettingBoxKey.exitBehavior, 0);
                      }
                      // Stop download engine before exit
                      await GopeedService().stop();
                      exit(0);
                    },
                    child: Text(t.exitDialog.exit)),
                TextButton(
                    onPressed: () async {
                      if (saveExitBehavior) {
                        await setting.put(SettingBoxKey.exitBehavior, 1);
                      }
                      HaipeeDialog.dismiss();
                      windowManager.hide();
                    },
                    child: Text(t.exitDialog.minimize)),
                TextButton(
                    onPressed: HaipeeDialog.dismiss,
                    child: Text(t.exitDialog.cancel)),
              ],
            );
          });
        });
    }
  }

  /// 处理前后台变更
  /// windows/linux 在程序后台或失去焦点时只会触发 inactive 不会触发 paused
  /// android/ios/macos 在程序后台时会先触发 inactive 再触发 paused, 回到前台时会先触发 inactive 再触发 resumed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      debugPrint("应用进入后台");
      // bool webDavEnable =
      //     await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
      // bool webDavEnableHistory = await setting
      //     .get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
      // if (webDavEnable && webDavEnableHistory) {
      //   var webDav = WebDav();
      //   webDav.updateHistory();
      // }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("应用回到前台");
      // bool webDavEnable =
      //     await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
      // bool webDavEnableHistory = await setting
      //     .get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
      // if (webDavEnable && webDavEnableHistory) {
      //   try {
      //     var webDav = WebDav();
      //     webDav.downloadAndPatchHistory();
      //   } catch (e) {
      //     HaipeeLogger().log(Level.error, '同步观看记录失败 ${e.toString()}');
      //   }
      // }
    } else if (state == AppLifecycleState.inactive) {
      debugPrint("应用处于非活动状态");
      // if (Platform.isWindows || Platform.isLinux) {
      //   bool webDavEnable =
      //       await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
      //   bool webDavEnableHistory = await setting
      //       .get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
      //   if (webDavEnable && webDavEnableHistory) {
      //     var webDav = WebDav();
      //     webDav.updateHistory();
      //   }
      // }
    }
  }

  Future<void> _handleTray() async {
    final TrayLabels labels = HaipeeTrayLabels.fromRef(ref);
    if (Platform.isWindows) {
      await trayManager.setIcon('assets/images/logo/logo_lanczos.ico');
    } else if (Platform.environment.containsKey('FLATPAK_ID') ||
        Platform.environment.containsKey('SNAP')) {
      await trayManager.setIcon('io.github.hugetiny.haipee');
    } else {
      await trayManager.setIcon('assets/images/logo/logo_rounded.png');
    }

    if (!Platform.isLinux) {
      await trayManager.setToolTip(labels.tooltip);
    }

    Menu trayMenu = Menu(items: [
      MenuItem(key: 'show_window', label: labels.showWindow),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: labels.exit)
    ]);
    await trayManager.setContextMenu(trayMenu);
  }

  ThemeData _buildLightTheme(ColorScheme? dynamicScheme, Color seedColor) {
    if (dynamicScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: dynamicScheme,
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          backgroundColor: dynamicScheme.surface,
          foregroundColor: dynamicScheme.onSurface,
          elevation: 0.5,
          scrolledUnderElevation: 0,
          toolbarHeight: 40,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(size: 22, color: dynamicScheme.onSurface),
          titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            iconSize: const WidgetStatePropertyAll(22.0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024,
        chipTheme: const ChipThemeData(showCheckmark: false),
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: seedColor,
      appBarTheme: const AppBarTheme(
        elevation: 0.5,
        scrolledUnderElevation: 0,
        toolbarHeight: 40,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(size: 22),
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          iconSize: WidgetStatePropertyAll(22.0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      progressIndicatorTheme: progressIndicatorTheme2024,
      sliderTheme: sliderTheme2024,
      pageTransitionsTheme: pageTransitionsTheme2024,
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }

  ThemeData _buildDarkTheme(
    ColorScheme? dynamicScheme,
    Color seedColor,
    bool oledEnhance,
  ) {
    ThemeData base;
    if (dynamicScheme != null) {
      base = ThemeData(
        useMaterial3: true,
        colorScheme: dynamicScheme,
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
          backgroundColor: dynamicScheme.surface,
          foregroundColor: dynamicScheme.onSurface,
          elevation: 0.5,
          scrolledUnderElevation: 0,
          toolbarHeight: 40,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(size: 22, color: dynamicScheme.onSurface),
          titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            iconSize: const WidgetStatePropertyAll(22.0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024,
        chipTheme: const ChipThemeData(showCheckmark: false),
      );
    } else {
      base = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: seedColor,
        appBarTheme: const AppBarTheme(
          elevation: 0.5,
          scrolledUnderElevation: 0,
          toolbarHeight: 40,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(size: 22),
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            iconSize: WidgetStatePropertyAll(22.0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024,
        chipTheme: const ChipThemeData(showCheckmark: false),
      );
    }
    return oledEnhance ? Utils.oledDarkTheme(base) : base;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final Color seedColor = themeState.seedColor;
    final bool useDynamicColor = themeState.useDynamicColor;
    final bool oledEnhance = themeState.oledEnhance;

    // Theme initialization is performed in initState via a
    // post-frame callback to avoid modifying providers during build.

    final ThemeData fallbackLightTheme = _buildLightTheme(null, seedColor);
    final ThemeData fallbackDarkTheme =
        _buildDarkTheme(null, seedColor, oledEnhance);

    final Widget app = TranslationProvider(
      child: DynamicColorBuilder(
        builder: (dynamicLight, dynamicDark) {
          final bool canUseDynamic =
              useDynamicColor && dynamicLight != null && dynamicDark != null;

          final ThemeData lightTheme = canUseDynamic
              ? _buildLightTheme(dynamicLight, seedColor)
              : fallbackLightTheme;
          final ThemeData darkTheme = canUseDynamic
              ? _buildDarkTheme(dynamicDark, seedColor, oledEnhance)
              : fallbackDarkTheme;

          return MaterialApp.router(
            title: LocaleSettings.currentLocale.translations.app.title,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppLocaleUtils.supportedLocales,
            locale: LocaleSettings.currentLocale.flutterLocale,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeState.themeMode,
            routerConfig: router,
            builder: (context, child) =>
                DebugHudOverlay(child: child ?? const SizedBox()),
          );
        },
      ),
    );

    // 强制设置高帧率
    if (Platform.isAndroid) {
      try {
        late List modes;
        FlutterDisplayMode.supported.then((value) {
          modes = value;
          var storageDisplay = setting.get(SettingBoxKey.displayMode);
          DisplayMode f = DisplayMode.auto;
          if (storageDisplay != null) {
            f = modes.firstWhere((e) => e.toString() == storageDisplay);
          }
          DisplayMode preferred = modes.toList().firstWhere((el) => el == f);
          FlutterDisplayMode.setPreferredMode(preferred);
        });
      } catch (e) {
        HaipeeLogger().log(Level.error, '高帧率设置失败 ${e.toString()}');
      }
    }

    return app;
  }
}
