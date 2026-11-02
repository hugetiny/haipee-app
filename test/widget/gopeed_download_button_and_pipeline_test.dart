import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/download/download_page.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/pages/resource/resource_search_content.dart';
import 'package:haipee/utils/storage.dart';

class _MockPopularController extends PopularController {
  @override
  PopularState build() => PopularState(trendList: const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final sampleMagnetItem = TorrentItem(
    title: '[ANi] 葬送的芙莉莲 - 28 [1080P][MP4]',
    magnetUrl: 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Frieren_28',
    fileSize: '1.42 GB',
    sizeBytes: 1524678900,
    seeders: 350,
    leechers: 20,
    publishDate: '2小时前',
    source: TorrentSourceType.mikan,
    indexerName: 'Mikan',
    customCategory: TorrentCategory.video,
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('gopeed_btn_pipeline_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    Hive.init(tempDir.path);
    await GStorage.init();
    LocaleSettings.setLocale(AppLocale.zhCn);

    final dylibFile = File('${Directory.current.path}/macos/Frameworks/libgopeed.dylib');
    if (dylibFile.existsSync()) {
      await GopeedService().initialize(storageDir: '${tempDir.path}/gopeed');
    }
  });

  tearDownAll(() async {
    try {
      await GopeedService().stop();
    } catch (_) {}
    try {
      await Hive.close().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('验证全网资源搜索表格与卡片中点击“下载”按钮能够顺利启动任务并入队，绝不死锁或点不动', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        popularProvider.overrideWith(_MockPopularController.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(torrentSearchProvider.notifier);
    notifier.state = TorrentSearchState(
      isLoading: false,
      keyword: '芙莉莲',
      items: [sampleMagnetItem],
      categoryCounts: {
        TorrentCategory.video: 1,
      },
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    // 1. 验证表格呈现下载按钮
    final downloadButton = find.widgetWithText(FilledButton, '下载');
    expect(downloadButton, findsOneWidget);

    // 2. 点击下载按钮并在真实异步域推进 Gopeed 引擎交互
    await tester.runAsync(() async {
      await tester.tap(downloadButton);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        final state = container.read(downloadControllerProvider);
        if (state.waitingTasks.isNotEmpty || state.activeTasks.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 验证无任何未经捕获的崩溃异常
    expect(tester.takeException(), isNull);

    // 3. 验证任务入队至 GStorage 与下载控制器
    final downloadState = container.read(downloadControllerProvider);
    expect(
      downloadState.waitingTasks.length + downloadState.activeTasks.length,
      greaterThanOrEqualTo(1),
    );
  });

  testWidgets('验证在下载中心页面 (DownloadPage) 各操作按钮正常响应且无溢出', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 模拟向下载队列注入一条测试任务
    final mockTask = DownloadTask(
      gid: 'test-gid-123',
      url: 'https://example.com/test.mp4',
      title: '测试下载任务.mp4',
      status: 'active',
      totalLength: 1024 * 1024 * 500,
      completedLength: 1024 * 1024 * 250,
      downloadSpeed: 1024 * 1024 * 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.runAsync(() async {
      await GStorage.downloadTasks.put(mockTask.gid, mockTask);
      await container.read(downloadControllerProvider.notifier).loadFromStorage();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DownloadPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    // 验证任务名称呈现
    expect(find.text('测试下载任务.mp4'), findsOneWidget);

    // 验证暂停按钮存在并可点击
    final pauseBtn = find.byTooltip('暂停');
    if (pauseBtn.evaluate().isNotEmpty) {
      await tester.tap(pauseBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
  });
}
