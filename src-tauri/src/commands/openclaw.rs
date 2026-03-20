use std::collections::HashMap;
use tauri::State;

use crate::openclaw_config;
use crate::store::AppState;

// ============================================================================
// OpenClaw Provider Commands (migrated from provider.rs)
// ============================================================================

/// Import providers from OpenClaw live config to database.
///
/// OpenClaw uses additive mode — users may already have providers
/// configured in openclaw.json.
#[tauri::command]
pub fn import_openclaw_providers_from_live(state: State<'_, AppState>) -> Result<usize, String> {
    crate::services::provider::import_openclaw_providers_from_live(state.inner())
        .map_err(|e| e.to_string())
}

/// Get provider IDs in the OpenClaw live config.
#[tauri::command]
pub fn get_openclaw_live_provider_ids() -> Result<Vec<String>, String> {
    openclaw_config::get_providers()
        .map(|providers| providers.keys().cloned().collect())
        .map_err(|e| e.to_string())
}

/// Get a single OpenClaw provider fragment from live config.
#[tauri::command]
pub fn get_openclaw_live_provider(
    #[allow(non_snake_case)] providerId: String,
) -> Result<Option<serde_json::Value>, String> {
    openclaw_config::get_provider(&providerId).map_err(|e| e.to_string())
}

/// Scan openclaw.json for known configuration hazards.
#[tauri::command]
pub fn scan_openclaw_config_health() -> Result<Vec<openclaw_config::OpenClawHealthWarning>, String>
{
    openclaw_config::scan_openclaw_config_health().map_err(|e| e.to_string())
}

// ============================================================================
// Agents Configuration Commands
// ============================================================================

/// Get OpenClaw default model config (agents.defaults.model)
#[tauri::command]
pub fn get_openclaw_default_model() -> Result<Option<openclaw_config::OpenClawDefaultModel>, String>
{
    openclaw_config::get_default_model().map_err(|e| e.to_string())
}

/// Set OpenClaw default model config (agents.defaults.model)
#[tauri::command]
pub fn set_openclaw_default_model(
    model: openclaw_config::OpenClawDefaultModel,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_default_model(&model).map_err(|e| e.to_string())
}

/// Get OpenClaw model catalog/allowlist (agents.defaults.models)
#[tauri::command]
pub fn get_openclaw_model_catalog(
) -> Result<Option<HashMap<String, openclaw_config::OpenClawModelCatalogEntry>>, String> {
    openclaw_config::get_model_catalog().map_err(|e| e.to_string())
}

/// Set OpenClaw model catalog/allowlist (agents.defaults.models)
#[tauri::command]
pub fn set_openclaw_model_catalog(
    catalog: HashMap<String, openclaw_config::OpenClawModelCatalogEntry>,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_model_catalog(&catalog).map_err(|e| e.to_string())
}

/// Get full agents.defaults config (all fields)
#[tauri::command]
pub fn get_openclaw_agents_defaults(
) -> Result<Option<openclaw_config::OpenClawAgentsDefaults>, String> {
    openclaw_config::get_agents_defaults().map_err(|e| e.to_string())
}

/// Set full agents.defaults config (all fields)
#[tauri::command]
pub fn set_openclaw_agents_defaults(
    defaults: openclaw_config::OpenClawAgentsDefaults,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_agents_defaults(&defaults).map_err(|e| e.to_string())
}

// ============================================================================
// Env Configuration Commands
// ============================================================================

/// Get OpenClaw env config (env section of openclaw.json)
#[tauri::command]
pub fn get_openclaw_env() -> Result<openclaw_config::OpenClawEnvConfig, String> {
    openclaw_config::get_env_config().map_err(|e| e.to_string())
}

/// Set OpenClaw env config (env section of openclaw.json)
#[tauri::command]
pub fn set_openclaw_env(
    env: openclaw_config::OpenClawEnvConfig,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_env_config(&env).map_err(|e| e.to_string())
}

// ============================================================================
// Tools Configuration Commands
// ============================================================================

/// Get OpenClaw tools config (tools section of openclaw.json)
#[tauri::command]
pub fn get_openclaw_tools() -> Result<openclaw_config::OpenClawToolsConfig, String> {
    openclaw_config::get_tools_config().map_err(|e| e.to_string())
}

/// Set OpenClaw tools config (tools section of openclaw.json)
#[tauri::command]
pub fn set_openclaw_tools(
    tools: openclaw_config::OpenClawToolsConfig,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_tools_config(&tools).map_err(|e| e.to_string())
}

// ============================================================================
// Generic JSON Configuration Commands
// ============================================================================

/// Get an arbitrary section from openclaw.json
#[tauri::command]
pub fn get_openclaw_json_section(section: String) -> Result<serde_json::Value, String> {
    openclaw_config::get_json_section(&section).map_err(|e| e.to_string())
}

/// Set an arbitrary section in openclaw.json
#[tauri::command]
pub fn set_openclaw_json_section(
    section: String,
    value: serde_json::Value,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::set_json_section(&section, &value).map_err(|e| e.to_string())
}

// ============================================================================
// Raw JSON I/O Commands
// ============================================================================

/// Read raw openclaw.json text
#[tauri::command]
pub fn read_openclaw_json_raw() -> Result<String, String> {
    openclaw_config::read_json_raw().map_err(|e| e.to_string())
}

/// Write raw openclaw.json text
#[tauri::command]
pub fn write_openclaw_json_raw(
    content: String,
) -> Result<openclaw_config::OpenClawWriteOutcome, String> {
    openclaw_config::write_json_raw(&content).map_err(|e| e.to_string())
}

/// Find OpenClaw session key by session ID
///
/// OpenClaw TUI requires session key (e.g., "agent:main:main") for --session parameter,
/// but we only have the sessionId (UUID). This looks up the key from sessions.json.
#[tauri::command]
pub fn find_openclaw_session_key(session_id: String) -> Result<Option<String>, String> {
    openclaw_config::find_session_key_by_id(&session_id).map_err(|e| e.to_string())
}
