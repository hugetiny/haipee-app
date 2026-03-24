//! OpenClaw Profile Management
//!
//! Manages Haipee's OpenClaw profile directory (~/.openclaw-haipee/).
//!
//! On first startup, creates a fresh minimal profile with default configuration.
//! After initialization, Haipee uses its own profile independently.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Profile name for Haipee
pub const PROFILE_NAME: &str = "haipee";

/// Default gateway port for Haipee (different from main OpenClaw's 18789)
pub const DEFAULT_GATEWAY_PORT: u16 = 18770;

// ============================================================================
// Profile Management
// ============================================================================

/// Get the profile directory path
pub fn get_profile_dir() -> PathBuf {
    dirs::home_dir()
        .expect("Cannot find home directory")
        .join(format!(".openclaw-{}", PROFILE_NAME))
}

/// Check if the profile directory exists
pub fn profile_exists() -> bool {
    get_profile_dir().exists()
}

/// Initialize the Haipee OpenClaw profile
///
/// Creates a fresh minimal profile at ~/.openclaw-haipee/ with default configuration.
/// If the profile already exists, this is a no-op.
pub fn init_profile() -> Result<PathBuf, String> {
    let profile_dir = get_profile_dir();

    if profile_dir.exists() {
        log::info!(
            "[OpenClawProfile] Profile already exists at {:?}",
            profile_dir
        );
        return Ok(profile_dir);
    }

    log::info!(
        "[OpenClawProfile] Creating fresh profile at {:?}",
        profile_dir
    );
    create_minimal_profile(&profile_dir)?;
    update_gateway_port(&profile_dir)?;

    log::info!("[OpenClawProfile] Profile initialized successfully");
    Ok(profile_dir)
}

/// Create a minimal profile with default configuration
fn create_minimal_profile(profile_dir: &Path) -> Result<(), String> {
    // Create essential directory structure
    let dirs = [
        "identity",
        "agents/main/sessions",
        "devices",
        "skills",
        "memory",
        "workspace",
    ];
    for dir in dirs {
        fs::create_dir_all(profile_dir.join(dir))
            .map_err(|e| format!("Failed to create {} directory: {}", dir, e))?;
    }

    // Create minimal openclaw.json config
    create_profile_config(profile_dir)?;

    Ok(())
}

/// Update the gateway port in the profile config
fn update_gateway_port(profile_dir: &Path) -> Result<(), String> {
    let config_path = profile_dir.join("openclaw.json");

    if !config_path.exists() {
        create_profile_config(profile_dir)?;
        return Ok(());
    }

    // Read existing config
    let config_str =
        fs::read_to_string(&config_path).map_err(|e| format!("Failed to read config: {}", e))?;

    let mut config: serde_json::Value =
        serde_json::from_str(&config_str).map_err(|e| format!("Failed to parse config: {}", e))?;

    // Update gateway settings
    if let Some(gateway) = config.get_mut("gateway") {
        if let Some(obj) = gateway.as_object_mut() {
            obj.insert("port".to_string(), serde_json::json!(DEFAULT_GATEWAY_PORT));
            obj.insert("bind".to_string(), serde_json::json!("loopback"));
        }
    } else {
        config["gateway"] = serde_json::json!({
            "mode": "local",
            "port": DEFAULT_GATEWAY_PORT,
            "bind": "loopback"
        });
    }

    // Write updated config
    let updated_config = serde_json::to_string_pretty(&config)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;

    fs::write(&config_path, updated_config)
        .map_err(|e| format!("Failed to write config: {}", e))?;

    log::info!(
        "[OpenClawProfile] Updated gateway port to {}",
        DEFAULT_GATEWAY_PORT
    );
    Ok(())
}

/// Create the profile's openclaw.json configuration
fn create_profile_config(profile_dir: &Path) -> Result<(), String> {
    let config_path = profile_dir.join("openclaw.json");

    if config_path.exists() {
        log::info!("[OpenClawProfile] Config already exists");
        return Ok(());
    }

    // Minimal config for Haipee
    let config = serde_json::json!({
        "agents": {
            "defaults": {
                "model": {
                    "primary": null
                }
            }
        },
        "gateway": {
            "mode": "local",
            "port": DEFAULT_GATEWAY_PORT,
            "bind": "loopback"
        }
    });

    let config_str = serde_json::to_string_pretty(&config)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;

    fs::write(&config_path, config_str).map_err(|e| format!("Failed to write config: {}", e))?;

    log::info!("[OpenClawProfile] Created openclaw.json");
    Ok(())
}

// ============================================================================
// Gateway Token Management
// ============================================================================

/// Get the gateway token for the Haipee profile
///
/// First tries to read from the config file (gateway.auth.token),
/// then falls back to .gateway-token file.
pub fn get_gateway_token() -> Result<String, String> {
    // First, try to read from config file
    let config_path = get_profile_dir().join("openclaw.json");
    if config_path.exists() {
        let config_str = fs::read_to_string(&config_path)
            .map_err(|e| format!("Failed to read config: {}", e))?;

        if let Ok(config) = serde_json::from_str::<serde_json::Value>(&config_str) {
            if let Some(token) = config
                .get("gateway")
                .and_then(|g| g.get("auth"))
                .and_then(|a| a.get("token"))
                .and_then(|t| t.as_str())
            {
                if !token.is_empty() {
                    log::info!("[OpenClawProfile] Found gateway token in config file");
                    return Ok(token.to_string());
                }
            }
        }
    }

    // Fallback: try .gateway-token file
    let token_path = get_profile_dir().join(".gateway-token");
    if token_path.exists() {
        return fs::read_to_string(&token_path)
            .map_err(|e| format!("Failed to read gateway token: {}", e));
    }

    Err("Gateway token not found. Start the gateway first with 'openclaw --profile haipee gateway start'".to_string())
}

/// Check if gateway is running for the Haipee profile
pub fn is_gateway_running() -> bool {
    // Try to connect to the gateway port
    let port = get_gateway_port().unwrap_or(DEFAULT_GATEWAY_PORT);
    std::net::TcpStream::connect(format!("127.0.0.1:{}", port)).is_ok()
}

/// Get the configured gateway port
pub fn get_gateway_port() -> Result<u16, String> {
    let config_path = get_profile_dir().join("openclaw.json");

    if !config_path.exists() {
        return Ok(DEFAULT_GATEWAY_PORT);
    }

    let config_str =
        fs::read_to_string(&config_path).map_err(|e| format!("Failed to read config: {}", e))?;

    let config: serde_json::Value =
        serde_json::from_str(&config_str).map_err(|e| format!("Failed to parse config: {}", e))?;

    Ok(config
        .get("gateway")
        .and_then(|g| g.get("port"))
        .and_then(|p| p.as_u64())
        .map(|p| p as u16)
        .unwrap_or(DEFAULT_GATEWAY_PORT))
}

/// Get the gateway WebSocket URL
pub fn get_gateway_url() -> Result<String, String> {
    let port = get_gateway_port()?;
    Ok(format!("ws://127.0.0.1:{}/ws", port))
}

// ============================================================================
// Session Management
// ============================================================================

/// List sessions for the Haipee profile
pub fn list_sessions() -> Result<serde_json::Value, String> {
    let output = Command::new("openclaw")
        .args(["--profile", PROFILE_NAME, "sessions", "--json"])
        .output()
        .map_err(|e| format!("Failed to execute openclaw: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Failed to list sessions: {}", stderr));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let sessions: serde_json::Value =
        serde_json::from_str(&stdout).map_err(|e| format!("Failed to parse sessions: {}", e))?;

    Ok(sessions)
}

/// Start the gateway for the Haipee profile
pub fn start_gateway() -> Result<(), String> {
    // Check if already running
    if is_gateway_running() {
        log::info!("[OpenClawProfile] Gateway already running");
        return Ok(());
    }

    // Initialize profile if needed
    init_profile()?;

    // Start gateway in background
    let _child = Command::new("openclaw")
        .args(["--profile", PROFILE_NAME, "gateway", "start"])
        .spawn()
        .map_err(|e| format!("Failed to start gateway: {}", e))?;

    log::info!("[OpenClawProfile] Gateway started");
    Ok(())
}

/// Stop the gateway for the Haipee profile
pub fn stop_gateway() -> Result<(), String> {
    let output = Command::new("openclaw")
        .args(["--profile", PROFILE_NAME, "gateway", "stop"])
        .output()
        .map_err(|e| format!("Failed to stop gateway: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Failed to stop gateway: {}", stderr));
    }

    log::info!("[OpenClawProfile] Gateway stopped");
    Ok(())
}

/// Get the status of the gateway
pub fn gateway_status() -> Result<serde_json::Value, String> {
    let output = Command::new("openclaw")
        .args(["--profile", PROFILE_NAME, "gateway", "status", "--json"])
        .output()
        .map_err(|e| format!("Failed to get gateway status: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let status: serde_json::Value =
        serde_json::from_str(&stdout).map_err(|e| format!("Failed to parse status: {}", e))?;

    Ok(status)
}
