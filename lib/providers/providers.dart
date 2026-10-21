// 统一导出所有 Riverpod Providers
// 按功能分类组织，方便统一导入
// 说明：部分页面级 Provider 使用 autoDispose（如 video、info、search），
// 在页面销毁时会自动清理状态以降低内存占用。
//
// 使用方式:
// ```dart
// import 'package:kazumi/providers/providers.dart';
//
// // 直接访问所有 Provider
// ref.read(popularProvider.notifier);
// ref.watch(videoProvider);
// ```

// ==================== 核心功能 Providers ====================
export 'package:kazumi/providers/riverpod_compat.dart';
export 'package:kazumi/pages/popular/providers.dart'; // popularProvider
export 'package:kazumi/pages/timeline/providers.dart'; // timelineProvider
export 'package:kazumi/pages/my/providers.dart'; // collectionsProvider, favoritesShowDeleteProvider, favoritesSyncingProvider
export 'package:kazumi/pages/history/providers.dart'; // historyProvider
export 'package:kazumi/pages/video/providers.dart'; // videoProvider, episodeCommentsProvider, selectedEpisodeProvider, showDebugLogProvider, etc.
export 'package:kazumi/pages/search/providers.dart'; // searchProvider
export 'package:kazumi/pages/info/providers.dart'; // bangumiInfoProvider, bangumiCommentsProvider, bangumiCharactersProvider, bangumiStaffsProvider

// ==================== 下载管理 Providers ====================
export 'package:kazumi/pages/download/providers.dart'; // downloadControllerProvider, downloadPageUIProvider, gopeedStatusProvider, filteredActiveTasksProvider, etc.

// ==================== 设置 Providers ====================
export 'package:kazumi/pages/setting/providers.dart'; // themeProvider, playerSettingsProvider, metadataSettingsProvider, localeSettingsProvider, showWindowButtonProvider
export 'package:kazumi/pages/settings/danmaku/providers.dart'; // danmakuSettingsProvider
export 'package:kazumi/pages/webdav_editor/providers.dart'; // webDavSettingsProvider

// ==================== 插件系统 Providers ====================
export 'package:kazumi/plugins/plugins_providers.dart'; // pluginsProvider, pluginEditorUIProvider, pluginShopUIProvider, pluginSelectionProvider

// ==================== 播放器相关 Providers ====================
export 'package:kazumi/pages/player/player_providers.dart'; // playerProvider
export 'package:kazumi/pages/webview/providers.dart'; // webviewItemControllerProvider

// ==================== 工具和辅助 Providers ====================
export 'package:kazumi/shaders/providers.dart'; // shadersControllerProvider
export 'package:kazumi/providers/media_suite_providers.dart'; // metadataClientProvider, metadataSyncControllerProvider
export 'package:kazumi/providers/translations_provider.dart'; // translationsProvider

/// ==================== Riverpod 最佳实践指南 ====================
///
/// 【Provider 选择】
/// 1. NotifierProvider - 推荐用于新代码（Riverpod 2.0+）
///    - 替代 StateNotifierProvider，语法更简洁
///    - 自动处理状态初始化
///
/// 2. StateNotifierProvider - 兼容旧代码
///    - 已有大量使用，保持向后兼容
///
/// 3. FutureProvider / AsyncNotifier - 异步数据获取
///    - 自动处理 loading / error / data 状态
///
/// 4. StreamProvider - 实时数据流
///    - WebSocket、Server-Sent Events
///    - 示例：downloadEventStreamProvider、downloadStatusStreamProvider
///
/// 5. Provider - 计算派生状态
///    - 从其他 Provider 派生的只读数据
///    - 示例：filteredActiveTasksProvider、downloadStatisticsProvider
///
/// 6. Provider.family - 参数化 Provider
///    - 需要动态参数的场景（如按 ID 查询）
///    - 示例：downloadTaskProvider、taskDetailStateProvider
///
/// 【命名规范】
/// - 控制器: xxxProvider（如 downloadControllerProvider）
/// - UI 状态: xxxUIProvider（如 downloadPageUIProvider）
/// - 异步数据: xxxFutureProvider / xxxStreamProvider
/// - 派生状态: filteredXxxProvider、xxxStatisticsProvider
///
/// 【状态管理】
/// - ref.watch() - 监听变化并重建 widget
/// - ref.read() - 一次性读取或触发操作
/// - ref.listen() - 监听变化执行副作用（如显示 toast）
/// - select() - 精确订阅特定字段，减少不必要的重建
///
/// 【性能优化】
/// 1. 使用 select 减少重建
///    ```dart
///    final isLoading = ref.watch(downloadControllerProvider.select((s) => s.isLoading));
///    ```
///
/// 2. 拆分 Provider 避免大状态
///    - 将独立功能拆分为独立 Provider
///    - 避免一个 Provider 管理所有状态
///
/// 3. 防抖和节流
///    - 频繁操作使用 Timer 防抖（参考 DownloadController._scheduleRefresh）
///    - 搜索输入使用节流
///
/// 4. 乐观更新提升响应速度
///    - 立即更新 UI 状态
///    - 异步操作完成后同步真实状态
///    - 失败时回滚（参考 DownloadController._optimisticUpdateTaskStatus）
///
/// 【生命周期】
/// - StateNotifier/Notifier 的 dispose 中释放资源
/// - Timer、StreamSubscription、StreamController 必须在 dispose 中取消/关闭
/// - 避免内存泄漏
///
/// 【实时通信模式（Stream）】
/// 1. 创建 StreamProvider 暴露事件流
///    ```dart
///    final downloadEventStreamProvider = StreamProvider<dynamic>((ref) {
///      final controller = ref.watch(downloadControllerProvider.notifier);
///      return controller.eventStream;
///    });
///    ```
///
/// 2. Controller 内部管理事件连接
///    ```dart
///    final StreamController<EventData> _eventStreamController =
///        StreamController<EventData>.broadcast();
///    Stream<EventData> get eventStream => _eventStreamController.stream;
///    ```
///
/// 3. 在 widget 中监听事件
///    ```dart
///    ref.listen(downloadEventStreamProvider, (previous, next) {
///      next.whenData((event) {
///        // 处理事件
///      });
///    });
///    ```
///
/// 【测试】
/// - Provider 易于 mock 和单元测试
/// - 使用 ProviderContainer 进行隔离测试
/// - 业务逻辑与 UI 分离便于测试
