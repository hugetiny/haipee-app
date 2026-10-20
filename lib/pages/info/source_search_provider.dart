import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

enum PluginSearchStatus { pending, success, error }

class SourceSearchState {
  const SourceSearchState({
    required this.statuses,
    required this.results,
    required this.responseTimes,
    this.errors = const {},
  });

  factory SourceSearchState.initial(Iterable<String> pluginNames) {
    final statusMap = <String, PluginSearchStatus>{
      for (final name in pluginNames) name: PluginSearchStatus.pending,
    };
    final resultMap = <String, List<SearchItem>>{
      for (final name in pluginNames) name: const [],
    };
    final responseTimeMap = <String, int>{
      for (final name in pluginNames) name: 0,
    };
    return SourceSearchState(
      statuses: statusMap,
      results: resultMap,
      responseTimes: responseTimeMap,
      errors: const {},
    );
  }

  final Map<String, PluginSearchStatus> statuses;
  final Map<String, List<SearchItem>> results;
  final Map<String, int> responseTimes;
  final Map<String, String> errors;

  SourceSearchState setStatus(String pluginName, PluginSearchStatus status) {
    final updatedStatuses = Map<String, PluginSearchStatus>.from(statuses)
      ..[pluginName] = status;
    return SourceSearchState(
      statuses: updatedStatuses,
      results: results,
      responseTimes: responseTimes,
      errors: errors,
    );
  }

  SourceSearchState setError(String pluginName, String errorReason) {
    final updatedStatuses = Map<String, PluginSearchStatus>.from(statuses)
      ..[pluginName] = PluginSearchStatus.error;
    final updatedErrors = Map<String, String>.from(errors)
      ..[pluginName] = errorReason;
    return SourceSearchState(
      statuses: updatedStatuses,
      results: results,
      responseTimes: responseTimes,
      errors: updatedErrors,
    );
  }

  SourceSearchState setResults(String pluginName, List<SearchItem> data) {
    final updatedResults = Map<String, List<SearchItem>>.from(results)
      ..[pluginName] = List<SearchItem>.unmodifiable(data);
    return SourceSearchState(
      statuses: statuses,
      results: updatedResults,
      responseTimes: responseTimes,
      errors: errors,
    );
  }

  SourceSearchState setResponseTime(String pluginName, int time) {
    final updatedTimes = Map<String, int>.from(responseTimes)
      ..[pluginName] = time;
    return SourceSearchState(
      statuses: statuses,
      results: results,
      responseTimes: updatedTimes,
      errors: errors,
    );
  }

  SourceSearchState removePlugins(Iterable<String> pluginNames) {
    final names = pluginNames.toSet();
    final updatedStatuses = Map<String, PluginSearchStatus>.from(statuses)
      ..removeWhere((key, _) => names.contains(key));
    final updatedResults = Map<String, List<SearchItem>>.from(results)
      ..removeWhere((key, _) => names.contains(key));
    final updatedTimes = Map<String, int>.from(responseTimes)
      ..removeWhere((key, _) => names.contains(key));
    final updatedErrors = Map<String, String>.from(errors)
      ..removeWhere((key, _) => names.contains(key));
    return SourceSearchState(
      statuses: updatedStatuses,
      results: updatedResults,
      responseTimes: updatedTimes,
      errors: updatedErrors,
    );
  }

  SourceSearchState addPlugins(Iterable<String> pluginNames) {
    if (pluginNames.isEmpty) {
      return this;
    }
    final updatedStatuses = Map<String, PluginSearchStatus>.from(statuses);
    final updatedResults = Map<String, List<SearchItem>>.from(results);
    final updatedTimes = Map<String, int>.from(responseTimes);
    final updatedErrors = Map<String, String>.from(errors);
    for (final name in pluginNames) {
      updatedStatuses[name] = PluginSearchStatus.pending;
      updatedResults[name] = const <SearchItem>[];
      updatedTimes[name] = 0;
      updatedErrors.remove(name);
    }
    return SourceSearchState(
      statuses: updatedStatuses,
      results: updatedResults,
      responseTimes: updatedTimes,
      errors: updatedErrors,
    );
  }
}

final sourceSearchProvider = NotifierProvider.family<
    SourceSearchController, SourceSearchState, String>(
  (keyword) => SourceSearchController(keyword),
);

class SourceSearchController
    extends Notifier<SourceSearchState> {
  SourceSearchController(this._keyword);
  final String _keyword;
  late String _activeKeyword;
  late final PluginsController _pluginsController;
  ProviderSubscription<PluginsState>? _pluginSubscription;
  bool _isDisposed = false;

  @override
  SourceSearchState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _pluginSubscription?.close();
      _pluginSubscription = null;
    });

    _activeKeyword = _keyword;
    _pluginsController = ref.read(pluginsProvider.notifier);

    final pluginState = ref.read(pluginsProvider);
    final enabledPlugins = pluginState.pluginList
        .where((plugin) => _pluginsController.isPluginEnabled(plugin.name))
        .toList();
    final initialNames =
        enabledPlugins.map((plugin) => plugin.name).toList();

    if (enabledPlugins.isNotEmpty) {
      Future.microtask(
        () => _queryAll(enabledPlugins, _keyword),
      );
    }

    _pluginSubscription = ref.listen<PluginsState>(
      pluginsProvider,
      (previous, next) {
        if (_isDisposed) {
          return;
        }

        final prevNames = previous?.pluginList
                .where((plugin) =>
                    !previous.disabledPluginNames.contains(plugin.name))
                .map((plugin) => plugin.name)
                .toList() ??
            const [];
        final nextNames = next.pluginList
            .where((plugin) =>
                !next.disabledPluginNames.contains(plugin.name))
            .map((plugin) => plugin.name)
            .toList();

        if (listEquals(prevNames, nextNames)) {
          return;
        }

        final prevSet = prevNames.toSet();
        final nextSet = nextNames.toSet();
        final removed = prevSet.difference(nextSet);
        final added = nextSet.difference(prevSet);

        var updatedState = state;
        if (removed.isNotEmpty) {
          updatedState = updatedState.removePlugins(removed);
        }
        if (added.isNotEmpty) {
          updatedState = updatedState.addPlugins(added);
        }
        state = updatedState;

        if (added.isEmpty) {
          return;
        }

        final newPlugins = next.pluginList
            .where((plugin) => added.contains(plugin.name))
            .toList();
        if (newPlugins.isNotEmpty) {
          for (final plugin in newPlugins) {
            unawaited(
              _queryPlugin(
                plugin,
                _activeKeyword,
                clearExisting: true,
              ),
            );
          }
        }
      },
      fireImmediately: false,
    );

    return SourceSearchState.initial(initialNames);
  }

  Future<void> queryPlugin(
    String pluginName, {
    String? keywordOverride,
  }) async {
    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      return;
    }
    await _queryPlugin(
      plugin,
      keywordOverride ?? _keyword,
      clearExisting: true,
    );
  }

  Future<void> refresh() async {
    final pluginList = _pluginsController.pluginList
        .where((plugin) => _pluginsController.isPluginEnabled(plugin.name))
        .toList();
    if (pluginList.isEmpty) {
      return;
    }
    await _queryAll(pluginList, _activeKeyword);
  }

  Future<void> searchWithKeyword(String keyword) async {
    final pluginList = _pluginsController.pluginList
        .where((plugin) => _pluginsController.isPluginEnabled(plugin.name))
        .toList();
    if (pluginList.isEmpty) {
      return;
    }
    await _queryAll(pluginList, keyword);
  }

  Future<void> _queryAll(List<Plugin> pluginList, String keyword) async {
    _activeKeyword = keyword;
    for (final plugin in pluginList) {
      _markPending(plugin.name, clearExisting: true);
    }

    final tasks = pluginList
        .map((plugin) => _queryPlugin(plugin, keyword, clearExisting: false))
        .toList();
    await Future.wait(tasks);
  }

  Future<void> _queryPlugin(
    Plugin plugin,
    String keyword, {
    required bool clearExisting,
  }) async {
    if (_isDisposed) {
      return;
    }

    _markPending(plugin.name, clearExisting: clearExisting);

    final stopwatch = Stopwatch()..start();

    try {
      final response = await plugin.queryBangumi(keyword, shouldRethrow: true);
      stopwatch.stop();

      if (_isDisposed) {
        return;
      }
      if (response.data.isNotEmpty) {
        _pluginsController.validityTracker.markSearchValid(plugin.name);
      }
      _markSuccess(plugin.name, response.data, stopwatch.elapsedMilliseconds);
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      KazumiLogger().log(
        Level.warning,
        '源 ${plugin.name} 检索失败: $error',
      );
      String reason = '检索异常';
      if (error is DioException) {
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
            reason = '网络连接超时';
            break;
          case DioExceptionType.sendTimeout:
            reason = '请求发送超时';
            break;
          case DioExceptionType.receiveTimeout:
            reason = '响应接收超时';
            break;
          case DioExceptionType.badResponse:
            final code = error.response?.statusCode;
            reason = code != null ? 'HTTP错误 ($code)' : '服务器响应异常';
            break;
          case DioExceptionType.cancel:
            reason = '请求已取消';
            break;
          case DioExceptionType.badCertificate:
            reason = 'SSL证书校验失败';
            break;
          case DioExceptionType.connectionError:
            reason = '网络连接失败 / 域名无法解析';
            break;
          default:
            reason = '网络请求异常';
            break;
        }
      } else {
        final errStr = error.toString().split('\n').first.trim();
        if (errStr.isNotEmpty) {
          reason = errStr.length > 50 ? '${errStr.substring(0, 50)}...' : errStr;
        }
      }
      _markError(plugin.name, reason);
    }
  }

  void _markPending(String pluginName, {required bool clearExisting}) {
    var updatedState = state.setStatus(pluginName, PluginSearchStatus.pending);
    if (clearExisting) {
      updatedState = updatedState.setResults(pluginName, const []);
    }
    state = updatedState;
  }

  void _markSuccess(String pluginName, List<SearchItem> data, int responseTime) {
    state = state
        .setStatus(pluginName, PluginSearchStatus.success)
        .setResults(pluginName, data)
        .setResponseTime(pluginName, responseTime);
  }

  void _markError(String pluginName, [String? errorReason]) {
    state = state.setError(pluginName, errorReason ?? '检索失败');
  }

  Plugin? _findPlugin(String name) {
    for (final plugin in _pluginsController.pluginList) {
      if (plugin.name == name) {
        return plugin;
      }
    }
    return null;
  }
}
