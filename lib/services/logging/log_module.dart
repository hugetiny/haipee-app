/// Strongly-typed module taxonomy for all Haipee operational logging.
enum LogModule {
  stream('STREAM'),
  gopeed('GOPEED'),
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
        if (rawTag.contains('gopeed')) return LogModule.gopeed;
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
        if (rawTag.contains('download') || rawTag.contains('gopeed')) {
          return LogModule.download;
        }
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

    // 2. 深入消息正文特征关键词，赋能旧代码自动接入分类体系
    final lower = str.toLowerCase();
    if (lower.contains('player intent error') ||
        lower.contains('media_kit') ||
        lower.contains('dandanplay') ||
        lower.contains('aniskip') ||
        lower.contains('danmaku') ||
        lower.contains('audio-add') ||
        lower.contains('libmpv')) {
      return LogModule.player;
    }
    if (lower.contains('torrserver') ||
        lower.contains('libtorrent') ||
        lower.contains('torrentstream') ||
        lower.contains('hls') ||
        lower.contains('.m3u8') ||
        lower.contains('免嗅探直接视频流')) {
      return LogModule.stream;
    }
    if (lower.contains('gopeed') ||
        lower.contains('downloadtask') ||
        lower.contains('aria2')) {
      return LogModule.download;
    }
    if (lower.contains('cardigann') ||
        lower.contains('torznab') ||
        lower.contains('indexer')) {
      return LogModule.indexer;
    }
    if (lower.contains('webview') ||
        lower.contains('maccms') ||
        lower.contains('tvbox') ||
        lower.contains('xpath') ||
        lower.contains('嗅探') ||
        lower.contains('规则')) {
      return LogModule.plugin;
    }
    if (lower.contains('dioexception') ||
        lower.contains('socketexception') ||
        lower.contains('handshake') ||
        lower.contains('http-header') ||
        lower.contains('bad response') ||
        lower.contains('connection timeout')) {
      return LogModule.network;
    }
    if (lower.contains('syncplay')) return LogModule.syncplay;
    if (lower.contains('webdav') || lower.contains('hivestorage')) return LogModule.storage;
    if (lower.contains('renderflex overflow') || lower.contains('snackbar') || lower.contains('toast message')) {
      return LogModule.ui;
    }

    return LogModule.system;
  }
}
