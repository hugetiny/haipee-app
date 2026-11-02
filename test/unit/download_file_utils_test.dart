import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/download_file_utils.dart';
import 'package:haipee/modules/download/download_task.dart';

void main() {
  group('DownloadFileUtils.validateDownloadedContent', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('haipee_download_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should detect HTML error page returned instead of RAR file', () {
      final fakeRarFile = File('${tempDir.path}/test_archive.rar');
      fakeRarFile.writeAsStringSync(
        '<!DOCTYPE html><html><head><title>Gofile - Download</title></head><body>Error: File not found or token expired</body></html>',
      );

      final task = DownloadTask(
        gid: 'test-gid-html',
        url: 'https://store8.gofile.io/download/web/1234/test_archive.rar',
        title: 'test_archive.rar',
        fileName: fakeRarFile.path,
        status: 'complete',
        completedLength: fakeRarFile.lengthSync(),
        totalLength: fakeRarFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('下载内容为重定向网页或鉴权失败'));
    });

    test('should detect JSON error payload returned instead of video', () {
      final fakeVideoFile = File('${tempDir.path}/episode.mp4');
      fakeVideoFile.writeAsStringSync('{"status":"error-notAuthorized","data":{}}');

      final task = DownloadTask(
        gid: 'test-gid-json',
        url: 'https://api.example.com/download/episode.mp4',
        title: 'episode.mp4',
        fileName: fakeVideoFile.path,
        status: 'complete',
        completedLength: fakeVideoFile.lengthSync(),
        totalLength: fakeVideoFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('下载内容为重定向网页或鉴权失败'));
    });

    test('should validate authentic RAR archive magic bytes', () {
      final validRarFile = File('${tempDir.path}/good_archive.rar');
      // RAR 5.0 magic bytes: Rar!\x1A\x07\x01\x00
      validRarFile.writeAsBytesSync([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]);

      final task = DownloadTask(
        gid: 'test-gid-rar',
        url: 'https://example.com/good_archive.rar',
        title: 'good_archive.rar',
        fileName: validRarFile.path,
        status: 'complete',
        completedLength: validRarFile.lengthSync(),
        totalLength: validRarFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('should flag corrupted or wrong magic bytes for small RAR file', () {
      final corruptRarFile = File('${tempDir.path}/corrupt.rar');
      // Random bytes without 'Rar!'
      corruptRarFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0x04]);

      final task = DownloadTask(
        gid: 'test-gid-corrupt-rar',
        url: 'https://example.com/corrupt.rar',
        title: 'corrupt.rar',
        fileName: corruptRarFile.path,
        status: 'complete',
        completedLength: corruptRarFile.lengthSync(),
        totalLength: corruptRarFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isFalse);
    });

    test('should validate authentic ZIP archive magic bytes', () {
      final validZipFile = File('${tempDir.path}/good.zip');
      // ZIP magic bytes: PK\x03\x04
      validZipFile.writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]);

      final task = DownloadTask(
        gid: 'test-gid-zip',
        url: 'https://example.com/good.zip',
        title: 'good.zip',
        fileName: validZipFile.path,
        status: 'complete',
        completedLength: validZipFile.lengthSync(),
        totalLength: validZipFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isTrue);
    });

    test('should validate authentic 7z archive magic bytes', () {
      final valid7zFile = File('${tempDir.path}/good.7z');
      // 7z magic bytes: '7' 'z' \xBC \xAF
      valid7zFile.writeAsBytesSync([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]);

      final task = DownloadTask(
        gid: 'test-gid-7z',
        url: 'https://example.com/good.7z',
        title: 'good.7z',
        fileName: valid7zFile.path,
        status: 'complete',
        completedLength: valid7zFile.lengthSync(),
        totalLength: valid7zFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isTrue);
    });

    test('should validate authentic MP4 ftyp box', () {
      final validMp4File = File('${tempDir.path}/movie.mp4');
      // MP4 header: 4 bytes length, 'ftyp', 'isom'
      validMp4File.writeAsBytesSync([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]);

      final task = DownloadTask(
        gid: 'test-gid-mp4',
        url: 'https://example.com/movie.mp4',
        title: 'movie.mp4',
        fileName: validMp4File.path,
        status: 'complete',
        completedLength: validMp4File.lengthSync(),
        totalLength: validMp4File.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isTrue);
    });

    test('should validate authentic MKV header', () {
      final validMkvFile = File('${tempDir.path}/movie.mkv');
      // MKV magic bytes: 0x1A, 0x45, 0xDF, 0xA3
      validMkvFile.writeAsBytesSync([0x1A, 0x45, 0xDF, 0xA3, 0x93, 0x42, 0x82, 0x88]);

      final task = DownloadTask(
        gid: 'test-gid-mkv',
        url: 'https://example.com/movie.mkv',
        title: 'movie.mkv',
        fileName: validMkvFile.path,
        status: 'complete',
        completedLength: validMkvFile.lengthSync(),
        totalLength: validMkvFile.lengthSync(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isTrue);
    });

    test('should flag suspicious tiny completed size when file is missing and host is gofile.io', () {
      final task = DownloadTask(
        gid: 'test-gid-gofile-missing',
        url: 'https://store8.gofile.io/download/web/abc-123/Romance_part1.rar',
        title: 'Romance_part1.rar',
        fileName: '/non/existent/path/Romance_part1.rar',
        status: 'complete',
        completedLength: 2048, // 2KB suspicious error page
        totalLength: 2048,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = DownloadFileUtils.validateDownloadedContent(task);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('下载内容为重定向网页或鉴权失败'));
    });
  });

  group('DownloadFileUtils.deleteDownloadedFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('haipee_del_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should delete both downloaded file and temp companion file', () async {
      final targetFile = File('${tempDir.path}/download.mp4');
      final tmpFile = File('${tempDir.path}/download.mp4.tmp');

      targetFile.writeAsStringSync('dummy content');
      tmpFile.writeAsStringSync('temporary part file');

      expect(targetFile.existsSync(), isTrue);
      expect(tmpFile.existsSync(), isTrue);

      final deleted = await DownloadFileUtils.deleteDownloadedFile(targetFile.path);

      expect(deleted, isTrue);
      expect(targetFile.existsSync(), isFalse);
      expect(tmpFile.existsSync(), isFalse);
    });
  });
}
