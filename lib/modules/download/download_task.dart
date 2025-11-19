class DownloadTask {
  String gid;

  String url;

  String title;

  String? fileName;

  int totalLength;

  int completedLength;

  int downloadSpeed;

  String status; // active, waiting, paused, error, complete, removed

  DateTime createdAt;

  DateTime updatedAt;

  String? errorMessage;

  int? errorCode;

  String? bangumiId;

  int? episodeNumber;

  DownloadTask({
    required this.gid,
    required this.url,
    required this.title,
    this.fileName,
    this.totalLength = 0,
    this.completedLength = 0,
    this.downloadSpeed = 0,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.errorCode,
    this.bangumiId,
    this.episodeNumber,
  });

  double get progress {
    if (totalLength == 0) return 0.0;
    return completedLength / totalLength;
  }

  bool get isActive => status == 'active';
  bool get isWaiting => status == 'waiting';
  bool get isPaused => status == 'paused';
  bool get isError => status == 'error';
  bool get isComplete => status == 'complete';
  bool get isRemoved => status == 'removed';
  bool get isDownloading => isActive || isWaiting;

  // filePath getter - returns fileName if available
  String? get filePath => fileName;

  factory DownloadTask.fromAria2Status(
    Map<String, dynamic> aria2Status, {
    String? title,
    String? bangumiId,
    int? episodeNumber,
  }) {
    final String gid = aria2Status['gid'] as String? ?? '';
    final String status = aria2Status['status'] as String? ?? 'unknown';
    final int totalLength =
        int.tryParse(aria2Status['totalLength']?.toString() ?? '0') ?? 0;
    final int completedLength =
        int.tryParse(aria2Status['completedLength']?.toString() ?? '0') ?? 0;
    final int downloadSpeed =
        int.tryParse(aria2Status['downloadSpeed']?.toString() ?? '0') ?? 0;
    final String? errorMessage = aria2Status['errorMessage'] as String?;
    final int? errorCode = aria2Status['errorCode'] != null
        ? int.tryParse(aria2Status['errorCode'].toString())
        : null;

    String url = '';
    String? fileName;
    if (aria2Status['files'] != null && aria2Status['files'] is List) {
      final List<dynamic> files = aria2Status['files'] as List<dynamic>;
      if (files.isNotEmpty && files[0] is Map) {
        final Map<String, dynamic> firstFile =
            files[0] as Map<String, dynamic>;
        if (firstFile['uris'] != null && firstFile['uris'] is List) {
          final List<dynamic> uris = firstFile['uris'] as List<dynamic>;
          if (uris.isNotEmpty && uris[0] is Map) {
            url = (uris[0] as Map<String, dynamic>)['uri']?.toString() ?? '';
          }
        }
        fileName = firstFile['path'] as String?;
      }
    }

    return DownloadTask(
      gid: gid,
      url: url,
      title: title ?? fileName ?? url,
      fileName: fileName,
      totalLength: totalLength,
      completedLength: completedLength,
      downloadSpeed: downloadSpeed,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      errorMessage: errorMessage,
      errorCode: errorCode,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      bangumiId: bangumiId ?? this.bangumiId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      gid: json['gid'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      fileName: json['fileName'] as String?,
      totalLength: json['totalLength'] as int? ?? 0,
      completedLength: json['completedLength'] as int? ?? 0,
      downloadSpeed: json['downloadSpeed'] as int? ?? 0,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      errorMessage: json['errorMessage'] as String?,
      errorCode: json['errorCode'] as int?,
      bangumiId: json['bangumiId'] as String?,
      episodeNumber: json['episodeNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gid': gid,
      'url': url,
      'title': title,
      'fileName': fileName,
      'totalLength': totalLength,
      'completedLength': completedLength,
      'downloadSpeed': downloadSpeed,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'errorMessage': errorMessage,
      'errorCode': errorCode,
      'bangumiId': bangumiId,
      'episodeNumber': episodeNumber,
    };
  }
}
