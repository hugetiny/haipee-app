import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/download_task.dart';
import 'package:haipee/modules/download/gopeed/gopeed_models.dart';

void main() {
  group('DownloadTask', () {
    test('should calculate progress correctly', () {
      final task = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Test Download',
        totalLength: 1000,
        completedLength: 500,
        downloadSpeed: 0,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.progress, 0.5);
    });

    test('should return 0 progress when totalLength is 0', () {
      final task = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Test Download',
        totalLength: 0,
        completedLength: 0,
        downloadSpeed: 0,
        status: 'waiting',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.progress, 0.0);
    });

    test('should correctly identify active status', () {
      final task = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Test Download',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.isActive, true);
      expect(task.isWaiting, false);
      expect(task.isPaused, false);
      expect(task.isComplete, false);
      expect(task.isError, false);
    });

    test('should correctly identify completed status', () {
      final task = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Test Download',
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.isComplete, true);
      expect(task.isActive, false);
    });

    test('should create task from gopeed task with smart video selection', () {
      final gopeedTask = GopeedTask(
        id: 'gopeed-123',
        name: 'My Video',
        status: 'running',
        totalLength: 10485760,
        completedLength: 5242880,
        downloadSpeed: 1048576,
        url: 'http://example.com/video.mp4',
        files: [
          GopeedFile(
            name: 'cover.jpg',
            path: '/downloads/cover.jpg',
            size: 150000,
          ),
          GopeedFile(
            name: 'video.mp4',
            path: '/downloads/video.mp4',
            size: 10335760,
            completed: 5242880,
          ),
        ],
      );

      final task = DownloadTask.fromGopeedTask(
        gopeedTask,
        title: 'My Video',
      );

      expect(task.gid, 'gopeed-123');
      expect(task.status, 'active');
      expect(task.totalLength, 10485760);
      expect(task.completedLength, 5242880);
      expect(task.downloadSpeed, 1048576);
      expect(task.title, 'My Video');
      expect(task.url, 'http://example.com/video.mp4');
      expect(task.fileName, '/downloads/video.mp4');
      expect(task.filePath, '/downloads/video.mp4');
      expect(task.isVideo, isTrue);
    });

    test('copyWith should update only specified fields', () {
      final original = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Original Title',
        status: 'active',
        completedLength: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        completedLength: 200,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.completedLength, 200);
      expect(updated.gid, 'test-gid'); // unchanged
      expect(updated.url, 'http://example.com/file.mp4'); // unchanged
      expect(updated.status, 'active'); // unchanged
    });

    test('should identify downloading status', () {
      final activeTask = DownloadTask(
        gid: 'test-gid',
        url: 'http://example.com/file.mp4',
        title: 'Test Download',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final waitingTask = DownloadTask(
        gid: 'test-gid-2',
        url: 'http://example.com/file2.mp4',
        title: 'Test Download 2',
        status: 'waiting',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(activeTask.isDownloading, true);
      expect(waitingTask.isDownloading, true);
    });

    test('should correctly classify media and non-media files (e.g. rar should not be playable)', () {
      final rarTask = DownloadTask(
        gid: 'rar-gid',
        url: 'https://store8.gofile.io/download/web/2e3f4aac-b07d-4a79-9ff7-f3128c5580b5/Romance_of_the_Three_Kingdoms_14.part7.rar',
        title: 'Romance_of_the_Three_Kingdoms_14.part7.rar',
        fileName: '/Users/a12/Downloads/Romance_of_the_Three_Kingdoms_14.part7.rar',
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(rarTask.isArchive, isTrue);
      expect(rarTask.isVideo, isFalse);
      expect(rarTask.isAudio, isFalse);
      expect(rarTask.isPlayable, isFalse);
      expect(rarTask.fileTypeDisplay, '压缩包');
      expect(rarTask.displayTitle, 'Romance_of_the_Three_Kingdoms_14.part7.rar');

      final mp4Task = DownloadTask(
        gid: 'mp4-gid',
        url: 'http://example.com/video.mp4',
        title: 'video.mp4',
        fileName: '/downloads/video.mp4',
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(mp4Task.isVideo, isTrue);
      expect(mp4Task.isPlayable, isTrue);
      expect(mp4Task.fileTypeDisplay, '视频');

      final zipTask = DownloadTask(
        gid: 'zip-gid',
        url: 'http://example.com/archive.zip',
        title: 'archive.zip',
        status: 'complete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(zipTask.isArchive, isTrue);
      expect(zipTask.isVideo, isFalse);
      expect(zipTask.isPlayable, isFalse);
    });
  });
}
