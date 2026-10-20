import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/modules/download/gopeed/gopeed_models.dart';
import 'package:kazumi/modules/download/gopeed/gopeed_service.dart';

void main() {
  group('DownloadTask.fromGopeedTask', () {
    test('correctly converts GopeedTask into DownloadTask', () {
      final gopeedTask = GopeedTask(
        id: 'task-12345',
        name: 'test_video.mp4',
        protocol: 'http',
        status: 'running',
        totalLength: 104857600,
        completedLength: 52428800,
        downloadSpeed: 5242880,
        uploadSpeed: 10240,
        savePath: '/Users/test/Downloads',
        url: 'https://example.com/test_video.mp4',
        files: [
          GopeedFile(name: 'test_video.mp4', path: 'test_video.mp4', size: 104857600),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask);

      expect(task.gid, equals('task-12345'));
      expect(task.title, equals('test_video.mp4'));
      expect(task.fileName, equals('test_video.mp4'));
      expect(task.status, equals('active'));
      expect(task.isActive, isTrue);
      expect(task.totalLength, equals(104857600));
      expect(task.completedLength, equals(52428800));
      expect(task.downloadSpeed, equals(5242880));
      expect(task.uploadSpeed, equals(10240));
      expect(task.progress, closeTo(0.5, 0.001));
      expect(task.isVideo, isTrue);
      expect(task.isPlayable, isTrue);
    });

    test('correctly handles non-media files like .rar from Gopeed', () {
      final gopeedTask = GopeedTask(
        id: 'rar-task-99',
        name: 'archive.rar',
        protocol: 'http',
        status: 'done',
        totalLength: 200000000,
        completedLength: 200000000,
        files: [
          GopeedFile(name: 'archive.rar', path: 'archive.rar', size: 200000000),
        ],
      );

      final task = DownloadTask.fromGopeedTask(gopeedTask);

      expect(task.status, equals('complete'));
      expect(task.isComplete, isTrue);
      expect(task.isArchive, isTrue);
      expect(task.isPlayable, isFalse);
    });
  });

  group('GopeedService FFI Lifecycle', () {
    test('GopeedService initializes and creates/pauses/resumes/deletes tasks in-process', () async {
      final dylibPath = '${Directory.current.path}/macos/Frameworks/libgopeed.dylib';
      if (!File(dylibPath).existsSync()) {
        return; // Skip if dylib not built in environment
      }

      final service = GopeedService();
      final tempDir = Directory.systemTemp.createTempSync('gopeed_test_');

      try {
        await service.initialize(storageDir: tempDir.path);
        expect(service.isInitialized, isTrue);

        // Fetch initial tasks
        final initialTasks = await service.getTasks();
        expect(initialTasks, isA<List<GopeedTask>>());

        // Create a test task (using dummy http url)
        final taskId = await service.createTask(
          url: 'https://example.com/file.zip',
          name: 'file.zip',
          savePath: tempDir.path,
          headers: {'User-Agent': 'Kazumi/1.0'},
        );
        expect(taskId, isNotEmpty);

        // Verify task appears in task list
        final tasksAfterCreate = await service.getTasks();
        final created = tasksAfterCreate.firstWhere((t) => t.id == taskId);
        expect(created.id, equals(taskId));

        // Test pause task
        await service.pauseTask(taskId);

        // Test resume task
        await service.resumeTask(taskId);

        // Test delete task
        await service.deleteTask(taskId);
      } finally {
        await service.stop();
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
