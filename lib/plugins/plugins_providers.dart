import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/plugins/plugins_controller.dart';

// ✅ 导出插件相关 UI 状态管理
export 'package:haipee/plugins/plugin_ui_state.dart';

/// 插件管理 Provider
///
/// 管理所有视频源插件的加载、更新和验证。
/// 负责插件的生命周期和有效性追踪。
///
/// 示例:
/// ```dart
/// final controller = ref.read(pluginsProvider.notifier);
/// await controller.updatePlugin(pluginName);
/// ```
final pluginsProvider =
    NotifierProvider<PluginsController, PluginsState>(PluginsController.new);
