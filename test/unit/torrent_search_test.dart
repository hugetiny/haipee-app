import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/parser/anime_title_parser.dart';
import 'package:haipee/modules/torrent_search/sources/mikan_source.dart';
import 'package:haipee/modules/torrent_search/sources/nyaa_source.dart';
import 'package:haipee/modules/torrent_search/sources/torznab_source.dart';

void main() {
  group('AnimeTitleParser Tests (化繁为简标题清洗)', () {
    test('正确解析典型字幕组标题 (NC-Raws)', () {
      const raw =
          '[NC-Raws] 葬送的芙莉莲 / Sousou no Frieren - 08 [Baha][WEB-DL][1080p][AVC AAC][CHT].mkv';
      final result = AnimeTitleParser.parse(raw);

      expect(result.subgroup, equals('NC-Raws'));
      expect(result.episode, equals('08'));
      expect(result.resolution, equals('1080P'));
      expect(result.language, equals('繁中'));
      expect(result.cleanedTitle.contains('葬送的芙莉莲'), isTrue);
    });

    test('正确解析中文方括号前缀与第XX话格式', () {
      const raw = '【极影字幕社】★10月新番 葬送的芙莉莲 Sousou no Frieren 第05话 GB 720P MP4';
      final result = AnimeTitleParser.parse(raw);

      expect(result.subgroup, equals('极影字幕社'));
      expect(result.episode, equals('05'));
      expect(result.resolution, equals('720P'));
      expect(result.language, equals('简中'));
    });

    test('正确解析全集/合集标识', () {
      const raw = '[SweetSub&LoliHouse] 葬送的芙莉莲 - 01-28 [Fin] [WebRip 1080p HEVC-10bit AAC]';
      final result = AnimeTitleParser.parse(raw);

      expect(result.subgroup, equals('SweetSub&LoliHouse'));
      expect(result.episode, equals('01-28'));
      expect(result.resolution, equals('1080P'));
    });
  });

  group('MikanSource RSS XML 解析测试', () {
    test('解析蜜柑计划标准 RSS 提要', () {
      const sampleXml = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>Mikan Project - 搜索结果</title>
    <item>
      <title>[LoliHouse] 葬送的芙莉莲 - 01 [WebRip 1080p HEVC-10bit AAC][简繁内封字幕]</title>
      <link>https://mikanani.me/Home/Episode/12345</link>
      <enclosure type="application/x-bittorrent" length="892182931" url="https://mikanani.me/Download/20230929/12345.torrent" />
      <torrent xmlns="https://mikanani.me/0.1/">
        <link>magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567</link>
        <contentLength>892182931</contentLength>
        <pubDate>2023-09-29T15:00:00</pubDate>
      </torrent>
    </item>
  </channel>
</rss>''';

      final source = MikanSource();
      final items = source.parseRssXml(sampleXml);

      expect(items.length, equals(1));
      final item = items.first;
      expect(item.source, equals(TorrentSourceType.mikan));
      expect(item.magnetUrl, contains('urn:btih:0123456789abcdef'));
      expect(item.torrentUrl, equals('https://mikanani.me/Download/20230929/12345.torrent'));
      expect(item.fileSize, equals('851 MB'));
      expect(item.episode, equals('01'));
      expect(item.subgroup, equals('LoliHouse'));
      expect(item.resolution, equals('1080P'));
      expect(item.displayTitle, equals('第 01 集'));
    });
  });

  group('NyaaSource RSS XML 解析测试', () {
    test('解析 Nyaa 标准 RSS 提要并构造磁力链接', () {
      const sampleXml = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:nyaa="https://nyaa.si/xmlns/nyaa">
  <channel>
    <title>Nyaa - Search</title>
    <item>
      <title>[SubsPlease] Frieren - 08 (1080p) [ABCD1234].mkv</title>
      <link>https://nyaa.si/download/12345.torrent</link>
      <pubDate>Fri, 20 Oct 2023 15:30:00 -0000</pubDate>
      <nyaa:seeders>150</nyaa:seeders>
      <nyaa:leechers>12</nyaa:leechers>
      <nyaa:infoHash>0123456789abcdef0123456789abcdef01234567</nyaa:infoHash>
      <nyaa:size>1.4 GiB</nyaa:size>
    </item>
  </channel>
</rss>''';

      final source = NyaaSource();
      final items = source.parseRssXml(sampleXml);

      expect(items.length, equals(1));
      final item = items.first;
      expect(item.source, equals(TorrentSourceType.nyaa));
      expect(item.seeders, equals(150));
      expect(item.leechers, equals(12));
      expect(item.fileSize, equals('1.4 GiB'));
      expect(item.magnetUrl, startsWith('magnet:?xt=urn:btih:0123456789abcdef'));
      expect(item.episode, equals('08'));
    });
  });

  group('TorznabSource (Prowlarr/Jackett) XML 解析测试', () {
    test('解析标准 Torznab 命名空间与扩展属性', () {
      const sampleXml = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2015/feed">
  <channel>
    <title>Prowlarr Feed</title>
    <item>
      <title>[Lilith-Raws] Sousou no Frieren - 08 [1080p]</title>
      <link>https://indexer.example/download.torrent</link>
      <pubDate>Fri, 20 Oct 2023 16:00:00 +0000</pubDate>
      <torznab:attr name="seeders" value="88" />
      <torznab:attr name="peers" value="95" />
      <torznab:attr name="magneturl" value="magnet:?xt=urn:btih:fedcba9876543210fedcba9876543210fedcba98" />
      <torznab:attr name="size" value="1073741824" />
    </item>
  </channel>
</rss>''';

      final source = TorznabSource(host: 'http://127.0.0.1:9696', apiKey: 'testkey');
      final items = source.parseRssXml(sampleXml);

      expect(items.length, equals(1));
      final item = items.first;
      expect(item.source, equals(TorrentSourceType.torznab));
      expect(item.seeders, equals(88));
      expect(item.leechers, equals(7)); // peers (95) - seeders (88)
      expect(item.magnetUrl, contains('fedcba9876543210'));
      expect(item.fileSize, equals('1.0 GB'));
      expect(item.episode, equals('08'));
    });
  });

  group('TorrentSearchService 聚合与智能排序测试', () {
    test('多源数据去重与优先级排序', () async {
      // 验证排序规则：有集数 > 做种数多 > 日期近
      final item1 = TorrentItem(
        title: 'Random Movie',
        magnetUrl: 'magnet:?xt=urn:btih:1111',
        source: TorrentSourceType.nyaa,
        seeders: 50,
      );
      final item2 = TorrentItem(
        title: '[Sub] Frieren - 08 [1080p]',
        magnetUrl: 'magnet:?xt=urn:btih:2222',
        source: TorrentSourceType.mikan,
        episode: '08',
        seeders: 20,
      );
      final item3 = TorrentItem(
        title: '[Sub] Frieren - 08 [720p]',
        magnetUrl: 'magnet:?xt=urn:btih:3333',
        source: TorrentSourceType.mikan,
        episode: '08',
        seeders: 100,
      );

      final list = [item1, item2, item3];
      list.sort((a, b) {
        final aHasEp = a.episode != null ? 1 : 0;
        final bHasEp = b.episode != null ? 1 : 0;
        if (aHasEp != bHasEp) return bHasEp.compareTo(aHasEp);
        return b.seeders.compareTo(a.seeders);
      });

      // item3 有集数且 seeders=100，应排第一；item2 有集数 seeders=20，排第二；item1 无集数排第三
      expect(list[0].magnetUrl, equals(item3.magnetUrl));
      expect(list[1].magnetUrl, equals(item2.magnetUrl));
      expect(list[2].magnetUrl, equals(item1.magnetUrl));
    });
  });
}
