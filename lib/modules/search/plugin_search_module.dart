class SearchItem {
  String name;
  String src;
  String pic;
  String remarks;

  SearchItem({
    required this.name,
    required this.src,
    this.pic = '',
    this.remarks = '',
  });

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(
      name: json['name']?.toString() ?? '',
      src: json['src']?.toString() ?? '',
      pic: json['pic']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'src': src,
      if (pic.isNotEmpty) 'pic': pic,
      if (remarks.isNotEmpty) 'remarks': remarks,
    };
  }
}

class PluginSearchResponse {
  String pluginName;
  List<SearchItem> data;

  PluginSearchResponse({
    required this.pluginName,
    required this.data,
  });

  factory PluginSearchResponse.fromJson(Map<String, dynamic> json) {
    return PluginSearchResponse(
      pluginName: json['pluginName'],
      data: (json['data'] as List)
          .map((itemJson) => SearchItem.fromJson(itemJson))
          .toList(),
    );
  }
}
