import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart'
    as inapp;
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/adaptive_dialog_frame.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// 应用内交互式网页登录对话框 (用于半私有与私有 Cardigann 索引器自动抓取 Cookie 凭据)
class IndexerWebLoginDialog extends StatefulWidget {
  final String siteName;
  final String initialUrl;

  const IndexerWebLoginDialog({
    super.key,
    required this.siteName,
    required this.initialUrl,
  });

  static Future<String?> show(
    BuildContext context, {
    required String siteName,
    required String initialUrl,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => IndexerWebLoginDialog(
        siteName: siteName,
        initialUrl: initialUrl,
      ),
    );
  }

  @override
  State<IndexerWebLoginDialog> createState() => _IndexerWebLoginDialogState();
}

class _IndexerWebLoginDialogState extends State<IndexerWebLoginDialog> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _currentCookie = '';
  int _cookieCount = 0;

  bool get _isWebviewSupported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows);

  @override
  void initState() {
    super.initState();
    if (_isWebviewSupported) {
      _initWebViewController();
    }
  }

  void _initWebViewController() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (url) async {
              if (mounted) {
                setState(() => _isLoading = false);
              }
              await _extractCookies();
            },
            onWebResourceError: (error) {
              HaipeeLogger().log(
                Level.warning,
                'IndexerWebLogin webview error: ${error.description}',
              );
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            },
          ),
        );

      final uri = Uri.tryParse(widget.initialUrl);
      if (uri != null) {
        controller.loadRequest(uri);
      }
      _webViewController = controller;
    } catch (e) {
      HaipeeLogger().log(Level.error, 'Failed to init WebViewController: $e');
      _hasError = true;
      _isLoading = false;
    }
  }

  Future<void> _extractCookies() async {
    final collectedCookies = <String, String>{};

    // 1. 尝试从 InAppWebViewPlatform 原生 CookieManager 读取
    try {
      if (inapp.InAppWebViewPlatform.instance != null) {
        final cookieMgr = inapp.PlatformCookieManager(
          const inapp.PlatformCookieManagerCreationParams(),
        );
        final uri = Uri.tryParse(widget.initialUrl);
        if (uri != null) {
          final targetWebUri = inapp.WebUri(uri.origin);
          final cookies = await cookieMgr.getCookies(url: targetWebUri);
          for (final c in cookies) {
            if (c.name.isNotEmpty && c.value != null) {
              collectedCookies[c.name] = c.value.toString();
            }
          }
        }
      }
    } catch (_) {}

    // 2. 尝试从 document.cookie 读取补充
    try {
      if (_webViewController != null) {
        final jsResult = await _webViewController!
            .runJavaScriptReturningResult('document.cookie');
        final rawStr = jsResult.toString().replaceAll('"', '').trim();
        if (rawStr.isNotEmpty && rawStr != 'null') {
          final pairs = rawStr.split(';');
          for (final p in pairs) {
            final split = p.trim().split('=');
            if (split.length >= 2) {
              final key = split[0].trim();
              final val = split.sublist(1).join('=').trim();
              if (key.isNotEmpty) {
                collectedCookies[key] = val;
              }
            }
          }
        }
      }
    } catch (_) {}

    if (collectedCookies.isNotEmpty && mounted) {
      final formatted = collectedCookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      setState(() {
        _currentCookie = formatted;
        _cookieCount = collectedCookies.length;
      });
    }
  }

  void _finishAndSave() async {
    await _extractCookies();
    if (_currentCookie.trim().isEmpty) {
      HaipeeDialog.showToast(message: '尚未检测到有效登录凭据，请先在网页中完成登录');
      return;
    }
    if (mounted) {
      HaipeeDialog.showToast(message: '登录成功！已自动获取并保存站点凭据');
      Navigator.of(context).pop(_currentCookie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AdaptiveDialogFrame(
      maxWidth: 720,
      maxHeight: 640,
      expand: true,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部标题栏
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '登录 ${widget.siteName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '请在下方网页中正常登录、通过验证码或 2FA，登录成功后点击保存',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '刷新网页',
                  onPressed: () {
                    final uri = Uri.tryParse(widget.initialUrl);
                    if (uri != null) {
                      _webViewController?.loadRequest(uri);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 中间 WebView 视口
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(60),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(100),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      if (_isWebviewSupported && _webViewController != null)
                        WebViewWidget(controller: _webViewController!)
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.web_asset_off_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '当前平台或环境不支持内嵌 WebView 视口',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '请在支持的设备上使用，或在设置中使用 API Key 授权',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isLoading)
                        Container(
                          color: colorScheme.surface.withAlpha(180),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_hasError)
                        Container(
                          color: colorScheme.surface.withAlpha(240),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 40,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(height: 8),
                                const Text('网页加载失败，请检查网络连接或镜像地址'),
                                const SizedBox(height: 12),
                                FilledButton.tonal(
                                  onPressed: () {
                                    final uri = Uri.tryParse(widget.initialUrl);
                                    if (uri != null) {
                                      _webViewController?.loadRequest(uri);
                                    }
                                  },
                                  child: const Text('重试加载'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 底部操作栏与 Cookie 检测状态
            Row(
              children: [
                Icon(
                  _cookieCount > 0
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: _cookieCount > 0 ? Colors.green : colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cookieCount > 0
                        ? '已捕获 $_cookieCount 个站点 Cookie (就绪)'
                        : '登录完成后点击右侧按钮保存凭据',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _cookieCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _cookieCount > 0
                          ? Colors.green.shade700
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _finishAndSave,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('完成并保存登录凭据'),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
