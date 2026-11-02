import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show rootBundle, AssetManifest, MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugin_validity_tracker.dart';
import 'package:haipee/plugins/plugin_install_time_tracker.dart';
import 'package:haipee/request/plugin.dart';
import 'package:haipee/modules/plugin/plugin_http_module.dart';
import 'package:logger/logger.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/request/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:haipee/modules/plugin/plugin_subscription.dart';
import 'package:haipee/utils/storage.dart';

// 从 1.5.1 版本开始，规则文件储存在单一的 plugins.json 文件中。
// 之前的版本中，规则以分离文件形式存储，版本更新后将这些分离文件合并为单一的 plugins.json 文件。

class PluginsState {
  const PluginsState({
    this.pluginList = const [],
    this.pluginHTTPList = const [],
    this.disabledPluginNames = const {},
    this.subscriptions = const [],
  });

  final List<Plugin> pluginList;
  final List<PluginHTTPItem> pluginHTTPList;
  final Set<String> disabledPluginNames;
  final List<PluginSubscription> subscriptions;

  bool isPluginEnabled(String name) => !disabledPluginNames.contains(name);

  int get enabledPluginCount =>
      pluginList.where((p) => !disabledPluginNames.contains(p.name)).length;

  List<Plugin> get enabledPlugins =>
      pluginList.where((p) => !disabledPluginNames.contains(p.name)).toList();

  PluginsState copyWith({
    List<Plugin>? pluginList,
    List<PluginHTTPItem>? pluginHTTPList,
    Set<String>? disabledPluginNames,
    List<PluginSubscription>? subscriptions,
  }) {
    return PluginsState(
      pluginList: pluginList ?? this.pluginList,
      pluginHTTPList: pluginHTTPList ?? this.pluginHTTPList,
      disabledPluginNames: disabledPluginNames ?? this.disabledPluginNames,
      subscriptions: subscriptions ?? this.subscriptions,
    );
  }
}

class PluginsController extends Notifier<PluginsState> {
  static const List<String> bundledPluginAssets = [
    // 1. Haipee 规则 (36个官方及社区精选动漫/视频源)
    'assets/plugins/mutefun.json',
    'assets/plugins/dalvdm.json',
    'assets/plugins/anime7.json',
    'assets/plugins/DM84.json',
    'assets/plugins/xfdm.json',
    'assets/plugins/7sefun.json',
    'assets/plugins/AGE.json',
    'assets/plugins/AnFuns.json',
    'assets/plugins/Fantuan.json',
    'assets/plugins/LMM.json',
    'assets/plugins/MXdm.json',
    'assets/plugins/aafun.json',
    'assets/plugins/akianime.json',
    'assets/plugins/baimao.json',
    'assets/plugins/ciyuancheng.json',
    'assets/plugins/clicli.json',
    'assets/plugins/ezdmw.json',
    'assets/plugins/giriGiriLove.json',
    'assets/plugins/libvio.json',
    'assets/plugins/mandao.json',
    'assets/plugins/mengfan.json',
    'assets/plugins/mgnacg.json',
    'assets/plugins/mifun.json',
    'assets/plugins/milimili.json',
    'assets/plugins/moefan.json',
    'assets/plugins/moonci.json',
    'assets/plugins/nekodm.json',
    'assets/plugins/nyafun.json',
    'assets/plugins/omofun.json',
    'assets/plugins/qimi.json',
    'assets/plugins/skr.json',
    'assets/plugins/sorani.json',
    'assets/plugins/xfdmneo.json',
    'assets/plugins/xfdmnext.json',
    'assets/plugins/xiaobao.json',
    'assets/plugins/yinghua.json',
    // 2. MacCMS 规则 (24个主流苹果CMS V10 JSON 采集源)
    'assets/plugins/liangzi.json',
    'assets/plugins/ffzy.json',
    'assets/plugins/bfzy.json',
    'assets/plugins/jyzy.json',
    'assets/plugins/suoni.json',
    'assets/plugins/wolong.json',
    'assets/plugins/guangsu.json',
    'assets/plugins/kuaiche.json',
    'assets/plugins/hongniu.json',
    'assets/plugins/jisu.json',
    'assets/plugins/wujin.json',
    'assets/plugins/zuida.json',
    'assets/plugins/baiduyun.json',
    'assets/plugins/yinghuazy.json',
    'assets/plugins/shandian.json',
    'assets/plugins/xinlang.json',
    'assets/plugins/huya.json',
    'assets/plugins/piaoling.json',
    'assets/plugins/haitun.json',
    'assets/plugins/youzhi.json',
    'assets/plugins/ikun.json',
    'assets/plugins/subo.json',
    'assets/plugins/heimuer.json',
    'assets/plugins/zy360.json',
    // 3. TVBox 规则 (12个主流 TVBox 点播配置源)
    'assets/plugins/tvbox_guangsu.json',
    'assets/plugins/tvbox_wolong.json',
    'assets/plugins/tvbox_liangzi.json',
    'assets/plugins/tvbox_feifan.json',
    'assets/plugins/tvbox_baofeng.json',
    'assets/plugins/tvbox_jisu.json',
    'assets/plugins/tvbox_hongniu.json',
    'assets/plugins/tvbox_zuida.json',
    'assets/plugins/tvbox_haohua.json',
    'assets/plugins/tvbox_1080p.json',
    'assets/plugins/tvbox_suoni.json',
    'assets/plugins/tvbox_360.json',
    // 4. IPTV 规则 (12个主流 M3U/M3U8 全球与中文电视直播源)
    'assets/plugins/iptv.json',
    'assets/plugins/iptv_cn.json',
    'assets/plugins/iptv_zho.json',
    'assets/plugins/iptv_hk.json',
    'assets/plugins/iptv_tw.json',
    'assets/plugins/iptv_jp.json',
    'assets/plugins/iptv_us.json',
    'assets/plugins/iptv_anim.json',
    'assets/plugins/iptv_movies.json',
    'assets/plugins/iptv_music.json',
    'assets/plugins/iptv_fmm.json',
    'assets/plugins/iptv_yang.json',
    // 5. Piped 规则 (12个哔哩哔哩、抖音及全球 YouTube Piped 实例节点)
    'assets/plugins/bilibili.json',
    'assets/plugins/douyin.json',
    'assets/plugins/piped_kavin.json',
    'assets/plugins/piped_libre.json',
    'assets/plugins/piped_adminforge.json',
    'assets/plugins/piped_smnz.json',
    'assets/plugins/piped_drgns.json',
    'assets/plugins/piped_duinocoin.json',
    'assets/plugins/piped_privacydev.json',
    'assets/plugins/piped_projectsegfau.json',
    'assets/plugins/piped_darkness.json',
    'assets/plugins/piped_ngn.json',
    // 6. AList 规则 (12个主流 AList V3 聚合网盘搜索源)
    'assets/plugins/alist.json',
    'assets/plugins/alist_chirmyram.json',
    'assets/plugins/alist_xiaoya.json',
    'assets/plugins/alist_chuguang.json',
    'assets/plugins/alist_jlbx.json',
    'assets/plugins/alist_shenzjd.json',
    'assets/plugins/alist_hikerfans.json',
    'assets/plugins/alist_bashroot.json',
    'assets/plugins/alist_ecve.json',
    'assets/plugins/alist_zi0.json',
    'assets/plugins/alist_52qy.json',
    'assets/plugins/alist_haojia.json',
  ];

  bool _isDisposed = false;
  PluginsState _cachedState = const PluginsState();

  @override
  set state(PluginsState value) {
    _cachedState = value;
    if (!_isDisposed) {
      super.state = value;
    }
  }

  PluginsState get _currentState {
    try {
      final s = state;
      _cachedState = s;
      return s;
    } catch (_) {
      return _cachedState;
    }
  }

  void _setState(PluginsState newState) {
    state = newState;
  }

  @override
  PluginsState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    _cachedState = const PluginsState();
    Future.microtask(init);
    return _cachedState;
  }

  // 规则有效性追踪器
  final validityTracker = PluginValidityTracker();

  // 规则安装时间追踪器
  final installTimeTracker = PluginInstallTimeTracker();

  String pluginsFileName = "plugins.json";

  Directory? oldPluginDirectory;

  Directory? newPluginDirectory;

  List<Plugin> get pluginList => _currentState.pluginList;

  List<PluginHTTPItem> get pluginHTTPList => _currentState.pluginHTTPList;

  List<PluginSubscription> get subscriptions => _currentState.subscriptions;

  // Initializes the plugin directory and loads all plugins
  Future<void> init() async {
    try {
      _loadDisabledPlugins();
      _loadSubscriptions();
      final directory = await getApplicationSupportDirectory();
      if (_isDisposed) return;
      oldPluginDirectory = Directory('${directory.path}/plugins');
      if (!await oldPluginDirectory!.exists()) {
        try {
          await oldPluginDirectory!.create(recursive: true);
        } catch (_) {}
      }
      if (_isDisposed) return;
      newPluginDirectory = Directory('${directory.path}/plugins/v2');
      if (!await newPluginDirectory!.exists()) {
        try {
          await newPluginDirectory!.create(recursive: true);
        } catch (_) {}
      }
      if (_isDisposed) return;
      await loadAllPlugins();
      if (_isDisposed) return;
      await _loadInitialMarketCatalog();
    } catch (e, stack) {
      if (e is! MissingPluginException) {
        HaipeeLogger().log(Level.error, 'PluginsController init 异常: $e\n$stack');
      } else {
        HaipeeLogger().log(Level.debug, 'PluginsController init path_provider unavailable in test: $e');
      }
    }
  }

  Future<void> _loadInitialMarketCatalog() async {
    if (_currentState.pluginHTTPList.isEmpty) {
      try {
        final bundled = await PluginHTTP.loadBundledPluginList();
        if (bundled.isNotEmpty && _currentState.pluginHTTPList.isEmpty) {
          _setState(_currentState.copyWith(
            pluginHTTPList: List<PluginHTTPItem>.unmodifiable(bundled),
          ));
          HaipeeLogger().log(Level.info, '已就绪官方规则市场预置索引: ${bundled.length} 项');
        }
      } catch (_) {}
    }
  }

  // Loads all plugins from the directory, populates the plugin list, and saves to plugins.json if needed
  Future<void> loadAllPlugins() async {
    try {
      if (newPluginDirectory == null) return;
      HaipeeLogger()
          .log(Level.info, 'Plugins Directory: ${newPluginDirectory!.path}');
      if (await newPluginDirectory!.exists()) {
        final pluginsFile = File('${newPluginDirectory!.path}/$pluginsFileName');
        if (await pluginsFile.exists()) {
          try {
            final jsonString = await pluginsFile.readAsString();
            final plugins = getPluginListFromJson(jsonString);
            if (plugins.isNotEmpty) {
              await _ensureWorkingPlugins(plugins);
              _setPluginList(plugins);
              HaipeeLogger()
                  .log(Level.info, 'Current Plugin number: ${plugins.length}');
            } else {
              HaipeeLogger().log(Level.warning, 'plugins.json 为空或损坏，正在重置恢复预置规则');
              await resetAllBundledPlugins();
            }
          } catch (e) {
            HaipeeLogger().log(Level.error, '读取 plugins.json 失败, 尝试重置恢复预置规则: $e');
            await resetAllBundledPlugins();
          }
        } else {
          // No plugins.json
          var jsonFiles = await getPluginFiles();
          final List<Plugin> plugins = [];
          for (var filePath in jsonFiles) {
            try {
              final file = File(filePath);
              final jsonString = await file.readAsString();
              final data = jsonDecode(jsonString);
              final plugin = Plugin.fromJson(data);
              plugins.add(plugin);
              await file.delete(recursive: true);
            } catch (_) {}
          }
          await _ensureWorkingPlugins(plugins);
          _setPluginList(plugins);
          savePlugins();
        }
      } else {
        HaipeeLogger().log(Level.warning, 'Plugin directory does not exist');
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, 'loadAllPlugins 异常: $e');
    }
  }

  /// 确保关键高质量视频源（如 Maccms 影视源、IPTV、AList、mutefun, dalvdm）在本地规则列表中存在且无同名重复
  Future<void> _ensureWorkingPlugins(List<Plugin> plugins) async {
    bool changed = false;

    // 1. 先按规则名称去重（清理历史重复追加项）
    final seenNames = <String>{};
    final deduped = <Plugin>[];
    for (final p in plugins) {
      if (seenNames.add(p.name)) {
        deduped.add(p);
      } else {
        changed = true;
      }
    }
    if (changed) {
      plugins
        ..clear()
        ..addAll(deduped);
    }

    for (final assetPath in bundledPluginAssets) {
      try {
        String content;
        try {
          content = await rootBundle.loadString(assetPath);
        } catch (_) {
          content = File(assetPath).readAsStringSync();
        }
        final plugin = assetPath.endsWith('.yaml') || assetPath.endsWith('.yml')
            ? Plugin.fromYaml(content)
            : Plugin.fromJson(jsonDecode(content));
        final fileStem =
            assetPath.split('/').last.replaceAll(RegExp(r'\.(json|yaml|yml)$'), '');
        final existingIndex = plugins.indexWhere(
          (p) => p.name == plugin.name || p.name == fileStem,
        );
        if (existingIndex == -1) {
          plugins.add(plugin);
          changed = true;
          HaipeeLogger().log(Level.info, '已自动补充工作视频源: ${plugin.name}');
        } else if (fileStem == 'mutefun' || plugin.name == 'mutefun') {
          final p = plugins[existingIndex];
          // 若 mutefun 仍为旧版包含 voddetail 的 baseURL 或缺少 sourceTemplate，自动更新
          if (p.baseUrl.contains('/voddetail') ||
              p.searchApiConfig?['sourceTemplate'] == null) {
            plugins[existingIndex] = plugin;
            changed = true;
            HaipeeLogger().log(Level.info,
                '已自动升级 mutefun 规则为规范根域名与 sourceTemplate: ${plugin.baseUrl}');
          }
        }
      } catch (e) {
        HaipeeLogger().log(Level.warning, '加载预置规则失败 $assetPath: $e');
      }
    }

    if (changed) {
      _setPluginList(plugins);
      await savePlugins();
    }
  }

  @visibleForTesting
  Future<void> ensureWorkingPluginsForTesting(List<Plugin> plugins) =>
      _ensureWorkingPlugins(plugins);

  // Retrieves a list of JSON plugin file paths from the plugin directory
  Future<List<String>> getPluginFiles() async {
    try {
      if (oldPluginDirectory != null && await oldPluginDirectory!.exists()) {
        final jsonFiles = oldPluginDirectory!
            .listSync()
            .where((file) => file.path.endsWith('.json') && file is File)
            .map((file) => file.path)
            .toList();
        return jsonFiles;
      }
    } catch (_) {}
    return [];
  }

  // Copies plugin JSON files from the assets to the plugin directory
  Future<void> copyPluginsToExternalDirectory() async {
    List<String> jsonFiles = [];
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      jsonFiles = assets
          .where((String asset) =>
              asset.startsWith('assets/plugins/') &&
              (asset.endsWith('.json') ||
               asset.endsWith('.yaml') ||
               asset.endsWith('.yml')))
          .toList();
    } catch (_) {}
    if (jsonFiles.isEmpty) {
      jsonFiles = bundledPluginAssets;
    }

    final List<Plugin> plugins = [...pluginList];
    for (var filePath in jsonFiles) {
      try {
        final content = await rootBundle.loadString(filePath);
        final plugin = filePath.endsWith('.yaml') || filePath.endsWith('.yml')
            ? Plugin.fromYaml(content)
            : Plugin.fromJson(jsonDecode(content));
        if (!plugins.any((p) => p.name == plugin.name)) {
          plugins.add(plugin);
        }
      } catch (_) {}
    }
    _setPluginList(plugins);
    await savePlugins();
    HaipeeLogger().log(Level.info,
        '${plugins.length} plugin files saved to ${newPluginDirectory!.path}');
  }

  List<dynamic> pluginListToJson() {
    final List<dynamic> json = [];
    for (var plugin in pluginList) {
      json.add(plugin.toJson());
    }
    return json;
  }

  // Converts a JSON string into a list of Plugin objects safely.
  List<Plugin> getPluginListFromJson(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        HaipeeLogger().log(Level.warning, 'plugins.json 顶层非 List 结构');
        return [];
      }
      final List<Plugin> plugins = [];
      for (var j in decoded) {
        try {
          Plugin? p;
          if (j is Map<String, dynamic>) {
            p = Plugin.fromJson(j);
          } else if (j is Map) {
            p = Plugin.fromJson(Map<String, dynamic>.from(j));
          }
          if (p != null && p.name.trim().isNotEmpty) {
            plugins.add(p);
          }
        } catch (e) {
          HaipeeLogger().log(Level.warning, '解析单项规则失败: $e');
        }
      }
      return plugins;
    } catch (e) {
      HaipeeLogger().log(Level.error, '解析 plugins.json 失败: $e');
      return [];
    }
  }

  Future<void> removePlugin(Plugin plugin) async {
    final updated = pluginList.where((p) => p.name != plugin.name).toList();
    _setPluginList(updated);
    await savePlugins();
  }

  // Update or add plugin
  void updatePlugin(Plugin plugin) {
    final updated = [...pluginList];
    final index = updated.indexWhere((p) => p.name == plugin.name);
    if (index >= 0) {
      updated[index] = plugin;
    } else {
      updated.add(plugin);
    }
    _setPluginList(updated);
    savePlugins();
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updated = [...pluginList];
    final plugin = updated.removeAt(oldIndex);
    updated.insert(newIndex, plugin);
    _setPluginList(updated);
    savePlugins();
  }

  Future<void> savePlugins() async {
    if (newPluginDirectory == null) {
      return;
    }
    final jsonData = jsonEncode(pluginListToJson());
    final pluginsFile = File('${newPluginDirectory!.path}/$pluginsFileName');
    await pluginsFile.writeAsString(jsonData);
    HaipeeLogger().log(Level.info, '已更新源文件 $pluginsFileName');
  }

  Future<void> queryPluginHTTPList() async {
    var pluginHTTPListRes = await PluginHTTP.getPluginList();
    if (_isDisposed) {
      return;
    }
    _setState(_currentState.copyWith(
      pluginHTTPList: List<PluginHTTPItem>.unmodifiable(pluginHTTPListRes),
    ));
  }

  void setPluginHTTPList(List<PluginHTTPItem> list) {
    if (_isDisposed) return;
    _setState(_currentState.copyWith(
      pluginHTTPList: List<PluginHTTPItem>.unmodifiable(list),
    ));
  }

  Future<Plugin?> queryPluginHTTP(String name) async {
    Plugin? plugin;
    plugin = await PluginHTTP.getPlugin(name);
    return plugin;
  }

  String pluginStatus(PluginHTTPItem pluginHTTPItem) {
    String pluginStatus = 'install';
    for (Plugin plugin in pluginList) {
      if (pluginHTTPItem.name == plugin.name) {
        if (pluginHTTPItem.version == plugin.version) {
          pluginStatus = 'installed';
        } else {
          pluginStatus = 'update';
        }
        break;
      }
    }
    return pluginStatus;
  }

  String pluginUpdateStatus(Plugin plugin) {
    if (!pluginHTTPList.any((p) => p.name == plugin.name)) {
      return "nonexistent";
    }
    PluginHTTPItem p = pluginHTTPList.firstWhere(
      (p) => p.name == plugin.name,
    );
    return p.version == plugin.version ? "latest" : "updatable";
  }

  Future<int> tryUpdatePlugin(Plugin plugin) async {
    return await tryUpdatePluginByName(plugin.name);
  }

  Future<int> tryUpdatePluginByName(String name) async {
    var pluginHTTPItem = await queryPluginHTTP(name);
    if (pluginHTTPItem != null) {
      if (int.parse(pluginHTTPItem.api) > Api.apiLevel) {
        return 1;
      }
      updatePlugin(pluginHTTPItem);
      return 0;
    }
    return 2;
  }

  Future<int> tryUpdateAllPlugin() async {
    int count = 0;
    for (Plugin plugin in pluginList) {
      if (pluginUpdateStatus(plugin) == 'updatable') {
        if (await tryUpdatePlugin(plugin) == 0) {
          count++;
        }
      }
    }
    return count;
  }

  void removePlugins(Iterable<String> pluginNames) {
    final names = pluginNames.toSet();
    final updated = pluginList
        .where((plugin) => !names.contains(plugin.name))
        .toList();
    _setPluginList(updated);
    savePlugins();
  }

  static const List<String> bundledPluginNames = [
    'liangzi',
    '量子影视',
    'ffzy',
    '非凡影视',
    'bfzy',
    '暴风影视',
    'jyzy',
    '金鹰影视',
    'bilibili',
    'douyin',
    'iptv',
    '全球电视直播',
    'alist',
    'AList 聚合网盘',
    'mutefun',
    'dalvdm',
    'anime7',
    'DM84',
    'xfdm',
  ];

  bool isBundledPlugin(String name) {
    return bundledPluginNames.contains(name) ||
        bundledPluginAssets.any((a) =>
            a.contains('/$name.json') ||
            a.contains('/$name.yaml') ||
            a.contains('/$name.yml'));
  }

  bool isPluginEnabled(String name) {
    return _currentState.isPluginEnabled(name);
  }

  void _loadDisabledPlugins() {
    try {
      if (!GStorage.isSettingInitialized) return;
      final list = GStorage.setting.get(SettingBoxKey.disabledVideoPlugins, defaultValue: <dynamic>[]);
      if (list is List) {
        final disabled = list.map((e) => e.toString()).toSet();
        _setState(_currentState.copyWith(disabledPluginNames: disabled));
      }
    } catch (_) {}
  }

  void _saveDisabledPlugins(Set<String> disabled) {
    try {
      if (!GStorage.isSettingInitialized) return;
      GStorage.setting.put(SettingBoxKey.disabledVideoPlugins, disabled.toList());
    } catch (_) {}
  }

  void togglePluginEnabled(String name, bool enabled) {
    if (_isDisposed) return;
    try {
      final updated = Set<String>.from(_currentState.disabledPluginNames);
      if (enabled) {
        updated.remove(name);
      } else {
        updated.add(name);
      }
      _saveDisabledPlugins(updated);
      _setState(_currentState.copyWith(disabledPluginNames: updated));
    } catch (_) {}
  }

  void batchTogglePlugins(Iterable<String> names, bool enabled) {
    if (_isDisposed) return;
    try {
      final updated = Set<String>.from(_currentState.disabledPluginNames);
      if (enabled) {
        updated.removeAll(names);
      } else {
        updated.addAll(names);
      }
      _saveDisabledPlugins(updated);
      _setState(_currentState.copyWith(disabledPluginNames: updated));
    } catch (_) {}
  }

  // --- 在线规则源订阅 (Online Subscription) ---

  void _loadSubscriptions() {
    try {
      if (!GStorage.isSettingInitialized) return;
      final raw = GStorage.setting.get(SettingBoxKey.webRuleSubscriptions);
      if (raw != null) {
        final List<dynamic> list = raw is String ? jsonDecode(raw) : (raw as List);
        final subs = list
            .map((e) => PluginSubscription.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _setState(_currentState.copyWith(subscriptions: subs));
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '加载规则订阅列表失败: $e');
    }
  }

  Future<void> _saveSubscriptions(List<PluginSubscription> subs) async {
    try {
      if (!GStorage.isSettingInitialized) return;
      final jsonList = subs.map((s) => s.toJson()).toList();
      await GStorage.setting.put(SettingBoxKey.webRuleSubscriptions, jsonList);
      _setState(_currentState.copyWith(subscriptions: subs));
    } catch (e) {
      HaipeeLogger().log(Level.warning, '保存规则订阅列表失败: $e');
    }
  }

  /// 添加新的远程视频规则订阅
  Future<void> addSubscription(
    String name,
    String url, {
    bool syncImmediately = true,
  }) async {
    final cleanUrl = url.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : '在线视频规则订阅';
    final id = 'sub_${DateTime.now().millisecondsSinceEpoch}';

    final sub = PluginSubscription(
      id: id,
      name: cleanName,
      url: cleanUrl,
      enabled: true,
      lastSync: null,
      pluginCount: 0,
    );

    final updated = List<PluginSubscription>.from(_currentState.subscriptions)
      ..add(sub);
    await _saveSubscriptions(updated);

    if (syncImmediately) {
      await syncSubscription(id);
    }
  }

  /// 移除规则订阅
  Future<void> removeSubscription(String id) async {
    final updated =
        _currentState.subscriptions.where((s) => s.id != id).toList();
    await _saveSubscriptions(updated);
  }

  /// 同步单个规则订阅，拉取并批量导入规则
  Future<int> syncSubscription(String id) async {
    final index = _currentState.subscriptions.indexWhere((s) => s.id == id);
    if (index < 0) return 0;

    final sub = _currentState.subscriptions[index];
    try {
      final plugins = await PluginSubscription.fetchPluginsFromUrl(sub.url);
      if (plugins.isNotEmpty) {
        final importedCount = await addOrUpdatePlugins(plugins, enableAll: true);
        final updatedSub = sub.copyWith(
          lastSync: DateTime.now(),
          pluginCount: plugins.length,
        );
        final updatedSubs =
            List<PluginSubscription>.from(_currentState.subscriptions);
        updatedSubs[index] = updatedSub;
        await _saveSubscriptions(updatedSubs);
        return importedCount;
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, '同步订阅失败: ${sub.name} ($id): $e');
      rethrow;
    }
    return 0;
  }

  /// 一键同步全部已启用的在线规则源订阅
  Future<int> syncAllSubscriptions() async {
    int totalImported = 0;
    for (final sub in _currentState.subscriptions) {
      if (sub.enabled) {
        try {
          final count = await syncSubscription(sub.id);
          totalImported += count;
        } catch (_) {}
      }
    }
    return totalImported;
  }

  /// 批量导入或更新多条 Plugin 规则 (从文件多选、剪贴板数组或订阅源一键载入)
  Future<int> addOrUpdatePlugins(
    List<Plugin> plugins, {
    bool enableAll = true,
  }) async {
    if (plugins.isEmpty) return 0;

    final currentList = List<Plugin>.from(_currentState.pluginList);
    final disabledSet = Set<String>.from(_currentState.disabledPluginNames);
    int count = 0;

    for (final p in plugins) {
      if (p.name.trim().isEmpty) continue;
      final existingIndex = currentList.indexWhere((it) => it.name == p.name);
      if (existingIndex >= 0) {
        currentList[existingIndex] = p;
      } else {
        currentList.add(p);
      }
      if (enableAll) {
        disabledSet.remove(p.name);
      }
      count++;
    }

    _saveDisabledPlugins(disabledSet);
    _setPluginList(currentList);
    await savePlugins();
    HaipeeLogger().log(Level.info, '批量导入成功: $count 条规则，当前规则库总数: ${currentList.length}');
    return count;
  }

  /// 批量并发测试指定规则的连通性与可用性
  /// 测试通过（可用）的规则自动载入并开启，测试失败的置于禁用状态
  Future<Map<String, bool>> testAndAutoLoadPlugins({
    List<Plugin>? targets,
    String keyword = '海贼王',
    void Function(String name, PluginHealthStatus status)? onProgress,
  }) async {
    final list = targets ?? pluginList;
    if (list.isEmpty) return {};

    final results = <String, bool>{};
    final passedNames = <String>[];
    final failedNames = <String>[];

    // 并发分批探测，每批最多 3 个请求，避免并发过高触发风控或阻塞
    for (int i = 0; i < list.length; i += 3) {
      if (_isDisposed) break;
      final chunk =
          list.sublist(i, (i + 3 > list.length) ? list.length : i + 3);

      await Future.wait(chunk.map((plugin) async {
        validityTracker.markTesting(plugin.name);
        onProgress?.call(plugin.name, PluginHealthStatus.testing);

        final (isPassed, latency, error) = await plugin.testConnectivity();
        if (isPassed) {
          validityTracker.markValid(
            plugin.name,
            latencyMs: latency,
          );
          results[plugin.name] = true;
          passedNames.add(plugin.name);
          togglePluginEnabled(plugin.name, true);
          onProgress?.call(plugin.name, PluginHealthStatus.passed);
        } else {
          validityTracker.markInvalid(
            plugin.name,
            error: error ?? 'HTTP 响应异常',
            latencyMs: latency,
          );
          results[plugin.name] = false;
          failedNames.add(plugin.name);
          togglePluginEnabled(plugin.name, false);
          onProgress?.call(plugin.name, PluginHealthStatus.failed);
        }
      }));
    }

    return results;
  }


  Future<void> resetAllBundledPlugins() async {
    List<String> jsonFiles = [];
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      jsonFiles = assets
          .where((String asset) =>
              asset.startsWith('assets/plugins/') &&
              (asset.endsWith('.json') ||
               asset.endsWith('.yaml') ||
               asset.endsWith('.yml')))
          .toList();
    } catch (_) {}
    if (jsonFiles.isEmpty) {
      jsonFiles = bundledPluginAssets;
    }

    final List<Plugin> plugins = [...pluginList];
    for (var filePath in jsonFiles) {
      try {
        String content;
        try {
          content = await rootBundle.loadString(filePath);
        } catch (_) {
          content = File(filePath).readAsStringSync();
        }
        final plugin = filePath.endsWith('.yaml') || filePath.endsWith('.yml')
            ? Plugin.fromYaml(content)
            : Plugin.fromJson(jsonDecode(content));
        final idx = plugins.indexWhere((p) => p.name == plugin.name);
        if (idx >= 0) {
          plugins[idx] = plugin;
        } else {
          plugins.add(plugin);
        }
      } catch (_) {}
    }
    _setPluginList(plugins);
    await savePlugins();
  }

  Future<bool> resetSingleBundledPlugin(String name) async {
    for (final assetPath in bundledPluginAssets) {
      final assetName =
          assetPath.split('/').last.replaceAll(RegExp(r'\.(json|yaml|yml)$'), '');
      try {
        String content;
        try {
          content = await rootBundle.loadString(assetPath);
        } catch (_) {
          content = File(assetPath).readAsStringSync();
        }
        final plugin = assetPath.endsWith('.yaml') || assetPath.endsWith('.yml')
            ? Plugin.fromYaml(content)
            : Plugin.fromJson(jsonDecode(content));
        if (assetName == name || plugin.name == name) {
          updatePlugin(plugin);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  void _setPluginList(List<Plugin> plugins) {
    if (_isDisposed) {
      return;
    }
    final seen = <String>{};
    final deduped = <Plugin>[];
    for (final p in plugins) {
      if (seen.add(p.name)) {
        deduped.add(p);
      }
    }
    _setState(_currentState.copyWith(
      pluginList: List<Plugin>.unmodifiable(deduped),
    ));
  }
}
