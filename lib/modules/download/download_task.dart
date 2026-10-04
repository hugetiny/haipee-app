import 'package:hive_ce/hive.dart';

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
    String? bestVideoPath;
    int maxVideoLength = -1;
    String? fallbackPath;

    if (aria2Status['files'] != null && aria2Status['files'] is List) {
      final List<dynamic> files = aria2Status['files'] as List<dynamic>;
      for (final f in files) {
        if (f is Map) {
          final String path = f['path']?.toString() ?? '';
          final int length =
              int.tryParse(f['length']?.toString() ?? '0') ?? 0;
          if (path.isNotEmpty) {
            fallbackPath ??= path;
            final lower = path.toLowerCase();
            final isVideo = lower.endsWith('.mp4') ||
                lower.endsWith('.mkv') ||
                lower.endsWith('.avi') ||
                lower.endsWith('.flv') ||
                lower.endsWith('.ts') ||
                lower.endsWith('.mov') ||
                lower.endsWith('.webm');
            if (isVideo && length > maxVideoLength) {
              maxVideoLength = length;
              bestVideoPath = path;
            }
          }
          if (url.isEmpty && f['uris'] != null && f['uris'] is List) {
            final uris = f['uris'] as List<dynamic>;
            if (uris.isNotEmpty && uris[0] is Map) {
              url = (uris[0] as Map<String, dynamic>)['uri']?.toString() ?? '';
            }
          }
        }
      }
    }

    final String? fileName = bestVideoPath ?? fallbackPath;

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
}
