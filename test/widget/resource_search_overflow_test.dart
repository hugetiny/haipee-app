import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/pages/resource/resource_search_content.dart';
import 'package:haipee/utils/storage.dart';

import 'package:haipee/pages/popular/popular_controller.dart';
import 'package:haipee/pages/popular/providers.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';

class _MockTorrentSearchNotifier extends TorrentSearchNotifier {
  final TorrentSearchState initialState;
  _MockTorrentSearchNotifier(this.initialState);

  @override
  TorrentSearchState build() => initialState;
}

class _MockPopularController extends PopularController {
  @override
  PopularState build() => PopularState(
        trendList: [
          BangumiItem.fromJson({
            'id': 1,
            'name': 'dummy',
            'type': 2,
            'name_cn': '测试番剧',
            'summary': '测试',
            'date': '2024-01-01',
            'images': {
              'large': '',
              'common': '',
              'medium': '',
              'small': '',
              'grid': '',
            },
          }),
        ],
      );
}

void main() {
  late Directory tempDir;

  final sampleVideoItem = TorrentItem(
    title: '[ANi] 葬送的芙莉莲 - 28 [1080P][Baha][WEB-DL][AAC TC][MP4] (Sousou no Frieren)',
    magnetUrl: 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678',
    pageUrl: 'https://mikanani.me/Home/Episode/12345',
    fileSize: '1.42 GB',
    sizeBytes: 1524678900,
    seeders: 320,
    leechers: 15,
    publishDate: '4小时前',
    source: TorrentSourceType.mikan,
    customCategory: TorrentCategory.video,
    resolution: '1080P',
    codec: 'H.264',
    mediaSource: 'WEB-DL',
    subgroup: 'ANi',
    isFreeleech: true,
  );

  final sampleNonVideoItem = TorrentItem(
    title: 'Ubuntu 24.04 LTS Desktop amd64 ISO Image Release Official',
    magnetUrl: 'magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12',
    fileSize: '5.80 GB',
    sizeBytes: 6228300000,
    seeders: 1200,
    leechers: 45,
    publishDate: '2天前',
    source: TorrentSourceType.cardigann,
    indexerName: 'UbuntuTracker',
    customCategory: TorrentCategory.software,
  );

  final sampleAudioItem = TorrentItem(
    title: 'YOASOBI - THE BOOK 3 [Hi-Res FLAC 24bit/96kHz] (Lossless Album)',
    magnetUrl: 'magnet:?xt=urn:btih:9876543210fedcba9876543210fedcba98765432',
    fileSize: '650 MB',
    sizeBytes: 681574400,
    seeders: 150,
    leechers: 8,
    publishDate: '1天前',
    source: TorrentSourceType.cardigann,
    indexerName: 'MusicTracker',
    customCategory: TorrentCategory.audio,
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('resource_search_overflow_test');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('setting');
    GStorage.setting = box;
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('验证在桌面大屏 (1280x800) 下迅雷表格与操作列无 RenderFlex 溢出警告', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockState = TorrentSearchState(
      keyword: '芙莉莲',
      items: [sampleVideoItem, sampleNonVideoItem, sampleAudioItem],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentSearchProvider.overrideWith(() => _MockTorrentSearchNotifier(mockState)),
          popularProvider.overrideWith(_MockPopularController.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 检查是否有任何 FlutterError (包括 RenderFlex overflow)
    expect(tester.takeException(), isNull);

    // 验证表格展示内容与操作列按钮
    expect(find.text('操作'), findsOneWidget);
    expect(find.text('下载'), findsWidgets);
    expect(find.text('在线看'), findsOneWidget); // 仅视频项目显示在线看
    expect(find.text('在线听'), findsOneWidget); // 仅音频/音乐项目显示在线听
    expect(find.text('1.42 GB'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_browser), findsOneWidget); // 具有 pageUrl 的项目显示在浏览器打开按钮

    // 点击第一行（选中状态），触发底部状态栏选中高亮
    await tester.tap(find.text('1.42 GB'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 再次确认底部状态栏更新后无溢出
    expect(tester.takeException(), isNull);
    expect(find.textContaining('已选中:'), findsOneWidget);
  });

  testWidgets('验证在窄屏移动端 (360x700) 下卡片视图与操作按钮无 RenderFlex 溢出警告', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockState = TorrentSearchState(
      keyword: '芙莉莲',
      items: [sampleVideoItem, sampleNonVideoItem, sampleAudioItem],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentSearchProvider.overrideWith(() => _MockTorrentSearchNotifier(mockState)),
          popularProvider.overrideWith(_MockPopularController.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );

    // 窄屏卡片视图下无任何溢出，第一项视频有在线看，原始发布页 URL 与按钮完整呈现
    expect(tester.takeException(), isNull);
    expect(find.text('立即下载'), findsWidgets);
    expect(find.text('在线看'), findsOneWidget);
    expect(find.text('https://mikanani.me/Home/Episode/12345'), findsOneWidget);
    expect(find.text('原始页面'), findsOneWidget);

    // 向下滚动显示第三项音频卡片
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('在线听'), findsOneWidget);
  });

  testWidgets('验证在大字体缩放 (1.4x) 与中等屏幕 (900x600) 下表格行各单元格能自适应缩放且不溢出', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockState = TorrentSearchState(
      keyword: '芙莉莲',
      items: [sampleVideoItem, sampleNonVideoItem],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentSearchProvider.overrideWith(() => _MockTorrentSearchNotifier(mockState)),
          popularProvider.overrideWith(_MockPopularController.new),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 确保在大字体缩放 1.4x 下依然 0 溢出
    expect(tester.takeException(), isNull);
    expect(find.text('操作'), findsOneWidget);
    expect(find.text('下载'), findsWidgets);
  });

  testWidgets('验证响应式断点 (>=700 表格 / <700 卡片) 自动随窗口大小动态切换', (tester) async {
    // 1. 初始化为宽屏 1024x768
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockState = TorrentSearchState(
      keyword: '芙莉莲',
      items: [sampleVideoItem, sampleNonVideoItem],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentSearchProvider.overrideWith(() => _MockTorrentSearchNotifier(mockState)),
          popularProvider.overrideWith(_MockPopularController.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceSearchContent(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 宽屏时自动呈现表格视图，显示模式提示为自适应(表格)
    expect(find.text('自适应 (表格)'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
    expect(find.text('做种数'), findsOneWidget);

    // 2. 动态改变窗口尺寸至窄屏 600x768 (< 700.0 断点)
    tester.view.physicalSize = const Size(600, 768);
    await tester.pumpAndSettle();

    // 窄屏时自动动态切换为卡片视图，显示模式提示为自适应(卡片)
    expect(find.text('自适应 (卡片)'), findsOneWidget);
    expect(find.text('立即下载'), findsWidgets);
    expect(find.text('做种数'), findsNothing); // 表格表头在卡片模式下不存在

    // 3. 再次扩大窗口至宽屏 1200x768
    tester.view.physicalSize = const Size(1200, 768);
    await tester.pumpAndSettle();

    // 自动切回表格视图
    expect(find.text('自适应 (表格)'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
  });
}
