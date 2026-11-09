import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/modules/download/download_file_utils.dart';
import 'package:haipee/bean/widget/tree/tree.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/services/logging/log_module.dart';
import 'package:haipee/bean/widget/responsive/responsive.dart';

/// 迅雷风格：三联复选框与目录树选择性下载弹窗
class SelectiveDownloadDialog extends StatefulWidget {
  final String title;
  final List<TorrentFileEntry> files;
  final String? defaultSavePath;
  final bool isExistingTask;
  final Future<void> Function(List<int> selectedIndices, String savePath) onConfirm;

  const SelectiveDownloadDialog({
    super.key,
    required this.title,
    required this.files,
    this.defaultSavePath,
    this.isExistingTask = false,
    required this.onConfirm,
  });

  /// 便捷静态方法打开弹窗
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<TorrentFileEntry> files,
    String? defaultSavePath,
    bool isExistingTask = false,
    required Future<void> Function(List<int> selectedIndices, String savePath) onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SelectiveDownloadDialog(
        title: title,
        files: files,
        defaultSavePath: defaultSavePath,
        isExistingTask: isExistingTask,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<SelectiveDownloadDialog> createState() => _SelectiveDownloadDialogState();
}

class _SelectiveDownloadDialogState extends State<SelectiveDownloadDialog> {
  late TorrentTreeNode _rootNode;
  late TextEditingController _pathController;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rootNode = TorrentTreeNode.buildTree(widget.files, rootName: widget.title);

    String savePath = widget.defaultSavePath ?? '';
    if (savePath.isEmpty) {
      try {
        savePath = (GStorage.setting.get(
          SettingBoxKey.downloadDirectory,
          defaultValue: '',
        ) as String).trim();
      } catch (_) {}
    }
    if (savePath.isEmpty) {
      savePath = DownloadFileUtils.getDefaultDownloadDirectorySync();
    }
    _pathController = TextEditingController(text: savePath);
  }

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 获取当前已勾选文件的 1-based 序号集合
  List<int> get _selectedIndices {
    return widget.files.where((f) => f.isSelected).map((f) => f.index).toList();
  }

  /// 获取当前已勾选文件的总字节数
  int get _selectedBytes {
    return widget.files.where((f) => f.isSelected).fold(0, (sum, f) => sum + f.sizeBytes);
  }

  /// 获取种子全部文件的总字节数
  int get _totalBytes {
    return widget.files.fold(0, (sum, f) => sum + f.sizeBytes);
  }

  /// 一键全选
  void _selectAll() {
    setState(() {
      _rootNode.setSelected(true);
    });
  }

  /// 一键全不选
  void _deselectAll() {
    setState(() {
      _rootNode.setSelected(false);
    });
  }

  /// 一键反选
  void _invertSelection() {
    setState(() {
      for (final f in widget.files) {
        f.isSelected = !f.isSelected;
      }
    });
  }

  /// 仅选择视频文件
  void _selectVideosOnly() {
    setState(() {
      for (final f in widget.files) {
        f.isSelected = f.isVideo;
      }
    });
  }

  /// 仅选择音频文件
  void _selectAudiosOnly() {
    setState(() {
      for (final f in widget.files) {
        f.isSelected = f.isAudio;
      }
    });
  }

  /// 选择保存目录
  Future<void> _pickDirectory() async {
    if (AppLog.isFirebaseTestLab) {
      AppLog.d(LogModule.download, 'Firebase Test Lab 自动化测试中跳过唤起系统外部文件选择器');
      return;
    }
    try {
      final res = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载保存目录',
        initialDirectory: _pathController.text.isNotEmpty ? _pathController.text : null,
      );
      if (res != null && res.isNotEmpty) {
        setState(() {
          _pathController.text = res;
        });
      }
    } catch (e, stack) {
      AppLog.w(LogModule.download, '选择保存目录失败: $e', error: e, stackTrace: stack);
    }
  }

  /// 扁平化展开的可见节点（支持虚拟列表滚动）
  List<_FlatNode> _getVisibleNodes(TorrentTreeNode node, int depth) {
    final list = <_FlatNode>[];
    if (_searchKeyword.isNotEmpty) {
      // 搜索模式：直接展示匹配的文件
      for (final f in widget.files) {
        if (f.name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            f.path.toLowerCase().contains(_searchKeyword.toLowerCase())) {
          list.add(_FlatNode(
            node: TorrentTreeNode(
              name: f.name,
              fullPath: f.path,
              isDirectory: false,
              file: f,
            ),
            depth: 0,
          ));
        }
      }
      return list;
    }

    for (final child in node.children) {
      list.add(_FlatNode(node: child, depth: depth));
      if (child.isDirectory && child.isExpanded) {
        list.addAll(_getVisibleNodes(child, depth + 1));
      }
    }
    return list;
  }

  Future<void> _handleConfirm() async {
    final indices = _selectedIndices;
    if (indices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少勾选一个文件进行下载'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final savePath = _pathController.text.trim();
      await widget.onConfirm(indices, savePath);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleNodes = _getVisibleNodes(_rootNode, 0);

    final selectedCount = _selectedIndices.length;
    final totalCount = widget.files.length;
    final selectedBytes = _selectedBytes;
    final totalBytes = _totalBytes;
    final progress = totalBytes > 0 ? (selectedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

    return AdaptiveDialogFrame(
      maxWidth: 780,
      maxHeight: 680,
      expand: true,
      child: Column(
        children: [
          // 1. 顶栏：标题与关闭按钮
          _buildHeader(theme, colorScheme),

          // 2. 保存路径选择区域
          _buildSavePathSection(theme, colorScheme),

          // 3. 迅雷式快速筛选工具栏（全选、反选、仅视频、仅音频）
          _buildQuickToolbar(theme, colorScheme),

          const Divider(height: 1),

          // 4. 三联复选框文件树内容区
          Expanded(
            child: visibleNodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 8),
                        Text(
                          _searchKeyword.isNotEmpty ? '未找到匹配的文件' : '种子中无文件',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleNodes.length,
                    itemBuilder: (context, index) {
                      final flatNode = visibleNodes[index];
                      return _buildNodeRow(flatNode, theme, colorScheme);
                    },
                  ),
          ),

          const Divider(height: 1),

          // 5. 底栏：统计数据、容量占用进度条与确认按钮
          _buildFooter(theme, colorScheme, selectedCount, totalCount, selectedBytes, totalBytes, progress),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isMobile
            ? Colors.transparent
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: isMobile
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.account_tree_outlined, color: colorScheme.primary, size: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  widget.isExistingTask ? '选择下载文件（三联文件树）' : '新建下载 - 选择下载文件',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSavePathSection(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 360;
          return Row(
            spacing: 8,
            children: [
              Icon(Icons.folder_outlined, size: 20, color: colorScheme.onSurfaceVariant),
              if (!isVeryNarrow)
                Text(
                  '保存目录:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    _pathController.text.isNotEmpty ? _pathController.text : '默认下载目录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              isVeryNarrow
                  ? OutlinedButton(
                      onPressed: _pickDirectory,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('更改'),
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickDirectory,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('更改'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickToolbar(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 580;
          final chips = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('全选'),
                avatar: const Icon(Icons.select_all, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _selectAll,
              ),
              ActionChip(
                label: const Text('全不选'),
                avatar: const Icon(Icons.deselect, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _deselectAll,
              ),
              ActionChip(
                label: const Text('反选'),
                avatar: const Icon(Icons.swap_horiz, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _invertSelection,
              ),
              ActionChip(
                label: const Text('仅视频'),
                avatar: const Icon(Icons.movie_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _selectVideosOnly,
              ),
              ActionChip(
                label: const Text('仅音频'),
                avatar: const Icon(Icons.music_note_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _selectAudiosOnly,
              ),
            ],
          );

          final searchInput = SizedBox(
            width: isNarrow ? double.infinity : 180,
            height: 34,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索文件名...',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchKeyword = '';
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              style: theme.textTheme.bodySmall,
              onChanged: (val) {
                setState(() {
                  _searchKeyword = val.trim();
                });
              },
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                chips,
                searchInput,
              ],
            );
          }

          return Row(
            spacing: 12,
            children: [
              Expanded(child: chips),
              searchInput,
            ],
          );
        },
      ),
    );
  }

  Widget _buildNodeRow(_FlatNode flat, ThemeData theme, ColorScheme colorScheme) {
    final node = flat.node;
    final isDir = node.isDirectory;
    final depth = flat.depth;

    return TreeTile(
      depth: depth,
      onTap: () {
        if (isDir) {
          setState(() {
            node.isExpanded = !node.isExpanded;
          });
        } else {
          setState(() {
            node.file?.isSelected = !(node.file?.isSelected ?? false);
          });
        }
      },
      expandIcon: isDir
          ? IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              icon: Icon(
                node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  node.isExpanded = !node.isExpanded;
                });
              },
            )
          : null,
      checkbox: Checkbox(
        tristate: isDir,
        value: isDir ? node.triStateValue : (node.file?.isSelected ?? false),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (bool? val) {
          setState(() {
            if (isDir) {
              final current = node.triStateValue;
              if (current == true) {
                node.setSelected(false);
              } else {
                node.setSelected(true);
              }
            } else {
              node.file?.isSelected = val ?? false;
            }
          });
        },
      ),
      icon: _buildNodeIcon(node, colorScheme),
      title: Text(
        node.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isDir ? FontWeight.w600 : FontWeight.normal,
          color: (isDir ? (node.triStateValue != false) : (node.file?.isSelected ?? false))
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      trailing: isDir
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${node.selectedFilesCount}/${node.totalFilesCount} 项 · ${TorrentFileEntry.formatBytes(node.totalSizeBytes)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              node.file?.formattedSize ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: (node.file?.isSelected ?? false)
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  Widget _buildNodeIcon(TorrentTreeNode node, ColorScheme colorScheme) {
    if (node.isDirectory) {
      return Icon(
        node.isExpanded ? Icons.folder_open : Icons.folder,
        color: Colors.amber.shade700,
        size: 20,
      );
    }

    final file = node.file;
    if (file == null) {
      return Icon(Icons.insert_drive_file, color: colorScheme.outline, size: 18);
    }

    if (file.isVideo) {
      return const Icon(Icons.movie, color: Colors.blueAccent, size: 18);
    } else if (file.isAudio) {
      return const Icon(Icons.music_note, color: Colors.purpleAccent, size: 18);
    } else if (file.isImage) {
      return const Icon(Icons.image, color: Colors.teal, size: 18);
    } else if (file.isSubtitle) {
      return const Icon(Icons.subtitles, color: Colors.indigoAccent, size: 18);
    } else if (file.isArchive) {
      return const Icon(Icons.archive, color: Colors.deepOrange, size: 18);
    } else if (file.isDocument) {
      return const Icon(Icons.description, color: Colors.blueGrey, size: 18);
    }

    return Icon(Icons.insert_drive_file, color: colorScheme.outline, size: 18);
  }

  Widget _buildFooter(
    ThemeData theme,
    ColorScheme colorScheme,
    int selectedCount,
    int totalCount,
    int selectedBytes,
    int totalBytes,
    double progress,
  ) {
    final selectedStr = TorrentFileEntry.formatBytes(selectedBytes);
    final totalStr = TorrentFileEntry.formatBytes(totalBytes);
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: isMobile
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          final infoSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '已选择 $selectedCount / 全部 $totalCount 个文件',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '($selectedStr / $totalStr)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ],
          );

          final actionsSection = Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: (_isSubmitting || selectedCount == 0)
                    ? null
                    : _handleConfirm,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        widget.isExistingTask
                            ? Icons.check
                            : Icons.download,
                        size: 18),
                label: Text(
                  _isSubmitting
                      ? '提交中...'
                      : (widget.isExistingTask
                          ? '应用选择 ($selectedCount)'
                          : '立即下载 ($selectedCount)'),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                infoSection,
                actionsSection,
              ],
            );
          }

          return Row(
            spacing: 16,
            children: [
              Expanded(child: infoSection),
              actionsSection,
            ],
          );
        },
      ),
    );
  }
}

class _FlatNode {
  final TorrentTreeNode node;
  final int depth;

  _FlatNode({required this.node, required this.depth});
}
