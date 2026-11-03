# Haipee 云端 AI 自动化测试与运行时遥测系统 (Sentry + Firebase Test Lab)

本项目已接入行业顶级的自动化崩溃发现与云端真机自动化巡检组合：**`sentry_flutter` + Google Cloud Firebase Test Lab**。

由于本地开发环境磁盘空间受限且未配置 Android SDK / Gradle 编译链，**所有 Android 编译与云端真机自动化测试全流程均托管于 GitHub Actions 运行**，本地零磁盘消耗、零环境污染。

---

## 架构总览

```mermaid
flowchart TD
    A[代码提交 / 手动触发 Workflow] --> B[GitHub Actions Runner (Ubuntu)]
    B --> C[flutter build apk --release]
    C -->|注入 SENTRY_DSN 与 FIREBASE_TEST_LAB| D[生成 Release APK]
    D --> E[Google Cloud Firebase Test Lab]
    E --> F[AI 驱动的 Robo 智能爬虫巡检 (真机 Pixel 7/6)]
    F -->|模拟点击/滑动/旋屏/文本输入| G{检测到异常/Crash?}
    G -->|是| H[Sentry 捕获完整 Dart 堆栈、崩溃截图与视图层级]
    G -->|否| I[输出云端测试视频、性能图表与自动化测试报告]
    H --> J[开发者收到 Sentry 告警 & 定位修复]
```

1. **Sentry 运行时遥测 (`lib/services/sentry/sentry_service.dart`)**：
   - **零敏感信息硬编码**：通过 `--dart-define=SENTRY_DSN=...` 编译期注入；无 DSN 时自动静默空跑（本地开发及离线完全不受影响）。
   - **Talker 日志无缝桥接**：所有业务日志（下载、播放、Aria2、Gopeed、解析）自动转化为 Sentry Breadcrumbs，崩溃时直接还原完整的上下文调用轨迹。
   - **自动化视觉诊断**：在支持的移动平台上自动捕获崩溃瞬间的界面截图与 Widget 树视图层级（View Hierarchy）。
   - **环境自动嗅探**：在 Firebase Test Lab 下运行时自动打上 `testlab` 与 `runner=firebase_test_lab` 标签，采样率提升至 100%。

2. **Firebase Test Lab 智能巡检 (`.github/workflows/firebase_test_lab.yaml`)**：
   - **AI Robo 自动遍历**：无需手写任何 UI 脚本，Google 智能爬虫会自动模拟真实用户点击、长按、滑动、表单输入、横竖屏切换与物理返回键。
   - **真机阵列测试**：默认针对 Google Pixel 7 (Android 13/33) 及 Pixel 6 (Android 12/32) 真机矩阵执行深度探索。
   - **测试制品自动汇总**：测试完成后在 GitHub Actions Step Summary 直接生成 Firebase Console 测试报告、巡检视频与交互录像链接。

---

## 自动化环境配置状态 (已全自动完成)

已使用本地 CLI 和 GitHub CLI 为本仓库（`hugetiny/hapi`）完成全自动配置：

| 配置项 | 详细信息 | 状态 |
| :--- | :--- | :--- |
| **Sentry 组织与项目** | Organization: `hugetiny` / Project: `kazumi` (ID: `4512290620571648`) | ✅ 自动创建完成 |
| **Sentry DSN** | `https://076d98eefdbedbe17c02c727c7cd9ae0@o4508346535641088.ingest.us.sentry.io/4512290620571648` | ✅ 已注入 GitHub Secret (`SENTRY_DSN`) |
| **Google Cloud 项目** | Project ID: `flutter-e3137` | ✅ API 已激活 (`testing`, `toolresults`) |
| **GCP 服务账号** | `github-actions-testlab@flutter-e3137.iam.gserviceaccount.com` | ✅ 已绑定 `testAdmin` 与 `editor` 权限 |
| **GCP 认证密钥** | 专用高权限 Service Account JSON Key | ✅ 已注入 GitHub Secret (`GCP_SA_KEY`) |
| **项目 ID 变量** | `flutter-e3137` | ✅ 已注入 GitHub Secret (`FIREBASE_PROJECT_ID`) |

---

## 如何触发测试

### 方式一：在 GitHub 页面上一键手动触发 (Workflow Dispatch)
1. 打开 GitHub 仓库页面，点击 **Actions** 选项卡。
2. 在左侧工作流列表中选择 **"Firebase Test Lab Automated AI Testing"**。
3. 点击右侧 **"Run workflow"**：
   - 可自定义探索时长（例如 `3m`、`5m`）。
   - 可选择测试机型（`Flagship Pixel 7` 或 `Multi-device Matrix`）。
4. 点击绿色按钮立即启动云端编译与真机巡检。

### 方式二：自动触发
- 当推送到 `main` 分支且包含核心代码变更时，工作流会自动触发执行。
