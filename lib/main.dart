import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:haipee/app_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:haipee/utils/storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:haipee/request/request.dart';
import 'package:flutter/services.dart';
import 'package:haipee/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:haipee/pages/error/storage_error_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/services/sentry/sentry_service.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';

void setupGlobalErrorHandlers() {
  // Hook Flutter and platform errors to Talker and preserve existing/Sentry hooks
  final originalFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    // In release mode, FlutterError.presentError defaults to a no-op unless forceReport is true.
    // Calling dumpErrorToConsole with forceReport: true ensures structured error boxes
    // (RenderFlex overflow metrics, pixel counts, and widget chains) reach logcat and syslog.
    FlutterError.dumpErrorToConsole(details, forceReport: true);

    final exceptionStr = details.exceptionAsString();
    if (exceptionStr.contains('overflowed') || exceptionStr.contains('RenderFlex')) {
      AppLog.recordRenderFlexOverflow(details);
    } else {
      AppLog.e(
        LogModule.system,
        '[HAIPEE_ERROR] Flutter unhandled error: $exceptionStr',
        error: details.exception,
        stackTrace: details.stack,
      );
    }

    HaipeeLogger().talker.handle(details.exception, details.stack);
    originalFlutterOnError?.call(details);
  };

  final originalPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e(
      LogModule.system,
      '[HAIPEE_EXCEPTION] Unhandled platform exception: $error',
      error: error,
      stackTrace: stack,
    );
    HaipeeLogger().talker.handle(error, stack);
    return originalPlatformOnError?.call(error, stack) ?? true;
  };

  // Defensive global error widget builder to completely eliminate the Red Screen of Death
  // and prevent layout/hit-test crashes caused by interactive widgets in broken render subtrees.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GeneralErrorWidget(
                errMsg: details.exceptionAsString(),
              ),
            ),
          ),
        ),
      ),
    );
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.detectTestLab();

  await SentryService.init(
    appRunner: () async {
      setupGlobalErrorHandlers();

      MediaKit.ensureInitialized();
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarColor: Colors.transparent,
        ));
      }

      if (Platform.isAndroid) {
        await Utils.checkWebViewFeatureSupport();
      }

      try {
        await Hive.initFlutter(
            '${(await getApplicationSupportDirectory()).path}/hive');
        await GStorage.init();
      } catch (_) {
        runApp(MaterialApp(
            title: '初始化失败',
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [
              Locale.fromSubtags(
                  languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
            ],
            locale: const Locale.fromSubtags(
                languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
            builder: (context, child) {
              return const StorageErrorPage();
            }));
        return;
      }
      bool showWindowButton = await GStorage.setting
          .get(SettingBoxKey.showWindowButton, defaultValue: false);
      if (Utils.isDesktop()) {
        await windowManager.ensureInitialized();
        bool isLowResolution = await Utils.isLowResolution();
        WindowOptions windowOptions = WindowOptions(
          size: isLowResolution ? const Size(800, 600) : const Size(1280, 860),
          center: true,
          skipTaskbar: false,
          // macOS always hide title bar regardless of showWindowButton setting
          titleBarStyle: (Platform.isMacOS || !showWindowButton)
              ? TitleBarStyle.hidden
              : TitleBarStyle.normal,
          windowButtonVisibility: showWindowButton,
          title: 'haipee',
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
        // Fallback for hot restart or if waitUntilReadyToShow has already fired
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            if (!(await windowManager.isVisible())) {
              await windowManager.show();
              await windowManager.focus();
            }
          } catch (_) {}
        });
      }
      Request();
      await Request.setCookie();

      // Initialize Gopeed download engine in background without blocking UI startup
      unawaited(
        GopeedService().initialize().catchError((e) {
          HaipeeLogger().log(Level.warning, '[Main] Failed to initialize Gopeed: $e');
        }),
      );

      runApp(
        const ProviderScope(
          child: AppWidget(),
        ),
      );
    },
  );
}
