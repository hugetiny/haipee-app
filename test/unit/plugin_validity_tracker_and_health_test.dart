import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/main.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugin_validity_tracker.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/pages/info/source_search_provider.dart';

class TestablePluginsController extends PluginsController {
  final List<Plugin> initialList;
  TestablePluginsController(this.initialList);

  @override
  PluginsState build() {
    ref.onDispose(() {
      // ignore: invalid_use_of_protected_member
      // Trigger disposal state
    });
    return PluginsState(
      pluginList: initialList,
      disabledPluginNames: {},
    );
  }
}

void main() {
  group('PluginValidityTracker Health Tracking Tests', () {
    late PluginValidityTracker tracker;

    setUp(() {
      tracker = PluginValidityTracker();
    });

    test('Initial status is idle and no latency/error', () {
      expect(tracker.getStatus('test_plugin'), PluginHealthStatus.idle);
      expect(tracker.getLatency('test_plugin'), isNull);
      expect(tracker.getError('test_plugin'), isNull);
      expect(tracker.isSearchValid('test_plugin'), isFalse);
    });

    test('markTesting transitions status to testing', () {
      tracker.markTesting('test_plugin');
      expect(tracker.getStatus('test_plugin'), PluginHealthStatus.testing);
      expect(tracker.getRecord('test_plugin'), isNotNull);
      expect(tracker.getRecord('test_plugin')!.status, PluginHealthStatus.testing);
    });

    test('markValid records latency and marks search valid', () {
      tracker.markValid('test_plugin', latencyMs: 120);
      expect(tracker.getStatus('test_plugin'), PluginHealthStatus.passed);
      expect(tracker.getLatency('test_plugin'), 120);
      expect(tracker.getError('test_plugin'), isNull);
      expect(tracker.isSearchValid('test_plugin'), isTrue);
    });

    test('markInvalid records error and latency and clears search valid', () {
      tracker.markValid('test_plugin', latencyMs: 120);
      expect(tracker.isSearchValid('test_plugin'), isTrue);

      tracker.markInvalid('test_plugin', error: 'Connection timed out', latencyMs: 5000);
      expect(tracker.getStatus('test_plugin'), PluginHealthStatus.failed);
      expect(tracker.getLatency('test_plugin'), 5000);
      expect(tracker.getError('test_plugin'), 'Connection timed out');
      expect(tracker.isSearchValid('test_plugin'), isFalse);
    });

    test('clear resets all records and search valid set', () {
      tracker.markValid('p1', latencyMs: 50);
      tracker.markInvalid('p2', error: 'err');
      tracker.clear();

      expect(tracker.getStatus('p1'), PluginHealthStatus.idle);
      expect(tracker.getStatus('p2'), PluginHealthStatus.idle);
      expect(tracker.isSearchValid('p1'), isFalse);
    });
  });

  group('PluginsController testAndAutoLoadPlugins Tests', () {
    test('Empty plugins returns empty map immediately', () async {
      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([])),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(pluginsProvider.notifier);
      final res = await controller.testAndAutoLoadPlugins();
      expect(res, isEmpty);
    });

    test('Test failure automatically disables rule', () async {
      final badPlugin = Plugin(
        name: 'Invalid Endpoint Plugin',
        version: '1.0.0',
        type: 'xpath',
        api: 'http://127.0.0.1:9', // unreachable
        baseUrl: 'http://127.0.0.1:9',
        searchURL: 'http://127.0.0.1:9/search?q=@keyword',
        searchList: '//div',
        searchName: '//a',
        searchResult: '//a',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: false,
        useWebview: false,
        useNativePlayer: false,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([badPlugin])),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(pluginsProvider.notifier);
      expect(controller.isPluginEnabled(badPlugin.name), isTrue);

      final results = await controller.testAndAutoLoadPlugins(targets: [badPlugin]);
      expect(results[badPlugin.name], isFalse);
      expect(controller.validityTracker.getStatus(badPlugin.name), PluginHealthStatus.failed);
      expect(controller.isPluginEnabled(badPlugin.name), isFalse);
    });

    test('batchTogglePlugins enables previously disabled rules and persists state', () {
      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([])),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(pluginsProvider.notifier);

      // Initially rule1 and rule2 are enabled
      expect(controller.isPluginEnabled('rule1'), isTrue);
      expect(controller.isPluginEnabled('rule2'), isTrue);

      // Batch disable
      controller.batchTogglePlugins(['rule1', 'rule2'], false);
      expect(controller.isPluginEnabled('rule1'), isFalse);
      expect(controller.isPluginEnabled('rule2'), isFalse);

      // Batch enable
      controller.batchTogglePlugins(['rule1'], true);
      expect(controller.isPluginEnabled('rule1'), isTrue);
      expect(controller.isPluginEnabled('rule2'), isFalse);
    });

    test('Disposed controller handles toggle and batchToggle gracefully without throwing', () {
      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([])),
        ],
      );
      final controller = container.read(pluginsProvider.notifier);
      container.dispose();

      // Calling toggle on disposed controller should not throw
      expect(() => controller.togglePluginEnabled('rule1', false), returnsNormally);
      expect(() => controller.batchTogglePlugins(['rule1', 'rule2'], false), returnsNormally);
    });

    test('Chunked batch test immediately disables failed plugin during execution', () async {
      final badPlugin1 = Plugin(
        name: 'Fail1',
        version: '1.0.0',
        type: 'xpath',
        api: 'http://127.0.0.1:9',
        baseUrl: 'http://127.0.0.1:9',
        searchURL: 'http://127.0.0.1:9/fail1',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: false,
        useWebview: false,
        useNativePlayer: false,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([badPlugin1])),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(pluginsProvider.notifier);
      expect(controller.isPluginEnabled('Fail1'), isTrue);

      bool progressObservedDisabled = false;
      await controller.testAndAutoLoadPlugins(
        targets: [badPlugin1],
        onProgress: (name, status) {
          if (status == PluginHealthStatus.failed) {
            // When progress notification arrives, chunk completes and state is already disabled
            progressObservedDisabled = !controller.isPluginEnabled('Fail1');
          }
        },
      );

      expect(controller.isPluginEnabled('Fail1'), isFalse);
      expect(progressObservedDisabled, isTrue);
    });

    test('SourceSearchProvider strictly excludes disabled plugins from searchWithKeyword and refresh', () async {
      final p1 = Plugin(
        name: 'EnabledRule',
        version: '1.0.0',
        type: 'xpath',
        api: 'http://test',
        baseUrl: 'http://test',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: false,
        useWebview: false,
        useNativePlayer: false,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );
      final p2 = Plugin(
        name: 'DisabledRule',
        version: '1.0.0',
        type: 'xpath',
        api: 'http://test',
        baseUrl: 'http://test',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        muliSources: false,
        useWebview: false,
        useNativePlayer: false,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
      );

      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([p1, p2])),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(pluginsProvider.notifier);
      controller.togglePluginEnabled('DisabledRule', false);

      final notifier = container.read(sourceSearchProvider('CLANNAD').notifier);
      final state = container.read(sourceSearchProvider('CLANNAD'));
      expect(state.statuses.containsKey('EnabledRule'), isTrue);
      expect(state.statuses.containsKey('DisabledRule'), isFalse);

      await notifier.searchWithKeyword('海贼王');
      final updatedState = container.read(sourceSearchProvider('CLANNAD'));
      expect(updatedState.statuses.containsKey('EnabledRule'), isTrue);
      expect(updatedState.statuses.containsKey('DisabledRule'), isFalse);
    });
  });

  group('PluginsState Pure Selector & Enabled State Safety Tests', () {
    final p1 = Plugin(
      name: 'AlphaPlugin',
      version: '1.0.0',
      type: 'xpath',
      api: 'http://test',
      baseUrl: 'http://test',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: false,
      useWebview: false,
      useNativePlayer: false,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    );
    final p2 = Plugin(
      name: 'BetaPlugin',
      version: '1.0.0',
      type: 'xpath',
      api: 'http://test',
      baseUrl: 'http://test',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      referer: '',
      muliSources: false,
      useWebview: false,
      useNativePlayer: false,
      usePost: false,
      useLegacyParser: false,
      userAgent: '',
    );

    test('PluginsState helper methods work purely without Ref dependency', () {
      const stateEmpty = PluginsState();
      expect(stateEmpty.isPluginEnabled('AlphaPlugin'), isTrue);
      expect(stateEmpty.enabledPluginCount, 0);
      expect(stateEmpty.enabledPlugins, isEmpty);

      final stateWithPlugins = PluginsState(
        pluginList: [p1, p2],
        disabledPluginNames: {'BetaPlugin'},
      );
      expect(stateWithPlugins.isPluginEnabled('AlphaPlugin'), isTrue);
      expect(stateWithPlugins.isPluginEnabled('BetaPlugin'), isFalse);
      expect(stateWithPlugins.enabledPluginCount, 1);
      expect(stateWithPlugins.enabledPlugins.map((e) => e.name), ['AlphaPlugin']);
    });

    test('Riverpod select on enabledPluginCount evaluates cleanly during notification without throwing', () {
      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([p1, p2])),
        ],
      );
      addTearDown(container.dispose);

      int observedCount = -1;
      final sub = container.listen<int>(
        pluginsProvider.select((s) => s.enabledPluginCount),
        (previous, next) {
          observedCount = next;
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(observedCount, 2);

      final controller = container.read(pluginsProvider.notifier);
      controller.state = controller.state.copyWith(
        disabledPluginNames: {'BetaPlugin'},
      );

      expect(observedCount, 1);
    });

    test('Calling controller.isPluginEnabled inside Riverpod selector callback is safe and does not throw', () {
      final container = ProviderContainer(
        overrides: [
          pluginsProvider.overrideWith(() => TestablePluginsController([p1, p2])),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(pluginsProvider.notifier);
      int enabledMatches = -1;

      // This previously triggered Riverpod Ref._throwIfInvalidUsage: '_debugCallbackStack == 0'
      // because isPluginEnabled called AnyNotifier.state inside select.
      // Now decoupled through _currentState try-catch fallback.
      final sub = container.listen<int>(
        pluginsProvider.select((s) {
          return s.pluginList.where((p) => controller.isPluginEnabled(p.name)).length;
        }),
        (prev, next) {
          enabledMatches = next;
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(enabledMatches, 2);

      controller.togglePluginEnabled('AlphaPlugin', false);
      expect(enabledMatches, 1);
    });

    test('getPluginListFromJson gracefully handles corrupted, non-list, and partial JSON without throwing', () {
      final controller = PluginsController();

      // 1. Invalid syntax
      expect(controller.getPluginListFromJson('invalid { json'), isEmpty);

      // 2. Not a list
      expect(controller.getPluginListFromJson('{"key": "value"}'), isEmpty);
      expect(controller.getPluginListFromJson('"plain string"'), isEmpty);
      expect(controller.getPluginListFromJson('12345'), isEmpty);

      // 3. List with one malformed element and one valid plugin
      final validPluginJson = p1.toJson();
      final mixedList = jsonEncode([
        {'invalid_field': 123}, // missing required fields
        validPluginJson,
      ]);
      final parsed = controller.getPluginListFromJson(mixedList);
      expect(parsed.length, 1);
      expect(parsed.first.name, 'AlphaPlugin');
    });

    testWidgets('Global ErrorWidget.builder renders GeneralErrorWidget without red screen', (tester) async {
      final originalBuilder = ErrorWidget.builder;
      final originalFlutterOnError = FlutterError.onError;
      final originalPlatformOnError = PlatformDispatcher.instance.onError;

      try {
        setupGlobalErrorHandlers();

        final details = FlutterErrorDetails(
          exception: Exception('Test riverpod ProviderException simulation'),
          stack: StackTrace.current,
        );

        final widget = ErrorWidget.builder(details);
        expect(widget, isNotNull);
        expect(widget.runtimeType.toString(), contains('Directionality'));

        await tester.pumpWidget(widget);
        expect(find.byType(GeneralErrorWidget), findsOneWidget);
        expect(find.textContaining('Test riverpod ProviderException simulation'), findsOneWidget);
      } finally {
        ErrorWidget.builder = originalBuilder;
        FlutterError.onError = originalFlutterOnError;
        PlatformDispatcher.instance.onError = originalPlatformOnError;
      }
    });
  });
}
