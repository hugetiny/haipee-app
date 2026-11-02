import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/cardigann_torznab.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/sources/nyaa_source.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';

void main() {
  group('Cardigann Category Unification & Strict Mapping Tests', () {
    test('无分类或YAML未映射项目一律归入全部 (TorrentCategory.all)，彻底摒弃标题关键词hack', () {
      // 包含昔日触发关键词的非游戏资源：漫画、电视剧、纪录片
      final mangaItem = const TorrentItem(
        title: '三国志 全60卷 [横山光辉]',
        magnetUrl: 'magnet:?xt=urn:btih:manga_sanguo',
        source: TorrentSourceType.torrentscsv,
      );
      expect(mangaItem.category, equals(TorrentCategory.all));
      expect(mangaItem.isGame, isFalse);
      expect(mangaItem.isVideo, isFalse);

      final episodeItem = const TorrentItem(
        title: '三国志 第 E01 集 1080p',
        magnetUrl: 'magnet:?xt=urn:btih:tv_sanguo',
        source: TorrentSourceType.torrentscsv,
      );
      expect(episodeItem.category, equals(TorrentCategory.all));
      expect(episodeItem.isGame, isFalse);

      final documentaryItem = const TorrentItem(
        title: '歴史秘話ヒストリア「徹底解明！三国志」',
        magnetUrl: 'magnet:?xt=urn:btih:doc_sanguo',
        source: TorrentSourceType.cardigann,
      );
      expect(documentaryItem.category, equals(TorrentCategory.all));
      expect(documentaryItem.isGame, isFalse);

      // 即使是含有单机/豪华版/DLC字样，若来源无分类定义，也归入全部，不擅自猜入游戏
      final unclassifiedGameTitle = const TorrentItem(
        title: '三国志14 威力加强版 豪华版 免安装绿色版',
        magnetUrl: 'magnet:?xt=urn:btih:game_sanguo',
        source: TorrentSourceType.torrentscsv,
      );
      expect(unclassifiedGameTitle.category, equals(TorrentCategory.all));
      expect(unclassifiedGameTitle.isGame, isFalse);
      expect(unclassifiedGameTitle.canStreamVideo, isFalse);

      // 纯音频文件在无 YAML 分类时由解析器赋予 TorrentCategory.all，严格归入全部，绝不猜入音频子分类，但允许边下边听
      final unclassifiedAudio = const TorrentItem(
        title: '三国志 电视原声音乐大碟.flac',
        magnetUrl: 'magnet:?xt=urn:btih:ost_sanguo',
        source: TorrentSourceType.torrentscsv,
      );
      expect(unclassifiedAudio.category, equals(TorrentCategory.all));
      expect(unclassifiedAudio.isAudio, isFalse);
      expect(unclassifiedAudio.canStreamAudio, isTrue);
      expect(unclassifiedAudio.canStreamVideo, isFalse);

      // 视频剧集在无 YAML 分类时，严格归入全部 (TorrentCategory.all)，绝不猜入视频子分类，但允许边下边播
      expect(episodeItem.category, equals(TorrentCategory.all));
      expect(episodeItem.isVideo, isFalse);
      expect(episodeItem.canStreamVideo, isTrue);
    });

    test('显式 customCategory 严格生效，忠实遵循 Cardigann YAML 映射', () {
      final realGameItem = const TorrentItem(
        title: '三国志14 威力加强版',
        magnetUrl: 'magnet:?xt=urn:btih:game_real',
        source: TorrentSourceType.cardigann,
        customCategory: TorrentCategory.game,
      );
      expect(realGameItem.category, equals(TorrentCategory.game));
      expect(realGameItem.isGame, isTrue);

      final realVideoItem = const TorrentItem(
        title: '三国志演义 1994',
        magnetUrl: 'magnet:?xt=urn:btih:tv_real',
        source: TorrentSourceType.cardigann,
        customCategory: TorrentCategory.video,
      );
      expect(realVideoItem.category, equals(TorrentCategory.video));
      expect(realVideoItem.isVideo, isTrue);
    });

    test('Torznab 标准分类映射函数正确性 (toTorrentCategory & fromTorrentCategory)', () {
      // 游戏分类：4050 及 10000..10999 (主机平台)
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.pcGames), equals(TorrentCategory.game));
      expect(TorznabCategories.toTorrentCategory(10000), equals(TorrentCategory.game));
      expect(TorznabCategories.toTorrentCategory(10100), equals(TorrentCategory.game));

      // 音频分类：1000..1999 (严防 1010 等音频子分类被误标为游戏)
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.audio), equals(TorrentCategory.audio));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.audioMp3), equals(TorrentCategory.audio));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.audioLossless), equals(TorrentCategory.audio));

      // 视频分类：2000..2999 及 5000..5999
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.movies), equals(TorrentCategory.video));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.tv), equals(TorrentCategory.video));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.tvAnime), equals(TorrentCategory.video));

      // 书籍/文档：3000..3999
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.books), equals(TorrentCategory.document));

      // 软件：4000..4999 (非 4050)
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.pc), equals(TorrentCategory.software));
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.pcIso), equals(TorrentCategory.software));

      // 其它 (7000 / 8000 / 未知分类) -> 一律归入全部 (TorrentCategory.all)
      expect(TorznabCategories.toTorrentCategory(TorznabCategories.other), equals(TorrentCategory.all));
      expect(TorznabCategories.toTorrentCategory(8000), equals(TorrentCategory.all));
      expect(TorznabCategories.toTorrentCategory(0), equals(TorrentCategory.all));

      // 反向映射：游戏分类严禁夹带 1010, 1020 等音频分类
      final gameSearchCats = TorznabCategories.fromTorrentCategory(TorrentCategory.game);
      expect(gameSearchCats, contains(TorznabCategories.pcGames));
      expect(gameSearchCats.contains(TorznabCategories.audioMp3), isFalse);
      expect(gameSearchCats.contains(TorznabCategories.audioLossless), isFalse);
    });

    test('Nyaa.si 官方分类体系映射 (1_ 视频, 2_ 音频, 3_ 文档, 4_ 影视, 6_ 软件/游戏)', () {
      const sampleNyaaHtml = '''
<!DOCTYPE html>
<html>
<body>
  <table class="torrent-list">
    <tbody>
      <tr>
        <td><a href="/?c=3_3"><img alt="Literature - Raw" /></a></td>
        <td><a href="/view/1" title="三国志 全60卷">三国志 全60卷</a></td>
        <td><a href="magnet:?xt=urn:btih:manga">Magnet</a></td>
        <td>1.9 GiB</td>
        <td>2019-10-25</td>
        <td>6</td>
        <td>0</td>
      </tr>
      <tr>
        <td><a href="/?c=4_4"><img alt="Live Action - Raw" /></a></td>
        <td><a href="/view/2" title="三国志演義 第01回">三国志演義 第01回</a></td>
        <td><a href="magnet:?xt=urn:btih:tv">Magnet</a></td>
        <td>21.0 GiB</td>
        <td>2022-05-29</td>
        <td>1</td>
        <td>1</td>
      </tr>
      <tr>
        <td><a href="/?c=6_2"><img alt="Software - Games" /></a></td>
        <td><a href="/view/3" title="Romance of the Three Kingdoms XIV">Romance of the Three Kingdoms XIV</a></td>
        <td><a href="magnet:?xt=urn:btih:game">Magnet</a></td>
        <td>15.0 GiB</td>
        <td>2020-01-16</td>
        <td>10</td>
        <td>2</td>
      </tr>
      <tr>
        <td><a href="/?c=2_1"><img alt="Audio - Lossless" /></a></td>
        <td><a href="/view/4" title="三国志 OST FLAC">三国志 OST FLAC</a></td>
        <td><a href="magnet:?xt=urn:btih:ost">Magnet</a></td>
        <td>500 MiB</td>
        <td>2021-02-14</td>
        <td>3</td>
        <td>0</td>
      </tr>
    </tbody>
  </table>
</body>
</html>
''';

      final nyaaYaml = '''
id: nyaasi
name: Nyaa.si
caps:
  categorymappings:
    - {id: 1_0, cat: 5070, desc: "Anime"}
    - {id: 2_1, cat: 1000, desc: "Audio - Lossless"}
    - {id: 3_3, cat: 3000, desc: "Literature - Raw"}
    - {id: 4_4, cat: 5000, desc: "Live Action - Raw"}
    - {id: 6_2, cat: 4050, desc: "Software - Games"}
search:
  paths:
    - path: /
  rows:
    selector: table.torrent-list > tbody > tr
  fields:
    category:
      selector: td:nth-child(1) a
      attribute: href
      filters:
        - name: querystring
          args: c
    title:
      selector: td:nth-child(2) a
      attribute: title
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
''';

      final def = CardigannParser.parseYaml(nyaaYaml);
      final executor = CardigannQueryExecutor();
      final results = executor.parseHtmlResults(
        htmlContent: sampleNyaaHtml,
        definition: def,
        baseUrl: 'https://nyaa.si',
      );

      expect(results.length, equals(4));

      // 条目 1: 三国志 全60卷 应为书籍/文档 (3000 -> TorrentCategory.document)
      expect(results[0].title, equals('三国志 全60卷'));
      expect(results[0].category, equals(TorrentCategory.document));
      expect(results[0].isGame, isFalse);

      // 条目 2: 三国志演义 应为影视/视频 (5000 -> TorrentCategory.video)
      expect(results[1].title, equals('三国志演義 第01回'));
      expect(results[1].category, equals(TorrentCategory.video));
      expect(results[1].isGame, isFalse);

      // 条目 3: 三国志14 游戏 应为游戏 (4050 -> TorrentCategory.game)
      expect(results[2].title, equals('Romance of the Three Kingdoms XIV'));
      expect(results[2].category, equals(TorrentCategory.game));
      expect(results[2].isGame, isTrue);

      // 条目 4: 原声大碟 应为音频 (1000 -> TorrentCategory.audio)
      expect(results[3].title, equals('三国志 OST FLAC'));
      expect(results[3].category, equals(TorrentCategory.audio));
    });

    test('NyaaSource RSS 解析准确映射 2_ 音频, 3_ 文档, 4_ 视频, 6_2 游戏', () {
      const nyaaRssXml = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:nyaa="https://nyaa.si/xmlns/nyaa">
  <channel>
    <title>Nyaa</title>
    <item>
      <title>三国志 全60卷</title>
      <link>magnet:?xt=urn:btih:sanguomanga</link>
      <nyaa:categoryId>3_3</nyaa:categoryId>
      <nyaa:size>1.9 GiB</nyaa:size>
    </item>
    <item>
      <title>三国志演义 第01集</title>
      <link>magnet:?xt=urn:btih:sanguotv</link>
      <nyaa:categoryId>4_1</nyaa:categoryId>
      <nyaa:size>1.4 GiB</nyaa:size>
    </item>
    <item>
      <title>三国志14 游戏本体</title>
      <link>magnet:?xt=urn:btih:sanguogame</link>
      <nyaa:categoryId>6_2</nyaa:categoryId>
      <nyaa:size>15 GiB</nyaa:size>
    </item>
  </channel>
</rss>''';

      final source = NyaaSource();
      final items = source.parseRssXml(nyaaRssXml);

      expect(items.length, equals(3));
      expect(items[0].category, equals(TorrentCategory.document));
      expect(items[0].isGame, isFalse);

      expect(items[1].category, equals(TorrentCategory.video));
      expect(items[1].isGame, isFalse);

      expect(items[2].category, equals(TorrentCategory.game));
      expect(items[2].isGame, isTrue);
    });

    test('CardigannDefinition 支持 caps.categories 字典映射 (ACG.RIP & EZTV)', () {
      const acgripYaml = '''
id: acgrip
name: ACG.RIP
caps:
  categories:
    1: TV
search:
  paths:
    - path: /
  rows:
    selector: tbody tr
  fields:
    category:
      text: 1
    title:
      selector: td.title a
    magnet:
      selector: td.action a
      attribute: href
''';

      final def = CardigannParser.parseYaml(acgripYaml);
      expect(def.caps.categorymappings.isNotEmpty, isTrue);
      final torznabCat = def.mapToTorznabCategory('1');
      expect(torznabCat, equals(TorznabCategories.tv)); // 5000
      expect(TorznabCategories.toTorrentCategory(torznabCat!), equals(TorrentCategory.video));
    });

    test('TorrentSearchState 过滤规则：无分类项目仅在全部标签下展示，不泄漏至游戏或视频子分类', () {
      final unclassifiedItem = const TorrentItem(
        title: '三国志 全60卷',
        magnetUrl: 'magnet:?xt=urn:btih:1',
        source: TorrentSourceType.torrentscsv,
      );
      final gameItem = const TorrentItem(
        title: '三国志14',
        magnetUrl: 'magnet:?xt=urn:btih:2',
        source: TorrentSourceType.cardigann,
        customCategory: TorrentCategory.game,
      );
      final videoItem = const TorrentItem(
        title: '三国志演义',
        magnetUrl: 'magnet:?xt=urn:btih:3',
        source: TorrentSourceType.cardigann,
        customCategory: TorrentCategory.video,
      );

      final state = TorrentSearchState(
        items: [unclassifiedItem, gameItem, videoItem],
        categoryFilter: TorrentCategory.all,
      );

      // 全部筛选：包含所有 3 项
      expect(state.filteredItems.length, equals(3));

      // 游戏筛选：仅包含真正归类为游戏的项，未分类项绝不混入
      final gameState = state.copyWith(categoryFilter: TorrentCategory.game);
      expect(gameState.filteredItems.length, equals(1));
      expect(gameState.filteredItems.first.title, equals('三国志14'));

      // 视频筛选：仅包含真正归类为视频的项
      final videoState = state.copyWith(categoryFilter: TorrentCategory.video);
      expect(videoState.filteredItems.length, equals(1));
      expect(videoState.filteredItems.first.title, equals('三国志演义'));
    });
  });
}
