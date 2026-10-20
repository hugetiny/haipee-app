import 'package:dio/dio.dart';
import 'package:kazumi/modules/cardigann/cardigann_torznab.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/parser/anime_title_parser.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

class TorznabSource implements TorrentSource {
  final Dio _dio;
  final String? customName;
  final String host;
  final String apiKey;
  final String category;

  TorznabSource({
    Dio? dio,
    this.customName,
    required this.host,
    required this.apiKey,
    this.category = '5000', // 5000 为 Newznab/Torznab 标准动漫分类代码
  }) : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  @override
  String get name => customName ?? 'Torznab (Prowlarr/Jackett)';

  @override
  TorrentSourceType get type => TorrentSourceType.torznab;

  @override
  bool get enabled => host.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    final trimmedHost = host.trim().replaceAll(RegExp(r'/+$'), '');
    final trimmedKey = apiKey.trim();
    if (!enabled) return [];

    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty) return [];

    final url = '$trimmedHost/api?t=search&q=${Uri.encodeComponent(cleanKeyword)}&apikey=$trimmedKey&cat=$category';
    try {
      final response = await _dio.get<String>(url);
      final rawXml = response.data;
      if (rawXml == null || rawXml.isEmpty) {
        return [];
      }
      return parseRssXml(rawXml);
    } catch (e) {
      KazumiLogger().log(Level.warning, '[TorznabSource] 搜索失败: $e');
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

        String? magnetUrl;
        int seeders = 0;
        int leechers = 0;
        int? rawSize;
        String? catStr;

        final catElem = item.findElements('category').firstOrNull?.innerText.trim();
        if (catElem != null && catElem.isNotEmpty) {
          catStr = catElem;
        }

        // 解析 torznab 扩展属性 <torznab:attr name="..." value="..."/>
        for (final child in item.children.whereType<XmlElement>()) {
          if (child.name.local == 'attr') {
            final attrName = child.getAttribute('name');
            final attrVal = child.getAttribute('value');
            if (attrName == 'magneturl' && attrVal != null) {
              magnetUrl = attrVal;
            } else if (attrName == 'seeders' && attrVal != null) {
              seeders = int.tryParse(attrVal) ?? 0;
            } else if (attrName == 'peers' && attrVal != null) {
              final peers = int.tryParse(attrVal) ?? 0;
              leechers = (peers > seeders) ? (peers - seeders) : 0;
            } else if (attrName == 'size' && attrVal != null) {
              rawSize = int.tryParse(attrVal);
            } else if (attrName == 'category' && attrVal != null && attrVal.isNotEmpty) {
              catStr = attrVal;
            }
          }
        }

        // enclosure 或 link
        String? torrentUrl;
        final enclosure = item.findElements('enclosure').firstOrNull;
        if (enclosure != null) {
          torrentUrl = enclosure.getAttribute('url');
          if (rawSize == null) {
            final lenStr = enclosure.getAttribute('length');
            if (lenStr != null) rawSize = int.tryParse(lenStr);
          }
        }

        if (magnetUrl == null) {
          final link = item.findElements('link').firstOrNull?.innerText.trim();
          if (link != null && link.startsWith('magnet:')) {
            magnetUrl = link;
          } else if (link != null && link.isNotEmpty) {
            torrentUrl = link;
          }
        }

        if (magnetUrl == null && (torrentUrl == null || torrentUrl.isEmpty)) {
          continue;
        }

        final sizeTag = item.findElements('size').firstOrNull?.innerText.trim();
        if (sizeTag != null && rawSize == null) {
          rawSize = int.tryParse(sizeTag);
        }

        final pubDateRaw = item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '';
        final parsedMeta = AnimeTitleParser.parse(title);

        TorrentCategory? customCat;
        if (catStr != null && catStr.isNotEmpty) {
          final catNum = int.tryParse(catStr);
          if (catNum != null) {
            final mapped = TorznabCategories.toTorrentCategory(catNum);
            if (mapped != TorrentCategory.all) {
              customCat = mapped;
            }
          }
        }

        result.add(TorrentItem(
          title: title,
          magnetUrl: magnetUrl ?? torrentUrl ?? '',
          torrentUrl: torrentUrl,
          fileSize: _formatSize(rawSize),
          sizeBytes: rawSize ?? 0,
          publishDate: _formatDate(pubDateRaw),
          rawPublishDate: pubDateRaw,
          source: TorrentSourceType.torznab,
          seeders: seeders,
          leechers: leechers,
          cleanedTitle: parsedMeta.cleanedTitle,
          episode: parsedMeta.episode,
          subgroup: parsedMeta.subgroup,
          resolution: parsedMeta.resolution,
          language: parsedMeta.language,
          customCategory: customCat,
        ));
      }

      return result;
    } catch (e) {
      KazumiLogger().log(Level.warning, '[TorznabSource] XML 解析失败: $e');
      return [];
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.tryParse(raw);
      if (date != null) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(0)} MB';
    } else {
      return '${(bytes / kb).toStringAsFixed(0)} KB';
    }
  }
}
