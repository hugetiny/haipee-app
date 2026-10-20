import 'dart:math' as math;

/// 种子文件项模型（用于选择性下载与文件树展示）
class TorrentFileEntry {
  /// 1-based 文件序号（与 Aria2 select-file 及 BitTorrent 标准对齐）
  final int index;

  /// 文件在种子内的完整相对路径，如 "Folder/Sub/file.mkv"
  final String path;

  /// 纯文件名，如 "file.mkv"
  final String name;

  /// 文件大小（字节）
  final int sizeBytes;

  /// 路径分段，如 ["Folder", "Sub", "file.mkv"]
  final List<String> pathSegments;

  /// 是否已被用户勾选下载
  bool isSelected;

  TorrentFileEntry({
    required this.index,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.pathSegments,
    this.isSelected = true,
  });

  /// 文件扩展名（小写，不带点）
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return '';
  }

  static const Set<String> _videoExts = {
    'mkv', 'mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'ts', 'm2ts', 'm4v', 'rmvb', 'iso'
  };

  static const Set<String> _audioExts = {
    'flac', 'mp3', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'ape', 'alac', 'dsd', 'cue'
  };

  static const Set<String> _imageExts = {
    'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'svg'
  };

  static const Set<String> _subtitleExts = {
    'ass', 'srt', 'ssa', 'vtt', 'sub', 'idx'
  };

  static const Set<String> _archiveExts = {
    'zip', 'rar', '7z', 'tar', 'gz', 'xz', 'bz2', 'tgz', 'tbz2'
  };

  static const Set<String> _docExts = {
    'pdf', 'txt', 'epub', 'mobi', 'azw3', 'md', 'doc', 'docx'
  };

  bool get isVideo => _videoExts.contains(extension);
  bool get isAudio => _audioExts.contains(extension);
  bool get isImage => _imageExts.contains(extension);
  bool get isSubtitle => _subtitleExts.contains(extension);
  bool get isArchive => _archiveExts.contains(extension);
  bool get isDocument => _docExts.contains(extension);

  /// 友好格式化文件大小
  String get formattedSize => formatBytes(sizeBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor().clamp(0, suffixes.length - 1);
    final size = bytes / math.pow(1024, i);
    if (i == 0) return '${bytes.toInt()} B';
    return '${size.toStringAsFixed(size >= 100 ? 0 : (size >= 10 ? 1 : 2))} ${suffixes[i]}';
  }

  TorrentFileEntry copyWith({
    int? index,
    String? path,
    String? name,
    int? sizeBytes,
    List<String>? pathSegments,
    bool? isSelected,
  }) {
    return TorrentFileEntry(
      index: index ?? this.index,
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pathSegments: pathSegments ?? this.pathSegments,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// 种子文件树节点（支持目录折叠与三联复选框）
class TorrentTreeNode {
  final String name;
  final String fullPath;
  final bool isDirectory;
  final TorrentFileEntry? file;
  final List<TorrentTreeNode> children;
  TorrentTreeNode? parent;
  bool isExpanded;

  TorrentTreeNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    this.file,
    List<TorrentTreeNode>? children,
    this.parent,
    this.isExpanded = true,
  }) : children = children ?? [];

  /// 节点（含所有子代）总文件大小
  int get totalSizeBytes {
    if (!isDirectory) return file?.sizeBytes ?? 0;
    return children.fold(0, (sum, child) => sum + child.totalSizeBytes);
  }

  /// 节点（含所有子代）已选中的文件大小
  int get selectedSizeBytes {
    if (!isDirectory) return (file?.isSelected ?? false) ? (file?.sizeBytes ?? 0) : 0;
    return children.fold(0, (sum, child) => sum + child.selectedSizeBytes);
  }

  /// 总文件数量
  int get totalFilesCount {
    if (!isDirectory) return 1;
    return children.fold(0, (sum, child) => sum + child.totalFilesCount);
  }

  /// 已勾选文件数量
  int get selectedFilesCount {
    if (!isDirectory) return (file?.isSelected ?? false) ? 1 : 0;
    return children.fold(0, (sum, child) => sum + child.selectedFilesCount);
  }

  /// 三态复选框值 (Tri-state):
  /// - true: 全选
  /// - false: 全不选
  /// - null: 半选 (Indeterminate)
  bool? get triStateValue {
    if (!isDirectory) {
      return file?.isSelected ?? false;
    }
    if (children.isEmpty) return false;

    int trueCount = 0;
    int falseCount = 0;
    int nullCount = 0;

    for (final child in children) {
      final state = child.triStateValue;
      if (state == true) {
        trueCount++;
      } else if (state == false) {
        falseCount++;
      } else {
        nullCount++;
      }
    }

    if (nullCount > 0) return null;
    if (trueCount > 0 && falseCount > 0) return null;
    if (trueCount > 0) return true;
    return false;
  }

  /// 递归设置选中状态
  void setSelected(bool selected) {
    if (!isDirectory) {
      file?.isSelected = selected;
    } else {
      for (final child in children) {
        child.setSelected(selected);
      }
    }
  }

  /// 将扁平的 TorrentFileEntry 列表构建为层级文件树
  static TorrentTreeNode buildTree(List<TorrentFileEntry> entries, {String rootName = '全部文件'}) {
    final root = TorrentTreeNode(
      name: rootName,
      fullPath: '',
      isDirectory: true,
      isExpanded: true,
    );

    for (final entry in entries) {
      TorrentTreeNode current = root;
      final segments = entry.pathSegments;

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final isLast = i == segments.length - 1;
        final currentPath = segments.sublist(0, i + 1).join('/');

        if (isLast) {
          // 叶子节点（文件）
          final fileNode = TorrentTreeNode(
            name: segment,
            fullPath: currentPath,
            isDirectory: false,
            file: entry,
            parent: current,
          );
          current.children.add(fileNode);
        } else {
          // 目录节点
          var dirNode = current.children.firstWhere(
            (c) => c.isDirectory && c.name == segment,
            orElse: () {
              final newDir = TorrentTreeNode(
                name: segment,
                fullPath: currentPath,
                isDirectory: true,
                parent: current,
                isExpanded: true,
              );
              current.children.add(newDir);
              return newDir;
            },
          );
          current = dirNode;
        }
      }
    }

    _sortTree(root);
    return root;
  }

  /// 排序：目录排在前面，同类按名称字典序排序
  static void _sortTree(TorrentTreeNode node) {
    if (!node.isDirectory) return;
    node.children.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    for (final child in node.children) {
      if (child.isDirectory) {
        _sortTree(child);
      }
    }
  }
}
