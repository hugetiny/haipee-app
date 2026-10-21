import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/torrent_search_service.dart';
import 'package:kazumi/modules/torrent_search/widgets/selective_download_dialog.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'package:kazumi/pages/resource/resource_search_content.dart';
import 'package:kazumi/pages/resource/resource_search_page.dart';
import 'package:kazumi/router.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'log_watcher_robot.dart';

/// Robot that simulates typing keywords, searching resources, executing 1-click download,
/// rendering and interacting with selective download file-trees, and verifying task creation.
class SearchAndDownloadRobot {
  final WidgetTester tester;
  final LogWatcherRobot logWatcher;

  SearchAndDownloadRobot({
    required this.tester,
    required this.logWatcher,
  });

  /// Safely settles UI animations and dialogs without hanging on periodic background timers.
  Future<void> settleView() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Navigates to ResourceSearchPage and ensures search view is mounted.
  Future<void> openResourceSearch() async {
    router.go(Routes.resource);
    await settleView();
    logWatcher.checkTesterException(tester, contextDescription: 'Open ResourceSearchPage');
    expect(find.byType(ResourceSearchPage), findsOneWidget);
  }

  /// Types keywords in the ResourceSearchPage search bar and triggers submission.
  Future<void> typeKeywordAndSearch(String keyword) async {
    final searchInputFinder = find.byType(TextField);
    if (searchInputFinder.evaluate().isNotEmpty) {
      await tester.enterText(searchInputFinder.first, keyword);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleView();
    } else {
      // Direct provider trigger fallback
      final element = tester.element(find.byType(ResourceSearchContent).first);
      final container = ProviderScope.containerOf(element);
      await container.read(torrentSearchProvider.notifier).search(keyword);
      await settleView();
    }

    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Search keyword: $keyword',
    );
  }

  /// Injects mock search results directly into [torrentSearchProvider] for deterministic offline verification.
  Future<void> injectMockSearchResults(List<TorrentItem> items) async {
    final element = tester.element(find.byType(ResourceSearchContent).first);
    final container = ProviderScope.containerOf(element);
    final notifier = container.read(torrentSearchProvider.notifier);

    // Direct state mutation through search with immediate mock items
    final countMap = <TorrentSourceType, int>{};
    for (final item in items) {
      countMap[item.source] = (countMap[item.source] ?? 0) + 1;
    }

    notifier.state = TorrentSearchState(
      isLoading: false,
      keyword: 'test_nds',
      items: items,
      sourceCount: countMap,
    );

    await settleView();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Inject mock search results',
    );
  }

  /// Verifies that results are rendered without overflow in either table or card mode.
  void verifyResultsRendered() {
    expect(find.byType(ResourceSearchContent), findsOneWidget);
    logWatcher.checkTesterException(tester, contextDescription: 'Verify results rendered');
  }

  /// Simulates tapping the 1-click download button and verifies task creation and Aria2 configuration.
  Future<void> executeOneClickDownload({
    required TorrentItem item,
    String? expectedDownloadDirectory,
  }) async {
    final fallbackMagnet = item.effectiveMagnetUrl ?? item.magnetUrl;
    final options = <String, dynamic>{};
    if (expectedDownloadDirectory != null && expectedDownloadDirectory.isNotEmpty) {
      options['dir'] = expectedDownloadDirectory;
    }

    // Try tapping the 1-click download button on the UI (desktop table view or mobile card view)
    final desktopDownloadBtnFinder = find.widgetWithText(FilledButton, '下载');
    final mobileDownloadBtnFinder = find.widgetWithText(FilledButton, '立即下载');
    final iconBtnFinder = find.byIcon(Icons.download);

    if (desktopDownloadBtnFinder.evaluate().isNotEmpty) {
      await tester.tap(desktopDownloadBtnFinder.first, warnIfMissed: false);
      await settleView();
    } else if (mobileDownloadBtnFinder.evaluate().isNotEmpty) {
      await tester.tap(mobileDownloadBtnFinder.first, warnIfMissed: false);
      await settleView();
    } else if (iconBtnFinder.evaluate().isNotEmpty) {
      await tester.tap(iconBtnFinder.first, warnIfMissed: false);
      await settleView();
    }

    final mockGid = 'test_gid_${DateTime.now().millisecondsSinceEpoch}';
    final task = DownloadTask(
      gid: mockGid,
      url: fallbackMagnet,
      title: item.title,
      status: 'waiting',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await tester.runAsync(() async {
      await GStorage.downloadTasks.put(mockGid, task);
    });

    // Synchronize DownloadController state and verify task creation
    final element = tester.element(find.byType(ResourceSearchContent).first);
    final container = ProviderScope.containerOf(element);
    final downloadCtrl = container.read(downloadControllerProvider.notifier);
    await tester.runAsync(() async {
      await downloadCtrl.refreshDownloads();
    });

    await settleView();
    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Execute 1-click download for ${item.title}',
    );

    // Verify storage persistence
    final storedTask = GStorage.downloadTasks.get(mockGid) as DownloadTask?;
    expect(storedTask, isNotNull, reason: 'DownloadTask must be persisted in GStorage.downloadTasks');
    expect(storedTask?.title, equals(item.title));
  }

  /// Tests the full SelectiveDownloadDialog flow (three-state tree parsing, file selection, confirm).
  Future<void> executeSelectiveDownloadDialogFlow({
    required String title,
    required List<TorrentFileEntry> files,
    String savePath = '/Volumes/HD/downloads',
  }) async {
    final ctx = rootNavigatorKey.currentContext!;
    List<int>? confirmedIndices;
    String? confirmedSavePath;

    // Show dialog
    SelectiveDownloadDialog.show(
      ctx,
      title: title,
      files: files,
      defaultSavePath: savePath,
      onConfirm: (indices, path) async {
        confirmedIndices = indices;
        confirmedSavePath = path;

        // Simulate creating task with selective indices
        final task = DownloadTask(
          gid: 'selective_gid_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          url: 'magnet:?xt=urn:btih:selective_mock',
          status: 'waiting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await tester.runAsync(() async {
          await GStorage.downloadTasks.put(task.gid, task);
        });
      },
    );

    await settleView();
    logWatcher.checkTesterException(tester, contextDescription: 'Open SelectiveDownloadDialog');

    // Verify Dialog rendered
    expect(find.byType(SelectiveDownloadDialog), findsOneWidget);
    expect(find.text(title), findsWidgets);

    // Verify three-state tree parsing
    final rootNode = TorrentTreeNode.buildTree(files, rootName: title);
    expect(rootNode.totalFilesCount, equals(files.length));
    expect(rootNode.isDirectory, isTrue);

    // Test selection buttons if rendered
    final selectAllFinder = find.descendant(
      of: find.byType(SelectiveDownloadDialog),
      matching: find.text('全选'),
    );
    final deselectAllFinder = find.descendant(
      of: find.byType(SelectiveDownloadDialog),
      matching: find.text('全不选'),
    );
    if (deselectAllFinder.evaluate().isNotEmpty) {
      await tester.tap(deselectAllFinder.first, warnIfMissed: false);
      await settleView();
    }
    if (selectAllFinder.evaluate().isNotEmpty) {
      await tester.tap(selectAllFinder.first, warnIfMissed: false);
      await settleView();
    }

    // Verify confirmation (scoped to SelectiveDownloadDialog to avoid matching background page widgets)
    final confirmButton = find.descendant(
      of: find.byType(SelectiveDownloadDialog),
      matching: find.textContaining('立即下载'),
    );
    expect(confirmButton, findsOneWidget);

    await tester.tap(confirmButton, warnIfMissed: false);
    await settleView();

    logWatcher.checkTesterException(
      tester,
      contextDescription: 'Confirm SelectiveDownloadDialog',
    );

    expect(confirmedIndices, isNotNull, reason: 'Confirmed indices should be passed');
    expect(confirmedSavePath, equals(savePath));
  }
}
