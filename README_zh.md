<div align="center">

# Haipee

**跨平台全能视听播放与高速下载聚合应用**

[![Version](https://img.shields.io/badge/version-0.0.1-blue.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20iOS-orange.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)

**[English](README.md)** • **[简体中文](README_zh.md)**

[官方网站](https://haipee.com) • [功能特性](#-功能特性) • [支持平台](#-支持平台) • [快速下载](#-快速下载) • [多语言支持](#-多语言支持) • [常见问题](#-常见问题-faq) • [声明与协议](#-声明与协议-license--privacy) • [致谢](#-致谢-credits)

</div>

---

## ✨ 功能特性

- ⚡ **Gopeed 原生极速下载**：深度集成 Gopeed 多线程下载引擎内核，原生支持 HTTP/HTTPS 与 BitTorrent 磁力链接高速下载、断点续传及多任务并发管理。
- 🎬 **全能媒体播放**：基于高性能 `media-kit` 渲染内核，支持硬件加速、DASH / HLS 流媒体播放与 Anime4K 实时画质超分辨率增强。
- 💬 **弹幕交互与字幕匹配**：集成 Dandanplay 开放弹幕协议，智能识别媒体标题并载入实时滚动弹幕与外挂字幕。
- 🔍 **四大统一资源体系**：全面覆盖在线视频、电视直播、网盘资源（WebDAV / Alist）与 BT 磁力，支持 Cardigann、Torznab、Prowlarr 规范扩展与即时多维排序。
- 🎨 **现代化自适应界面**：Material You 动态调色体系，无缝适配大屏桌面端（macOS 原生避让、右键菜单、快捷键）与移动端触控交互。
- 🌐 **完备多语言支持**：基于 `slang` 构建，开箱即用支持简体中文、繁体中文、English、日本語。

---

## 📱 支持平台

| 平台 | 最低版本要求 | 运行架构 | 发布形式 |
| :--- | :--- | :--- | :--- |
| **Android** | Android 10+ | arm64-v8a / armeabi-v7a / x86_64 | 独立 APK 安装包 |
| **Windows** | Windows 10+ | x64 | 绿色便携 Zip 压缩包，解压即用 |
| **macOS** | macOS 10.15+ (Catalina) | Universal (Apple Silicon & Intel) | 通用二进制 Zip 归档 |
| **Linux** | Ubuntu 20.04+ / Debian 11+ | amd64 | Debian `.deb` 安装包与 `.tar.gz` 便携包 |
| **iOS** | iOS 13+ | arm64 | 未签名 `.ipa`（供 TrollStore 或自签名安装） |

---

## ⬇️ 快速下载

最新版本安装包可直接前往 [GitHub Releases 页面](https://github.com/hugetiny/haipee-app/releases/latest) 获取：

<div align="center">
  <a href="https://github.com/hugetiny/haipee-app/releases/latest">
    <img src="static/svg/get_it_on_github.svg" alt="Get it on GitHub" width="220"/>
  </a>
</div>

| 文件名 | 适用操作系统 | 说明 |
| :--- | :--- | :--- |
| `haipee-android-arm64-v0.0.1.apk` | Android | 推荐主流 64 位 Android 手机与平板安装 |
| `haipee-android-armv7-v0.0.1.apk` | Android | 适用于 32 位老旧设备 |
| `haipee-android-x86_64-v0.0.1.apk` | Android | 适用于 Android 模拟器与 x86_64 设备 |
| `haipee-windows-v0.0.1.zip` | Windows | 绿色便携版，解压后直接运行 `haipee.exe` |
| `haipee-macos-universal-v0.0.1.zip` | macOS | 通用架构归档，支持 M 系列芯片及 Intel Mac |
| `haipee-linux-v0.0.1-amd64.deb` | Linux (Debian/Ubuntu) | 标准 Debian 安装包，自带桌面图标与启动项关联 |
| `haipee-linux-v0.0.1-amd64.tar.gz` | Linux (通用发行版) | 便携免安装归档包 |
| `haipee-ios-unsigned-v0.0.1.ipa` | iOS | 免签名安装包，供自签名或 TrollStore 侧载 |

---

## 🌐 多语言支持

设置路径：`设置` → `通用` → `应用语言`

- 🇨🇳 简体中文 (`zh-CN`)
- 🇺🇸 English (`en-US`)
- 🇹🇼 繁體中文 (`zh-TW`)
- 🇯🇵 日本語 (`ja-JP`)

---

## ❓ 常见问题 (FAQ)

<details>
<summary><b>Q: 为什么启用 Anime4K 超分辨率后播放有卡顿？</b></summary>

Anime4K 实时超分滤镜直接由 GPU 执行着色计算。如果在核芯显卡或轻薄本上运行，建议在播放面板中选择“性能优先”档位或针对低分辨率视频源开启，可有效降低硬件负荷。
</details>

<details>
<summary><b>Q: 为什么播放视频时内存占用较高？</b></summary>

为保证高码率流媒体在网络抖动环境下的流畅播放，播放内核会预加载部分视听流到动态内存缓冲区中。您可以在「设置 - 播放设置」中开启**低内存模式**以严格限制内存占用上限。
</details>

<details>
<summary><b>Q: Linux 版本下载后应该如何选择？</b></summary>

推荐 Debian、Ubuntu、Linux Mint 等衍生发行版优先使用 `.deb` 格式安装包（通过 `sudo dpkg -i haipee-linux-*.deb` 安装），会自动集成桌面应用启动图标、托盘控制与系统关联。其他 Linux 发行版可直接使用便携 `.tar.gz` 解压使用。
</details>

---

## 📜 声明与协议 (License & Privacy)

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
