import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/pages/info/source_search_provider.dart';

void main() {
  group('SourceSearchState error reason tracking', () {
    test('initial state has empty errors', () {
      final state = SourceSearchState.initial(['dalvdm', 'DM84']);
      expect(state.errors, isEmpty);
      expect(state.statuses['dalvdm'], PluginSearchStatus.pending);
      expect(state.statuses['DM84'], PluginSearchStatus.pending);
    });

    test('setError records human-readable error reason and error status', () {
      var state = SourceSearchState.initial(['dalvdm', 'DM84']);
      state = state.setError('dalvdm', '网络连接超时 (10秒)');

      expect(state.statuses['dalvdm'], PluginSearchStatus.error);
      expect(state.errors['dalvdm'], '网络连接超时 (10秒)');
      // Other plugin is unaffected
      expect(state.statuses['DM84'], PluginSearchStatus.pending);
      expect(state.errors['DM84'], isNull);
    });

    test('addPlugins and removePlugins correctly clean up error state', () {
      var state = SourceSearchState.initial(['dalvdm']);
      state = state.setError('dalvdm', 'HTTP错误 (502)');
      expect(state.errors['dalvdm'], 'HTTP错误 (502)');

      // Re-adding plugin clears its old error
      state = state.addPlugins(['dalvdm']);
      expect(state.statuses['dalvdm'], PluginSearchStatus.pending);
      expect(state.errors['dalvdm'], isNull);

      // Removing plugin removes its error entry
      state = state.setError('dalvdm', '连接失败');
      state = state.removePlugins(['dalvdm']);
      expect(state.errors.containsKey('dalvdm'), isFalse);
    });
  });
}
