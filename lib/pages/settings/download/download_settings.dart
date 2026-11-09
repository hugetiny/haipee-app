import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/providers/download_providers.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  ConsumerState<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  final TextEditingController _maxConcurrentController = TextEditingController();
  String _downloadDirectory = '';
  int _parallelEpisodes = 3;
  int _parallelSegments = 3;
  bool _downloadDanmaku = true;

  final HaipeeLogger _logger = HaipeeLogger();

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
      defaultValue: 3,
    );
    _maxConcurrentController.text = (maxConcurrent as int).toString();
    _downloadDirectory = (setting.get(
      SettingBoxKey.downloadDirectory,
      defaultValue: '',
    ) as String);
    _parallelEpisodes =
        GStorage.getSetting(SettingsKeys.downloadParallelEpisodes);
    _parallelSegments =
        GStorage.getSetting(SettingsKeys.downloadParallelSegments);
    _downloadDanmaku = GStorage.getSetting(SettingsKeys.downloadDanmaku);
  }

  /// 调起系统原生文件夹选择器让用户直接挑选下载目录
  Future<void> _pickDownloadDirectory() async {
    if (AppLog.isFirebaseTestLab) {
      AppLog.d(LogModule.download, 'Firebase Test Lab 自动化测试中跳过唤起系统外部文件夹选择器');
      return;
    }
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
        HaipeeDialog.showToast(message: '默认下载目录已更新为:\n$cleanPath');
      }
    } catch (e) {
      _logger.log(Level.warning, '选择下载目录失败: $e');
      if (mounted) {
        HaipeeDialog.showToast(message: '选择目录失败: $e');
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
      HaipeeDialog.showToast(message: '已恢复系统默认下载目录');
    } catch (e) {
      if (mounted) {
        HaipeeDialog.showToast(message: '重置目录失败: $e');
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
        HaipeeDialog.showToast(message: '无法打开目录: $e');
      }
    }
  }

  /// 弹出手动修改路径对话框
  Future<void> _showEditDownloadDirectoryDialog() async {
    final editController = TextEditingController(text: _downloadDirectory);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AdaptiveDialogFrame(
          maxWidth: 500,
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
        HaipeeDialog.showToast(message: '下载目录已更新');
      }
    }
  }

  Future<void> _saveSettings() async {
    final maxConcurrent = int.tryParse(_maxConcurrentController.text.trim());
    if (maxConcurrent == null || maxConcurrent < 1 || maxConcurrent > 16) {
      HaipeeDialog.showToast(message: '最大并发下载数必须在 1-16 之间');
      return;
    }

    final setting = GStorage.setting;
    await setting.put(SettingBoxKey.maxConcurrentDownloads, maxConcurrent);
    HaipeeDialog.showToast(message: '下载设置已保存');
  }

  Future<void> _restartEngine() async {
    ref.read(downloadSettingsProvider.notifier).setEngineStatus('正在重新连接 Gopeed 引擎...');
    try {
      await GopeedService().initialize();
      ref.read(downloadSettingsProvider.notifier).setEngineStatus('Gopeed 2.0 运行中 (内嵌原生内核)');
      HaipeeDialog.showToast(message: 'Gopeed 下载引擎已就绪');
    } catch (e) {
      ref.read(downloadSettingsProvider.notifier).setEngineStatus('Gopeed 初始化失败: $e');
      HaipeeDialog.showToast(message: '引擎初始化异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadSettings = ref.watch(downloadSettingsProvider);

    return SettingsDetailScaffold(
      title: const Text('下载设置'),
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveSettings,
          tooltip: '保存',
        ),
      ],
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
              SettingsTile.switchTile(
                leading: const Icon(Icons.subtitles_rounded),
                onToggle: (value) {
                  setState(() => _downloadDanmaku = value ?? !_downloadDanmaku);
                  GStorage.putSetting(
                      SettingsKeys.downloadDanmaku, _downloadDanmaku);
                },
                title: const Text('缓存弹幕'),
                description: const Text('下载视频时同时缓存弹幕数据'),
                initialValue: _downloadDanmaku,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('任务与并发'),
            tiles: [
              SettingsSliderTile(
                leading: const Icon(Icons.video_library_rounded),
                title: const Text('同时下载集数'),
                description: const Text('并行下载的剧集数量'),
                value: _parallelEpisodes.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                valueLabel: '$_parallelEpisodes 集',
                onChanged: (value) {
                  setState(() => _parallelEpisodes = value.toInt());
                  GStorage.putSetting(
                    SettingsKeys.downloadParallelEpisodes,
                    _parallelEpisodes,
                  );
                },
              ),
              SettingsSliderTile(
                leading: const Icon(Icons.call_split_rounded),
                title: const Text('分片并发数'),
                description: const Text('每集同时下载的分片数量'),
                value: _parallelSegments.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                valueLabel: '$_parallelSegments 个',
                onChanged: (value) {
                  setState(() => _parallelSegments = value.toInt());
                  GStorage.putSetting(
                    SettingsKeys.downloadParallelSegments,
                    _parallelSegments,
                  );
                },
              ),
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
            title: const Text('说明'),
            tiles: [
              SettingsTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('关于并发设置'),
                description: const Text(
                  '• 集数并发：同时下载多少集视频\n'
                  '• 分片并发：每集内同时下载多少个视频片段\n'
                  '• 较高的并发可提升速度，但可能被服务器限制\n'
                  '• 修改后对新开始的下载生效',
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
