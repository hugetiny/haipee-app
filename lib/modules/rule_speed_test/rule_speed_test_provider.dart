import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/cardigann/models/indexer_plugin.dart';
import 'package:haipee/plugins/plugin_validity_tracker.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';

/// 全局规则测速状态
class RuleSpeedTestState {
  final bool isTesting;
  final String categoryLabel;
  final int testedCount;
  final int totalCount;
  final int passedCount;
  final int failedCount;
  final String currentTestingItem;
  final Map<String, PluginHealthStatus> statusMap;
  final Map<String, int> latencyMap;
  final Map<String, String> errorMap;

  const RuleSpeedTestState({
    this.isTesting = false,
    this.categoryLabel = '',
    this.testedCount = 0,
    this.totalCount = 0,
    this.passedCount = 0,
    this.failedCount = 0,
    this.currentTestingItem = '',
    this.statusMap = const {},
    this.latencyMap = const {},
    this.errorMap = const {},
  });

  RuleSpeedTestState copyWith({
    bool? isTesting,
    String? categoryLabel,
    int? testedCount,
    int? totalCount,
    int? passedCount,
    int? failedCount,
    String? currentTestingItem,
    Map<String, PluginHealthStatus>? statusMap,
    Map<String, int>? latencyMap,
    Map<String, String>? errorMap,
  }) {
    return RuleSpeedTestState(
      isTesting: isTesting ?? this.isTesting,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      testedCount: testedCount ?? this.testedCount,
      totalCount: totalCount ?? this.totalCount,
      passedCount: passedCount ?? this.passedCount,
      failedCount: failedCount ?? this.failedCount,
      currentTestingItem: currentTestingItem ?? this.currentTestingItem,
      statusMap: statusMap ?? this.statusMap,
      latencyMap: latencyMap ?? this.latencyMap,
      errorMap: errorMap ?? this.errorMap,
    );
  }
}

/// 全局规则测速服务 Notifier
///
/// 无论用户切换到应用内的任何页面（视频直播、资源搜索、设置子分类等），
/// 测速与自动启用/禁用过程均在全局 Riverpod 容器后台持续执行，永不中断。
class RuleSpeedTestNotifier extends Notifier<RuleSpeedTestState> {
  bool _cancelled = false;

  static const _prefStatusKey = 'rule_speed_test_status_map';
  static const _prefLatencyKey = 'rule_speed_test_latency_map';
  static const _prefErrorKey = 'rule_speed_test_error_map';

  void _persistState() {
    try {
      if (GStorage.setting.isOpen) {
        final statusMapRaw = state.statusMap.map((k, v) => MapEntry(k, v.name));
        GStorage.setting.put(_prefStatusKey, statusMapRaw);
        GStorage.setting.put(_prefLatencyKey, state.latencyMap);
        GStorage.setting.put(_prefErrorKey, state.errorMap);
      }
    } catch (_) {}
  }

  (Map<String, PluginHealthStatus>, Map<String, int>, Map<String, String>) _loadPersisted() {
    try {
      if (GStorage.setting.isOpen) {
        final rawStatus = GStorage.setting.get(_prefStatusKey);
        final rawLatency = GStorage.setting.get(_prefLatencyKey);
        final rawError = GStorage.setting.get(_prefErrorKey);

        final statusMap = <String, PluginHealthStatus>{};
        if (rawStatus is Map) {
          rawStatus.forEach((k, v) {
            final key = k.toString();
            final name = v.toString();
            if (name == 'passed') {
              statusMap[key] = PluginHealthStatus.passed;
            } else if (name == 'failed') {
              statusMap[key] = PluginHealthStatus.failed;
            } else if (name == 'testing') {
              statusMap[key] = PluginHealthStatus.testing;
            } else {
              statusMap[key] = PluginHealthStatus.idle;
            }
          });
        }

        final latencyMap = <String, int>{};
        if (rawLatency is Map) {
          rawLatency.forEach((k, v) {
            if (v is num) latencyMap[k.toString()] = v.toInt();
          });
        }

        final errorMap = <String, String>{};
        if (rawError is Map) {
          rawError.forEach((k, v) {
            errorMap[k.toString()] = v.toString();
          });
        }

        return (statusMap, latencyMap, errorMap);
      }
    } catch (_) {}
    return (const {}, const {}, const {});
  }

  @override
  RuleSpeedTestState build() {
    final (statusMap, latencyMap, errorMap) = _loadPersisted();
    // 异步同步到 validityTracker，确保旧组件与新状态完全一致
    Future.microtask(() {
      try {
        final pluginsCtrl = ref.read(pluginsProvider.notifier);
        statusMap.forEach((name, status) {
          if (status == PluginHealthStatus.passed) {
            pluginsCtrl.validityTracker.markValid(name, latencyMs: latencyMap[name]);
          } else if (status == PluginHealthStatus.failed) {
            pluginsCtrl.validityTracker.markInvalid(name, error: errorMap[name], latencyMs: latencyMap[name]);
          }
        });
      } catch (_) {}
    });
    return RuleSpeedTestState(
      statusMap: statusMap,
      latencyMap: latencyMap,
      errorMap: errorMap,
    );
  }

  /// 取消当前正在执行的全局后台测速
  void cancel() {
    if (state.isTesting) {
      _cancelled = true;
      state = state.copyWith(
        isTesting: false,
        currentTestingItem: '',
      );
      HaipeeDialog.showToast(message: '已终止当前规则测速');
    }
  }

  /// 并发分批测速视频/直播/网盘规则（Haipee、MacCMS、TVBox、IPTV、Piped、AList）
  Future<void> runAutoBatchTestForPlugins({
    required List<Plugin> targetPlugins,
    String categoryLabel = '规则',
  }) async {
    if (state.isTesting) {
      HaipeeDialog.showToast(message: '已有规则测速正在后台进行中 (${state.testedCount}/${state.totalCount})');
      return;
    }
    if (targetPlugins.isEmpty) {
      HaipeeDialog.showToast(message: '当前分类暂无可测速规则');
      return;
    }

    _cancelled = false;
    final initialStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
    for (final p in targetPlugins) {
      initialStatus[p.name] = PluginHealthStatus.idle;
    }

    state = state.copyWith(
      isTesting: true,
      categoryLabel: categoryLabel,
      testedCount: 0,
      totalCount: targetPlugins.length,
      passedCount: 0,
      failedCount: 0,
      currentTestingItem: '',
      statusMap: initialStatus,
    );

    int passed = 0;
    int failed = 0;
    int tested = 0;
    final pluginsCtrl = ref.read(pluginsProvider.notifier);

    try {
      const chunkSize = 3;
      for (int i = 0; i < targetPlugins.length; i += chunkSize) {
        if (_cancelled) break;
        final chunk = targetPlugins.sublist(
          i,
          (i + chunkSize > targetPlugins.length) ? targetPlugins.length : i + chunkSize,
        );

        // 更新当前测试项名称
        state = state.copyWith(
          currentTestingItem: chunk.map((p) => p.name).join(', '),
        );

        await Future.wait(chunk.map((plugin) async {
          if (_cancelled) return;

          final currentStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
          currentStatus[plugin.name] = PluginHealthStatus.testing;
          pluginsCtrl.validityTracker.markTesting(plugin.name);
          state = state.copyWith(statusMap: currentStatus);

          final (isPassed, latency, error) = await plugin.testConnectivity();
          if (isPassed) {
            passed++;
            tested++;
            pluginsCtrl.validityTracker.markValid(
              plugin.name,
              latencyMs: latency,
            );
            pluginsCtrl.togglePluginEnabled(plugin.name, true);

            final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
            final updatedLatency = Map<String, int>.from(state.latencyMap);
            updatedStatus[plugin.name] = PluginHealthStatus.passed;
            updatedLatency[plugin.name] = latency;

            state = state.copyWith(
              testedCount: tested,
              passedCount: passed,
              statusMap: updatedStatus,
              latencyMap: updatedLatency,
            );
          } else {
            failed++;
            tested++;
            pluginsCtrl.validityTracker.markInvalid(
              plugin.name,
              error: error ?? 'HTTP 响应异常',
              latencyMs: latency,
            );
            pluginsCtrl.togglePluginEnabled(plugin.name, false);

            final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
            final updatedLatency = Map<String, int>.from(state.latencyMap);
            final updatedError = Map<String, String>.from(state.errorMap);
            updatedStatus[plugin.name] = PluginHealthStatus.failed;
            updatedLatency[plugin.name] = latency;
            updatedError[plugin.name] = error ?? 'HTTP 响应异常';

            state = state.copyWith(
              testedCount: tested,
              failedCount: failed,
              statusMap: updatedStatus,
              latencyMap: updatedLatency,
              errorMap: updatedError,
            );
          }
        }));
      }

      if (!_cancelled) {
        HaipeeDialog.showToast(
          message:
              '$categoryLabel测速完成：$passed 个可用已自动启用${failed > 0 ? "，$failed 个不可用已自动禁用" : ""}',
        );
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, '全局规则测速异常: $e');
    } finally {
      _persistState();
      state = state.copyWith(
        isTesting: false,
        currentTestingItem: '',
      );
    }
  }

  /// 并发分批测速 Cardigann 种子/磁力规则
  Future<void> runAutoBatchTestForIndexers({
    required List<IndexerPlugin> targets,
    String categoryLabel = 'Cardigann 规则',
  }) async {
    if (state.isTesting) {
      HaipeeDialog.showToast(message: '已有规则测速正在后台进行中 (${state.testedCount}/${state.totalCount})');
      return;
    }
    if (targets.isEmpty) {
      HaipeeDialog.showToast(message: '当前暂无可测速的 Cardigann 规则');
      return;
    }

    _cancelled = false;
    final initialStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
    for (final p in targets) {
      initialStatus[p.id] = PluginHealthStatus.idle;
    }

    state = state.copyWith(
      isTesting: true,
      categoryLabel: categoryLabel,
      testedCount: 0,
      totalCount: targets.length,
      passedCount: 0,
      failedCount: 0,
      currentTestingItem: '',
      statusMap: initialStatus,
    );

    int passed = 0;
    int failed = 0;
    int tested = 0;
    final notifier = ref.read(indexerPluginsProvider.notifier);

    try {
      const chunkSize = 3;
      for (int i = 0; i < targets.length; i += chunkSize) {
        if (_cancelled) break;
        final chunk = targets.sublist(
          i,
          (i + chunkSize > targets.length) ? targets.length : i + chunkSize,
        );

        state = state.copyWith(
          currentTestingItem: chunk.map((p) => p.name).join(', '),
        );

        await Future.wait(chunk.map((plugin) async {
          if (_cancelled) return;

          final currentStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
          currentStatus[plugin.id] = PluginHealthStatus.testing;
          state = state.copyWith(statusMap: currentStatus);

          final stopwatch = Stopwatch()..start();
          try {
            final executor = CardigannQueryExecutor();
            await executor
                .search(
                  plugin.definition,
                  '1080p',
                  userConfig: plugin.settings,
                  customBaseUrl: plugin.customBaseUrl,
                  throwOnError: true,
                )
                .timeout(const Duration(seconds: 8));
            stopwatch.stop();

            passed++;
            tested++;
            await notifier.togglePlugin(plugin.id, true);

            final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
            final updatedLatency = Map<String, int>.from(state.latencyMap);
            updatedStatus[plugin.id] = PluginHealthStatus.passed;
            updatedLatency[plugin.id] = stopwatch.elapsedMilliseconds;

            state = state.copyWith(
              testedCount: tested,
              passedCount: passed,
              statusMap: updatedStatus,
              latencyMap: updatedLatency,
            );
          } catch (e) {
            stopwatch.stop();
            failed++;
            tested++;
            await notifier.togglePlugin(plugin.id, false);

            final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
            final updatedLatency = Map<String, int>.from(state.latencyMap);
            final updatedError = Map<String, String>.from(state.errorMap);
            updatedStatus[plugin.id] = PluginHealthStatus.failed;
            updatedLatency[plugin.id] = stopwatch.elapsedMilliseconds;
            updatedError[plugin.id] = e.toString();

            state = state.copyWith(
              testedCount: tested,
              failedCount: failed,
              statusMap: updatedStatus,
              latencyMap: updatedLatency,
              errorMap: updatedError,
            );
          }
        }));
      }

      if (!_cancelled) {
        HaipeeDialog.showToast(
          message:
              '$categoryLabel测速完成：$passed 个可用已自动启用${failed > 0 ? "，$failed 个不可用已自动禁用" : ""}',
        );
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, 'Cardigann 规则测速异常: $e');
    } finally {
      _persistState();
      state = state.copyWith(
        isTesting: false,
        currentTestingItem: '',
      );
    }
  }

  /// 单条规则独立重测（视频/直播/网盘规则）
  Future<void> retestSinglePlugin(Plugin plugin) async {
    final currentStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
    currentStatus[plugin.name] = PluginHealthStatus.testing;
    state = state.copyWith(statusMap: currentStatus);

    HaipeeDialog.showLoading(msg: '正在后台测试【${plugin.name}】连通性...');
    final pluginsCtrl = ref.read(pluginsProvider.notifier);
    pluginsCtrl.validityTracker.markTesting(plugin.name);

    final (isPassed, latency, error) = await plugin.testConnectivity();
    HaipeeDialog.dismiss();

    if (isPassed) {
      pluginsCtrl.validityTracker.markValid(
        plugin.name,
        latencyMs: latency,
      );
      pluginsCtrl.togglePluginEnabled(plugin.name, true);

      final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
      final updatedLatency = Map<String, int>.from(state.latencyMap);
      updatedStatus[plugin.name] = PluginHealthStatus.passed;
      updatedLatency[plugin.name] = latency;

      state = state.copyWith(
        statusMap: updatedStatus,
        latencyMap: updatedLatency,
      );
      _persistState();
      HaipeeDialog.showToast(
        message: '【${plugin.name}】测速通过 (${latency}ms)，已自动启用',
      );
    } else {
      pluginsCtrl.validityTracker.markInvalid(
        plugin.name,
        error: error ?? 'HTTP 响应异常',
        latencyMs: latency,
      );
      pluginsCtrl.togglePluginEnabled(plugin.name, false);

      final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
      final updatedLatency = Map<String, int>.from(state.latencyMap);
      final updatedError = Map<String, String>.from(state.errorMap);
      updatedStatus[plugin.name] = PluginHealthStatus.failed;
      updatedLatency[plugin.name] = latency;
      updatedError[plugin.name] = error ?? 'HTTP 响应异常';

      state = state.copyWith(
        statusMap: updatedStatus,
        latencyMap: updatedLatency,
        errorMap: updatedError,
      );
      _persistState();
      HaipeeDialog.showToast(
        message: '【${plugin.name}】测速未通过${error != null ? ': $error' : ''}，已自动禁用',
      );
    }
  }

  /// 单条规则独立重测（Cardigann 种子规则）
  Future<void> retestSingleIndexer(IndexerPlugin plugin) async {
    final currentStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
    currentStatus[plugin.id] = PluginHealthStatus.testing;
    state = state.copyWith(statusMap: currentStatus);

    HaipeeDialog.showLoading(msg: '正在后台测试【${plugin.name}】连通性...');
    final notifier = ref.read(indexerPluginsProvider.notifier);

    final stopwatch = Stopwatch()..start();
    try {
      final executor = CardigannQueryExecutor();
      await executor
          .search(
            plugin.definition,
            '1080p',
            userConfig: plugin.settings,
            customBaseUrl: plugin.customBaseUrl,
            throwOnError: true,
          )
          .timeout(const Duration(seconds: 8));
      stopwatch.stop();
      HaipeeDialog.dismiss();

      await notifier.togglePlugin(plugin.id, true);

      final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
      final updatedLatency = Map<String, int>.from(state.latencyMap);
      updatedStatus[plugin.id] = PluginHealthStatus.passed;
      updatedLatency[plugin.id] = stopwatch.elapsedMilliseconds;

      state = state.copyWith(
        statusMap: updatedStatus,
        latencyMap: updatedLatency,
      );
      _persistState();
      HaipeeDialog.showToast(
        message: '【${plugin.name}】测速通过 (${stopwatch.elapsedMilliseconds}ms)，已自动启用',
      );
    } catch (e) {
      stopwatch.stop();
      HaipeeDialog.dismiss();

      await notifier.togglePlugin(plugin.id, false);

      final updatedStatus = Map<String, PluginHealthStatus>.from(state.statusMap);
      final updatedLatency = Map<String, int>.from(state.latencyMap);
      final updatedError = Map<String, String>.from(state.errorMap);
      updatedStatus[plugin.id] = PluginHealthStatus.failed;
      updatedLatency[plugin.id] = stopwatch.elapsedMilliseconds;
      updatedError[plugin.id] = e.toString();

      state = state.copyWith(
        statusMap: updatedStatus,
        latencyMap: updatedLatency,
        errorMap: updatedError,
      );
      _persistState();
      HaipeeDialog.showToast(
        message: '【${plugin.name}】测速未通过，已自动禁用',
      );
    }
  }
}

/// 全局规则测速 Provider（常驻后台，跨页面永不中断）
final ruleSpeedTestProvider =
    NotifierProvider<RuleSpeedTestNotifier, RuleSpeedTestState>(
  RuleSpeedTestNotifier.new,
);
