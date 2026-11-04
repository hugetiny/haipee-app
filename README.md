<div align="center">

# Haipee

**A modern cross-platform media hub and high-speed download aggregator**

[![Version](https://img.shields.io/badge/version-0.0.1-blue.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20iOS-orange.svg)](https://github.com/hugetiny/haipee-app/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)

**[English](README.md)** • **[简体中文](README_zh.md)**

[Official Website](https://haipee.com) • [Features](#-features) • [Supported Platforms](#-supported-platforms) • [Download](#-download) • [Languages](#-languages) • [FAQ](#-frequently-asked-questions-faq) • [License & Privacy](#-license--privacy) • [Credits](#-credits)

</div>

---

## ✨ Features

- ⚡ **Embedded Gopeed Download Engine**: Native multi-threaded HTTP/HTTPS acceleration, high-speed BitTorrent & Magnet link resolution, breakpoint resuming, and intelligent queue management.
- 🎬 **Universal Media Player**: Powered by the high-performance `media-kit` core with full hardware decoding acceleration, DASH/HLS streaming support, and real-time Anime4K super-resolution upscaling shaders.
- 💬 **Interactive Danmaku & Subtitles**: Deep integration with the open Dandanplay protocol for automated title recognition, synchronized floating comments (danmaku), and smart subtitle matching.
- 🔍 **Unified Multi-Source Ecosystem**: Comprehensive search and aggregation across Online Video sources, TV / IPTV Live channels, Cloud Drives (WebDAV / Alist), and BT / Magnet Indexers (supporting Cardigann, Torznab, and Prowlarr protocols).
- 🎨 **Modern Adaptive UI**: Fluid Material You dynamic palette theming, with responsive layouts across mobile touchscreens and desktop environments (macOS window control safe areas, native context menus, and global keyboard shortcuts).
- 🌐 **Comprehensive Localization**: Built on `slang` with out-of-the-box support for English, Simplified Chinese, Traditional Chinese, and Japanese.

---

## 📱 Supported Platforms

| Platform | Minimum Requirement | Architecture | Distribution Type |
| :--- | :--- | :--- | :--- |
| **Android** | Android 10+ | arm64-v8a / armeabi-v7a / x86_64 | Standalone APK |
| **Windows** | Windows 10+ | x64 | Portable Zip Archive |
| **macOS** | macOS 10.15+ (Catalina) | Universal (Apple Silicon & Intel) | Native App Bundle in Zip |
| **Linux** | Ubuntu 20.04+ / Debian 11+ | amd64 | Debian `.deb` & Portable `.tar.gz` |
| **iOS** | iOS 13+ | arm64 | Unsigned `.ipa` (TrollStore / Sideloading) |

---

## ⬇️ Download

Download the latest release binaries directly from the [GitHub Releases Page](https://github.com/hugetiny/haipee-app/releases/latest):

<div align="center">
  <a href="https://github.com/hugetiny/haipee-app/releases/latest">
    <img src="static/svg/get_it_on_github.svg" alt="Get it on GitHub" width="220"/>
  </a>
</div>

| Filename | Target System | Description |
| :--- | :--- | :--- |
| `haipee-android-arm64-v0.0.1.apk` | Android | Recommended for modern 64-bit phones and tablets |
| `haipee-android-armv7-v0.0.1.apk` | Android | 32-bit legacy Android devices |
| `haipee-android-x86_64-v0.0.1.apk` | Android | Android emulators & x86_64 hardware |
| `haipee-windows-v0.0.1.zip` | Windows | Portable zip package; extract and run `haipee.exe` |
| `haipee-macos-universal-v0.0.1.zip` | macOS | Universal binary (Apple Silicon M-series & Intel) |
| `haipee-linux-v0.0.1-amd64.deb` | Linux (Debian/Ubuntu) | Standard Debian package with system launcher integration |
| `haipee-linux-v0.0.1-amd64.tar.gz` | Linux (Generic) | Portable tarball archive |
| `haipee-ios-unsigned-v0.0.1.ipa` | iOS | Unsigned package for self-signing or TrollStore installation |

---

## 🌐 Languages

Configure language at: `Settings` → `General` → `App Language`

- 🇺🇸 English (`en-US`)
- 🇨🇳 简体中文 (`zh-CN`)
- 🇹🇼 繁體中文 (`zh-TW`)
- 🇯🇵 日本語 (`ja-JP`)

---

## ❓ Frequently Asked Questions (FAQ)

<details>
<summary><b>Q: Why does playback stutter when Anime4K super-resolution is enabled?</b></summary>

Anime4K applies real-time GLSL super-resolution shader passes directly on your GPU. On integrated graphics cards or thin-and-light laptops, it is recommended to select the "Fast / Efficiency" preset or apply it primarily to lower-resolution media (e.g. 720p or 480p) to conserve GPU computing resources.
</details>

<details>
<summary><b>Q: Why does memory usage increase during video playback?</b></summary>

To maintain stutter-free playback for high-bitrate streaming over unstable or fluctuating network conditions, the playback engine pre-buffers video and audio packets into a dynamic memory cache. You can toggle **Low Memory Mode** under `Settings` → `Player Settings` to enforce strict buffer boundaries.
</details>

<details>
<summary><b>Q: Which Linux package should I choose?</b></summary>

For Debian, Ubuntu, Linux Mint, and related distributions, installing the `.deb` package (`sudo dpkg -i haipee-linux-*.deb`) is recommended as it registers the desktop launcher, application icons, and system associations. For other Linux distributions, use the portable `.tar.gz` archive.
</details>

---

## 📜 License & Privacy

- **Open Source License**: Distributed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
- **Privacy Commitment**: Haipee is strictly local-first. It does not collect any personal data, nor does it contain analytics trackers or remote telemetry.

---

## 🙏 Credits

- [Gopeed](https://github.com/GopeedLab/gopeed) - High-performance multi-threaded download and BitTorrent engine.
- [media-kit](https://github.com/media-kit/media-kit) - Cross-platform media playback library for Flutter.
- [Dandanplay](https://www.dandanplay.com/) - Open danmaku protocol and comment databases.
- [Bangumi](https://bangumi.tv/) - Open media metadata and subject information APIs.
- [Anime4K](https://github.com/bloc97/Anime4K) - Real-time high-quality anime upscaling algorithms.
- [xpath_selector](https://github.com/simonkimi/xpath_selector) - Lightweight XPath parsing and node extraction library.
