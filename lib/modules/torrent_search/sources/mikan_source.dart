import 'package:dio/dio.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/parser/anime_title_parser.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:xml/xml.dart';

class MikanSource implements TorrentSource {
  final Dio _dio;
  final String baseUrl;

  MikanSource({
    Dio? dio,
    this.baseUrl = 'https://mikanani.me',
  }) : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ));

  @override
  String get name => '蜜柑计划';

  @override
  TorrentSourceType get type => TorrentSourceType.mikan;

  @override
  bool get enabled => true;

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return [];

    final url = '$baseUrl/RSS/Search?searchstr=${Uri.encodeComponent(trimmed)}';
    try {
      final response = await _dio.get<String>(url);
      final rawXml = response.data;
      if (rawXml == null || rawXml.isEmpty) {
        return [];
      }
      return parseRssXml(rawXml);
    } catch (e) {
      KazumiLogger().log(Level.warning, '[MikanSource] 搜索失败: $e');
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

        // 磁力链接通常在 <torrent> 命名空间下，或直接在 description/link 中
        String? magnetUrl;
        int? rawLength;

        // 尝试解析 mikanani.me/0.1/ 下的 <torrent>
        for (final child in item.children.whereType<XmlElement>()) {
          if (child.name.local == 'torrent') {
            for (final torrentChild in child.children.whereType<XmlElement>()) {
              if (torrentChild.name.local == 'link') {
                final linkText = torrentChild.innerText.trim();
                if (linkText.startsWith('magnet:')) {
                  magnetUrl = linkText;
                }
              } else if (torrentChild.name.local == 'contentLength') {
                rawLength = int.tryParse(torrentChild.innerText.trim());
              }
            }
          }
        }

        // enclosure 节点中可能包含 torrent 下载地址与长度
        String? torrentUrl;
        final enclosure = item.findElements('enclosure').firstOrNull;
        if (enclosure != null) {
          torrentUrl = enclosure.getAttribute('url');
          if (rawLength == null) {
            final lenStr = enclosure.getAttribute('length');
            if (lenStr != null) rawLength = int.tryParse(lenStr);
          }
        }

        // 如果没有找到 magnet，检查 description 或 link
        if (magnetUrl == null) {
          final link = item.findElements('link').firstOrNull?.innerText.trim();
          if (link != null && link.startsWith('magnet:')) {
            magnetUrl = link;
          }
        }

        // 如果依然没有 magnet 但有 torrentUrl，则备用
        if (magnetUrl == null && torrentUrl == null) {
          continue;
        }

        // 发布日期
        final pubDateRaw = item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '';
        final friendlyDate = _formatDate(pubDateRaw);
        final friendlySize = _formatSize(rawLength);

        // 智能清洗标题元数据
        final parsedMeta = AnimeTitleParser.parse(title);

        result.add(TorrentItem(
          title: title,
          magnetUrl: magnetUrl ?? torrentUrl ?? '',
          torrentUrl: torrentUrl,
          fileSize: friendlySize,
          sizeBytes: rawLength ?? 0,
          publishDate: friendlyDate,
          rawPublishDate: pubDateRaw,
          source: TorrentSourceType.mikan,
          cleanedTitle: parsedMeta.cleanedTitle,
          episode: parsedMeta.episode,
          subgroup: parsedMeta.subgroup,
          resolution: parsedMeta.resolution,
          language: parsedMeta.language,
          customCategory: TorrentCategory.video,
        ));
      }

      return result;
    } catch (e) {
      KazumiLogger().log(Level.warning, '[MikanSource] XML 解析失败: $e');
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
