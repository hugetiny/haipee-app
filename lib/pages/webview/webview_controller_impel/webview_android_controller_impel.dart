import 'dart:async';
import 'dart:collection';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/pages/webview/webview_controller.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebviewAndroidItemControllerImpel
    extends WebviewItemController<PlatformInAppWebViewController> {
  PlatformHeadlessInAppWebView? headlessWebView;
  Timer? loadingMonitorTimer;
  bool hasInjectedScripts = false;
  bool shouldInjectIframeRedirect = false;
  bool useNativePlayer = false;

  @override
  Future<void> init() async {
    if (webviewController != null) {
      initEventController.add(true);
      return;
    }
    headlessWebView ??= PlatformHeadlessInAppWebView(
      PlatformHeadlessInAppWebViewCreationParams(
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: '''
            (function() {
              window.alert = function(msg) { console.warn('[Sniffer JS Alert suppressed]:', msg); };
              window.confirm = function(msg) { console.warn('[Sniffer JS Confirm suppressed]:', msg); return true; };
              window.prompt = function(msg, defaultText) { console.warn('[Sniffer JS Prompt suppressed]:', msg); return defaultText || ''; };
            })();
            ''',
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          userAgent: Utils.getRandomUA(),
          mediaPlaybackRequiresUserGesture: true,
          javaScriptCanOpenWindowsAutomatically: false,
          cacheEnabled: false,
          blockNetworkImage: true,
          loadsImagesAutomatically: false,
          upgradeKnownHostsToHTTPS: false,
          safeBrowsingEnabled: false,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
          geolocationEnabled: false,
        ),
        onWebViewCreated: (controller) {
          AppLog.i(LogModule.stream, '[WebView] Created');
          webviewController = controller;
          initEventController.add(true);
        },
        onLoadStart: (controller, url) async {
          logEventController.add('started loading: $url');
          if (url.toString() != 'about:blank') {
            await onLoadStart();
          }
        },
        onLoadStop: (controller, url) {
          logEventController.add('loading completed: $url');
        },
        onJsAlert: (controller, jsAlertRequest) async {
          AppLog.w(LogModule.stream,
              '[WebView Alert 拦截]: ${jsAlertRequest.message} (url: ${jsAlertRequest.url})');
          return JsAlertResponse(
            handledByClient: true,
            action: JsAlertResponseAction.CONFIRM,
          );
        },
        onJsConfirm: (controller, jsConfirmRequest) async {
          AppLog.w(LogModule.stream,
              '[WebView Confirm 拦截]: ${jsConfirmRequest.message} (url: ${jsConfirmRequest.url})');
          return JsConfirmResponse(
            handledByClient: true,
            action: JsConfirmResponseAction.CONFIRM,
          );
        },
        onJsPrompt: (controller, jsPromptRequest) async {
          AppLog.w(LogModule.stream,
              '[WebView Prompt 拦截]: ${jsPromptRequest.message} (url: ${jsPromptRequest.url})');
          return JsPromptResponse(
            handledByClient: true,
            action: JsPromptResponseAction.CONFIRM,
            value: '',
          );
        },
        onJsBeforeUnload: (controller, jsBeforeUnloadRequest) async {
          return JsBeforeUnloadResponse(
            handledByClient: true,
            action: JsBeforeUnloadResponseAction.CONFIRM,
          );
        },
      ),
    );
    await headlessWebView?.run();
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    await unloadPage();
    if (!hasInjectedScripts) {
      addJavaScriptHandlers(useNativePlayer, useLegacyParser);
      await addUserScripts(useNativePlayer, useLegacyParser);
      hasInjectedScripts = true;
    }
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    shouldInjectIframeRedirect = true;
    this.useNativePlayer = useNativePlayer;
    videoLoadingEventController.add(true);

    logEventController.add('🔍 开始解析: $url');

    await webviewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    loadingMonitorTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (isVideoSourceLoaded || isIframeLoaded) {
        timer.cancel();
      } else {
        count++;
        // Log progress every 5 seconds
        if (count % 5 == 0) {
          logEventController.add('⏳ 解析中... $count秒');
        }
        if (count >= 30) {
          timer.cancel();
          // Mark as loaded (failed) to stop loading state
          isIframeLoaded = true;
          videoLoadingEventController.add(false);
          await unloadPage();

          logEventController.add('clear');
          logEventController.add('❌ 解析视频资源超时');
          logEventController.add('💡 请切换到其他播放列表或视频源');
          logEventController.add('showDebug');
          AppLog.w(
            LogModule.stream,
            'Android WebView 视频资源嗅探超时 (30s): 目标地址=$url',
          );
        }
      }
    });
  }

  void addJavaScriptHandlers(bool useNativePlayer, bool useLegacyParser) {
    logEventController.add('Adding LogBridge handler');
    webviewController?.addJavaScriptHandler(
        handlerName: 'LogBridge',
        callback: (args) {
          String message = args[0].toString();
          if (message.contains('about:blank')) {
            return;
          }
          logEventController.add(message);
        });

    if (!useNativePlayer) {
      logEventController.add('Adding IframeRedirectBridge handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'IframeRedirectBridge',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Redirect to: $message');
            Future.delayed(const Duration(seconds: 2), () {
              isIframeLoaded = true;
              videoLoadingEventController.add(false);
            });
          });
    } else if (useLegacyParser) {
      logEventController.add('Adding JSBridgeDebug handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'JSBridgeDebug',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Callback received: $message');
            logEventController.add(
                'If there is audio but no video, please report it to the rule developer.');
            if ((message.contains('http') || message.startsWith('//')) &&
                !message.contains('googleads') &&
                !message.contains('googlesyndication.com') &&
                !message.contains('prestrain.html') &&
                !message.contains('prestrain%2Ehtml') &&
                !message.contains('adtrafficquality')) {
              logEventController.add('Parsing video source $message');
              String encodedUrl = Uri.encodeFull(message);
              if (Utils.decodeVideoSource(encodedUrl) != encodedUrl) {
                isIframeLoaded = true;
                isVideoSourceLoaded = true;
                videoLoadingEventController.add(false);
                logEventController.add('clear');
                logEventController.add(
                    'Loading video source ${Utils.decodeVideoSource(encodedUrl)}');
                unloadPage();
                videoParserEventController
                    .add((Utils.decodeVideoSource(encodedUrl), offset));
              }
            }
          });
    } else {
      logEventController.add('Adding VideoBridgeDebug handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'VideoBridgeDebug',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Callback received: $message');
            if (message.contains('http') && !isVideoSourceLoaded) {
              logEventController.add('clear');
              logEventController.add('Loading video source: $message');
              isIframeLoaded = true;
              isVideoSourceLoaded = true;
              videoLoadingEventController.add(false);
              unloadPage();
              videoParserEventController.add((message, offset));
            }
          });
    }
  }

  Future<void> addUserScripts(
      bool useNativePlayer, bool useLegacyParser) async {
    if (!useNativePlayer) {
      return;
    }
    final List<UserScript> scripts = [];

    if (useLegacyParser) {
      logEventController.add('Adding JSBridgeDebug UserScript');
      const String jsBridgeDebugScript = """
        window.flutter_inappwebview.callHandler('LogBridge', 'JSBridgeDebug script loaded: ' + window.location.href);
        function processIframeElement(iframe) {
          window.flutter_inappwebview.callHandler('LogBridge', 'Processing iframe element');
          let src = iframe.getAttribute('src');
          if (src) {
            window.flutter_inappwebview.callHandler('JSBridgeDebug', src);
          }
        }

        const _observer = new MutationObserver((mutations) => {
          window.flutter_inappwebview.callHandler('LogBridge', 'Scanning for iframes...');
          mutations.forEach(mutation => {
            if (mutation.type === 'attributes' && mutation.target.nodeName === 'IFRAME') {
              processIframeElement(mutation.target);
            } else {
              mutation.addedNodes.forEach(node => {
                if (node.nodeName === 'IFRAME') processIframeElement(node);
                if (node.querySelectorAll) {
                  node.querySelectorAll('iframe').forEach(processIframeElement);
                }
              });
            }
          });
        });

        _observer.observe(document.documentElement, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['src']
        });
      """;
      scripts.add(UserScript(
        source: jsBridgeDebugScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ));
    } else {
      logEventController.add('Adding VideoBridgeDebug UserScripts');
      const String blobParserScript = """
        window.flutter_inappwebview.callHandler('LogBridge', 'BlobParser script loaded: ' + window.location.href);
        const _r_text = window.Response.prototype.text;
        window.Response.prototype.text = function () {
            return new Promise((resolve, reject) => {
                _r_text.call(this).then((text) => {
                    resolve(text);
                    if (text.trim().startsWith("#EXTM3U")) {
                        window.flutter_inappwebview.callHandler('LogBridge', 'M3U8 source found: ' + this.url);
                        window.flutter_inappwebview.callHandler('VideoBridgeDebug', this.url);
                    }
                }).catch(reject);
            });
        }

        const _open = window.XMLHttpRequest.prototype.open;
        window.XMLHttpRequest.prototype.open = function (...args) {
            this.addEventListener("load", () => {
                try {
                    // Check if the URL looks like M3U8
                    const url = args[1];
                    if (url && (url.includes('.m3u8') || url.includes('m3u8'))) {
                        window.flutter_inappwebview.callHandler('LogBridge', 'M3U8 URL detected: ' + url);
                        window.flutter_inappwebview.callHandler('VideoBridgeDebug', url);
                        return;
                    }

                    // Try to read response content (only if responseType allows it)
                    if (this.responseType === '' || this.responseType === 'text') {
                        let content = this.responseText;
                        if (content && content.trim().startsWith("#EXTM3U")) {
                            window.flutter_inappwebview.callHandler('LogBridge', 'M3U8 content found: ' + url);
                            window.flutter_inappwebview.callHandler('VideoBridgeDebug', url);
                        }
                    }
                } catch {}
            });
            return _open.apply(this, args);
        };
      """;

      final String videoTagParserScript = """
        window.flutter_inappwebview.callHandler('LogBridge', 'VideoTagParser script loaded: ' + window.location.href);

        function decodeMacCMS(rawUrl, encrypt) {
          if (!rawUrl || typeof rawUrl !== 'string') return '';
          var u = rawUrl.trim();
          try {
            if (encrypt == 1) {
              u = unescape(u);
            } else if (encrypt == 2) {
              u = unescape(atob(u));
            }
          } catch (e) {}

          if (!u.startsWith('http') && !u.startsWith('//')) {
            try {
              var b = unescape(atob(u));
              if (b.includes('http') || b.includes('.m3u8') || b.includes('.mp4')) {
                u = b;
              }
            } catch (e) {}
          }

          try {
            if (u.includes('%')) {
              u = decodeURIComponent(u);
            }
          } catch (e) {
            try {
              u = unescape(u);
            } catch (_) {}
          }
          return u;
        }

        try {
          const medias = document.querySelectorAll('video, audio');
          for (let m = 0; m < medias.length; m++) {
            medias[m].muted = true;
            medias[m].volume = 0;
          }
        } catch(e) {}
        if (!window.__haipee_mute_listener) {
          window.__haipee_mute_listener = true;
          document.addEventListener('play', function(e) {
            try {
              if (e.target && (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO')) {
                e.target.muted = true;
                e.target.volume = 0;
              }
            } catch(_) {}
          }, true);
        }

        function checkMacCMS() {
          try {
            if (window.player_aaaa && window.player_aaaa.url) {
              let u = decodeMacCMS(window.player_aaaa.url, window.player_aaaa.encrypt);
              if (u.indexOf('.m3u8') !== -1 || u.indexOf('.mp4') !== -1 || u.indexOf('.flv') !== -1) {
                window.flutter_inappwebview.callHandler('LogBridge', 'player_aaaa direct media found: ' + u);
                window.flutter_inappwebview.callHandler('VideoBridgeDebug', u);
                return true;
              } else if (window.MacPlayerConfig && window.MacPlayerConfig.player_list) {
                let from = window.player_aaaa.from;
                let pObj = window.MacPlayerConfig.player_list[from];
                if (pObj && pObj.parse) {
                  let target = pObj.parse + encodeURIComponent(u);
                  window.flutter_inappwebview.callHandler('LogBridge', 'MacPlayerConfig target iframe: ' + target);
                  window.flutter_inappwebview.callHandler('IframeRedirectBridge', target);
                  return true;
                }
              }
            }
          } catch(e) {}
          return false;
        }

        const _observer = new MutationObserver((mutations) => {
          if (checkMacCMS()) return;
          window.flutter_inappwebview.callHandler('LogBridge', 'Scanning for video elements...');
          for (const mutation of mutations) {
            if (mutation.type === "attributes" && mutation.target.nodeName === "VIDEO") {
              if (processVideoElement(mutation.target)) return;
              continue;
            }
            for (const node of mutation.addedNodes) {
              if (node.nodeName === "VIDEO") {
                if (processVideoElement(node)) return;
              }
              if (node.querySelectorAll) {
                for (const video of node.querySelectorAll("video")) {
                  if (processVideoElement(video)) return;
                }
              }
            }
          }
        });
        function processVideoElement(video) {
          window.flutter_inappwebview.callHandler('LogBridge', 'Scanning video element for source URL');
          let src = video.getAttribute('src');
          if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads') && !src.includes('groupvideo') && !src.includes('photo.qq.com')) {
            _observer.disconnect();
            window.flutter_inappwebview.callHandler('LogBridge', 'VIDEO source found: ' + src);
            window.flutter_inappwebview.callHandler('VideoBridgeDebug', src);
            return true;
          }
          const sources = video.getElementsByTagName('source');
          for (let source of sources) {
            src = source.getAttribute('src');
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads') && !src.includes('groupvideo') && !src.includes('photo.qq.com')) {
              _observer.disconnect();
              window.flutter_inappwebview.callHandler('LogBridge', 'VIDEO source found (source tag): ' + src);
              window.flutter_inappwebview.callHandler('VideoBridgeDebug', src);
              return true;
            }
          }
        }

        function setupVideoProcessing() {
          if (checkMacCMS()) return;
          for (const video of document.querySelectorAll("video")) {
            if (processVideoElement(video)) return;
          }
          _observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src']
          });
        }
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', setupVideoProcessing);
        } else {
          setupVideoProcessing();
        }
    """;
      scripts.add(UserScript(
        source: blobParserScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ));
      scripts.add(UserScript(
        source: videoTagParserScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ));
    }

    await webviewController?.addUserScripts(
      userScripts: scripts,
    );
  }

  Future<void> onLoadStart() async {
    if (!useNativePlayer && shouldInjectIframeRedirect) {
      logEventController.add('Adding IframeRedirectBridge UserScript');
      shouldInjectIframeRedirect = false;
      await webviewController?.evaluateJavascript(source: """
        window.flutter_inappwebview.callHandler('LogBridge', 'IframeRedirectBridge script loaded: ' + window.location.href);
        const _observer = new MutationObserver((mutations) => {
          window.flutter_inappwebview.callHandler('LogBridge', 'Scanning for iframes...');
          for (const mutation of mutations) {
            if (mutation.type === "attributes" && mutation.target.nodeName === "IFRAME") {
              if (processIframeElement(mutation.target)) return;
              continue;
            }
            for (const node of mutation.addedNodes) {
              if (node.nodeName === "IFRAME") {
                if (processIframeElement(node)) return;
              }
              if (node.querySelectorAll) {
                for (const iframe of node.querySelectorAll("iframe")) {
                  if (processIframeElement(iframe)) return;
                }
              }
            }
          }
        });

        function processIframeElement(iframe) {
          window.flutter_inappwebview.callHandler('LogBridge', 'Processing iframe element');
          let src = iframe.getAttribute("src");
          if (src && src.trim() !== '' && (src.startsWith('http') || src.startsWith('//')) && !src.includes('googleads') && !src.includes('adtrafficquality') && !src.includes('googlesyndication.com') && !src.includes('google.com') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
            _observer.disconnect();
            window.flutter_inappwebview.callHandler("IframeRedirectBridge", src);
            window.location.href = src;
            return true;
          }
        }

        function setupIframeProcessing() {
          for (const iframe of document.querySelectorAll("iframe")) {
            if (processIframeElement(iframe)) return;
          }
          _observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ["src"],
          });
        }

        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', setupIframeProcessing);
        } else {
          setupIframeProcessing();
        }
      """);
    }
  }

  @override
  Future<void> unloadPage() async {
    loadingMonitorTimer?.cancel();
    await webviewController!
        .loadUrl(urlRequest: URLRequest(url: WebUri("about:blank")));
  }

  @override
  void dispose() {
    loadingMonitorTimer?.cancel();
    headlessWebView?.dispose();
    headlessWebView = null;
    webviewController = null;
  }
}
