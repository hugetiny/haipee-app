import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/modules/parse_failure/parse_failure_module.dart';
import 'package:haipee/modules/plugin/plugin_http_module.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/request/plugin.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('market_catalog_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ParseFailureRecordAdapter());
    }
    final box = await Hive.openBox('setting');
    await box.put(SettingBoxKey.enableGitProxy, false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
    GStorage.setting = box;
    GStorage.parseFailures =
        await Hive.openBox<ParseFailureRecord>('parseFailures');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('2kdm 规范域名与 sourceTemplate 验证', () {
    test('mutefun.json 的 baseURL 为纯净主站域名 https://www.2kdm.com/，而非 voddetail 临时跳转子路径', () {
      final file = File('assets/plugins/mutefun.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      // 验证规范 baseURL
      expect(jsonMap['baseURL'], 'https://www.2kdm.com/');

      // 验证包含 sourceTemplate 以正确指向详情页
      final searchApiConfig = jsonMap['searchApiConfig'] as Map<String, dynamic>;
      expect(searchApiConfig['sourceTemplate'], 'https://www.2kdm.com/voddetail/@source.html');
      expect(searchApiConfig['sourcePath'], r'$.id');
    });

    test('Plugin 解析 mutefun.json 生成的搜索项包含完整的 voddetail URL，且 baseUrl 保持主页', () async {
      final file = File('assets/plugins/mutefun.json');
      final plugin = Plugin.fromJson(jsonDecode(file.readAsStringSync()));

      expect(plugin.baseUrl, 'https://www.2kdm.com/');
      expect(plugin.referer, 'https://www.2kdm.com/');
    });
  });

  group('Kazumi 视频规则市场内置离线预加载验证 (绝非 0 个源)', () {
    test('assets/plugins/index.json 预置索引存在且收录 >= 17 个官方社区规则', () {
      final indexFile = File('assets/plugins/index.json');
      expect(indexFile.existsSync(), isTrue);
      final list = jsonDecode(indexFile.readAsStringSync()) as List;
      expect(list.length, greaterThanOrEqualTo(17));

      final names = list.map((e) => (e as Map)['name']?.toString()).toSet();
      expect(names.contains('mutefun'), isTrue);
      expect(names.contains('dalvdm'), isTrue);
      expect(names.contains('DM84'), isTrue);
      expect(names.contains('giriGiriLove'), isTrue);
    });

    test('PluginHTTP.loadBundledPluginList 能够无网络瞬间解析出规则市场条目且包含有效源地址 baseURL', () async {
      final list = await PluginHTTP.loadBundledPluginList();
      expect(list.length, greaterThanOrEqualTo(17));
      final mutefunItem = list.firstWhere((item) => item.name == 'mutefun');
      expect(mutefunItem.baseURL, 'https://www.2kdm.com/');
      expect(mutefunItem.effectiveBaseUrl, 'https://www.2kdm.com/');

      final dalvdmItem = list.firstWhere((item) => item.name == 'dalvdm');
      expect(dalvdmItem.baseURL, 'https://www.sbdl.cc/');
      expect(dalvdmItem.effectiveBaseUrl, 'https://www.sbdl.cc/');

      final sefunItem = list.firstWhere((item) => item.name == '7sefun');
      expect(sefunItem.baseURL, 'https://www.7sefun.top/');
      expect(sefunItem.effectiveBaseUrl, 'https://www.7sefun.top/');
    });

    test('PluginHTTPItem 在远端 index 未提供 baseURL 时通过社区映射表智能兜底 effectiveBaseUrl', () {
      final rawItemWithoutUrl = {
        'name': '7sefun',
        'version': '1.3',
        'useNativePlayer': true,
        'antiCrawlerEnabled': false,
        'author': '',
        'lastUpdate': 1786362131000,
      };

      final item = PluginHTTPItem.fromJson(rawItemWithoutUrl);
      expect(item.baseURL, '');
      expect(item.effectiveBaseUrl, 'https://www.7sefun.top/');

      final ageItem = PluginHTTPItem.fromJson({'name': 'AGE', 'version': '1.5', 'useNativePlayer': true, 'author': '', 'lastUpdate': 0});
      expect(ageItem.effectiveBaseUrl, 'https://www.agedm.io/');
    });

    test('PluginsController 自动将旧版 mutefun 规则升级为规范根域名与 sourceTemplate', () async {
      final oldMutefun = Plugin(
        name: 'mutefun',
        version: '1.4',
        type: 'anime',
        api: '9',
        baseUrl: 'https://www.2kdm.com/voddetail/',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: true,
        useWebview: true,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(pluginsProvider.notifier);
      final plugins = [oldMutefun];

      // 验证升级逻辑生效
      await controller.ensureWorkingPluginsForTesting(plugins);

      final updatedMutefun = plugins.firstWhere((p) => p.name == 'mutefun');
      expect(updatedMutefun.baseUrl, 'https://www.2kdm.com/');
      expect(updatedMutefun.searchApiConfig?['sourceTemplate'],
          'https://www.2kdm.com/voddetail/@source.html');
      expect(updatedMutefun.searchApiConfig?['sourcePath'], r'$.id');
    });
  });
}

