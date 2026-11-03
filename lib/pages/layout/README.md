# 全局 AppBar 架构迁移指南

## 概述

本项目已重构为**全局统一的 Scaffold + AppBar** 架构，所有页面共享一个 AppBar，样式完全统一。

## 架构说明

### 核心组件

1. **`ScaffoldMenu`** (`lib/pages/menu/menu.dart`)
   - 全局 Scaffold 容器
   - 通过 `ShellRoute` 包裹所有主要页面
   - 负责渲染统一的 AppBar 和底部导航栏

2. **`AppBarConfig`** (`lib/pages/layout/app_bar_config.dart`)
   - AppBar 配置模型
   - 包含标题、操作按钮、底部 Widget 等所有配置项

3. **`appBarConfigProvider`**
   - 全局 Riverpod StateProvider
   - 页面通过更新此 Provider 来配置 AppBar

## 页面迁移步骤

### 步骤 1：移除页面中的 Scaffold

**迁移前：**
```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: SysAppBar(
        title: Text('我的页面'),
        actions: [...],
      ),
      body: Column(...),
    );
  }
}
```

**迁移后：**
```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 直接返回 body 内容，不需要 Scaffold
    return Column(...);
  }
}
```

### 步骤 2：设置 AppBar 配置

有三种方式设置 AppBar 配置：

#### 方式 1：在 build 方法开始时设置（简单页面推荐）

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // 设置 AppBar 配置
  ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
    title: '我的页面',
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => context.push('/settings'),
      ),
    ],
    needTopOffset: false, // 统一使用 false
  );
  
  return Column(...);
}
```

#### 方式 2：使用生命周期方法（StatefulWidget 推荐）

```dart
class _MyPageState extends ConsumerState<MyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateAppBarConfig();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAppBarConfig();
  }

  void _updateAppBarConfig() {
    ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
      title: t.myPage.title,
      actions: [...],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(...);
  }
}
```

#### 方式 3：监听状态变化动态更新（动态内容推荐）

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(myStateProvider);
  
  // 监听状态变化，更新 AppBar
  ref.listen(myStateProvider, (previous, next) {
    if (mounted) {
      _updateAppBarConfig();
    }
  });
  
  return Column(...);
}

void _updateAppBarConfig() {
  final state = ref.read(myStateProvider);
  
  ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
    title: state.isEditMode ? '编辑模式' : '查看模式',
    actions: state.isEditMode ? editActions : viewActions,
  );
}
```

### 步骤 3：处理 FloatingActionButton

由于页面不再有自己的 Scaffold，需要使用 `Positioned` 或 `Stack` 来放置 FAB：

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  return Stack(
    children: [
      // 主要内容
      Column(...),
      
      // FloatingActionButton
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          onPressed: () => ...,
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
}
```

## AppBarConfig 配置项说明

```dart
AppBarConfig(
  // 标题 - 可以是 String 或 Widget
  title: '标题文本',  // 或 Text('标题')，或自定义 Widget
  
  // 右侧操作按钮列表
  actions: [
    IconButton(...),
    FilledButton.icon(...),
  ],
  
  // 左侧按钮（通常是返回按钮，可自定义）
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => context.pop(),
  ),
  
  // 底部 Widget（如 TabBar）
  bottom: TabBar(
    controller: tabController,
    tabs: [...],
  ),
  
  // 自定义工具栏高度（通常不需要设置，会自动计算）
  toolbarHeight: 56.0,
  
  // 是否需要顶部偏移（统一使用 false）
  needTopOffset: false,
  
  // 前导按钮宽度
  leadingWidth: 56.0,
  
  // 是否显示 AppBar（某些页面可能需要隐藏）
  visible: true,
)
```

## 特殊情况处理

### 隐藏 AppBar

某些页面可能不需要 AppBar（如启动页、全屏播放器）：

```dart
ref.read(appBarConfigProvider.notifier).state = const AppBarConfig.hidden();
```

或：

```dart
ref.read(appBarConfigProvider.notifier).state = const AppBarConfig(visible: false);
```

### 动态标题（如可点击的下拉菜单）

```dart
ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
  title: InkWell(
    onTap: showMenu,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('当前选项'),
        Icon(Icons.arrow_drop_down),
      ],
    ),
  ),
);
```

### TabBar 页面

```dart
ref.read(appBarConfigProvider.notifier).state = AppBarConfig(
  title: '标签页',
  bottom: TabBar(
    controller: _tabController,
    tabs: [
      Tab(text: '标签1'),
      Tab(text: '标签2'),
    ],
  ),
);

// Body 使用 TabBarView
return TabBarView(
  controller: _tabController,
  children: [...],
);
```

## 已迁移页面示例

### ✅ DownloadPage
- 使用方式 2（生命周期方法）
- 包含动态 TabBar
- 支持选择模式（动态切换 AppBar）
- 参考：`lib/pages/download/download_page.dart`

### ✅ PopularPage
- 使用方式 2（生命周期方法）
- 移除了 SliverAppBar，改为通用样式
- 可点击的标题（标签选择）
- 参考：`lib/pages/popular/popular_page.dart`

## 待迁移页面清单

- [ ] TimelinePage
- [ ] MyPage
- [ ] SettingPage
- [ ] HistoryPage
- [ ] FavoritesPage
- [ ] InfoPage
- [ ] VideoPage
- [ ] PlayerPage
- [ ] SearchPage
- [ ] LogsPage
- [ ] WebViewPage

## 迁移检查清单

迁移每个页面时，请确保：

- [ ] 移除了 `Scaffold` 包裹
- [ ] 移除了 `SysAppBar` 导入（不再需要）
- [ ] 添加了 `import 'package:haipee/pages/layout/app_bar_config.dart';`
- [ ] 在合适的位置设置 `appBarConfigProvider`
- [ ] 统一使用 `needTopOffset: false`
- [ ] FloatingActionButton 使用 `Stack` + `Positioned`
- [ ] 测试页面在手机和桌面的显示效果
- [ ] 测试 AppBar 的动态更新（如果适用）

## 优势总结

✅ **样式完全统一** - 所有页面的 AppBar 高度、样式一致
✅ **消除嵌套 Scaffold** - 性能更好，布局更清晰
✅ **代码更简洁** - 页面只关注内容，不需要管理 Scaffold
✅ **易于维护** - AppBar 配置集中管理，修改样式只需改一处
✅ **灵活性高** - 支持动态标题、动态操作按钮等各种需求

## 注意事项

⚠️ **重要**：所有页面必须在 `ShellRoute` 中才能使用全局 AppBar

⚠️ **不要设置 toolbarHeight**：除非有特殊需求，让 `SysAppBar` 自动计算高度

⚠️ **统一使用 needTopOffset: false**：确保所有页面样式一致

⚠️ **及时更新配置**：页面状态变化时，记得调用 `_updateAppBarConfig()`

## 问题排查

### AppBar 不显示
- 检查是否设置了 `appBarConfigProvider`
- 检查 `visible` 是否为 `true`

### AppBar 高度不对
- 移除自定义的 `toolbarHeight`
- 确保 `needTopOffset: false`

### AppBar 不更新
- 检查是否在状态变化时调用了更新方法
- 使用 `ref.listen` 监听状态变化

### TabBar 显示异常
- 确保 TabController 生命周期正确
- 检查 TabBar 和 TabBarView 的 tabs 数量是否一致

## 联系支持

如有问题，请检查已迁移页面的实现或查看本文档。