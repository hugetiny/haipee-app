import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/download/providers.dart';
import 'log_watcher_robot.dart';

/// Automated Fuzz and Invariant Hunter Robot based on modern Flutter testing paradigms:
/// 1. Chaos Viewport & Accessibility Text Scale Fuzzing
/// 2. Concurrent State Machine & Mutation Fuzzing
/// 3. Malformed String & Boundary Input Fuzzing
/// 4. Invariant Assertion Engine (mutually exclusive states, clamp invariants)
class FuzzAndInvariantHunterRobot {
  final WidgetTester tester;
  final LogWatcherRobot logWatcher;

  FuzzAndInvariantHunterRobot({
    required this.tester,
    required this.logWatcher,
  });

  /// Settles UI transitions safely.
  Future<void> settle() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 1. Fuzzes multiple extreme viewports and accessibility text scales.
  Future<void> fuzzViewportsAndTextScales({
    required List<Size> testSizes,
    List<double> textScales = const [1.0, 1.3, 1.6],
  }) async {
    for (final size in testSizes) {
      for (final scale in textScales) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;

        await tester.pump();
        await settle();

        logWatcher.checkTesterException(
          tester,
          contextDescription: 'Viewport Fuzz: ${size.width.toInt()}x${size.height.toInt()} @ ${scale}x scale',
        );

        // Assert widget tree presence
        expect(find.byType(DownloadPage), findsOneWidget);
      }
    }

    // Reset test values
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await settle();
  }

  /// 2. Fuzzes download controller state mutations (speed bursts, zero-length files, boundary progress).
  Future<void> fuzzTaskStateMutations({int iterations = 30}) async {
    final rnd = Random(42);
    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final controller = container.read(downloadControllerProvider.notifier);

    for (int i = 0; i < iterations; i++) {
      final totalLen = rnd.nextBool() ? rnd.nextInt(100000000) : (rnd.nextBool() ? 0 : -100);
      final completedLen = rnd.nextInt(200000000);
      final speed = rnd.nextBool() ? rnd.nextInt(50000000) : -10;
      final statuses = ['active', 'waiting', 'paused', 'error', 'complete', 'removed', 'unknown_state'];
      final chosenStatus = statuses[rnd.nextInt(statuses.length)];

      final fuzzedTask = DownloadTask(
        gid: 'fuzz_task_$i',
        url: 'https://example.com/item_$i.dat',
        title: 'Fuzzed Task #$i [${rnd.nextInt(9999)}]',
        fileName: 'item_$i.bin',
        totalLength: totalLen,
        completedLength: completedLen,
        downloadSpeed: speed < 0 ? 0 : speed,
        status: chosenStatus,
        createdAt: DateTime.now().subtract(Duration(minutes: rnd.nextInt(1000))),
        updatedAt: DateTime.now(),
      );

      // Invariant checks on task model
      expect(
        fuzzedTask.progress,
        greaterThanOrEqualTo(0.0),
        reason: 'Task progress must never be negative',
      );
      expect(
        fuzzedTask.progress,
        lessThanOrEqualTo(1.0),
        reason: 'Task progress must never exceed 1.0',
      );
      expect(fuzzedTask.progress.isNaN, isFalse);
      expect(fuzzedTask.progress.isInfinite, isFalse);
    }

    // Force a controller refresh to verify state consistency
    await tester.runAsync(() async {
      await controller.refreshDownloads();
    });
    await settle();

    logWatcher.checkTesterException(tester, contextDescription: 'Task State Mutation Fuzzing');
  }

  /// 3. Injects malformed, unicode-overflow, and boundary strings into search and sort.
  Future<void> fuzzSearchAndSortingFilters() async {
    final edgeInputs = [
      '',
      ' ',
      '   ',
      'a',
      'nds',
      '<script>alert("xss")</script>',
      '../../../../etc/passwd',
      'SELECT * FROM downloads WHERE 1=1;',
      '🔥🎉✨👾🤖💾📦🚀',
      'العربية / עברית / 中文 / 日本語 / Русский',
      'A' * 500,
      '\u0000\u0001\u0002\u001F',
      'null',
      'undefined',
    ];

    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final uiNotifier = container.read(downloadPageUIProvider.notifier);

    for (final input in edgeInputs) {
      uiNotifier.updateSearchQuery(input);
      await settle();

      logWatcher.checkTesterException(
        tester,
        contextDescription: 'Search Query Fuzz: ${input.length > 20 ? input.substring(0, 20) : input}',
      );
    }

    // Clear search
    uiNotifier.clearSearch();
    await settle();

    // Fuzz all sort options
    final sortOptions = ['name', 'size', 'speed', 'progress', 'created', 'invalid_sort_key'];
    for (final sort in sortOptions) {
      uiNotifier.updateSort(sort, ascending: true);
      await settle();
      uiNotifier.updateSort(sort, ascending: false);
      await settle();

      logWatcher.checkTesterException(
        tester,
        contextDescription: 'Sort Option Fuzz: $sort',
      );
    }
  }

  /// 4. Global Invariant Assertion: Checks overall DownloadState consistency.
  void assertGlobalDownloadInvariants() {
    final element = tester.element(find.byType(DownloadPage).first);
    final container = ProviderScope.containerOf(element);
    final state = container.read(downloadControllerProvider);

    // Sum invariant
    final totalComputed = state.activeTasks.length +
        state.waitingTasks.length +
        state.pausedTasks.length +
        state.completedTasks.length +
        state.failedTasks.length;
    expect(
      state.totalAll,
      equals(totalComputed),
      reason: 'DownloadState.totalAll must match the exact sum of all task buckets',
    );

    // Speed invariants
    expect(state.totalDownloadSpeed, greaterThanOrEqualTo(0));
    expect(state.totalUploadSpeed, greaterThanOrEqualTo(0));
    expect(state.estimatedRemainingSeconds, greaterThanOrEqualTo(0));

    logWatcher.checkTesterException(tester, contextDescription: 'Global Invariant Verification');
  }
}
