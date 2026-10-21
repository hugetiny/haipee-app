import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:kazumi/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/download/gopeed/gopeed_service.dart';
import 'package:kazumi/providers/download_providers.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  ConsumerState<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  final TextEditingController _maxConcurrentController = TextEditingController();
  String _downloadDirectory = '';

  final KazumiLogger _logger = KazumiLogger();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    Future.microtask(() {
      if (mounted) _checkEngineStatus();
    });
  }

  void _checkEngineStatus() {
    final isInitialized = GopeedService().isInitialized;
    ref.read(downloadSettingsProvider.notifier).setEngineStatus(
      isInitialized ? 'Gopeed 2.0 运行中 (内嵌原生内核)' : 'Gopeed 2.0 就绪中',
    );
  }

  @override
  void dispose() {
    _maxConcurrentController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final setting = GStorage.setting;
    final maxConcurrent = setting.get(
      SettingBoxKey.maxConcurrentDownloads,
      defaultValue: setting.get(
        SettingBoxKey.aria2MaxConcurrentDownloads,
        defaultValue: 3,
      ),
    );
    _maxConcurrentController.text = (maxConcurrent as int).toString();
    _downloadDirectory = (setting.get(
      SettingBoxKey.downloadDirectory,
      defaultValue: '',
    ) as String);
  }

  /// 调起系统原生文件夹选择器让用户直接挑选下载目录
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
      _logger.log(Level.warning, '无法打开目录: $e');
      if (mounted) {
        KazumiDialog.showToast(message: '无法打开目录: $e');
      }
    }
  }

  /// 弹出手动修改路径对话框
  Future<void> _showEditDownloadDirectoryDialog() async {
    final editController = TextEditingController(text: _downloadDirectory);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('设置默认下载目录'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: '输入自定义路径 (留空恢复系统默认)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(editController.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      if (result.isEmpty) {
        await _resetDownloadDirectory();
      } else {
        await GStorage.setting.put(SettingBoxKey.downloadDirectory, result);
        if (!mounted) return;
        setState(() {
          _downloadDirectory = result;
        });
        KazumiDialog.showToast(message: '下载目录已更新');
      }
    }
  }

  Future<void> _saveSettings() async {
    final maxConcurrent = int.tryParse(_maxConcurrentController.text.trim());
    if (maxConcurrent == null || maxConcurrent < 1 || maxConcurrent > 16) {
      KazumiDialog.showToast(message: '最大并发下载数必须在 1-16 之间');
      return;
    }

    final setting = GStorage.setting;
    await setting.put(SettingBoxKey.maxConcurrentDownloads, maxConcurrent);
    await setting.put(SettingBoxKey.aria2MaxConcurrentDownloads, maxConcurrent);
    KazumiDialog.showToast(message: '下载设置已保存');
  }

  Future<void> _restartEngine() async {
    ref.read(downloadSettingsProvider.notifier).setEngineStatus('正在重新连接 Gopeed 引擎...');
    try {
      await GopeedService().initialize();
      ref.read(downloadSettingsProvider.notifier).setEngineStatus('Gopeed 2.0 运行中 (内嵌原生内核)');
      KazumiDialog.showToast(message: 'Gopeed 下载引擎已就绪');
    } catch (e) {
      ref.read(downloadSettingsProvider.notifier).setEngineStatus('Gopeed 初始化失败: $e');
      KazumiDialog.showToast(message: '引擎初始化异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadSettings = ref.watch(downloadSettingsProvider);

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
            title: const Text('任务与并发'),
            tiles: [
              SettingsTile(
                title: const Text('最大并发下载数'),
                description: const Text('同时进行的最大并发下载任务数 (1-16)'),
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
            ],
          ),
          SettingsSection(
            title: const Text('下载核心引擎'),
            tiles: [
              SettingsTile(
                title: const Text('内核状态'),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      downloadSettings.engineStatus,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '基于 Gopeed 2.0 原生跨平台引擎，采用在进程内直接绑定 FFI 调用，轻量低耗且无需守护进程或外部网络端口。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                leading: const Icon(Icons.bolt),
                trailing: ElevatedButton.icon(
                  onPressed: _restartEngine,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('检查引擎'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
