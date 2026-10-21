import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadValidationResult {
  final bool isValid;
  final String? errorMessage;

  const DownloadValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const DownloadValidationResult.invalid(this.errorMessage)
      : isValid = false;
}

class DownloadDiskInfo {
  final String fullPath;
  final String directory;
  final String fileName;
  final bool exists;
  final bool isDirectory;
  final int diskSize;

  const DownloadDiskInfo({
    required this.fullPath,
    required this.directory,
    required this.fileName,
    required this.exists,
    required this.isDirectory,
    required this.diskSize,
  });
}

class DownloadFileUtils {
  /// Resolves the default download directory synchronously (custom setting or system Downloads)
  static String getDefaultDownloadDirectorySync() {
    try {
      final customPath = (GStorage.setting.get(
        SettingBoxKey.downloadDirectory,
        defaultValue: '',
      ) as String).trim();
      if (customPath.isNotEmpty) {
        return customPath;
      }
    } catch (_) {}

    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        final dl = p.join(home, 'Downloads');
        if (Directory(dl).existsSync()) {
          return dl;
        }
      }
    } catch (_) {}

    return Directory.current.path;
  }

  /// Resolves the default download directory (custom setting or system Downloads)
  static Future<String> getDefaultDownloadDirectory() async {
    try {
      final customPath = (GStorage.setting.get(
        SettingBoxKey.downloadDirectory,
        defaultValue: '',
      ) as String).trim();
      if (customPath.isNotEmpty) {
        return customPath;
      }
    } catch (_) {}

    try {
      final downloadDir = await getDownloadsDirectory()
          .timeout(const Duration(milliseconds: 150));
      if (downloadDir != null) {
        return downloadDir.path;
      }
      final appDocDir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(milliseconds: 150));
      return appDocDir.path;
    } catch (_) {}

    return getDefaultDownloadDirectorySync();
  }

  /// Resolves the canonical full path, containing directory, and disk existence for a task synchronously.
  static DownloadDiskInfo resolveDiskInfo(DownloadTask task) {
    String? rawPath = task.filePath;
    if (rawPath == null || rawPath.trim().isEmpty) {
      rawPath = task.fileName;
    }

    String defaultDir = getDefaultDownloadDirectorySync();

    String fullPath = '';
    String directory = '';
    String fileName = '';

    if (rawPath != null && rawPath.trim().isNotEmpty) {
      final trimmed = rawPath.trim();
      if (p.isAbsolute(trimmed)) {
        fullPath = p.normalize(trimmed);
        fileName = p.basename(fullPath);
        directory = p.dirname(fullPath);
      } else {
        fileName = p.basename(trimmed);
        fullPath = p.normalize(p.join(defaultDir, trimmed));
        directory = p.dirname(fullPath);
      }
    } else {
      final safeName = task.displayTitle.isNotEmpty
          ? task.displayTitle
          : (task.title.isNotEmpty ? task.title : 'download_task');
      fileName = p.basename(safeName);
      fullPath = p.normalize(p.join(defaultDir, fileName));
      directory = defaultDir;
    }

    bool exists = false;
    bool isDir = false;
    int diskSize = 0;

    try {
      final file = File(fullPath);
      if (file.existsSync()) {
        exists = true;
        isDir = false;
        diskSize = file.lengthSync();
      } else {
        final dir = Directory(fullPath);
        if (dir.existsSync()) {
          exists = true;
          isDir = true;
          for (final entity in dir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                diskSize += entity.lengthSync();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    return DownloadDiskInfo(
      fullPath: fullPath,
      directory: directory,
      fileName: fileName,
      exists: exists,
      isDirectory: isDir,
      diskSize: diskSize,
    );
  }

  /// Async version of resolveDiskInfo with platform directory fallback.
  static Future<DownloadDiskInfo> resolveDiskInfoAsync(DownloadTask task) async {
    String? rawPath = task.filePath;
    if (rawPath == null || rawPath.trim().isEmpty) {
      rawPath = task.fileName;
    }

    String defaultDir = '';
    try {
      defaultDir = await getDefaultDownloadDirectory();
    } catch (_) {
      defaultDir = getDefaultDownloadDirectorySync();
    }

    String fullPath = '';
    String directory = '';
    String fileName = '';

    if (rawPath != null && rawPath.trim().isNotEmpty) {
      final trimmed = rawPath.trim();
      if (p.isAbsolute(trimmed)) {
        fullPath = p.normalize(trimmed);
        fileName = p.basename(fullPath);
        directory = p.dirname(fullPath);
      } else {
        fileName = p.basename(trimmed);
        fullPath = p.normalize(p.join(defaultDir, trimmed));
        directory = p.dirname(fullPath);
      }
    } else {
      final safeName = task.displayTitle.isNotEmpty
          ? task.displayTitle
          : (task.title.isNotEmpty ? task.title : 'download_task');
      fileName = p.basename(safeName);
      fullPath = p.normalize(p.join(defaultDir, fileName));
      directory = defaultDir;
    }

    bool exists = false;
    bool isDir = false;
    int diskSize = 0;

    try {
      final file = File(fullPath);
      if (await file.exists()) {
        exists = true;
        isDir = false;
        diskSize = await file.length();
      } else {
        final dir = Directory(fullPath);
        if (await dir.exists()) {
          exists = true;
          isDir = true;
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                diskSize += await entity.length();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    return DownloadDiskInfo(
      fullPath: fullPath,
      directory: directory,
      fileName: fileName,
      exists: exists,
      isDirectory: isDir,
      diskSize: diskSize,
    );
  }

  /// Opens a file using the system default application.
  static Future<bool> openFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      KazumiDialog.showToast(message: '文件路径为空');
      return false;
    }
    final file = File(filePath);
    if (!file.existsSync()) {
      KazumiDialog.showToast(message: '文件不存在: $filePath');
      return false;
    }

    try {
      final result = await OpenFilex.open(file.absolute.path);
      if (result.type != ResultType.done) {
        KazumiDialog.showToast(message: '无法打开文件: ${result.message}');
        return false;
      }
      return true;
    } on PlatformException catch (e) {
      KazumiDialog.showToast(message: '打开文件失败: ${e.message}');
      return false;
    } catch (e) {
      KazumiDialog.showToast(message: '打开文件时发生错误: $e');
      return false;
    }
  }

  /// Opens the containing folder and highlights/reveals the file in Finder (macOS), Explorer (Windows), or file manager (Linux).
  static Future<bool> openContainingFolder(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      KazumiDialog.showToast(message: '文件路径为空');
      return false;
    }

    try {
      final file = File(filePath);
      final exists = file.existsSync();
      final dir = exists
          ? file.parent
          : (Directory(filePath).existsSync() ? Directory(filePath) : file.parent);

      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }

      if (Platform.isMacOS) {
        if (exists) {
          await Process.run('open', ['-R', file.absolute.path]);
        } else if (dir.existsSync()) {
          await Process.run('open', [dir.absolute.path]);
        } else {
          KazumiDialog.showToast(message: '文件夹不存在: ${dir.path}');
          return false;
        }
        return true;
      } else if (Platform.isWindows) {
        if (exists) {
          await Process.run('explorer.exe', ['/select,', file.absolute.path]);
        } else if (dir.existsSync()) {
          await Process.run('explorer.exe', [dir.absolute.path]);
        } else {
          KazumiDialog.showToast(message: '文件夹不存在: ${dir.path}');
          return false;
        }
        return true;
      } else if (Platform.isLinux) {
        final targetDir = dir.existsSync() ? dir.absolute.path : file.parent.path;
        await Process.run('xdg-open', [targetDir]);
        return true;
      } else {
        if (dir.existsSync()) {
          final res = await OpenFilex.open(dir.path);
          return res.type == ResultType.done;
        }
      }
    } catch (e) {
      KazumiDialog.showToast(message: '打开所在文件夹失败: $e');
      return false;
    }
    return false;
  }

  /// Deletes downloaded file, its control file (.aria2), and any companion files.
  static Future<bool> deleteDownloadedFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    bool deleted = false;
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        deleted = true;
      }
      final aria2File = File('$filePath.aria2');
      if (aria2File.existsSync()) {
        await aria2File.delete();
      }
      final dir = Directory(filePath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        deleted = true;
      }
    } catch (_) {}
    return deleted;
  }

  /// Inspects downloaded file for invalid redirect, HTML error pages, or corrupt small payloads.
  static DownloadValidationResult validateDownloadedContent(DownloadTask task) {
    final filePath = task.filePath ?? task.fileName;
    final ext = task.fileExtension.toLowerCase();
    final isArchive = task.isArchive;
    final isVideo = task.isVideo;
    final isInstaller = task.isInstaller;
    final isAudio = task.isAudio;
    final bool isExpectedBinary = isArchive || isVideo || isInstaller || isAudio || ext == '.iso';

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        final int fileSize;
        try {
          fileSize = file.lengthSync();
        } catch (_) {
          return const DownloadValidationResult.valid();
        }

        // If file is smaller than 512 KB and expected to be a binary asset, inspect content
        if (fileSize < 512 * 1024 && isExpectedBinary) {
          try {
            final randomAccess = file.openSync(mode: FileMode.read);
            final bytesToRead = fileSize < 4096 ? fileSize : 4096;
            final bytes = randomAccess.readSync(bytesToRead);
            randomAccess.closeSync();

            if (bytes.isNotEmpty) {
              final contentPrefix = String.fromCharCodes(bytes).toLowerCase();

              // 1. Check for HTML / XML / web redirection / error signatures
              final hasHtmlSignature = contentPrefix.contains('<!doctype html') ||
                  contentPrefix.contains('<html') ||
                  contentPrefix.contains('<head') ||
                  contentPrefix.contains('<body>') ||
                  contentPrefix.contains('<title>') ||
                  contentPrefix.contains('<script') ||
                  contentPrefix.contains('window.location') ||
                  contentPrefix.contains('{"status":"error') ||
                  contentPrefix.contains('access denied') ||
                  contentPrefix.contains('403 forbidden') ||
                  contentPrefix.contains('401 unauthorized') ||
                  contentPrefix.contains('cloudflare') ||
                  contentPrefix.contains('gofile.io');

              if (hasHtmlSignature) {
                return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
              }

              // 2. Magic bytes validation for common formats when under 128 KB
              if (fileSize < 128 * 1024) {
                if (ext == '.rar' || ext.endsWith('.rar')) {
                  // RAR magic bytes: Rar! (0x52, 0x61, 0x72, 0x21)
                  if (bytes.length < 4 ||
                      bytes[0] != 0x52 ||
                      bytes[1] != 0x61 ||
                      bytes[2] != 0x72 ||
                      bytes[3] != 0x21) {
                    return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
                  }
                } else if (ext == '.zip') {
                  // ZIP magic bytes: PK (0x50, 0x4B)
                  if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
                    return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
                  }
                } else if (ext == '.7z') {
                  // 7z magic bytes: 7z (0x37, 0x7A)
                  if (bytes.length < 2 || bytes[0] != 0x37 || bytes[1] != 0x7A) {
                    return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
                  }
                } else if (ext == '.mp4' || ext == '.m4v') {
                  if (!contentPrefix.contains('ftyp')) {
                    return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
                  }
                } else if (ext == '.mkv' || ext == '.webm') {
                  if (bytes.length < 4 ||
                      bytes[0] != 0x1A ||
                      bytes[1] != 0x45 ||
                      bytes[2] != 0xDF ||
                      bytes[3] != 0xA3) {
                    return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
                  }
                }
              }
            }
          } catch (_) {}
        }
      } else {
        // File does not exist on disk, check suspicious small completed length
        if (task.completedLength > 0 &&
            task.completedLength < 64 * 1024 &&
            isExpectedBinary &&
            (task.url.contains('gofile.io') || task.url.contains('pan.') || task.url.contains('drive.'))) {
          return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
        }
      }
    } else {
      if (task.completedLength > 0 &&
          task.completedLength < 64 * 1024 &&
          isExpectedBinary &&
          (task.url.contains('gofile.io') || task.url.contains('pan.'))) {
        return const DownloadValidationResult.invalid('下载内容为重定向网页或鉴权失败，文件可能已失效');
      }
    }

    return const DownloadValidationResult.valid();
  }
}
