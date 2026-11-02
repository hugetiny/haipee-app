import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:haipee/pages/download/providers.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/modules/download/download_file_utils.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

// 只在非 Windows 平台导入 super_drag_and_drop
// Windows 平台存在本地库加载问题
bool get _supportsDragAndDrop => !kIsWeb && !Platform.isWindows;

/// 新建下载对话框
/// 支持：URL 输入、种子文件选择、种子文件拖拽、磁力链接
class AddDownloadDialog extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String? initialFileName;

  const AddDownloadDialog({
    super.key,
    this.initialUrl,
    this.initialFileName,
  });

  @override
  ConsumerState<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends ConsumerState<AddDownloadDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _cookieController = TextEditingController();
  final TextEditingController _refererController = TextEditingController();
  final TextEditingController _userAgentController = TextEditingController();
  final TextEditingController _headersController = TextEditingController();
  final TextEditingController _savePathController = TextEditingController();
  final HaipeeLogger _logger = HaipeeLogger();

  // 使用ValueNotifier替代setState
  final ValueNotifier<File?> _torrentFileNotifier = ValueNotifier<File?>(null);
  final ValueNotifier<bool> _showAdvancedOptionsNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _connectionsNotifier = ValueNotifier<int>(16); // 单文件最大连接数
  final ValueNotifier<int> _splitNotifier = ValueNotifier<int>(5); // 单任务连接数

  int get _connections => _connectionsNotifier.value;
  int get _split => _splitNotifier.value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
    }
    if (widget.initialFileName != null && widget.initialFileName!.isNotEmpty) {
      _fileNameController.text = widget.initialFileName!;
    }

    String defaultSavePath = '';
    try {
      defaultSavePath = (GStorage.setting.get(
        SettingBoxKey.downloadDirectory,
        defaultValue: '',
      ) as String).trim();
    } catch (_) {}
    if (defaultSavePath.isEmpty) {
      defaultSavePath = DownloadFileUtils.getDefaultDownloadDirectorySync();
    }
    _savePathController.text = defaultSavePath;

    _urlController.addListener(_onUrlChanged);
    if (_urlController.text.isNotEmpty) {
      _onUrlChanged();
    }
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    if (_fileNameController.text.isEmpty && text.isNotEmpty) {
      _tryAutoDetectFilename(text);
    }
    if (text.contains('gofile.io')) {
      if (_refererController.text.isEmpty) {
        _refererController.text = 'https://gofile.io/';
      }
    }
    if (mounted) setState(() {});
  }

  void _tryAutoDetectFilename(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.length == 1) {
      try {
        final uri = Uri.parse(lines.first);
        final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) {
          final last = Uri.decodeComponent(segs.last);
          if (last.contains('.') && !last.startsWith('?')) {
            _fileNameController.text = last;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        final text = data.text!.trim();
        if (_urlController.text.isEmpty) {
          _urlController.text = text;
        } else {
          _urlController.text = '${_urlController.text}\n$text';
        }
        _tryAutoDetectFilename(text);
      }
    } catch (e) {
      _logger.log(Level.warning, '[AddDownloadDialog] Clipboard error: $e');
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _tabController.dispose();
    _urlController.dispose();
    _fileNameController.dispose();
    _cookieController.dispose();
    _refererController.dispose();
    _userAgentController.dispose();
    _headersController.dispose();
    _savePathController.dispose();
    // 释放ValueNotifier资源
    _torrentFileNotifier.dispose();
    _showAdvancedOptionsNotifier.dispose();
    _connectionsNotifier.dispose();
    _splitNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),
            // 标签页
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'URL 下载'),
                Tab(text: '种子下载'),
              ],
            ),
            // 内容区域
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUrlTab(),
                  _buildTorrentTab(),
                ],
              ),
            ),
            // 底部按钮
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Text(
            '新建下载任务',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '支持 HTTP/HTTPS/FTP/磁力链接',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('粘贴剪贴板'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // URL 输入框
          TextField(
            controller: _urlController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  '输入下载链接，每行一个\n支持：\n- HTTP/HTTPS 链接\n- FTP 链接\n- 磁力链接（magnet:?xt=...）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          if (_urlController.text.contains('gofile.io')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF0A84FF), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '检测到 gofile.io 链接：已自动填充 Referer。若下载返回几 KB 的重定向页面导致鉴权失败，请在下方“高级选项”中填入 Cookie 或使用包含下载 Token 的直接链接。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 自定义文件名（单任务时可用）
          TextField(
            controller: _fileNameController,
            decoration: const InputDecoration(
              labelText: '保存文件名（可选）',
              hintText: '例如: my_archive.rar（留空自动解析）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.drive_file_rename_outline),
              helperText: '仅在添加单个链接时生效，留空则自动从 URL 或服务器头获取',
            ),
          ),
          const SizedBox(height: 16),
          // 高级选项
          _buildAdvancedOptions(),
        ],
      ),
    );
  }

  Widget _buildTorrentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽区域或提示文本
          if (_supportsDragAndDrop)
            _buildDropZonePlaceholder() // 暂不实现拖拽
          else
            _buildDropZonePlaceholder(),
          const SizedBox(height: 16),
          // 选择文件按钮
          Center(
            child: FilledButton.icon(
              onPressed: _pickTorrentFile,
              icon: const Icon(Icons.file_open),
              label: const Text('选择种子文件'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 已选择的文件
          ValueListenableBuilder<File?>(
            valueListenable: _torrentFileNotifier,
            builder: (context, torrentFile, child) {
              return torrentFile != null ? _buildSelectedTorrent() : const SizedBox();
            },
          ),
          const SizedBox(height: 16),
          // 高级选项
          _buildAdvancedOptions(),
        ],
      ),
    );
  }

  Widget _buildDropZonePlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            Platform.isWindows ? '点击下方按钮选择种子文件' : '拖入种子文件到此处',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 .torrent 文件',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // 移除原来的 _buildDropZone 方法，因为它使用了 DropRegion

  Widget _buildSelectedTorrent() {
    return Card(
      child: ValueListenableBuilder<File?>(
        valueListenable: _torrentFileNotifier,
        builder: (context, torrentFile, child) {
          if (torrentFile == null) return const SizedBox();
          return ListTile(
            leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
            title: Text(torrentFile.path.split(Platform.pathSeparator).last),
            subtitle: Text(torrentFile.path),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _torrentFileNotifier.value = null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 展开/收起按钮
        InkWell(
          onTap: () =>
              _showAdvancedOptionsNotifier.value = !_showAdvancedOptionsNotifier.value,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showAdvancedOptionsNotifier,
            builder: (context, showAdvancedOptions, child) {
              return Row(
                children: [
                  Icon(
                    showAdvancedOptions
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '高级选项',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              );
            },
          ),
        ),
        // 高级选项内容
        ValueListenableBuilder<bool>(
          valueListenable: _showAdvancedOptionsNotifier,
          builder: (context, showAdvancedOptions, child) {
            if (!showAdvancedOptions) return const SizedBox();
            return Column(
              children: [
                const SizedBox(height: 16),
                // 保存路径
                TextField(
                  controller: _savePathController,
                  decoration: InputDecoration(
                    labelText: '保存路径（可选）',
                    hintText: '留空使用默认下载路径',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.folder),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickSavePath,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Cookie
                TextField(
                  controller: _cookieController,
                  decoration: const InputDecoration(
                    labelText: 'Cookie（网盘鉴权/登录凭证，可选）',
                    hintText: '例如: accountToken=... 或 cf_clearance=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cookie_outlined),
                    helperText: '适用于需要登录或鉴权的网盘直链（如 gofile.io、123云盘等）',
                  ),
                ),
                const SizedBox(height: 14),
                // Referer
                TextField(
                  controller: _refererController,
                  decoration: const InputDecoration(
                    labelText: 'Referer（防盗链来源，可选）',
                    hintText: '例如: https://gofile.io/',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link_outlined),
                    helperText: '部分网盘直链需要校验来源页面',
                  ),
                ),
                const SizedBox(height: 14),
                // User-Agent
                TextField(
                  controller: _userAgentController,
                  decoration: const InputDecoration(
                    labelText: 'User-Agent（浏览器标识，可选）',
                    hintText: '留空默认使用内置 Chrome 标识',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.devices_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                // 其他自定义请求头
                TextField(
                  controller: _headersController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '其他自定义请求头（可选）',
                    hintText: '每行一个，例如:\nAuthorization: Bearer xxx',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.http),
                    helperText: '可自定义其他任意 HTTP Header',
                  ),
                ),
                const SizedBox(height: 16),
                // 连接数设置
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _connectionsNotifier,
                            builder: (context, connections, child) {
                              return Text(
                                '单文件连接数: $connections',
                                style: Theme.of(context).textTheme.bodyMedium,
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _connectionsNotifier,
                            builder: (context, connections, child) {
                              return Slider(
                                value: connections.toDouble(),
                                min: 1,
                                max: 16,
                                divisions: 15,
                                label: connections.toString(),
                                onChanged: (value) =>
                                    _connectionsNotifier.value = value.toInt(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _splitNotifier,
                            builder: (context, split, child) {
                              return Text(
                                '单任务分段数: $split',
                                style: Theme.of(context).textTheme.bodyMedium,
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _splitNotifier,
                            builder: (context, split, child) {
                              return Slider(
                                value: split.toDouble(),
                                min: 1,
                                max: 16,
                                divisions: 15,
                                label: split.toString(),
                                onChanged: (value) => _splitNotifier.value = value.toInt(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const Key('add_download_submit_btn'),
            onPressed: _handleSubmit,
            icon: const Icon(Icons.download),
            label: const Text('开始下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTorrentFile() async {
    if (AppLog.isFirebaseTestLab) {
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
        dialogTitle: '选择种子文件',
      );

      if (result != null && result.files.single.path != null) {
        _torrentFileNotifier.value = File(result.files.single.path!);
        _logger.log(Level.info,
            '[AddDownload] Selected torrent: ${_torrentFileNotifier.value!.path}');
      }
    } catch (e) {
      _logger.log(Level.error, '[AddDownload] Failed to pick torrent file: $e');
      _showError('选择文件失败: $e');
    }
  }

  Future<void> _pickSavePath() async {
    if (AppLog.isFirebaseTestLab) {
      return;
    }
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存路径',
      );

      if (result != null) {
        _savePathController.text = result;
      }
    } catch (e) {
      _logger.log(Level.error, '[AddDownload] Failed to pick save path: $e');
      _showError('选择路径失败: $e');
    }
  }

  Future<void> _handleSubmit() async {
    try {
      if (_tabController.index == 0) {
        // URL 下载
        await _submitUrlDownload();
      } else {
        // 种子下载
        await _submitTorrentDownload();
      }
    } catch (e) {
      _logger.log(Level.error, '[AddDownload] Submit failed: $e');
      _showError('添加下载失败: $e');
    }
  }

  Future<void> _submitUrlDownload() async {
    final urls = _urlController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (urls.isEmpty) {
      _showError('请输入至少一个下载链接');
      return;
    }

    // 构建下载选项
    final options = <String, dynamic>{};
    if (_savePathController.text.isNotEmpty) {
      options['dir'] = _savePathController.text;
    }
    final customName = _fileNameController.text.trim();
    if (customName.isNotEmpty && urls.length == 1) {
      options['out'] = customName;
    }

    final headersList = <String>[];
    final cookie = _cookieController.text.trim();
    if (cookie.isNotEmpty) {
      headersList.add('Cookie: $cookie');
    }
    final referer = _refererController.text.trim();
    if (referer.isNotEmpty) {
      headersList.add('Referer: $referer');
    }
    final ua = _userAgentController.text.trim();
    if (ua.isNotEmpty) {
      options['user-agent'] = ua;
      headersList.add('User-Agent: $ua');
    }
    if (_headersController.text.trim().isNotEmpty) {
      final headers = _headersController.text
          .split('\n')
          .map((h) => h.trim())
          .where((h) => h.isNotEmpty && h.contains(':'))
          .toList();
      headersList.addAll(headers);
    }
    if (headersList.isNotEmpty) {
      options['header'] = headersList;
    }

    options['max-connection-per-server'] = _connectionsNotifier.value;
    options['split'] = _splitNotifier.value;

    // 添加到下载服务
    final controller = ref.read(downloadControllerProvider.notifier);
    await controller.addUris(urls, options: options);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 ${urls.length} 个下载任务'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitTorrentDownload() async {
    if (_torrentFileNotifier.value == null) {
      _showError('请选择或拖入种子文件');
      return;
    }

    // 构建下载选项
    final options = <String, dynamic>{};
    if (_savePathController.text.isNotEmpty) {
      options['dir'] = _savePathController.text;
    }
    options['max-connection-per-server'] = _connections;
    options['split'] = _split;

    // 添加到下载服务
    final controller = ref.read(downloadControllerProvider.notifier);
    await controller.addTorrent(_torrentFileNotifier.value!, options: options);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已添加种子下载任务'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
