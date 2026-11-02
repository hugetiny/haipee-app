import 'dart:async';
import 'package:haipee/modules/search/plugin_search_module.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';

/// [DEPRECATED] This class is deprecated and should not be used.
/// Use SourceSearchController from lib/pages/info/source_search_provider.dart instead.
/// This file is kept temporarily for reference but will be removed in a future update.
class QueryManager {
  QueryManager({
    required this.pluginsController,
  });

  final PluginsController pluginsController;
  StreamController<PluginSearchResponse>? _controller;
  bool _isCancelled = false;

  // Temporary storage to replace removed InfoController properties
  final List<PluginSearchResponse> _searchResponses = [];
  final Map<String, String> _searchStatus = {};

  Future<void> querySource(String keyword, String pluginName) async {
    final existingIndex = _searchResponses
        .indexWhere((response) => response.pluginName == pluginName);
    if (existingIndex != -1) {
      _searchResponses.removeAt(existingIndex);
    }
    _searchStatus[pluginName] = 'pending';
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        plugin.queryBangumi(keyword, shouldRethrow: true).then((result) {
          if (_isCancelled) return;

          _searchStatus[plugin.name] = 'success';
          if (result.data.isNotEmpty) {
            pluginsController.validityTracker.markSearchValid(plugin.name);
          }
          _searchResponses.add(result);
        }).catchError((error) {
          if (_isCancelled) return;

          _searchStatus[plugin.name] = 'error';
        });
      }
    }
  }

  Future<void> queryAllSource(String keyword) async {
    _controller = StreamController<PluginSearchResponse>();
    _searchResponses.clear();

    final enabledPlugins = pluginsController.pluginList
        .where((p) => pluginsController.isPluginEnabled(p.name));
    for (Plugin plugin in enabledPlugins) {
      _searchStatus[plugin.name] = 'pending';
    }

    for (Plugin plugin in enabledPlugins) {
      if (_isCancelled) return;

      plugin.queryBangumi(keyword, shouldRethrow: true).then((result) {
        if (_isCancelled) return;

        _searchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
        }
        _controller?.add(result);
      }).catchError((error) {
        if (_isCancelled) return;

        _searchStatus[plugin.name] = 'error';
      });
    }

    final controller = _controller;
    if (controller == null) {
      return;
    }
    await for (var result in controller.stream) {
      if (_isCancelled) break;

      _searchResponses.add(result);
    }
  }

  void cancel() {
    _isCancelled = true;
    _controller?.close();
    _controller = null;
  }
}
