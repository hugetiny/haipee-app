import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/services/logging/log_module.dart';

void main() {
  group('LogModule Tests', () {
    test('all enum values have non-empty uppercase tags', () {
      for (final module in LogModule.values) {
        expect(module.tag, isNotEmpty);
        expect(module.tag, equals(module.tag.toUpperCase()));
      }
    });

    test('LogModule.detect extracts module from bracketed prefix tags', () {
      expect(LogModule.detect('[Gopeed] stdout: downloading'), equals(LogModule.gopeed));
      expect(LogModule.detect('[GopeedProcessManager] started'), equals(LogModule.gopeed));
      expect(LogModule.detect('[TorrentStreamService] init'), equals(LogModule.stream));
      expect(LogModule.detect('[TorrServer] ready'), equals(LogModule.stream));
      expect(LogModule.detect('[Libtorrent] alert'), equals(LogModule.stream));
      expect(LogModule.detect('[IndexerManager] loaded 10 indexers'), equals(LogModule.indexer));
      expect(LogModule.detect('[TorznabSource] query'), equals(LogModule.indexer));
      expect(LogModule.detect('[CardigannExecutor] parse'), equals(LogModule.indexer));
      expect(LogModule.detect('[PlayerController] start play'), equals(LogModule.player));
      expect(LogModule.detect('[Danmaku] loaded'), equals(LogModule.player));
      expect(LogModule.detect('[DownloadTask] queued'), equals(LogModule.download));
      expect(LogModule.detect('[GopeedService] task added'), equals(LogModule.gopeed));
      expect(LogModule.detect('[SyncPlay] connected'), equals(LogModule.syncplay));
      expect(LogModule.detect('[HiveStorage] box opened'), equals(LogModule.storage));
      expect(LogModule.detect('[WebDAV] synced'), equals(LogModule.storage));
      expect(LogModule.detect('[DioInterceptor] GET 200'), equals(LogModule.network));
      expect(LogModule.detect('[Layout Overflow Filtered] summary'), equals(LogModule.ui));
      expect(LogModule.detect('[DialogHelper] show'), equals(LogModule.ui));
      expect(LogModule.detect('[PluginShop] loaded'), equals(LogModule.plugin));
      expect(LogModule.detect('[kazumi webview parser] event'), equals(LogModule.plugin));
    });

    test('LogModule.detect falls back to LogModule.system on unknown or untagged messages', () {
      expect(LogModule.detect('Just a regular message'), equals(LogModule.system));
      expect(LogModule.detect(null), equals(LogModule.system));
      expect(LogModule.detect('[UnknownTag] message'), equals(LogModule.system));
      expect(LogModule.detect(12345), equals(LogModule.system));
    });
  });
}
