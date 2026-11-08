import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart' as inapp;
import 'package:haipee/modules/bilibili/bilibili_auth_service.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';

/// 登录模式枚举
enum BiliLoginTab {
  /// 网页 / 验证码快捷登录 (手机端默认主流方案)
  webview,

  /// 客户端扫码登录 (桌面端默认主流方案)
  qrCode,

  /// 手动导入 Cookie / SESSDATA
  cookie,
}

/// B站登录与账号管理对话框 (跨平台自适应，精准区分桌面与移动端)
class BiliLoginDialog extends StatefulWidget {
  const BiliLoginDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const BiliLoginDialog(),
    );
  }

  @override
  State<BiliLoginDialog> createState() => _BiliLoginDialogState();
}

class _BiliLoginDialogState extends State<BiliLoginDialog> {
  final BiliAuthService _authService = BiliAuthService();

  late BiliLoginTab _currentTab;

  // --- 扫码登录状态 ---
  BiliQrCodeData? _qrData;
  BiliQrCodeStatus _qrStatus = BiliQrCodeStatus.notScanned;
  String _qrStatusMessage = '正在生成登录二维码...';
  bool _qrLoading = true;
  Timer? _qrPollTimer;
  bool _isPollInFlight = false;
  bool _loginCompleted = false;

  // --- 网页登录状态 ---
  WebViewController? _webViewController;
  bool _webviewLoading = true;
  bool _webviewHasError = false;

  // --- Cookie 导入状态 ---
  final TextEditingController _cookieInputController = TextEditingController();
  bool _cookieVerifying = false;
  String? _cookieErrorMessage;

  bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    // 手机端默认进入网页/短信登录，桌面端仅使用扫码登录
    _currentTab = _isMobilePlatform ? BiliLoginTab.webview : BiliLoginTab.qrCode;

    if (!_authService.isLoggedIn) {
      if (_currentTab == BiliLoginTab.qrCode) {
        _startQrCodeFlow();
      } else if (_currentTab == BiliLoginTab.webview && _isMobilePlatform) {
        _initWebViewController();
      }
    }
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    _cookieInputController.dispose();
    super.dispose();
  }

  void _switchTab(BiliLoginTab tab) {
    if (!_isMobilePlatform && tab != BiliLoginTab.qrCode) return;
    if (_currentTab == tab) return;
    setState(() {
      _currentTab = tab;
    });

    if (tab == BiliLoginTab.qrCode) {
      if (_qrData == null ||
          _qrStatus == BiliQrCodeStatus.expired ||
          _qrStatus == BiliQrCodeStatus.error) {
        _startQrCodeFlow();
      } else {
        _startQrPolling(_qrData!.qrcodeKey);
      }
    } else {
      _qrPollTimer?.cancel();
    }

    if (tab == BiliLoginTab.webview && _isMobilePlatform && _webViewController == null) {
      _initWebViewController();
    }
  }

  // ==========================================
  // 扫码登录流程
  // ==========================================
  Future<void> _startQrCodeFlow() async {
    _qrPollTimer?.cancel();
    _isPollInFlight = false;
    _loginCompleted = false;
    setState(() {
      _qrLoading = true;
      _qrStatus = BiliQrCodeStatus.notScanned;
      _qrStatusMessage = '正在生成登录二维码...';
    });

    try {
      final qrData = await _authService.generateQrCode();
      if (!mounted) return;
      setState(() {
        _qrData = qrData;
        _qrLoading = false;
        _qrStatusMessage = '请使用哔哩哔哩客户端扫码登录';
      });
      WidgetsBinding.instance.scheduleForcedFrame();

      _startQrPolling(qrData.qrcodeKey);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrLoading = false;
        _qrStatus = BiliQrCodeStatus.error;
        _qrStatusMessage = '二维码生成失败，请点击重试';
      });
      WidgetsBinding.instance.scheduleForcedFrame();
    }
  }

  void _startQrPolling(String qrcodeKey) {
    _qrPollTimer?.cancel();
    _isPollInFlight = false;
    _qrPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _loginCompleted) {
        timer.cancel();
        return;
      }
      if (_isPollInFlight) return;
      _isPollInFlight = true;
      try {
        final result = await _authService.pollQrCode(qrcodeKey);
        if (!mounted || _loginCompleted) {
          timer.cancel();
          return;
        }

        final String nextMessage = result.status == BiliQrCodeStatus.notScanned
            ? '请使用哔哩哔哩客户端扫码登录'
            : result.message;

        if (_qrStatus != result.status || _qrStatusMessage != nextMessage) {
          setState(() {
            _qrStatus = result.status;
            _qrStatusMessage = nextMessage;
          });
          WidgetsBinding.instance.scheduleForcedFrame();
        }

        if (result.status == BiliQrCodeStatus.success) {
          _loginCompleted = true;
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop(true);
            WidgetsBinding.instance.scheduleForcedFrame();
          }
          HaipeeDialog.showToast(message: '登录成功！已解锁 1080P/4K 高清画质');
        } else if (result.status == BiliQrCodeStatus.expired ||
            result.status == BiliQrCodeStatus.error) {
          timer.cancel();
        }
      } catch (_) {
      } finally {
        _isPollInFlight = false;
      }
    });
  }

  // ==========================================
  // 移动端 WebView 登录流程
  // ==========================================
  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _webviewLoading = true;
              _webviewHasError = false;
            });
            _inspectLoginCookieFromUrl(url);
          },
          onPageFinished: (url) async {
            setState(() => _webviewLoading = false);
            _inspectLoginCookieFromUrl(url);
            await _inspectPlatformCookies();
          },
          onWebResourceError: (error) {
            setState(() {
              _webviewLoading = false;
              _webviewHasError = true;
            });
          },
          onNavigationRequest: (request) {
            _inspectLoginCookieFromUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://passport.bilibili.com/login'));
  }

  void _inspectLoginCookieFromUrl(String url) {
    if (url.contains('SESSDATA=') || url.contains('bili_jct=')) {
      try {
        final uri = Uri.parse(url);
        final sessData = uri.queryParameters['SESSDATA'];
        final biliJct = uri.queryParameters['bili_jct'];
        final dedeUserId = uri.queryParameters['DedeUserID'];
        if (sessData != null && sessData.isNotEmpty) {
          _handleLoginSuccess(sessData: sessData, biliJct: biliJct, dedeUserId: dedeUserId);
        }
      } catch (_) {}
    }
  }

  Future<void> _inspectPlatformCookies() async {
    try {
      if (inapp.InAppWebViewPlatform.instance != null) {
        final cookieMgr = inapp.PlatformCookieManager(const inapp.PlatformCookieManagerCreationParams());
        final cookies = await cookieMgr.getCookies(
          url: inapp.WebUri('https://bilibili.com'),
        );
        String? sessData;
        String? biliJct;
        String? dedeUserId;

        for (final cookie in cookies) {
          if (cookie.name == 'SESSDATA' && cookie.value.toString().isNotEmpty) {
            sessData = cookie.value.toString();
          }
          if (cookie.name == 'bili_jct' && cookie.value.toString().isNotEmpty) {
            biliJct = cookie.value.toString();
          }
          if (cookie.name == 'DedeUserID' && cookie.value.toString().isNotEmpty) {
            dedeUserId = cookie.value.toString();
          }
        }

        if (sessData != null && sessData.isNotEmpty) {
          await _handleLoginSuccess(sessData: sessData, biliJct: biliJct, dedeUserId: dedeUserId);
          return;
        }
      }
    } catch (_) {}

    try {
      final jsCookie = await _webViewController?.runJavaScriptReturningResult('document.cookie');
      if (jsCookie != null) {
        final cookieStr = jsCookie.toString().replaceAll('"', '');
        if (cookieStr.contains('DedeUserID=') || cookieStr.contains('bili_jct=')) {
          // 尝试从文档 Cookie 提取基础信息
          final parts = cookieStr.split(';');
          String? dedeUserId;
          for (final part in parts) {
            final pair = part.trim().split('=');
            if (pair.length >= 2) {
              if (pair[0] == 'DedeUserID') dedeUserId = pair[1];
            }
          }
          if (dedeUserId != null) {
            // 已登录检测到 UID
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _handleLoginSuccess({
    required String sessData,
    String? biliJct,
    String? dedeUserId,
  }) async {
    await _authService.saveSession(
      sessData: sessData,
      biliJct: biliJct,
      dedeUserId: dedeUserId,
    );
    await _authService.fetchUserProfile();
    if (mounted) {
      HaipeeDialog.showToast(message: '哔哩哔哩登录成功！已解锁 1080P/4K 高清画质', context: context);
      Navigator.of(context).pop(true);
    }
  }

  // ==========================================
  // Cookie 导入流程
  // ==========================================
  Future<void> _handleCookieImport() async {
    final text = _cookieInputController.text.trim();
    if (text.isEmpty) {
      setState(() => _cookieErrorMessage = '请输入 Cookie 或 SESSDATA');
      return;
    }

    setState(() {
      _cookieVerifying = true;
      _cookieErrorMessage = null;
    });

    final (success, message) = await _authService.loginWithCookieString(text);
    if (!mounted) return;

    setState(() => _cookieVerifying = false);

    if (success) {
      HaipeeDialog.showToast(message: message, context: context);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _cookieErrorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ValueListenableBuilder<BiliUserProfile?>(
      valueListenable: _authService.userNotifier,
      builder: (context, user, _) {
        final isLoggedIn = _authService.isLoggedIn && user != null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tv, color: Colors.pink, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isLoggedIn ? '哔哩哔哩账号管理' : '登录哔哩哔哩',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isLoggedIn && _isMobilePlatform)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '手机端推荐',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _currentTab == BiliLoginTab.webview && _isMobilePlatform ? 420 : 340,
              maxHeight: _currentTab == BiliLoginTab.webview && _isMobilePlatform ? 480 : 400,
            ),
            child: isLoggedIn
                ? _buildLoggedInView(user, colorScheme)
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMobilePlatform) ...[
                          _buildTabSelector(colorScheme),
                          const SizedBox(height: 14),
                          switch (_currentTab) {
                            BiliLoginTab.webview => _buildWebviewLoginView(colorScheme, textTheme),
                            BiliLoginTab.qrCode => _buildQrLoginView(colorScheme),
                            BiliLoginTab.cookie => _buildCookieLoginView(colorScheme, textTheme),
                          },
                        ] else ...[
                          const SizedBox(height: 4),
                          _buildQrLoginView(colorScheme),
                        ],
                      ],
                    ),
                  ),
          ),
          actions: [
            if (isLoggedIn) ...[
              TextButton.icon(
                onPressed: () async {
                  await _authService.logout();
                  setState(() {
                    _currentTab = _isMobilePlatform ? BiliLoginTab.webview : BiliLoginTab.qrCode;
                  });
                  if (_currentTab == BiliLoginTab.qrCode) {
                    _startQrCodeFlow();
                  } else if (_isMobilePlatform) {
                    _initWebViewController();
                  }
                },
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: const Text('退出登录', style: TextStyle(color: Colors.red)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('完成'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('暂不登录 (保持360P)'),
              ),
              if ((!_isMobilePlatform || _currentTab == BiliLoginTab.qrCode) &&
                  (_qrStatus == BiliQrCodeStatus.expired || _qrStatus == BiliQrCodeStatus.error))
                FilledButton.icon(
                  onPressed: _startQrCodeFlow,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新生成'),
                ),
              if (_isMobilePlatform && _currentTab == BiliLoginTab.cookie)
                FilledButton(
                  onPressed: _cookieVerifying ? null : _handleCookieImport,
                  child: _cookieVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('验证并登录'),
                ),
            ],
          ],
        );
      },
    );
  }

  /// 模式切换器 (SegmentedButton)
  Widget _buildTabSelector(ColorScheme colorScheme) {
    return SegmentedButton<BiliLoginTab>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(
          value: BiliLoginTab.webview,
          label: Text('网页/短信', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.phone_android, size: 15),
        ),
        ButtonSegment(
          value: BiliLoginTab.qrCode,
          label: Text('扫码登录', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.qr_code_2, size: 15),
        ),
        ButtonSegment(
          value: BiliLoginTab.cookie,
          label: Text('Cookie', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.vpn_key_outlined, size: 15),
        ),
      ],
      selected: {_currentTab},
      onSelectionChanged: (set) => _switchTab(set.first),
    );
  }

  /// 1. 移动端/网页快捷登录视图
  Widget _buildWebviewLoginView(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isMobilePlatform) {
      return SizedBox(
        height: 380,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (_webViewController != null)
                WebViewWidget(controller: _webViewController!),
              if (_webviewLoading)
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('正在加载官方登录页面...', style: TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              if (_webviewHasError)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text('加载失败，请检查网络连接', style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _webViewController?.reload(),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 桌面端提示视图
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices, size: 40, color: Colors.blue),
          const SizedBox(height: 10),
          const Text(
            '桌面端推荐使用手机 App 扫码登录',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '若需使用账号密码或短信登录，可点击下方按钮在外部浏览器中打开，登录后切换至 Cookie 标签粘贴凭证。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => launchUrlString('https://passport.bilibili.com/login'),
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('在默认浏览器中打开登录页'),
          ),
        ],
      ),
    );
  }

  /// 2. 扫码登录视图 (桌面端主流推荐)
  Widget _buildQrLoginView(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 190,
          height: 190,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _qrLoading
              ? const Center(child: CircularProgressIndicator())
              : (_qrData != null && _qrStatus != BiliQrCodeStatus.expired && _qrStatus != BiliQrCodeStatus.error)
                  ? QrImageView(
                      data: _qrData!.url,
                      version: QrVersions.auto,
                      size: 170,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    )
                  : Center(
                      child: InkWell(
                        onTap: _startQrCodeFlow,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _qrStatus == BiliQrCodeStatus.expired
                                  ? Icons.refresh
                                  : Icons.error_outline,
                              size: 40,
                              color: Colors.black54,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '点击刷新二维码',
                              style: TextStyle(color: Colors.black87, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_qrStatus == BiliQrCodeStatus.scannedWaitingConfirmation)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_qrStatus == BiliQrCodeStatus.success)
              const Icon(Icons.check_circle, color: Colors.green, size: 18)
            else
              const Icon(Icons.qr_code_scanner, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _qrStatusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _qrStatus == BiliQrCodeStatus.success
                      ? Colors.green
                      : (_qrStatus == BiliQrCodeStatus.error ? Colors.red : colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '登录后可解除 360P 限制，畅享 1080P/4K 原画',
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
      ],
    );
  }

  /// 3. Cookie / SESSDATA 手动导入视图
  Widget _buildCookieLoginView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手动粘贴 B站登录凭据 (SESSDATA)',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _cookieInputController,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '粘贴完整的 Cookie 字符串，或直接输入 SESSDATA=xxx',
            hintStyle: const TextStyle(fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.all(10),
            errorText: _cookieErrorMessage,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '提示：在电脑浏览器登录 B 站后，按 F12 打开开发者工具，在 Application/Storage > Cookies 中找到 SESSDATA 复制粘贴即可。',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 已登录管理视图
  Widget _buildLoggedInView(BiliUserProfile user, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 36,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: user.face.isNotEmpty ? CachedNetworkImageProvider(user.face) : null,
          child: user.face.isEmpty ? const Icon(Icons.person, size: 36) : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.uname,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isVip) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.vipLabel.isNotEmpty ? user.vipLabel : '大会员',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hd_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                user.isVip ? '已解锁 1080P60 / 4K 超清画质' : '已解锁 1080P 全高清画质',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
