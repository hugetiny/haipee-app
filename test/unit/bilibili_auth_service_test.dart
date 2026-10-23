import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/bilibili_models.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BiliAuthService authService;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bili_auth_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting_test');
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await GStorage.setting.clear();
    authService = BiliAuthService();
  });

  group('BiliAuthService Tests', () {
    test('1. generateQrCode successfully returns url and qrcodeKey', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.uri.path.contains('/qrcode/generate')) {
          return ResponseBody.fromString(
            '{"code":0,"data":{"url":"https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=test_key_123","qrcode_key":"test_key_123"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      authService.setCustomDio(mockDio);
      final qrData = await authService.generateQrCode();

      expect(qrData.qrcodeKey, equals('test_key_123'));
      expect(qrData.url, contains('qrcode_key=test_key_123'));
    });

    test('2. pollQrCode handles notScanned, scannedWaiting, expired, and success', () async {
      final mockDio = Dio();
      int callCount = 0;

      mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.uri.path.contains('/qrcode/poll')) {
          callCount++;
          if (callCount == 1) {
            return ResponseBody.fromString(
              '{"code":0,"data":{"code":86101,"message":"未扫码"}}',
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          } else if (callCount == 2) {
            return ResponseBody.fromString(
              '{"code":0,"data":{"code":86090,"message":"已扫码未确认"}}',
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          } else if (callCount == 3) {
            return ResponseBody.fromString(
              '{"code":0,"data":{"code":86038,"message":"已失效"}}',
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          } else {
            return ResponseBody.fromString(
              '{"code":0,"data":{"code":0,"message":"成功","url":"https://passport.biligame.com/crossDomain?DedeUserID=123456&SESSDATA=mock_sess_abc123&bili_jct=mock_jct_789"}}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'set-cookie': [
                  'SESSDATA=mock_sess_abc123; Path=/; Domain=.bilibili.com;',
                  'bili_jct=mock_jct_789; Path=/; Domain=.bilibili.com;',
                  'DedeUserID=123456; Path=/; Domain=.bilibili.com;',
                ],
              },
            );
          }
        }
        return ResponseBody.fromString('{}', 404);
      });

      authService.setCustomDio(mockDio);

      // Call 1: notScanned
      final res1 = await authService.pollQrCode('key_1');
      expect(res1.status, equals(BiliQrCodeStatus.notScanned));

      // Call 2: scannedWaiting
      final res2 = await authService.pollQrCode('key_1');
      expect(res2.status, equals(BiliQrCodeStatus.scannedWaitingConfirmation));

      // Call 3: expired
      final res3 = await authService.pollQrCode('key_1');
      expect(res3.status, equals(BiliQrCodeStatus.expired));

      // Call 4: success
      final res4 = await authService.pollQrCode('key_1');
      expect(res4.status, equals(BiliQrCodeStatus.success));
      expect(res4.sessData, equals('mock_sess_abc123'));
      expect(res4.biliJct, equals('mock_jct_789'));
      expect(res4.dedeUserId, equals('123456'));

      // Verify stored in Hive
      expect(authService.isLoggedIn, isTrue);
      expect(authService.getSessData(), equals('mock_sess_abc123'));
      expect(authService.getBiliJct(), equals('mock_jct_789'));
    });

    test('3. fetchUserProfile fetches user details and saves to storage', () async {
      await authService.saveSession(sessData: 'valid_sess');

      final mockDio = Dio();
      mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.uri.path.contains('/nav')) {
          return ResponseBody.fromString(
            '{"code":0,"data":{"isLogin":true,"mid":88888,"uname":"测试二次元用户","face":"https://i0.hdslb.com/bfs/face/mock.jpg","vipType":2,"vip_label":{"text":"年度大会员"},"vip_due_date":1790000000}}',
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      authService.setCustomDio(mockDio);
      final profile = await authService.fetchUserProfile();

      expect(profile, isNotNull);
      expect(profile!.uname, equals('测试二次元用户'));
      expect(profile.mid, equals(88888));
      expect(profile.isVip, isTrue);
      expect(profile.vipLabel, equals('年度大会员'));
      expect(authService.userNotifier.value?.uname, equals('测试二次元用户'));
    });

    test('4. logout clears all credentials and resets state', () async {
      await authService.saveSession(sessData: 'to_be_cleared');
      expect(authService.isLoggedIn, isTrue);

      await authService.logout();
      expect(authService.isLoggedIn, isFalse);
      expect(authService.getSessData(), isNull);
      expect(authService.userNotifier.value, isNull);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
