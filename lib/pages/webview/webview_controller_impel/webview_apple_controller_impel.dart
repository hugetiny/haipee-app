import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebviewAppleItemControllerImpel
    extends WebviewItemController<PlatformInAppWebViewController> {
  PlatformHeadlessInAppWebView? headlessWebView;
  Timer? loadingMonitorTimer;
  bool hasInjectedScripts = false;
  String? _lastRedirectedIframeUrl;

  @override
  Future<void> init() async {
    headlessWebView ??= PlatformHeadlessInAppWebView(
      PlatformHeadlessInAppWebViewCreationParams(
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: '''
            function removeLazyLoading() {
              document.querySelectorAll('iframe[loading="lazy"]').forEach(iframe => {
                iframe.removeAttribute('loading');
              });
            }
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', removeLazyLoading);
            } else {
              removeLazyLoading();
            }
          ''',
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          userAgent: Utils.getRandomUA(),
          mediaPlaybackRequiresUserGesture: true,
          allowsInlineMediaPlayback: true,
          javaScriptCanOpenWindowsAutomatically: true,
          useOnLoadResource: false,
          cacheEnabled: false,
          isInspectable: false,
          contentBlockers: [
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?devtools-detector\.js",
                  resourceType: [
                    ContentBlockerTriggerResourceType.SCRIPT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(urlFilter: '.*', resourceType: [
                ContentBlockerTriggerResourceType.IMAGE,
              ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?googleads",
                  resourceType: [
                    ContentBlockerTriggerResourceType.DOCUMENT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?googlesyndication\.com",
                  resourceType: [
                    ContentBlockerTriggerResourceType.DOCUMENT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?prestrain\.html",
                  resourceType: [
                    ContentBlockerTriggerResourceType.DOCUMENT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?prestrain%2Ehtml",
                  resourceType: [
                    ContentBlockerTriggerResourceType.DOCUMENT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                  urlFilter: r"^https?://.+?adtrafficquality",
                  resourceType: [
                    ContentBlockerTriggerResourceType.DOCUMENT,
                  ]),
              action:
                  ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
            ),
          ],
        ),
        onWebViewCreated: (controller) {
          debugPrint('[WebView] Created');
          webviewController = controller;
          initEventController.add(true);
        },
        onLoadStart: (controller, url) {
          logEventController.add('started loading: $url');
        },
        onLoadStop: (controller, url) {
          logEventController.add('loading completed: $url');
          _scanPageForMediaAndIframes();
        },
        onReceivedError: (controller, request, error) {
          debugPrint(
              '[WebView] Error: ${error.toString()} - Request: ${request.url}');
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
    _lastRedirectedIframeUrl = null;
    videoLoadingEventController.add(true);

    // 规范化 URL 路径，清理意外的双斜杠
    final normalizedUrl = url.replaceAllMapped(
      RegExp(r'^((?:https?:)?//[^/]+)(/.*)$'),
      (match) {
        final host = match.group(1)!;
        final path = match.group(2)!.replaceAll(RegExp(r'/+'), '/');
        return '$host$path';
      },
    );

    logEventController.add('🔍 开始解析: $normalizedUrl');

    await webviewController?.loadUrl(urlRequest: URLRequest(url: WebUri(normalizedUrl)));

    loadingMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (isVideoSourceLoaded) {
        timer.cancel();
      } else {
        count++;
        if (count % 5 == 0) {
          logEventController.add('⏳ 解析中... $count秒');
        }
        await _scanPageForMediaAndIframes();
        if (count >= 30) {
          timer.cancel();
          isIframeLoaded = true;
          videoLoadingEventController.add(false);
          await unloadPage();

          logEventController.add('clear');
          logEventController.add('❌ 解析视频资源超时');
          logEventController.add('💡 请切换到其他播放列表或视频源');
          logEventController.add('showDebug');
        }
      }
    });
  }

  void _onVideoSourceFound(String mediaUrl) {
    if (isVideoSourceLoaded) return;
    isIframeLoaded = true;
    isVideoSourceLoaded = true;
    loadingMonitorTimer?.cancel();
    videoLoadingEventController.add(false);
    logEventController.add('clear');
    logEventController.add('🎉 视频解析成功: $mediaUrl');
    unloadPage();
    videoParserEventController.add((mediaUrl, offset));
  }

  void _handleIframeRedirect(String iframeUrl, int offset) {
    if (isVideoSourceLoaded) return;
    String targetUrl = iframeUrl.trim();
    if (targetUrl.startsWith('//')) {
      targetUrl = 'https:$targetUrl';
    }
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      return;
    }
    if (_lastRedirectedIframeUrl == targetUrl) {
      return;
    }
    _lastRedirectedIframeUrl = targetUrl;
    logEventController.add('🚀 跟随播放器框架: $targetUrl');
    webviewController?.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
  }

  Future<void> _scanPageForMediaAndIframes() async {
    if (isVideoSourceLoaded) return;
    try {
      final result = await webviewController?.evaluateJavascript(source: '''
        (function() {
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

          // 1. Scan <video> elements
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            var src = videos[i].getAttribute('src') || videos[i].src;
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads') && !src.includes('groupvideo') && !src.includes('photo.qq.com')) {
              return JSON.stringify({ type: 'video', url: src });
            }
            var sources = videos[i].getElementsByTagName('source');
            for (var j = 0; j < sources.length; j++) {
              var sSrc = sources[j].getAttribute('src') || sources[j].src;
              if (sSrc && sSrc.trim() !== '' && !sSrc.startsWith('blob:') && !sSrc.includes('googleads') && !sSrc.includes('groupvideo') && !sSrc.includes('photo.qq.com')) {
                return JSON.stringify({ type: 'video', url: sSrc });
              }
            }
          }

          // 2. Scan MacCMS player_aaaa
          if (window.player_aaaa && window.player_aaaa.url) {
            var u = decodeMacCMS(window.player_aaaa.url, window.player_aaaa.encrypt);
            if (u.indexOf('.m3u8') !== -1 || u.indexOf('.mp4') !== -1 || u.indexOf('.flv') !== -1) {
              return JSON.stringify({ type: 'video', url: u });
            } else if (window.MacPlayerConfig && window.MacPlayerConfig.player_list) {
              var from = window.player_aaaa.from;
              var pObj = window.MacPlayerConfig.player_list[from];
              if (pObj && pObj.parse) {
                return JSON.stringify({ type: 'iframe', url: pObj.parse + encodeURIComponent(u) });
              }
            }
          }

          // 3. Scan iframes
          var iframes = document.querySelectorAll('iframe');
          for (var k = 0; k < iframes.length; k++) {
            var iSrc = iframes[k].src || iframes[k].getAttribute('src');
            if (iSrc && iSrc.trim() !== '') {
              if (iSrc.startsWith('//')) {
                iSrc = window.location.protocol + iSrc;
              } else if (iSrc.startsWith('/')) {
                iSrc = window.location.origin + iSrc;
              }
              if (iSrc.startsWith('http') &&
                  !iSrc.includes('google') && !iSrc.includes('prestrain') && !iSrc.includes('adtraffic') &&
                  !iSrc.includes('about:blank')) {
                return JSON.stringify({ type: 'iframe', url: iSrc });
              }
            }
          }

          return '';
        })();
      ''');

      if (result != null && result.toString().isNotEmpty && result.toString() != '""' && result.toString() != 'null') {
        dynamic parsed;
        try {
          final str = result is String ? result : result.toString();
          parsed = jsonDecode(str);
        } catch (_) {}

        if (parsed is Map) {
          final type = parsed['type']?.toString();
          final mediaUrl = parsed['url']?.toString() ?? '';
          if (type == 'video' && mediaUrl.isNotEmpty && !isVideoSourceLoaded) {
            logEventController.add('🎯 主动嗅探定位视频流: $mediaUrl');
            _onVideoSourceFound(mediaUrl);
          } else if (type == 'iframe' && mediaUrl.isNotEmpty && !isVideoSourceLoaded) {
            _handleIframeRedirect(mediaUrl, offset);
          }
        }
      }
    } catch (e) {
      debugPrint('[AppleWebView] Scan error: $e');
    }
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

    logEventController.add('Adding IframeRedirectBridge handler');
    webviewController?.addJavaScriptHandler(
        handlerName: 'IframeRedirectBridge',
        callback: (args) {
          String message = args[0].toString();
          logEventController.add('Redirect callback: $message');
          _handleIframeRedirect(message, offset);
        });

    logEventController.add('Adding JSBridgeDebug handler');
    webviewController?.addJavaScriptHandler(
        handlerName: 'JSBridgeDebug',
        callback: (args) {
          String message = args[0].toString();
          logEventController.add('Legacy callback: $message');
          if ((message.contains('http') || message.startsWith('//')) &&
              !message.contains('googleads') &&
              !message.contains('googlesyndication.com') &&
              !message.contains('prestrain.html') &&
              !message.contains('prestrain%2Ehtml') &&
              !message.contains('adtrafficquality')) {
            String encodedUrl = Uri.encodeFull(message);
            final decoded = Utils.decodeVideoSource(encodedUrl);
            if (decoded != encodedUrl) {
              _onVideoSourceFound(decoded);
            } else if (message.endsWith('.m3u8') || message.contains('.m3u8?')) {
              _onVideoSourceFound(message);
            }
          }
        });

    logEventController.add('Adding VideoBridgeDebug handler');
    webviewController?.addJavaScriptHandler(
        handlerName: 'VideoBridgeDebug',
        callback: (args) {
          String message = args[0].toString();
          logEventController.add('VideoBridge callback: $message');
          if (message.contains('http') && !isVideoSourceLoaded) {
            _onVideoSourceFound(message);
          }
        });
  }

  Future<void> addUserScripts(
      bool useNativePlayer, bool useLegacyParser) async {
    final List<UserScript> scripts = [];

    const String safeCallScript = """
      function _kCall(handler, msg) {
        try {
          if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
            window.flutter_inappwebview.callHandler(handler, msg);
          } else {
            window.addEventListener('flutterInAppWebViewPlatformReady', function() {
              try {
                if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
                  window.flutter_inappwebview.callHandler(handler, msg);
                }
              } catch(e) {}
            }, { once: true });
          }
        } catch(e) {}
      }
    """;

    final String blobParserScript = """
      $safeCallScript

      _kCall('LogBridge', 'BlobParser loaded: ' + window.location.href);

      ${useNativePlayer ? '''
      // Mute all audio/video elements at prototype level in headless mode to prevent audio leakage
      try {
        if (window.HTMLMediaElement && window.HTMLMediaElement.prototype) {
          try {
            Object.defineProperty(window.HTMLMediaElement.prototype, 'muted', {
              get: function() { return true; },
              set: function() {}
            });
            Object.defineProperty(window.HTMLMediaElement.prototype, 'volume', {
              get: function() { return 0; },
              set: function() {}
            });
          } catch(e) {}
        }
      } catch(e) {}
      ''' : ''}

      // 1. Hook window.fetch
      try {
        if (typeof window.fetch === 'function' && !window.__kazumi_fetch_wrapped) {
          window.__kazumi_fetch_wrapped = true;
          const _fetch = window.fetch;
          window.fetch = async function (...args) {
            let url = '';
            try {
              const req = args && args[0];
              if (typeof req === 'string') {
                url = req;
              } else if (req && req.url) {
                url = req.url;
              }
              var adKeywords = ['google', 'adtraffic', 'prestrain', 'photo.qq.com', 'groupvideo', 'googlesyndication', 'doubleclick', 'analytics'];
              function isAdUrl(u) {
                if (!u) return true;
                for (var a = 0; a < adKeywords.length; a++) {
                  if (u.indexOf(adKeywords[a]) !== -1) return true;
                }
                return false;
              }
              if (url && (url.includes('.m3u8') || url.includes('m3u8') || url.includes('.mp4') || url.includes('.flv'))) {
                if (!isAdUrl(url)) {
                  _kCall('LogBridge', 'M3U8/MP4 URL detected (fetch): ' + url);
                  _kCall('VideoBridgeDebug', url);
                }
              }
            } catch (e) {}

            const resp = await _fetch.apply(this, args);

            try {
              const ct = resp && resp.headers && resp.headers.get ? (resp.headers.get('content-type') || '') : '';
              const respUrl = resp && (resp.url || url) ? (resp.url || url) : '';

              if (ct.includes('application/vnd.apple.mpegurl') || ct.includes('application/x-mpegURL') || ct.includes('video/mp4')) {
                _kCall('LogBridge', 'M3U8/MP4 content-type detected: ' + respUrl);
                if (respUrl && !isAdUrl(respUrl)) {
                  _kCall('VideoBridgeDebug', respUrl);
                }
              } else {
                try {
                  const cloned = resp.clone();
                  cloned.text().then(function(text) {
                    if (text && text.trim().startsWith('#EXTM3U')) {
                      _kCall('LogBridge', 'M3U8 content found: ' + respUrl);
                      if (!isAdUrl(respUrl)) {
                        _kCall('VideoBridgeDebug', respUrl);
                      }
                    }
                  }).catch(function(){});
                } catch (e) {}
              }
            } catch (e) {}

            return resp;
          };
        }
      } catch (e) {}

      // 2. Hook Response.prototype.text
      try {
        if (window.Response && window.Response.prototype && !window.__kazumi_resp_wrapped) {
          window.__kazumi_resp_wrapped = true;
          const _r_text = window.Response.prototype.text;
          window.Response.prototype.text = function () {
            return new Promise((resolve, reject) => {
              _r_text.call(this).then((text) => {
                resolve(text);
                try {
                  if (text && typeof text === 'string' && text.trim().startsWith("#EXTM3U")) {
                    _kCall('LogBridge', 'M3U8 source found (Response.text): ' + this.url);
                    if (!isAdUrl(this.url)) {
                      _kCall('VideoBridgeDebug', this.url);
                    }
                  }
                } catch(e) {}
              }).catch(reject);
            });
          };
        }
      } catch(e) {}

      // 3. Hook XMLHttpRequest
      try {
        if (window.XMLHttpRequest && window.XMLHttpRequest.prototype && !window.__kazumi_xhr_wrapped) {
          window.__kazumi_xhr_wrapped = true;
          const _open = window.XMLHttpRequest.prototype.open;
          window.XMLHttpRequest.prototype.open = function (...args) {
            try {
              const url = args[1];
              if (url && typeof url === 'string') {
                if (url.includes('.m3u8') || url.includes('m3u8') || url.includes('.mp4') || url.includes('.flv')) {
                  if (!isAdUrl(url)) {
                    _kCall('LogBridge', 'M3U8 URL detected (XHR): ' + url);
                    _kCall('VideoBridgeDebug', url);
                  }
                }
              }
            } catch(e) {}

            this.addEventListener("load", function () {
              try {
                const url = args[1];
                if (this.responseType === '' || this.responseType === 'text') {
                  const content = this.responseText;
                  if (content && typeof content === 'string' && content.trim().startsWith("#EXTM3U")) {
                    _kCall('LogBridge', 'M3U8 content found (XHR): ' + url);
                    if (!isAdUrl(url)) {
                      _kCall('VideoBridgeDebug', url);
                    }
                  }
                }
              } catch(e) {}
            });
            return _open.apply(this, args);
          };
        }
      } catch(e) {}
    """;

    final String domScannerScript = """
      \$safeCallScript

      _kCall('LogBridge', 'DomScanner loaded: ' + window.location.href);

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

      ${useNativePlayer ? '''
      try {
        const medias = document.querySelectorAll('video, audio');
        for (let m = 0; m < medias.length; m++) {
          medias[m].muted = true;
          medias[m].volume = 0;
        }
      } catch(e) {}
      if (!window.__kazumi_mute_listener) {
        window.__kazumi_mute_listener = true;
        document.addEventListener('play', function(e) {
          try {
            if (e.target && (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO')) {
              e.target.muted = true;
              e.target.volume = 0;
            }
          } catch(_) {}
        }, true);
      }
      ''' : ''}

      function scanAllMedia() {
        // MacCMS player_aaaa
        try {
          if (window.player_aaaa && window.player_aaaa.url) {
            let u = decodeMacCMS(window.player_aaaa.url, window.player_aaaa.encrypt);
            if (u.indexOf('.m3u8') !== -1 || u.indexOf('.mp4') !== -1 || u.indexOf('.flv') !== -1) {
              _kCall('LogBridge', 'player_aaaa direct media found: ' + u);
              _kCall('VideoBridgeDebug', u);
              return;
            } else if (window.MacPlayerConfig && window.MacPlayerConfig.player_list) {
              let from = window.player_aaaa.from;
              let pObj = window.MacPlayerConfig.player_list[from];
              if (pObj && pObj.parse) {
                let target = pObj.parse + encodeURIComponent(u);
                _kCall('LogBridge', 'MacPlayerConfig target iframe: ' + target);
                _kCall('IframeRedirectBridge', target);
                return;
              }
            }
          }
        } catch(e) {}

        // Video elements
        try {
          const videos = document.querySelectorAll('video');
          for (let i = 0; i < videos.length; i++) {
            let src = videos[i].getAttribute('src') || videos[i].src;
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads') && !src.includes('groupvideo') && !src.includes('photo.qq.com')) {
              _kCall('LogBridge', 'Video tag found: ' + src);
              _kCall('VideoBridgeDebug', src);
              return;
            }
            const sources = videos[i].getElementsByTagName('source');
            for (let j = 0; j < sources.length; j++) {
              let sSrc = sources[j].getAttribute('src') || sources[j].src;
              if (sSrc && sSrc.trim() !== '' && !sSrc.startsWith('blob:') && !sSrc.includes('googleads') && !sSrc.includes('groupvideo') && !sSrc.includes('photo.qq.com')) {
                _kCall('LogBridge', 'Video source tag found: ' + sSrc);
                _kCall('VideoBridgeDebug', sSrc);
                return;
              }
            }
          }
        } catch(e) {}

        // Iframe elements
        try {
          const iframes = document.querySelectorAll('iframe');
          for (let k = 0; k < iframes.length; k++) {
            let iSrc = iframes[k].src || iframes[k].getAttribute('src');
            if (iSrc && iSrc.trim() !== '') {
              if (iSrc.startsWith('//')) {
                iSrc = window.location.protocol + iSrc;
              } else if (iSrc.startsWith('/')) {
                iSrc = window.location.origin + iSrc;
              }
              if (iSrc.startsWith('http') &&
                  !iSrc.includes('google') && !iSrc.includes('prestrain') && !iSrc.includes('adtraffic') &&
                  !iSrc.includes('about:blank')) {
                _kCall('LogBridge', 'Iframe element detected: ' + iSrc);
                _kCall('IframeRedirectBridge', iSrc);
                break;
              }
            }
          }
        } catch(e) {}
      }

      scanAllMedia();

      try {
        const _obs = new MutationObserver(function() {
          scanAllMedia();
        });
        _obs.observe(document.documentElement || document.body, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['src']
        });
      } catch(e) {}
    """;

    scripts.add(UserScript(
      source: blobParserScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false,
    ));
    scripts.add(UserScript(
      source: domScannerScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      forMainFrameOnly: false,
    ));

    await webviewController?.addUserScripts(
      userScripts: scripts,
    );
  }

  @override
  Future<void> unloadPage() async {
    loadingMonitorTimer?.cancel();
    _lastRedirectedIframeUrl = null;
    try {
      await webviewController?.evaluateJavascript(source: '''
        try {
          var medias = document.querySelectorAll('video, audio');
          for (var i = 0; i < medias.length; i++) {
            medias[i].pause();
            medias[i].src = '';
          }
        } catch(e) {}
      ''');
    } catch (_) {}
    await webviewController
        ?.loadUrl(urlRequest: URLRequest(url: WebUri("about:blank")));
  }

  @override
  void dispose() {
    loadingMonitorTimer?.cancel();
    headlessWebView?.dispose();
    headlessWebView = null;
    webviewController = null;
  }
}
