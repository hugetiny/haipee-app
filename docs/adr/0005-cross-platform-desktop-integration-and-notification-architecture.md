# 5. 全平台桌面系统集成、托盘守护与本地通知引擎架构设计 (Cross-Platform Desktop Integration, System Tray, and Notification Architecture)

* 状态: 已接受 (Accepted)
* 日期: 2026-10-09

## 背景 (Context)

Kazumi 作为一款定位全平台（macOS、Windows、Linux、Android、iOS）的高性能媒体发现、流式播放与资源下载客户端，桌面端深度系统集成是决定用户体验与产品质感的关键要素。在产品演进过程中，我们面临三大核心技术与架构抉择：

1. **应用图标（App Icon）更新与缓存死锁困境**：
   - 用户期望将 Dock 图标由原彩色动漫风升级为黑绿极客科技风格（外层向下大箭头代表高速下载，内嵌向上小箭头代表做种分享）。
   - macOS 存在臭名昭著的 LaunchServices Dock 图标缓存死锁机制（`com.apple.dock.iconcache` 绑定 Bundle ID），即使工程内 Assets 资源已经重新生成，Dock 栏及任务切换器仍然顽固加载旧图标。
2. **系统托盘（System Tray）的设计规范与平台割裂**：
   - 过去直接将彩色应用图标塞入 macOS 顶部菜单栏，在暗黑模式或动态壁纸下对比度极差，严重违背 Apple 人机交互指南（HIG）。
   - 托盘需要兼顾多端差异：macOS 需要模板图标（Template Image）自适应深浅色，Windows 需要高清 `.ico`，Linux 需要遵循 FreeDesktop 图标命名。
3. **通知系统（Notification Engine）的技术选型决裂**：
   - 社区存在两种主要通知方案：`awesome_notifications` 与 `flutter_local_notifications`。
   - `awesome_notifications`（`^0.12.1`）重心高度倾斜于 Android/iOS 移动端富媒体，其桌面端（macOS/Windows）长期缺乏稳定维护，且由于排他性的后台通信拦截，极易导致 MethodChannel 缺失甚至桌面构建崩溃；
   - 相比之下，`flutter_local_notifications`（`^22.3.1`）是 Flutter 社区首屈一指的标准基石，不仅具备完整的 Android/iOS 权限与渠道支持，且第一方原生支持 macOS Darwin UserNotifications、Windows WinRT Toast 和 Linux libnotify。

---

## 决策 (Decision)

经深入调研与工程实测，我们做出以下三项核心决策：

### 1. 双轨保障 App Icon 部署管线 (Dual-Pipeline App Icon Architecture)

- **构建期管道（Build-Time Pipeline）**：
  - 维护基准高精度矢量/位图资源（黑绿极客科技嵌套双向箭头），通过 `flutter_launcher_icons`（最新规范）全自动衍生 Android、iOS、macOS (`AppIcon.appiconset`)、Windows (`.ico`) 与 Linux 全套分发资产；
  - 辅以原生资产构建脚本（`deploy_geek_icons.py` / `generate_icns.py`），生成标准 `AppIcon.icns` 与编译后 `Assets.car`。
- **运行时强注入兜底（Runtime Direct Injection）**：
  - 在 `macos/Runner/AppDelegate.swift` 中，于 `applicationDidFinishLaunching` 阶段显式执行：
    ```swift
    if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
       let iconImage = NSImage(contentsOfFile: iconPath) {
        NSApp.applicationIconImage = iconImage
    }
    ```
  - 彻底绕过 macOS LaunchServices 损坏或滞后的系统缓存，确保无论用户首次启动还是存量更新，Dock 图标 100% 呈现全新黑绿极客视觉。

### 2. 极简无干扰系统托盘守护者 (System Tray Minimal Guardian via `tray_manager`)

- **选用 `tray_manager` 作为跨平台托盘核心抽象**：
  - 在 `lib/app_widget.dart` 中建立生命周期绑定与事件响应。
- **遵循 macOS HIG 模板图标规范**：
  - 在 macOS 下使用专门设计的单色透明镂空白线剪影图标（`assets/images/logo/tray_icon_macos.png`），配置 `isTemplate: true` 与 `iconSize: 18`。macOS 系统内核自动根据顶栏明暗色彩、菜单高亮状态进行动态矢量反色。
- **极简无干扰与生命周期看护**：
  - 左键单击直接激活并置顶主窗口（`windowManager.show()` + `windowManager.focus()`）；
  - 右键呼出轻量上下文菜单（“显示窗口”、“退出应用”）；
  - 退出时统一通知 `Aria2ProcessManager().stop()`，安全回收本地后台守护进程。

### 3. 全端统一的本地通知引擎 (Universal Notification Engine via `flutter_local_notifications`)

- **全面拥抱 `flutter_local_notifications: ^22.3.1`，坚决弃用 `awesome_notifications`**：
  - 构建集中式领域服务 `NotificationService`（`lib/services/notification/notification_service.dart`）；
  - 统一封装 DarwinNotificationDetails（macOS / iOS）、AndroidNotificationDetails（配置 `kazumi_downloads` 和 `kazumi_stream` 高优先级渠道）、WindowsNotificationDetails 与 LinuxNotificationDetails。
- **与核心业务深度贯通**：
  - **下载完成通知（`showDownloadCompleted`）**：在 `DownloadController`（WebSocket 事件及定期同步循环中）精确捕获下载任务完成状态，展示任务标题与存储路径；
  - **防冷启动骚扰设计（Startup Notification Suppression）**：应用启动从本地持久化存储（Hive）加载既有历史任务时，将已完成任务 GID 预先注入 `_notifiedCompletionGids` 集合，避免冷启动时爆弹历史通知；
  - **媒体流就绪（`showStreamReady`）**：为 `TorrentStreamService` 边下边播预缓冲提供就绪提示；
  - **通知点击响应（Interaction Routing）**：用户在桌面系统点击通知横幅时，自动唤醒并置顶应用主窗口。

---

## 后果 (Consequences)

### 正面收益 (Positive)
- **视觉风格高度统一**：Dock 栏黑绿极客双箭头与顶部托盘纯白单色模板各司其职，桌面端原生质感显著提升。
- **多端稳定性与架构纯净度**：弃用有崩溃风险的移动端专用库，全平台采用第一方强维护的 `flutter_local_notifications`，0 警告 0 报错通过 `flutter analyze`。
- **体验无缝**：后台下载任务在完成时自动推送桌面系统通知，用户点击即可无缝返回应用，免除用户反复切窗查看进度的痛点。

### 代价与后续维护 (Trade-offs & Maintenance)
- **多端通知权限差异**：macOS 与 Android 13+ 需要用户显式授权通知权限，已在 `main.dart` 启动时异步申请；若用户在系统设置中手动拒绝，业务逻辑需保持静默降级（通过 Talker 记入日志，不影响核心下载与流式播放）。
