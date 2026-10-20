import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/core/git_proxy_interceptor.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 安装类型枚举
enum InstallationType {
  windowsMsix, // Kazumi_windows_1.7.5.msix
  windowsPortable, // Kazumi_windows_1.7.5.zip
  linuxDeb, // Kazumi_linux_1.7.5_amd64.deb
  linuxTar, // Kazumi_linux_1.7.5_amd64.tar.gz
  macosDmg, // Kazumi_macos_1.7.5.dmg
  androidApk, // Kazumi_android_1.7.5.apk
  ios, // iOS App
  unknown,
}

/// 更新信息类
class UpdateInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;
  final InstallationType? installationType;
  final List<InstallationType> availableInstallationTypes;
  final List<dynamic> assets;

  UpdateInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    this.installationType,
    this.availableInstallationTypes = const [],
    this.assets = const [],
  });

  /// 获取默认的安装类型（第一个可用类型）
  InstallationType get recommendedInstallationType {
    if (availableInstallationTypes.isNotEmpty) {
      return availableInstallationTypes.first;
    }
    return installationType ?? InstallationType.unknown;
  }
}

class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();
  static const String _integrityErrorCode = 'INTEGRITY_CHECK_FAILED';

  factory AutoUpdater() => _instance;

  AutoUpdater._internal() {
    _dio.interceptors.add(GitProxyInterceptor());
  }

  final Dio _dio = Dio();

  Box get setting => GStorage.setting;

  AppTranslations get _translations => t;

  /// 检测所有可能的安装类型
  Future<List<InstallationType>> _detectAvailableInstallationTypes() async {
    List<InstallationType> availableTypes = [];

    try {
      if (Platform.isWindows) {
        // Windows 平台支持 MSIX 和 ZIP 便携版
        availableTypes.add(InstallationType.windowsMsix);
        availableTypes.add(InstallationType.windowsPortable);
      } else if (Platform.isLinux) {
        // Linux 平台支持 DEB 和 TAR.GZ
        availableTypes.add(InstallationType.linuxDeb);
        availableTypes.add(InstallationType.linuxTar);
      } else if (Platform.isMacOS) {
        // macOS 平台支持 DMG
        availableTypes.add(InstallationType.macosDmg);
      } else if (Platform.isIOS) {
        // iOS 平台通过 Github
        availableTypes.add(InstallationType.ios);
      } else if (Platform.isAndroid) {
        // Android 平台支持 APK
        availableTypes.add(InstallationType.androidApk);
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '检测安装类型失败: ${e.toString()}');
    }

    if (availableTypes.isEmpty) {
      availableTypes.add(InstallationType.unknown);
    }

    return availableTypes;
  }

  /// 检查是否有新版本可用
  Future<UpdateInfo?> checkForUpdates() async {
    final updateTexts = _translations.settings.update;
    try {
      final response = await _dio.get(Api.latestApp);
      final data = response.data;

      if (data == null || !data.containsKey('tag_name')) {
        throw Exception(updateTexts.error.invalidResponse);
      }

      final remoteVersion = data['tag_name'] as String;
      final currentVersion = Api.version;

      if (Utils.needUpdate(currentVersion, remoteVersion)) {
        final availableTypes = await _detectAvailableInstallationTypes();

        return UpdateInfo(
          version: remoteVersion,
          description: data['body'] ?? updateTexts.fallbackDescription,
          downloadUrl: '',
          // 将在用户选择安装类型后填充
          releaseNotes: data['html_url'] ?? '',
          publishedAt: data['published_at'] ?? '',
          installationType: availableTypes.first,
          // 保持兼容性
          availableInstallationTypes: availableTypes,
          assets: data['assets'] ?? [],
        );
      }

      return null;
    } catch (e) {
      KazumiLogger().log(Level.error, '检查更新失败: ${e.toString()}');
      rethrow;
    }
  }

  /// 自动检查更新（仅在启用自动更新时）
  Future<void> autoCheckForUpdates() async {
    final autoUpdate =
        setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (!autoUpdate) return;

    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: true);
      }
    } catch (e) {
      // 自动检查失败时不显示错误
      KazumiLogger().log(Level.warning, '自动检查更新失败: ${e.toString()}');
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdates() async {
    final updateTexts = _translations.settings.update;
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: false);
      } else {
        KazumiDialog.showToast(message: updateTexts.toast.alreadyLatest);
      }
    } catch (e) {
      KazumiDialog.showToast(message: updateTexts.toast.checkFailed);
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo, {bool isAutoCheck = false}) {
    KazumiDialog.show(
      builder: (context) {
        final translations = context.t;
        final updateTexts = translations.settings.update;
        return AlertDialog(
          title: Text(updateTexts.dialog.title
              .replaceFirst('{version}', updateInfo.version)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(updateInfo.description),
                if (updateInfo.publishedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    updateTexts.dialog.publishedAt.replaceFirst(
                        '{date}', Utils.formatDate(updateInfo.publishedAt)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (!Platform.isLinux && !Platform.isIOS) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          updateTexts.dialog.installationTypeLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        ...updateInfo.availableInstallationTypes.map((type) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  KazumiDialog.dismiss();
                                  _downloadUpdateWithType(updateInfo, type);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.download,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getInstallationTypeDescription(
                                              translations, type),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isAutoCheck)
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(
                      message: updateTexts.toast.autoUpdateDisabled);
                },
                child: Text(
                  updateTexts.dialog.actions.disableAutoUpdate,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                updateTexts.dialog.actions.remindLater,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (updateInfo.releaseNotes.isNotEmpty)
              TextButton(
                onPressed: () {
                  launchUrl(Uri.parse(updateInfo.releaseNotes),
                      mode: LaunchMode.externalApplication);
                },
                child: Text(updateTexts.dialog.actions.viewDetails),
              ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                // 直接使用第一个可用的安装类型
                if (updateInfo.availableInstallationTypes.isNotEmpty) {
                  _downloadUpdateWithType(
                      updateInfo, updateInfo.availableInstallationTypes.first);
                }
              },
              child: Text(updateTexts.dialog.actions.updateNow),
            ),
          ],
        );
      },
    );
  }

  /// 获取安装类型的描述
  String _getInstallationTypeDescription(
      AppTranslations translations, InstallationType type) {
    final labels = translations.settings.update.installationType;
    switch (type) {
      case InstallationType.windowsMsix:
        return labels.windowsMsix;
      case InstallationType.windowsPortable:
        return labels.windowsPortable;
      case InstallationType.linuxDeb:
        return labels.linuxDeb;
      case InstallationType.linuxTar:
        return labels.linuxTar;
      case InstallationType.macosDmg:
        return labels.macosDmg;
      case InstallationType.androidApk:
        return labels.androidApk;
      case InstallationType.ios:
        return labels.ios;
      case InstallationType.unknown:
        return labels.unknown;
    }
  }

  /// 根据选择的类型下载更新
  Future<void> _downloadUpdateWithType(
      UpdateInfo updateInfo, InstallationType selectedType) async {
    final translations = _translations;
    final updateTexts = translations.settings.update;
    try {
      // iOS 和 Linux 直接跳转到 Release 页面
      if (selectedType == InstallationType.ios ||
          selectedType == InstallationType.linuxDeb ||
          selectedType == InstallationType.linuxTar) {
        String releaseUrl = updateInfo.releaseNotes;
        if (releaseUrl.isEmpty) {
          releaseUrl = Api.latestApp;
        }
        launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
        return;
      }

      final downloadUrl =
          await _getDownloadUrlForType(updateInfo.assets, selectedType);
      if (downloadUrl.isEmpty) {
        KazumiDialog.showToast(
            message: updateTexts.toast.downloadLinkMissing.replaceFirst(
          '{type}',
          _getInstallationTypeDescription(translations, selectedType),
        ));
        return;
      }

      // 获取文件的 SHA256 哈希值用于验证
      final expectedHash =
          _getFileHashFromAssets(updateInfo.assets, downloadUrl);

      // 创建一个临时的 UpdateInfo 对象用于下载
      final downloadInfo = UpdateInfo(
        version: updateInfo.version,
        description: updateInfo.description,
        downloadUrl: downloadUrl,
        releaseNotes: updateInfo.releaseNotes,
        publishedAt: updateInfo.publishedAt,
        installationType: selectedType,
        availableInstallationTypes: [selectedType],
        assets: updateInfo.assets,
      );

      _downloadUpdate(downloadInfo, expectedHash);
    } catch (e) {
      KazumiDialog.showToast(
        message: updateTexts.toast.downloadFailed
            .replaceFirst('{error}', e.toString()),
      );
      KazumiLogger().log(Level.error, '下载更新失败: ${e.toString()}');
    }
  }

  /// 下载更新
  Future<void> _downloadUpdate(
      UpdateInfo updateInfo, String expectedHash) async {
    final translations = _translations;
    final updateTexts = translations.settings.update;
    if (updateInfo.downloadUrl.isEmpty) {
      KazumiDialog.showToast(message: updateTexts.toast.noCompatibleLink);
      return;
    }

    // 显示下载进度对话框
    KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        final dialogTexts = context.t.settings.update;
        return AlertDialog(
          title: Text(dialogTexts.download.progressTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _downloadProgress,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text('${(value * 100).toStringAsFixed(1)}%'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelDownload();
                KazumiDialog.dismiss();
              },
              child: Text(dialogTexts.download.cancel),
            ),
          ],
        );
      },
    );

    try {
      final downloadPath = await _downloadFile(
          updateInfo.downloadUrl, updateInfo.version, expectedHash);

      // 不自动关闭对话框，而是显示下载完成状态
      _showDownloadCompleteDialog(downloadPath, updateInfo);
    } catch (e) {
      KazumiDialog.dismiss();

      // 显示详细的错误信息
      String errorMessage = updateTexts.download.error.general;
      if (e.toString().contains('Permission denied') ||
          e.toString().contains('Operation not permitted')) {
        errorMessage = updateTexts.download.error.permission;
      } else if (e.toString().contains('No space left')) {
        errorMessage = updateTexts.download.error.diskFull;
      } else if (e.toString().contains('Network')) {
        errorMessage = updateTexts.download.error.network;
      } else if (e.toString().contains(_integrityErrorCode)) {
        errorMessage = updateTexts.download.error.integrity;
      }

      KazumiDialog.show(
        builder: (context) {
          return AlertDialog(
            title: Text(updateTexts.download.error.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 8),
                Text(
                  updateTexts.download.error.details
                      .replaceFirst('{error}', e.toString()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(),
                child: Text(updateTexts.download.error.confirm),
              ),
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                  // 重新尝试下载
                  _downloadUpdate(updateInfo, expectedHash);
                },
                child: Text(updateTexts.download.error.retry),
              ),
            ],
          );
        },
      );

      KazumiLogger().log(Level.error, '下载更新失败: ${e.toString()}');
    }
  }

  final ValueNotifier<double> _downloadProgress = ValueNotifier(0.0);
  CancelToken? _cancelToken;

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  /// 显示下载完成对话框
  void _showDownloadCompleteDialog(String filePath, UpdateInfo updateInfo) {
    // 替换当前的下载进度对话框内容
    KazumiDialog.dismiss();

    KazumiDialog.show(
      builder: (context) {
        final translations = context.t;
        final updateTexts = translations.settings.update;
        return AlertDialog(
          title: Text(updateTexts.download.complete.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(updateTexts.download.complete.message
                        .replaceFirst('{version}', updateInfo.version)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                updateTexts.download.complete.quitNotice,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      updateTexts.download.complete.fileLocation,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      filePath,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                updateTexts.download.complete.buttons.later,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                // 在文件管理器中显示文件
                _revealInFileManager(filePath);
              },
              child: Text(updateTexts.download.complete.buttons.openFolder),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                _installUpdate(
                    filePath, updateInfo.recommendedInstallationType);
              },
              child: Text(updateTexts.download.complete.buttons.installNow),
            ),
          ],
        );
      },
    );
  }

  /// 下载文件
  Future<String> _downloadFile(
      String url, String version, String expectedHash) async {
    final fileName = _getFileNameFromUrl(url, version);

    // 统一使用临时目录
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);

    // 检查文件是否已存在
    if (await file.exists()) {
      try {
        //使用哈希验证文件完整性
        final localHash = await Utils.calculateFileHash(file);
        if (localHash == expectedHash) {
          // 文件已存在且哈希匹配，直接返回
          KazumiLogger().log(Level.info, '文件已存在且哈希验证通过，跳过下载: $filePath');
          _downloadProgress.value = 1.0;
          return filePath;
        } else {
          // 文件存在但哈希不匹配，删除后重新下载
          KazumiLogger().log(Level.info,
              '检测到文件哈希不匹配 (本地: $localHash, 期望: $expectedHash)，删除后重新下载');
          await file.delete();
        }
      } catch (e) {
        // 验证过程中出错，删除文件重新下载
        KazumiLogger().log(Level.warning, '文件验证失败，删除后重新下载: ${e.toString()}');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    _cancelToken = CancelToken();

    await _dio.download(
      url,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _downloadProgress.value = received / total;
        }
      },
    );

    // 下载完成后验证文件哈希
    final downloadedHash = await Utils.calculateFileHash(file);
    if (downloadedHash != expectedHash) {
      // 哈希不匹配，删除文件并抛出异常
      await file.delete();
      throw Exception(
          '$_integrityErrorCode: expected=$expectedHash actual=$downloadedHash');
    }
    KazumiLogger().log(Level.info, '文件下载完成，哈希验证通过: $filePath');

    return filePath;
  }

  /// 安装更新
  void _installUpdate(
      String filePath, InstallationType installationType) async {
    final updateTexts = _translations.settings.update;
    try {
      // 显示准备退出的提示
      KazumiDialog.showToast(message: updateTexts.toast.prepareToInstall);

      await Future.delayed(const Duration(seconds: 2));

      if (Platform.isWindows) {
        if (installationType == InstallationType.windowsMsix) {
          final Uri fileUri = Uri.file(filePath);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
          } else {
            throw 'Could not launch $fileUri';
          }
        } else {
          await Process.start('explorer.exe', [filePath], runInShell: true);
        }
      } else if (Platform.isMacOS) {
        if (filePath.endsWith('.dmg')) {
          await Process.start('open', [filePath]);
          exit(0);
        }
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          final errorDetail = result.message.isNotEmpty
              ? result.message
              : updateTexts.toast.unknownReason;
          KazumiDialog.showToast(
            message: updateTexts.toast.openInstallerFailed
                .replaceFirst('{error}', errorDetail),
          );
          return;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
      exit(0);
    } catch (e) {
      KazumiDialog.showToast(
        message: updateTexts.toast.launchInstallerFailed
            .replaceFirst('{error}', e.toString()),
      );
      KazumiLogger().log(Level.error, '启动安装程序失败: ${e.toString()}');
    }
  }

  /// 在文件管理器中显示文件
  void _revealInFileManager(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', filePath],
            runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        // 尝试打开包含文件的文件夹
        final directory = Directory(filePath).parent.path;
        await Process.start('xdg-open', [directory]);
      }
      KazumiDialog.dismiss();
    } catch (e) {
      KazumiDialog.showToast(
          message: _translations.settings.update.toast.revealFailed);
      KazumiLogger().log(Level.warning, '打开文件管理器失败: ${e.toString()}');
    }
  }

  /// 根据安装类型获取下载链接
  Future<String> _getDownloadUrlForType(
      List<dynamic> assets, InstallationType type) async {
    final patterns =
        _getFilePatterns(type).map((p) => p.toLowerCase()).toList();

    try {
      final asset = assets.cast<Map<String, dynamic>>().firstWhere((asset) {
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        final downloadUrl = (asset['browser_download_url'] as String?) ?? '';
        return downloadUrl.isNotEmpty &&
            patterns.every((pattern) => name.contains(pattern));
      });
      return (asset['browser_download_url'] as String?) ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 获取合适的下载链接
  /// 根据安装类型获取文件名模式
  List<String> _getFilePatterns(InstallationType installationType) {
    switch (installationType) {
      case InstallationType.windowsMsix:
        return ['windows', '.msix'];
      case InstallationType.windowsPortable:
        return ['windows', '.zip'];
      case InstallationType.macosDmg:
        return ['macos', '.dmg'];
      case InstallationType.androidApk:
        return ['android', '.apk'];
      // 以下类型直接跳转到 GitHub Release 页面，不需要下载文件
      case InstallationType.linuxDeb:
      case InstallationType.linuxTar:
      case InstallationType.ios:
      case InstallationType.unknown:
        return [];
    }
  }

  /// 从URL获取文件名
  String _getFileNameFromUrl(String url, String version) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    if (fileName.isNotEmpty) {
      return fileName;
    }

    // 回退方案
    String extension = '';
    if (Platform.isWindows) {
      extension = '.msix';
    } else if (Platform.isMacOS) {
      extension = '.dmg';
    } else if (Platform.isLinux) {
      extension = '.deb';
    } else if (Platform.isAndroid) {
      extension = '.apk';
    }
    return 'Kazumi-$version$extension';
  }

  /// 从 assets 中获取文件的哈希值
  String _getFileHashFromAssets(List<dynamic> assets, String downloadUrl) {
    for (final asset in assets) {
      final assetDownloadUrl = asset['browser_download_url'] as String? ?? '';
      if (assetDownloadUrl == downloadUrl) {
        final digest = asset['digest'] as String? ?? '';
        if (digest.isNotEmpty && digest.startsWith('sha256:')) {
          return digest.substring(7); // 移除 "sha256:" 前缀
        }
      }
    }
    return '';
  }
}
