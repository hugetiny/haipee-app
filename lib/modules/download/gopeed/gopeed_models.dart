class GopeedTask {
  final String id;
  final String name;
  final String protocol;
  final String status;
  final int totalLength;
  final int completedLength;
  final int downloadSpeed;
  final int uploadSpeed;
  final int uploaded;
  final String savePath;
  final String url;
  final List<GopeedFile> files;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? doneAt;

  GopeedTask({
    required this.id,
    required this.name,
    this.protocol = 'http',
    required this.status,
    this.totalLength = 0,
    this.completedLength = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.uploaded = 0,
    this.savePath = '',
    this.url = '',
    this.files = const [],
    this.createdAt,
    this.updatedAt,
    this.doneAt,
  });

  bool get isRunning => status == 'running';
  bool get isPaused => status == 'pause';
  bool get isWaiting => status == 'wait' || status == 'ready';
  bool get isDone => status == 'done';
  bool get isError => status == 'error';

  double get progress {
    if (totalLength == 0) return 0.0;
    return (completedLength / totalLength).clamp(0.0, 1.0);
  }

  factory GopeedTask.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final req = meta['req'] as Map<String, dynamic>? ?? {};
    final res = meta['res'] as Map<String, dynamic>? ?? {};
    final opts = meta['opts'] as Map<String, dynamic>? ?? {};
    final progress = json['progress'] as Map<String, dynamic>? ?? {};

    final rawFiles = res['files'] as List<dynamic>? ?? [];
    final files = rawFiles
        .map((f) => GopeedFile.fromJson((f as Map).cast<String, dynamic>()))
        .toList();

    return GopeedTask(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? res['name']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? 'http',
      status: json['status']?.toString() ?? 'ready',
      totalLength: (res['size'] as num?)?.toInt() ?? 0,
      completedLength: (progress['downloaded'] as num?)?.toInt() ?? 0,
      downloadSpeed: (progress['speed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (progress['uploadSpeed'] as num?)?.toInt() ?? 0,
      uploaded: (progress['uploaded'] as num?)?.toInt() ?? 0,
      savePath: opts['path']?.toString() ?? '',
      url: req['url']?.toString() ?? '',
      files: files,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      doneAt: json['doneAt'] != null
          ? DateTime.tryParse(json['doneAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'protocol': protocol,
      'status': status,
      'totalLength': totalLength,
      'completedLength': completedLength,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'savePath': savePath,
      'url': url,
    };
  }
}

class GopeedFile {
  final String name;
  final String path;
  final int size;

  GopeedFile({
    required this.name,
    required this.path,
    required this.size,
  });

  factory GopeedFile.fromJson(Map<String, dynamic> json) {
    return GopeedFile(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class GopeedTaskEvent {
  final String eventType;
  final GopeedTask? task;
  final Map<String, dynamic> raw;

  GopeedTaskEvent({
    required this.eventType,
    this.task,
    required this.raw,
  });

  factory GopeedTaskEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    final taskData = json['task'] as Map<String, dynamic>?;
    return GopeedTaskEvent(
      eventType: type,
      task: taskData != null ? GopeedTask.fromJson(taskData) : null,
      raw: json,
    );
  }
}
