# Haipee AI Agent Engineering Guide (AGENTS.md)

This document establishes the mandatory architectural standards and verification methodology for all AI agents (including DeepCoder, subagents, and automated assistants) working in the Haipee codebase.

---

## 1. 严格禁止截图开发准则 (Strict Zero-Screenshot Policy)

> [!CAUTION]
> **严禁在开发、排错、或验收过程中调用任何形式的屏幕截图！**
> - **禁止命令**：`screencapture`, `flutter screenshot`, 以及任何调用 OS 图像采集或 AppleScript/CGEvent 像素模拟点击的操作。
> - **禁止行为**：禁止通过保存/读取图片文件（`.png`, `.jpg`）让 AI 进行肉眼视觉审图。

### 为什么坚决废除截图模式？
1. **严重浪费 Token**：一张全高清/Retina 截图消耗海量 Vision/Image Token，迅速冲爆上下文窗口，成本高昂且毫无复用价值。
2. **信息低维且脆弱**：像素只是 GPU 光栅化后的瞬时显存镜像，无法反映 Flutter Widget 树结构、RenderObject 布局约束、Flex 伸缩系数、以及 Riverpod Provider 的状态流转。
3. **无法暴露深层 Bug**：当发生 `RenderFlex overflowed` 或未捕获的 Dart 异步异常时，截图只能看到局部截断或死循环转圈，无法输出堆栈行号。
4. **无法进 CI/CD**：纯靠人工/模型看图无法在无头服务器或自动化构建流水线中做回归拦截。

---

## 2. 现代主流 AI Flutter 确定性工程体系 (Mainstream AI Flutter Stack)

AI 开发 Flutter 的正确标准姿态是**全链路程序化确定性校验（Programmatic Deterministic Verification）**：

```
┌────────────────────────────────────────────────────────────────────────┐
│  第 4 层: 结构化遥测与单点事实日志流 (AppLog / SentryTalkerObserver)     │
├────────────────────────────────────────────────────────────────────────┤
│  第 3 层: 强类型语义 Key (Key('...')) 与自动化 Robot 机器人驱动测试       │
├────────────────────────────────────────────────────────────────────────┤
│  第 2 层: 运行态 Dart VM Service WebSocket 自省 CLI (tool/inspect_app) │
├────────────────────────────────────────────────────────────────────────┤
│  第 1 层: 纯内存无头组件测试体系 (Headless WidgetTester & flutter test)   │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 第 1 层：纯内存无头组件测试 (`flutter test`)
- 毫秒级构建虚拟渲染管线，完全脱离 OS 桌面弹窗和物理屏幕。
- 动态模拟多端视口：
  ```dart
  // 桌面宽屏
  tester.view.physicalSize = const Size(1280, 800);
  // 移动窄屏
  tester.view.physicalSize = const Size(375, 812);
  ```
- 自动拦截并断言全屏零溢出：
  ```dart
  expect(tester.takeException(), isNull);
  ```
- 通过 `find.byKey(...)`、`find.text(...)`、`find.byType(...)` 断言组件、层级与路由状态。

### 2.2 第 2 层：运行态 VM Service WebSocket 自省体系 (`tool/inspect_app.dart`)
在本地 Dev 模式运行应用时（`flutter run`），通过 Dart VM Service 端口直连 WebSocket 自省运行态：
```bash
# 1. 递归检测当前全屏是否存在任何 RenderFlex 像素溢出
dart tool/inspect_app.dart --check-overflow

# 2. 定位指定组件、文本、Key 的屏幕坐标、尺寸与属性
dart tool/inspect_app.dart --find "目标文本或组件名"

# 3. 打印当前界面的关键组件层级结构树
dart tool/inspect_app.dart --tree

# 4. 触发毫秒级热重载或热重启
dart tool/inspect_app.dart --reload
dart tool/inspect_app.dart --restart
```
> 输出结果全部为结构化纯文本与 JSON 数据，耗费极少 Token，100% 精准确定。

### 2.3 第 3 层：强语义 Key 契约
- 严禁任何盲点坐标点击。所有核心页面、Tab、功能按钮、单选芯片、输入框均必须赋予显式强类型 Key（如 `Key('catalog_tab_anime')`, `Key('info_btn_watch_online')`）。
- 自动化驱动通过 Key 进行交互和校验。

### 2.4 第 4 层：日志与遥测共存架构 (`AppLog` + `SentryFlutter`)
- **单一事实来源 (SSOT)**：所有业务模块统一使用 `AppLog` 输出带模块标记（`[LogModule]`）的结构化日志。
- **本地运维第一公民**：本地终端输出、本地 3×5MB 轮转文件落盘、应用内 F12 调试看板。
- **云端 APM 零耦合桥接**：`SentryService` 通过 `SentryTalkerObserver` 作为观察者接入。
  - 平常在本地环形缓冲区保留最近 30 条 Breadcrumbs，不浪费网络与配额。
  - 仅在触发致命崩溃或 `AppLog.error()` 时，附带 30 条上下文轨迹一次性上报。
  - 未配置 `SENTRY_DSN` 时自动完全空转（No-op），本地开发零性能影响。

---

## 3. 任务交付门禁 (Acceptance Criteria)

任何 AI 代理完成功能开发、修复缺陷或重构后，必须满足以下三项硬性检查才可宣告完成：

1. **静态代码分析**：
   ```bash
   flutter analyze
   ```
   必须保持 **0 errors, 0 warnings**。

2. **单元与组件自动化测试**：
   ```bash
   flutter test
   ```
   所有相关测试用例 100% 绿灯通过。

3. **运行态自省溢出检测（若处于本地启动联调中）**：
   ```bash
   dart tool/inspect_app.dart --check-overflow
   ```
   必须确认 **全界面 0 像素溢出 (Zero RenderFlex Overflows)**。
