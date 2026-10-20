import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/aria2_client.dart';
import 'package:kazumi/utils/aria2_process_manager.dart';
import 'package:kazumi/utils/aria2_updater.dart';
import 'package:kazumi/utils/aria2_feature_manager.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/providers/download_providers.dart';
import 'package:logger/logger.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  ConsumerState<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _maxConcurrentController =
      TextEditingController();
  String _downloadDirectory = '';

  final KazumiLogger _logger = KazumiLogger();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    Future.microtask(() {
      if (mounted) _checkAria2Status();
    });
  }

  void _checkAria2Status() {
    if (Platform.isIOS) {
      final isAvailable = Aria2FeatureManager().isAvailable;
      if (isAvailable) {
        final isRunning = Aria2ProcessManager().isRunning;
        ref.read(downloadSettingsProvider.notifier).setAria2Status(
          isRunning ? 'aria2 运行中（自签名版本）' : 'aria2 未运行（自签名版本）'
        );
      } else {
        ref.read(downloadSettingsProvider.notifier).setAria2Status(
          'iOS App Store 版本不支持 aria2\n请使用自签名 IPA 版本'
        );
      }
    } else {
      final isRunning = Aria2ProcessManager().isRunning;
      ref.read(downloadSettingsProvider.notifier).setAria2Status(
        isRunning ? 'aria2 运行中' : 'aria2 未运行'
      );
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _secretController.dispose();
    _timeoutController.dispose();
    _maxConcurrentController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final setting = GStorage.setting;
    _endpointController.text = setting.get(
      SettingBoxKey.aria2Endpoint,
      defaultValue: 'http://127.0.0.1:6800/jsonrpc',
    ) as String;
    _secretController.text =
        setting.get(SettingBoxKey.aria2Secret, defaultValue: '') as String;
    _timeoutController.text =
        (setting.get(SettingBoxKey.aria2TimeoutSeconds, defaultValue: 15)
                as int)
            .toString();
    _maxConcurrentController.text = (setting.get(
      SettingBoxKey.aria2MaxConcurrentDownloads,
      defaultValue: 2,
    ) as int)
        .toString();
    _downloadDirectory = (setting.get(
      SettingBoxKey.downloadDirectory,
      defaultValue: '',
    ) as String);
  }

  /// 调起系统原生文件夹选择器让用户直接挑选下载目录（无需手动输入文本）
  Future<void> _pickDownloadDirectory() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择默认下载目录',
        initialDirectory:
            _downloadDirectory.isNotEmpty ? _downloadDirectory : null,
      );

      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        final cleanPath = selectedPath.trim();
        await GStorage.setting.put(SettingBoxKey.downloadDirectory, cleanPath);
        if (!mounted) return;
        setState(() {
          _downloadDirectory = cleanPath;
        });
        KazumiDialog.showToast(message: '默认下载目录已更新为:\n$cleanPath');
      }
    } catch (e) {
      _logger.log(Level.warning, '选择下载目录失败: $e');
      if (mounted) {
        KazumiDialog.showToast(message: '选择目录失败: $e');
      }
    }
  }

  /// 恢复系统默认下载目录
  Future<void> _resetDownloadDirectory() async {
    try {
      await GStorage.setting.delete(SettingBoxKey.downloadDirectory);
      if (!mounted) return;
      setState(() {
        _downloadDirectory = '';
      });
      KazumiDialog.showToast(message: '已恢复系统默认下载目录');
    } catch (e) {
      if (mounted) {
        KazumiDialog.showToast(message: '重置目录失败: $e');
      }
    }
  }

  /// 在访达 / 资源管理器中打开当前下载目录
  Future<void> _openFolderInSystem() async {
    final path = _downloadDirectory.trim();
    if (path.isEmpty) return;
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      _logger.log(Level.warning, '打开目录失败: $e');
    }
  }

  /// 高级用户手动输入下载目录对话框
  void _showEditDownloadDirectoryDialog() {
    final controller = TextEditingController(text: _downloadDirectory);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置默认下载目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入下载目录路径',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newDir = controller.text.trim();
              if (newDir.isNotEmpty) {
                await GStorage.setting.put(SettingBoxKey.downloadDirectory, newDir);
                if (!mounted) return;
                setState(() {
                  _downloadDirectory = newDir;
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('下载目录已更新'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final setting = GStorage.setting;

    final endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      KazumiDialog.showToast(message: '端点地址不能为空');
      return;
    }

    try {
      Uri.parse(endpoint);
    } catch (e) {
      KazumiDialog.showToast(message: '端点地址格式不正确');
      return;
    }

    final timeoutSeconds = int.tryParse(_timeoutController.text.trim());
    if (timeoutSeconds == null || timeoutSeconds < 5 || timeoutSeconds > 120) {
      KazumiDialog.showToast(message: '超时时间必须在5-120秒之间');
      return;
    }

    final maxConcurrent = int.tryParse(_maxConcurrentController.text.trim());
    if (maxConcurrent == null || maxConcurrent < 1) {
      KazumiDialog.showToast(message: '最大并发下载数必须大于0');
      return;
    }

    await setting.put(SettingBoxKey.aria2Endpoint, endpoint);
    await setting.put(SettingBoxKey.aria2Secret, _secretController.text.trim());
    await setting.put(SettingBoxKey.aria2TimeoutSeconds, timeoutSeconds);
    await setting.put(
        SettingBoxKey.aria2MaxConcurrentDownloads, maxConcurrent);

    if (mounted) {
      KazumiDialog.showToast(message: '设置已保存');
    }
  }

  Future<void> _testConnection() async {
    ref.read(downloadSettingsProvider.notifier).setTestingConnection(true);
    ref.read(downloadSettingsProvider.notifier).setConnectionStatus('');

    try {
      final endpoint = _endpointController.text.trim();
      if (endpoint.isEmpty) {
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus('连接失败: 端点地址不能为空');
        ref.read(downloadSettingsProvider.notifier).setTestingConnection(false);
        return;
      }

      final Uri endpointUri;
      try {
        endpointUri = Uri.parse(endpoint);
      } catch (e) {
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus('连接失败: 端点地址格式不正确');
        ref.read(downloadSettingsProvider.notifier).setTestingConnection(false);
        return;
      }

      final secret = _secretController.text.trim();
      final timeoutSeconds = int.tryParse(_timeoutController.text.trim()) ?? 15;

      _logger.log(Level.info, '[DownloadSettings] Testing connection to: $endpoint');
      _logger.log(Level.info, '[DownloadSettings] Endpoint URI: ${endpointUri.toString()}');
      _logger.log(Level.info, '[DownloadSettings] Has secret: ${secret.isNotEmpty}');
      _logger.log(Level.info, '[DownloadSettings] Timeout: ${timeoutSeconds}s');

      final client = Aria2Client(
        endpoint: endpointUri,
        secret: secret.isEmpty ? null : secret,
        timeout: Duration(seconds: timeoutSeconds),
      );

      // Test connection using aria2.getVersion - more reliable than tellActive
      final result = await client.testConnection();

      ref.read(downloadSettingsProvider.notifier).setConnectionStatus(result);
      ref.read(downloadSettingsProvider.notifier).setTestingConnection(false);

      _logger.log(Level.info, '[DownloadSettings] Connection test successful: $result');
    } on Aria2RpcException catch (e) {
      _logger.log(Level.error, '[DownloadSettings] Aria2 RPC error: ${e.message}', error: e);
      String errorDetail = e.message;

      // Provide more specific error messages
      if (errorDetail.contains('Connection refused') ||
          errorDetail.contains('无法连接')) {
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus(
          '连接失败: 无法连接到 aria2\n'
          '可能原因:\n'
          '1. aria2 进程未启动（点击下方"重启"按钮）\n'
          '2. 端点地址不正确（当前: ${_endpointController.text}）\n'
          '3. 防火墙阻止了连接'
        );
      } else if (errorDetail.contains('timeout') || errorDetail.contains('超时')) {
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus(
          '连接失败: 连接超时\n'
          '可能原因:\n'
          '1. aria2 进程响应缓慢\n'
          '2. 端点地址不正确\n'
          '3. 网络问题'
        );
      } else if (e.code == 1) {
        // Unauthorized error
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus(
          '连接失败: 认证失败\n'
          '密钥(Secret)不正确，请检查设置'
        );
      } else if (e.code == -32700) {
        // Parse error - usually means wrong endpoint
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus(
          '连接失败: 端点地址错误\n'
          '当前地址: ${_endpointController.text}\n'
          '标准地址应为: http://127.0.0.1:6800/jsonrpc'
        );
      } else {
        ref.read(downloadSettingsProvider.notifier).setConnectionStatus('连接失败: $errorDetail');
      }
      ref.read(downloadSettingsProvider.notifier).setTestingConnection(false);
    } catch (e) {
      _logger.log(Level.error, '[DownloadSettings] Connection test failed: $e');
      ref.read(downloadSettingsProvider.notifier).setConnectionStatus(
        '连接失败: ${e.toString()}\n'
        '请检查:\n'
        '1. aria2 是否正在运行\n'
        '2. 端点地址是否正确\n'
        '3. 密钥是否正确（如果设置了密钥）'
      );
      ref.read(downloadSettingsProvider.notifier).setTestingConnection(false);
    }
  }

  Future<void> _checkForUpdates() async {
    // Mobile platforms not supported
    if (Platform.isIOS || Platform.isAndroid) {
      KazumiDialog.showToast(message: '移动平台使用内置 aria2,无需更新');
      return;
    }

    ref.read(downloadSettingsProvider.notifier).setIsCheckingUpdate(true);
    ref.read(downloadSettingsProvider.notifier).setUpdateInfo(null);

    try {
      final updateInfo = await Aria2Updater().checkForUpdates();
      ref.read(downloadSettingsProvider.notifier).setIsCheckingUpdate(false);
      ref.read(downloadSettingsProvider.notifier).setUpdateInfo(updateInfo);

      if (updateInfo == null) {
        KazumiDialog.showToast(message: '检查更新失败');
      } else if (!updateInfo.hasUpdate) {
        KazumiDialog.showToast(message: '已是最新版本');
      } else {
        _showUpdateDialog(updateInfo);
      }
    } catch (e) {
      ref.read(downloadSettingsProvider.notifier).setIsCheckingUpdate(false);
      KazumiDialog.showToast(message: '检查更新失败: $e');
    }
  }

  void _showUpdateDialog(Aria2UpdateInfo updateInfo) {
    // For Windows, show WinGet update dialog
    if (Platform.isWindows) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本: ${updateInfo.currentVersion}'),
              Text('最新版本: ${updateInfo.latestVersion}'),
              const SizedBox(height: 16),
              Text('更新方式: ${updateInfo.updateMethod}'),
              const SizedBox(height: 8),
              const Text(
                '更新将通过 WinGet 自动进行',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _installUpdate(updateInfo);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      );
    } else {
      // For macOS/Linux, show manual update instructions
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更新 aria2'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本: ${updateInfo.currentVersion}'),
              const SizedBox(height: 16),
              const Text('请使用系统包管理器更新:'),
              const SizedBox(height: 8),
              if (updateInfo.updateCommand != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    updateInfo.updateCommand!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _installUpdate(Aria2UpdateInfo updateInfo) async {
    if (!Platform.isWindows) {
      KazumiDialog.showToast(message: '请使用系统包管理器手动更新');
      return;
    }

    ref.read(downloadSettingsProvider.notifier).setIsDownloadingUpdate(true);

    try {
      // For Windows, use WinGet to update
      final success = await Aria2Updater().updateAria2();

      ref.read(downloadSettingsProvider.notifier).setIsDownloadingUpdate(false);

      if (success) {
        _showRestartDialog();
      } else {
        KazumiDialog.showToast(message: 'WinGet 更新失败,请检查日志');
      }
    } catch (e) {
      ref.read(downloadSettingsProvider.notifier).setIsDownloadingUpdate(false);
      KazumiDialog.showToast(message: '更新失败: $e');
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('更新成功'),
        content: const Text('aria2 已更新，请重启 aria2 服务以使用新版本。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('稍后重启'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartAria2();
            },
            child: const Text('重启 aria2'),
          ),
        ],
      ),
    );
  }

  Future<void> _restartAria2() async {
    if (!Aria2FeatureManager().isAvailable) {
      KazumiDialog.showToast(message: Aria2FeatureManager().getAvailabilityMessage());
      return;
    }

    ref.read(downloadSettingsProvider.notifier).setIsRestartingAria2(true);
    ref.read(downloadSettingsProvider.notifier).setAria2Status('正在重启 aria2...');

    try {
      final success = await Aria2ProcessManager().restart();

      // 等待 aria2 完全启动
      await Future.delayed(const Duration(seconds: 2));

      ref.read(downloadSettingsProvider.notifier).setIsRestartingAria2(false);
      if (success) {
        ref.read(downloadSettingsProvider.notifier).setAria2Status('aria2 重启成功');
      } else {
        ref.read(downloadSettingsProvider.notifier).setAria2Status('aria2 重启失败');
      }

      if (success) {
        KazumiDialog.showToast(message: 'aria2 重启成功，请稍后重试测试连接');
      } else {
        KazumiDialog.showToast(message: 'aria2 重启失败，请检查日志');
      }
    } catch (e) {
      ref.read(downloadSettingsProvider.notifier).setIsRestartingAria2(false);
      ref.read(downloadSettingsProvider.notifier).setAria2Status('aria2 重启失败');
      KazumiDialog.showToast(message: 'aria2 重启失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadSettings = ref.watch(downloadSettingsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final textFieldWidth = (screenWidth < 500)
        ? (screenWidth * 0.35).clamp(80.0, 130.0)
        : 300.0;

    return Scaffold(
      appBar: SysAppBar(
        title: const Text('下载设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存',
          ),
        ],
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('下载目录'),
            tiles: [
              SettingsTile(
                title: const Text('默认下载目录'),
                description: Text(
                  _downloadDirectory.isNotEmpty
                      ? _downloadDirectory
                      : '系统默认下载目录 (Downloads)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: const Icon(Icons.folder_open),
                onPressed: (_) => _pickDownloadDirectory(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.folder_open_outlined, size: 16),
                      label: const Text('选择目录'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: _pickDownloadDirectory,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: '手动输入路径',
                      onPressed: _showEditDownloadDirectoryDialog,
                    ),
                    if (_downloadDirectory.isNotEmpty) ...[
                      if (Platform.isMacOS ||
                          Platform.isWindows ||
                          Platform.isLinux)
                        IconButton(
                          icon: const Icon(Icons.launch_outlined),
                          tooltip: '在文件管理器中打开',
                          onPressed: _openFolderInSystem,
                        ),
                      IconButton(
                        icon: const Icon(Icons.restore_outlined),
                        tooltip: '恢复系统默认',
                        onPressed: _resetDownloadDirectory,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('aria2 设置'),
            tiles: [
              SettingsTile(
                title: const Text('端点地址'),
                description: const Text('aria2 JSON-RPC 端点'),
                leading: const Icon(Icons.link),
                trailing: SizedBox(
                  width: textFieldWidth,
                  child: TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      hintText: 'http://127.0.0.1:6800/jsonrpc',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              SettingsTile(
                title: const Text('密钥 (Secret)'),
                description: const Text('aria2 RPC 密钥，留空表示无密钥'),
                leading: const Icon(Icons.vpn_key),
                trailing: SizedBox(
                  width: textFieldWidth,
                  child: TextField(
                    controller: _secretController,
                    decoration: const InputDecoration(
                      hintText: '可选',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                ),
              ),
              SettingsTile(
                title: const Text('超时时间 (秒)'),
                description: const Text('请求超时时间，范围 5-120 秒'),
                leading: const Icon(Icons.timer),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _timeoutController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              SettingsTile(
                title: const Text('最大并发下载数'),
                description: const Text('同时进行的最大下载任务数'),
                leading: const Icon(Icons.speed),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _maxConcurrentController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              SettingsTile(
                title: const Text('测试连接'),
                description: downloadSettings.connectionStatus.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            downloadSettings.connectionStatus,
                            style: TextStyle(
                              color: downloadSettings.connectionStatus.contains('成功')
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (downloadSettings.connectionStatus.contains('失败')) ...[
                            const SizedBox(height: 4),
                            Text(
                              '提示: 内置 aria2 服务未响应。请点击下方"重启"按钮。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const Text('测试 aria2 连接是否正常'),
                leading: const Icon(Icons.network_check),
                trailing: downloadSettings.isTestingConnection
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: _testConnection,
                        child: const Text('测试'),
                      ),
              ),
            ],
          ),
          if (!Platform.isIOS)
            SettingsSection(
              title: const Text('进程管理'),
              tiles: [
                SettingsTile(
                  title: const Text('aria2 状态'),
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        downloadSettings.aria2Status,
                        style: TextStyle(
                          color: downloadSettings.aria2Status.contains('运行中') || downloadSettings.aria2Status.contains('成功')
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kazumi 内置 aria2 下载引擎\n应用启动时会自动运行',
                        style: TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  leading: const Icon(Icons.info_outline),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (screenWidth < 450)
                        IconButton(
                          onPressed: _checkAria2Status,
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: '检查',
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _checkAria2Status,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('检查'),
                        ),
                      const SizedBox(width: 4),
                      if (screenWidth < 450)
                        IconButton(
                          onPressed: downloadSettings.isRestartingAria2 ? null : _restartAria2,
                          icon: downloadSettings.isRestartingAria2
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt, size: 20),
                          tooltip: '重启',
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: downloadSettings.isRestartingAria2 ? null : _restartAria2,
                          icon: downloadSettings.isRestartingAria2
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt, size: 16),
                          label: const Text('重启'),
                        ),
                    ],
                  ),
                ),
                SettingsTile(
                  title: const Text('自动启动'),
                  description: const Text(
                    'Kazumi 内置 aria2 二进制文件\n'
                    '启动应用时会自动运行 aria2 进程\n'
                    '退出应用时会自动停止 aria2 进程',
                  ),
                  leading: const Icon(Icons.play_circle_outline),
                ),
              ],
            ),
          if (Platform.isWindows)
            SettingsSection(
              title: const Text('aria2 更新'),
              tiles: [
                SettingsTile(
                  title: const Text('检查更新'),
                  description: downloadSettings.updateInfo != null
                      ? Text(downloadSettings.updateInfo!.hasUpdate
                          ? '发现新版本: ${downloadSettings.updateInfo!.latestVersion}'
                          : '当前已是最新版本')
                      : const Text('检查 aria2 是否有新版本可用'),
                  leading: const Icon(Icons.system_update),
                  trailing: downloadSettings.isCheckingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: _checkForUpdates,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('检查更新'),
                        ),
                ),
                if (downloadSettings.isDownloadingUpdate)
                  SettingsTile(
                    title: const Text('正在更新'),
                    description: const Text('通过 WinGet 更新 aria2...'),
                    leading: const Icon(Icons.download),
                    trailing: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                SettingsTile(
                  title: const Text('自动更新说明'),
                  description: const Text(
                    'Windows 版本使用 WinGet 管理 aria2\n'
                    '如果系统未安装 aria2,会自动安装\n'
                    '更新会通过 WinGet 自动进行\n'
                    'WinGet 是 Windows 官方包管理器',
                  ),
                  leading: const Icon(Icons.info_outline),
                ),
              ],
            ),
          if (Platform.isMacOS || Platform.isLinux)
            SettingsSection(
              title: const Text('aria2 更新'),
              tiles: [
                SettingsTile(
                  title: const Text('手动更新'),
                  description: Text(
                    Platform.isMacOS
                        ? '请使用 Homebrew 更新: brew upgrade aria2'
                        : '请使用系统包管理器更新:\nsudo apt update && sudo apt upgrade aria2c',
                  ),
                  leading: const Icon(Icons.info_outline),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
