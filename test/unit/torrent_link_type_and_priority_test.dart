import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/widgets/torrent_link_badge.dart';
import 'package:kazumi/modules/torrent_search/parser/torrent_file_parser.dart';

void main() {
  group('TorrentItem Link Type & Priority Classification Tests', () {
    test('Nyaa 1530677 real-world case: Dual source (torrent + magnet)', () {
      const nyaaItem = TorrentItem(
        title: '[SubsPlease] Spy x Family - 06 (1080p) [F29C52E7].mkv',
        magnetUrl:
            'magnet:?xt=urn:btih:6bb64c74937a0f7e1b5bcf279b329432f838bc6f&dn=%5BSubsPlease%5D+Spy+x+Family+-+06+%281080p%29+%5BF29C52E7%5D.mkv',
        torrentUrl: 'https://nyaa.si/download/1530677.torrent',
        pageUrl: 'https://nyaa.si/view/1530677',
        source: TorrentSourceType.nyaa,
        indexerName: 'Nyaa',
        seeders: 154,
        leechers: 12,
        fileSize: '1.4 GB',
      );

      expect(nyaaItem.hasTorrent, isTrue);
      expect(nyaaItem.hasMagnet, isTrue);
      expect(nyaaItem.isDualSource, isTrue);
      expect(nyaaItem.linkType, equals(TorrentLinkType.dual));
      expect(nyaaItem.linkTypeLabel, equals('种子+磁力'));
      expect(nyaaItem.effectiveTorrentUrl, equals('https://nyaa.si/download/1530677.torrent'));
      expect(nyaaItem.effectiveMagnetUrl, startsWith('magnet:?xt=urn:btih:'));
    });

    test('Torrent-only item: hasTorrent is true, hasMagnet is false', () {
      const torrentOnlyItem = TorrentItem(
        title: 'Fedora-Workstation-Live-x86_64-39.iso',
        magnetUrl: '',
        torrentUrl: 'https://torrent.fedoraproject.org/torrents/Fedora-Workstation-Live-x86_64-39.torrent',
        source: TorrentSourceType.torznab,
        indexerName: 'Fedora Tracker',
      );

      expect(torrentOnlyItem.hasTorrent, isTrue);
      expect(torrentOnlyItem.hasMagnet, isFalse);
      expect(torrentOnlyItem.isDualSource, isFalse);
      expect(torrentOnlyItem.linkType, equals(TorrentLinkType.torrentOnly));
      expect(torrentOnlyItem.linkTypeLabel, equals('种子'));
      expect(torrentOnlyItem.effectiveTorrentUrl, equals('https://torrent.fedoraproject.org/torrents/Fedora-Workstation-Live-x86_64-39.torrent'));
      expect(torrentOnlyItem.effectiveMagnetUrl, isNull);
    });

    test('Magnet-only item: hasTorrent is false, hasMagnet is true', () {
      const magnetOnlyItem = TorrentItem(
        title: 'Ubuntu 24.04 Desktop AMD64',
        magnetUrl: 'magnet:?xt=urn:btih:5a9e3e78a63212891238912389123',
        torrentUrl: null,
        source: TorrentSourceType.piratebay,
        indexerName: 'The Pirate Bay',
      );

      expect(magnetOnlyItem.hasTorrent, isFalse);
      expect(magnetOnlyItem.hasMagnet, isTrue);
      expect(magnetOnlyItem.isDualSource, isFalse);
      expect(magnetOnlyItem.linkType, equals(TorrentLinkType.magnetOnly));
      expect(magnetOnlyItem.linkTypeLabel, equals('磁力'));
      expect(magnetOnlyItem.effectiveTorrentUrl, isNull);
      expect(magnetOnlyItem.effectiveMagnetUrl, equals('magnet:?xt=urn:btih:5a9e3e78a63212891238912389123'));
    });

    test('Edge case: magnetUrl actually contains http link and torrentUrl is null', () {
      const swappedItem = TorrentItem(
        title: 'Test Software Torrent',
        magnetUrl: 'https://tracker.org/download/file.torrent',
        torrentUrl: null,
        source: TorrentSourceType.cardigann,
      );

      expect(swappedItem.hasTorrent, isTrue);
      expect(swappedItem.hasMagnet, isFalse);
      expect(swappedItem.linkType, equals(TorrentLinkType.torrentOnly));
      expect(swappedItem.effectiveTorrentUrl, equals('https://tracker.org/download/file.torrent'));
    });

    test('Edge case: torrentUrl starts with magnet:? and magnetUrl is empty', () {
      const swappedMagnetItem = TorrentItem(
        title: 'Test Swapped Magnet',
        magnetUrl: '',
        torrentUrl: 'magnet:?xt=urn:btih:1111222233334444',
        source: TorrentSourceType.cardigann,
      );

      expect(swappedMagnetItem.hasTorrent, isFalse);
      expect(swappedMagnetItem.hasMagnet, isTrue);
      expect(swappedMagnetItem.linkType, equals(TorrentLinkType.magnetOnly));
      expect(swappedMagnetItem.effectiveMagnetUrl, equals('magnet:?xt=urn:btih:1111222233334444'));
    });

    test('Empty links item: linkType is none', () {
      const emptyItem = TorrentItem(
        title: 'Broken Entry',
        magnetUrl: '',
        torrentUrl: null,
        source: TorrentSourceType.cardigann,
      );

      expect(emptyItem.hasTorrent, isFalse);
      expect(emptyItem.hasMagnet, isFalse);
      expect(emptyItem.isDualSource, isFalse);
      expect(emptyItem.linkType, equals(TorrentLinkType.none));
      expect(emptyItem.linkTypeLabel, equals('无链接'));
    });
  });

  group('TorrentLinkBadge Widget Tests', () {
    testWidgets('renders dual badge with "种子+磁力" text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentLinkBadge(type: TorrentLinkType.dual),
          ),
        ),
      );

      expect(find.text('种子+磁力'), findsOneWidget);
      expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
    });

    testWidgets('renders torrentOnly badge with "种子" text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentLinkBadge(type: TorrentLinkType.torrentOnly),
          ),
        ),
      );

      expect(find.text('种子'), findsOneWidget);
      expect(find.byIcon(Icons.file_present_outlined), findsOneWidget);
    });

    testWidgets('renders magnetOnly badge with "磁力" text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentLinkBadge(type: TorrentLinkType.magnetOnly),
          ),
        ),
      );

      expect(find.text('磁力'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('renders nothing when type is none', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentLinkBadge(type: TorrentLinkType.none),
          ),
        ),
      );

      expect(find.byType(TorrentLinkBadge), findsOneWidget);
      expect(find.text('种子+磁力'), findsNothing);
      expect(find.text('种子'), findsNothing);
      expect(find.text('磁力'), findsNothing);
    });

    testWidgets('compact mode renders properly without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentLinkBadge(type: TorrentLinkType.dual, compact: true),
          ),
        ),
      );

      expect(find.text('种子+磁力'), findsOneWidget);
    });
  });

  group('Torrent Priority & 0ms Parsing Verification', () {
    test('TorrentFileParser parseBytes extracts multi-file tree instantly', () {
      // 构造最小有效的合法 Bencode 多文件 Torrent 字节流
      final bencodeData = utf8.encode(
        'd4:info'
        'd5:filesl'
        'd6:lengthi10485760e4:pathl12:episode1.mkvee'
        'd6:lengthi20971520e4:pathl12:episode2.mkvee'
        'e'
        '4:name15:Spy x Family S1'
        '12:piece lengthi262144e'
        'e'
        'e',
      );

      final parsed = TorrentFileParser.parseBytes(Uint8List.fromList(bencodeData));
      expect(parsed.name, equals('Spy x Family S1'));
      expect(parsed.files.length, equals(2));
      expect(parsed.files[0].name, equals('episode1.mkv'));
      expect(parsed.files[0].sizeBytes, equals(10485760));
      expect(parsed.files[1].name, equals('episode2.mkv'));
      expect(parsed.files[1].sizeBytes, equals(20971520));
      expect(parsed.totalBytes, equals(31457280));
    });
  });
}
