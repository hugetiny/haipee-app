# Kazumi Copilot Instructions

## Overview
- Flutter anime client that scrapes sources with XPath plugins and layers a custom media-kit player; entrypoint is `lib/main.dart`.
- Feature modules live under `lib/pages/**`, each pairing a `providers.dart` with a Notifier controller/state (see `lib/providers/providers.dart`).
- Generated artifacts (`*.g.dart`, `*.freezed.dart`) sit beside sources; refresh with `flutter pub run build_runner build --delete-conflicting-outputs` when models or database schema change.

## Boot Flow
- `main.dart` initializes `MediaKit`, Drift Database (`GStorage.init()`), window chrome, and a shared `Dio` client before mounting `ProviderScope`.
- `lib/pages/init_page.dart` runs first: initializes plugins, copies shaders, loads danmaku shields, and eventually routes to `/tab/popular`.
- Initial theme, auto-update mirror, and sync decisions are read from `GStorage.setting` (backed by SQLite); keep that box coherent when modifying onboarding flows.

## Plugin System
- Runtime plugins are stored as one `plugins.json` under the app support dir (`PluginsController`), seeded from `assets/plugins/*.json` if the user accepts the disclaimer.
- `lib/plugins/plugins.dart` defines `Plugin` with XPath selectors (`searchList`, `chapterRoads`, etc.) and fetch logic via `xpath_selector_html_parser`.
- Remote updates come from `PluginHTTP.getPluginList()`; `PluginsController.tryUpdate*` enforces `Api.apiLevel` compatibility and writes back to disk.

## Storage & Sync (Drift Architecture)
- **Local Database**: Replaced Hive with **Drift (SQLite)** defined in `lib/db/database.dart`.
- **Adapter Layer**: `lib/utils/storage.dart` implements `MockBox` to maintain backward compatibility with the Hive-like API (`get`, `put`, `values`), allowing seamless migration of existing controllers.
- **Serialization**: Complex objects (`History`, `CollectedBangumi`, `MetadataRecord`) are serialized to JSON strings before being stored in SQLite text columns.
- **Cloud Sync (Planned)**: Moving towards **Cloudflare D1/R2** for synchronization. WebDAV (`lib/utils/webdav.dart`) is currently maintained but slated for replacement/augmentation.
- **Preferences**: Theme, display, and plugin preferences live in the `Settings` table via `GStorage.setting`.

## Networking
- `Request` wraps a singleton `Dio` with `ApiInterceptor` that injects Bangumi, Dandan, and GitHub proxy headers using `GStorage.setting` flags.
- Use `extra['customError']` to suppress global snackbars via `KazumiDialog.showToast`; pass `shouldRethrow: true` when upstream logic needs raw `DioException`s.
- Plugins and search calls randomize UA / Accept-Language through `Utils` to evade anti-scraping; reuse those helpers for new scrapers.

## Playback Pipeline
- `lib/pages/video/video_controller.dart` orchestrates playlist (`Road`) retrieval via the active `Plugin`, hands URLs to `webviewItemController`, and tracks episode/comments state.
- `lib/pages/player/player_state.dart` is a `freezed` data class powering UI/controls; `PlayerController` toggles Anime4K, aspect ratio, danmaku, and SyncPlay metadata.
- Shaders are copied once by `ShadersController.copyShadersToExternalDirectory()` and consumed by the media-kit pipeline; add new `.glsl` files under `assets/shaders/`.

## UI & Routing
- Navigation uses `GoRouter` with a shell scaffold (`lib/router.dart`); `KazumiDialog.observer` keeps dialog and snackbar contexts in sync with route changes.
- Tabs (`popular`, `timeline`, `collect`, `my`) expose Riverpod notifiers like `PopularController` and `MyController` to manage async loading and pagination.
- Theme selection flows through `themeNotifierProvider`; `AppWidget` applies dynamic color (Material You) when available and toggles OLED-enhanced dark palettes via `Utils.oledDarkTheme`.

## Tooling & Commands
- Standard workflow: `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs`, then `flutter run -d windows` (or target device).
- **Drift**: Run build_runner whenever `lib/db/database.dart` schema changes.
- Custom media-kit and WebView forks are pinned via git dependencies in `pubspec.yaml`; ensure `git` access when resolving packages.
- Windows builds rely on `window_manager` for close prevention/tray; avoid bypassing `windowManager.close()` in desktop exit logic.

## Logging & Debugging
- `KazumiLogger` writes error-level logs to `${ApplicationSupport}/logs/kazumi_logs.log` using a synchronized file lock; call `simpleLog` for quick breadcrumbs.
- User-visible notifications should go through `KazumiDialog.showToast` to respect the shell scaffold; avoid `ScaffoldMessenger` directly outside that helper.
- Player/network issues often stem from plugins; log plugin names and URLs with `KazumiLogger().log(Level.info, ...)` as done in the controllers to aid troubleshooting.

## Design Philosophy & Interaction Guidelines
- **Challenge Unreasonable Requests**: If a user's prompt violates standard UI/UX practices (e.g., placing a "Back to Top" button inside a search input), do not blindly follow it. Instead, politely explain why it might be suboptimal and propose a more standard or user-friendly alternative (e.g., placing it in the AppBar or using a FloatingActionButton).
- **Consistency**: Maintain visual and functional consistency across the app. Re-use existing widgets (`KazumiDialog`, `SysAppBar`) and patterns rather than inventing new ones for one-off features.
- **Material Design**: Adhere to Material Design 3 guidelines where possible, especially for navigation, dialogs, and input fields.
- **User Feedback**: Always provide feedback for actions (Toasts for success/failure, loading indicators for async operations). Use `KazumiDialog.showToast` for transient messages.
