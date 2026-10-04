import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 插件编辑器 UI 状态
///
/// 管理插件编辑器相关的 UI 状态
class PluginEditorUIState {
  final bool useLegacyParser; // 是否使用旧版解析器
  final bool usePost; // 是否使用 POST 请求
  final bool useNativePlayer; // 是否使用原生播放器

  const PluginEditorUIState({
    this.useLegacyParser = false,
    this.usePost = false,
    this.useNativePlayer = true,
  });

  PluginEditorUIState copyWith({
    bool? useLegacyParser,
    bool? usePost,
    bool? useNativePlayer,
  }) {
    return PluginEditorUIState(
      useLegacyParser: useLegacyParser ?? this.useLegacyParser,
      usePost: usePost ?? this.usePost,
      useNativePlayer: useNativePlayer ?? this.useNativePlayer,
    );
  }
}

/// 插件编辑器 UI 状态 Notifier
class PluginEditorUINotifier extends Notifier<PluginEditorUIState> {
  @override
  PluginEditorUIState build() => const PluginEditorUIState();

  void setUseLegacyParser(bool value) {
    state = state.copyWith(useLegacyParser: value);
  }

  void setUsePost(bool value) {
    state = state.copyWith(usePost: value);
  }

  void setUseNativePlayer(bool value) {
    state = state.copyWith(useNativePlayer: value);
  }
}

/// 插件编辑器 UI Provider
final pluginEditorUIProvider =
    NotifierProvider<PluginEditorUINotifier, PluginEditorUIState>(
  PluginEditorUINotifier.new,
);

/// 插件商店 UI 状态
///
/// 管理插件商店页面的加载、超时和排序状态
class PluginShopUIState {
  final bool isLoading;
  final bool isTimeout;
  final bool sortByName;

  const PluginShopUIState({
    this.isLoading = false,
    this.isTimeout = false,
    this.sortByName = false,
  });

  PluginShopUIState copyWith({
    bool? isLoading,
    bool? isTimeout,
    bool? sortByName,
  }) {
    return PluginShopUIState(
      isLoading: isLoading ?? this.isLoading,
      isTimeout: isTimeout ?? this.isTimeout,
      sortByName: sortByName ?? this.sortByName,
    );
  }
}

/// 插件商店 UI 状态 Notifier
class PluginShopUINotifier extends Notifier<PluginShopUIState> {
  @override
  PluginShopUIState build() => const PluginShopUIState();

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setTimeout(bool value) {
    state = state.copyWith(isTimeout: value);
  }

  void setSortByName(bool value) {
    state = state.copyWith(sortByName: value);
  }
}

/// 插件商店 UI Provider
final pluginShopUIProvider =
    NotifierProvider<PluginShopUINotifier, PluginShopUIState>(
  PluginShopUINotifier.new,
);

/// 插件多选模式状态
///
/// 管理插件列表的多选模式和选中项
class PluginSelectionState {
  final bool multiSelectMode;
  final Set<String> selectedNames;

  const PluginSelectionState({
    this.multiSelectMode = false,
    this.selectedNames = const {},
  });

  PluginSelectionState copyWith({
    bool? multiSelectMode,
    Set<String>? selectedNames,
  }) {
    return PluginSelectionState(
      multiSelectMode: multiSelectMode ?? this.multiSelectMode,
      selectedNames: selectedNames ?? this.selectedNames,
    );
  }
}

/// 插件多选状态 Notifier
class PluginSelectionNotifier extends Notifier<PluginSelectionState> {
  @override
  PluginSelectionState build() => const PluginSelectionState();

  void enableMultiSelect() {
    state = state.copyWith(multiSelectMode: true);
  }

  void disableMultiSelect() {
    state = const PluginSelectionState(
      multiSelectMode: false,
      selectedNames: {},
    );
  }

  void toggleSelection(String pluginName) {
    final selected = Set<String>.from(state.selectedNames);
    if (selected.contains(pluginName)) {
      selected.remove(pluginName);
    } else {
      selected.add(pluginName);
    }
    state = state.copyWith(selectedNames: selected);
  }

  void selectAll(Iterable<String> pluginNames) {
    state = state.copyWith(selectedNames: pluginNames.toSet());
  }

  void clearSelection() {
    state = state.copyWith(selectedNames: {});
  }
}

/// 插件多选状态 Provider
final pluginSelectionProvider =
    NotifierProvider<PluginSelectionNotifier, PluginSelectionState>(
  PluginSelectionNotifier.new,
);
