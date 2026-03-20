//! E2E Testing Commands
//!
//! These commands are primarily useful for E2E testing with WebDriver.
//! They use doc(hidden) when the webdriver feature is not enabled.

use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct E2eAppInfo {
    pub version: String,
    pub is_e2e_mode: bool,
    pub platform: String,
}

/// Get app version and E2E mode status
/// Useful for tests to verify the app is running in E2E mode.
#[tauri::command]
#[cfg_attr(not(feature = "webdriver"), doc(hidden))]
pub fn e2e_get_app_info() -> E2eAppInfo {
    E2eAppInfo {
        version: env!("CARGO_PKG_VERSION").to_string(),
        is_e2e_mode: crate::e2e_mode::is_enabled(),
        platform: std::env::consts::OS.to_string(),
    }
}

/// Verify that the backend is responsive
/// Returns true if the Rust backend is ready to handle requests.
#[tauri::command]
#[cfg_attr(not(feature = "webdriver"), doc(hidden))]
pub fn e2e_ping() -> bool {
    true
}
