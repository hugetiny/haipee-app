import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// B站账号鉴权与扫码登录服务 (单例)
class BiliAuthService {
  static final BiliAuthService _instance = BiliAuthService._internal();
  factory BiliAuthService() => _instance;
  BiliAuthService._internal() {
    _loadStoredUser();
  }

  Dio? _customDio;
  Dio get _client => _customDio ?? Dio();

  @visibleForTesting
  void setCustomDio(Dio dio) {
    _customDio = dio;
  }

  /// 响应式当前用户画像通知器
  final ValueNotifier<BiliUserProfile?> userNotifier = ValueNotifier<BiliUserProfile?>(null);

  bool get isLoggedIn {
    final sessData = getSessData();
    return sessData != null && sessData.trim().isNotEmpty;
  }

  String? getSessData() {
    try {
      final val = GStorage.setting.get('bilibiliSessData');
      if (val is String && val.trim().isNotEmpty) return val.trim();
    } catch (_) {}
    return null;
  }

  String? getBiliJct() {
    try {
      final val = GStorage.setting.get('bilibiliBiliJct');
      if (val is String && val.trim().isNotEmpty) return val.trim();
    } catch (_) {}
    return null;
  }

  void _loadStoredUser() {
    try {
      final raw = GStorage.setting.get('bilibiliUserInfo');
      if (raw != null) {
        if (raw is Map) {
          userNotifier.value = BiliUserProfile.fromJson(Map<String, dynamic>.from(raw));
        } else if (raw is String && raw.isNotEmpty) {
          userNotifier.value = BiliUserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  /// 1. 获取扫码登录的二维码 URL 与 qrcodeKey
  Future<BiliQrCodeData> generateQrCode() async {
    const url = 'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
    final response = await _client.get<Map<String, dynamic>>(
      url,
      options: Options(
        headers: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    final data = response.data?['data'];
    if (data == null || data['url'] == null || data['qrcode_key'] == null) {
      throw StateError('获取B站登录二维码失败: ${response.data}');
    }

    return BiliQrCodeData(
      url: data['url'].toString(),
      qrcodeKey: data['qrcode_key'].toString(),
    );
  }

  /// 2. 轮询二维码扫码状态
  Future<BiliQrCodePollResult> pollQrCode(String qrcodeKey) async {
    final url =
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key=$qrcodeKey';
    final response = await _client.get<Map<String, dynamic>>(
      url,
      options: Options(
        headers: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    final resData = response.data;
    final data = resData?['data'] as Map<String, dynamic>?;
    final int code = data?['code'] is int ? data!['code'] as int : -1;
    final String message = data?['message']?.toString() ?? resData?['message']?.toString() ?? '';

    switch (code) {
      case 0:
        // 扫码登录成功！解析 Cookie
        final String callbackUrl = data?['url']?.toString() ?? '';
        String? sessData;
        String? biliJct;
        String? dedeUserId;

        // 从回调 URL query 参数解析
        if (callbackUrl.isNotEmpty) {
          try {
            final uri = Uri.parse(callbackUrl);
            sessData = uri.queryParameters['SESSDATA'];
            biliJct = uri.queryParameters['bili_jct'];
            dedeUserId = uri.queryParameters['DedeUserID'];
          } catch (_) {}
        }

        // 备用：从 response header set-cookie 解析
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null) {
          for (final line in setCookies) {
            for (final part in line.split(';')) {
              final kv = part.trim().split('=');
              if (kv.length == 2) {
                if (kv[0] == 'SESSDATA' && sessData == null) sessData = kv[1];
                if (kv[0] == 'bili_jct' && biliJct == null) biliJct = kv[1];
                if (kv[0] == 'DedeUserID' && dedeUserId == null) dedeUserId = kv[1];
              }
            }
          }
        }

        if (sessData != null && sessData.isNotEmpty) {
          await saveSession(
            sessData: sessData,
            biliJct: biliJct,
            dedeUserId: dedeUserId,
          );

          // 异步刷新获取最新用户信息
          try {
            await fetchUserProfile();
          } catch (e) {
            KazumiLogger().log(Level.warning, '[BiliAuth] 刷新用户资料异常: $e');
          }

          return BiliQrCodePollResult(
            status: BiliQrCodeStatus.success,
            message: '登录成功',
            sessData: sessData,
            biliJct: biliJct,
            dedeUserId: dedeUserId,
          );
        } else {
          return const BiliQrCodePollResult(
            status: BiliQrCodeStatus.error,
            message: '登录成功但未提取到有效凭据',
          );
        }

      case 86101:
        return BiliQrCodePollResult(
          status: BiliQrCodeStatus.notScanned,
          message: message.isNotEmpty ? message : '未扫码',
        );

      case 86090:
        return BiliQrCodePollResult(
          status: BiliQrCodeStatus.scannedWaitingConfirmation,
          message: message.isNotEmpty ? message : '已扫码，等待确认',
        );

      case 86038:
        return BiliQrCodePollResult(
          status: BiliQrCodeStatus.expired,
          message: message.isNotEmpty ? message : '二维码已过期',
        );

      default:
        return BiliQrCodePollResult(
          status: BiliQrCodeStatus.error,
          message: message.isNotEmpty ? message : '状态未知 ($code)',
        );
    }
  }

  /// 3. 保存凭据
  Future<void> saveSession({
    required String sessData,
    String? biliJct,
    String? dedeUserId,
  }) async {
    await GStorage.setting.put('bilibiliSessData', sessData.trim());
    if (biliJct != null) {
      await GStorage.setting.put('bilibiliBiliJct', biliJct.trim());
    }
    if (dedeUserId != null) {
      await GStorage.setting.put('bilibiliDedeUserId', dedeUserId.trim());
    }
  }

  /// 4. 远程拉取最新用户资料与大会员状态
  Future<BiliUserProfile?> fetchUserProfile() async {
    final sessData = getSessData();
    if (sessData == null || sessData.isEmpty) {
      userNotifier.value = null;
      await GStorage.setting.delete('bilibiliUserInfo');
      return null;
    }

    try {
      const url = 'https://api.bilibili.com/x/web-interface/nav';
      final response = await _client.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: {
            'Referer': 'https://www.bilibili.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Cookie': 'SESSDATA=$sessData;',
          },
        ),
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data != null && data['isLogin'] == true) {
        final profile = BiliUserProfile(
          isLogin: true,
          mid: data['mid'] is int ? data['mid'] as int : int.tryParse(data['mid']?.toString() ?? '0') ?? 0,
          uname: data['uname']?.toString() ?? 'B站用户',
          face: data['face']?.toString() ?? '',
          vipType: data['vipType'] is int ? data['vipType'] as int : 0,
          vipLabel: data['vip_label']?['text']?.toString() ?? '',
          vipDueDate: data['vip_due_date'] is int ? data['vip_due_date'] as int : 0,
        );

        userNotifier.value = profile;
        await GStorage.setting.put('bilibiliUserInfo', profile.toJson());
        return profile;
      } else {
        // Cookie 已失效
        await logout();
        return null;
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '[BiliAuth] 获取用户资料失败: $e');
      return userNotifier.value;
    }
  }

  /// 5. 通过原始 Cookie 字符串或 SESSDATA 手动登录
  Future<(bool, String)> loginWithCookieString(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return (false, 'Cookie 不能为空');
    }

    String? sessData;
    String? biliJct;
    String? dedeUserId;

    if (trimmed.contains('=')) {
      final parts = trimmed.split(';');
      for (final part in parts) {
        final pair = part.trim().split('=');
        if (pair.length >= 2) {
          final key = pair[0].trim();
          final val = pair.sublist(1).join('=').trim();
          if (key == 'SESSDATA') sessData = val;
          if (key == 'bili_jct') biliJct = val;
          if (key == 'DedeUserID') dedeUserId = val;
        }
      }
    } else {
      // 纯 SESSDATA 串
      sessData = trimmed;
    }

    if (sessData == null || sessData.isEmpty) {
      return (false, '未能从输入中提取到有效的 SESSDATA');
    }

    await saveSession(
      sessData: sessData,
      biliJct: biliJct,
      dedeUserId: dedeUserId,
    );

    try {
      final profile = await fetchUserProfile();
      if (profile != null && profile.isLogin) {
        return (true, '登录成功！欢迎，${profile.uname}');
      } else {
        await logout();
        return (false, 'Cookie 验证未通过，账号未处于登录状态或凭据已失效');
      }
    } catch (e) {
      return (false, '请求验证失败: $e');
    }
  }

  /// 6. 退出登录
  Future<void> logout() async {
    await GStorage.setting.delete('bilibiliSessData');
    await GStorage.setting.delete('bilibiliBiliJct');
    await GStorage.setting.delete('bilibiliDedeUserId');
    await GStorage.setting.delete('bilibiliUserInfo');
    userNotifier.value = null;
  }
}
