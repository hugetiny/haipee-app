//! E2E Test Mode Support
//!
//! When HAIPEE_E2E_MODE=1 is set, the app runs in E2E test mode:
//! - Interactive dialogs are skipped (auto-retry or use defaults)
//! - Database initialization auto-recovers from failures

/// Check if the app is running in E2E test mode
pub fn is_enabled() -> bool {
    std::env::var("HAIPEE_E2E_MODE")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false)
}

/// Handle config load error in E2E mode
/// Returns true if should retry, false if should skip migration
pub fn handle_config_error(attempt: &mut u8) -> bool {
    *attempt += 1;
    if *attempt >= 2 {
        log::warn!("[E2E] Config load failed after retries, skipping migration");
        false
    } else {
        log::info!("[E2E] Auto-retrying config load (attempt {})", *attempt);
        true
    }
}

/// Handle database init error in E2E mode
/// Returns true if should retry
pub fn handle_db_error(attempt: &mut u8, db_path: &std::path::Path) -> bool {
    *attempt += 1;
    if *attempt >= 2 {
        // Remove corrupted DB and retry with fresh one
        if db_path.exists() {
            log::warn!("[E2E] Removing corrupted database");
            let _ = std::fs::remove_file(db_path);
        }
        *attempt = 0; // Reset for fresh retry
        true
    } else {
        log::info!("[E2E] Auto-retrying database init (attempt {})", *attempt);
        true
    }
}
