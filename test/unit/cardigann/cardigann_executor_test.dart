import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/cardigann/cardigann_torznab.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';

void main() {
  group('CardigannQueryExecutor HTML Parsing Tests', () {
    const sampleYaml = '''
---
id: testnyaa
name: TestNyaa
language: en-US
type: public
links:
  - https://testnyaa.si/

caps:
  categorymappings:
    - {id: 1_2, cat: 5070, desc: "Anime - English"}
    - {id: 2_1, cat: 3000, desc: "Books"}
    - {id: 3_1, cat: 1000, desc: "Audio"}

search:
  paths:
    - path: /
  rows:
    selector: table.torrent-list > tbody > tr:has(a[href*="/download/"])

  fields:
    category:
      selector: td:nth-child(1) a
      attribute: href
      filters:
        - name: querystring
          args: c
    title:
      selector: td:nth-child(2) a:last-child
      attribute: title
    details:
      selector: td:nth-child(2) a:last-child
      attribute: href
    download:
      selector: a[href*="/download/"]
      attribute: href
    magnet:
      selector: a[href^="magnet:"]
      attribute: href
    size:
      selector: td:nth-child(4)
    date:
      selector: td:nth-child(5)
    seeders:
      selector: td:nth-child(6)
    leechers:
      selector: td:nth-child(7)
    downloadvolumefactor:
      case:
        tr.success: 0
        "*": 1
''';

    const sampleHtml = '''
<!DOCTYPE html>
<html>
<body>
  <table class="torrent-list">
    <thead>
      <tr>
        <th>Cat</th><th>Name</th><th>Links</th><th>Size</th><th>Date</th><th>S</th><th>L</th>
      </tr>
    </thead>
    <tbody>
      <tr class="success">
        <td><a href="/?c=1_2"><img alt="Anime" /></a></td>
        <td>
          <a href="/view/1001" title="[Erai-raws] Sousou no Frieren - 28 [1080p][HEVC][Multiple Subtitle].mkv">[Erai-raws] Sousou no Frieren - 28 [1080p][HEVC][Multiple Subtitle].mkv</a>
        </td>
        <td class="text-center">
          <a href="/download/1001.torrent"><i class="fa fa-download"></i></a>
          <a href="magnet:?xt=urn:btih:ABCDEF1234567890&dn=Frieren"><i class="fa fa-magnet"></i></a>
        </td>
        <td class="text-center">1.4 GiB</td>
        <td class="text-center">2024-03-22 15:30</td>
        <td class="text-center" style="color: green;">125</td>
        <td class="text-center" style="color: red;">12</td>
      </tr>
      <tr class="default">
        <td><a href="/?c=2_1"><img alt="Books" /></a></td>
        <td>
          <a href="/view/1002" title="Chainsaw Man Vol 15 (Digital) (danke-Empire).cbz">Chainsaw Man Vol 15 (Digital) (danke-Empire).cbz</a>
        </td>
        <td class="text-center">
          <a href="/download/1002.torrent"><i class="fa fa-download"></i></a>
          <a href="magnet:?xt=urn:btih:FEDCBA0987654321&dn=Chainsaw"><i class="fa fa-magnet"></i></a>
        </td>
        <td class="text-center">85.4 MiB</td>
        <td class="text-center">2024-03-20 10:00</td>
        <td class="text-center">45</td>
        <td class="text-center">3</td>
      </tr>
      <tr>
        <!-- Irrelevant row without download link, should be skipped by :has() selector -->
        <td>Ad row</td>
      </tr>
    </tbody>
  </table>
</body>
</html>
''';

    test('parseHtmlResults extracts rows and maps Torznab categories properly', () {
      final definition = CardigannParser.parseYaml(sampleYaml);
      final executor = CardigannQueryExecutor();

      final items = executor.parseHtmlResults(
        htmlContent: sampleHtml,
        definition: definition,
        baseUrl: 'https://testnyaa.si',
      );

      expect(items.length, equals(2));

      // First item (Anime)
      final animeItem = items[0];
      expect(animeItem.title, contains('Sousou no Frieren - 28'));
      expect(animeItem.magnetUrl, equals('magnet:?xt=urn:btih:ABCDEF1234567890&dn=Frieren'));
      expect(animeItem.torrentUrl, equals('https://testnyaa.si/download/1001.torrent'));
      expect(animeItem.pageUrl, equals('https://testnyaa.si/view/1001'));
      expect(animeItem.seeders, equals(125));
      expect(animeItem.leechers, equals(12));
      expect(animeItem.isFreeleech, isTrue); // from tr.success
      expect(animeItem.source, equals(TorrentSourceType.cardigann));
      expect(animeItem.indexerName, equals('TestNyaa'));
      expect(animeItem.category, equals(TorrentCategory.video));
      expect(animeItem.resolution, equals('1080p'));
      expect(animeItem.codec, equals('HEVC'));

      // Second item (Books)
      final bookItem = items[1];
      expect(bookItem.title, contains('Chainsaw Man Vol 15'));
      expect(bookItem.magnetUrl, equals('magnet:?xt=urn:btih:FEDCBA0987654321&dn=Chainsaw'));
      expect(bookItem.pageUrl, equals('https://testnyaa.si/view/1002'));
      expect(bookItem.seeders, equals(45));
      expect(bookItem.isFreeleech, isFalse); // from default class
      expect(bookItem.category, equals(TorrentCategory.document)); // Torznab 3000
    });

    test('TorznabCategories mapping functions work in both directions', () {
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.tvAnime), equals(TorrentCategory.video));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.moviesWebDl), equals(TorrentCategory.video));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.audioLossless), equals(TorrentCategory.audio));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.pcGames), equals(TorrentCategory.game));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.booksEbook), equals(TorrentCategory.document));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.pcIso), equals(TorrentCategory.software));

      expect(TorznabCategories.fromTorrentCategory(TorrentCategory.video), contains(TorznabCategories.tvAnime));
      expect(TorznabCategories.fromTorrentCategory(TorrentCategory.audio), contains(TorznabCategories.audio));
    });
  });
}
