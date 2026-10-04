import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/aria2_android_channel.dart';
import 'package:kazumi/utils/aria2_ios_channel.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:logger/logger.dart';

/// Manages the aria2 process lifecycle for desktop, Android, and iOS platforms.
/// On Android and iOS: Uses bundled binary via platform channel
/// On Desktop: Launches system aria2c binary
class Aria2ProcessManager {
  static final Aria2ProcessManager _instance = Aria2ProcessManager._internal();
  factory Aria2ProcessManager() => _instance;
  Aria2ProcessManager._internal();

  Process? _aria2Process;
  bool _isRunning = false;
  final KazumiLogger _logger = KazumiLogger();

  bool get isRunning => _isRunning;

  /// Starts the aria2 process if it's not already running.
  /// On Android: Uses bundled binary via platform channel
  /// On iOS: Uses bundled binary via platform channel (self-signed builds only)
  /// On Desktop: Launches system aria2c binary
  Future<bool> start() async {
    // Check if aria2 is available on this platform
    final isAvailable = await Aria2FeatureManager().initialize();
    if (!isAvailable) {
      _logger.log(Level.warning, '[Aria2ProcessManager] aria2 is not available on this platform/build');
      return false;
    }

    // iOS: Use platform channel
    if (Platform.isIOS) {
      final isRunning = await Aria2IOSChannel.isAria2Running();
      if (isRunning) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 is already running on iOS');
        _isRunning = true;
        return true;
      }
    }

    // Android: Use platform channel
    else if (Platform.isAndroid) {
      final isRunning = await Aria2AndroidChannel.isAria2Running();
      if (isRunning) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 is already running on Android');
        _isRunning = true;
        return true;
      }
    }

    // Desktop: Check if aria2 process is already running (system-wide check)
    else {
      // First check our own tracked process
      if (_isRunning && _aria2Process != null) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 is already running (tracked process)');
        return true;
      }

      // Check if any aria2c process is running system-wide
      final isSystemRunning = await _isAria2RunningSystemWide();
      if (isSystemRunning) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 is already running system-wide, will reuse existing process');
        _isRunning = true;
        return true;
      }
    }

    try {
      final setting = GStorage.setting;
      final String secret = setting.get(SettingBoxKey.aria2Secret, defaultValue: '') as String;
      final int maxConcurrent = setting.get(SettingBoxKey.aria2MaxConcurrentDownloads, defaultValue: 2) as int;

      // Get the download directory
      final Directory downloadsDir = await _getDownloadsDirectory();

      // Build aria2 command arguments
      final List<String> args = [
        '--enable-rpc',
        '--rpc-listen-all=true',
        '--rpc-listen-port=6800',
        '--dir=${downloadsDir.path}',
        '--max-concurrent-downloads=$maxConcurrent',
        '--continue=true',
        '--max-connection-per-server=16',
        '--min-split-size=1M',
        '--split=16',
        '--disable-ipv6=true',
        '--http-accept-gzip=true',
        '--allow-overwrite=true',
        '--auto-file-renaming=true',
      ];

      if (secret.isNotEmpty) {
        args.add('--rpc-secret=$secret');
      }

      // iOS: Use platform channel with bundled binary (self-signed builds only)
      if (Platform.isIOS) {
        _logger.log(Level.info, '[Aria2ProcessManager] Starting aria2 on iOS via platform channel');
        _logger.log(Level.info, '[Aria2ProcessManager] Download directory: ${downloadsDir.path}');

        final success = await Aria2IOSChannel.startAria2(args);
        if (success) {
          _isRunning = true;
          _logger.log(Level.info, '[Aria2ProcessManager] aria2 started successfully on iOS');
        } else {
          _logger.log(Level.error, '[Aria2ProcessManager] Failed to start aria2 on iOS');
        }
        return success;
      }

      // Android: Use platform channel with bundled binary
      if (Platform.isAndroid) {
        // Add Android-specific DNS configuration
        args.add('--async-dns');
        // Note: DNS servers will be configured dynamically by the native code if needed

        _logger.log(Level.info, '[Aria2ProcessManager] Starting aria2 on Android via platform channel');
        _logger.log(Level.info, '[Aria2ProcessManager] Download directory: ${downloadsDir.path}');

        final success = await Aria2AndroidChannel.startAria2(args);
        if (success) {
          _isRunning = true;
          _logger.log(Level.info, '[Aria2ProcessManager] aria2 started successfully on Android');
        } else {
          _logger.log(Level.error, '[Aria2ProcessManager] Failed to start aria2 on Android');
        }
        return success;
      }

      // Desktop: Use system aria2c binary
      // Try to find aria2c in PATH or common locations
      String? aria2Path = await _findAria2Binary();

      if (aria2Path == null) {
        _logger.log(Level.error, '[Aria2ProcessManager] aria2c binary not found in PATH or common locations');
        return false;
      }

      _logger.log(Level.info, '[Aria2ProcessManager] Starting aria2c from: $aria2Path');
      _logger.log(Level.info, '[Aria2ProcessManager] Download directory: ${downloadsDir.path}');
      _logger.log(Level.info, '[Aria2ProcessManager] RPC port: 6800');

      try {
        _aria2Process = await Process.start(aria2Path, args);
        _isRunning = true;
      } on ProcessException catch (e) {
        _logger.log(Level.error, '[Aria2ProcessManager] Failed to start process: $e');
        // Check if port might be in use
        if (e.message.contains('bind') || e.message.contains('address')) {
          _logger.log(Level.warning, '[Aria2ProcessManager] Port 6800 might be in use');
        }
        _isRunning = false;
        _aria2Process = null;
        return false;
      }

      // Listen to stdout and stderr for logging
      _aria2Process!.stdout.listen((data) {
        final output = String.fromCharCodes(data).trim();
        if (output.isNotEmpty) {
          _logger.log(Level.info, '[Aria2ProcessManager] stdout: $output');
        }
      });

      _aria2Process!.stderr.listen((data) {
        final output = String.fromCharCodes(data).trim();
        if (output.isNotEmpty) {
          _logger.log(Level.warning, '[Aria2ProcessManager] stderr: $output');
        }
      });

      // Listen for process exit
      _aria2Process!.exitCode.then((exitCode) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 process exited with code: $exitCode');
        _isRunning = false;
        _aria2Process = null;
      });

      _logger.log(Level.info, '[Aria2ProcessManager] aria2 started successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.log(Level.error, '[Aria2ProcessManager] Failed to start aria2: $e', error: e, stackTrace: stackTrace);
      _isRunning = false;
      _aria2Process = null;
      return false;
    }
  }

  /// Stops the aria2 process if it's running.
  Future<void> stop() async {
    if (Platform.isIOS) {
      _logger.log(Level.info, '[Aria2ProcessManager] Stopping aria2 on iOS');
      await Aria2IOSChannel.stopAria2();
      _isRunning = false;
    } else if (Platform.isAndroid) {
      _logger.log(Level.info, '[Aria2ProcessManager] Stopping aria2 on Android');
      await Aria2AndroidChannel.stopAria2();
      _isRunning = false;
    } else if (_aria2Process != null) {
      _logger.log(Level.info, '[Aria2ProcessManager] Stopping aria2 process');
      _aria2Process!.kill();
      _aria2Process = null;
      _isRunning = false;
    } else {
      // If we don't have a tracked process, just mark as not running
      _logger.log(Level.info, '[Aria2ProcessManager] No tracked aria2 process to stop');
      _isRunning = false;
    }
  }

  /// Checks if aria2c is running system-wide (for desktop platforms).
  Future<bool> _isAria2RunningSystemWide() async {
    try {
      if (Platform.isWindows) {
        // Use tasklist to check for aria2c.exe
        final result = await Process.run(
          'tasklist',
          ['/FI', 'IMAGENAME eq aria2c.exe', '/FO', 'CSV', '/NH'],
        );
        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          // If output contains aria2c.exe, it's running
          if (output.isNotEmpty && output.contains('aria2c.exe')) {
            _logger.log(Level.info, '[Aria2ProcessManager] Found running aria2c.exe process');
            return true;
          }
        }
      } else {
        // Use pgrep or ps for Unix-like systems
        final result = await Process.run('pgrep', ['aria2c']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().trim();
          if (output.isNotEmpty) {
            _logger.log(Level.info, '[Aria2ProcessManager] Found running aria2c process');
            return true;
          }
        }
      }
    } catch (e) {
      _logger.log(Level.debug, '[Aria2ProcessManager] Could not check for running aria2 process: $e');
    }
    return false;
  }

  /// Restarts the aria2 process.
  Future<bool> restart() async {
    await stop();
    await Future.delayed(const Duration(seconds: 1));
    return await start();
  }

  /// Finds the aria2c binary in PATH or common locations.
  /// First checks for updated binary, then falls back to system binary.
  /// On Windows: Automatically installs via WinGet if not found.
  Future<String?> _findAria2Binary() async {
    // First check if there's an updated binary available
    try {
      final updatedPath = await _getUpdatedBinaryPath();
      if (updatedPath != null) {
        _logger.log(Level.info, '[Aria2ProcessManager] Using updated binary: $updatedPath');
        return updatedPath;
      }
    } catch (e) {
      _logger.log(Level.warning, '[Aria2ProcessManager] Could not check for updated binary: $e');
    }

    // Check for bundled asset binary
    try {
      final bundledPath = await _extractBundledAssetBinary();
      if (bundledPath != null) {
        _logger.log(Level.info, '[Aria2ProcessManager] Using bundled asset binary: $bundledPath');
        return bundledPath;
      }
    } catch (e) {
      _logger.log(Level.debug, '[Aria2ProcessManager] Bundled asset binary not available: $e');
    }

    // Try to run aria2c directly (will work if it's in PATH)
    try {
      if (Platform.isWindows) {
        // On Windows, try aria2c.exe
        final result = await Process.run('where', ['aria2c.exe']);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim().split('\n').first;
          if (path.isNotEmpty) {
            _logger.log(Level.info, '[Aria2ProcessManager] Found aria2c in PATH: $path');
            return path;
          }
        }
      } else {
        // On Unix-like systems, use 'which'
        final result = await Process.run('which', ['aria2c']);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty) {
            _logger.log(Level.info, '[Aria2ProcessManager] Found aria2c in PATH: $path');
            return path;
          }
        }
      }
    } catch (e) {
      _logger.log(Level.warning, '[Aria2ProcessManager] Could not find aria2c in PATH: $e');
    }

    // Try common installation locations
    final commonPaths = _getCommonAria2Paths();
    for (final path in commonPaths) {
      final file = File(path);
      if (await file.exists()) {
        _logger.log(Level.info, '[Aria2ProcessManager] Found aria2c at: $path');
        return path;
      }
    }

    // Windows: Try to install via WinGet if not found
    if (Platform.isWindows) {
      _logger.log(Level.info, '[Aria2ProcessManager] aria2c not found, attempting to install via WinGet...');
      final installed = await _installAria2ViaWinGet();
      if (installed) {
        // Try to find it again after installation
        try {
          final result = await Process.run('where', ['aria2c.exe']);
          if (result.exitCode == 0) {
            final path = result.stdout.toString().trim().split('\n').first;
            if (path.isNotEmpty) {
              _logger.log(Level.info, '[Aria2ProcessManager] aria2c installed successfully: $path');
              return path;
            }
          }
        } catch (e) {
          _logger.log(Level.error, '[Aria2ProcessManager] Failed to find aria2c after installation: $e');
        }
      }
    }

    return null;
  }

  /// Installs aria2 via WinGet on Windows (async installation).
  /// Returns true if installation command was executed successfully.
  Future<bool> _installAria2ViaWinGet() async {
    try {
      _logger.log(Level.info, '[Aria2ProcessManager] Checking if WinGet is available...');

      // Check if WinGet is available
      final wingetCheck = await Process.run('winget', ['--version']);
      if (wingetCheck.exitCode != 0) {
        _logger.log(Level.error, '[Aria2ProcessManager] WinGet is not available on this system');
        return false;
      }

      _logger.log(Level.info, '[Aria2ProcessManager] WinGet version: ${wingetCheck.stdout.toString().trim()}');
      _logger.log(Level.info, '[Aria2ProcessManager] Installing aria2 via WinGet (this may take a few minutes)...');

      // Install aria2 using WinGet (accept all prompts)
      final installResult = await Process.run(
        'winget',
        ['install', 'aria2.aria2', '--accept-source-agreements', '--accept-package-agreements', '--silent'],
        runInShell: true,
      );

      if (installResult.exitCode == 0) {
        _logger.log(Level.info, '[Aria2ProcessManager] aria2 installed successfully via WinGet');
        return true;
      } else {
        _logger.log(Level.error, '[Aria2ProcessManager] WinGet installation failed: ${installResult.stderr}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.log(Level.error, '[Aria2ProcessManager] Failed to install aria2 via WinGet: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets the updated binary path if available (from Aria2Updater).
  Future<String?> _getUpdatedBinaryPath() async {
    try {
      String updateDirPath;
      if (Platform.isWindows) {
        final appDir = await getApplicationSupportDirectory();
        updateDirPath = '${appDir.path}\\aria2_update';
      } else {
        final appDir = await getApplicationSupportDirectory();
        updateDirPath = '${appDir.path}/aria2_update';
      }

      final binaryName = Platform.isWindows ? 'aria2c.exe' : 'aria2c';
      final binaryPath = Platform.isWindows
          ? '$updateDirPath\\$binaryName'
          : '$updateDirPath/$binaryName';
      final binaryFile = File(binaryPath);

      if (await binaryFile.exists()) {
        return binaryPath;
      }
    } catch (e) {
      _logger.log(Level.debug, '[Aria2ProcessManager] No updated binary found: $e');
    }

    return null;
  }

  /// Extracts bundled aria2c binary from Flutter assets for desktop platforms.
  Future<String?> _extractBundledAssetBinary() async {
    try {
      String assetPath;
      String binaryName;
      if (Platform.isWindows) {
        assetPath = 'assets/bin/windows/aria2c.exe';
        binaryName = 'aria2c.exe';
      } else if (Platform.isMacOS) {
        assetPath = 'assets/bin/macos/aria2c';
        binaryName = 'aria2c';
      } else if (Platform.isLinux) {
        assetPath = 'assets/bin/linux/aria2c';
        binaryName = 'aria2c';
      } else {
        return null;
      }

      final appDir = await getApplicationSupportDirectory();
      final targetFile = File('${appDir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}$binaryName');

      if (!await targetFile.exists()) {
        _logger.log(Level.info, '[Aria2ProcessManager] Extracting bundled asset binary: $assetPath');
        await targetFile.parent.create(recursive: true);
        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', targetFile.path]);
      }
      return targetFile.path;
    } catch (e) {
      _logger.log(Level.debug, '[Aria2ProcessManager] Extracting bundled asset failed or asset not found: $e');
      return null;
    }
  }

  /// Returns a list of common aria2c installation paths for different platforms.
  List<String> _getCommonAria2Paths() {
    if (Platform.isWindows) {
      return [
        'C:\\Program Files\\aria2\\aria2c.exe',
        'C:\\Program Files (x86)\\aria2\\aria2c.exe',
        'C:\\aria2\\aria2c.exe',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/usr/local/bin/aria2c',
        '/opt/homebrew/bin/aria2c',
        '/usr/bin/aria2c',
      ];
    } else if (Platform.isLinux) {
      return [
        '/usr/bin/aria2c',
        '/usr/local/bin/aria2c',
        '/opt/aria2/bin/aria2c',
      ];
    } else if (Platform.isAndroid) {
      // For Android, we might need to bundle aria2c with the app
      // or install it via Termux
      return [
        '/data/data/com.termux/files/usr/bin/aria2c',
      ];
    }
    return [];
  }

  /// Gets the appropriate downloads directory for the current platform.
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // On Android, use external storage downloads directory
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final downloadsDir = Directory('${externalDir.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      }
    }

    // For desktop platforms, use the system downloads directory
    try {
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
      // If null, fall through to fallback
    } catch (e) {
      _logger.log(Level.warning, '[Aria2ProcessManager] Could not get downloads directory: $e');
    }

    // Fallback: use app directory
    _logger.log(Level.info, '[Aria2ProcessManager] Using app directory for downloads');
    final Directory appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/Downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }
}
