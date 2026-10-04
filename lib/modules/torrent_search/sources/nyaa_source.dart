import 'package:dio/dio.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/parser/anime_title_parser.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

class NyaaSource implements TorrentSource {
  final Dio _dio;
  final String baseUrl;

  NyaaSource({
    Dio? dio,
    this.baseUrl = 'https://nyaa.si',
  }) : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ));

  @override
  String get name => 'Nyaa';

  @override
  TorrentSourceType get type => TorrentSourceType.nyaa;

  @override
  bool get enabled => true;

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];

    final url = '$baseUrl/?page=rss&q=${Uri.encodeComponent(trimmed)}&c=0_0&f=0';
    try {
      final response = await _dio.get<String>(url);
      final rawXml = response.data;
      if (rawXml == null || rawXml.isEmpty) {
        return [];
      }
      return parseRssXml(rawXml);
    } catch (e) {
      KazumiLogger().log(Level.warning, '[NyaaSource] 搜索失败: $e');
      return [];
    }
  }

  List<TorrentItem> parseRssXml(String xmlString) {
    try {
      final document = XmlDocument.parse(xmlString);
      final items = document.findAllElements('item');
      final result = <TorrentItem>[];

      for (final item in items) {
        final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
        if (title.isEmpty) continue;

        String? infoHash;
        String? sizeStr;
        int seeders = 0;
        int leechers = 0;

        for (final child in item.children.whereType<XmlElement>()) {
          final localName = child.name.local;
          if (localName == 'infoHash') {
            infoHash = child.innerText.trim();
          } else if (localName == 'size') {
            sizeStr = child.innerText.trim();
          } else if (localName == 'seeders') {
            seeders = int.tryParse(child.innerText.trim()) ?? 0;
          } else if (localName == 'leechers') {
            leechers = int.tryParse(child.innerText.trim()) ?? 0;
          }
        }

        final torrentUrl = item.findElements('link').firstOrNull?.innerText.trim();

        // 构造标准 Magnet 链接
        String magnetUrl = '';
        if (infoHash != null && infoHash.isNotEmpty) {
          magnetUrl = 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}';
        } else if (torrentUrl != null && torrentUrl.startsWith('magnet:')) {
          magnetUrl = torrentUrl;
        }

        if (magnetUrl.isEmpty && (torrentUrl == null || torrentUrl.isEmpty)) {
          continue;
        }

        final pubDateRaw = item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '';
        final parsedMeta = AnimeTitleParser.parse(title);

        result.add(TorrentItem(
          title: title,
          magnetUrl: magnetUrl.isNotEmpty ? magnetUrl : (torrentUrl ?? ''),
          torrentUrl: torrentUrl,
          fileSize: sizeStr ?? '',
          publishDate: _formatDate(pubDateRaw),
          source: TorrentSourceType.nyaa,
          seeders: seeders,
          leechers: leechers,
          cleanedTitle: parsedMeta.cleanedTitle,
          episode: parsedMeta.episode,
          subgroup: parsedMeta.subgroup,
          resolution: parsedMeta.resolution,
          language: parsedMeta.language,
        ));
      }

      return result;
    } catch (e) {
      KazumiLogger().log(Level.warning, '[NyaaSource] XML 解析失败: $e');
      return [];
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      // e.g. Fri, 20 Oct 2023 15:30:00 -0000
      final parts = raw.split(' ');
      if (parts.length >= 4) {
        return '${parts[3]}-${parts[2]}-${parts[1]}';
      }
    } catch (_) {}
    return raw;
  }
}
