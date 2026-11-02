import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Non-blocking, asynchronous rolling file sink with strictly bounded disk footprint.
///
/// Rotation strategy:
/// - Active file: `haipee.log` (up to [maxFileSizeBytes], default 5MB)
/// - Backups: `haipee.1.log`, `haipee.2.log` (up to [maxBackups], default 2)
/// - Maximum total footprint: (1 + maxBackups) * 5MB = 15MB max.
class RollingFileSink {
  RollingFileSink({
    required this.directoryProvider,
    this.baseName = 'haipee.log',
    this.maxFileSizeBytes = 5 * 1024 * 1024,
    this.maxBackups = 2,
  }) {
    final dotIdx = baseName.lastIndexOf('.');
    if (dotIdx > 0) {
      _namePrefix = baseName.substring(0, dotIdx);
      _nameSuffix = baseName.substring(dotIdx);
    } else {
      _namePrefix = baseName;
      _nameSuffix = '';
    }
  }

  final Future<Directory> Function() directoryProvider;
  final String baseName;
  final int maxFileSizeBytes;
  final int maxBackups;

  late final String _namePrefix;
  late final String _nameSuffix;

  final Queue<String> _pendingQueue = Queue<String>();
  bool _isPumping = false;
  bool _isDisposed = false;

  IOSink? _activeSink;
  File? _activeFile;
  int _currentFileLength = 0;
  Directory? _logDir;

  String _backupFileName(int index) => '$_namePrefix.$index$_nameSuffix';
  String get _primaryFileName => '$_namePrefix$_nameSuffix';

  /// Asynchronously writes a log entry without blocking the caller.
  void write(String entry) {
    if (_isDisposed) return;
    _pendingQueue.add(entry);
    _pump();
  }

  void _pump() async {
    if (_isPumping || _isDisposed) return;
    _isPumping = true;
    try {
      while (_pendingQueue.isNotEmpty && !_isDisposed) {
        final message = _pendingQueue.removeFirst();
        await _writeEntry(message);
      }
      // When the write queue is drained, flush the active sink to the OS file descriptor
      // so AI agents, terminal monitors (tail -f), and diagnostic exporters see real-time updates.
      if (_activeSink != null && !_isDisposed) {
        try {
          await _activeSink!.flush();
        } catch (_) {}
      }
    } catch (_) {
      // Catch all write failures to protect caller runtime stability
    } finally {
      _isPumping = false;
      if (_pendingQueue.isNotEmpty && !_isDisposed) {
        _pump();
      }
    }
  }

  Future<void> _writeEntry(String message) async {
    await _ensureInitialized();
    if (_activeSink == null) return;

    final line = '$message\n';
    final lineByteCount = utf8.encode(line).length;

    // Only rotate if file already has content, preventing infinite rotation cascades on oversized single lines
    if (_currentFileLength > 0 && (_currentFileLength + lineByteCount > maxFileSizeBytes)) {
      await _rotate();
    }

    _activeSink?.write(line);
    _currentFileLength += lineByteCount;
  }

  Future<void> _ensureInitialized() async {
    if (_activeSink != null && _activeFile != null) return;
    try {
      _logDir = await directoryProvider();
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }

      _activeFile = File(p.join(_logDir!.path, _primaryFileName));
      if (await _activeFile!.exists()) {
        _currentFileLength = await _activeFile!.length();
        if (_currentFileLength >= maxFileSizeBytes) {
          await _rotate();
          return;
        }
      } else {
        await _activeFile!.create();
        _currentFileLength = 0;
      }
      _activeSink = _activeFile!.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (_) {
      _activeSink = null;
    }
  }

  Future<void> _rotate() async {
    try {
      if (_activeSink != null) {
        try {
          await _activeSink!.flush();
          await _activeSink!.close();
        } catch (_) {}
        _activeSink = null;
      }

      if (_logDir == null) return;

      // 1. Delete oldest backup (e.g. haipee.2.log) if it exists
      final oldestBackup = File(p.join(_logDir!.path, _backupFileName(maxBackups)));
      if (await oldestBackup.exists()) {
        try {
          await oldestBackup.delete();
        } catch (_) {}
      }

      // 2. Cascade shift existing backups (e.g. haipee.1.log -> haipee.2.log)
      for (int i = maxBackups - 1; i >= 1; i--) {
        final cur = File(p.join(_logDir!.path, _backupFileName(i)));
        final next = File(p.join(_logDir!.path, _backupFileName(i + 1)));
        if (await cur.exists()) {
          // On Windows, rename fails if destination file exists; remove destination first
          if (await next.exists()) {
            try {
              await next.delete();
            } catch (_) {}
          }
          try {
            await cur.rename(next.path);
          } catch (_) {}
        }
      }

      // 3. Shift active file (haipee.log -> haipee.1.log)
      final primary = File(p.join(_logDir!.path, _primaryFileName));
      final firstBackup = File(p.join(_logDir!.path, _backupFileName(1)));
      if (await primary.exists()) {
        // On Windows, remove target before renaming
        if (await firstBackup.exists()) {
          try {
            await firstBackup.delete();
          } catch (_) {}
        }
        try {
          await primary.rename(firstBackup.path);
        } catch (_) {}
      }

      // 4. Create fresh primary file
      _activeFile = File(p.join(_logDir!.path, _primaryFileName));
      await _activeFile!.create();
      _activeSink = _activeFile!.openWrite(mode: FileMode.writeOnlyAppend);
      _currentFileLength = 0;
    } catch (_) {
      // In case of rotation error, attempt to reopen primary
      try {
        if (_activeFile != null) {
          _activeSink = _activeFile!.openWrite(mode: FileMode.writeOnlyAppend);
        }
      } catch (_) {}
    }
  }

  /// Flushes all pending writes to disk.
  Future<void> flush() async {
    while (_pendingQueue.isNotEmpty || _isPumping) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    try {
      await _activeSink?.flush();
    } catch (_) {}
  }

  /// Clears active and all backup logs.
  Future<void> clear() async {
    await flush();
    try {
      if (_activeSink != null) {
        try {
          await _activeSink!.close();
        } catch (_) {}
        _activeSink = null;
      }
      if (_logDir != null && await _logDir!.exists()) {
        final primary = File(p.join(_logDir!.path, _primaryFileName));
        if (await primary.exists()) {
          try {
            await primary.delete();
          } catch (_) {}
        }
        for (int i = 1; i <= maxBackups; i++) {
          final backup = File(p.join(_logDir!.path, _backupFileName(i)));
          if (await backup.exists()) {
            try {
              await backup.delete();
            } catch (_) {}
          }
        }
      }
      _currentFileLength = 0;
      await _ensureInitialized();
    } catch (_) {}
  }

  /// Returns the log directory.
  Future<Directory> getLogDirectory() async {
    await _ensureInitialized();
    return _logDir ?? await directoryProvider();
  }

  /// Returns the primary active log file.
  Future<File> getPrimaryFile() async {
    await _ensureInitialized();
    return _activeFile ?? File(p.join((await getLogDirectory()).path, _primaryFileName));
  }

  /// Returns all existing log files in newest-first order (`haipee.log`, `haipee.1.log`, `haipee.2.log`).
  Future<List<File>> getExistingLogFiles() async {
    await _ensureInitialized();
    final list = <File>[];
    if (_logDir == null || !await _logDir!.exists()) return list;

    final primary = File(p.join(_logDir!.path, _primaryFileName));
    if (await primary.exists()) list.add(primary);

    for (int i = 1; i <= maxBackups; i++) {
      final f = File(p.join(_logDir!.path, _backupFileName(i)));
      if (await f.exists()) list.add(f);
    }
    return list;
  }

  /// Reads all log files in chronological sequence:
  /// `haipee.2.log` (oldest) -> `haipee.1.log` -> `haipee.log` (newest active).
  Future<String> readAllLogsChronological() async {
    await flush();
    final buffer = StringBuffer();
    if (_logDir == null || !await _logDir!.exists()) return '';

    for (int i = maxBackups; i >= 1; i--) {
      final backup = File(p.join(_logDir!.path, _backupFileName(i)));
      if (await backup.exists()) {
        try {
          final content = await backup.readAsString(
            encoding: const Utf8Codec(allowMalformed: true),
          );
          if (content.isNotEmpty) {
            buffer.writeln('=== LOG BACKUP #$i (${backup.path}) ===');
            buffer.writeln(content.trim());
            buffer.writeln();
          }
        } catch (_) {}
      }
    }

    final primary = File(p.join(_logDir!.path, _primaryFileName));
    if (await primary.exists()) {
      try {
        final content = await primary.readAsString(
          encoding: const Utf8Codec(allowMalformed: true),
        );
        if (content.isNotEmpty) {
          buffer.writeln('=== ACTIVE LOG (${primary.path}) ===');
          buffer.writeln(content.trim());
        }
      } catch (_) {}
    }

    return buffer.toString();
  }

  /// Disposes of the file sink and frees resources.
  Future<void> dispose() async {
    _isDisposed = true;
    await flush();
    try {
      await _activeSink?.close();
      _activeSink = null;
    } catch (_) {}
  }
}
