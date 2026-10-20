# ADR 0008: Zero-Screenshot Development Architecture (无截图开发全链路工程架构)

## 状态 (Status)
**已接受 (Accepted)** - 2026-10-15

---

## 背景与痛点 (Context & Problem Statement)

在过去的辅助开发与调试流程中，曾出现使用操作系统的屏幕截图（如 macOS `screencapture`）以及基于盲点像素坐标的鼠标模拟点击（AppleScript / `CGEvent`）来进行验证的低效模式。

该模式在现代化 Flutter 工程开发中存在严重的致命缺陷，被明确定义为低质且不可靠的调试手段：
1. **像素而非语义 (Pixels vs. Semantics)**：截图捕获的仅是 GPU 光栅化后的瞬时像素，既无法反映 Flutter 的 Widget 树分层、RenderObject 布局约束、Flex 伸缩系数，也无法感知后台 Riverpod Provider 的状态流转。
2. **环境敏感与脆弱性 (Brittleness)**：Impeller/Metal 桌面端渲染受操作系统 Retina 缩放倍率、多屏 DPI、窗口层级遮挡等影响极大，像素匹配极其容易漂移失效。
3. **无法暴露深层异常**：当发生 `RenderFlex overflowed by X pixels`、网络超时或未捕获的 Dart 异步异常时，截图只能看到局部变形或转圈，无法输出调用栈与精确定位行号。
4. **验证周期漫长**：每次截图、保存、读取与人工/模型审图耗时多达数十秒，严重破坏敏捷调试节奏。

因此，必须在架构和工具链层面彻底根除截图依赖，确立纯代码级、自省式、确定性的**无截图开发架构 (Zero-Screenshot Development Architecture)**。

---

## 架构决策 (Architectural Decisions)

我们确立了**四层金字塔型无截图工程验证体系**：

```
                ┌──────────────────────────────────────────────┐
                │ 第 4 层: 结构化遥测与日志流 (AppLog / Telemetry)  │
                ├──────────────────────────────────────────────┤
                │ 第 3 层: 强语义 Key 与 Robot 机器人测试驱动    │
                ├──────────────────────────────────────────────┤
                │ 第 2 层: 运行态 VM Service JSON-RPC 自省 CLI │
                ├──────────────────────────────────────────────┤
                │ 第 1 层: 纯内存无头组件测试 (Headless WidgetTester)│
                └──────────────────────────────────────────────┘
```

### 1. 第 1 层：纯内存无头组件测试 (Headless WidgetTester & Responsive Pipeline)
- 基于 `flutter test`，完全脱离操作系统 GUI 窗口与真实显示器。
- 利用 Flutter 虚拟渲染管线，秒级模拟多端视口：
  - 桌面宽屏：`tester.view.physicalSize = const Size(1280, 800);`
  - 移动窄屏：`tester.view.physicalSize = const Size(375, 812);`
- 自动拦截并断言全应用零溢出：
  `expect(tester.takeException(), isNull);`
- 纯代码级断言文本、图标、布局层级与路由跳转。

### 2. 第 2 层：运行态 VM Service JSON-RPC 自省体系 (`tool/inspect_app.dart`)
- 引入官方 `package:vm_service`（`dev_dependencies`）。
- 建立工程常驻 CLI 工具 `tool/inspect_app.dart`，直连运行中的 Flutter 实例 WebSocket（`ws://127.0.0.1:<port>/<token>/ws`）：
  - `--check-overflow`：调用 `ext.flutter.inspector.getRootWidgetSummaryTree`，自动递归全屏节点，若有任意组件 `hasOverflow == true` 即刻报警并输出溢出节点与描述；全绿则断言通过。
  - `--find <query>`：通过组件类型、语义描述或 `Key` 在运行态秒级定位目标组件，输出对应节点结构与属性。
  - `--tree`：以精简树形打印当前界面的关键组件层级。
  - `--reload` / `--restart`：调用 `ext.flutter.reassemble` 触发毫秒级热重载，无需依赖终端标准输入。

### 3. 第 3 层：强语义 Key (`Key`) 与 Robot 机器人驱动体系
- 杜绝一切基于坐标的点击。核心业务组件全部赋予显式强类型 Key：
  - 元数据源站选择器：`Key('metadata_provider_selector')`
  - 5 大分类 Tab：`Key('catalog_tab_anime')`、`Key('catalog_tab_real')`、`Key('catalog_tab_game')`、`Key('catalog_tab_music')`、`Key('catalog_tab_book')`
  - 分类直搜动作芯片：`Key('catalog_chip_timeline')`、`Key('catalog_chip_search_real')`、`Key('catalog_chip_search_game')`、`Key('catalog_chip_search_music')`、`Key('catalog_chip_search_book')`
  - 详情页分流按钮：`Key('info_btn_search_torrent')`（全网BT搜索）、`Key('info_btn_watch_online')`（在线观看）、`Key('info_btn_universal_search')`（全网搜索资源）
  - 全网资源单选过滤器：`ValueKey('category_chip_video')`、`ValueKey('category_chip_game')` 等
- 依托 Robot 模式封装高阶交互动作，实现端到端业务流的代码级自运转。

### 4. 第 4 层：结构化遥测与日志汇流 (`AppLog` / Talker)
- 结合 `AppLog` 强类型模块标签，所有网络请求、子进程（Aria2、TorrServer）与渲染生命周期事件均实时记录。
- 通过结构化日志诊断代替人工肉眼观察。

---

## 落地成效与合规约束 (Consequences & Compliance)

1. **绝对禁令 (Strict Ban)**：
   - 严禁调用 `screencapture` 截图命令；
   - 严禁调用 AppleScript / Swift 模拟 OS 屏幕像素点击；
   - 严禁以“肉眼截图观察”作为需求验收手段。
2. **交付标准 (Acceptance Criteria)**：
   - 每一个 UI 或交互变更，必须通过 `flutter test` 组件测试断言通过；
   - 必须通过 `dart run tool/inspect_app.dart --check-overflow` 验证运行态 0 像素溢出；
   - `flutter analyze` 必须保持 0 issues。
