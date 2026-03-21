# Haipee OpenClaw Integration Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable Haipee to send messages to OpenClaw sessions via Gateway WebSocket API, 1:1 copying AutoClaw's implementation.

**Architecture:** Haipee connects to OpenClaw Gateway via WebSocket, uses `chat.send` RPC method to send messages, following AutoClaw's exact pattern.

**Tech Stack:** Rust (Tauri commands + WebSocket client), TypeScript (frontend API)

---

## Background: AutoClaw's Actual Implementation

### What AutoClaw Does NOT Use

❌ **CLI subprocess** - AutoClaw does NOT spawn `openclaw agent --session-id ...` process

❌ **Channel plugin** - The `channels.feishu` + `plugins.entries.openclaw-lark` config is for **receiving** messages from Feishu users, NOT for sending

### What AutoClaw Actually Uses

✅ **WebSocket connection** to OpenClaw Gateway

✅ **`chat.send` RPC method** to send messages

### AutoClaw's Source Code (extracted from app.asar)

```javascript
// /tmp/autoclaw-extract/out/main/index.js (line 1300-1365)

class GatewayClient {
  // WebSocket request method
  async request(method, params = {}, timeoutMs = 30000) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("Not connected to gateway");
    }
    const id = uuid.v4();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Request timeout: ${method}`));
      }, timeoutMs);
      this.pendingRequests.set(id, { resolve, reject, timer });
      this.sendFrame({
        type: "req",
        id,
        method,
        params
      });
    });
  }

  // Send agent message
  async sendAgentMessage(params) {
    const traceId = params.idempotencyKey || uuid.v4();
    const reqParams = {
      sessionKey: params.sessionKey,
      message: params.message,
      ...params.thinkingLevel ? { thinking: params.thinkingLevel } : {},
      idempotencyKey: traceId
    };
    // Optional: inject system prompt
    if (params.systemPrompt) {
      await this.request("chat.inject", {
        sessionKey: params.sessionKey,
        role: "system",
        content: params.systemPrompt
      }, 15000);
    }
    // Send the message via chat.send RPC
    const ack = await this.request("chat.send", reqParams, 120000);
    return ack;
  }
}
```

### WebSocket Frame Format

```typescript
// Request frame
{
  type: "req",
  id: string,        // UUID for request/response correlation
  method: string,    // "chat.send", "chat.inject", "sessions.list", etc.
  params: object     // Method-specific parameters
}

// Response frame
{
  type: "res",
  id: string,        // Matches request id
  ok: boolean,
  result?: object,   // On success
  error?: { message: string, type: string }  // On failure
}

// Event frame (streaming)
{
  type: "event",
  event: string,     // "agent.stream", "session.updated", etc.
  data: object
}
```

### Profile Setup (AutoClaw's approach)

AutoClaw uses `--profile autoclaw` flag:

```
~/.openclaw-autoclaw/
├── openclaw.json          # Config with providers, model settings
├── identity/
│   └── device.json        # Shared with main OpenClaw (same deviceId)
├── devices/
│   └── paired.json        # Paired operator devices
├── .gateway-token         # Gateway auth token
└── agents/main/sessions/  # Session files
```

## Haipee Implementation Design

### 1. WebSocket Client (Rust)

```rust
// src-tauri/src/services/openclaw_gateway.rs

use tokio_tungstenite::{connect_async, tungstenite::Message};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Serialize)]
struct GatewayRequest {
    #[serde(rename = "type")]
    msg_type: String,
    id: String,
    method: String,
    params: serde_json::Value,
}

#[derive(Deserialize)]
struct GatewayResponse {
    #[serde(rename = "type")]
    msg_type: String,
    id: String,
    ok: bool,
    result: Option<serde_json::Value>,
    error: Option<GatewayError>,
}

pub struct OpenClawGatewayClient {
    ws_sender: mpsc::Sender<Message>,
    pending_requests: Arc<DashMap<String, oneshot::Sender<Result<serde_json::Value, String>>>>,
}

impl OpenClawGatewayClient {
    pub async fn connect(gateway_url: &str, token: &str) -> Result<Self, String> {
        let url = format!("{}?token={}", gateway_url, token);
        let (ws_stream, _) = connect_async(&url)
            .await
            .map_err(|e| format!("WebSocket connect failed: {}", e))?;

        let (write, read) = ws_stream.split();
        // ... implement message routing
    }

    pub async fn send_message(
        &self,
        session_key: &str,
        message: &str,
        thinking_level: Option<&str>,
    ) -> Result<serde_json::Value, String> {
        let id = Uuid::new_v4().to_string();
        let params = serde_json::json!({
            "sessionKey": session_key,
            "message": message,
            "idempotencyKey": id.clone(),
            ...(thinking_level.map(|t| ("thinking", t)))
        });

        self.request("chat.send", params).await
    }

    async fn request(&self, method: &str, params: serde_json::Value) -> Result<serde_json::Value, String> {
        let id = Uuid::new_v4().to_string();
        let (tx, rx) = oneshot::channel();

        self.pending_requests.insert(id.clone(), tx);

        let req = GatewayRequest {
            msg_type: "req".to_string(),
            id: id.clone(),
            method: method.to_string(),
            params,
        };

        self.ws_sender.send(Message::Text(serde_json::to_string(&req).unwrap())).await
            .map_err(|e| format!("Send failed: {}", e))?;

        rx.await.map_err(|e| format!("Response cancelled: {}", e))?
    }
}
```

### 2. Tauri Commands

```rust
// src-tauri/src/commands/openclaw.rs

#[tauri::command]
pub async fn send_openclaw_message(
    state: State<'_, AppState>,
    session_key: String,
    message: String,
    thinking_level: Option<String>,
) -> Result<serde_json::Value, String> {
    let client = state.openclaw_gateway.lock().await;

    if let Some(client) = client.as_ref() {
        client.send_message(&session_key, &message, thinking_level.as_deref()).await
    } else {
        Err("Not connected to OpenClaw Gateway".to_string())
    }
}

#[tauri::command]
pub async fn connect_openclaw_gateway(
    state: State<'_, AppState>,
) -> Result<(), String> {
    // 1. Get gateway URL and token from profile
    // 2. Connect WebSocket
    // 3. Store client in state
}
```

### 3. Profile Initialization

```rust
// src-tauri/src/services/openclaw_profile.rs

use std::fs;
use std::path::PathBuf;

pub fn init_haipee_profile() -> Result<PathBuf, String> {
    let home = dirs::home_dir().ok_or("Cannot find home directory")?;
    let profile_dir = home.join(".openclaw-haipee");

    // Create directory structure
    fs::create_dir_all(profile_dir.join("identity"))?;
    fs::create_dir_all(profile_dir.join("agents/main/sessions"))?;

    // Copy device.json from main OpenClaw (shared identity)
    let main_device = home.join(".openclaw/identity/device.json");
    let haipee_device = profile_dir.join("identity/device.json");

    if main_device.exists() && !haipee_device.exists() {
        fs::copy(&main_device, &haipee_device)
            .map_err(|e| format!("Failed to copy device.json: {}", e))?;
    }

    // Create minimal openclaw.json
    let config = serde_json::json!({
        "agents": {
            "defaults": {
                "model": { "primary": "claude-sonnet-4-6" }
            }
        },
        "gateway": {
            "mode": "local",
            "port": 18770  // Different port from main OpenClaw
        }
    });

    fs::write(
        profile_dir.join("openclaw.json"),
        serde_json::to_string_pretty(&config).unwrap()
    )?;

    Ok(profile_dir)
}
```

---

## Implementation Tasks

### Task 1: Add WebSocket Dependencies

**Files:**
- Modify: `src-tauri/Cargo.toml`

**Dependencies to add:**
```toml
tokio-tungstenite = { version = "0.21", features = ["native-tls"] }
uuid = { version = "1.0", features = ["v4", "serde"] }
dashmap = "5.5"
```

### Task 2: Create Gateway Client Service

**Files:**
- Create: `src-tauri/src/services/openclaw_gateway.rs`
- Modify: `src-tauri/src/services/mod.rs`

**Implementation:**
1. WebSocket connection with token auth
2. Request/response correlation with UUID
3. `chat.send` RPC method
4. Event streaming for agent responses

### Task 3: Create Profile Service

**Files:**
- Create: `src-tauri/src/services/openclaw_profile.rs`
- Modify: `src-tauri/src/services/mod.rs`

**Implementation:**
1. `init_haipee_profile()` - Create profile directory
2. `copy_device_identity()` - Share device with main OpenClaw
3. `get_gateway_config()` - Read gateway URL and token

### Task 4: Update Tauri Commands

**Files:**
- Modify: `src-tauri/src/commands/openclaw.rs`
- Modify: `src-tauri/src/lib.rs`

**Changes:**
1. Replace CLI subprocess with WebSocket client
2. Add `connect_openclaw_gateway` command
3. Add `disconnect_openclaw_gateway` command
4. Update `send_openclaw_message` to use WebSocket

### Task 5: Frontend API Updates

**Files:**
- Modify: `src/lib/api/openclawChannel.ts`

**Changes:**
1. Add connection state management
2. Update types for streaming responses
3. Add event listeners for agent stream

### Task 6: UI Integration

**Files:**
- Modify: `src/components/sessions/OpenClawChannel.tsx`

**Changes:**
1. Connection status indicator
2. Auto-connect on component mount
3. Display streaming responses

---

## Session Management Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         Haipee App                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐     ┌──────────────────────────────────┐  │
│  │  Sessions   │────▶│  OpenClaw Channel Tab            │  │
│  │  Sidebar    │     │  ┌────────────────────────────┐  │  │
│  └─────────────┘     │  │ Session: agent:main:main   │  │  │
│                      │  │ Messages: [...]            │  │  │
│                      │  │ ┌────────────────────────┐ │  │  │
│                      │  │ │ Input: [           ]   │ │  │  │
│                      │  │ │        [Send]         │ │  │  │
│                      │  │ └────────────────────────┘ │  │  │
│                      │  └────────────────────────────┘  │  │
│                      └──────────────────────────────────┘  │
│                                    │                        │
│                                    ▼                        │
│                      ┌──────────────────────────┐          │
│                      │  invoke('send_openclaw_  │          │
│                      │    message', {...})      │          │
│                      └──────────────────────────┘          │
│                                    │                        │
└────────────────────────────────────│────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │  Tauri Backend (Rust)          │
                    │  OpenClawGatewayClient         │
                    │  WebSocket: chat.send RPC      │
                    └────────────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │  OpenClaw Gateway (port 18770) │
                    │  Process via agent session     │
                    └────────────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │  WebSocket Event Stream        │
                    │  agent.stream events → UI      │
                    └────────────────────────────────┘
```

---

## Configuration

### Haipee's openclaw.json

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "claude-sonnet-4-6"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "port": 18770,
    "bind": "loopback"
  }
}
```

### Gateway URL Format

```
ws://127.0.0.1:18770/ws?token=<gateway-token>
```

The gateway token is stored in `~/.openclaw-haipee/.gateway-token`.

---

## Verification

1. **Profile Setup**:
   ```bash
   ls ~/.openclaw-haipee/
   # Should show: openclaw.json, identity/, agents/
   ```

2. **Gateway Connection**:
   ```bash
   # Start Haipee's Gateway
   openclaw --profile haipee gateway start

   # Check status
   openclaw --profile haipee gateway status
   ```

3. **WebSocket Test**:
   - Open Haipee app
   - Connect to Gateway
   - Send test message
   - Verify streaming response

4. **Frontend Test**:
   - Navigate to OpenClaw channel
   - Select session
   - Send message
   - Verify response appears in UI