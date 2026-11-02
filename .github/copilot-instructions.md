# Haipee Copilot Instructions

## Overview
- Flutter anime client that scrapes sources with XPath plugins and layers a custom media-kit player; entrypoint is `lib/main.dart`.
- Feature modules live under `lib/pages/**`, each pairing a `providers.dart` with a Notifier controller/state (see `lib/providers/providers.dart`).
- Generated artifacts (`*.g.dart`, `*.freezed.dart`) sit beside sources; refresh with `flutter pub run build_runner build --delete-conflicting-outputs` when models change.

## Boot Flow
- `main.dart` initializes `MediaKit`, Hive (`GStorage.init()`), window chrome, and a shared `Dio` client before mounting `ProviderScope`.
- `lib/pages/init_page.dart` runs first: migrates Hive boxes, copies shaders, loads danmaku shields, prompts for plugin consent, and eventually routes to `/tab/popular`.
- Initial theme, auto-update mirror, and WebDAV sync decisions are read from `GStorage.setting`; keep that box coherent when modifying onboarding flows.

## Plugin System
- Runtime plugins are stored as one `plugins.json` under the app support dir (`PluginsController`), seeded from `assets/plugins/*.json` if the user accepts the disclaimer.
- `lib/plugins/plugins.dart` defines `Plugin` with XPath selectors (`searchList`, `chapterRoads`, etc.) and fetch logic via `xpath_selector_html_parser`.
- Remote updates come from `PluginHTTP.getPluginList()`; `PluginsController.tryUpdate*` enforces `Api.apiLevel` compatibility and writes back to disk.

## Storage & Sync
- `lib/utils/storage.dart` centralizes Hive boxes (`collectibles`, `histories`, `collectChanges`, `shieldList`, etc.) and exposes patch/restore helpers for WebDAV.
- WebDAV sync (`lib/utils/webdav.dart`) copies `.hive` files to `/haipeeSync` with optimistic merge rules; guard `isHistorySyncing` when scheduling background tasks.
- Theme, display, and plugin preferences originate from the `setting` box; update via Riverpod notifiers (see `lib/pages/settings/providers.dart`) then persist.

## Networking
- `Request` wraps a singleton `Dio` with `ApiInterceptor` that injects Bangumi, Dandan, and GitHub proxy headers using `GStorage.setting` flags.
- Use `extra['customError']` to suppress global snackbars via `HaipeeDialog.showToast`; pass `shouldRethrow: true` when upstream logic needs raw `DioException`s.
- Plugins and search calls randomize UA / Accept-Language through `Utils` to evade anti-scraping; reuse those helpers for new scrapers.

## Playback Pipeline
- `lib/pages/video/video_controller.dart` orchestrates playlist (`Road`) retrieval via the active `Plugin`, hands URLs to `webviewItemController`, and tracks episode/comments state.
- `lib/pages/player/player_state.dart` is a `freezed` data class powering UI/controls; `PlayerController` toggles Anime4K, aspect ratio, danmaku, and SyncPlay metadata.
- Shaders are copied once by `ShadersController.copyShadersToExternalDirectory()` and consumed by the media-kit pipeline; add new `.glsl` files under `assets/shaders/`.

## UI & Routing
- Navigation uses `GoRouter` with a shell scaffold (`lib/router.dart`); `HaipeeDialog.observer` keeps dialog and snackbar contexts in sync with route changes.
- Tabs (`popular`, `timeline`, `collect`, `my`) expose Riverpod notifiers like `PopularController` and `MyController` to manage async loading and pagination.
- Theme selection flows through `themeNotifierProvider`; `AppWidget` applies dynamic color (Material You) when available and toggles OLED-enhanced dark palettes via `Utils.oledDarkTheme`.

## Tooling & Commands
- Standard workflow: `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs`, then `flutter run -d windows` (or target device).
- Custom media-kit and WebView forks are pinned via git dependencies in `pubspec.yaml`; ensure `git` access when resolving packages.
- Windows builds rely on `window_manager` for close prevention/tray; avoid bypassing `windowManager.close()` in desktop exit logic.

## Logging & Debugging
- `HaipeeLogger` writes error-level logs to `${ApplicationSupport}/logs/haipee_logs.log` using a synchronized file lock; call `simpleLog` for quick breadcrumbs.
- User-visible notifications should go through `HaipeeDialog.showToast` to respect the shell scaffold; avoid `ScaffoldMessenger` directly outside that helper.
- Player/network issues often stem from plugins; log plugin names and URLs with `HaipeeLogger().log(Level.info, ...)` as done in the controllers to aid troubleshooting.
<parameter name="filePath">d:\Users\huget\StudioProjects\Haipee\.github\copilot-instructions.md
