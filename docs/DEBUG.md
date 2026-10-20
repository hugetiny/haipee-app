# Kazumi Logging & Diagnostic Specification (日志与诊断规范)

本文档为 Kazumi 的标准化日志子系统规范。详细定义了日志分卷存储路径、AI 代理诊断规范、模块化标签分流、子进程输出汇流及全局开发者 HUD 快捷键。

---

## 1. 架构总览 (Architecture Overview)

Kazumi 采用基于统一门面 `AppLog` 的强类型分流日志架构：

```
                    ┌───────────────────────────┐
                    │  AppLog Facade (统一门面)   │
                    └─────────────┬─────────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
       ┌─────────────────────┐         ┌──────────────────────┐
       │ In-Memory & Dev HUD │         │ Rolling File Sink    │
       │   (TalkerFlutter)   │         │ (后台分卷非阻塞文件写入) │
       └──────────┬──────────┘         └──────────┬───────────┘
                  │                               │
       ┌──────────┴──────────┐         ┌──────────┴───────────┐
       │ In-App TalkerScreen │         │ kazumi.log (5MB)     │
       │ Global Shortcut F12 │         │ kazumi.1.log (5MB)   │
       │ Instant Error Toast │         │ kazumi.2.log (5MB)   │
       └─────────────────────┘         └──────────────────────┘
```

1. **强类型模块 (`LogModule`)**：杜绝零散无序日志，所有日志均打上强类型标签 (`STREAM`, `ARIA2`, `INDEXER`, `PLAYER`, `NETWORK`, `UI`, `DOWNLOAD`, `SYNCPLAY`, `STORAGE`, `SYSTEM`, `PLUGIN`)。
2. **分卷持久化 (`RollingFileSink`)**：突破原先仅 Warning/Error 落盘的局限，持久化全量业务上下文（INFO、WARNING、ERROR、CRITICAL；开发者模式下记录 DEBUG）。单卷 5MB，最多保留 3 卷（`kazumi.log`, `kazumi.1.log`, `kazumi.2.log`），严格限制最大磁盘占用不超过 15MB。
3. **子进程与原生库统一汇流**：Aria2 守护进程 (`[Aria2]`)、TorrServer 二进制 (`[TorrServer]`) 以及 libtorrent 核心 alert 告警均自动重定向至 `AppLog`。
4. **实时报错感知与开发者 HUD**：全局桌面快捷键（`F12` / `Cmd+Shift+L` / `Ctrl+Shift+L`）秒级唤起交互式日志控制台；任意未捕获异常即时弹出无侵入底部通知并支持一键直达日志页面。

---

## 2. 标准日志存储路径 (Standard Log Locations)

在各支持平台上，日志统一存放于应用的 Application Support 目录下的 `logs/` 子文件夹中：

| 平台 | 模式 / 架构 | 固定绝对路径 |
| :--- | :--- | :--- |
| **macOS** | 沙盒构建 (Release / App Bundle) | `~/Library/Containers/com.predidit.kazumi/Data/Library/Application Support/com.predidit.kazumi/logs/kazumi.log` |
| **macOS** | 开发调试环境 (Flutter Run / Debug) | `~/Library/Application Support/com.example.kazumi/logs/kazumi.log` |
| **macOS** | 非沙盒安装包 (macOS Release) | `~/Library/Application Support/com.predidit.kazumi/logs/kazumi.log` |
| **Windows** | 标准桌面应用 | `%APPDATA%\com.predidit.kazumi\logs\kazumi.log` (即 `C:\Users\<User>\AppData\Roaming\com.predidit.kazumi\logs\kazumi.log`) |
| **Linux** | XDG 规范路径 | `~/.local/share/com.predidit.kazumi/logs/kazumi.log` |
| **Android** | 应用内部私有存储 | `/data/user/0/com.predidit.kazumi/files/logs/kazumi.log` |
| **iOS** | 沙盒 Documents / Support | `~/Library/Application Support/logs/kazumi.log` |

---

## 3. 分卷回滚规范 (Rolling File Strategy)

- **当前活跃日志**：`kazumi.log`（所有新日志实时异步追加写入）。
- **历史归档日志 1**：`kazumi.1.log`（上一轮 5MB 满额日志）。
- **历史归档日志 2**：`kazumi.2.log`（更早一轮 5MB 满额日志）。
- **回滚机制**：
  当 `kazumi.log` 大小达到 5MB 时：
  1. 删除最旧的 `kazumi.2.log`；
  2. 将 `kazumi.1.log` 重命名为 `kazumi.2.log`；
  3. 将 `kazumi.log` 重命名为 `kazumi.1.log`；
  4. 新建空白 `kazumi.log` 继续写入。
- **全量时间轴读取**：
  通过 `AppLog.exportDiagnostics()` 读取时，系统按 `kazumi.2.log` -> `kazumi.1.log` -> `kazumi.log` 顺序将历史拼装为完整的时间正序流水。

---

## 4. 日志单行结构与 AI 检索规范 (Log Format Specification)

每条日志统一严格遵循以下格式标准：

```
[YYYY-MM-DD HH:mm:ss.SSS] [LEVEL] [MODULE] message
    Error: <error>
    StackTrace:
#0 ...
```

### 示例

```log
[2026-10-13 18:25:01.456] [INFO] [ARIA2] [Aria2] Starting aria2c from: /opt/homebrew/bin/aria2c
[2026-10-13 18:25:02.123] [INFO] [STREAM] [TorrentStreamService] Initializing libtorrent engine at ...
[2026-10-13 18:25:05.789] [ERROR] [NETWORK] Request failed with statusCode 502
    Error: DioException [bad response]: 502 Bad Gateway
    StackTrace:
#0 DioClient._dispatch (dio_client.dart:45)
#1 Request.get (request.dart:82)
```

### AI 代理快速排查指南 (AI Agent Inspection Cheatsheet)

AI 助手在进行故障诊断时，可直接通过 Bash / 终端执行以下指令检索：

```bash
# 1. 查找 macOS 最新 100 行日志（自动兼容开发调试环境与沙盒路径）
tail -n 100 ~/Library/Application\ Support/com.example.kazumi/logs/kazumi.log 2>/dev/null || tail -n 100 ~/Library/Containers/com.predidit.kazumi/Data/Library/Application\ Support/com.predidit.kazumi/logs/kazumi.log 2>/dev/null || tail -n 100 ~/Library/Application\ Support/com.predidit.kazumi/logs/kazumi.log

# 2. 检索所有异常与报错
rg "\[ERROR\]|\[EXCEPTION\]" ~/Library/Application\ Support/com.example.kazumi/logs/ 2>/dev/null || rg "\[ERROR\]|\[EXCEPTION\]" ~/Library/Containers/com.predidit.kazumi/Data/Library/Application\ Support/com.predidit.kazumi/logs/ 2>/dev/null || rg "\[ERROR\]|\[EXCEPTION\]" ~/Library/Application\ Support/com.predidit.kazumi/logs/

# 3. 追踪流媒体或种子引擎运行态
rg "\[STREAM\]" ~/Library/Application\ Support/com.example.kazumi/logs/kazumi.log 2>/dev/null || rg "\[STREAM\]" ~/Library/Containers/com.predidit.kazumi/Data/Library/Application\ Support/com.predidit.kazumi/logs/kazumi.log

# 4. 追踪 Aria2 下载进程输出
rg "\[ARIA2\]" ~/Library/Application\ Support/com.example.kazumi/logs/kazumi.log 2>/dev/null || rg "\[ARIA2\]" ~/Library/Containers/com.predidit.kazumi/Data/Library/Application\ Support/com.predidit.kazumi/logs/kazumi.log
```

---

## 5. 强类型模块标签对照 (Subsystem Tags)

| 标签 (`LogModule`) | 对应模块与业务范围 | 典型场景 |
| :--- | :--- | :--- |
| `STREAM` | 原生 Libtorrent 2.1.1、TorrServer、在线边下边播 | 种子连接、Peer 发现、分片缓冲、引擎配置 |
| `ARIA2` | 内置 Aria2 守护进程生命周期与 RPC | 进程启动/退出、RPC 鉴权、离线下载任务 |
| `INDEXER` | Cardigann YAML 抓取引擎与 Torznab 源 | 站点解析、选择器执行、搜索响应、规则加载 |
| `PLAYER` | 媒体播放核心 (`media_kit`)、弹幕引擎 | 解码器切换、超分辨率、弹幕渲染、进度跳跃 |
| `NETWORK` | 全局 HTTP (`Dio`)、WebDAV、代理转发 | API 通信、Cloudflare 探测、Cookie 维护 |
| `UI` | 界面组件、弹窗、自适应布局 | 路由跳转、Theme 变更、布局溢出过滤防御 |
| `DOWNLOAD` | 本地离线任务队列与状态机 | 任务暂停/恢复、文件落盘、存储配额 |
| `SYNCPLAY` | 房间联播协同播放器 | WebSocket 同步协议、时钟校准、房间广播 |
| `STORAGE` | Hive 数据库、设置偏好与本地收藏 | 数据库迁移、脏数据校验、备份恢复 |
| `SYSTEM` | 平台通道、系统托盘、通知、窗口管理 | 托盘事件、前后台切换、退出阻止、通知唤醒 |
| `PLUGIN` | 在线视频源解析规则与 WebView 执行器 | 视频源商店解析、无头浏览器嗅探 |

---

## 6. 开发者交互与 HUD (Developer HUD & Interaction)

1. **全局快捷键 (Global Shortcuts)**：
   - 任意页面按下 **`F12`**：即时弹出 / 隐藏全功能交互式日志控制台 (`TalkerScreen`)。
   - macOS 下支持 **`Cmd + Shift + L`**，Windows / Linux 下支持 **`Ctrl + Shift + L`**。
2. **开发者调试模式 (Developer Mode)**：
   - 进入应用 **设置 -> 关于与支持 -> 开发者调试模式** 即可一键启用。
   - 启用后：
     - 落盘日志包含 `DEBUG` 级别详细跟踪；
     - 界面右下角显示浮动调试指示浮标（`DevLog` / 报错数字徽标），点击即可唤起控制台。
3. **实时异常通知 (Instant Error Toast)**：
   - 发生未捕获异常或 `AppLog.e` 时，屏幕底部弹出带右侧按钮的非侵入式 Toast：
     `发生异常: [错误摘要]   [查看日志]`
   - 点击 **[查看日志]** 即刻直达控制台定位异常堆栈。
   - 内置 3 秒防抖节流保护，防止异常风暴阻塞 UI。
4. **日志控制台快捷工具箱 (Logs Page Toolbar)**：
   - **打开目录**：直接在系统访达 (Finder) / 资源管理器中打开日志文件夹；
   - **复制路径**：复制主日志文件的完整系统绝对路径；
   - **导出诊断**：生成并复制包含设备软硬件信息、系统版本及全卷日志的一站式诊断报告；
   - **清空日志**：重置内存历史与分卷磁盘文件。

---

## 7. 无截图自省与调试 CLI (Zero-Screenshot VM Service Introspection CLI)

为杜绝任何基于系统截图（`screencapture`）和盲点像素点击的低效脆弱操作，Kazumi 建立了基于 Dart VM Service JSON-RPC 的无截图运行态自省工具 `tool/inspect_app.dart`。

### 常用命令指令集

```bash
# 1. 检测全界面是否有任何 RenderFlex 像素溢出
dart run tool/inspect_app.dart --check-overflow

# 2. 检索指定组件或语义 Key（如查找分类 Tab、选择器或操作按钮）
dart run tool/inspect_app.dart --find metadata_provider_selector
dart run tool/inspect_app.dart --find catalog_tab
dart run tool/inspect_app.dart --find info_btn

# 3. 打印当前界面的精简 Widget 结构树
dart run tool/inspect_app.dart --tree

# 4. 触发运行态毫秒级热重载 (无需终端输入)
dart run tool/inspect_app.dart --reload
```

