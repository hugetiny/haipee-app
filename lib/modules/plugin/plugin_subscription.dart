import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// 在线视频规则源订阅模型 (对标去中心化 IndexerRepoSubscription)
/// 支持订阅 GitHub、Gitee、私有云或 CDN 上的 Web 规则清单 (index.json / rules.yaml)
class PluginSubscription {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final DateTime? lastSync;
  final int pluginCount;

  const PluginSubscription({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.lastSync,
    this.pluginCount = 0,
  });

  PluginSubscription copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
    DateTime? lastSync,
    int? pluginCount,
  }) {
    return PluginSubscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      lastSync: lastSync ?? this.lastSync,
      pluginCount: pluginCount ?? this.pluginCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'enabled': enabled,
      'lastSync': lastSync?.toIso8601String(),
      'pluginCount': pluginCount,
    };
  }

  factory PluginSubscription.fromJson(Map<String, dynamic> json) {
    return PluginSubscription(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名订阅源',
      url: json['url']?.toString() ?? '',
      enabled: json['enabled'] as bool? ?? true,
      lastSync: json['lastSync'] != null
          ? DateTime.tryParse(json['lastSync'].toString())
          : null,
      pluginCount: (json['pluginCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// 从远程 URL 拉取并批量解析规则 (支持 JSON 数组、YAML 列表、Manifest 清单及递归分发)
  static Future<List<Plugin>> fetchPluginsFromUrl(
    String url, {
    Dio? client,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return const [];

    final dio = client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Haipee/RuleSubscription',
              'Accept': '*/*',
            },
          ),
        );
    dio.interceptors.add(GitProxyInterceptor());

    try {
      final response = await dio.get<String>(
        cleanUrl,
        options: Options(responseType: ResponseType.plain),
      );

      final body = response.data?.trim() ?? '';
      if (body.isEmpty) return const [];

      // 1. 使用 Plugin.parseMany 统一解析 (覆盖 JSON 数组、YAML 列表、多文档等)
      final parsed = Plugin.parseMany(body);
      if (parsed.isNotEmpty) {
        return parsed;
      }

      // 2. 检查是否为包含下载子链接的索引数组 (形如 [ { "name": "...", "url": "..." } ])
      try {
        final decoded = jsonDecode(body);
        if (decoded is List) {
          final List<Plugin> remoteSubPlugins = [];
          final List<Future<void>> subTasks = [];

          for (final item in decoded) {
            if (item is Map && item['url'] != null) {
              final subUrl = item['url'].toString();
              subTasks.add(() async {
                try {
                  final subResp = await dio.get<String>(
                    subUrl,
                    options: Options(responseType: ResponseType.plain),
                  );
                  final subBody = subResp.data?.trim() ?? '';
                  final subParsed = Plugin.parseMany(subBody);
                  remoteSubPlugins.addAll(subParsed);
                } catch (_) {}
              }());
            }
          }

          if (subTasks.isNotEmpty) {
            await Future.wait(subTasks);
            if (remoteSubPlugins.isNotEmpty) {
              return remoteSubPlugins;
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      HaipeeLogger().log(Level.warning, '拉取在线规则订阅失败: $url, error: $e');
      rethrow;
    }

    return const [];
  }
}
