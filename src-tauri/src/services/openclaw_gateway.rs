//! OpenClaw Gateway WebSocket Client
//!
//! 1:1 copy of AutoClaw's GatewayClient implementation.
//! Uses WebSocket to connect to OpenClaw Gateway and send messages via `chat.send` RPC.

use dashmap::DashMap;
use futures_util::{SinkExt, StreamExt};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{mpsc, oneshot};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use uuid::Uuid;

// ============================================================================
// Types
// ============================================================================

/// Gateway request frame (sent to WebSocket)
#[derive(Serialize)]
struct GatewayRequest {
    #[serde(rename = "type")]
    msg_type: String,
    id: String,
    method: String,
    params: serde_json::Value,
}

/// Gateway response frame (received from WebSocket)
#[derive(Deserialize)]
struct GatewayResponse {
    #[serde(rename = "type")]
    msg_type: String,
    id: String,
    ok: bool,
    result: Option<serde_json::Value>,
    error: Option<GatewayError>,
}

/// Gateway error
#[derive(Deserialize)]
struct GatewayError {
    message: String,
    #[serde(rename = "type")]
    error_type: Option<String>,
}

/// Gateway event frame (streaming)
#[derive(Deserialize)]
pub struct GatewayEvent {
    #[serde(rename = "type")]
    pub msg_type: String,
    pub event: String,
    pub data: serde_json::Value,
}

/// Connection status
#[derive(Debug, Clone, PartialEq, Serialize)]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Connected,
    Error(String),
}

/// Agent stream event (for streaming responses)
#[derive(Debug, Clone, Serialize)]
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

/// OpenClaw Gateway WebSocket client
///
/// This is a 1:1 copy of AutoClaw's GatewayClient implementation.
/// Uses WebSocket to connect to OpenClaw Gateway and send messages via `chat.send` RPC.
pub struct OpenClawGatewayClient {
    /// WebSocket sender channel
    ws_sender: mpsc::Sender<WsMessage>,
    /// Pending requests waiting for response
    pending_requests: Arc<DashMap<String, oneshot::Sender<Result<serde_json::Value, String>>>>,
    /// Connection status
    status: Arc<RwLock<ConnectionStatus>>,
    /// Event callback sender
    event_sender: mpsc::Sender<AgentStreamEvent>,
    /// Abort signal for background tasks
    abort_tx: mpsc::Sender<()>,
}

impl OpenClawGatewayClient {
    /// Default request timeout (30 seconds)
    const DEFAULT_TIMEOUT_MS: u64 = 30_000;
    /// Chat send timeout (2 minutes, matching AutoClaw)
    const CHAT_SEND_TIMEOUT_MS: u64 = 120_000;

    /// Connect to OpenClaw Gateway
    ///
    /// # Arguments
    /// * `gateway_url` - WebSocket URL (e.g., "ws://127.0.0.1:18770/ws")
    /// * `token` - Gateway authentication token
    ///
    /// # Returns
    /// Connected client instance
    pub async fn connect(
        gateway_url: &str,
        token: &str,
    ) -> Result<(Arc<Self>, mpsc::Receiver<AgentStreamEvent>), String> {
        // Build URL with token
        let url = if gateway_url.contains('?') {
            format!("{}&token={}", gateway_url, token)
        } else {
            format!("{}?token={}", gateway_url, token)
        };

        log::info!("[OpenClawGateway] Connecting to {}", gateway_url);

        // Connect WebSocket
        let (ws_stream, _) = connect_async(&url)
            .await
            .map_err(|e| format!("WebSocket connect failed: {}", e))?;

        let (write, read) = ws_stream.split();

        // Create channels
        let (ws_sender, ws_receiver) = mpsc::channel(100);
        let (event_sender, event_receiver) = mpsc::channel(100);
        let (abort_tx, _abort_rx) = mpsc::channel(1);

        // Shared state
        let pending_requests: Arc<DashMap<String, oneshot::Sender<Result<serde_json::Value, String>>>> =
            Arc::new(DashMap::new());
        let status = Arc::new(RwLock::new(ConnectionStatus::Connected));

        let client = Arc::new(Self {
            ws_sender,
            pending_requests: pending_requests.clone(),
            status: status.clone(),
            event_sender: event_sender.clone(),
            abort_tx,
        });

        // Spawn write task (send requests)
        tokio::spawn(async move {
            Self::write_task(ws_receiver, write).await;
        });

        // Spawn read task (receive responses/events)
        let event_sender_clone = event_sender;
        tokio::spawn(async move {
            Self::read_task(read, pending_requests, status, event_sender_clone).await;
        });

        log::info!("[OpenClawGateway] Connected successfully");
        Ok((client, event_receiver))
    }

    /// Send a message to an OpenClaw session
    ///
    /// This is the main method for sending messages, matching AutoClaw's `sendAgentMessage`.
    ///
    /// # Arguments
    /// * `session_key` - Session key (e.g., "agent:main:main")
    /// * `message` - Message content
    /// * `thinking_level` - Optional thinking level (off, minimal, low, medium, high, xhigh)
    ///
    /// # Returns
    /// Response from the agent
    pub async fn send_message(
        &self,
        session_key: &str,
        message: &str,
        thinking_level: Option<&str>,
    ) -> Result<serde_json::Value, String> {
        let trace_id = Uuid::new_v4().to_string();

        // Build params (matching AutoClaw's structure)
        let mut params = serde_json::json!({
            "sessionKey": session_key,
            "message": message,
            "idempotencyKey": trace_id,
        });

        if let Some(thinking) = thinking_level {
            params["thinking"] = thinking.into();
        }

        log::info!(
            "[OpenClawGateway] Sending message to session: {} (trace: {})",
            session_key,
            trace_id
        );

        // Call chat.send RPC
        self.request("chat.send", params, Self::CHAT_SEND_TIMEOUT_MS)
            .await
    }

    /// Inject a system prompt into the session
    ///
    /// # Arguments
    /// * `session_key` - Session key
    /// * `content` - System prompt content
    pub async fn inject_system_prompt(
        &self,
        session_key: &str,
        content: &str,
    ) -> Result<(), String> {
        let params = serde_json::json!({
            "sessionKey": session_key,
            "role": "system",
            "content": content,
        });

        self.request("chat.inject", params, 15_000).await?;
        Ok(())
    }

    /// List available sessions
    pub async fn list_sessions(&self) -> Result<serde_json::Value, String> {
        self.request("sessions.list", serde_json::json!({}), Self::DEFAULT_TIMEOUT_MS)
            .await
    }

    /// Get connection status
    pub fn status(&self) -> ConnectionStatus {
        self.status.read().clone()
    }

    /// Check if connected
    pub fn is_connected(&self) -> bool {
        matches!(*self.status.read(), ConnectionStatus::Connected)
    }

    /// Disconnect from gateway
    pub async fn disconnect(&self) {
        let _ = self.abort_tx.send(()).await;
        let _ = self.ws_sender.send(WsMessage::Close(None)).await;
        *self.status.write() = ConnectionStatus::Disconnected;
        log::info!("[OpenClawGateway] Disconnected");
    }

    // ========================================================================
    // Internal: Request/Response
    // ========================================================================

    /// Send a request to the gateway and wait for response
    ///
    /// This matches AutoClaw's `request` method exactly.
    async fn request(
        &self,
        method: &str,
        params: serde_json::Value,
        timeout_ms: u64,
    ) -> Result<serde_json::Value, String> {
        if !self.is_connected() {
            return Err("Not connected to gateway".to_string());
        }

        let id = Uuid::new_v4().to_string();
        let (tx, rx) = oneshot::channel();

        // Register pending request
        self.pending_requests.insert(id.clone(), tx);

        // Build request frame
        let req = GatewayRequest {
            msg_type: "req".to_string(),
            id: id.clone(),
            method: method.to_string(),
            params,
        };

        let req_json = serde_json::to_string(&req)
            .map_err(|e| format!("Failed to serialize request: {}", e))?;

        // Send request
        self.ws_sender
            .send(WsMessage::Text(req_json.into()))
            .await
            .map_err(|e| format!("Failed to send request: {}", e))?;

        // Wait for response with timeout
        let result = tokio::time::timeout(Duration::from_millis(timeout_ms), rx)
            .await
            .map_err(|_| {
                self.pending_requests.remove(&id);
                format!("Request timeout: {}", method)
            })?
            .map_err(|_| "Response cancelled".to_string())?;

        result
    }

    // ========================================================================
    // Background Tasks
    // ========================================================================

    /// Write task: send messages to WebSocket
    async fn write_task(
        mut receiver: mpsc::Receiver<WsMessage>,
        mut write: futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<
                tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
            >,
            WsMessage,
        >,
    ) {
        while let Some(msg) = receiver.recv().await {
            if let Err(e) = write.send(msg).await {
                log::error!("[OpenClawGateway] Write error: {}", e);
                break;
            }
        }
    }

    /// Read task: receive messages from WebSocket
    async fn read_task(
        mut read: futures_util::stream::SplitStream<
            tokio_tungstenite::WebSocketStream<
                tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
            >,
        >,
        pending_requests: Arc<DashMap<String, oneshot::Sender<Result<serde_json::Value, String>>>>,
        status: Arc<RwLock<ConnectionStatus>>,
        event_sender: mpsc::Sender<AgentStreamEvent>,
    ) {
        while let Some(msg) = read.next().await {
            match msg {
                Ok(WsMessage::Text(text)) => {
                    // Convert Utf8Bytes to &str for parsing
                    let text_str = text.as_str();
                    // Try to parse as response
                    if let Ok(response) = serde_json::from_str::<GatewayResponse>(text_str) {
                        if response.msg_type == "res" {
                            // Handle response
                            if let Some((_, tx)) = pending_requests.remove(&response.id) {
                                let result = if response.ok {
                                    Ok(response.result.unwrap_or(serde_json::Value::Null))
                                } else {
                                    Err(response
                                        .error
                                        .map(|e| e.message)
                                        .unwrap_or_else(|| "Unknown error".to_string()))
                                };
                                let _ = tx.send(result);
                            }
                        }
                    } else if let Ok(event) = serde_json::from_str::<GatewayEvent>(text_str) {
                        // Handle event
                        if event.msg_type == "event" {
                            // Parse agent.stream events
                            if event.event == "agent.stream" {
                                if let Some(data) = event.data.as_object() {
                                    let stream_event = AgentStreamEvent {
                                        session_key: data
                                            .get("sessionKey")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("")
                                            .to_string(),
                                        run_id: data
                                            .get("runId")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("")
                                            .to_string(),
                                        event_type: data
                                            .get("event")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("")
                                            .to_string(),
                                        content: data
                                            .get("content")
                                            .and_then(|v| v.as_str())
                                            .map(|s| s.to_string()),
                                        is_complete: data
                                            .get("event")
                                            .and_then(|v| v.as_str())
                                            .map(|s| s == "done")
                                            .unwrap_or(false),
                                    };
                                    let _ = event_sender.send(stream_event).await;
                                }
                            }
                        }
                    }
                }
                Ok(WsMessage::Close(_)) => {
                    log::info!("[OpenClawGateway] Connection closed by server");
                    *status.write() = ConnectionStatus::Disconnected;
                    break;
                }
                Ok(WsMessage::Ping(data)) => {
                    // Pong is handled automatically by tungstenite
                    log::debug!("[OpenClawGateway] Received ping");
                    let _ = data;
                }
                Err(e) => {
                    log::error!("[OpenClawGateway] Read error: {}", e);
                    *status.write() = ConnectionStatus::Error(e.to_string());
                    break;
                }
                _ => {}
            }
        }
    }
}

impl Drop for OpenClawGatewayClient {
    fn drop(&mut self) {
        *self.status.write() = ConnectionStatus::Disconnected;
    }
}