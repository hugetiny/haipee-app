import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/adaptive_dialog_frame.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 安装类型枚举
enum InstallationType {
  windowsMsix, // Haipee_windows_1.7.5.msix
  windowsPortable, // Haipee_windows_1.7.5.zip
  linuxDeb, // Haipee_linux_1.7.5_amd64.deb
  linuxTar, // Haipee_linux_1.7.5_amd64.tar.gz
  macosDmg, // Haipee_macos_1.7.5.dmg
  androidApk, // Haipee_android_1.7.5.apk
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
      HaipeeLogger().log(Level.warning, '检测安装类型失败: ${e.toString()}');
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
      HaipeeLogger().log(Level.error, '检查更新失败: ${e.toString()}');
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
      HaipeeLogger().log(Level.warning, '自动检查更新失败: ${e.toString()}');
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
        HaipeeDialog.showToast(message: updateTexts.toast.alreadyLatest);
      }
    } catch (e) {
      HaipeeDialog.showToast(message: updateTexts.toast.checkFailed);
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo, {bool isAutoCheck = false}) {
    HaipeeDialog.show(
      builder: (context) {
        final translations = context.t;
        final updateTexts = translations.settings.update;
        final isMobile = MediaQuery.sizeOf(context).width < 640;
        final theme = Theme.of(context);

        return AdaptiveDialogFrame(
          maxWidth: 540,
          maxHeight: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        updateTexts.dialog.title
                            .replaceFirst('{version}', updateInfo.version),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => HaipeeDialog.dismiss(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updateInfo.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                      if (updateInfo.publishedAt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          updateTexts.dialog.publishedAt.replaceFirst(
                              '{date}', Utils.formatDate(updateInfo.publishedAt)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (!Platform.isLinux && !Platform.isIOS) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                updateTexts.dialog.installationTypeLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...updateInfo.availableInstallationTypes.map((type) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        HaipeeDialog.dismiss();
                                        _downloadUpdateWithType(updateInfo, type);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.25),
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.download_rounded,
                                              size: 18,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _getInstallationTypeDescription(
                                                    translations, type),
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 12,
                                              color: theme.colorScheme.outline,
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
              ),
              // Footer
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  12 + (isMobile ? MediaQuery.paddingOf(context).bottom : 0),
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isAutoCheck)
                      TextButton(
                        onPressed: () {
                          setting.put(SettingBoxKey.autoUpdate, false);
                          HaipeeDialog.dismiss();
                          HaipeeDialog.showToast(
                              message: updateTexts.toast.autoUpdateDisabled);
                        },
                        child: Text(
                          updateTexts.dialog.actions.disableAutoUpdate,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    TextButton(
                      onPressed: () => HaipeeDialog.dismiss(),
                      child: Text(
                        updateTexts.dialog.actions.remindLater,
                        style: TextStyle(color: theme.colorScheme.outline),
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
                    FilledButton.icon(
                      onPressed: () {
                        HaipeeDialog.dismiss();
                        if (updateInfo.availableInstallationTypes.isNotEmpty) {
                          _downloadUpdateWithType(
                              updateInfo, updateInfo.availableInstallationTypes.first);
                        }
                      },
                      icon: const Icon(Icons.upgrade_rounded, size: 18),
                      label: Text(updateTexts.dialog.actions.updateNow),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        HaipeeDialog.showToast(
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
      HaipeeDialog.showToast(
        message: updateTexts.toast.downloadFailed
            .replaceFirst('{error}', e.toString()),
      );
      HaipeeLogger().log(Level.error, '下载更新失败: ${e.toString()}');
    }
  }

  /// 下载更新
  Future<void> _downloadUpdate(
      UpdateInfo updateInfo, String expectedHash) async {
    final translations = _translations;
    final updateTexts = translations.settings.update;
    if (updateInfo.downloadUrl.isEmpty) {
      HaipeeDialog.showToast(message: updateTexts.toast.noCompatibleLink);
      return;
    }

    // 显示下载进度对话框
    HaipeeDialog.show(
      clickMaskDismiss: false,
      builder: (context) {
        final dialogTexts = context.t.settings.update;
        final theme = Theme.of(context);
        final isMobile = MediaQuery.sizeOf(context).width < 640;

        return AdaptiveDialogFrame(
          maxWidth: 440,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              20 + (isMobile ? MediaQuery.paddingOf(context).bottom : 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogTexts.download.progressTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<double>(
                  valueListenable: _downloadProgress,
                  builder: (context, value, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(value * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _cancelDownload();
                      HaipeeDialog.dismiss();
                    },
                    child: Text(dialogTexts.download.cancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final downloadPath = await _downloadFile(
          updateInfo.downloadUrl, updateInfo.version, expectedHash);

      // 不自动关闭对话框，而是显示下载完成状态
      _showDownloadCompleteDialog(downloadPath, updateInfo);
    } catch (e) {
      HaipeeDialog.dismiss();

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

      HaipeeDialog.show(
        builder: (context) {
          final theme = Theme.of(context);
          final isMobile = MediaQuery.sizeOf(context).width < 640;
          return AdaptiveDialogFrame(
            maxWidth: 440,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                16 + (isMobile ? MediaQuery.paddingOf(context).bottom : 0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: theme.colorScheme.error, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        updateTexts.download.error.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(errorMessage),
                  const SizedBox(height: 8),
                  Text(
                    updateTexts.download.error.details
                        .replaceFirst('{error}', e.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => HaipeeDialog.dismiss(),
                        child: Text(updateTexts.download.error.confirm),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          HaipeeDialog.dismiss();
                          // 重新尝试下载
                          _downloadUpdate(updateInfo, expectedHash);
                        },
                        child: Text(updateTexts.download.error.retry),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      HaipeeLogger().log(Level.error, '下载更新失败: ${e.toString()}');
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
    HaipeeDialog.dismiss();

    HaipeeDialog.show(
      builder: (context) {
        final translations = context.t;
        final updateTexts = translations.settings.update;
        final theme = Theme.of(context);
        final isMobile = MediaQuery.sizeOf(context).width < 640;

        return AdaptiveDialogFrame(
          maxWidth: 480,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              16 + (isMobile ? MediaQuery.paddingOf(context).bottom : 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        updateTexts.download.complete.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  updateTexts.download.complete.message
                      .replaceFirst('{version}', updateInfo.version),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  updateTexts.download.complete.quitNotice,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updateTexts.download.complete.fileLocation,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        filePath,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => HaipeeDialog.dismiss(),
                      child: Text(
                        updateTexts.download.complete.buttons.later,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                    if (!Platform.isAndroid && !Platform.isIOS) ...[
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _revealInFileManager(filePath),
                        child: Text(
                            updateTexts.download.complete.buttons.openFolder),
                      ),
                    ],
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        HaipeeDialog.dismiss();
                        _installUpdate(
                            filePath, updateInfo.recommendedInstallationType);
                      },
                      child: Text(
                          updateTexts.download.complete.buttons.installNow),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        if (expectedHash.isNotEmpty) {
          final localHash = await Utils.calculateFileHash(file);
          if (localHash.toLowerCase() == expectedHash.toLowerCase()) {
            // 文件已存在且哈希匹配，直接返回
            HaipeeLogger().log(Level.info, '文件已存在且哈希验证通过，跳过下载: $filePath');
            _downloadProgress.value = 1.0;
            return filePath;
          } else {
            // 文件存在但哈希不匹配，删除后重新下载
            HaipeeLogger().log(Level.info,
                '检测到文件哈希不匹配 (本地: $localHash, 期望: $expectedHash)，删除后重新下载');
            await file.delete();
          }
        } else {
          // 没有提供远端哈希时，认为已存在的文件有效
          HaipeeLogger().log(Level.info, '文件已存在，跳过下载: $filePath');
          _downloadProgress.value = 1.0;
          return filePath;
        }
      } catch (e) {
        // 验证过程中出错，删除文件重新下载
        HaipeeLogger().log(Level.warning, '文件验证失败，删除后重新下载: ${e.toString()}');
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

    // 下载完成后验证文件哈希（仅当远端提供哈希时校验）
    if (expectedHash.isNotEmpty) {
      final downloadedHash = await Utils.calculateFileHash(file);
      if (downloadedHash.toLowerCase() != expectedHash.toLowerCase()) {
        // 哈希不匹配，删除文件并抛出异常
        await file.delete();
        throw Exception(
            '$_integrityErrorCode: expected=$expectedHash actual=$downloadedHash');
      }
      HaipeeLogger().log(Level.info, '文件下载完成，哈希验证通过: $filePath');
    }

    return filePath;
  }

  /// 安装更新
  void _installUpdate(
      String filePath, InstallationType installationType) async {
    final updateTexts = _translations.settings.update;
    try {
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          final errorDetail = result.message.isNotEmpty
              ? result.message
              : updateTexts.toast.unknownReason;
          HaipeeDialog.showToast(
            message: updateTexts.toast.openInstallerFailed
                .replaceFirst('{error}', errorDetail),
          );
        }
        // 注意：Android 下绝不能调用 exit(0)！
        // 必须保持进程存活，否则 OpenFilex 的 FileProvider 会在系统安装器读取 APK 流时崩溃退出，导致解析安装包失败。
        return;
      }

      // 显示准备退出的提示 (针对桌面平台)
      HaipeeDialog.showToast(message: updateTexts.toast.prepareToInstall);
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
        } else if (filePath.endsWith('.zip')) {
          _revealInFileManager(filePath);
          return;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
      exit(0);
    } catch (e) {
      HaipeeDialog.showToast(
        message: updateTexts.toast.launchInstallerFailed
            .replaceFirst('{error}', e.toString()),
      );
      HaipeeLogger().log(Level.error, '启动安装程序失败: ${e.toString()}');
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
      HaipeeDialog.dismiss();
    } catch (e) {
      HaipeeDialog.showToast(
          message: _translations.settings.update.toast.revealFailed);
      HaipeeLogger().log(Level.warning, '打开文件管理器失败: ${e.toString()}');
    }
  }

  /// 根据安装类型获取下载链接
  Future<String> _getDownloadUrlForType(
      List<dynamic> assets, InstallationType type) async {
    // 针对 Android 优先匹配 arm64 架构（覆盖 99% 现代 Android 机型）
    if (type == InstallationType.androidApk) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name']?.toString() ?? '').toLowerCase();
        final downloadUrl = asset['browser_download_url']?.toString() ?? '';
        if (downloadUrl.isNotEmpty &&
            name.contains('.apk') &&
            (name.contains('arm64') || name.contains('arm64-v8a'))) {
          return downloadUrl;
        }
      }
      // 降级兜底：若未匹配到明确的 arm64，匹配任意 .apk 安装包
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name']?.toString() ?? '').toLowerCase();
        final downloadUrl = asset['browser_download_url']?.toString() ?? '';
        if (downloadUrl.isNotEmpty && name.contains('.apk')) {
          return downloadUrl;
        }
      }
    }

    // 针对 macOS 支持 .dmg 与 .zip (Universal 便携包)
    if (type == InstallationType.macosDmg) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name']?.toString() ?? '').toLowerCase();
        final downloadUrl = asset['browser_download_url']?.toString() ?? '';
        if (downloadUrl.isNotEmpty &&
            name.contains('macos') &&
            (name.contains('.dmg') || name.contains('.zip'))) {
          return downloadUrl;
        }
      }
    }

    final patterns =
        _getFilePatterns(type).map((p) => p.toLowerCase()).toList();

    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      final downloadUrl = asset['browser_download_url']?.toString() ?? '';
      if (downloadUrl.isNotEmpty &&
          patterns.every((pattern) => name.contains(pattern))) {
        return downloadUrl;
      }
    }
    return '';
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
    return 'haipee-$version$extension';
  }

  /// 从 assets 中获取文件的哈希值
  String _getFileHashFromAssets(List<dynamic> assets, String downloadUrl) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      final assetDownloadUrl = asset['browser_download_url']?.toString() ?? '';
      if (assetDownloadUrl == downloadUrl) {
        final digest = asset['digest']?.toString() ?? '';
        if (digest.isNotEmpty && digest.startsWith('sha256:')) {
          return digest.substring(7); // 移除 "sha256:" 前缀
        }
      }
    }
    return '';
  }
}
