import 'package:haipee/plugins/plugins.dart';

class PluginHTTPItem {
  String name;
  String version;
  bool useNativePlayer;
  String author;
  int lastUpdate;
  String baseURL;
  String category;
  String type;

  PluginHTTPItem({
    required this.name,
    required this.version,
    required this.useNativePlayer,
    required this.author,
    required this.lastUpdate,
    this.baseURL = '',
    this.category = '',
    this.type = '',
  });

  PluginRuleType get ruleType =>
      PluginRuleType.fromString(type.isNotEmpty ? type : category);

  /// 社区官方规则知名源地址映射表（当远端索引未携带 baseURL 时的智能兜底）
  static const Map<String, String> defaultCommunityPluginBaseUrls = {
    '7sefun': 'https://www.7sefun.top/',
    'aafun': 'https://www.moonci.com/',
    'AGE': 'https://www.agedm.io/',
    'akianime': 'https://www.akianime.cc/',
    'baimao': 'https://www.baimaodm.com/',
    'dalvdm': 'https://www.sbdl.cc/',
    'DM84': 'https://dm84.tv/',
    'ezdmw': 'https://m.ezdmw.org/',
    'giriGiriLove': 'https://ani.girigirilove.com/',
    'LMM': 'https://www.lmm85.com/',
    'mgnacg': 'https://www.mgnacg.com/',
    'moonci': 'https://www.moonci.com/',
    'mutefun': 'https://www.2kdm.com/',
    'MXdm': 'https://www.dcc3.com/',
    'sorani': 'https://www.sorani.net/',
    'xfdmneo': 'https://dm1.xfdm.pro/',
    'xfdmnext': 'https://next.xifanacg.com/',
    'anime7': 'https://anime7.top/',
    'xfdm': 'https://dm.xifanacg.com/',
  };

  /// 获取该规则有效的源站主页地址
  String get effectiveBaseUrl {
    if (baseURL.isNotEmpty) return baseURL;
    return defaultCommunityPluginBaseUrls[name] ?? '';
  }

  factory PluginHTTPItem.fromJson(Map<String, dynamic> json) {
    return PluginHTTPItem(
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      useNativePlayer: json['useNativePlayer'] ?? false,
      author: json['author'] ?? '',
      lastUpdate: json['lastUpdate'] ?? 0,
      baseURL: json['baseURL'] ?? json['baseUrl'] ?? '',
      category: json['category'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

