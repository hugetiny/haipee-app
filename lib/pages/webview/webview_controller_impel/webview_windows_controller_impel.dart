import 'dart:async';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:haipee/pages/webview/webview_controller.dart';

class WebviewWindowsItemControllerImpel
    extends WebviewItemController<WebviewController> {
  final List<StreamSubscription> subscriptions = [];
  Timer? _timeoutTimer;

  @override
  Future<void> init() async {
    webviewController ??= WebviewController();
    await webviewController!.initialize();
    await webviewController!
        .setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    initEventController.add(true);
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    await unloadPage();
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);

    _startTimeoutTimer();

    subscriptions.add(webviewController!.onM3USourceLoaded.listen((data) {
      String url = data['url'] ?? '';
      if (url.isEmpty) {
        return;
      }
      _cancelTimeoutTimer();
      unloadPage();
      isIframeLoaded = true;
      isVideoSourceLoaded = true;
      videoLoadingEventController.add(false);
      logEventController.add('Loading m3u8 source: $url');
      videoParserEventController.add((url, offset));
    }));
    subscriptions.add(webviewController!.onVideoSourceLoaded.listen((data) {
      String url = data['url'] ?? '';
      if (url.isEmpty) {
        return;
      }
      _cancelTimeoutTimer();
      unloadPage();
      isIframeLoaded = true;
      isVideoSourceLoaded = true;
      videoLoadingEventController.add(false);
      logEventController.add('Loading video source: $url');
      videoParserEventController.add((url, offset));
    }));
    await webviewController!.loadUrl(url);
  }

  void _startTimeoutTimer() {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!isVideoSourceLoaded) {
        logEventController.add('解析视频资源超时');
        videoLoadingEventController.add(false);
        AppLog.w(
          LogModule.stream,
          'Windows WebView 视频资源嗅探超时 (15s)',
        );
      }
    });
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  Future<void> unloadPage() async {
    _cancelTimeoutTimer();
    for (var s in subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    await redirect2Blank();
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    for (var s in subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    try {
      webviewController?.dispose();
    } catch (_) {}
  }

  // The webview_windows package does not have a method to unload the current page.
  // The loadUrl method opens a new tab, which can lead to memory leaks.
  // Directly disposing of the webview controller would require reinitialization when switching episodes, which is costly.
  // Therefore, this method is used to redirect to a blank page instead.
  Future<void> redirect2Blank() async {
    await webviewController!.executeScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
