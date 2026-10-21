import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/app_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:kazumi/request/request.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:kazumi/modules/download/gopeed/gopeed_service.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/error/storage_error_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/services/sentry/sentry_service.dart';

void setupGlobalErrorHandlers() {
  // Hook Flutter and platform errors to Talker and preserve existing/Sentry hooks
  final originalFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    KazumiLogger().talker.handle(details.exception, details.stack);
    originalFlutterOnError?.call(details);
  };

  final originalPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    KazumiLogger().talker.handle(error, stack);
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
          title: 'Kazumi',
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }
      Request();
      await Request.setCookie();

      // Initialize Gopeed download engine
      try {
        await GopeedService().initialize();
      } catch (e) {
        KazumiLogger().log(Level.warning, '[Main] Failed to initialize Gopeed: $e');
      }

      runApp(
        const ProviderScope(
          child: AppWidget(),
        ),
      );
    },
  );
}
