# Haipee 彻底清理 Kazumi 元素、全量测试 (含 Firebase Test Lab) 与 Release 发布计划

本文档规划了执行“彻底消除 Kazumi 元素”、“全量确定性回归与 Firebase Test Lab 云端真机测试”、“源代码推送私有库 (hugetiny/hapi)”、“正式版本发布到公开库 (hugetiny/haipee)”的端到端实施方案。

---

## 阶段一：全工程 Kazumi 元素深度清理与重命名

### 1.1 项目底座与 Dart 模块重命名
- `pubspec.yaml`：将 `name: kazumi` 修改为 `name: haipee`，版本号保持 `2.3.7+20307`。
- 全量源码与测试：将所有 `package:kazumi/...` 自动化全局替换为 `package:haipee/...`。

### 1.2 核心类名与组件符号重构
- 类名与文件重命名：
  - `KazumiDialog` / `KazumiDialogObserver` -> `HaipeeDialog` / `HaipeeDialogObserver`
  - `KazumiLogger` -> `HaipeeLogger`
  - `KazumiColors` -> `HaipeeColors`
  - `KazumiTheme` -> `HaipeeTheme`
  - `KazumiAppBarActions` -> `HaipeeAppBarActions`（文件：`kazumi_app_bar_actions.dart` -> `haipee_app_bar_actions.dart`）
  - `KazumiActionItem` -> `HaipeeActionItem`（文件：`kazumi_action_item.dart` -> `haipee_action_item.dart`）
  - `KazumiTopOverlayBar` -> `HaipeeTopOverlayBar`（文件：`kazumi_top_overlay_bar.dart` -> `haipee_top_overlay_bar.dart`）
  - `KazumiNavRail` -> `HaipeeNavRail`
  - `KazumiLicensePage` -> `HaipeeLicensePage`
  - `KazumiProgressHUD` -> `HaipeeProgressHUD`
  - `KazumiHttp` -> `HaipeeHttp`
  - `KazumiPlugin` -> `HaipeePlugin`
  - `KazumiTrayLabels` -> `HaipeeTrayLabels`
  - `test/widget/kazumi_dialog_test.dart` -> `test/widget/haipee_dialog_test.dart`

### 1.3 规则分类与生态标签重构
- 规则枚举：`PluginRuleType.kazumi` 重构为 `PluginRuleType.haipee`（解析器兼容 `kazumi` 与 `haipee` 字符串）。
- 规则标签：`'Kazumi 规则'` -> `'Haipee 规则'`。
- 内置规则作者与请求头：`"Kazumi Official"` -> `"Haipee Official"`，User-Agent `"Mozilla/5.0 (Kazumi/Player)"` -> `"Mozilla/5.0 (Haipee/Player)"`。

### 1.4 移动与桌面原生平台底座包名与标识重构
- Android：
  - `android/app/build.gradle`: `namespace = "com.example.haipee"`, `applicationId = "com.example.haipee"`.
  - `android/app/src/main/AndroidManifest.xml`: `package="com.example.haipee"`.
  - 源码目录调整：`android/app/src/main/kotlin/com/example/kazumi/` 移动至 `android/app/src/main/kotlin/com/example/haipee/`，更新包声明为 `package com.example.haipee`.
- Linux：
  - 更新 desktop 文件与软链接脚本：`assets/linux/io.github.Predidit.Kazumi.desktop` 改为 `io.github.hugetiny.haipee.desktop`，Exec 改为 `haipee`.
- macOS / Windows：
  - 检查 Runner 相关工程配置确保 Product Name / Executable 均对齐 `haipee`.

### 1.5 门禁验证 (Acceptance Criteria)
- 运行 `flutter pub get`。
- 运行 `flutter analyze` 确保 **0 errors, 0 warnings**。
- 运行 `flutter test` 确保全量测试 100% 绿灯。
- 检查 `git grep -i "kazumi"` 确认业务代码无遗留。

---

## 阶段二：全链路测试与 Firebase Test Lab 真机巡检

### 2.1 本地全量回归测试
- 运行 `flutter test` 执行所有单元测试与组件测试。

### 2.2 构建 Release APK (Test Lab 专用编译态)
- 执行：
  ```bash
  flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation --dart-define=FIREBASE_TEST_LAB=true
  ```

### 2.3 执行 Firebase Test Lab 云端真机矩阵
- 运行 `tool/run_firebase_testlab.sh`（使用 Google Cloud SDK，模型 `panther`, Android 33）。
- 爬虫配合 `tool/testlab_roboscript.json` 执行 5 大核心模块无死角自动化巡检。
- 自动拉取 GCS 云端日志，执行 `dart tool/analyze_testlab_logs.dart`，生成分析报告并确认零未捕获异常。

---

## 阶段三：源代码推送到私有仓库 (hugetiny/hapi)

- 整理并提交所有改动：`git add .`、`git commit -m "refactor: complete rename to haipee and eliminate kazumi elements"`。
- 推送至私有仓库：`git push hugetiny main`。

---

## 阶段四：打包并发布 Release 到公开仓库 (hugetiny/haipee)

- 编译发布版本二进制制品：
  - Android Release APK: `build/app/outputs/flutter-apk/app-release.apk` 重命名为 `haipee-android-arm64-v2.3.7.apk`
  - macOS Release 包（若当前环境支持）：打包生成压缩归档
- 使用 GitHub CLI 在公开仓库创建正式 Release：
  ```bash
  gh release create v2.3.7 haipee-android-arm64-v2.3.7.apk \
    --repo hugetiny/haipee \
    --title "haipee v2.3.7" \
    --notes "..."
  ```
- 验证 Release 在 `https://github.com/hugetiny/haipee/releases` 成功上线并可供下载。
