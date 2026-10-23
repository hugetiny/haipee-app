# Kazumi Domain

Kazumi is a cross-platform media client for discovering, indexing, and streaming anime content across diverse third-party sources with synchronized playback and metadata tracking.

## Language

### Core Entities

**Bangumi**:
An anime work or series entry containing metadata such as titles, cover images, air dates, episode catalogs, and staff information.
_Avoid_: Anime, show, video, series

**Episode**:
A single broadcast installment or video chapter of a Bangumi.
_Avoid_: Part, chapter, track

**Road**:
A streaming route or source mirror providing playable video stream URLs and resolutions for a specific Episode.
_Avoid_: Route, line, server, mirror

**Plugin**:
A modular declarative rule set or extractor responsible for parsing external media sources. Specializes into `VideoPlugin` (extracting video streams and episode catalogs from Web streaming sites) and `IndexerPlugin` (indexing torrent/magnet releases from P2P trackers).
_Avoid_: Source, scraper, extension, addon

**Web Media Stream (Web在线流媒体体系)**:
The direct client-server media consumption model delivering video catalogs, multi-episode playlists, and HTTP-based live video streams (HLS `.m3u8`, MP4, or DASH `.m4s`). Driven by `VideoPlugin` rules and universal media extractors (such as `yt-dlp` / `lux`), characterized by instant playback, zero local storage requirement, and synchronized danmaku.
_Avoid_: P2P distribution, torrent streaming, local file persistence

**P2P Release Indexing (P2P种子与磁力体系)**:
The decentralized file distribution indexing model querying trackers via Cardigann YAML / Torznab specifications. Results represent multi-file release archives (video, audio, software, games, subtitles) with seed/peer health metrics, consumed either via offline batch download or prioritized sequential piece streaming via the unified Gopeed engine.
_Avoid_: Web scraping, direct HTTP video links, single-stream playback

**Universal Media Extractor (通用流媒体抽取内核)**:
An external specialized extractor engine (such as `yt-dlp` or `Lux`) maintaining high-frequency bypasses for dynamic web signatures, headers verification (Referer/User-Agent), and DASH dual-stream demuxing across major web platforms (Bilibili, Douyin, YouTube).
_Avoid_: Static XPath scraping for big platforms, Torznab tracker indexing

**Dual Discovery Topology (双轨发现拓扑)**:
The intentional architectural separation of Web streaming catalogs and P2P resource search into decoupled primary workflows while preserving cross-domain linkage (e.g. pivoting from an anime info card to full-network torrent search).
_Avoid_: Conflating P2P releases into video playlists, blind monolithic search result mixing


**Indexer Plugin**:
A declarative site definition specification (aligned with Cardigann / Torznab) defining search query parameters, HTML row selectors, CSS/XPath extraction fields, and category mappings for a torrent tracker or release indexer.
_Avoid_: Torrent scraper, tracker script, search plugin

**Plugin Repository**:
A decentralized remote manifest hosting installable, versioned Plugins that clients can subscribe to and auto-update (hosted primarily at `https://github.com/hugetiny/Kazumi` and Git mirrors).
_Avoid_: Store server, central proprietary backend

**Declarative Plugin YAML Specification (Kazumi 声明式插件 YAML 规范)**:
The human-readable YAML/JSON schema declaring scraping selectors, search endpoints, thumbnail extraction fields (`searchPic`), and authentication descriptors (`auth`) for video streaming and metadata extractors.
_Avoid_: Hardcoded site scrapers without schema definitions, monolithic Dart-only plugins

**In-App Plugin Authentication (应用内插件授权与扫码鉴权)**:
The native in-app authentication flow (e.g., official Bilibili QR code passport login) providing zero-leakage, interactive session (`SESSDATA`) capture directly on mobile and desktop viewports, automatically unlocking high-bitrate media streams (1080P/4K DASH) without manual browser cookie copying.
_Avoid_: Requiring users to inspect browser DevTools to copy cookies, storing raw passwords in client

**Torznab Category Mapping**:
The canonical integer-based taxonomy standard (e.g. 2000 for Movies, 5000 for TV, 5070 for Anime, 4000 for Games) used by Indexer Plugins to correlate site-specific sections with unified filter tabs.
_Avoid_: Custom category strings, arbitrary tags

**Cloudflare Bypass**:
An automated failover mechanism that detects Cloudflare Turnstile / anti-bot challenges on raw HTTP requests, launches a headless or sandboxed WebView to obtain valid clearance cookies, and resumes native HTTP scraping.
_Avoid_: Flaresolverr dependency, external proxy requirement

### Playback & Interaction

**Danmaku**:
Synchronized, floating text comments overlaid on top of the video viewport at specific playback timestamps.
_Avoid_: Bullet comment, barrage, floating comment, subtitle

**Playback**:
The active video rendering session including timeline progress, resolution selection, volume, and playback state.
_Avoid_: Player, viewing, watching

### User Data & Sync

**Collect**:
A user-saved bookmark or status tracking for a Bangumi (e.g., watching, completed, planned).
_Avoid_: Favorite, bookmark, star

**History**:
A chronological log recording previously watched Episodes along with playback progress timestamps.
_Avoid_: Record, recent, log

**Metadata Sync**:
The process of synchronizing a user's collection, watch progress, and ratings with external tracking platforms (such as Bangumi.tv).
_Avoid_: Account sync, backup, cloud sync

### Navigation & Shell Layout

**Responsive Scaffold**:
The adaptive outer application shell providing a full-height `NavigationRail` on medium/expanded desktop viewports and a bottom `NavigationBar` on compact mobile viewports.
_Avoid_: Global AppBar, master-detail wrapper

**Home / Resource Catalog (资源分类)**:
The top-level primary landing destination ("资源分类") providing extensible metadata exploration across multiple media categories from configured Metadata Providers.
_Avoid_: Flat unpartitioned video-only tabs, popular dropdown, burying non-video discovery

**Primary Navigation Shell (一级主导航架构)**:
The 5 canonical top-level destinations in the desktop NavigationRail and mobile NavigationBar: 1) 资源分类 (Resource Catalog), 2) 全网资源 (Universal Resource Search), 3) 离线下载 (Offline Downloads), 4) 我的 (My Library), 5) 设置 (Settings). Auxiliary discovery tools (such as Timeline / 时间表) are positioned within their specific domain channels rather than occupying primary navigation real estate.
_Avoid_: Flat 6-item menu with dedicated timeline rail item, overcrowded top bar

**Metadata Provider (元数据源站)**:
An information catalog service (currently default to Bangumi / bgm.tv, architected for future multi-source extensions like TMDB, VNDB, Douban) providing rich metadata, cover art, air dates, staff, and rankings across canonical media categories (for Bangumi: 动画[2], 影视[6], 游戏[4], 音乐[3], 书籍[1]).
_Avoid_: Hardcoded single-site scrapers, video-only assumption, mixing real live-action drama into anime type

**Cross-Domain Resource Linkage (跨域资源联动)**:
The direct interaction bridge linking metadata items to Universal Resource Search. In item detail views:
- Non-video entities (Game, Music, Book): The primary action button routes exclusively to Universal Resource Search with pre-filled title and pre-selected single-choice Torznab category filter.
- Video entities (Anime, Real): Provides clearly differentiated dual actions — Left: "全网资源搜索" (BT/Magnet download), Right: "在线观看" (Legacy HTTP website scraper via VideoPlugin).
_Avoid_: Attempting HTTP video playback on games/books, unlinked manual search retyping


### Resource Discovery & Indexers

**Universal Resource Search**:
A cross-category torrent and Usenet indexing pipeline aggregating releases from Prowlarr, Torznab, and public trackers without domain restrictions.
_Avoid_: Anime-only torrent search, private scraper

**-arr Release Specification**:
Deterministic Scene/P2P media release parsing (extracting resolution, media source, codec, audio, season, episode, and year) coupled with objective interactive sorting (seeders, age, size) and CAM/TS rejection.
_Avoid_: Blackbox weighted scoring, arbitrary multiplier heuristics

**Cardigann Indexer**:
A declarative YAML-defined tracker specification executed by the native Cardigann engine, serving as the sole execution format for local tracker scrapers and eliminating hardcoded single-site scrapers.
_Avoid_: Hardcoded scraper, custom Dart source class, site spider

**Dynamic Indexer Identifier (IndexerId)**:
The canonical unique alphanumeric string (e.g. `nyaasi`, `dmhy`, `1337x`, `torrentscsv`) assigned to each Indexer Plugin, decoupling release sources from fixed enums.
_Avoid_: Hardcoded source enum, static source type

**Torznab Client**:
The remote client interface querying self-hosted or remote Torznab/Newznab aggregators (such as Prowlarr or Jackett) via the standardized XML RSS API, coexisting alongside local Cardigann Indexers as an optional external extension.
_Avoid_: Prowlarr-only scraper, custom tracker gateway, required backend daemon

**Autonomous Dart Torrent Search Layer**:
A self-contained, in-process multi-provider search pipeline implemented entirely in native Dart, executing Cardigann Indexer rules with progressive streaming concurrency, requiring zero external server daemons or child processes across all five platforms.
_Avoid_: Embedded Prowlarr daemon, external background service, local server dependency

**Rule Repository Subscription**:
A decentralized remote manifest subscription mechanism allowing the client to discover, download, and hot-update Cardigann Indexer YAML definitions over HTTP/CDN without requiring application binary updates.
_Avoid_: App Store update for site fixes, hardcoded provider release

**Indexer Lifecycle State**:
The provenance and modification status of an indexer rule, partitioned into Built-in (`assets/indexers/`), Overridden Built-in (local modifications taking precedence with reset fallback), and User Custom (imported third-party rules).
_Avoid_: Monolithic read-only rules, unresettable edits

**Dry-Run Scraping Verification**:
The pre-installation test execution of a Cardigann YAML definition against live target sites to validate selector extraction, HTTP reachability, and result schema before committing to persistent storage.
_Avoid_: Blind rule saving, silent parser failure

### Settings Information Architecture

**Settings Hierarchy**:
The canonical five-tiered taxonomy for application preferences, ordered strictly as: 1) General & Appearance, 2) Media & Playback (视听与媒体), 3) Resource Discovery & Download (资源检索与下载), 4) Data & Cloud Sync (数据与云同步), and 5) About & Support (关于与支持). Rules are strictly decoupled by business domain: online streaming rules reside under Media & Playback as `Kazumi 视频规则`, while torrent indexer rules reside under Resource Discovery & Download as `Cardigann 规则`. Composite or redundant rule management centers are strictly prohibited.
_Avoid_: Flat unorganized settings list, mixed media and tracker configurations, redundant composite rule center options

**Media Settings Domain**:
The sub-hierarchy encompassing core video playback engine, hardware decoding, video upscaling (super resolution), danmaku styling/filtering, metadata providers (Bangumi/TMDB), and online video streaming rules (`Kazumi 视频规则`, including Maccms, DOM scraping, and video rule market).
_Avoid_: Fragmented player toggles on root settings page, mixing Cardigann indexer settings into media rules

**Resource Discovery & Download Domain**:
The unified subsystem managing torrent release indexers (`Cardigann 规则`, including Cardigann YAML definitions, tracker market, and connectivity testing) and the local download manager (Gopeed engine lifecycle, directories, and transfer limits).
_Avoid_: Separating search indexers from download client configuration, redundant multi-source rule aggregators

### Download & Streaming Engine Architecture

**Unified Gopeed Engine (`Gopeed FFI`)**:
The unified in-process Go download and streaming engine operating via Dart FFI. Serves both permanent offline batch acquisition ("立即下载") and real-time media streaming ("在线看") via an internal HTTP 206 Partial Content server with sequential piece scheduling and dynamic sliding-window readahead.
_Avoid_: Aria2 daemon, standalone TorrServer, C++ libtorrent FFI, multi-engine fragmentation

**Sequential Piece Streaming**:
The dynamic read-ahead piece prioritization mechanism in the torrent engine that prioritizes pieces around the current playback offset and head/tail metadata headers, enabling instant video seek and playback before the full torrent is downloaded.
_Avoid_: Random rarest-first streaming playback, blocking on full file download

### Desktop Integration & System Services

**App Icon Dual-Pipeline**:
The dual-layer asset generation and runtime injection pipeline combining build-time multi-resolution packaging (`flutter_launcher_icons`, `AppIcon.appiconset`, `.ico`, `.icns`) with macOS `AppDelegate.swift` runtime `NSApp.applicationIconImage` fallback, immune to LaunchServices Dock icon cache deadlocks.
_Avoid_: Static-only icon replacement, unverified dock icon cache

**System Tray Guardian**:
The background daemon interface managed via `tray_manager`, displaying an adaptive monochrome template icon on macOS (`isTemplate: true`, 18pt) and system-appropriate icons on Windows/Linux, providing instant window restoration and graceful teardown of background engine tasks and child processes.
_Avoid_: Colorful status bar icons on macOS, unmanaged tray process leaks

**Universal Notification Engine (`flutter_local_notifications`)**:
The centralized cross-platform notification subsystem (`NotificationService`) delivering download completion, stream readiness, and background status alerts across macOS Darwin, Windows Toast, Linux libnotify, Android channels, and iOS, with cold-start suppression and click-to-focus window orchestration.
_Avoid_: Mobile-only notification plugins (e.g. `awesome_notifications`), unthrottled startup notification spam

### Responsive Design & Iconography Architecture

**Adaptive Viewport Taxonomy**:
The 3-tier responsive contract strictly enforced across all pages: Compact Mobile (< 600dp), Medium Tablet (600dp ~ 1024dp), and Expanded Desktop (> 1024dp). Single-column form/settings pages enforce `ConstrainedContent(maxWidth: 1000)` centering; discovery/market pages adapt from 1-column mobile lists to 2~3 column `AdaptiveGrid` cards without layout drift.
_Avoid_: Full-screen unbounded list stretch on ultrawide monitors, hardcoded desktop pixel widths, ad-hoc screen type checks

**Minimalist Cyber Interlock Iconography**:
The vector iconography system representing bidirectional peer-to-peer data flow (Download ⬇ and Upload ⬆) through precision multi-facet geometric ribbons and micro-chamfers, rendered against an unpolluted matte obsidian squircle (`#121418`) with zero background glare, zero halos, and zero raw negative cutouts.
_Avoid_: Crude raw black polygon cutouts, blurry background glow halos, skeuomorphic radar noise

### Modern Flutter 3.47+ & M3 Architectural Contracts

**Native Spacing Contract (`Row/Column spacing`)**:
The declarative spacing discipline replacing bare `SizedBox` spacer anti-patterns across layout rows and columns. Ensures automatic spacing folding when sibling elements are conditionally omitted, eliminating redundant RenderBox instantiations and visual spacing anomalies.
_Avoid_: Raw `SizedBox(width: x)` or `SizedBox(height: y)` spacer widgets between homogenous flex children

**Material 3 Hero Carousel (`CarouselView`)**:
The first-class Material 3 multi-browse and hero carousel integration for featured trending media, providing natural inertia snapping, shape morphing, and fluid touch/mouse drag viewport responsiveness across desktop and mobile.
_Avoid_: Ad-hoc PageView hacks, unconstrained horizontal listviews without viewport snapping

**SPM Dual-Track Governance**:
The Apple platform build dependency management policy tracking Swift Package Manager (SPM) migration while stabilizing native CocoaPods bindings for complex C/C++ audio-video engines (`media_kit`, `libtorrent_flutter`), safeguarding against breaking native link errors during framework transitions.
_Avoid_: Reckless unofficial forks of complex C++ plugins, ignoring upstream SPM migration milestones

### Logging Subsystem & Developer Observability

**Unified Logging Subsystem (`AppLog`)**:
The zero-boilerplate static facade unifying application logging across 11 strongly-typed subsystems (`LogModule.stream`, `LogModule.aria2`, `LogModule.indexer`, `LogModule.player`, `LogModule.network`, `LogModule.ui`, `LogModule.download`, `LogModule.syncplay`, `LogModule.storage`, `LogModule.system`, `LogModule.plugin`) backed by `TalkerFlutter`. Provides backward-compatible shims for legacy `KazumiLogger`.
_Avoid_: Scattershot `print` / `debugPrint`, unstructured string logs, unmanaged log levels

**Telemetry Coexistence Topology (`AppLog` & `SentryFlutter` Coexistence)**:
The decoupled two-tier observability topology where `AppLog` acts as the authoritative local Single Source of Truth (SSOT) and `SentryService` acts as the optional cloud APM consumer via `SentryTalkerObserver`. Local developers and offline builds run with zero remote overhead; when a valid Sentry DSN is configured, `AppLog` errors and warnings automatically flow into Sentry Breadcrumbs and Issue events without littering business code with direct Sentry calls.
_Avoid_: Direct duplicate reporting from UI/business layers, conflicting logging abstractions, hardcoded remote telemetry dependencies

**Rolling File Sink**:
The non-blocking, queued file persistence sink maintaining at most 3 fixed-size log files (`kazumi.log`, `kazumi.1.log`, `kazumi.2.log`, 5MB each) in the application support directory, persisting INFO, WARNING, ERROR, and CRITICAL logs (plus DEBUG when developer mode is active).
_Avoid_: Direct synchronous file writes in UI thread, unbounded single log files, loss of operational INFO context

**In-App Developer HUD & Error Perception**:
The developer observability layer providing instant global keyboard shortcuts (`F12`, `Cmd+Shift+L`, `Ctrl+Shift+L`) to toggle the interactive `TalkerScreen` inspector, throttled bottom error notifications with direct 1-click inspection, and an optional floating debug badge in developer mode.
_Avoid_: Hidden unreachable logs, unthrottled error toast spam, needing device USB debuggers to inspect production issues

**Subprocess Log Stream Ingestion**:
The unified I/O stream piping directing stdout/stderr and event callbacks from internal and background engines (such as Gopeed FFI event pipes and external daemons) into `AppLog` with standard module tagging (`[Gopeed]`, `[Download]`, `[Stream]`).
_Avoid_: Swallowing daemon stdout/stderr, unparsed raw character codes, silent child process crashes

### Zero-Screenshot Development Architecture & Introspection

**Zero-Screenshot Development Architecture**:
The 4-layer headless testing and introspection toolchain strictly banning OS-level screenshotting (`screencapture`) and coordinate-based clicking (`CGEvent` / AppleScript). Replaces visual guesswork with deterministic in-memory `WidgetTester` assertions, `ext.flutter.inspector` VM Service JSON-RPC queries, strong semantic `Key` identifiers, and domain-level Robot automation.
_Avoid_: OS screenshot captures, pixel coordinate mouse clicking, visual regression guessing, slow non-deterministic manual verification

**Programmatic Verification Protocol (程序化确定性校验规范)**:
The mandatory development invariant requiring all functional, visual, and liveness verifications to be performed programmatically through unit/widget tests (`flutter test`), VM Service RPC inspections (`tool/inspect_app.dart`), and structured `AppLog` state machine streams. Pixel eyeballing and screenshot rendering are permanently prohibited across all engineering and subagent tasks.
_Avoid_: Taking screenshots to confirm layout, eyeballing image files, manual clicking without Finder assertions

**VM Service Introspection CLI (`tool/inspect_app.dart`)**:
The dedicated developer and AI automation CLI connecting directly to the running Dart VM Service WebSocket (`ws://127.0.0.1:<port>/<token>/ws`). Provides instantaneous runtime overflow scanning (`--check-overflow`), live widget finding by type/key/description (`--find`), compact widget hierarchy tree dumping (`--tree`), and RPC-driven hot reload (`--reload`).
_Avoid_: Relying on blind GUI interaction, uninspected render overflow, guessing whether widgets exist on screen




