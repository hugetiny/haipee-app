//! OpenClaw Gateway HTTP Client
//!
//! Uses HTTP API to communicate with OpenClaw Gateway.
//! Simpler than WebSocket approach - no device authentication required.

use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

// ============================================================================
// Types
// ============================================================================

/// Connection status
#[derive(Debug, Clone, PartialEq, Serialize)]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Connected,
    Error(String),
}

/// Chat completion request (OpenAI-compatible)
#[derive(Serialize)]
struct ChatCompletionRequest {
    model: String,
    messages: Vec<ChatMessage>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stream: Option<bool>,
}

/// Chat message
#[derive(Serialize)]
struct ChatMessage {
    role: String,
    content: String,
}

/// Chat completion response (OpenAI-compatible)
#[derive(Deserialize)]
struct ChatCompletionResponse {
    choices: Vec<ChatChoice>,
}

/// Chat choice
#[derive(Deserialize)]
struct ChatChoice {
    message: ChatMessageResponse,
}

/// Chat message in response
#[derive(Deserialize)]
struct ChatMessageResponse {
    content: String,
}

/// Agent stream event (for future streaming support)
#[derive(Debug, Clone, Serialize)]
#[allow(dead_code)]
pub struct AgentStreamEvent {
    pub session_key: String,
    pub run_id: String,
    pub event_type: String,
    pub content: Option<String>,
    pub is_complete: bool,
}

// ============================================================================
// Gateway Client
// ============================================================================

/// OpenClaw Gateway HTTP client
///
/// Uses HTTP API to communicate with OpenClaw Gateway.
/// No device authentication required - just gateway token.
pub struct OpenClawGatewayClient {
    /// Gateway base URL (e.g., "http://127.0.0.1:18770")
    base_url: String,
    /// Gateway authentication token
    token: String,
    /// Default model to use
    default_model: Option<String>,
    /// Connection status
    status: Arc<RwLock<ConnectionStatus>>,
}

impl OpenClawGatewayClient {
    /// Default request timeout (2 minutes)
    const DEFAULT_TIMEOUT_SECS: u64 = 120;

    /// Create a new gateway client
    ///
    /// # Arguments
    /// * `gateway_url` - WebSocket or HTTP URL (e.g., "ws://127.0.0.1:18770/ws" or "http://127.0.0.1:18770")
    /// * `token` - Gateway authentication token
    pub fn new(gateway_url: &str, token: &str) -> Self {
        // Normalize URL - convert ws:// to http:// and remove /ws suffix
        let base_url = gateway_url
            .replace("ws://", "http://")
            .replace("wss://", "https://");

        let base_url = base_url.trim_end_matches("/ws").trim_end_matches("/");

        Self {
            base_url: base_url.to_string(),
            token: token.to_string(),
            default_model: None,
            status: Arc::new(RwLock::new(ConnectionStatus::Disconnected)),
        }
    }

    /// Connect to the gateway (verify connectivity)
    pub async fn connect(&self) -> Result<(), String> {
        *self.status.write() = ConnectionStatus::Connecting;

        // Try to hit the gateway health endpoint
        let url = format!("{}/v1/models", self.base_url);

        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .timeout(std::time::Duration::from_secs(10))
            .send()
            .await
            .map_err(|e| format!("Failed to connect to gateway: {}", e))?;

        if response.status().is_success() || response.status().as_u16() == 403 {
            // 403 is expected for some providers, but means gateway is reachable
            *self.status.write() = ConnectionStatus::Connected;
            log::info!("[OpenClawGateway] Connected to {}", self.base_url);
            Ok(())
        } else {
            let status = response.status();
            *self.status.write() = ConnectionStatus::Error(format!("HTTP {}", status));
            Err(format!("Gateway returned HTTP {}", status))
        }
    }

    /// Set the default model for chat completions
    pub fn set_default_model(&mut self, model: String) {
        self.default_model = Some(model);
    }

    /// Send a message to the agent
    ///
    /// Uses the OpenAI-compatible /v1/chat/completions endpoint.
    ///
    /// # Arguments
    /// * `message` - Message content
    /// * `model` - Optional model override (e.g., "kimi/kimi-for-coding")
    pub async fn send_message(&self, message: &str, model: Option<&str>) -> Result<String, String> {
        let model = model
            .or(self.default_model.as_deref())
            .unwrap_or("kimi/kimi-for-coding");

        let request = ChatCompletionRequest {
            model: model.to_string(),
            messages: vec![ChatMessage {
                role: "user".to_string(),
                content: message.to_string(),
            }],
            stream: Some(false),
        };

        let url = format!("{}/v1/chat/completions", self.base_url);

        log::info!("[OpenClawGateway] Sending message to model: {}", model);

        let client = reqwest::Client::new();
        let response = client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/json")
            .json(&request)
            .timeout(std::time::Duration::from_secs(Self::DEFAULT_TIMEOUT_SECS))
            .send()
            .await
            .map_err(|e| format!("HTTP request failed: {}", e))?;

        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|e| format!("Failed to read response: {}", e))?;

        if !status.is_success() {
            log::error!("[OpenClawGateway] HTTP {}: {}", status, body);
            return Err(format!("HTTP {}: {}", status, body));
        }

        // Parse OpenAI-compatible response
        let completion: ChatCompletionResponse = serde_json::from_str(&body)
            .map_err(|e| format!("Failed to parse response: {} - body: {}", e, body))?;

        if let Some(choice) = completion.choices.first() {
            Ok(choice.message.content.clone())
        } else {
            Err("No response from agent".to_string())
        }
    }

    /// Send a message and get raw JSON response
    pub async fn send_message_raw(
        &self,
        message: &str,
        model: Option<&str>,
    ) -> Result<serde_json::Value, String> {
        let model = model
            .or(self.default_model.as_deref())
            .unwrap_or("kimi/kimi-for-coding");

        let request = ChatCompletionRequest {
            model: model.to_string(),
            messages: vec![ChatMessage {
                role: "user".to_string(),
                content: message.to_string(),
            }],
            stream: Some(false),
        };

        let url = format!("{}/v1/chat/completions", self.base_url);

        let client = reqwest::Client::new();
        let response = client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.token))
            .header("Content-Type", "application/json")
            .json(&request)
            .timeout(std::time::Duration::from_secs(Self::DEFAULT_TIMEOUT_SECS))
            .send()
            .await
            .map_err(|e| format!("HTTP request failed: {}", e))?;

        let status = response.status();
        let body = response
            .text()
            .await
            .map_err(|e| format!("Failed to read response: {}", e))?;

        if !status.is_success() {
            return Err(format!("HTTP {}: {}", status, body));
        }

        serde_json::from_str(&body).map_err(|e| format!("Failed to parse JSON: {}", e))
    }

    /// Get connection status
    pub fn status(&self) -> ConnectionStatus {
        self.status.read().clone()
    }

    /// Check if connected
    pub fn is_connected(&self) -> bool {
        matches!(*self.status.read(), ConnectionStatus::Connected)
    }

    /// Disconnect (no-op for HTTP client)
    pub fn disconnect(&self) {
        *self.status.write() = ConnectionStatus::Disconnected;
        log::info!("[OpenClawGateway] Disconnected");
    }
}
