import 'dart:async';

/// Stream buffer and playback states.
enum StreamState {
  stopped,
  buffering,
  ready,
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
  final int numPeers;
  final bool hasMetadata;
  final String errorMsg;
  final int downloadRate;

  const TorrentInfo({
    this.id = 0,
    this.numPeers = 0,
    this.hasMetadata = false,
    this.errorMsg = '',
    this.downloadRate = 0,
  });
}

/// Real-time playback stream buffering statistics and active speed metrics.
class StreamInfo {
  final int id;
  final int activePeers;
  final int downloadRate;
  final int bufferPieces;
  final double bufferSeconds;
  final StreamState streamState;

  const StreamInfo({
    this.id = 0,
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

  const BtConfig({
    this.maxConnections,
    this.downloadRateLimit,
    this.uploadRateLimit,
  });
}
