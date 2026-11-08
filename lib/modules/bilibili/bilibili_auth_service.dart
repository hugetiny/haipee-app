import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// B站账号鉴权与扫码登录服务 (单例)
class BiliAuthService {
  static final BiliAuthService _instance = BiliAuthService._internal();
  factory BiliAuthService() => _instance;
  BiliAuthService._internal() {
    _loadStoredUser();
  }

  final Dio _defaultDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  Dio? _customDio;
  Dio get _client => _customDio ?? _defaultDio;

  @visibleForTesting
  void setCustomDio(Dio dio) {
    _customDio = dio;
  }

  /// 响应式当前用户画像通知器
  final ValueNotifier<BiliUserProfile?> userNotifier = ValueNotifier<BiliUserProfile?>(null);

  BiliUserProfile? get currentUser => userNotifier.value;

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

  Map<String, dynamic>? _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// 1. 获取扫码登录的二维码 URL 与 qrcodeKey
  Future<BiliQrCodeData> generateQrCode() async {
    const url = 'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
    final response = await _client.get<dynamic>(
      url,
      options: Options(
        headers: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    final resData = _asJsonMap(response.data);
    final data = _asJsonMap(resData?['data']);
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
    final response = await _client.get<dynamic>(
      url,
      options: Options(
        headers: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    final resData = _asJsonMap(response.data);
    final data = _asJsonMap(resData?['data']);
    final rawCode = data?['code'];
    final int code = rawCode is num
        ? rawCode.toInt()
        : (int.tryParse(rawCode?.toString() ?? '') ?? -1);
    final String message = data?['message']?.toString() ?? resData?['message']?.toString() ?? '';

    switch (code) {
      case 0:
        // 扫码登录成功！优先从 Set-Cookie 提取原始编码 Cookie，防止 Uri.queryParameters 解码 %2C/%2A 破坏 SESSDATA
        final String callbackUrl = data?['url']?.toString() ?? '';
        String? sessData;
        String? biliJct;
        String? dedeUserId;

        final setCookies = response.headers['set-cookie'];
        if (setCookies != null) {
          for (final line in setCookies) {
            for (final part in line.split(';')) {
              final trimmed = part.trim();
              final eqIdx = trimmed.indexOf('=');
              if (eqIdx > 0) {
                final k = trimmed.substring(0, eqIdx).trim();
                final v = trimmed.substring(eqIdx + 1).trim();
                if (v.isEmpty) continue;
                if (k == 'SESSDATA' && (sessData == null || sessData.isEmpty)) {
                  sessData = v;
                } else if (k == 'bili_jct' && (biliJct == null || biliJct.isEmpty)) {
                  biliJct = v;
                } else if (k == 'DedeUserID' && (dedeUserId == null || dedeUserId.isEmpty)) {
                  dedeUserId = v;
                }
              }
            }
          }
        }

        // 从回调 URL 参数解析（优先正则提取保留原始百分号编码的 SESSDATA）
        if (callbackUrl.isNotEmpty) {
          final rawSessMatch =
              RegExp(r'(?:^|[?&])SESSDATA=([^&#]+)').firstMatch(callbackUrl);
          if (rawSessMatch != null && (sessData == null || sessData.isEmpty)) {
            sessData = rawSessMatch.group(1)?.trim();
          }
          try {
            final uri = Uri.parse(callbackUrl);
            if (sessData == null || sessData.isEmpty) {
              sessData = uri.queryParameters['SESSDATA'];
            }
            if (biliJct == null || biliJct.isEmpty) {
              biliJct = uri.queryParameters['bili_jct'];
            }
            if (dedeUserId == null || dedeUserId.isEmpty) {
              dedeUserId = uri.queryParameters['DedeUserID'];
            }
          } catch (_) {}
        }

        if (sessData != null && sessData.isNotEmpty) {
          await saveSession(
            sessData: sessData,
            biliJct: biliJct,
            dedeUserId: dedeUserId,
          );

          // 立即设置保底登录用户态，确保 UI 瞬间响应登录成功，不被 nav 接口延迟或波动阻断
          if (userNotifier.value == null) {
            final fallbackProfile = BiliUserProfile(
              isLogin: true,
              mid: int.tryParse(dedeUserId ?? '0') ?? 0,
              uname: dedeUserId != null && dedeUserId.isNotEmpty
                  ? 'B站用户 ($dedeUserId)'
                  : 'B站用户',
              face: '',
              vipType: 0,
              vipLabel: '',
              vipDueDate: 0,
            );
            userNotifier.value = fallbackProfile;
            await GStorage.setting.put('bilibiliUserInfo', fallbackProfile.toJson());
          }

          // 异步刷新获取最新用户昵称与大会员资料（禁止在刚扫码成功时因 nav 波动触发 logout）
          try {
            await fetchUserProfile(allowLogoutOnInvalid: false);
          } catch (e) {
            HaipeeLogger().log(Level.warning, '[BiliAuth] 刷新用户资料异常: $e');
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
          message: message.isNotEmpty ? message : '已扫码，请在手机端确认登录',
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
  Future<BiliUserProfile?> fetchUserProfile({
    bool allowLogoutOnInvalid = true,
  }) async {
    final sessData = getSessData();
    if (sessData == null || sessData.isEmpty) {
      userNotifier.value = null;
      await GStorage.setting.delete('bilibiliUserInfo');
      return null;
    }

    try {
      const url = 'https://api.bilibili.com/x/web-interface/nav';
      final biliJct = getBiliJct();
      final dedeUserId = GStorage.setting.get('bilibiliDedeUserId')?.toString();
      final cookieParts = <String>[
        'SESSDATA=$sessData',
        if (biliJct != null && biliJct.isNotEmpty) 'bili_jct=$biliJct',
        if (dedeUserId != null && dedeUserId.isNotEmpty) 'DedeUserID=$dedeUserId',
      ];
      final response = await _client.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Referer': 'https://www.bilibili.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Cookie': '${cookieParts.join('; ')};',
          },
        ),
      );

      final resData = _asJsonMap(response.data);
      final data = _asJsonMap(resData?['data']);
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
        if (allowLogoutOnInvalid) {
          // Cookie 已失效
          await logout();
          return null;
        }
        return userNotifier.value;
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '[BiliAuth] 获取用户资料失败: $e');
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
