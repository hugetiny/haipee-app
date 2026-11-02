import 'package:dio/dio.dart';
import 'package:haipee/request/core/git_proxy_interceptor.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// Single indexer entry in a remote repository manifest.
class IndexerRepoItem {
  final String id;
  final String name;
  final String description;
  final String type;
  final String language;
  final String version;
  final String downloadUrl;

  const IndexerRepoItem({
    required this.id,
    required this.name,
    this.description = '',
    this.type = 'public',
    this.language = 'en-US',
    this.version = '1.0.0',
    required this.downloadUrl,
  });

  factory IndexerRepoItem.fromJson(Map<String, dynamic> json) {
    return IndexerRepoItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'public',
      language: json['language']?.toString() ?? 'en-US',
      version: json['version']?.toString() ?? '1.0.0',
      downloadUrl: json['downloadUrl']?.toString() ??
          json['url']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'language': language,
      'version': version,
      'downloadUrl': downloadUrl,
    };
  }
}

/// Remote indexer repository manifest (`index.json`).
class IndexerRepoManifest {
  final String name;
  final String description;
  final String version;
  final DateTime? updatedAt;
  final List<IndexerRepoItem> indexers;

  const IndexerRepoManifest({
    required this.name,
    this.description = '',
    this.version = '1.0.0',
    this.updatedAt,
    this.indexers = const [],
  });

  factory IndexerRepoManifest.fromJson(Map<String, dynamic> json) {
    final list = <IndexerRepoItem>[];
    if (json['indexers'] is List) {
      for (final item in json['indexers']) {
        if (item is Map) {
          list.add(IndexerRepoItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    DateTime? updated;
    if (json['updatedAt'] != null) {
      updated = DateTime.tryParse(json['updatedAt'].toString());
    }

    return IndexerRepoManifest(
      name: json['name']?.toString() ?? 'Indexer Repository',
      description: json['description']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0.0',
      updatedAt: updated,
      indexers: list,
    );
  }
}

/// User subscription to a remote indexer repository.
class IndexerRepoSubscription {
  final String id;
  final String name;
  final String manifestUrl;
  final bool enabled;
  final DateTime? lastSync;

  const IndexerRepoSubscription({
    required this.id,
    required this.name,
    required this.manifestUrl,
    this.enabled = true,
    this.lastSync,
  });

  factory IndexerRepoSubscription.fromJson(Map<String, dynamic> json) {
    return IndexerRepoSubscription(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      manifestUrl: json['manifestUrl']?.toString() ?? '',
      enabled: json['enabled'] != false,
      lastSync: json['lastSync'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSync'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'manifestUrl': manifestUrl,
      'enabled': enabled,
      'lastSync': lastSync?.millisecondsSinceEpoch,
    };
  }

  /// Fetches the remote manifest using Dio.
  static Future<IndexerRepoManifest?> fetchManifest(
    String manifestUrl, {
    Dio? client,
  }) async {
    final dio = client ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
    dio.interceptors.add(GitProxyInterceptor());

    try {
      final res = await dio.get(manifestUrl);
      if (res.statusCode == 200 && res.data is Map) {
        return IndexerRepoManifest.fromJson(Map<String, dynamic>.from(res.data));
      }
      return null;
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[IndexerRepo] Failed to fetch manifest from $manifestUrl: $e',
      );
      return null;
    }
  }

  /// Downloads raw YAML from item downloadUrl.
  static Future<String?> downloadIndexerYaml(
    String downloadUrl, {
    Dio? client,
  }) async {
    final dio = client ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ));
    dio.interceptors.add(GitProxyInterceptor());

    try {
      final res = await dio.get(downloadUrl);
      if (res.statusCode == 200 && res.data != null) {
        return res.data.toString();
      }
      return null;
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[IndexerRepo] Failed to download indexer from $downloadUrl: $e',
      );
      return null;
    }
  }
}
