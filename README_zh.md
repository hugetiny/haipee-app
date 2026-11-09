<div align="center">

<img src="assets/images/logo/logo_rounded.png" width="128" height="128" alt="Haipee Logo" style="border-radius: 28px;" />

# Haipee

**跨平台全能视听播放与极速下载聚合终端**

[![Version](https://img.shields.io/badge/version-0.0.2-blue.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20iOS-orange.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/hugetiny/haipee-app?style=flat&color=yellow)](https://github.com/hugetiny/haipee-app/stargazers)

**[English](README.md)** • **[简体中文](README_zh.md)**

[官方网站](https://haipee.com) • [快速下载](#-快速下载) • [支持平台](#-支持平台) • [独特特性](#-相比其他产品haipee-有哪些独特特点) • [功能全览](#-核心功能全览) • [常见问题](#-常见问题-faq) • [开源协议](#-开源声明与隐私-license--privacy)

</div>

---

## 💡 一眼看懂 Haipee 是干嘛的？

> **“播放器里下载最快，下载器里播放最强，聚合工具里体验最主流。”**

日常看剧看番，我们经常在不同工具间反复横跳：传统播放器（如 PotPlayer/VLC）无法直接搜资源；影视聚合软件界面粗糙且没有下载与磁力能力；传统下载器（如 迅雷/百度网盘）下载时无法实时预览、没有弹幕、也不能画质超分。

**Haipee 将「全网资源聚合 + 高性能视听播放 + Gopeed 极速下载 + 智能多源弹幕」无缝熔铸为一体**：
- 🔍 **找资源不用换软件**：片名一搜，全网多规则聚合，自研 Haipee 规则、B站高清视频、影视采集站、IPTV 电视直播、磁力/BT 种子一网打尽；
- ⚡ **想下就下，满速直连**：原生内嵌 Gopeed 高性能 Go 下载引擎，多线程 HTTP 并发与 BitTorrent P2P 满速下载，支持边下边播，完工自动通知；
- 🎬 **画质与弹幕双重飞跃**：基于 `media-kit` 全硬件解码内核，集成 Anime4K GPU 实时画质超分辨率（老片瞬变 1080P/4K），全自动匹配弹弹Play多平台实时弹幕；
- 📱 **真·全端主流响应式设计**：拒绝手机端生硬狭窄的难看弹窗！手机端全宽底部抽屉（BottomSheet）与防误触操作胶囊，桌面端避让 macOS 红绿灯、全局快捷键与原生托盘。

---

## 🔥 相比其他产品，Haipee 有哪些独特特点？

| 核心维度 | 传统本地播放器 (VLC/PotPlayer) | 普通影视聚合应用 (TVBox等) | 传统下载工具 (迅雷/Aria2) | 🌟 Haipee 聚合终端 |
| :--- | :--- | :--- | :--- | :--- |
| **资源搜索** | ❌ 仅支持打开本地或单链接 | ⚠️ 依赖远程配置，排序混乱 | ❌ 仅提供下载通道，无法搜片 | ✅ **全网聚合秒级响应，Haipee规则置顶** |
| **下载内核** | ❌ 无下载能力 | ⚠️ 依赖系统粗糙下载，常卡死 | ✅ 支持下载，但界面臃肿/充值限速 | ✅ **原生内嵌 Gopeed 引擎，BT/HTTP 满速且完全免费** |
| **边下边播** | ❌ 不支持 | ❌ 不支持 | ⚠️ 体验割裂，需调用外部关联 | ✅ **开箱即用，首部关键帧高速预缓冲直接播放** |
| **实时弹幕** | ❌ 需手动找 XML 文件加载 | ⚠️ 覆盖不全，来源不明 | ❌ 无弹幕概念 | ✅ **多平台漫游（B站/巴哈/弹弹），明确标注来源条数并可自由开关** |
| **画质增强** | ⚠️ 需配置复杂着色器滤镜 | ❌ 无 | ❌ 无 | ✅ **开箱即用 Anime4K GPU 实时超分辨率着色器** |
| **多端交互** | ⚠️ 仅桌面端，无现代移动适配 | ⚠️ 仅偏向电视遥控器或安卓 | ⚠️ 界面充斥广告与弹窗 | ✅ **自适应全宽响应式交互，手机与桌面皆为第一公民** |
| **数据隐私** | ✅ 本地 | ⚠️ 存在远程服务劫持风险 | ❌ 商业数据收集与限速套路 | ✅ **100% 本地优先，无账户强制，无任何远程遥测追踪** |

---

## ✨ 核心功能全览

### 1. 🚀 原生内嵌 Gopeed 极速下载内核
- 底层通过 FFI/Cgo 直连编译好的 Gopeed 原生核心，跨平台零外部安装依赖；
- 完备支持 HTTP / HTTPS 多连接分段传输、BitTorrent 磁力链接与 DHT 网络发现；
- 下载任务与本地媒体库（LocalMedia）自动串联，任务完成自动触发系统级通知。

### 2. 🍿 极致画质视听引擎（全硬件加速 + Anime4K）
- 采用高性能跨平台 `media-kit` 多媒体框架，全面释放 GPU 硬件解码算力；
- 完整支持 DASH（视音频分离流）、HLS（m3u8 切片）与常见音视频容器；
- 内置 **Anime4K 实时着色算法**，可在播放时由显卡对动漫番剧进行实时超分辨率重建与噪点抑制。

### 3. 💬 智能多源弹幕与来源清晰透明
- 播放 B站 原生视频自动直载官方 CID 弹幕，聚合番剧全自动检索弹弹Play弹幕库；
- **平台来源清晰透明**：在弹幕设置面板与「视频统计信息 (Stats for Nerds)」中，清晰标明 Bilibili、巴哈姆特动画疯、弹弹Play 的具体条数，并支持独立开关各源弹幕；
- 支持弹幕字号、透明度、滚动速度、同屏防挤与关键词/正则智能屏蔽。

### 4. 🗂️ 视听生态一体化聚合
- **规则矩阵**：支持 Haipee 官方原生规则、TVBox 规则、MacCMS 采集规则、IPTV 电视直播、AList / WebDAV 个人云盘、Cardigann / Prowlarr 磁力索引器；
- **自适应并排按钮组**：一键在「表格详细视图 (Table)」与「海报网格视图 (Grid)」之间平滑切换；
- **媒体库管理**：历史进度断点记忆、收藏夹分类、本地下载直达，告别找不到下载目录的烦恼。

### 5. 📱 真正的现代响应式设计 (Fluid Responsive UI)
- 告别手机屏幕上居中缩成一团的落后弹窗；
- 手机端采用 Material 3 标准自适应全宽底部抽屉（BottomSheet），带有符合大拇指操作的拖拽把手与自动避让虚拟键盘交互；
- 桌面端具备专属避让机制（避让 macOS 原生红黄绿三色按钮）、右键菜单与全局媒体快捷键。

---

## 📱 支持平台

| 平台 | 最低版本要求 | 运行架构 | 发布形式 |
| :--- | :--- | :--- | :--- |
| **Android** | Android 10+ (API 29+) | arm64-v8a / armeabi-v7a / x86_64 | 独立 APK 安装包（支持应用内在线检测更新） |
| **macOS** | macOS 10.15+ (Catalina) | Universal (Apple Silicon M系列 & Intel) | 原生打包 App 归档（带 Dock 动态图标） |
| **Windows** | Windows 10+ (64-bit) | x64 | 绿色免安装便携 Zip 包，解压即用 |
| **Linux** | Ubuntu 20.04+ / Debian 11+ | amd64 | Debian `.deb` 安装包与 `.tar.gz` 便携包 |
| **iOS** | iOS 13+ | arm64 | 未签名 `.ipa`（供 TrollStore 巨魔或自签名安装） |

---

## ⬇️ 快速下载

最新版本安装包可直接前往 [GitHub Releases 页面](https://github.com/hugetiny/haipee-app/releases/latest) 下载：

<div align="center">
  <a href="https://github.com/hugetiny/haipee-app/releases/latest">
    <img src="static/svg/get_it_on_github.svg" alt="Get it on GitHub" width="220"/>
  </a>
</div>

| 文件名 | 适用平台 | 说明 |
| :--- | :--- | :--- |
| `haipee-android-arm64-v0.0.2.apk` | Android | 推荐主流 64 位手机与平板安装 |
| `haipee-android-armv7-v0.0.2.apk` | Android | 适用于 32 位老旧设备 |
| `haipee-android-x86_64-v0.0.2.apk` | Android | 适用于 Android 模拟器与 x86 平板 |
| `haipee-windows-v0.0.2.zip` | Windows | 绿色便携版，解压后双击 `haipee.exe` 运行 |
| `haipee-macos-universal-v0.0.2.zip` | macOS | 通用架构归档，完美兼容 M1/M2/M3/M4 及 Intel Mac |
| `haipee-linux-v0.0.2-amd64.deb` | Linux (Debian/Ubuntu) | 标准 Debian 安装包，自带桌面图标与托盘关联 |
| `haipee-linux-v0.0.2-amd64.tar.gz` | Linux (通用) | 便携免安装归档包 |
| `haipee-ios-unsigned-v0.0.2.ipa` | iOS | 免签名安装包，供 TrollStore 或个人证书自签名 |

---

## ❓ 常见问题 (FAQ)

<details>
<summary><b>Q: 开启 Anime4K 画质超分辨率会有发热或卡顿吗？</b></summary>

Anime4K 超分辨率滤镜完全依靠当前设备的显卡（GPU）进行实时并行着色运算。在轻薄本或核心显卡设备上，建议选择“Anime4K 均衡 (Lite)”档位，或者优先针对 480P/720P 等中低清晰度片源开启，既能显著提升细节感，又能节省设备算力与功耗。
</details>

<details>
<summary><b>Q: 播放视频时内存占用升高正常吗？</b></summary>

为确保在公共网络或弱网环境下播放大码率媒体时不频繁缓冲卡顿，播放引擎会预加载部分分片至动态内存缓冲区。如果您的设备内存较小（例如 4GB 运行内存的手机或老旧 PC），可在「设置 - 播放设置」中开启**低内存模式**，系统将严格限制动态缓冲上限。
</details>

<details>
<summary><b>Q: 安卓手机端如何接收新版本更新？</b></summary>

Haipee 在安卓端内置了智能更新检测管道。当发布新版本时，在应用内「设置 - 关于」或启动时会自动请求 GitHub 官方安全通道检测最新发布版本，并支持一键下载 APK 覆盖升级，无需重复手动到网页下载。
</details>

---

## 📜 开源声明与隐私 (License & Privacy)

- **开源协议**：本项目基于 [GNU General Public License v3.0 (GPL-3.0)](LICENSE) 协议开源。
- **隐私保护**：Haipee 恪守本地优先原则，不收集任何用户隐私数据，无任何第三方分析追踪或远程遥测代码。

---

## 🙏 致谢 (Credits)

- [Kazumi](https://github.com/Predidit/Kazumi) - 卓越的跨平台视听播放器架构与规则解析基石。
- [Gopeed](https://github.com/GopeedLab/gopeed) - 提供卓越的高性能多线程与 BitTorrent 磁力下载能力。
- [media-kit](https://github.com/media-kit/media-kit) - 强大的跨平台媒体播放渲染引擎。
- [Dandanplay](https://www.dandanplay.com/) - 开放弹幕协议与弹幕数据源支持。
- [Bangumi](https://bangumi.tv/) - 媒体与番组元数据开放接口。
- [Anime4K](https://github.com/bloc97/Anime4K) - 实时高质量画质超分辨率算法。
- [xpath_selector](https://github.com/simonkimi/xpath_selector) - 规则解析与抽取基础库。
