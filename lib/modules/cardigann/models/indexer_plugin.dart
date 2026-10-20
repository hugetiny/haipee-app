import 'package:kazumi/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:kazumi/modules/cardigann/indexer_plugin_manager.dart';
import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';
import 'package:kazumi/modules/torrent_search/sources/torrent_source.dart';

/// Cardigann Indexer Plugin implementing TorrentSource for Kazumi.
class IndexerPlugin implements TorrentSource {
  final String id;
  @override
  final String name;
  final String description;
  final String language;
  final String typeStr; // public, semi-private, private
  bool isEnabled;
  final bool isBuiltIn;
  final String rawYaml;
  final CardigannDefinition definition;
  final Map<String, String> settings;
  final DateTime installedAt;
  final DateTime updatedAt;

  /// Whether this indexer is part of the official bundled catalog.
  bool get isBundled => IndexerPluginsNotifier.isBundledId(id);

  /// Whether this built-in indexer has been overridden or modified by the user.
  bool get isOverridden => IndexerPluginsNotifier.isPluginOverridden(id, rawYaml);

  /// Whether this is a purely user-added custom indexer.
  bool get isCustom => !isBundled;

  final CardigannQueryExecutor _executor;

  IndexerPlugin({
    required this.id,
    required this.name,
    this.description = '',
    this.language = 'en-US',
    this.typeStr = 'public',
    this.isEnabled = true,
    this.isBuiltIn = false,
    required this.rawYaml,
    required this.definition,
    this.settings = const {},
    DateTime? installedAt,
    DateTime? updatedAt,
    CardigannQueryExecutor? executor,
  })  : installedAt = installedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        _executor = executor ?? CardigannQueryExecutor();

  @override
  TorrentSourceType get type => TorrentSourceType.indexerPlugin;

  @override
  bool get enabled => isEnabled;

  String? get customBaseUrl => settings['customBaseUrl'];

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    if (!isEnabled) return [];
    return _executor.search(
      definition,
      keyword,
      userConfig: settings,
      customBaseUrl: customBaseUrl,
    );
  }

  /// Specialized search specifying Torznab category.
  Future<List<TorrentItem>> searchWithCategory(
    String keyword, {
    int? torznabCategory,
  }) async {
    if (!isEnabled) return [];
    return _executor.search(
      definition,
      keyword,
      torznabCategory: torznabCategory,
      userConfig: settings,
      customBaseUrl: customBaseUrl,
    );
  }

  factory IndexerPlugin.fromYaml(
    String yamlContent, {
    String? customId,
    bool isEnabled = true,
    bool isBuiltIn = false,
    Map<String, String> settings = const {},
    DateTime? installedAt,
    DateTime? updatedAt,
    CardigannQueryExecutor? executor,
  }) {
    final definition = CardigannParser.parseYaml(yamlContent);
    final id = customId ?? definition.id;

    return IndexerPlugin(
      id: id,
      name: definition.name,
      description: definition.description,
      language: definition.language,
      typeStr: definition.type,
      isEnabled: isEnabled,
      isBuiltIn: isBuiltIn,
      rawYaml: yamlContent,
      definition: definition,
      settings: Map<String, String>.from(settings),
      installedAt: installedAt,
      updatedAt: updatedAt,
      executor: executor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'language': language,
      'typeStr': typeStr,
      'isEnabled': isEnabled,
      'isBuiltIn': isBuiltIn,
      'rawYaml': rawYaml,
      'settings': settings,
      'installedAt': installedAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory IndexerPlugin.fromJson(
    Map<String, dynamic> json, {
    CardigannQueryExecutor? executor,
  }) {
    final rawYaml = json['rawYaml']?.toString() ?? '';
    final definition = CardigannParser.parseYaml(rawYaml);

    final rawSettings = json['settings'];
    final settings = <String, String>{};
    if (rawSettings is Map) {
      rawSettings.forEach((k, v) {
        settings[k.toString()] = v.toString();
      });
    }

    return IndexerPlugin(
      id: json['id']?.toString() ?? definition.id,
      name: json['name']?.toString() ?? definition.name,
      description: json['description']?.toString() ?? definition.description,
      language: json['language']?.toString() ?? definition.language,
      typeStr: json['typeStr']?.toString() ?? definition.type,
      isEnabled: json['isEnabled'] == true,
      isBuiltIn: json['isBuiltIn'] == true,
      rawYaml: rawYaml,
      definition: definition,
      settings: settings,
      installedAt: json['installedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['installedAt'] as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : null,
      executor: executor,
    );
  }

  IndexerPlugin copyWith({
    String? id,
    String? name,
    String? description,
    String? language,
    String? typeStr,
    bool? isEnabled,
    bool? isBuiltIn,
    String? rawYaml,
    CardigannDefinition? definition,
    Map<String, String>? settings,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) {
    return IndexerPlugin(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      language: language ?? this.language,
      typeStr: typeStr ?? this.typeStr,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      rawYaml: rawYaml ?? this.rawYaml,
      definition: definition ?? this.definition,
      settings: settings ?? Map<String, String>.from(this.settings),
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      executor: _executor,
    );
  }
}
