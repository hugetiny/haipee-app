import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';

void main() {
  group('PT Tracker Nature & TorrentItem Tag Tests', () {
    test('TorrentItem trackerType public, semi-private, and private getters', () {
      const publicItem = TorrentItem(
        title: '[Mikan] Frieren - 01 [1080p].mp4',
        magnetUrl: 'magnet:?xt=urn:btih:1111',
        source: TorrentSourceType.cardigann,
        indexerName: '蜜柑计划',
        trackerType: 'public',
      );
      expect(publicItem.isPublicTracker, isTrue);
      expect(publicItem.isSemiPrivateTracker, isFalse);
      expect(publicItem.isPrivateTracker, isFalse);
      expect(publicItem.trackerTypeLabel, '公开');

      const semiPrivateItem = TorrentItem(
        title: '[RuTracker] Frieren [BDRip 1080p].mkv',
        magnetUrl: 'magnet:?xt=urn:btih:2222',
        source: TorrentSourceType.cardigann,
        indexerName: 'RuTracker',
        trackerType: 'semi-private',
      );
      expect(semiPrivateItem.isPublicTracker, isFalse);
      expect(semiPrivateItem.isSemiPrivateTracker, isTrue);
      expect(semiPrivateItem.isPrivateTracker, isFalse);
      expect(semiPrivateItem.trackerTypeLabel, '半私有');

      const privateItem = TorrentItem(
        title: '[M-Team] Frieren 2023 1080p BluRay x265-MTeam',
        magnetUrl: 'magnet:?xt=urn:btih:3333',
        source: TorrentSourceType.cardigann,
        indexerName: 'M-Team',
        trackerType: 'private',
      );
      expect(privateItem.isPublicTracker, isFalse);
      expect(privateItem.isSemiPrivateTracker, isFalse);
      expect(privateItem.isPrivateTracker, isTrue);
      expect(privateItem.trackerTypeLabel, '私有 PT');

      // Default with null trackerType falls back to public
      const defaultItem = TorrentItem(
        title: '[Nyaa] Frieren - 01.mkv',
        magnetUrl: 'magnet:?xt=urn:btih:4444',
        source: TorrentSourceType.nyaa,
      );
      expect(defaultItem.isPublicTracker, isTrue);
      expect(defaultItem.trackerTypeLabel, '公开');
    });

    test('IndexerPlugin.fromYaml parses definition.type as private correctly', () {
      const privateDefYaml = '''
---
id: mteam
name: M-Team
description: "M-Team 顶级综合 PT 站"
language: zh-CN
type: private
links:
  - https://kp.m-team.cc/
caps:
  categorymappings:
    - {id: 401, cat: 2000, desc: "Movie"}
  modes:
    search: [q]
search:
  paths:
    - path: /browse
  rows:
    selector: table.torrents > tr
  fields:
    title:
      selector: a[href*="detail"]
    magnet:
      text: "magnet:?xt=urn:btih:private123"
''';
      final plugin = IndexerPlugin.fromYaml(privateDefYaml);
      expect(plugin.definition.isPrivate, isTrue);
      expect(plugin.definition.type, 'private');
      expect(plugin.definition.isPublic, isFalse);
    });
  });
}
