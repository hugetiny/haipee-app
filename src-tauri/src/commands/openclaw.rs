use std::collections::HashMap;
use std::sync::Arc;
use tauri::State;

use crate::openclaw_config;
use crate::services::openclaw_gateway::ConnectionStatus;
use crate::services::openclaw_profile;
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

// ============================================================================
// OpenClaw Gateway Commands (1:1 AutoClaw implementation)
// ============================================================================

/// Initialize Haipee's OpenClaw profile
///
/// Creates ~/.openclaw-haipee/ directory with proper structure.
#[tauri::command]
pub fn init_openclaw_profile() -> Result<String, String> {
    let profile_dir = openclaw_profile::init_profile()?;
    Ok(profile_dir.to_string_lossy().to_string())
}

/// Check if OpenClaw profile exists
#[tauri::command]
pub fn openclaw_profile_exists() -> bool {
    openclaw_profile::profile_exists()
}

/// Get OpenClaw Gateway connection status
#[tauri::command]
pub fn get_openclaw_gateway_status(state: State<'_, AppState>) -> serde_json::Value {
    let gateway = state.openclaw_gateway.read();
    match gateway.as_ref() {
        Some(client) => {
            let status = client.status();
            serde_json::json!({
                "connected": client.is_connected(),
                "status": match status {
                    ConnectionStatus::Connected => "connected",
                    ConnectionStatus::Connecting => "connecting",
                    ConnectionStatus::Disconnected => "disconnected",
                    ConnectionStatus::Error(ref _e) => "error",
                },
                "error": match status {
                    ConnectionStatus::Error(ref e) => Some(e),
                    _ => None,
                }
            })
        }
        None => serde_json::json!({
            "connected": false,
            "status": "disconnected",
            "error": null
        }),
    }
}

/// Connect to OpenClaw Gateway
///
/// Initializes the profile if needed, then connects via WebSocket.
#[tauri::command]
pub async fn connect_openclaw_gateway(
    state: State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    // Check if already connected
    {
        let gateway = state.openclaw_gateway.read();
        if let Some(client) = gateway.as_ref() {
            if client.is_connected() {
                return Ok(serde_json::json!({
                    "connected": true,
                    "status": "already_connected"
                }));
            }
        }
    }

    // Initialize profile if needed
    openclaw_profile::init_profile()?;

    // Get gateway URL and token
    let gateway_url = openclaw_profile::get_gateway_url()?;
    let token = match openclaw_profile::get_gateway_token() {
        Ok(t) => t,
        Err(_) => {
            // Try to start the gateway
            openclaw_profile::start_gateway()?;
            // Wait a bit for the gateway to start
            tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
            openclaw_profile::get_gateway_token()?
        }
    };

    log::info!("[OpenClaw] Connecting to gateway: {}", gateway_url);

    // Connect via WebSocket
    let (client, event_receiver) = crate::services::openclaw_gateway::OpenClawGatewayClient::connect(
        &gateway_url,
        &token,
    )
    .await?;

    // Store in state
    {
        let mut gateway = state.openclaw_gateway.write();
        *gateway = Some(client);
    }
    {
        let mut events = state.openclaw_events.write();
        *events = Some(event_receiver);
    }

    log::info!("[OpenClaw] Connected to gateway successfully");

    Ok(serde_json::json!({
        "connected": true,
        "status": "connected"
    }))
}

/// Disconnect from OpenClaw Gateway
#[tauri::command]
pub async fn disconnect_openclaw_gateway(state: State<'_, AppState>) -> Result<(), String> {
    // Take the client out of the state (avoids holding lock across await)
    let client = {
        let mut gateway = state.openclaw_gateway.write();
        gateway.take()
    };

    // Clear events
    {
        let mut events = state.openclaw_events.write();
        *events = None;
    }

    // Now we can safely await without holding the lock
    if let Some(client) = client {
        client.disconnect().await;
    }

    Ok(())
}

/// Send a message to an OpenClaw session via WebSocket
///
/// Uses the `chat.send` RPC method (1:1 copy of AutoClaw's implementation).
#[tauri::command]
pub async fn send_openclaw_message(
    state: State<'_, AppState>,
    session_key: String,
    message: String,
    thinking_level: Option<String>,
) -> Result<serde_json::Value, String> {
    // Clone the Arc to avoid holding the lock across await
    let client = {
        let gateway = state.openclaw_gateway.read();
        match gateway.as_ref() {
            Some(client) => {
                if !client.is_connected() {
                    return Err("Not connected to OpenClaw Gateway".to_string());
                }
                Arc::clone(client)
            }
            None => return Err("Not connected to OpenClaw Gateway. Call connect_openclaw_gateway first.".to_string()),
        }
    };

    client
        .send_message(&session_key, &message, thinking_level.as_deref())
        .await
}

/// Inject a system prompt into an OpenClaw session
#[tauri::command]
pub async fn inject_openclaw_system_prompt(
    state: State<'_, AppState>,
    session_key: String,
    content: String,
) -> Result<(), String> {
    // Clone the Arc to avoid holding the lock across await
    let client = {
        let gateway = state.openclaw_gateway.read();
        match gateway.as_ref() {
            Some(client) => {
                if !client.is_connected() {
                    return Err("Not connected to OpenClaw Gateway".to_string());
                }
                Arc::clone(client)
            }
            None => return Err("Not connected to OpenClaw Gateway".to_string()),
        }
    };

    client.inject_system_prompt(&session_key, &content).await
}

/// List OpenClaw sessions for the Haipee profile
#[tauri::command]
pub fn list_openclaw_sessions() -> Result<serde_json::Value, String> {
    openclaw_profile::list_sessions()
}

/// Start the OpenClaw Gateway for Haipee profile
#[tauri::command]
pub fn start_openclaw_gateway() -> Result<(), String> {
    openclaw_profile::init_profile()?;
    openclaw_profile::start_gateway()
}

/// Stop the OpenClaw Gateway for Haipee profile
#[tauri::command]
pub fn stop_openclaw_gateway() -> Result<(), String> {
    openclaw_profile::stop_gateway()
}

/// Get OpenClaw Gateway status
#[tauri::command]
pub fn get_openclaw_gateway_service_status() -> Result<serde_json::Value, String> {
    openclaw_profile::gateway_status()
}

// ============================================================================
// Skills & MCP Commands
// ============================================================================

/// Skill entry with metadata
#[derive(serde::Serialize)]
pub struct OpenClawSkill {
    pub name: String,
    pub path: String,
    pub is_symlink: bool,
    pub is_directory: bool,
}

/// List all skills in the OpenClaw profile
#[tauri::command]
pub fn list_openclaw_skills() -> Result<Vec<OpenClawSkill>, String> {
    let skills_dir = openclaw_profile::get_profile_dir().join("skills");

    if !skills_dir.exists() {
        return Ok(Vec::new());
    }

    let mut skills = Vec::new();

    let entries = std::fs::read_dir(&skills_dir)
        .map_err(|e| format!("Failed to read skills directory: {}", e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read entry: {}", e))?;
        let name = entry.file_name().to_string_lossy().to_string();
        let path = entry.path();
        let metadata = std::fs::symlink_metadata(&path).ok();

        let is_symlink = metadata.as_ref().map(|m| m.file_type().is_symlink()).unwrap_or(false);
        let is_directory = metadata.as_ref().map(|m| m.is_dir()).unwrap_or(false);

        skills.push(OpenClawSkill {
            name,
            path: path.to_string_lossy().to_string(),
            is_symlink,
            is_directory,
        });
    }

    // Sort by name
    skills.sort_by(|a, b| a.name.cmp(&b.name));

    Ok(skills)
}

/// Provider entry from openclaw.json
#[derive(serde::Serialize)]
pub struct OpenClawProviderInfo {
    pub id: String,
    pub name: String,
    pub base_url: Option<String>,
    pub api_type: Option<String>,
    pub models_count: usize,
}

/// List all providers from openclaw.json models.providers
#[tauri::command]
pub fn list_openclaw_providers() -> Result<Vec<OpenClawProviderInfo>, String> {
    let providers = openclaw_config::get_providers()
        .map_err(|e| e.to_string())?;

    let mut result = Vec::new();

    for (id, value) in providers {
        let obj = value.as_object().cloned().unwrap_or_default();

        let name = obj.get("name")
            .and_then(|v| v.as_str())
            .unwrap_or(&id)
            .to_string();

        let base_url = obj.get("baseUrl")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let api_type = obj.get("api")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let models_count = obj.get("models")
            .and_then(|v| v.as_array())
            .map(|arr| arr.len())
            .unwrap_or(0);

        result.push(OpenClawProviderInfo {
            id,
            name,
            base_url,
            api_type,
            models_count,
        });
    }

    // Sort by name
    result.sort_by(|a, b| a.name.cmp(&b.name));

    Ok(result)
}
