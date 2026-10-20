import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/logging/rolling_file_sink.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_log_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RollingFileSink Tests', () {
    test('writes entries asynchronously to primary log file', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 1024,
      );

      sink.write('Log Line 1');
      sink.write('Log Line 2');
      await sink.flush();

      final primaryFile = await sink.getPrimaryFile();
      expect(await primaryFile.exists(), isTrue);

      final content = await primaryFile.readAsString();
      expect(content, contains('Log Line 1'));
      expect(content, contains('Log Line 2'));

      await sink.dispose();
    });

    test('rotates when file size exceeds threshold', () async {
      // Threshold = 100 bytes so rotation happens after a few lines
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 80,
        maxBackups: 2,
      );

      // Write enough to trigger first rotation
      sink.write('A' * 60); // 61 bytes with newline
      sink.write('B' * 60); // exceeds 80 bytes -> rotates kazumi.log -> kazumi.1.log
      await sink.flush();

      final backup1 = File(p.join(tempDir.path, 'kazumi.1.log'));
      final primary = File(p.join(tempDir.path, 'kazumi.log'));

      expect(await backup1.exists(), isTrue);
      expect(await primary.exists(), isTrue);

      // Write enough to trigger second rotation
      sink.write('C' * 60); // exceeds 80 bytes -> rotates kazumi.1 -> kazumi.2, kazumi -> kazumi.1
      await sink.flush();

      final backup2 = File(p.join(tempDir.path, 'kazumi.2.log'));
      expect(await backup2.exists(), isTrue);

      // Total files should be at most 3 (primary + 2 backups)
      final files = await sink.getExistingLogFiles();
      expect(files.length, equals(3));

      // Trigger third rotation -> oldest (.2) should be replaced
      sink.write('D' * 60);
      await sink.flush();

      final backup3 = File(p.join(tempDir.path, 'kazumi.3.log'));
      expect(await backup3.exists(), isFalse); // No .3 file created
      expect((await sink.getExistingLogFiles()).length, equals(3));

      await sink.dispose();
    });

    test('reads all logs chronologically from oldest backup to active log', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 60,
        maxBackups: 2,
      );

      sink.write('FIRST_ENTRY');
      sink.write('SECOND_ENTRY');
      sink.write('THIRD_ENTRY');
      await sink.flush();

      final chronological = await sink.readAllLogsChronological();
      expect(chronological, contains('FIRST_ENTRY'));
      expect(chronological, contains('THIRD_ENTRY'));

      // Chronological order: FIRST should appear before THIRD in the aggregated report
      final firstIdx = chronological.indexOf('FIRST_ENTRY');
      final thirdIdx = chronological.indexOf('THIRD_ENTRY');
      expect(firstIdx, isNot(-1));
      expect(thirdIdx, isNot(-1));
      expect(firstIdx, lessThan(thirdIdx));

      await sink.dispose();
    });

    test('clear removes all log files and resets state', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 50,
        maxBackups: 2,
      );

      sink.write('Line 1 ' * 10);
      sink.write('Line 2 ' * 10);
      sink.write('Line 3 ' * 10);
      await sink.flush();

      expect((await sink.getExistingLogFiles()).length, greaterThan(1));

      await sink.clear();

      final primary = await sink.getPrimaryFile();
      expect(await primary.exists(), isTrue);
      expect((await primary.readAsString()).trim(), isEmpty);

      final backup1 = File(p.join(tempDir.path, 'kazumi.1.log'));
      expect(await backup1.exists(), isFalse);

      await sink.dispose();
    });

    test('flushes writes automatically to disk when write queue is drained', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 1024,
      );

      sink.write('Realtime Disk Flush Test');
      // Wait for background pump loop to drain queue without calling explicit sink.flush()
      await Future.delayed(const Duration(milliseconds: 150));

      final primary = await sink.getPrimaryFile();
      expect(await primary.exists(), isTrue);
      final diskContent = await primary.readAsString();
      expect(diskContent, contains('Realtime Disk Flush Test'));

      await sink.dispose();
    });

    test('survives malformed non-UTF8 bytes in backups during chronological read', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 500,
        maxBackups: 2,
      );

      // Create an existing backup file containing non-UTF-8 bytes (e.g. 0xFF, 0xFE)
      final backup1 = File(p.join(tempDir.path, 'kazumi.1.log'));
      await backup1.writeAsBytes([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0xFF, 0xFE, 0x0A]); // "Hello\xFF\xFE\n"

      sink.write('Active Log Entry');
      await sink.flush();

      // readAllLogsChronological should not throw FormatException and should include both files
      final content = await sink.readAllLogsChronological();
      expect(content, contains('Hello'));
      expect(content, contains('Active Log Entry'));

      await sink.dispose();
    });

    test('oversized single log line does not cascade-wipe existing backups', () async {
      final sink = RollingFileSink(
        directoryProvider: () async => tempDir,
        baseName: 'kazumi.log',
        maxFileSizeBytes: 100,
        maxBackups: 2,
      );

      sink.write('Valuable Historical Entry');
      await sink.flush();

      // Write enough to push into backup 1
      sink.write('A' * 90);
      await sink.flush();

      final backup1 = File(p.join(tempDir.path, 'kazumi.1.log'));
      expect(await backup1.exists(), isTrue);

      // Write a single entry that exceeds maxFileSizeBytes by itself on the newly opened primary file
      sink.write('Z' * 300);
      await sink.flush();

      // Historical backup should still be preserved
      expect(await backup1.exists(), isTrue);

      await sink.dispose();
    });
  });
}
