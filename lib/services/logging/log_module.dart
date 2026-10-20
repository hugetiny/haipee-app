/// Strongly-typed module taxonomy for all Kazumi operational logging.
enum LogModule {
  stream('STREAM'),
  aria2('ARIA2'),
  indexer('INDEXER'),
  player('PLAYER'),
  network('NETWORK'),
  ui('UI'),
  download('DOWNLOAD'),
  syncplay('SYNCPLAY'),
  storage('STORAGE'),
  system('SYSTEM'),
  plugin('PLUGIN');

  final String tag;
  const LogModule(this.tag);

  /// Auto-detects module from a message string or bracketed prefix tag.
  static LogModule detect(dynamic message) {
    if (message == null) return LogModule.system;
    final str = message.toString();
    if (str.startsWith('[')) {
      final closeIdx = str.indexOf(']');
      if (closeIdx > 1) {
        final rawTag = str.substring(1, closeIdx).toLowerCase();
        if (rawTag.contains('aria2')) return LogModule.aria2;
        if (rawTag.contains('torrent') ||
            rawTag.contains('stream') ||
            rawTag.contains('torrserver') ||
            rawTag.contains('libtorrent')) {
          return LogModule.stream;
        }
        if (rawTag.contains('indexer') ||
            rawTag.contains('torznab') ||
            rawTag.contains('cardigann')) {
          return LogModule.indexer;
        }
        if (rawTag.contains('player') ||
            rawTag.contains('playback') ||
            rawTag.contains('danmaku') ||
            rawTag.contains('media_kit')) {
          return LogModule.player;
        }
        if (rawTag.contains('download')) return LogModule.download;
        if (rawTag.contains('syncplay')) return LogModule.syncplay;
        if (rawTag.contains('storage') ||
            rawTag.contains('hive') ||
            rawTag.contains('webdav')) {
          return LogModule.storage;
        }
        if (rawTag.contains('network') ||
            rawTag.contains('dio') ||
            rawTag.contains('http') ||
            rawTag.contains('api')) {
          return LogModule.network;
        }
        if (rawTag.contains('plugin') || rawTag.contains('webview')) {
          return LogModule.plugin;
        }
        if (rawTag.contains('ui') ||
            rawTag.contains('dialog') ||
            rawTag.contains('layout') ||
            rawTag.contains('widget')) {
          return LogModule.ui;
        }
      }
    }
    return LogModule.system;
  }
}
