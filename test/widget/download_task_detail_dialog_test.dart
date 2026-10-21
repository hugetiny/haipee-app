import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/download/download_file_utils.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/pages/download/download_task_detail_dialog.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_dialog_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(DownloadTaskAdapter());
    }
    GStorage.setting = await Hive.openBox('setting_test');
    GStorage.downloadTasks = await Hive.openBox<DownloadTask>('download_tasks_test');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    await GStorage.downloadTasks.close();
    await GStorage.setting.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('DownloadFileUtils.resolveDiskInfo', () {
    test('正确解析绝对路径与所在目录', () {
      final dummyFile = File('${tempDir.path}/sample_anime.mp4');
      dummyFile.writeAsStringSync('fake video content for testing');

      final task = DownloadTask(
        gid: 'test-gid-1',
        url: 'https://example.com/sample_anime.mp4',
        title: 'sample_anime.mp4',
        fileName: dummyFile.path,
        totalLength: 100,
        completedLength: 100,
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final diskInfo = DownloadFileUtils.resolveDiskInfo(task);
      expect(diskInfo.exists, isTrue);
      expect(diskInfo.isDirectory, isFalse);
      expect(diskInfo.fullPath, dummyFile.path);
      expect(diskInfo.directory, tempDir.path);
      expect(diskInfo.fileName, 'sample_anime.mp4');
      expect(diskInfo.diskSize, greaterThan(0));
    });

    test('对不存在的文件正确报告 exists == false', () {
      final task = DownloadTask(
        gid: 'test-gid-missing',
        url: 'https://example.com/missing.mp4',
        title: 'missing.mp4',
        fileName: '${tempDir.path}/does_not_exist.mp4',
        totalLength: 100,
        completedLength: 0,
        status: 'removed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final diskInfo = DownloadFileUtils.resolveDiskInfo(task);
      expect(diskInfo.exists, isFalse);
      expect(diskInfo.fullPath, contains('does_not_exist.mp4'));
      expect(diskInfo.directory, tempDir.path);
    });
  });

  group('DownloadTaskDetailDialog UI 交互与路径状态展示', () {
    testWidgets('removed 状态且本地文件存在：显示已取消状态、说明提示及文件路径', (tester) async {
      final existingFile = File('${tempDir.path}/frieren_01.mp4');
      existingFile.writeAsBytesSync(List.filled(1024 * 1024, 0)); // 1 MB file

      final removedTask = DownloadTask(
        gid: 'removed-task-1',
        url: 'https://example.com/frieren_01.mp4',
        title: '葬送的芙莉莲 第01集',
        fileName: existingFile.path,
        totalLength: 1024 * 1024 * 200,
        completedLength: 1024 * 1024,
        status: 'removed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => DownloadTaskDetailDialog(
                        task: removedTask,
                        onRetry: () {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // 验证标题与状态
      expect(find.text('下载任务详情'), findsOneWidget);
      expect(find.text('已取消 (已从队列移除)'), findsOneWidget);

      // 验证 removed 状态的详细说明横幅
      expect(find.textContaining('状态说明：已从下载队列移除 (removed)'), findsOneWidget);
      expect(find.textContaining('此任务已从下载引擎的执行队列中移出'), findsOneWidget);

      // 验证文件存储路径卡片
      expect(find.text('文件存储路径'), findsOneWidget);
      expect(find.text('保存目录'), findsOneWidget);
      expect(find.text('完整路径'), findsOneWidget);
      expect(find.text(existingFile.path), findsOneWidget);

      // 验证定位文件夹与操作按钮
      expect(find.text('定位文件夹'), findsOneWidget);
      expect(find.text('所在文件夹'), findsOneWidget);
      expect(find.text('重新下载'), findsOneWidget);
    });

    testWidgets('removed 状态且本地文件不存在：显示已取消与无文件提示', (tester) async {
      final missingTask = DownloadTask(
        gid: 'removed-missing-task',
        url: 'https://example.com/never_downloaded.mp4',
        title: '未下载任务',
        fileName: '${tempDir.path}/never_downloaded.mp4',
        totalLength: 1024 * 1024 * 50,
        completedLength: 0,
        status: 'removed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => DownloadTaskDetailDialog(task: missingTask),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('已取消 (已从队列移除)'), findsOneWidget);
      expect(find.text('本地文件不存在'), findsOneWidget);
      expect(find.textContaining('当前在指定下载路径未检测到对应文件'), findsOneWidget);
      expect(find.text('文件存储路径'), findsOneWidget);
      expect(find.text('保存目录'), findsOneWidget);
      expect(find.text('完整路径'), findsOneWidget);
    });
  });
}
