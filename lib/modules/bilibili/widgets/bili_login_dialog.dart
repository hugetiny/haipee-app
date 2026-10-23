import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';

/// B站扫码登录与账号管理对话框 (跨平台自适应)
class BiliLoginDialog extends StatefulWidget {
  const BiliLoginDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const BiliLoginDialog(),
    );
  }

  @override
  State<BiliLoginDialog> createState() => _BiliLoginDialogState();
}

class _BiliLoginDialogState extends State<BiliLoginDialog> {
  final BiliAuthService _authService = BiliAuthService();

  BiliQrCodeData? _qrData;
  BiliQrCodeStatus _status = BiliQrCodeStatus.notScanned;
  String _statusMessage = '正在生成登录二维码...';
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (!_authService.isLoggedIn) {
      _startQrCodeFlow();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startQrCodeFlow() async {
    _pollTimer?.cancel();
    setState(() {
      _isLoading = true;
      _status = BiliQrCodeStatus.notScanned;
      _statusMessage = '正在生成登录二维码...';
    });

    try {
      final qrData = await _authService.generateQrCode();
      if (!mounted) return;
      setState(() {
        _qrData = qrData;
        _isLoading = false;
        _statusMessage = '请使用哔哩哔哩客户端扫码登录';
      });

      _startPolling(qrData.qrcodeKey);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = BiliQrCodeStatus.error;
        _statusMessage = '二维码生成失败，请点击重试';
      });
    }
  }

  void _startPolling(String qrcodeKey) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final result = await _authService.pollQrCode(qrcodeKey);
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _status = result.status;
          _statusMessage = result.message;
        });

        if (result.status == BiliQrCodeStatus.success) {
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else if (result.status == BiliQrCodeStatus.expired ||
            result.status == BiliQrCodeStatus.error) {
          timer.cancel();
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<BiliUserProfile?>(
      valueListenable: _authService.userNotifier,
      builder: (context, user, _) {
        final isLoggedIn = _authService.isLoggedIn && user != null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              Text(
                isLoggedIn ? '哔哩哔哩账号管理' : '登录哔哩哔哩',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: isLoggedIn ? _buildLoggedInView(user, colorScheme) : _buildQrLoginView(colorScheme),
          ),
          actions: [
            if (isLoggedIn) ...[
              TextButton.icon(
                onPressed: () async {
                  await _authService.logout();
                  setState(() {});
                  _startQrCodeFlow();
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
              if (_status == BiliQrCodeStatus.expired || _status == BiliQrCodeStatus.error)
                FilledButton.icon(
                  onPressed: _startQrCodeFlow,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新生成'),
                ),
            ],
          ],
        );
      },
    );
  }

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

  Widget _buildQrLoginView(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_qrData != null && _status != BiliQrCodeStatus.expired && _status != BiliQrCodeStatus.error)
                  ? QrImageView(
                      data: _qrData!.url,
                      version: QrVersions.auto,
                      size: 176,
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
                              _status == BiliQrCodeStatus.expired
                                  ? Icons.refresh
                                  : Icons.error_outline,
                              size: 44,
                              color: Colors.black54,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击刷新二维码',
                              style: TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_status == BiliQrCodeStatus.scannedWaitingConfirmation)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_status == BiliQrCodeStatus.success)
              const Icon(Icons.check_circle, color: Colors.green, size: 18)
            else
              const Icon(Icons.qr_code_scanner, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _status == BiliQrCodeStatus.success
                      ? Colors.green
                      : (_status == BiliQrCodeStatus.error ? Colors.red : colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '登录后可解除 360P 限制，畅享 1080P/4K 原画',
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
      ],
    );
  }
}
