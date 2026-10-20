# ADR 0009: Unified Gopeed FFI Engine and Torrent Streaming (Gopeed FFI 统一离线下载与边下边播架构)

## 状态 (Status)
**已接受 (Accepted)** - 2026-10-20

---

## 背景与痛点 (Context & Problem Statement)

Kazumi 早期对于文件下载与流媒体在线播放规划了多进程/多引擎的混合架构：
1. **离线下载 (Offline Download)**：通过启动独立的 `aria2c` 守护进程，通过 Localhost JSON-RPC / WebSocket 通信进行离线文件下载。
2. **种子流式播放 (Torrent Streaming)**：曾规划引入独立进程的 `TorrServer` 或 C++ 原生库 `libtorrent`（通过 `libtorrent_flutter`）提供在线点播服务。

在多平台（macOS、Windows、Linux、iOS、Android）实践中，该异构设计暴露出严重的架构缺陷：
- **进程管理与沙盒受限**：外部子进程在移动端（尤其是 iOS App 沙盒禁止 `fork`/`exec`）根本无法启动；在桌面端则容易出现孤儿进程泄漏、随机端口抢占与防火墙弹窗。
- **CGO 与 C++ 编译泥潭**：C++ `libtorrent` 强依赖 Boost 及复杂的 Native Toolchain，且在 FFI/CGO 内部抛出的 SIGSEGV 无法被 Go/Dart 运行时捕获，极易导致主程序闪退崩溃。
- **底层引擎重复造轮子**：深度代码审计确认，开源流媒体服务 `TorrServer` 与现代多协议下载器 `Gopeed` **底层使用的是完全相同的纯 Go BitTorrent 核心库（`github.com/anacrolix/torrent`）**。两套引擎并存将导致双重 DHT、双重 Tracker 链接以及高昂的内存与磁盘 I/O 争用。

---

## 架构决策 (Architectural Decisions)

我们决定**彻底废弃独立的外部 Aria2 守护进程与多引擎并存模式，全面确立以 Gopeed 为单一核心的进程内 FFI 引擎（Unified Gopeed FFI Engine）**，并对 Gopeed Go 核心进行流媒体二次开发：

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Kazumi Flutter UI                             │
│       (Xunlei-Style Download Manager  /  MediaKit Video Player)         │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           │                                                   │
           ▼ (dart:ffi 内存直连 / NativePort)                   ▼ (HTTP 206 Partial Content)
┌──────────────────────────────────────┐            ┌──────────────────────────────────────┐
│        Gopeed Core FFI Bindings      │            │       Internal Streaming Proxy       │
│    (Start / Stop / Task Management)  │            │     (http://127.0.0.1:port/stream)   │
└──────────────────┬───────────────────┘            └──────────────────┬───────────────────┘
                   │                                                   │
                   └─────────────────────────┬─────────────────────────┘
                                             │
                                             ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                             In-Process Gopeed Go Core                                    │
│  - HTTP/HTTPS/网盘直链多线程引擎                                                           │
│  - 纯 Go BitTorrent 内核 (github.com/anacrolix/torrent)                                  │
│  - [二次开发] Sliding-Window Piece 优先级调度器 + HTTP 206 Partial Content 串流服务       │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1. 源码组织形态：Git Submodule (`third_party/gopeed`)
- 将维护的 Gopeed 仓库作为 Git Submodule 嵌入 `third_party/gopeed`。
- 保证 Go 核心代码与 Gopeed 官方开源仓库 1:1 对齐，所有针对流媒体（边下边播）的二次开发成果均可直接通过 Git 向 Gopeed 上游提交 Pull Request。

### 2. 遵循 Gopeed 原生 FFI 桥接规范
- **C-ABI 导出**：沿用 Gopeed 官方 `bind/desktop` 设计，通过 CGO 导出标准的 C 符号（`Start`, `Stop`, `InvokeAsync`, `SubscribeTaskEvents`）。
- **跨平台编译**：
  - 桌面端（macOS/Windows/Linux）：通过 Go `-buildmode=c-shared` 输出平台动态库（`.dylib` / `.dll` / `.so`），直接注入 Runner Frameworks。
  - 移动端（Android/iOS）：通过 `gomobile bind` 生成 `.aar` 与 `Libgopeed.xcframework`。
- **零网络回环损耗**：控制指令与实时进度事件全部通过 `dart:ffi` 与 Dart `NativePort` 传递，彻底消除 Localhost HTTP RPC 延迟。

### 3. Gopeed Go 核心流式二次开发 (Torrent Streaming Extension)
- 在 Gopeed 内部新增流媒体模式：
  1. **HTTP 206 服务**：引擎内启动轻量 HTTP 206 Partial Content 本地监听。
  2. **滑动窗口切片调度 (Sliding Window Piece Prioritization)**：播放器进行 Seek 跳转时，Go 核心动态计算对应的 Piece 索引，以高优先级调度当前播放点附近的切片及文件头部/尾部元数据，暂停远端切片下载。
  3. **边播边存转换**：播放临时缓冲数据支持一键原地保留转入下载管理器，避免重复拉取。

---

## 被否决方案与权衡 (Considered & Rejected Alternatives)

| 方案 | 评定 | 否决原因 |
| :--- | :--- | :--- |
| **Aria2 + Gopeed 双引擎** | ❌ 否决 | 功能高度重叠，双重状态持久化（Hive/SQLite）与 UI 复杂度成倍激增，Aria2 无法优雅跨平台 FFI 化。 |
| **Go 接入 C++ libtorrent** | ❌ 否决 | CGO 跨语言开销高，C++ 崩溃导致整个 App 闪退，毁掉 Gopeed 跨平台一键编译的天然优势。 |
| **独立进程 TorrServer** | ❌ 否决 | TorrServer 底层就是 `anacrolix/torrent`，外挂独立进程会引发端口占用、进程泄漏和重复资源占用。 |

---

## 收益与下游影响 (Consequences & Benefits)

1. **零外部守护进程**：彻底告别孤儿进程与杀不死的后台常驻服务，应用生命周期完全受控。
2. **多端 100% 纯 Go 免依赖编译**：统一为一套构建管线，在保持移动端（iOS/Android）沙盒合规的同时，极大降低维护负担。
3. **播放与下载合一**：用户在线点播视频的数据直接复用，随时一键永久保存，极大提升用户体验。
4. **反哺开源生态**：作为 Gopeed 维护者，流媒体能力的二次开发可直接回馈 Gopeed 社区，形成良性循环。
