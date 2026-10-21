import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/bean/card/staff_card.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/bean/widget/bangumi_context_menu.dart';
import 'package:kazumi/bean/widget/rule/unified_rule_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/characters/actor_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/bean/widget/download_context_menu.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/my/providers.dart';
import 'package:kazumi/utils/storage.dart';

class _FakeDownloadController extends Fake implements DownloadController {
  @override
  Future<void> pauseDownload(String gid) async {}

  @override
  Future<void> resumeDownload(String gid) async {}

  @override
  Future<void> retryDownload(DownloadTask task) async {}

  @override
  Future<void> removeDownload(String gid, {bool deleteFile = false, bool force = false}) async {}
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final _transparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('context_menu_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(BangumiTagAdapter());
    Hive.registerAdapter(CollectedBangumiAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles = await Hive.openBox('collectibles');
    GStorage.histories = await Hive.openBox('histories');
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  final testBangumi = BangumiItem(
    id: 99999,
    type: 2,
    name: 'Frieren: Beyond Journey\'s End',
    nameCn: '葬送的芙莉莲',
    summary: '千年精灵芙莉莲的故事',
    airDate: '2023-09-29',
    airWeekday: 5,
    rank: 1,
    images: {'large': ''},
    tags: [],
    alias: [],
    ratingScore: 9.3,
    votes: 50000,
    votesCount: [],
    info: '全28话',
  );

  group('Desktop & Adaptive Context Menu Interaction Tests', () {
    testWidgets('AppContextMenu triggers menu on secondary tap (right click)', (tester) async {
      bool actionInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppContextMenu(
              itemsBuilder: (context) => [
                AppMenuAction(
                  title: '动作A',
                  shortcutHint: '⌘A',
                  onSelected: () {
                    actionInvoked = true;
                  },
                ),
                AppMenuAction(
                  title: '动作B',
                  onSelected: () {},
                ),
              ],
              child: const SizedBox(
                width: 200,
                height: 100,
                child: Text('Right Click Target'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Right Click Target'), findsOneWidget);
      expect(find.text('动作A'), findsNothing);

      // 模拟桌面端鼠标右键次级点击 (Secondary Click)
      final center = tester.getCenter(find.text('Right Click Target'));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      // 菜单弹出层展示
      expect(find.text('动作A'), findsOneWidget);
      expect(find.text('动作B'), findsOneWidget);
      expect(find.text('⌘A'), findsOneWidget);

      // 点击菜单项触发 action
      await tester.tap(find.text('动作A'));
      await tester.pumpAndSettle();

      expect(actionInvoked, isTrue);
      // 菜单关闭
      expect(find.text('动作A'), findsNothing);
    });

    testWidgets('AppContextMenu triggers menu on long press (mobile touch parity)', (tester) async {
      bool actionInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppContextMenu(
              itemsBuilder: (context) => [
                AppMenuAction(
                  title: '长按操作',
                  onSelected: () {
                    actionInvoked = true;
                  },
                ),
              ],
              child: const SizedBox(
                width: 200,
                height: 100,
                child: Text('Long Press Target'),
              ),
            ),
          ),
        ),
      );

      // 模拟移动端长按
      await tester.longPress(find.text('Long Press Target'));
      await tester.pumpAndSettle();

      expect(find.text('长按操作'), findsOneWidget);
      await tester.tap(find.text('长按操作'));
      await tester.pumpAndSettle();

      expect(actionInvoked, isTrue);
    });

    testWidgets('DesktopContextMenu alias functions identically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopContextMenu(
              itemsBuilder: (context) => [
                AppMenuAction(
                  title: '桌面专属菜单',
                  onSelected: () {},
                ),
              ],
              child: const Text('Alias Target'),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Alias Target'));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('桌面专属菜单'), findsOneWidget);
    });

    testWidgets('AppContextMenu with enableLongPress: false suppresses long press menu trigger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppContextMenu(
              enableLongPress: false,
              itemsBuilder: (context) => [
                AppMenuAction(
                  title: '长按操作',
                  onSelected: () {},
                ),
              ],
              child: const SizedBox(
                width: 200,
                height: 100,
                child: Text('No Long Press Target'),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('No Long Press Target'));
      await tester.pumpAndSettle();

      expect(find.text('长按操作'), findsNothing);
    });
  });

  group('BangumiContextMenuHelper Semantic Specification Tests', () {
    testWidgets('BangumiContextMenuHelper builds full menu actions without history', (tester) async {
      late List<AppMenuItem> generatedItems;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  generatedItems = BangumiContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    bangumiItem: testBangumi,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final titles = generatedItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final submenus = generatedItems.whereType<AppMenuSubmenu>().map((s) => s.title).toList();

      // 无历史记录时提供 "立即观看"
      expect(titles, contains('立即观看'));
      expect(titles, contains('查看番剧详情'));
      expect(titles, contains('检索磁力/离线下载...'));
      expect(titles, contains('复制番剧名称'));
      expect(titles, contains('复制原名 (Frieren: Beyond Journey\'s End)'));
      expect(titles, contains('复制 Bangumi ID (99999)'));
      expect(titles, contains('复制 Bangumi 网页链接'));
      expect(titles, contains('在浏览器中打开 Bangumi 主页'));

      // 未追番时提供 "添加追番" 子菜单
      expect(submenus, contains('添加追番'));
    });

    testWidgets('BangumiContextMenuHelper integrates watching history and collect modification', (tester) async {
      final sampleHistory = History(
        testBangumi,
        12,
        'test_adapter',
        DateTime.now(),
        'https://example.com/stream.m3u8',
        '第12话 真实的魔法使',
      );

      late List<AppMenuItem> generatedItems;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  // 设置为 "在看" 状态
                  ref.read(collectionsProvider.notifier).addCollect(testBangumi, type: 1);

                  generatedItems = BangumiContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    bangumiItem: testBangumi,
                    explicitHistoryItem: sampleHistory,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final titles = generatedItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final submenus = generatedItems.whereType<AppMenuSubmenu>().map((s) => s.title).toList();

      // 有历史记录时提供 "继续观看" 和 "移出观看历史"
      expect(titles, contains('继续观看 (第12话 真实的魔法使)'));
      expect(titles, contains('移出观看历史'));

      // 处于追番状态时提供 "修改追番 (在看)" 和 "取消追番"
      expect(submenus, contains('修改追番 (在看)'));
      expect(titles, contains('取消追番'));
    });
  });

  group('Card Component Context Menu Integration Tests', () {
    testWidgets('UnifiedRuleCard mounts AppContextMenu via contextMenuBuilder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedRuleCard(
              title: '测试聚合规则',
              url: 'https://example.com/rule',
              onTap: () {},
              contextMenuBuilder: (context) => [
                AppMenuAction(
                  title: '测试抓取 (Dry-Run)',
                  onSelected: () {},
                ),
                AppMenuAction(
                  title: '导出 YAML',
                  onSelected: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('测试聚合规则'), findsOneWidget);

      final center = tester.getCenter(find.text('测试聚合规则'));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('测试抓取 (Dry-Run)'), findsOneWidget);
      expect(find.text('导出 YAML'), findsOneWidget);
    });

    testWidgets('CharacterCard secondary click renders character context menu', (tester) async {
      final character = CharacterItem(
        id: 101,
        type: 1,
        name: '芙莉莲',
        relation: '主角',
        avator: CharacterAvator(small: '', medium: '', grid: '', large: ''),
        actorList: [
          ActorItem(
            id: 201,
            type: 1,
            name: '种崎敦美',
            avator: ActorAvator(small: '', medium: '', grid: '', large: ''),
          ),
        ],
        info: CharacterExtraInfo(nameCn: '芙莉莲', summary: '千年精灵魔法使'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterCard(characterItem: character),
          ),
        ),
      );

      expect(find.text('芙莉莲'), findsOneWidget);

      final center = tester.getCenter(find.text('芙莉莲'));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('查看角色详情'), findsOneWidget);
      expect(find.text('复制角色名称'), findsOneWidget);
      expect(find.text('复制声优 (种崎敦美)'), findsOneWidget);
      expect(find.text('在浏览器中打开 Bangumi 页面'), findsOneWidget);
    });

    testWidgets('StaffCard secondary click renders staff context menu', (tester) async {
      final staff = StaffFullItem(
        staff: Staff(
          id: 301,
          name: '斋藤圭一郎',
          nameCN: '斋藤圭一郎',
          type: 1,
          info: '动画监督',
          comment: 300,
          lock: false,
          nsfw: false,
        ),
        positions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffCard(staffFullItem: staff),
          ),
        ),
      );

      expect(find.text('斋藤圭一郎'), findsWidgets);

      final center = tester.getCenter(find.text('斋藤圭一郎').first);
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('复制演职员名称'), findsOneWidget);
      expect(find.text('在浏览器中打开 Bangumi 页面'), findsOneWidget);
    });

    testWidgets('BangumiCardV secondary click renders context menu without assertion error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 350,
                child: BangumiCardV(bangumiItem: testBangumi),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(BangumiCardV));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('查看番剧详情'), findsOneWidget);
      expect(find.text('立即观看'), findsOneWidget);
    });

    testWidgets('BangumiInfoCardV secondary click renders context menu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 350,
                child: BangumiInfoCardV(
                  bangumiItem: testBangumi,
                  isLoading: false,
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(BangumiInfoCardV));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('查看番剧详情'), findsOneWidget);
      expect(find.text('检索磁力/离线下载...'), findsOneWidget);
      expect(find.text('复制番剧名称'), findsOneWidget);
    });

    testWidgets('Download task context menu dynamically generates actions matching lifecycle states', (tester) async {
      final now = DateTime.now();
      final completePlayableTask = DownloadTask(
        gid: 'gid-complete',
        title: 'Frieren EP12.mp4',
        fileName: 'Frieren EP12.mp4',
        status: 'complete',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 500,
        completedLength: 1024 * 1024 * 500,
        downloadSpeed: 0,
        uploadSpeed: 0,
        url: 'https://example.com/frieren.mp4',
      );

      final completeNonPlayableTask = DownloadTask(
        gid: 'gid-zip',
        title: 'Frieren EP12_Subs.zip',
        fileName: 'Frieren EP12_Subs.zip',
        status: 'complete',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 5,
        completedLength: 1024 * 1024 * 5,
        downloadSpeed: 0,
        uploadSpeed: 0,
        url: 'https://example.com/subs.zip',
      );

      final activeTask = DownloadTask(
        gid: 'gid-active',
        title: 'Frieren EP13.mp4',
        fileName: 'Frieren EP13.mp4',
        status: 'active',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 500,
        completedLength: 1024 * 1024 * 100,
        downloadSpeed: 1024 * 1024 * 2,
        uploadSpeed: 0,
        url: 'https://example.com/frieren13.mp4',
      );

      final pausedTask = DownloadTask(
        gid: 'gid-paused',
        title: 'Frieren EP14.mp4',
        fileName: 'Frieren EP14.mp4',
        status: 'paused',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 500,
        completedLength: 1024 * 1024 * 100,
        downloadSpeed: 0,
        uploadSpeed: 0,
        url: 'https://example.com/frieren14.mp4',
      );

      final waitingTask = DownloadTask(
        gid: 'gid-waiting',
        title: 'Frieren EP15.mp4',
        fileName: 'Frieren EP15.mp4',
        status: 'waiting',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 500,
        completedLength: 0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        url: 'https://example.com/frieren15.mp4',
      );

      final errorAuthTask = DownloadTask(
        gid: 'gid-error',
        title: 'Frieren EP16.mp4',
        fileName: 'Frieren EP16.mp4',
        status: 'error',
        createdAt: now,
        updatedAt: now,
        totalLength: 1024 * 1024 * 500,
        completedLength: 0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        url: 'https://example.com/frieren16.mp4',
        errorMessage: '下载异常：重定向网页',
      );

      late List<AppMenuItem> completeItems;
      late List<AppMenuItem> nonPlayableItems;
      late List<AppMenuItem> activeItems;
      late List<AppMenuItem> pausedItems;
      late List<AppMenuItem> waitingItems;
      late List<AppMenuItem> errorItems;

      final fakeController = _FakeDownloadController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  completeItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: completePlayableTask,
                    controller: fakeController,
                    isActive: false,
                  );
                  nonPlayableItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: completeNonPlayableTask,
                    controller: fakeController,
                    isActive: false,
                  );
                  activeItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: activeTask,
                    controller: fakeController,
                    isActive: true,
                  );
                  pausedItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: pausedTask,
                    controller: fakeController,
                    isActive: false,
                  );
                  waitingItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: waitingTask,
                    controller: fakeController,
                    isActive: false,
                  );
                  errorItems = DownloadContextMenuHelper.buildMenuItems(
                    context: context,
                    ref: ref,
                    task: errorAuthTask,
                    controller: fakeController,
                    isActive: false,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final completeTitles = completeItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final nonPlayableTitles = nonPlayableItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final activeTitles = activeItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final pausedTitles = pausedItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final waitingTitles = waitingItems.whereType<AppMenuAction>().map((a) => a.title).toList();
      final errorTitles = errorItems.whereType<AppMenuAction>().map((a) => a.title).toList();

      // 1. 完成的视频任务：播放、外部程序打开、定位、重新下载、属性、复制路径/URL/标题、选择、删除
      expect(completeTitles, contains('播放视频/音频'));
      expect(completeTitles, contains('使用外部程序打开文件'));
      expect(completeTitles, contains('在访达 / 资源管理器中显示'));
      expect(completeTitles, contains('重新下载'));
      expect(completeTitles, contains('任务详情属性...'));
      expect(completeTitles, contains('复制文件完整路径'));
      expect(completeTitles, contains('复制下载链接'));
      expect(completeTitles, contains('复制任务标题'));
      expect(completeTitles, contains('选择此任务'));
      expect(completeTitles, contains('删除任务'));
      expect(completeTitles, isNot(contains('暂停下载')));
      expect(completeTitles, isNot(contains('继续下载')));
      expect(completeTitles, isNot(contains('边下边播')));

      // 2. 完成的非媒体任务（如 zip）：使用外部程序打开为 "打开文件"，且不含播放选项
      expect(nonPlayableTitles, contains('打开文件'));
      expect(nonPlayableTitles, isNot(contains('播放视频/音频')));

      // 3. 下载中任务 (Active)：包含边下边播、暂停下载，不含继续下载
      expect(activeTitles, contains('边下边播'));
      expect(activeTitles, contains('暂停下载'));
      expect(activeTitles, isNot(contains('继续下载')));

      // 4. 已暂停任务 (Paused)：包含继续下载，不含暂停下载与边下边播
      expect(pausedTitles, contains('继续下载'));
      expect(pausedTitles, isNot(contains('暂停下载')));

      // 5. 等待中任务 (Waiting)：包含暂停下载
      expect(waitingTitles, contains('暂停下载'));

      // 6. 鉴权失败/重定向异常任务 (Error)：包含重试下载以及重新配置参数
      expect(errorTitles, contains('重试下载'));
      expect(errorTitles, contains('重新配置鉴权/参数...'));
    });

    testWidgets('Torrent card context menu builds complete P2P action set', (tester) async {
      const torrentItem = TorrentItem(
        title: '[Mikan-Project] Frieren EP12 [1080p].mp4',
        magnetUrl: 'magnet:?xt=urn:btih:abcdef1234567890',
        pageUrl: 'https://mikanani.me/Home/Episode/12345',
        source: TorrentSourceType.mikan,
        seeders: 42,
        fileSize: '450.2 MB',
      );

      String? clickedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppContextMenu(
              itemsBuilder: (context) => [
                AppMenuAction(
                  title: '极速下载',
                  onSelected: () => clickedAction = 'download_${torrentItem.source.name}',
                ),
                AppMenuAction(
                  title: '选择性下载 (迅雷树)...',
                  onSelected: () {},
                ),
                AppMenuAction(
                  title: '边下边播 (首尾关键帧优先)',
                  onSelected: () {},
                ),
                const AppMenuSeparator(),
                AppMenuAction(
                  title: '复制磁力链接',
                  onSelected: () => clickedAction = torrentItem.magnetUrl,
                ),
                AppMenuAction(
                  title: '复制资源全称',
                  onSelected: () => clickedAction = torrentItem.title,
                ),
                if (torrentItem.pageUrl != null)
                  AppMenuAction(
                    title: '在浏览器中打开原始发布页',
                    onSelected: () => clickedAction = torrentItem.pageUrl,
                  ),
              ],
              child: const Text('Torrent Card Target'),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Torrent Card Target'));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('极速下载'), findsOneWidget);
      expect(find.text('选择性下载 (迅雷树)...'), findsOneWidget);
      expect(find.text('边下边播 (首尾关键帧优先)'), findsOneWidget);
      expect(find.text('复制磁力链接'), findsOneWidget);
      expect(find.text('复制资源全称'), findsOneWidget);
      expect(find.text('在浏览器中打开原始发布页'), findsOneWidget);

      await tester.tap(find.text('复制磁力链接'));
      await tester.pumpAndSettle();
      expect(clickedAction, 'magnet:?xt=urn:btih:abcdef1234567890');
    });
  });
}
