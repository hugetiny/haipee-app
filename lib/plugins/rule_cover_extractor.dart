import 'package:html/dom.dart' as dom;
import 'package:xpath_selector/xpath_selector.dart';

/// 强韧媒体封面提取器 (Resilient Media Cover Extractor)
/// 负责从异构规则源（Haipee/Kazumi XPath DOM、MacCMS JSON、TVBox API）中提取并规范化封面地址，
/// 并提供跨源同名封面协同匹配（Cross-Source Cover Synergy）的标题归一化能力。
class RuleCoverExtractor {
  const RuleCoverExtractor._();

  /// 按优先级排列的懒加载与自定义图片属性列表
  static const List<String> _lazyImageAttributes = [
    'data-original',
    'data-src',
    'data-lazy-src',
    'data-lazy',
    'data-echo',
    'data-cover',
    'data-bg',
    'data-url',
    'data-cfsrc',
    'data-poster',
  ];

  /// JSON API / MacCMS 常见封面字段名优先级列表
  static const List<String> _jsonCoverKeys = [
    'vod_pic',
    'pic',
    'cover',
    'img',
    'vod_pic_thumb',
    'vod_pic_slide',
    'thumb',
    'poster',
    'thumbnail',
    'image',
  ];

  /// 匹配 CSS style="background-image: url(...)" 或 background: url(...)
  static final RegExp _cssUrlRegExp = RegExp(
    r"""url\(\s*['"]?([^'")\s]+)['"]?\s*\)""",
    caseSensitive: false,
  );

  /// 判断给定 URL 是否为无效的 1x1 占位图、空白图或懒加载 loading 占位图
  static bool isPlaceholderImageUrl(String? rawUrl) {
    if (rawUrl == null) return true;
    final clean = rawUrl.trim().toLowerCase();
    if (clean.isEmpty) return true;
    if (clean.startsWith('data:image/') || clean.startsWith('javascript:') || clean.startsWith('about:')) {
      return true;
    }
    // 常见动漫/影视站懒加载占位图特征
    if (clean.contains('137860000e3053288f11f') || // AGE 等站西瓜占位图
        clean.contains('/loading.') ||
        clean.contains('/blank.') ||
        clean.contains('/none.') ||
        clean.contains('/nopic') ||
        clean.contains('lazyload.') ||
        clean.contains('default_pic') ||
        clean.contains('placeholder.') ||
        clean.endsWith('/load.gif') ||
        clean.endsWith('/loading.gif') ||
        clean.endsWith('/grey.gif') ||
        clean.endsWith('/pixel.gif') ||
        clean.endsWith('/spacer.gif')) {
      return true;
    }
    return false;
  }

  /// 从 XPath 节点中提取封面 URL（支持显式 searchPic XPath 与启发式多属性 DOM 兜底）
  static String extractFromXPathNode(
    XPathNode element, {
    String searchPic = '',
    String baseUrl = '',
  }) {
    String candidate = '';

    // 1. 优先使用规则显式配置的 searchPic XPath
    final trimmedSearchPic = searchPic.trim();
    if (trimmedSearchPic.isNotEmpty) {
      try {
        final queryResult = element.queryXPath(trimmedSearchPic);
        // 支持直接提取属性（如 .//img/@data-original 或 .//a/@data-original）
        final attrVal = queryResult.attr?.trim() ?? '';
        if (attrVal.isNotEmpty && !isPlaceholderImageUrl(attrVal)) {
          candidate = attrVal;
        }
        // 支持提取节点
        if (candidate.isEmpty && queryResult.node != null) {
          candidate = _extractFromSingleXPathNode(queryResult.node!);
        }
      } catch (_) {}
    }

    // 2. 启发式多属性 DOM 自动兜底（兼容无 searchPic 的原版 Kazumi / Haipee 规则）
    if (candidate.isEmpty) {
      final rawNode = element.node;
      if (rawNode is dom.Element) {
        candidate = extractFromDomElement(rawNode);
      } else {
        try {
          final fallbackImg = element.queryXPath('.//img').node;
          if (fallbackImg != null) {
            candidate = _extractFromSingleXPathNode(fallbackImg);
          }
        } catch (_) {}
      }
    }

    return normalizeCoverUrl(candidate, baseUrl: baseUrl);
  }

  /// 从 HTML DOM Element 中执行多属性优先级启发式封面提取
  static String extractFromDomElement(dom.Element root) {
    // 2.1 检查节点自身及所有后代 <img> 标签（优先读取懒加载属性，最后读取非占位 src）
    final imgElements = <dom.Element>[
      if (root.localName == 'img') root,
      ...root.querySelectorAll('img'),
    ];
    for (final img in imgElements) {
      final fromImg = _extractAttributesFromElement(img, includeSrc: true);
      if (fromImg.isNotEmpty) return fromImg;
    }

    // 2.2 检查节点自身及所有后代元素上的懒加载属性（如 <a class="lazyload" data-original="..."> 或 <div class="hl-lazy" data-original="...">）
    final allElements = <dom.Element>[root, ...root.querySelectorAll('*')];
    for (final el in allElements) {
      final fromLazyAttr = _extractAttributesFromElement(el, includeSrc: false);
      if (fromLazyAttr.isNotEmpty) return fromLazyAttr;
    }

    // 2.3 检查内联 CSS style="background-image: url(...)"
    for (final el in allElements) {
      final fromStyle = _extractFromStyleAttribute(el.attributes['style']);
      if (fromStyle.isNotEmpty) return fromStyle;
    }

    // 2.4 若 searchList XPath 指向了卡片内部的子容器（如文字区 div），安全向上回溯一层单卡片父节点
    final parent = root.parent;
    if (parent != null && _isSafeSingleCardParent(root, parent)) {
      for (final img in parent.querySelectorAll('img')) {
        final fromImg = _extractAttributesFromElement(img, includeSrc: true);
        if (fromImg.isNotEmpty) return fromImg;
      }
      for (final el in [parent, ...parent.querySelectorAll('*')]) {
        final fromLazy = _extractAttributesFromElement(el, includeSrc: false);
        if (fromLazy.isNotEmpty) return fromLazy;
        final fromStyle = _extractFromStyleAttribute(el.attributes['style']);
        if (fromStyle.isNotEmpty) return fromStyle;
      }
    }

    return '';
  }

  /// 从 JSON Map（MacCMS / TVBox / 通用 API）中提取并规范化封面地址
  static String extractFromJsonMap(
    Map<dynamic, dynamic> item, {
    String picKey = '',
    String baseUrl = '',
  }) {
    final cleanKey = picKey.trim().replaceAll(RegExp(r'^\$\.'), '');
    final keysToTry = <String>[
      if (cleanKey.isNotEmpty) cleanKey,
      ..._jsonCoverKeys,
    ];

    for (final key in keysToTry) {
      final val = item[key]?.toString().trim() ?? '';
      if (val.isNotEmpty && !isPlaceholderImageUrl(val)) {
        final normalized = normalizeCoverUrl(val, baseUrl: baseUrl);
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  /// 规范化封面 URL：
  /// - 解码 HTML 实体 (&amp; -> &)
  /// - 补全协议相对路径 (// -> https://)
  /// - 保持原有的 http:// 或 https:// 协议（严禁盲目强转 http:// 为 https:// 导致无 SSL 采集站握手崩溃）
  /// - 补全站点相对路径
  static String normalizeCoverUrl(String? rawUrl, {String baseUrl = ''}) {
    if (rawUrl == null) return '';
    String url = rawUrl
        .trim()
        .replaceAll('&amp;', '&')
        .replaceAll(r'\/', '/');

    // 若包含在 url(...) 中，剥离外层
    final cssMatch = _cssUrlRegExp.firstMatch(url);
    if (cssMatch != null && cssMatch.group(1) != null) {
      url = cssMatch.group(1)!.trim();
    }

    if (isPlaceholderImageUrl(url)) return '';

    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final cleanBase = baseUrl.trim();
    if (cleanBase.isEmpty) return url;

    final normalizedBase = cleanBase.endsWith('/')
        ? cleanBase.substring(0, cleanBase.length - 1)
        : cleanBase;
    final normalizedPath = url.startsWith('/') ? url : '/$url';
    return '$normalizedBase$normalizedPath';
  }

  /// 将影视/番剧标题归一化，用于跨源同名封面协同匹配（Cross-Source Cover Synergy）
  static String normalizeTitleForSynergy(String rawTitle) {
    if (rawTitle.isEmpty) return '';
    String cleaned = rawTitle.toLowerCase().trim();
    // 移除【...】、[...]、(...)、（...）中的画质/字幕组/更新状态标记
    cleaned = cleaned.replaceAll(
      RegExp(r'(\[.*?\]|【.*?】|\(.*?\)|（.*?）|《|》)'),
      '',
    );
    // 移除常见空白与标点符号
    cleaned = cleaned.replaceAll(
      RegExp(r'[\s·•:：\-_~～!！?？,，.。/\\]+'),
      '',
    );
    return cleaned;
  }

  static String _extractFromSingleXPathNode(XPathNode node) {
    final domNode = node.node;
    if (domNode is dom.Element) {
      final fromAttr = _extractAttributesFromElement(domNode, includeSrc: true);
      if (fromAttr.isNotEmpty) return fromAttr;
      final fromStyle = _extractFromStyleAttribute(domNode.attributes['style']);
      if (fromStyle.isNotEmpty) return fromStyle;
    }
    for (final attr in _lazyImageAttributes) {
      final val = node.attributes[attr]?.trim() ?? '';
      if (val.isNotEmpty && !isPlaceholderImageUrl(val)) {
        return val;
      }
    }
    final srcVal = node.attributes['src']?.trim() ?? '';
    if (srcVal.isNotEmpty && !isPlaceholderImageUrl(srcVal)) {
      return srcVal;
    }
    final styleVal = _extractFromStyleAttribute(node.attributes['style']);
    if (styleVal.isNotEmpty) return styleVal;
    final textVal = node.text?.trim() ?? '';
    if (textVal.startsWith('http://') ||
        textVal.startsWith('https://') ||
        textVal.startsWith('//') ||
        textVal.startsWith('/')) {
      return textVal;
    }
    return '';
  }

  static String _extractAttributesFromElement(
    dom.Element el, {
    required bool includeSrc,
  }) {
    // 1. 优先检查所有懒加载属性（规避 src 为 loading 占位图的问题）
    for (final attr in _lazyImageAttributes) {
      final val = el.attributes[attr]?.trim() ?? '';
      if (val.isNotEmpty && !isPlaceholderImageUrl(val)) {
        return val;
      }
    }

    if (includeSrc) {
      // 2. 检查 srcset 的首个地址
      final srcset = el.attributes['srcset']?.trim() ?? '';
      if (srcset.isNotEmpty) {
        final firstEntry = srcset.split(',').first.trim().split(RegExp(r'\s+')).first;
        if (firstEntry.isNotEmpty && !isPlaceholderImageUrl(firstEntry)) {
          return firstEntry;
        }
      }

      // 3. 检查标准 src
      final src = el.attributes['src']?.trim() ?? '';
      if (src.isNotEmpty && !isPlaceholderImageUrl(src)) {
        return src;
      }
    }

    return '';
  }

  static String _extractFromStyleAttribute(String? style) {
    if (style == null || style.isEmpty) return '';
    final match = _cssUrlRegExp.firstMatch(style);
    if (match != null) {
      final url = match.group(1)?.trim() ?? '';
      if (url.isNotEmpty && !isPlaceholderImageUrl(url)) {
        return url;
      }
    }
    return '';
  }

  static bool _isSafeSingleCardParent(dom.Element child, dom.Element parent) {
    final tag = parent.localName?.toLowerCase() ?? '';
    if (child.localName?.toLowerCase() == 'li') return false;
    if (const {'body', 'html', 'ul', 'ol', 'table', 'tbody', 'section', 'main'}
        .contains(tag)) {
      return false;
    }
    // 仅当父容器内包含不超过 2 张图片时才视为单卡片容器，避免误取列表容器内其他条目的封面
    final imgs = parent.querySelectorAll('img');
    if (imgs.length > 2) return false;
    return true;
  }
}
