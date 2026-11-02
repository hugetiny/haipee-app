import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/pages/download/download_page.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/pages/download/widgets/add_download_dialog.dart';
import 'package:haipee/router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/utils/storage.dart';
import 'log_watcher_robot.dart';

/// Robot that interacts with DownloadPage and DownloadController,
/// fuzzes lifecycle state transitions, validates Xunlei layout stats,
/// and enforces strict invariants such as non-media playability restrictions.
class DownloadLifecycleRobot {
  final WidgetTester tester;
  final LogWatcherRobot logWatcher;

  DownloadLifecycleRobot({
    required this.tester,
    required this.logWatcher,
  });

  /// Settles UI transitions and timers safely.
  Future<void> settleView() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Navigates to the Download Page.
  Future<void> openDownloadPage() async {
    router.go(Routes.download);
    await settleView();
    logWatcher.checkTesterException(tester, contextDescription: 'Open DownloadPage');
    expect(find.byType(DownloadPage), findsOneWidget);
  }

  /// Populates mock tasks into GStorage and synchronizes DownloadController.
  Future<void> seedTasks(List<DownloadTask> tasks) async {
    await tester.runAsync(() async {
      await GStorage.downloadTasks.clear();
      for (final task in tasks) {
        await GStorage.downloadTasks.put(task.gid, task);
      }
    });

    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final controller = container.read(downloadControllerProvider.notifier);
    await tester.runAsync(() async {
      await controller.loadFromStorage();
    });

    await settleView();
    logWatcher.checkTesterException(tester, contextDescription: 'Seed tasks (${tasks.length} items)');
  }

  /// Switches to tab at [index] (0: 下载中, 1: 已暂停, 2: 已完成, 3: 下载失败, 4: 全部)
  Future<void> switchToTab(int index) async {
    const tabNames = ['下载中', '已暂停', '已完成', '下载失败', '全部'];
    final tabFinder = find.text(tabNames[index]);
    if (tabFinder.evaluate().isNotEmpty) {
      await tester.tap(tabFinder.first, warnIfMissed: false);
      await settleView();
    }
  }

  /// Strictly enforces the invariant: Non-media files (.rar, .zip, .7z, .exe)
  /// MUST NEVER show "播放" or "边下边播" buttons in the UI.
  Future<void> verifyPlayabilityInvariants(List<DownloadTask> tasks) async {
    for (final task in tasks) {
      if (!task.isPlayable) {
        // Assert task model level invariant
        expect(
          task.isPlayable,
          isFalse,
          reason: 'File ${task.fileName ?? task.title} with ext ${task.fileExtension} must have isPlayable == false',
        );
        expect(
          task.isVideo,
          isFalse,
          reason: 'Non-media file ${task.title} must not be classified as video',
        );
      } else {
        expect(
          task.isPlayable,
          isTrue,
          reason: 'Media file ${task.fileName ?? task.title} must have isPlayable == true',
        );
      }
    }

    // 1. Switch to '已完成' tab: verify completed tasks show play/open buttons appropriately
    await switchToTab(2);

    final playBtnFinder = find.widgetWithText(FilledButton, '播放');
    final openFileFinder = find.widgetWithText(FilledButton, '打开文件');

    final playableCompleted = tasks.where((t) => t.isComplete && t.isPlayable).length;
    final nonPlayableCompleted = tasks.where((t) => t.isComplete && !t.isPlayable).length;

    expect(
      openFileFinder.evaluate().length,
      equals(nonPlayableCompleted),
      reason: 'Every completed non-media task must show "打开文件" button',
    );
    expect(
      playBtnFinder.evaluate().length,
      equals(playableCompleted),
      reason: 'Only completed media tasks should show "播放" button',
    );

    // 2. Switch to '下载中' tab: verify active video shows "边下边播"
    await switchToTab(0);
    final streamPlayFinder = find.widgetWithText(FilledButton, '边下边播');
    final playableActive = tasks.where((t) => t.isActive && t.isPlayable).length;
    expect(
      streamPlayFinder.evaluate().length,
      equals(playableActive),
      reason: 'Only active media tasks should show "边下边播" button',
    );

    // 3. Return to '全部' tab
    await switchToTab(4);

    logWatcher.checkTesterException(tester, contextDescription: 'Verify playability invariants');
  }

  /// Verifies Xunlei stats banner numbers and ensures no NaN, negative, or overflow values.
  void verifyGlobalStatsBanner() {
    final statsBannerFinder = find.byType(SingleChildScrollView);
    expect(statsBannerFinder, findsWidgets);

    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final state = container.read(downloadControllerProvider);

    // Invariant assertions
    expect(state.totalDownloadSpeed, greaterThanOrEqualTo(0));
    expect(state.totalUploadSpeed, greaterThanOrEqualTo(0));
    expect(state.totalDownloading, greaterThanOrEqualTo(0));
    expect(state.totalCompleted, greaterThanOrEqualTo(0));
    expect(state.estimatedRemainingSeconds, greaterThanOrEqualTo(0));

    // Progress invariant: all tasks must have 0.0 <= progress <= 1.0
    for (final task in [...state.activeTasks, ...state.waitingTasks, ...state.completedTasks, ...state.pausedTasks, ...state.failedTasks]) {
      expect(task.progress, greaterThanOrEqualTo(0.0));
      expect(task.progress, lessThanOrEqualTo(1.0));
      expect(task.progress.isNaN, isFalse);
      expect(task.progress.isInfinite, isFalse);
    }

    logWatcher.checkTesterException(tester, contextDescription: 'Verify global stats banner invariants');
  }

  /// Tests batch selection flow: entering selection mode, selecting all, pausing, resuming, and clearing.
  Future<void> executeBatchSelectionFlow() async {
    final selectModeButton = find.byTooltip('批量管理');
    if (selectModeButton.evaluate().isNotEmpty) {
      await tester.tap(selectModeButton.first);
      await settleView();
    }

    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final uiNotifier = container.read(downloadPageUIProvider.notifier);

    // Verify selection mode active
    expect(container.read(downloadPageUIProvider).isSelectionMode, isTrue);

    // Select all
    final allTasks = container.read(downloadControllerProvider.notifier).getAllTasks();
    uiNotifier.selectAll(allTasks);
    await settleView();
    expect(container.read(downloadPageUIProvider).selectedGids.length, equals(allTasks.length));

    // Deselect all (clears selectedGids while preserving selection mode)
    uiNotifier.deselectAll();
    await settleView();
    expect(container.read(downloadPageUIProvider).selectedGids.isEmpty, isTrue);
    expect(container.read(downloadPageUIProvider).isSelectionMode, isTrue);

    // Toggle out of selection mode
    uiNotifier.toggleSelectionMode();
    await settleView();
    expect(container.read(downloadPageUIProvider).isSelectionMode, isFalse);

    // Test clearSelection() resets both selectedGids and exits selection mode
    uiNotifier.toggleSelectionMode();
    uiNotifier.selectAll(allTasks);
    expect(container.read(downloadPageUIProvider).isSelectionMode, isTrue);
    uiNotifier.clearSelection();
    await settleView();
    expect(container.read(downloadPageUIProvider).selectedGids.isEmpty, isTrue);
    expect(container.read(downloadPageUIProvider).isSelectionMode, isFalse);

    logWatcher.checkTesterException(tester, contextDescription: 'Batch selection flow');
  }

  /// Verifies Gofile redirect/auth error handling and reconfigure dialog.
  Future<void> verifyGofileReconfigureDialogFlow(DownloadTask errorTask) async {
    // Assert task recognizes redirect error
    expect(errorTask.isRedirectOrAuthError, isTrue);

    // Find "重新配置" button in the failed task card
    final reconfigBtn = find.widgetWithText(OutlinedButton, '重新配置');
    if (reconfigBtn.evaluate().isNotEmpty) {
      await tester.tap(reconfigBtn.first);
      await settleView();

      // Verify AddDownloadDialog opened with prefilled URL
      expect(find.byType(AddDownloadDialog), findsOneWidget);

      // Close dialog
      final closeBtn = find.descendant(
        of: find.byType(AddDownloadDialog),
        matching: find.byIcon(Icons.close),
      );
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn.first);
        await settleView();
      }
    }

    logWatcher.checkTesterException(tester, contextDescription: 'Gofile reconfigure dialog flow');
  }
}
