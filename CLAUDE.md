# Haipee Developer & AI Agent Guide (CLAUDE.md)

Haipee is a cross-platform anime and video aggregator built with Flutter and Dart.
This file serves as the definitive reference for Claude Code and coding agents working on Haipee.

---

## 1. 严格禁止截图准则 (Strict Zero-Screenshot Policy)

- **严禁任何形式的屏幕截图**：禁止调用 `screencapture`、`flutter screenshot` 或读取 UI 像素图片。
- **全链路程序化确定性校验体系**：
  1. **第 1 层：纯内存无头组件测试**：`flutter test`（毫秒级虚拟渲染管线，断言无溢出与结构状态）。
  2. **第 2 层：运行态 VM Service WebSocket 自省**：`dart tool/inspect_app.dart --check-overflow`（0 像素溢出保证）。
  3. **第 3 层：强语义 Key 契约**：所有交互组件使用明确的 `Key('...')`，严禁盲点坐标点击。
  4. **第 4 层：单点事实日志流**：统一使用 `AppLog` 带有 `[LogModule]` 标记。

---

## 2. 官方原生 Dart MCP Server (`dart mcp-server`)

Dart SDK 自带原生 Model Context Protocol (MCP) 服务端，已配置至 `.cursor/mcp.json`、`.vscode/mcp.json` 与 `~/.claude.json`。
常用原生工具：
- `analyze_files`：通过 Analysis Server 毫秒级分析文件，避免全量编译等待。
- `hot_reload` / `hot_restart`：热重载/热重启本地运行的 Flutter 应用。
- `widget_inspector`：程序化抓取当前界面的 Widget 树与约束结构。
- `get_runtime_errors` / `get_app_logs`：实时获取应用运行态错误与日志。
- `run_tests`：直接执行单元或组件测试用例。

---

## 3. 核心架构与业务铁则

### 3.1 统一单下载引擎：Gopeed 2.0 FFI (化繁为简)
- **彻底摒弃 Aria2**：代码库严禁任何 Aria2 守护进程或依赖。
- 所有多线程任务（HTTP/M3U8 切片并发与 BitTorrent/Magnet P2P 种子下载）均统一下发至内置 `Gopeed 2.0`（通过 Rust/Go FFI 纯内存绑定运行）。
- 下载参数在 `DownloadSettings` 中配置：`parallelEpisodes` (1-5), `parallelSegments` (1-10), `maxConcurrentDownloads` (1-16)。

### 3.2 设置分类层级体系 (Settings Taxonomy)
保持设置结构为上游 Haipee 的严格超集，顶层收敛为 4 个规范主菜单：
1. **播放 (Playback)**：播放器设置、弹幕设置、快捷键设置、刮削设置。
2. **资源 (Resources)**：
   - `规则管理`：集成分类过滤器（7 大规则分类：番剧 Anime、MacCMS 影视、Bilibili、抖音、直播 Live、网盘 Drive、Cardigann 种子）。
   - `下载设置`：统一 Gopeed 2.0 多线程分块与并发下载。
3. **应用 (Application)**：外观主题、界面设置、语言设置、云同步（Bangumi / WebDAV）、网络代理（Proxy / ECH / GitProxy）。
4. **其他 (Other)**：检查更新、存储与日志、开发者 HUD (Talker)、关于 Haipee。

---

## 4. 常用构建与验证命令

```bash
# 代码静态分析 (门禁：0 errors, 0 warnings)
flutter analyze

# 自动化测试 (门禁：100% 通过)
flutter test

# 代码国际化生成
dart run slang

# 运行态 WebSocket 溢出检测 (需在本地运行 app 时)
dart tool/inspect_app.dart --check-overflow

# 运行态热重载
dart tool/inspect_app.dart --reload
```
