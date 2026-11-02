import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:haipee/request/api.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/modules/plugin/plugin_http_module.dart';

class PluginHTTP {
  /// 从本地打包的预置资源中加载官方规则市场索引（零延迟瞬间就绪）
  static Future<List<PluginHTTPItem>> loadBundledPluginList() async {
    final List<PluginHTTPItem> list = [];
    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/plugins/index.json');
      } catch (_) {
        final f = File('assets/plugins/index.json');
        if (f.existsSync()) {
          jsonString = f.readAsStringSync();
        } else {
          return list;
        }
      }
      final jsonData = json.decode(jsonString);
      if (jsonData is List) {
        for (final item in jsonData) {
          try {
            list.add(PluginHTTPItem.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('读取内置规则市场索引失败: $e');
    }
    return list;
  }

  /// 获取规则市场最新列表（优先主站，失败自动切换加速镜像，兜底本地离线缓存）
  static Future<List<PluginHTTPItem>> getPluginList() async {
    List<PluginHTTPItem> pluginHTTPItemList = [];
    dynamic rawData;

    // 1. 尝试直接请求官方仓库
    try {
      final res = await Request().get('${Api.pluginShop}index.json');
      rawData = res.data;
    } catch (e) {
      debugPrint('获取官方源仓库失败，尝试加速镜像: $e');
      // 2. 备用加速镜像
      try {
        final mirrorUrl = '${Api.gitMirror}${Api.pluginShop}index.json';
        final res = await Request().get(mirrorUrl);
        rawData = res.data;
      } catch (mirrorErr) {
        debugPrint('加速镜像获取失败: $mirrorErr');
      }
    }

    if (rawData != null) {
      try {
        final jsonData = rawData is String ? json.decode(rawData) : rawData;
        if (jsonData is List) {
          for (final pluginJsonItem in jsonData) {
            try {
              final pluginHTTPItem = PluginHTTPItem.fromJson(pluginJsonItem);
              pluginHTTPItemList.add(pluginHTTPItem);
            } catch (_) {}
          }
        }
      } catch (parseErr) {
        debugPrint('解析源仓库 JSON 失败: $parseErr');
      }
    }

    // 3. 若网络获取为空（如离线或断网），自动兜底本地预置市场索引，确保永不呈现 0 个源
    if (pluginHTTPItemList.isEmpty) {
      pluginHTTPItemList = await loadBundledPluginList();
    }

    return pluginHTTPItemList;
  }

  /// 从市场获取规则详情（支持镜像与本地内置回退）
  static Future<Plugin?> getPlugin(String name) async {
    Plugin? plugin;
    dynamic rawData;

    try {
      final res = await Request().get('${Api.pluginShop}$name.json');
      rawData = res.data;
    } catch (e) {
      debugPrint('获取源 $name 错误，尝试加速镜像: $e');
      try {
        final mirrorUrl = '${Api.gitMirror}${Api.pluginShop}$name.json';
        final res = await Request().get(mirrorUrl);
        rawData = res.data;
      } catch (mirrorErr) {
        debugPrint('加速镜像获取源 $name 失败: $mirrorErr');
      }
    }

    if (rawData != null) {
      try {
        final jsonData = rawData is String ? json.decode(rawData) : rawData;
        plugin = Plugin.fromJson(jsonData);
      } catch (e) {
        debugPrint('解析源 $name 错误: $e');
      }
    }

    // 若网络不可达且为内置规则之一，从本地资产回退
    if (plugin == null) {
      try {
        String localJson = '';
        try {
          localJson =
              await rootBundle.loadString('assets/plugins/$name.json');
        } catch (_) {
          final f = File('assets/plugins/$name.json');
          if (f.existsSync()) {
            localJson = f.readAsStringSync();
          }
        }
        if (localJson.isNotEmpty) {
          plugin = Plugin.fromJson(json.decode(localJson));
        }
      } catch (_) {}
    }

    return plugin;
  }
}
