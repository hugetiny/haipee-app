import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bilibili/bilibili_auth_service.dart';
import 'package:kazumi/modules/bilibili/widgets/bili_login_dialog.dart';
import 'package:kazumi/pages/online/online_video_search_page.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bili_widget_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting_test_widget');
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    mockDio = Dio();
    mockDio.httpClientAdapter = _MockHttpClientAdapter((options) {
      if (options.uri.path.contains('/qrcode/generate')) {
        return ResponseBody.fromString(
          '{"code":0,"data":{"url":"https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=test_key","qrcode_key":"test_key"}}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString('{"code":0,"data":{"code":86101,"message":"未扫码"}}', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    });
    BiliAuthService().setCustomDio(mockDio);
  });

  group('Bilibili Login & Auth Banner Widget Tests', () {
    testWidgets('1. BiliLoginDialog mounts in unauthenticated state without overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BiliLoginDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiliLoginDialog), findsOneWidget);
      expect(find.text('登录哔哩哔哩'), findsOneWidget);
      expect(find.text('暂不登录 (保持360P)'), findsOneWidget);

      // Dismiss dialog to cancel timers
      await tester.tap(find.text('暂不登录 (保持360P)'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. OnlineVideoSearchPage shows Bilibili auth banner and opens login dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OnlineVideoSearchPage(initialPopularVideos: []),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Bili Auth Banner
      final bannerFinder = find.byKey(const Key('bili_auth_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(find.textContaining('B站未登录 (360P)'), findsOneWidget);

      // Tap banner to trigger dialog
      await tester.tap(bannerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BiliLoginDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('暂不登录 (保持360P)'));
      await tester.pumpAndSettle();
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
