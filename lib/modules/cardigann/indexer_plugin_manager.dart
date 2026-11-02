import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/modules/cardigann/models/indexer_repo.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

class IndexerPluginState {
  final List<IndexerPlugin> plugins;
  final List<IndexerRepoSubscription> subscriptions;
  final bool isLoading;
  final String? error;

  const IndexerPluginState({
    this.plugins = const [],
    this.subscriptions = const [],
    this.isLoading = false,
    this.error,
  });

  IndexerPluginState copyWith({
    List<IndexerPlugin>? plugins,
    List<IndexerRepoSubscription>? subscriptions,
    bool? isLoading,
    String? error,
  }) {
    return IndexerPluginState(
      plugins: plugins ?? this.plugins,
      subscriptions: subscriptions ?? this.subscriptions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class IndexerPluginsNotifier extends Notifier<IndexerPluginState> {
  static const Map<String, String> bundledAssetMap = {
    'nyaasi': 'assets/indexers/nyaasi.yml',
    'mikan': 'assets/indexers/mikan.yml',
    'dmhy': 'assets/indexers/dmhy.yml',
    'acgrip': 'assets/indexers/acgrip.yml',
    'anibt': 'assets/indexers/anibt.yml',
    'bangumi-moe': 'assets/indexers/bangumi-moe.yml',
    'animetosho-xyz': 'assets/indexers/animetosho-xyz.yml',
    'tokyotosho': 'assets/indexers/tokyotosho.yml',
    'anisource': 'assets/indexers/anisource.yml',
    'nekobt': 'assets/indexers/nekobt.yml',
    'shanaproject': 'assets/indexers/shanaproject.yml',
    'nipponsei': 'assets/indexers/nipponsei.yml',
    '1337x': 'assets/indexers/1337x.yml',
    'thepiratebay': 'assets/indexers/thepiratebay.yml',
    'yts': 'assets/indexers/yts.yml',
    'eztv': 'assets/indexers/eztv.yml',
    'torrentscsv': 'assets/indexers/torrentscsv.yml',
    'limetorrents': 'assets/indexers/limetorrents.yml',
    'kickasstorrents-to': 'assets/indexers/kickasstorrents-to.yml',
    'kickasstorrents-ws': 'assets/indexers/kickasstorrents-ws.yml',
    'extratorrent-st': 'assets/indexers/extratorrent-st.yml',
    'torrentdownloads': 'assets/indexers/torrentdownloads.yml',
    'torrentdownload': 'assets/indexers/torrentdownload.yml',
    'torrentproject2': 'assets/indexers/torrentproject2.yml',
    'uindex': 'assets/indexers/uindex.yml',
    'internetarchive': 'assets/indexers/internetarchive.yml',
    'linuxtracker': 'assets/indexers/linuxtracker.yml',
    'ebookbay': 'assets/indexers/ebookbay.yml',
    'blueroms': 'assets/indexers/blueroms.yml',
    'rutor': 'assets/indexers/rutor.yml',
  };

  static final Map<String, String> _bundledOriginalYamls = {};

  /// Checks whether an indexer ID is part of the official bundled assets.
  static bool isBundledId(String id) => bundledAssetMap.containsKey(id);

  /// Checks whether an indexer's YAML differs from its original bundled asset version.
  static bool isPluginOverridden(String id, String rawYaml) {
    if (!isBundledId(id)) return false;
    final original = _bundledOriginalYamls[id];
    if (original == null) return false;
    return original.trim() != rawYaml.trim();
  }

  /// Gets the original bundled YAML for an indexer, if cached.
  static String? getOriginalBundledYaml(String id) => _bundledOriginalYamls[id];

  /// Populates the original bundled YAML cache (for tests or manual init).
  static void registerBundledYaml(String id, String yaml) {
    _bundledOriginalYamls[id] = yaml;
  }

  bool _isDisposed = false;

  @override
  IndexerPluginState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    Future.microtask(init);
    return const IndexerPluginState(isLoading: true);
  }

  Future<void> init() async {
    try {
      final plugins = <IndexerPlugin>[];
      final box = GStorage.indexerPlugins;
      final existingIds = <String>{};

      if (box.isNotEmpty) {
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw != null) {
            try {
              final Map<String, dynamic> map = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : jsonDecode(raw.toString());
              final p = IndexerPlugin.fromJson(map);
              plugins.add(p);
              existingIds.add(p.id);
            } catch (e) {
              HaipeeLogger().log(
                Level.warning,
                '[IndexerManager] Failed to load indexer from Hive key $key: $e',
              );
            }
          }
        }
      }

      if (_isDisposed) return;

      // Ensure all bundled indexers exist (handles app first-run and upgrades with new bundled indexers)
      for (final entry in bundledAssetMap.entries) {
        final id = entry.key;
        final assetPath = entry.value;
        try {
          final yamlStr = await rootBundle.loadString(assetPath);
          _bundledOriginalYamls[id] = yamlStr;
          final plugin = IndexerPlugin.fromYaml(yamlStr, isBuiltIn: true);
          final existingIdx = plugins.indexWhere((p) => p.id == plugin.id);
          if (existingIdx < 0) {
            plugins.add(plugin);
            existingIds.add(plugin.id);
            await box.put(plugin.id, plugin.toJson());
          } else {
            final existing = plugins[existingIdx];
            // If it's a built-in plugin and the bundled asset was updated, refresh the definition while preserving user settings
            if (existing.isBuiltIn && existing.rawYaml.trim() != yamlStr.trim()) {
              final updated = plugin.copyWith(
                isEnabled: existing.isEnabled,
                settings: existing.settings,
              );
              plugins[existingIdx] = updated;
              await box.put(updated.id, updated.toJson());
            }
          }
        } catch (e) {
          HaipeeLogger().log(
            Level.warning,
            '[IndexerManager] Failed to load bundled asset $assetPath: $e',
          );
        }
      }

      // Load subscriptions
      final subs = <IndexerRepoSubscription>[];
      final subBox = GStorage.indexerRepos;
      for (final key in subBox.keys) {
        final raw = subBox.get(key);
        if (raw != null) {
          try {
            final Map<String, dynamic> map = raw is Map
                ? Map<String, dynamic>.from(raw)
                : jsonDecode(raw.toString());
            subs.add(IndexerRepoSubscription.fromJson(map));
          } catch (_) {}
        }
      }

      if (_isDisposed) return;
      state = state.copyWith(
        plugins: plugins,
        subscriptions: subs,
        isLoading: false,
      );
    } catch (e) {
      HaipeeLogger().log(Level.error, '[IndexerManager] Init failed: $e');
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// Adds or updates an indexer plugin from raw YAML string.
  Future<IndexerPlugin?> addOrUpdatePlugin(
    String yamlContent, {
    bool? isEnabled,
    Map<String, String>? settings,
  }) async {
    try {
      final parsed = CardigannParser.parseYaml(yamlContent);
      final id = parsed.id;
      final existingIndex = state.plugins.indexWhere((p) => p.id == id);
      final existing = existingIndex >= 0 ? state.plugins[existingIndex] : null;

      final mergedSettings = <String, String>{};
      if (existing != null) {
        mergedSettings.addAll(existing.settings);
      }
      if (settings != null) {
        mergedSettings.addAll(settings);
      }

      final isBundled = isBundledId(id);
      final plugin = IndexerPlugin.fromYaml(
        yamlContent,
        isEnabled: isEnabled ?? existing?.isEnabled ?? true,
        isBuiltIn: isBundled,
        settings: mergedSettings,
        installedAt: existing?.installedAt,
        updatedAt: DateTime.now(),
      );

      await GStorage.indexerPlugins.put(plugin.id, plugin.toJson());

      final updatedList = List<IndexerPlugin>.from(state.plugins);
      if (existingIndex >= 0) {
        updatedList[existingIndex] = plugin;
      } else {
        updatedList.add(plugin);
      }

      state = state.copyWith(plugins: updatedList);
      HaipeeLogger().log(
        Level.info,
        '[IndexerManager] Successfully saved indexer: ${plugin.name} (${plugin.id}), isBundled=$isBundled, isOverridden=${isPluginOverridden(plugin.id, plugin.rawYaml)}',
      );
      return plugin;
    } catch (e) {
      HaipeeLogger().log(
        Level.error,
        '[IndexerManager] Failed to add or update indexer plugin: $e',
      );
      rethrow;
    }
  }

  /// Toggles the enabled state of an indexer plugin.
  Future<void> togglePlugin(String id, bool enabled) async {
    final index = state.plugins.indexWhere((p) => p.id == id);
    if (index < 0) return;

    final target = state.plugins[index].copyWith(isEnabled: enabled);
    await GStorage.indexerPlugins.put(target.id, target.toJson());

    final updated = List<IndexerPlugin>.from(state.plugins);
    updated[index] = target;
    state = state.copyWith(plugins: updated);
  }

  /// Updates settings/credentials for a specific indexer (cookie, passkey, api key, etc.).
  Future<void> updatePluginSettings(
      String id, Map<String, String> settings) async {
    final index = state.plugins.indexWhere((p) => p.id == id);
    if (index < 0) return;

    final target = state.plugins[index].copyWith(
      settings: settings,
      updatedAt: DateTime.now(),
    );
    await GStorage.indexerPlugins.put(target.id, target.toJson());

    final updated = List<IndexerPlugin>.from(state.plugins);
    updated[index] = target;
    state = state.copyWith(plugins: updated);
    HaipeeLogger().log(
      Level.info,
      '[IndexerManager] Updated settings for indexer $id',
    );
  }

  /// Removes an indexer plugin (protected if built-in).
  Future<void> removePlugin(String id) async {
    if (isBundledId(id)) {
      HaipeeLogger().log(
        Level.warning,
        '[IndexerManager] Cannot delete built-in indexer $id. Use resetPlugin instead.',
      );
      return;
    }
    await GStorage.indexerPlugins.delete(id);
    final updated = state.plugins.where((p) => p.id != id).toList();
    state = state.copyWith(plugins: updated);
    HaipeeLogger().log(Level.info, '[IndexerManager] Removed indexer $id');
  }

  /// Resets a built-in indexer to its default configuration.
  Future<void> resetPlugin(String id) async {
    final assetPath = bundledAssetMap[id];
    if (assetPath == null) return;

    try {
      final yamlStr = await rootBundle.loadString(assetPath);
      _bundledOriginalYamls[id] = yamlStr;
      final plugin = IndexerPlugin.fromYaml(yamlStr, isBuiltIn: true);
      await GStorage.indexerPlugins.put(plugin.id, plugin.toJson());
      final updated =
          state.plugins.map((p) => p.id == id ? plugin : p).toList();
      state = state.copyWith(plugins: updated);
      HaipeeLogger().log(
        Level.info,
        '[IndexerManager] Successfully reset built-in indexer $id',
      );
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[IndexerManager] Failed to reset indexer $id: $e',
      );
    }
  }

  /// Gets the raw YAML content of an indexer for export.
  String? exportPluginYaml(String id) {
    final index = state.plugins.indexWhere((p) => p.id == id);
    if (index >= 0) {
      return state.plugins[index].rawYaml;
    }
    return null;
  }

  // --- Remote Subscriptions ---

  /// Adds a new remote repository subscription.
  Future<void> addSubscription(String name, String manifestUrl) async {
    final cleanUrl = manifestUrl.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Remote Indexers';
    final id = 'repo_${DateTime.now().millisecondsSinceEpoch}';

    final sub = IndexerRepoSubscription(
      id: id,
      name: cleanName,
      manifestUrl: cleanUrl,
      enabled: true,
      lastSync: null,
    );

    await GStorage.indexerRepos.put(id, sub.toJson());
    final updated = List<IndexerRepoSubscription>.from(state.subscriptions)..add(sub);
    state = state.copyWith(subscriptions: updated);

    // Sync immediately
    await syncSubscription(id);
  }

  /// Removes a repository subscription.
  Future<void> removeSubscription(String id) async {
    await GStorage.indexerRepos.delete(id);
    final updated = state.subscriptions.where((s) => s.id != id).toList();
    state = state.copyWith(subscriptions: updated);
  }

  /// Syncs an individual repository subscription.
  Future<int> syncSubscription(String id) async {
    final index = state.subscriptions.indexWhere((s) => s.id == id);
    if (index < 0) return 0;

    final sub = state.subscriptions[index];
    final manifest = await IndexerRepoSubscription.fetchManifest(sub.manifestUrl);
    if (manifest == null) return 0;

    int installedCount = 0;
    for (final item in manifest.indexers) {
      if (item.downloadUrl.isNotEmpty) {
        final yaml = await IndexerRepoSubscription.downloadIndexerYaml(item.downloadUrl);
        if (yaml != null && yaml.isNotEmpty) {
          try {
            await addOrUpdatePlugin(yaml);
            installedCount++;
          } catch (_) {}
        }
      }
    }

    final updatedSub = IndexerRepoSubscription(
      id: sub.id,
      name: manifest.name.isNotEmpty ? manifest.name : sub.name,
      manifestUrl: sub.manifestUrl,
      enabled: sub.enabled,
      lastSync: DateTime.now(),
    );
    await GStorage.indexerRepos.put(id, updatedSub.toJson());

    final updatedSubs = List<IndexerRepoSubscription>.from(state.subscriptions);
    updatedSubs[index] = updatedSub;
    state = state.copyWith(subscriptions: updatedSubs);

    return installedCount;
  }
}

final indexerPluginsProvider =
    NotifierProvider<IndexerPluginsNotifier, IndexerPluginState>(
  IndexerPluginsNotifier.new,
);
