import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:kazumi/modules/cardigann/cardigann_torznab.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_filter_pipeline.dart';
import 'package:kazumi/modules/cardigann/engine/cardigann_template.dart';
import 'package:kazumi/modules/cardigann/engine/cloudflare_bypass.dart';
import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/parser/scene_release_parser.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

/// Cardigann query execution engine.
/// Executes search requests, bypasses anti-bot challenges, parses HTML rows and fields,
/// maps categories to Torznab standards, and emits structured TorrentItems.
class CardigannQueryExecutor {
  final Dio dio;
  final CloudflareBypassHandler cloudflareBypass;

  CardigannQueryExecutor({
    Dio? dio,
    CloudflareBypassHandler? cloudflareBypass,
  })  : dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              followRedirects: true,
              maxRedirects: 5,
              validateStatus: (status) =>
                  status != null && status < 600,
            )),
        cloudflareBypass = cloudflareBypass ?? CloudflareBypassHandler();

  /// Executes a search on a Cardigann tracker definition.
  Future<List<TorrentItem>> search(
    CardigannDefinition definition,
    String keyword, {
    int? torznabCategory,
    Map<String, String>? userConfig,
    String? customBaseUrl,
    bool throwOnError = false,
  }) async {
    final baseUrl = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim().replaceAll(RegExp(r'/+$'), '')
        : definition.defaultLink.replaceAll(RegExp(r'/+$'), '');

    if (baseUrl.isEmpty) {
      KazumiLogger().log(
        Level.warning,
        '[Cardigann] Indexer ${definition.name} has no valid base URL',
      );
      if (throwOnError) {
        throw StateError('规则未指定有效的站点链接 (BaseURL 为空)');
      }
      return [];
    }

    final config = <String, String>{};
    // Populate default settings first
    for (final s in definition.settings) {
      if (s.defaultValue != null) {
        config[s.name] = s.defaultValue.toString();
      }
    }
    // Merge user-provided settings
    if (userConfig != null) {
      config.addAll(userConfig);
    }

    // Determine category IDs for search
    final mappedCategories = <dynamic>[];
    if (torznabCategory != null) {
      for (final mapping in definition.caps.categorymappings) {
        if (mapping.cat == torznabCategory) {
          mappedCategories.add(mapping.id);
        }
      }
      if (mappedCategories.isEmpty) {
        mappedCategories.add(torznabCategory);
      }
    }

    // Select matching path
    final searchBlock = definition.search;
    CardigannPath selectedPath = searchBlock.paths.first;
    for (final p in searchBlock.paths) {
      if (torznabCategory != null && p.categories.isNotEmpty) {
        if (p.categories.contains(torznabCategory)) {
          selectedPath = p;
          break;
        }
      }
    }

    final queryContext = <String, String>{
      'Keywords': keyword,
      'Type': 'search',
    };

    // Render path template
    final renderedPath = CardigannTemplate.render(
      selectedPath.path,
      keyword: keyword,
      categories: mappedCategories,
      config: config,
      query: queryContext,
      urlEncodeKeywords: true,
    );

    // Build URL
    String targetUrl;
    if (renderedPath.startsWith('http://') ||
        renderedPath.startsWith('https://')) {
      targetUrl = renderedPath;
    } else {
      final cleanSub = renderedPath.startsWith('/')
          ? renderedPath
          : '/$renderedPath';
      targetUrl = '$baseUrl$cleanSub';
    }

    // Render inputs
    final mergedInputs = <String, dynamic>{};
    mergedInputs.addAll(searchBlock.inputs);
    mergedInputs.addAll(selectedPath.inputs);

    final queryParams = <String, dynamic>{};
    mergedInputs.forEach((key, val) {
      final rendered = CardigannTemplate.render(
        val.toString(),
        keyword: keyword,
        categories: mappedCategories,
        config: config,
        query: queryContext,
        urlEncodeKeywords: false,
      );
      if (rendered.isNotEmpty) {
        queryParams[key] = rendered;
      }
    });

    // Build headers
    final headers = <String, dynamic>{
      'User-Agent': Utils.getRandomUA(),
      'Referer': '$baseUrl/',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
    };

    // If tracker defines cookie setting or passkey
    if (config['cookie'] != null && config['cookie']!.isNotEmpty) {
      headers['Cookie'] = config['cookie']!;
    }

    selectedPath.headers.forEach((k, v) {
      headers[k] = v;
    });

    final options = Options(
      headers: headers,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 600,
    );

    cloudflareBypass.injectClearance(targetUrl, options);

    String? htmlContent;
    try {
      Response response;
      if (selectedPath.method == 'post') {
        response = await dio.post(
          targetUrl,
          data: queryParams,
          options: options,
        );
      } else {
        response = await dio.get(
          targetUrl,
          queryParameters: queryParams,
          options: options,
        );
      }

      // Check Cloudflare anti-bot challenge
      if (CloudflareBypassHandler.isCloudflareChallenge(response) ||
          definition.useWebview) {
        KazumiLogger().log(
          Level.warning,
          '[Cardigann] Cloudflare challenge encountered for ${definition.name}',
        );
        htmlContent = await cloudflareBypass.resolveChallengeWithWebview(targetUrl);
      } else if (response.statusCode != null && response.statusCode! >= 400) {
        KazumiLogger().log(
          Level.warning,
          '[Cardigann] ${definition.name} returned HTTP ${response.statusCode}',
        );
        if (throwOnError) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP ${response.statusCode}',
          );
        }
        return [];
      }

      htmlContent ??= response.data?.toString();
    } catch (e) {
      KazumiLogger().log(
        throwOnError ? Level.error : Level.warning,
        '[Cardigann] Request failed for ${definition.name}: $e',
      );
      if (throwOnError) {
        rethrow;
      }
      return [];
    }

    if (htmlContent == null || htmlContent.trim().isEmpty) {
      if (throwOnError) {
        throw StateError('目标站点返回内容为空 (HTTP 响应正文为空白)');
      }
      return [];
    }

    final trimmed = htmlContent.trim();
    if (selectedPath.responseType == 'json' ||
        (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return parseJsonResults(
        jsonContent: trimmed,
        definition: definition,
        baseUrl: baseUrl,
      );
    }

    // Parse HTML and extract rows
    return parseHtmlResults(
      htmlContent: htmlContent,
      definition: definition,
      baseUrl: baseUrl,
    );
  }

  static void _ensureAnnotated(Element element) {
    Element top = element;
    while (top.parent != null) {
      top = top.parent!;
    }
    if (top.attributes['data-annotated'] == null) {
      top.attributes['data-annotated'] = 'true';
      _annotateNthChild(top);
    }
  }

  static void _annotateNthChild(Element parent) {
    var index = 1;
    for (final child in parent.children) {
      child.attributes['data-nth-child'] = '$index';
      index++;
      _annotateNthChild(child);
    }
  }

  /// Parses HTML response body into structured TorrentItems based on Cardigann definition.
  List<TorrentItem> parseHtmlResults({
    required String htmlContent,
    required CardigannDefinition definition,
    required String baseUrl,
  }) {
    final doc = parse(htmlContent);
    final rootElement = doc.documentElement ?? doc.body ?? Element.tag('html');
    _ensureAnnotated(rootElement);
    final rowDef = definition.search.rows;
    final rowSelector = rowDef.selector;

    final rowElements = queryElementsWithSelector(
      rootElement,
      rowSelector,
      after: rowDef.after,
      before: rowDef.before,
    );

    final results = <TorrentItem>[];
    final fieldsDef = definition.search.fields;

    for (final row in rowElements) {
      try {
        final fieldValues = <String, String>{};

        fieldsDef.forEach((fieldName, field) {
          final val = _extractField(row, field);
          if (val != null) {
            fieldValues[fieldName] = val;
          }
        });

        final item = _buildTorrentItem(fieldValues, definition, baseUrl);
        if (item != null) {
          results.add(item);
        }
      } catch (e) {
        KazumiLogger().log(
          Level.warning,
          '[Cardigann] Failed to parse row in ${definition.name}: $e',
        );
      }
    }

    return results;
  }

  /// Parses JSON response body into structured TorrentItems based on Cardigann definition.
  List<TorrentItem> parseJsonResults({
    required String jsonContent,
    required CardigannDefinition definition,
    required String baseUrl,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (e) {
      KazumiLogger().log(
        Level.warning,
        '[Cardigann] Failed to parse JSON for ${definition.name}: $e',
      );
      return [];
    }

    final rowDef = definition.search.rows;
    final rowSelector = rowDef.selector.trim();
    List<dynamic> rowsList = [];

    if (rowSelector.isEmpty || rowSelector == r'$') {
      if (decoded is List) {
        rowsList = decoded;
      }
    } else {
      dynamic current = decoded;
      final cleanSelector = rowSelector.startsWith(r'$.')
          ? rowSelector.substring(2)
          : (rowSelector.startsWith(r'$') ? rowSelector.substring(1) : rowSelector);
      final parts = cleanSelector.split('.').where((p) => p.isNotEmpty).toList();
      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else {
          current = null;
          break;
        }
      }
      if (current is List) {
        rowsList = current;
      }
    }

    final results = <TorrentItem>[];
    final fieldsDef = definition.search.fields;

    for (final row in rowsList) {
      try {
        final fieldValues = <String, String>{};

        fieldsDef.forEach((fieldName, field) {
          final val = _extractJsonField(row, field, fieldValues);
          if (val != null) {
            fieldValues[fieldName] = val;
          }
        });

        final item = _buildTorrentItem(fieldValues, definition, baseUrl);
        if (item != null) {
          results.add(item);
        }
      } catch (e) {
        KazumiLogger().log(
          Level.warning,
          '[Cardigann] Failed to parse JSON row in ${definition.name}: $e',
        );
      }
    }

    return results;
  }

  String? _extractJsonField(
    dynamic row,
    CardigannField field,
    Map<String, String> currentFieldValues,
  ) {
    String? rawVal;
    if (field.text != null && field.text!.isNotEmpty) {
      rawVal = field.text;
    } else if (field.selector != null && field.selector!.isNotEmpty) {
      final sel = field.selector!.trim();
      final cleanSel = sel.startsWith(r'$.')
          ? sel.substring(2)
          : (sel.startsWith(r'$') ? sel.substring(1) : sel);
      final parts = cleanSel.split('.').where((p) => p.isNotEmpty).toList();
      dynamic current = row;
      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else if (current is List) {
          final idx = int.tryParse(part);
          if (idx != null && idx >= 0 && idx < current.length) {
            current = current[idx];
          } else {
            current = null;
            break;
          }
        } else {
          current = null;
          break;
        }
      }
      if (current != null) {
        rawVal = current.toString();
      }
    }

    rawVal ??= field.defaultVal;
    if (rawVal == null) return null;

    if (field.filters.isNotEmpty) {
      return CardigannFilterPipeline.apply(
        rawVal,
        field.filters,
        contextVariables: currentFieldValues,
      );
    }
    return rawVal;
  }

  TorrentItem? _buildTorrentItem(
    Map<String, String> fieldValues,
    CardigannDefinition definition,
    String baseUrl,
  ) {
    // Title is required
    final title = fieldValues['title']?.trim() ?? '';
    if (title.isEmpty) return null;

    // Magnet, Download, Details
    var magnet = fieldValues['magnet']?.trim() ?? '';
    var downloadUrl = fieldValues['download']?.trim() ?? '';
    var detailsUrl = fieldValues['details']?.trim() ?? '';
    var commentsUrl = fieldValues['comments']?.trim() ?? '';

    // If download contains magnet link
    if (downloadUrl.startsWith('magnet:?')) {
      if (magnet.isEmpty) magnet = downloadUrl;
      downloadUrl = '';
    }

    // If magnet is missing and download is missing, check details
    if (magnet.isEmpty && downloadUrl.isEmpty && detailsUrl.isEmpty) {
      return null;
    }

    // Resolve relative URLs against baseUrl
    if (downloadUrl.isNotEmpty &&
        !downloadUrl.startsWith('http://') &&
        !downloadUrl.startsWith('https://')) {
      downloadUrl = downloadUrl.startsWith('/')
          ? '$baseUrl$downloadUrl'
          : '$baseUrl/$downloadUrl';
    }

    if (detailsUrl.isNotEmpty &&
        !detailsUrl.startsWith('http://') &&
        !detailsUrl.startsWith('https://')) {
      detailsUrl = detailsUrl.startsWith('/')
          ? '$baseUrl$detailsUrl'
          : '$baseUrl/$detailsUrl';
    }

    if (commentsUrl.isNotEmpty &&
        !commentsUrl.startsWith('http://') &&
        !commentsUrl.startsWith('https://')) {
      commentsUrl = commentsUrl.startsWith('/')
          ? '$baseUrl$commentsUrl'
          : '$baseUrl/$commentsUrl';
    }

    final effectivePageUrl = detailsUrl.isNotEmpty
        ? detailsUrl
        : (commentsUrl.isNotEmpty ? commentsUrl : null);

    // Size
    final rawSize = fieldValues['size'] ?? '';
    final sizeBytes = CardigannFilterPipeline.parseHumanSizeToBytes(rawSize);
    final fileSizeStr = rawSize.isNotEmpty
        ? rawSize
        : (sizeBytes > 0 ? CardigannFilterPipeline.formatBytes(sizeBytes) : '');

    // Date
    final rawDate = fieldValues['date'] ?? '';
    DateTime? rawPublishDate;
    String publishDateStr = rawDate;
    if (rawDate.isNotEmpty) {
      final parsedIso = CardigannFilterPipeline.parseDateString(rawDate);
      rawPublishDate = DateTime.tryParse(parsedIso);
      if (rawPublishDate != null) {
        publishDateStr =
            '${rawPublishDate.year}-${rawPublishDate.month.toString().padLeft(2, '0')}-${rawPublishDate.day.toString().padLeft(2, '0')}';
      }
    }

    // Seeders & Leechers
    final seeders = int.tryParse(fieldValues['seeders']?.replaceAll(',', '').trim() ?? '') ?? 0;
    final leechers = int.tryParse(fieldValues['leechers']?.replaceAll(',', '').trim() ?? '') ?? 0;

    // Freeleech detection (downloadvolumefactor: 0)
    final dlf = fieldValues['downloadvolumefactor']?.trim() ?? '';
    final isFreeleech = dlf == '0' || dlf == '0.0';

    // Category mapping: yml 规则未定义分类或站点未映射分类一律显式归入全部 (TorrentCategory.all)
    final rawCat = fieldValues['category'] ?? '';
    final torznabCat = definition.mapToTorznabCategory(rawCat);
    final mappedCategory = torznabCat != null
        ? TorznabCategories.toTorrentCategory(torznabCat)
        : TorrentCategory.all;

    // Scene metadata parsing
    final sceneInfo = SceneReleaseParser.parse(title);

    return TorrentItem(
      title: title,
      magnetUrl: magnet,
      torrentUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
      pageUrl: effectivePageUrl,
      fileSize: fileSizeStr,
      sizeBytes: sizeBytes,
      publishDate: publishDateStr,
      rawPublishDate: rawPublishDate?.toIso8601String(),
      source: TorrentSourceType.cardigann,
      indexerName: definition.name,
      indexerId: definition.id,
      seeders: seeders,
      leechers: leechers,
      cleanedTitle: sceneInfo.cleanTitle,
      episode: sceneInfo.episode,
      season: sceneInfo.season,
      year: sceneInfo.year,
      subgroup: sceneInfo.releaseGroup,
      resolution: sceneInfo.resolution,
      mediaSource: sceneInfo.source,
      codec: sceneInfo.codec,
      audio: sceneInfo.audio,
      isCam: sceneInfo.isCam,
      isFreeleech: isFreeleech,
      customCategory: mappedCategory,
    );
  }

  /// Extracts the string value for a single field from an HTML row element.
  String? _extractField(Element row, CardigannField field) {
    // 1. Evaluate case conditions if present
    if (field.caseConditions != null && field.caseConditions!.isNotEmpty) {
      for (final entry in field.caseConditions!.entries) {
        final conditionSelector = entry.key;
        if (conditionSelector == '*') {
          continue; // Default fallback
        }
        if (_elementMatchesSelector(row, conditionSelector)) {
          final res = entry.value?.toString() ?? '';
          return CardigannFilterPipeline.apply(res, field.filters);
        }
      }
      if (field.caseConditions!.containsKey('*')) {
        final fallback = field.caseConditions!['*']?.toString() ?? '';
        return CardigannFilterPipeline.apply(fallback, field.filters);
      }
    }

    // 2. Static text
    if (field.text != null && field.selector == null) {
      return CardigannFilterPipeline.apply(field.text!, field.filters);
    }

    // 3. Selector based extraction
    Element? targetElement;
    if (field.selector != null && field.selector!.isNotEmpty) {
      final list = queryElementsWithSelector(row, field.selector!);
      if (list.isNotEmpty) {
        targetElement = list.first;
      }
    } else {
      targetElement = row;
    }

    if (targetElement == null) {
      if (field.defaultVal != null) {
        return CardigannFilterPipeline.apply(field.defaultVal!, field.filters);
      }
      return field.optional ? null : '';
    }

    String rawText;
    if (field.attribute != null && field.attribute!.isNotEmpty) {
      rawText = targetElement.attributes[field.attribute!] ?? '';
    } else {
      rawText = targetElement.text.trim();
    }

    if (rawText.isEmpty && field.defaultVal != null) {
      rawText = field.defaultVal!;
    }

    return CardigannFilterPipeline.apply(rawText, field.filters);
  }

  /// Evaluates whether an element matches a selector or condition (e.g. "tr.success" or class names).
  bool _elementMatchesSelector(Element element, String selector) {
    final clean = selector.trim();
    if (clean.startsWith('.')) {
      final cls = clean.substring(1);
      return element.classes.contains(cls);
    }
    if (clean.contains('.')) {
      final parts = clean.split('.');
      final tag = parts[0];
      final cls = parts[1];
      if (tag.isNotEmpty && element.localName?.toLowerCase() != tag.toLowerCase()) {
        return false;
      }
      return element.classes.contains(cls);
    }
    if (clean.toLowerCase() == element.localName?.toLowerCase()) {
      return true;
    }
    // Try querySelector match
    try {
      final parent = element.parent;
      if (parent != null) {
        _ensureAnnotated(parent);
        final processed = _preprocessSelector(clean);
        return parent.querySelectorAll(processed).contains(element);
      }
    } catch (_) {}
    return false;
  }

  static String _preprocessSelector(String selector) {
    var clean = selector.trim();
    if (clean.contains(':nth-child(')) {
      clean = clean.replaceAllMapped(
        RegExp(r':nth-child\((\d+)\)'),
        (match) => '[data-nth-child="${match.group(1)}"]',
      );
    }
    return clean;
  }

  /// Executes selector queries supporting CSS selectors, CSS `:has()` pseudo-classes, and XPath.
  static List<Element> queryElementsWithSelector(
    Element root,
    String selector, {
    int? after,
    int? before,
  }) {
    final clean = selector.trim();
    if (clean.isEmpty) return [];

    _ensureAnnotated(root);
    List<Element> matched = [];

    // XPath support
    if (clean.startsWith('xpath:') || clean.startsWith('/') || clean.startsWith('./')) {
      try {
        final xpathQuery = clean.startsWith('xpath:') ? clean.substring(6) : clean;
        final nodes = root.queryXPath(xpathQuery).nodes;
        for (final n in nodes) {
          if (n.node is Element) {
            matched.add(n.node as Element);
          }
        }
      } catch (_) {}
    } else if (clean.contains(':has(')) {
      // CSS :has() support
      final hasRegex = RegExp(r'^(.*?):has\((.*?)\)$');
      final match = hasRegex.firstMatch(clean);
      if (match != null) {
        final baseSelector = _preprocessSelector(match.group(1)!.trim());
        final insideSelector = _preprocessSelector(match.group(2)!.trim());

        try {
          final candidates = baseSelector.isEmpty
              ? root.children
              : root.querySelectorAll(baseSelector);
          matched = candidates.where((elem) {
            try {
              return elem.querySelector(insideSelector) != null;
            } catch (_) {
              return false;
            }
          }).toList();
        } catch (_) {}
      }
    } else {
      // Standard CSS selector
      try {
        final processed = _preprocessSelector(clean);
        matched = root.querySelectorAll(processed);
      } catch (e) {
        KazumiLogger().log(
          Level.warning,
          '[Cardigann] querySelectorAll error with "$clean": $e',
        );
      }
    }

    // Apply 'after' (skip N items)
    if (after != null && after > 0) {
      if (after < matched.length) {
        matched = matched.sublist(after);
      } else {
        return [];
      }
    }

    // Apply 'before' (take N items)
    if (before != null && before > 0) {
      if (before < matched.length) {
        matched = matched.sublist(0, before);
      }
    }

    return matched;
  }
}
