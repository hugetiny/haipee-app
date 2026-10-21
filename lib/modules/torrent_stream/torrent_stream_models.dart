/// Stream buffer and playback states.
enum StreamState {
  stopped,
  buffering,
  ready,
  error,
}

/// BitTorrent engine states.
enum TorrentState {
  queuedForChecking,
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  allocating,
  checkingResumeData,
  paused,
  error,
}

/// Information describing a single file entry within a torrent payload.
class FileInfo {
  final int index;
  final String name;
  final int size;
  final String path;
  final bool isStreamable;

  int get id => index;

  const FileInfo({
    int? index,
    int? id,
    required this.name,
    required this.size,
    required this.path,
    this.isStreamable = true,
  }) : index = index ?? id ?? 0;

  @override
  String toString() =>
      'FileInfo(index: $index, name: $name, size: $size, path: $path, isStreamable: $isStreamable)';
}

/// Metadata and real-time network discovery state for an active torrent.
class TorrentInfo {
  final int id;
  final String name;
  final String savePath;
  final int numPeers;
  final int numSeeds;
  final bool hasMetadata;
  final String errorMsg;
  final TorrentState state;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int totalDone;
  final int totalWanted;
  final int totalUploaded;
  final bool isPaused;
  final bool isFinished;
  final int queuePosition;

  const TorrentInfo({
    this.id = 0,
    this.name = '',
    this.savePath = '',
    this.numPeers = 0,
    this.numSeeds = 0,
    this.hasMetadata = false,
    this.errorMsg = '',
    this.state = TorrentState.downloading,
    this.progress = 0.0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.totalUploaded = 0,
    this.isPaused = false,
    this.isFinished = false,
    this.queuePosition = 0,
  });
}

/// Real-time playback stream buffering statistics and active speed metrics.
class StreamInfo {
  final int id;
  final int torrentId;
  final int fileIndex;
  final String url;
  final int fileSize;
  final int readHead;
  final int readaheadWindow;
  final int activePeers;
  final int downloadRate;
  final int bufferPieces;
  final double bufferSeconds;
  final StreamState streamState;

  const StreamInfo({
    this.id = 0,
    this.torrentId = 0,
    this.fileIndex = -1,
    this.url = '',
    this.fileSize = 0,
    this.readHead = 0,
    this.readaheadWindow = 0,
    this.activePeers = 0,
    this.downloadRate = 0,
    this.bufferPieces = 0,
    this.bufferSeconds = 0.0,
    this.streamState = StreamState.buffering,
  });
}

/// BitTorrent engine session configuration options.
class BtConfig {
  final int? maxConnections;
  final int? downloadRateLimit;
  final int? uploadRateLimit;
  final int? cacheSize;
  final int? readerReadAhead;
  final int? preloadCache;
  final int? connectionsLimit;
  final int? torrentDisconnectTimeout;
  final bool? forceEncrypt;
  final bool? disableTcp;
  final bool? disableUtp;
  final bool? disableUpload;
  final bool? disableDht;
  final bool? disableUpnp;
  final bool? enableIpv6;
  final int? peersListenPort;
  final bool? responsiveMode;

  const BtConfig({
    this.maxConnections,
    this.downloadRateLimit,
    this.uploadRateLimit,
    this.cacheSize,
    this.readerReadAhead,
    this.preloadCache,
    this.connectionsLimit,
    this.torrentDisconnectTimeout,
    this.forceEncrypt,
    this.disableTcp,
    this.disableUtp,
    this.disableUpload,
    this.disableDht,
    this.disableUpnp,
    this.enableIpv6,
    this.peersListenPort,
    this.responsiveMode,
  });
}
