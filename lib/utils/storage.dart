import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:kazumi/db/database.dart' hide History, SearchHistory;
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/modules/parse_failure/parse_failure_module.dart';
import 'package:kazumi/modules/download/download_task.dart';
import 'package:kazumi/utils/api_credentials.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

// Mock Box class to mimic Hive Box behavior backed by Drift
class MockBox<T> {
  final Map<dynamic, T> _data = {};
  final String _name;
  final AppDatabase _db;

  MockBox(this._name, this._db);

  Iterable<T> get values => _data.values;
  Iterable<dynamic> get keys => _data.keys;
  int get length => _data.length;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  bool containsKey(dynamic key) => _data.containsKey(key);

  T? get(dynamic key, {T? defaultValue}) {
    return _data[key] ?? defaultValue;
  }

  Future<void> put(dynamic key, T value) async {
    _data[key] = value;
    await _persist(key, value);
  }

  Future<void> delete(dynamic key) async {
    final value = _data[key];
    _data.remove(key);
    await _deleteFromDb(key, value);
  }

  Future<void> clear() async {
    _data.clear();
    await _clearDb();
  }

  Future<void> putAll(Map<dynamic, T> entries) async {
    _data.addAll(entries);
    await _db.batch((batch) {
      for (var entry in entries.entries) {
        _batchInsert(batch, entry.key, entry.value);
      }
    });
  }

  Future<int> add(T value) async {
    int id = DateTime.now().millisecondsSinceEpoch;
    if (value is CollectedBangumiChange) {
      id = value.id;
    }
    await put(id, value);
    return id;
  }

  Future<void> flush() async {
    // No-op for Drift as we persist immediately
  }

  Map<dynamic, T> toMap() => Map.from(_data);

  void _batchInsert(Batch batch, dynamic key, T value) {
    if (_name == 'setting') {
      final jsonStr = jsonEncode(value);
      batch.insert(
          _db.settings,
          SettingsCompanion.insert(key: key.toString(), value: jsonStr),
          mode: InsertMode.insertOrReplace);
    } else if (_name == 'histories') {
      final jsonStr = jsonEncode(value);
      final h = value as History;
      batch.insert(
          _db.histories,
          HistoriesCompanion.insert(
              id: Value(h.bangumiItem.id),
              json: jsonStr,
              lastWatchTime: h.lastWatchTime),
          mode: InsertMode.insertOrReplace);
    } else if (_name == 'collectibles') {
      final jsonStr = jsonEncode(value);
      final c = value as CollectedBangumi;
      batch.insert(
          _db.collectibles,
          CollectiblesCompanion.insert(
              id: Value(c.bangumiItem.id),
              json: jsonStr,
              type: c.type,
              updateTime: Value(c.time)),
          mode: InsertMode.insertOrReplace);
    } else if (_name == 'collectchanges') {
      final jsonStr = jsonEncode(value);
      final c = value as CollectedBangumiChange;
      batch.insert(
          _db.collectChanges,
          CollectChangesCompanion.insert(
              id: Value(c.id),
              json: jsonStr,
              bangumiId: c.bangumiID,
              timestamp:
                  DateTime.fromMillisecondsSinceEpoch(c.timestamp * 1000)),
          mode: InsertMode.insertOrReplace);
    } else if (_name == 'searchHistory') {
      final s = value as SearchHistory;
      batch.insert(
          _db.searchHistories,
          SearchHistoriesCompanion.insert(
              keyword: s.keyword,
              timestamp: DateTime.fromMillisecondsSinceEpoch(s.timestamp)),
          mode: InsertMode.insertOrReplace);
    } else {
      // Generic cache
      final jsonStr = jsonEncode(value);
      batch.insert(
          _db.keyValueCache,
          KeyValueCacheCompanion.insert(
              boxName: _name, key: key.toString(), value: jsonStr),
          mode: InsertMode.insertOrReplace);
    }
  }

  Future<void> _persist(dynamic key, T value) async {
    await _db.batch((batch) {
      _batchInsert(batch, key, value);
    });
  }

  Future<void> _deleteFromDb(dynamic key, T? value) async {
    if (_name == 'setting') {
      await (_db.delete(_db.settings)..where((t) => t.key.equals(key.toString()))).go();
    } else if (_name == 'histories') {
      if (value != null) {
        final h = value as History;
        await (_db.delete(_db.histories)..where((t) => t.id.equals(h.bangumiItem.id))).go();
      }
    } else if (_name == 'collectibles') {
       // Key is ID
       await (_db.delete(_db.collectibles)..where((t) => t.id.equals(int.parse(key.toString())))).go();
    } else if (_name == 'collectchanges') {
       await (_db.delete(_db.collectChanges)..where((t) => t.id.equals(int.parse(key.toString())))).go();
    } else if (_name == 'searchHistory') {
       if (value != null) {
         final s = value as SearchHistory;
         await (_db.delete(_db.searchHistories)..where((t) => t.keyword.equals(s.keyword) & t.timestamp.equals(DateTime.fromMillisecondsSinceEpoch(s.timestamp)))).go();
       }
    } else {
       await (_db.delete(_db.keyValueCache)..where((t) => t.boxName.equals(_name) & t.key.equals(key.toString()))).go();
    }
  }

  Future<void> _clearDb() async {
     if (_name == 'setting') {
      await _db.delete(_db.settings).go();
    } else if (_name == 'histories') {
      await _db.delete(_db.histories).go();
    } else if (_name == 'collectibles') {
      await _db.delete(_db.collectibles).go();
    } else if (_name == 'collectchanges') {
      await _db.delete(_db.collectChanges).go();
    } else if (_name == 'searchHistory') {
      await _db.delete(_db.searchHistories).go();
    } else {
      await (_db.delete(_db.keyValueCache)..where((t) => t.boxName.equals(_name))).go();
    }
  }
}

class GStorage {
  static late AppDatabase db;

  static late MockBox<BangumiItem> favorites;
  static late MockBox<CollectedBangumi> collectibles;
  static late MockBox<History> histories;
  static late MockBox<CollectedBangumiChange> collectChanges;
  static late MockBox<String> shieldList;
  static late MockBox<dynamic> setting;
  static late MockBox<SearchHistory> searchHistory;
  static late MockBox<MetadataRecord> metadataCache;
  static late MockBox<ParseFailureRecord> parseFailures;
  static late MockBox<dynamic> downloadTasks;
  static late MockBox<dynamic> torrentEntries;
  static late MockBox<dynamic> playbackProfiles;
  static late MockBox<dynamic> pluginStats;

  static Future init() async {
    db = AppDatabase();

    // Initialize MockBoxes
    favorites = MockBox('favorites', db);
    collectibles = MockBox('collectibles', db);
    histories = MockBox('histories', db);
    setting = MockBox('setting', db);
    collectChanges = MockBox('collectchanges', db);
    shieldList = MockBox('shieldList', db);
    searchHistory = MockBox('searchHistory', db);
    metadataCache = MockBox('metadataCache', db);
    parseFailures = MockBox('parseFailures', db);
    downloadTasks = MockBox('downloadTasks', db);
    torrentEntries = MockBox('torrentEntries', db);
    playbackProfiles = MockBox('playbackProfiles', db);
    pluginStats = MockBox('pluginStats', db);

    // Load data from DB to memory
    await _loadSettings();
    await _loadHistories();
    await _loadCollectibles();
    await _loadCollectChanges();
    await _loadSearchHistory();

    // Load generic boxes
    await _loadGeneric('shieldList', shieldList, (json) => json as String);
    await _loadGeneric('metadataCache', metadataCache, (json) => MetadataRecord.fromJson(json));
    await _loadGeneric('parseFailures', parseFailures, (json) => ParseFailureRecord.fromJson(json));
    await _loadGeneric('downloadTasks', downloadTasks, (json) => DownloadTask.fromJson(json));
    // torrentEntries and playbackProfiles might be dynamic maps or specific objects.
    // Assuming dynamic for now as per original code.
    await _loadGeneric('torrentEntries', torrentEntries, (json) => json);
    await _loadGeneric('playbackProfiles', playbackProfiles, (json) => json);
    await _loadGeneric('pluginStats', pluginStats, (json) => json);

    await _ensureRetentionDefaults();
  }

  static Future<void> _loadSettings() async {
    final rows = await db.select(db.settings).get();
    for (var row in rows) {
      try {
        setting._data[row.key] = jsonDecode(row.value);
      } catch (e) {
        setting._data[row.key] = row.value;
      }
    }
  }

  static Future<void> _loadHistories() async {
    final rows = await db.select(db.histories).get();
    for (var row in rows) {
      try {
        final h = History.fromJson(jsonDecode(row.json));
        histories._data[h.key] = h;
      } catch (e) {
        KazumiLogger().log(Level.error, 'Failed to load history: $e');
      }
    }
  }

  static Future<void> _loadCollectibles() async {
    final rows = await db.select(db.collectibles).get();
    for (var row in rows) {
      try {
        final c = CollectedBangumi.fromJson(jsonDecode(row.json));
        collectibles._data[c.bangumiItem.id] = c;
      } catch (e) {
        KazumiLogger().log(Level.error, 'Failed to load collectible: $e');
      }
    }
  }

  static Future<void> _loadCollectChanges() async {
    final rows = await db.select(db.collectChanges).get();
    for (var row in rows) {
      try {
        final c = CollectedBangumiChange.fromJson(jsonDecode(row.json));
        collectChanges._data[c.id] = c;
      } catch (e) {
        KazumiLogger().log(Level.error, 'Failed to load collect change: $e');
      }
    }
  }

  static Future<void> _loadSearchHistory() async {
    final rows = await db.select(db.searchHistories).get();
    for (var row in rows) {
      try {
        final s = SearchHistory(row.keyword, row.timestamp.millisecondsSinceEpoch);
        searchHistory._data[s.key] = s;
      } catch (e) {
        KazumiLogger().log(Level.error, 'Failed to load search history: $e');
      }
    }
  }

  static Future<void> _loadGeneric<T>(String boxName, MockBox<T> box, T Function(dynamic) fromJson) async {
    final rows = await (db.select(db.keyValueCache)..where((t) => t.boxName.equals(boxName))).get();
    for (var row in rows) {
      try {
        dynamic decoded = jsonDecode(row.value);
        box._data[row.key] = fromJson(decoded);
      } catch (e) {
        if (T == String) {
           box._data[row.key] = row.value as T;
        }
      }
    }
  }


  static Future<void> backupBox(String boxName, String backupFilePath) async {
    // TODO: Implement backup for SQLite
    KazumiLogger().log(Level.warning, 'Backup not implemented for SQLite yet');
  }

  static Future<void> patchHistory(String backupFilePath) async {
    // TODO: Implement restore for SQLite
    KazumiLogger().log(Level.warning, 'Restore not implemented for SQLite yet');
  }

  static Future<void> restoreCollectibles(String backupFilePath) async {
    // TODO: Implement restore for SQLite
    KazumiLogger().log(Level.warning, 'Restore not implemented for SQLite yet');
  }

  static Future<List<CollectedBangumi>> getCollectiblesFromFile(
      String backupFilePath) async {
    // TODO: Implement restore for SQLite
    KazumiLogger().log(Level.warning, 'Restore not implemented for SQLite yet');
    return [];
  }

  static Future<List<CollectedBangumiChange>> getCollectChangesFromFile(
      String backupFilePath) async {
    // TODO: Implement restore for SQLite
    KazumiLogger().log(Level.warning, 'Restore not implemented for SQLite yet');
    return [];
  }

  static Future<void> patchCollectibles(
      List<CollectedBangumi> remoteCollectibles,
      List<CollectedBangumiChange> remoteChanges) async {
    List<CollectedBangumi> localCollectibles = collectibles.values.toList();
    List<CollectedBangumiChange> localChanges = collectChanges.values.toList();

    final List<CollectedBangumiChange> newLocalChanges =
        localChanges.where((localChange) {
      return !remoteChanges
          .any((remoteChange) => remoteChange.id == localChange.id);
    }).toList();

    newLocalChanges.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Process local changes
    for (var change in newLocalChanges) {
      if (change.action == 3) {
        remoteCollectibles
            .removeWhere((b) => b.bangumiItem.id == change.bangumiID);
      } else {
        final changedBangumiID = change.bangumiID.toString();
        for (var localCollect in localCollectibles) {
          if (localCollect.bangumiItem.id.toString() == changedBangumiID) {
            if (change.action == 1) {
              final exists = remoteCollectibles
                  .any((b) => b.bangumiItem.id == localCollect.bangumiItem.id);
              if (!exists) {
                remoteCollectibles.add(localCollect);
              } else {
                final index = remoteCollectibles.indexWhere(
                    (b) => b.bangumiItem.id == localCollect.bangumiItem.id);
                localCollect.type = change.type;
                if (index != -1) {
                  remoteCollectibles[index] = localCollect;
                }
              }
            } else if (change.action == 2) {
              final index = remoteCollectibles.indexWhere(
                  (b) => b.bangumiItem.id == localCollect.bangumiItem.id);
              localCollect.type = change.type;
              if (index != -1) {
                remoteCollectibles[index] = localCollect;
              }
            }
            break;
          }
        }
      }
    }

    // merge local changes with remote changes
    final Map<int, CollectedBangumiChange> mergedMap = {};
    for (var change in remoteChanges) {
      mergedMap[change.id] = change;
    }
    for (var change in newLocalChanges) {
      if (!mergedMap.containsKey(change.id)) {
        mergedMap[change.id] = change;
      }
    }
    final List<CollectedBangumiChange> mergedChanges =
        mergedMap.values.toList();

    // Update local storage
    await collectibles.clear();
    for (var collect in remoteCollectibles) {
      await collectibles.put(collect.bangumiItem.id, collect);
    }
    await collectChanges.clear();
    for (var change in mergedChanges) {
      await collectChanges.put(change.id, change);
    }
  }

  // Prevent instantiation
  GStorage._();

  static Future<void> _ensureRetentionDefaults() async {
    final Locale platformLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final bool bangumiDefault = _shouldEnableBangumiByDefault(platformLocale);

    if (!setting.containsKey(SettingBoxKey.metadataRetentionHours)) {
      await setting.put(SettingBoxKey.metadataRetentionHours, 24);
    }
    if (!setting.containsKey(SettingBoxKey.downloadRetentionHours)) {
      await setting.put(SettingBoxKey.downloadRetentionHours, 24);
    }
    if (!setting.containsKey(SettingBoxKey.playbackProfileRetentionHours)) {
      await setting.put(SettingBoxKey.playbackProfileRetentionHours, 24);
    }
    if (!setting.containsKey(SettingBoxKey.metadataBangumiEnabled)) {
      await setting.put(SettingBoxKey.metadataBangumiEnabled, bangumiDefault);
    }
    if (!setting.containsKey(SettingBoxKey.metadataTmdbEnabled)) {
      await setting.put(SettingBoxKey.metadataTmdbEnabled, true);
    }
    if (!setting.containsKey(SettingBoxKey.metadataPreferredLocale)) {
      await setting.put(SettingBoxKey.metadataPreferredLocale, '');
    }
    if (!setting.containsKey(SettingBoxKey.tmdbApiKey)) {
      await setting.put(SettingBoxKey.tmdbApiKey, '');
    }
    if (!setting.containsKey(SettingBoxKey.danDanAppId)) {
      await setting.put(SettingBoxKey.danDanAppId, '');
    }
    if (!setting.containsKey(SettingBoxKey.danDanApiKey)) {
      await setting.put(SettingBoxKey.danDanApiKey, '');
    }
    if (!setting.containsKey(SettingBoxKey.aria2Endpoint)) {
      await setting.put(
          SettingBoxKey.aria2Endpoint, 'http://127.0.0.1:6800/jsonrpc');
    }
    if (!setting.containsKey(SettingBoxKey.aria2Secret)) {
      await setting.put(SettingBoxKey.aria2Secret, '');
    }
    if (!setting.containsKey(SettingBoxKey.aria2TimeoutSeconds)) {
      await setting.put(SettingBoxKey.aria2TimeoutSeconds, 15);
    }
    if (!setting.containsKey(SettingBoxKey.aria2MaxConcurrentDownloads)) {
      await setting.put(SettingBoxKey.aria2MaxConcurrentDownloads, 2);
    }
    if (!setting.containsKey(SettingBoxKey.torrentConsentAccepted)) {
      await setting.put(SettingBoxKey.torrentConsentAccepted, false);
    }
    if (!setting.containsKey(SettingBoxKey.torrentConsentTimestamp)) {
      await setting.put(SettingBoxKey.torrentConsentTimestamp, 0);
    }
  }

  static bool _shouldEnableBangumiByDefault(Locale locale) {
    final String code = locale.languageCode.toLowerCase();
    return code == 'zh' || code == 'ja';
  }

  static Duration metadataRetentionDuration() {
    return Duration(
        hours: _readRetentionHours(
      SettingBoxKey.metadataRetentionHours,
      24,
    ));
  }

  static Duration downloadRetentionDuration() {
    return Duration(
        hours: _readRetentionHours(
      SettingBoxKey.downloadRetentionHours,
      24,
    ));
  }

  static Duration playbackProfileRetentionDuration() {
    return Duration(
        hours: _readRetentionHours(
      SettingBoxKey.playbackProfileRetentionHours,
      24,
    ));
  }

  static int _readRetentionHours(String key, int fallback) {
    final dynamic value = setting.get(key, defaultValue: fallback);
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static String readDanDanAppId() {
    final String? stored =
        (setting.get(SettingBoxKey.danDanAppId, defaultValue: '') as String?)
            ?.trim();
    return (stored != null && stored.isNotEmpty)
        ? stored
        : ApiCredentials.danDanAppId;
  }

  static String readDanDanApiKey() {
    final String? stored =
        (setting.get(SettingBoxKey.danDanApiKey, defaultValue: '') as String?)
            ?.trim();
    return (stored != null && stored.isNotEmpty)
        ? stored
        : ApiCredentials.danDanApiKey;
  }
}

class SettingBoxKey {
  static const String hAenable = 'hAenable',
      hardwareDecoder = 'hardwareDecoder',
      searchEnhanceEnable = 'searchEnhanceEnable',
      autoUpdate = 'autoUpdate',
      alwaysOntop = 'alwaysOntop',
      defaultPlaySpeed = 'defaultPlaySpeed',
      defaultAspectRatioType = 'defaultAspectRatioType',
      danmakuEnhance = 'danmakuEnhance',
      danmakuBorder = 'danmakuBorder',
      danmakuOpacity = 'danmakuOpacity',
      danmakuFontSize = 'danmakuFontSize',
      danmakuTop = 'danmakuTop',
      danmakuScroll = 'danmakuScroll',
      danmakuBottom = 'danmakuBottom',
      danmakuMassive = 'danmakuMassive',
      danmakuArea = 'danmakuArea',
      danmakuColor = 'danmakuColor',
      danmakuEnabledByDefault = 'danmakuEnabledByDefault',
      danmakuBiliBiliSource = 'danmakuBiliBiliSource',
      danmakuGamerSource = 'danmakuGamerSource',
      danmakuDanDanSource = 'danmakuDanDanSource',
      danmakuFontWeight = 'danmakuFontWeight',
      themeMode = 'themeMode',
      themeColor = 'themeColor',
      privateMode = 'privateMode',
      autoPlay = 'autoPlay',
      playResume = 'playResume',
      showPlayerError = 'showPlayerError',
      oledEnhance = 'oledEnhance',
      displayMode = 'displayMode',
      enableGitProxy = 'enableGitProxy',
      enableSystemProxy = 'enableSystemProxy',
      isWideScreen = 'isWideScreen',
      webDavEnable = 'webDavEnable',
      webDavEnableHistory = 'webDavEnableHistory',
      webDavEnableCollect = 'webDavEnableCollect',
      webDavURL = 'webDavURL',
      webDavUsername = 'webDavUsername',
      webDavPassword = 'webDavPasswd',
      lowMemoryMode = 'lowMemoryMode',
      showWindowButton = 'showWindowButton',
      useDynamicColor = 'useDynamicColor',
      exitBehavior = 'exitBehavior',
      playerDebugMode = 'playerDebugMode',
      syncPlayEndPoint = 'syncPlayEndPoint',
      androidEnableOpenSLES = 'androidEnableOpenSLES',
      defaultSuperResolutionType = 'defaultSuperResolutionType',
      superResolutionWarn = 'superResolutionWarn',
      playerDisableAnimations = 'playerDisableAnimations',
      metadataRetentionHours = 'metadataRetentionHours',
      downloadRetentionHours = 'downloadRetentionHours',
      playbackProfileRetentionHours = 'playbackProfileRetentionHours',
      metadataBangumiEnabled = 'metadataBangumiEnabled',
      metadataTmdbEnabled = 'metadataTmdbEnabled',
      metadataPreferredLocale = 'metadataPreferredLocale',
      tmdbApiKey = 'tmdbApiKey',
      danDanAppId = 'danDanAppId',
      danDanApiKey = 'danDanApiKey',
      aria2Endpoint = 'aria2Endpoint',
      aria2Secret = 'aria2Secret',
      aria2TimeoutSeconds = 'aria2TimeoutSeconds',
      aria2MaxConcurrentDownloads = 'aria2MaxConcurrentDownloads',
      torrentConsentAccepted = 'torrentConsentAccepted',
      torrentConsentTimestamp = 'torrentConsentTimestamp',
      subtitleAutoMatchEnabled = 'subtitleAutoMatchEnabled',
      subtitlePreferredLanguages = 'subtitlePreferredLanguages',
      subtitlePreferredFormats = 'subtitlePreferredFormats',
      appLocale = 'appLocale';
}
