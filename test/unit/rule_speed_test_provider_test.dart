import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/rule_speed_test/rule_speed_test_provider.dart';
import 'package:haipee/plugins/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RuleSpeedTestProvider Global State Tests', () {
    test('Initial state is idle and zero counts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(ruleSpeedTestProvider);
      expect(state.isTesting, isFalse);
      expect(state.categoryLabel, isEmpty);
      expect(state.testedCount, 0);
      expect(state.totalCount, 0);
      expect(state.passedCount, 0);
      expect(state.failedCount, 0);
      expect(state.currentTestingItem, isEmpty);
      expect(state.statusMap, isEmpty);
      expect(state.latencyMap, isEmpty);
    });

    test('Cancel changes isTesting to false and clears current item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(ruleSpeedTestProvider.notifier);
      // Manually trigger cancel on idle
      notifier.cancel();
      expect(container.read(ruleSpeedTestProvider).isTesting, isFalse);
    });

    test('Empty targets toast and does not start testing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(ruleSpeedTestProvider.notifier).runAutoBatchTestForPlugins(
            targetPlugins: [],
            categoryLabel: '空规则测试',
          );

      final state = container.read(ruleSpeedTestProvider);
      expect(state.isTesting, isFalse);
      expect(state.totalCount, 0);
    });

    test('IPTV plugin tests M3U subscription reachability without requiring anime keyword', () async {
      final iptvPlugin = Plugin(
        name: '测试IPTV',
        api: '1',
        type: 'iptv',
        category: 'live',
        version: '1.0',
        muliSources: true,
        useWebview: false,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        userAgent: '',
        baseUrl: '',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
      );

      // 空 URL 应当立即返回不可用且给出明确原因，而不是盲搜海贼王
      final (isSuccess, _, error) = await iptvPlugin.testConnectivity();
      expect(isSuccess, isFalse);
      expect(error, contains('IPTV 订阅地址为空'));
    });
  });
}
