import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:haipee/modules/download/gopeed/gopeed_models.dart';

part 'download_task.g.dart';

@HiveType(typeId: 20)
class DownloadTask extends HiveObject {
  @HiveField(0)
  String gid;

  @HiveField(1)
  String url;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? fileName;

  @HiveField(4)
  int totalLength;

  @HiveField(5)
  int completedLength;

  @HiveField(6)
  int downloadSpeed;

  @HiveField(7)
  String status; // active, waiting, paused, error, complete, removed

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  @HiveField(10)
  String? errorMessage;

  @HiveField(11)
  int? errorCode;

  @HiveField(12)
  String? bangumiId;

  @HiveField(13)
  int? episodeNumber;

  /// In-memory runtime upload speed (bytes/sec)
  int uploadSpeed;

  DownloadTask({
    required this.gid,
    required this.url,
    required this.title,
    this.fileName,
    this.totalLength = 0,
    this.completedLength = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.errorCode,
    this.bangumiId,
    this.episodeNumber,
  });

  double get progress {
    if (totalLength <= 0) return 0.0;
    final val = completedLength / totalLength;
    if (val < 0.0) return 0.0;
    if (val > 1.0) return 1.0;
    return val;
  }

  bool get isActive => status == 'active';
  bool get isWaiting => status == 'waiting';
  bool get isPaused => status == 'paused';
  bool get isError => status == 'error';
  bool get isComplete => status == 'complete';
  bool get isRemoved => status == 'removed';
  bool get isDownloading => isActive || isWaiting;

  /// Whether this task failed due to an HTML redirect or authentication error
  bool get isRedirectOrAuthError =>
      errorMessage?.contains('重定向网页') == true ||
      errorMessage?.contains('鉴权失败') == true;

  static const Set<String> _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.flv', '.mov', '.wmv', '.webm', '.ts',
    '.m4v', '.3gp', '.rmvb', '.vob', '.f4v', '.asf', '.mpg', '.mpeg',
    '.m2ts', '.mts'
  };

  static const Set<String> _audioExtensions = {
    '.mp3', '.flac', '.wav', '.ape', '.dsd', '.dsf', '.dff', '.alac',
    '.ogg', '.m4a', '.aac', '.opus', '.wma', '.mid', '.midi'
  };

  static const Set<String> _archiveExtensions = {
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.iso', '.cab',
    '.z', '.tgz', '.tbz2', '.txz', '.7-zip'
  };

  static const Set<String> _documentExtensions = {
    '.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.txt',
    '.epub', '.mobi', '.azw3', '.md', '.rtf', '.csv'
  };

  static const Set<String> _installerExtensions = {
    '.dmg', '.pkg', '.exe', '.msi', '.apk', '.deb', '.rpm', '.ipa',
    '.appimage'
  };

  /// Clean file extension with leading dot in lowercase, e.g. '.rar'
  String get fileExtension {
    final candidate = (fileName != null && fileName!.isNotEmpty)
        ? fileName!
        : (title.isNotEmpty ? title : url);
    final clean = candidate.split('?').first.split('#').first;
    final lastDot = clean.lastIndexOf('.');
    if (lastDot == -1 || lastDot == clean.length - 1) {
      return '';
    }
    final ext = clean.substring(lastDot).toLowerCase();
    if (ext.contains('/') || ext.contains(r'\')) return '';
    return ext;
  }

  bool get isAudio => _audioExtensions.contains(fileExtension);

  bool get isVideo => _videoExtensions.contains(fileExtension);

  bool get isArchive => _archiveExtensions.contains(fileExtension);

  bool get isDocument => _documentExtensions.contains(fileExtension);

  bool get isInstaller => _installerExtensions.contains(fileExtension);

  bool get isTorrent => url.startsWith('magnet:') || fileExtension == '.torrent';

  bool get isMedia => isVideo || isAudio;

  bool get isPlayable => isMedia;

  String get fileTypeDisplay {
    if (isVideo) return '视频';
    if (isAudio) return '音频';
    if (isArchive) return '压缩包';
    if (isInstaller) return '安装包';
    if (isDocument) return '文档';
    if (isTorrent) return '种子';
    if (fileExtension.isNotEmpty) {
      return fileExtension.replaceFirst('.', '').toUpperCase();
    }
    return '文件';
  }

  /// Clean, readable display title
  String get displayTitle {
    if (title.isNotEmpty &&
        !title.startsWith('http://') &&
        !title.startsWith('https://') &&
        !title.startsWith('magnet:')) {
      return title;
    }
    if (fileName != null && fileName!.isNotEmpty) {
      final name = fileName!.split(RegExp(r'[/\\]')).last;
      if (name.isNotEmpty) return name;
    }
    if (url.startsWith('magnet:?')) {
      final uri = Uri.tryParse(url);
      final dn = uri?.queryParameters['dn'];
      if (dn != null && dn.isNotEmpty) return dn;
      return '磁力链接任务';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty) {
          return Uri.decodeComponent(last);
        }
      }
    }
    return title.isNotEmpty ? title : '未知下载任务';
  }

  /// Human-readable error message
  String get readableErrorMessage {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return errorMessage!;
    }
    if (errorCode != null) {
      switch (errorCode) {
        case 1:
          return '网络连接或传输错误 (SSL/协议错误)';
        case 2:
          return '下载超时';
        case 3:
          return '资源不存在 (HTTP 404)';
        case 4:
          return '未找到指定的文件或 URL';
        case 6:
          return '网络读写异常';
        case 7:
          return '未完成的下载 (连接断开)';
        case 9:
          return '磁盘空间不足';
        case 12:
          return '正在下载相同资源';
        case 13:
          return '文件已存在';
        case 24:
          return 'HTTP 授权失败';
        default:
          return '下载错误 (代码: $errorCode)';
      }
    }
    return '未知下载错误';
  }

  // filePath getter - returns fileName if available
  String? get filePath => fileName;

  factory DownloadTask.fromGopeedTask(
    GopeedTask gopeedTask, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
    bool preferAudio = false,
    String? url,
  }) {
    String mappedStatus;
    switch (gopeedTask.status) {
      case 'running':
        mappedStatus = 'active';
        break;
      case 'pause':
        mappedStatus = 'paused';
        break;
      case 'wait':
      case 'ready':
        mappedStatus = 'waiting';
        break;
      case 'done':
        mappedStatus = 'complete';
        break;
      case 'error':
        mappedStatus = 'error';
        break;
      default:
        mappedStatus = gopeedTask.status;
    }

    String effectiveTitle = title ?? '';
    if (effectiveTitle.isEmpty || effectiveTitle.startsWith('magnet:')) {
      if (gopeedTask.name.isNotEmpty) {
        effectiveTitle = gopeedTask.name;
      }
    }

    String resolvedUrl = url ?? '';
    if (resolvedUrl.isEmpty) {
      resolvedUrl = gopeedTask.url;
    }

    String? bestVideoPath;
    int maxVideoLength = -1;
    final List<Map<String, dynamic>> audioFiles = [];
    String? fallbackPath;

    for (final f in gopeedTask.files) {
      String resolvedPath = f.path.isNotEmpty ? f.path : f.name;
      if (resolvedPath.isNotEmpty) {
        if (gopeedTask.savePath.isNotEmpty && !p.isAbsolute(resolvedPath)) {
          resolvedPath = p.join(gopeedTask.savePath, resolvedPath);
        }
        fallbackPath ??= resolvedPath;
        final lower = resolvedPath.toLowerCase();
        final isVideo = _videoExtensions.any((ext) => lower.endsWith(ext));
        if (isVideo && f.size > maxVideoLength) {
          maxVideoLength = f.size;
          bestVideoPath = resolvedPath;
        }
        final isAudioFile = _audioExtensions.any((ext) => lower.endsWith(ext));
        if (isAudioFile) {
          audioFiles.add({'path': resolvedPath, 'length': f.size});
        }
      }
    }

    String? bestAudioPath;
    int maxAudioLength = -1;
    if (audioFiles.isNotEmpty) {
      for (final a in audioFiles) {
        final len = a['length'] as int;
        if (len > maxAudioLength) {
          maxAudioLength = len;
        }
      }
      audioFiles.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
      bestAudioPath = audioFiles.first['path'] as String;
    }

    String? fileName;
    if (preferAudio && bestAudioPath != null) {
      fileName = bestAudioPath;
    } else if (bestAudioPath != null && maxAudioLength > maxVideoLength) {
      fileName = bestAudioPath;
    } else {
      fileName = bestVideoPath ?? bestAudioPath ?? fallbackPath;
    }

    if (fileName == null && gopeedTask.name.isNotEmpty) {
      fileName = gopeedTask.savePath.isNotEmpty && !p.isAbsolute(gopeedTask.name)
          ? p.join(gopeedTask.savePath, gopeedTask.name)
          : gopeedTask.name;
    }

    return DownloadTask(
      gid: gopeedTask.id,
      url: resolvedUrl,
      title: effectiveTitle.isNotEmpty ? effectiveTitle : (fileName ?? resolvedUrl),
      fileName: fileName,
      totalLength: gopeedTask.totalLength,
      completedLength: gopeedTask.completedLength,
      downloadSpeed: gopeedTask.downloadSpeed,
      uploadSpeed: gopeedTask.uploadSpeed,
      status: mappedStatus,
      createdAt: gopeedTask.createdAt ?? DateTime.now(),
      updatedAt: gopeedTask.updatedAt ?? DateTime.now(),
      bangumiId: bangumiId,
      episodeNumber: episodeNumber,
    );
  }

  DownloadTask copyWith({
    String? gid,
    String? url,
    String? title,
    String? fileName,
    int? totalLength,
    int? completedLength,
    int? downloadSpeed,
    int? uploadSpeed,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
    int? errorCode,
    String? bangumiId,
    int? episodeNumber,
  }) {
    return DownloadTask(
      gid: gid ?? this.gid,
      url: url ?? this.url,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      totalLength: totalLength ?? this.totalLength,
      completedLength: completedLength ?? this.completedLength,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      bangumiId: bangumiId ?? this.bangumiId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }
}
