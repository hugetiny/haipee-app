class SearchItem {
  String name;
  String src;
  String pic;
  String remarks;
  String category; // 'video' (在线视频) | 'live' (电视直播) | 'drive' (网盘资源) | 'bt' (BT磁力)

  SearchItem({
    required this.name,
    required this.src,
    this.pic = '',
    this.remarks = '',
    this.category = 'video',
  });

  /// 网盘和 BT 属于资源类（也就是下载类）
  bool get isResource => category == 'drive' || category == 'bt';
  bool get isDownloadable => isResource;
  bool get isLive => category == 'live';
  bool get isDrive => category == 'drive';
  bool get isBt => category == 'bt';
  bool get isVideo => category == 'video' || (!isLive && !isDrive && !isBt);

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(
      name: json['name']?.toString() ?? '',
      src: json['src']?.toString() ?? '',
      pic: json['pic']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      category: json['category']?.toString() ?? 'video',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'src': src,
      if (pic.isNotEmpty) 'pic': pic,
      if (remarks.isNotEmpty) 'remarks': remarks,
      if (category.isNotEmpty) 'category': category,
    };
  }
}

class PluginSearchResponse {
  String pluginName;
  List<SearchItem> data;
  String category;

  PluginSearchResponse({
    required this.pluginName,
    required this.data,
    this.category = 'video',
  });

  factory PluginSearchResponse.fromJson(Map<String, dynamic> json) {
    return PluginSearchResponse(
      pluginName: json['pluginName']?.toString() ?? '',
      category: json['category']?.toString() ?? 'video',
      data: (json['data'] as List? ?? const [])
          .map((itemJson) => SearchItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
    );
  }
}
