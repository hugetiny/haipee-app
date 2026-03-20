//! 对话命令 - 通过活跃供应商进行流式对话

use futures::StreamExt;
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter, State};

use crate::app_config::AppType;
use crate::error::AppError;
use crate::proxy::providers::{get_adapter, AuthInfo, AuthStrategy};
use crate::store::AppState;

/// 单条聊天消息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatMessagePayload {
    pub role: String,
    pub content: String,
}

/// 流式chunk事件payload
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatChunkEvent {
    pub session_id: String,
    pub message_id: String,
    pub delta: String,
}

/// 流式完成事件payload
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatDoneEvent {
    pub session_id: String,
    pub message_id: String,
}

/// 流式错误事件payload
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatErrorEvent {
    pub session_id: String,
    pub message_id: String,
    pub error: String,
}

/// 供应商信息（用于前端展示）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatProviderInfo {
    pub provider_id: String,
    pub provider_name: String,
    pub base_url: String,
    pub default_model: String,
    pub app_type: String,
}

/// 向活跃供应商发送聊天消息并流式输出
///
/// 事件:
/// - `chat-chunk` : ChatChunkEvent - 每个文本片段
/// - `chat-done`  : ChatDoneEvent  - 流式结束
/// - `chat-error` : ChatErrorEvent - 错误
#[tauri::command]
pub async fn chat_with_provider(
    app: AppHandle,
    state: State<'_, AppState>,
    app_type: AppType,
    session_id: String,
    message_id: String,
    messages: Vec<ChatMessagePayload>,
    model: Option<String>,
) -> Result<(), AppError> {
    let sid = session_id.clone();
    let mid = message_id.clone();

    let result = do_chat(&app, &state, app_type, session_id, message_id, messages, model).await;

    if let Err(ref e) = result {
        let _ = app.emit(
            "chat-error",
            ChatErrorEvent {
                session_id: sid,
                message_id: mid,
                error: e.to_string(),
            },
        );
    }

    result
}

async fn do_chat(
    app: &AppHandle,
    state: &State<'_, AppState>,
    app_type: AppType,
    session_id: String,
    message_id: String,
    messages: Vec<ChatMessagePayload>,
    model: Option<String>,
) -> Result<(), AppError> {
    // 获取当前活跃供应商
    let current_provider_id = state
        .db
        .get_current_provider(app_type.as_str())?
        .ok_or_else(|| {
            AppError::Message(format!(
                "No active provider for {}. Please configure a provider first.",
                app_type.as_str()
            ))
        })?;

    let providers = state.db.get_all_providers(app_type.as_str())?;
    let provider = providers
        .get(&current_provider_id)
        .ok_or_else(|| AppError::Message(format!("Provider {current_provider_id} not found")))?
        .clone();

    let adapter = get_adapter(&app_type);

    let base_url = adapter
        .extract_base_url(&provider)
        .map_err(|e| AppError::Message(format!("Failed to extract base_url: {e}")))?;

    let auth: AuthInfo = adapter
        .extract_auth(&provider)
        .ok_or_else(|| AppError::Message("API key not configured for this provider".to_string()))?;

    let model_name = model.unwrap_or_else(|| resolve_default_model(&app_type));

    let proxy_config = provider.meta.as_ref().and_then(|m| m.proxy_config.as_ref());
    let client = crate::proxy::http_client::get_for_provider(proxy_config);

    let api_messages: Vec<serde_json::Value> = messages
        .iter()
        .map(|m| {
            serde_json::json!({
                "role": m.role,
                "content": m.content
            })
        })
        .collect();

    // Detect api_format from provider meta/settings
    let api_format = provider
        .meta
        .as_ref()
        .and_then(|m| m.api_format.as_deref())
        .or_else(|| {
            provider
                .settings_config
                .get("api_format")
                .and_then(|v| v.as_str())
        });

    let use_openai_format = match &app_type {
        AppType::Claude => {
            auth.strategy == AuthStrategy::GitHubCopilot || api_format == Some("openai_chat")
        }
        _ => true, // Codex, Gemini, OpenCode, OpenClaw all use OpenAI-compatible API
    };

    if use_openai_format {
        stream_openai_chat(
            app,
            &client,
            &base_url,
            &auth,
            &model_name,
            api_messages,
            session_id,
            message_id,
        )
        .await
    } else {
        stream_claude_chat(
            app,
            &client,
            &base_url,
            &auth,
            &model_name,
            api_messages,
            session_id,
            message_id,
        )
        .await
    }
}

fn resolve_default_model(app_type: &AppType) -> String {
    match app_type {
        AppType::Claude => "claude-opus-4-6".to_string(),
        AppType::Codex => "gpt-4.1".to_string(),
        AppType::Gemini => "gemini-2.5-pro-preview".to_string(),
        AppType::OpenCode => "anthropic/claude-opus-4-6".to_string(),
        AppType::OpenClaw => "claude-opus-4-6".to_string(),
    }
}

/// 获取当前供应商信息（用于前端展示模型、供应商名称等）
#[tauri::command]
pub fn get_chat_provider_info(
    state: State<'_, AppState>,
    app_type: AppType,
) -> Result<Option<ChatProviderInfo>, AppError> {
    let current_provider_id = match state.db.get_current_provider(app_type.as_str())? {
        Some(id) => id,
        None => return Ok(None),
    };

    let providers = state.db.get_all_providers(app_type.as_str())?;
    let provider = match providers.get(&current_provider_id) {
        Some(p) => p,
        None => return Ok(None),
    };

    let adapter = get_adapter(&app_type);
    let base_url = adapter.extract_base_url(provider).unwrap_or_default();

    Ok(Some(ChatProviderInfo {
        provider_id: current_provider_id,
        provider_name: provider.name.clone(),
        base_url,
        default_model: resolve_default_model(&app_type),
        app_type: app_type.as_str().to_string(),
    }))
}

/// 流式 Claude (Anthropic native) Messages API
async fn stream_claude_chat(
    app: &AppHandle,
    client: &reqwest::Client,
    base_url: &str,
    auth: &AuthInfo,
    model: &str,
    messages: Vec<serde_json::Value>,
    session_id: String,
    message_id: String,
) -> Result<(), AppError> {
    let base = base_url.trim_end_matches('/');
    let url = if base.ends_with("/v1") {
        format!("{base}/messages")
    } else {
        format!("{base}/v1/messages")
    };

    let body = serde_json::json!({
        "model": model,
        "max_tokens": 4096,
        "stream": true,
        "messages": messages
    });

    let mut req = client
        .post(&url)
        .header("authorization", format!("Bearer {}", auth.api_key))
        .header("anthropic-version", "2023-06-01")
        .header("content-type", "application/json")
        .header("accept", "text/event-stream");

    if auth.strategy == AuthStrategy::Anthropic {
        req = req.header("x-api-key", &auth.api_key);
    }

    let response = req
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::Message(format!("Request failed: {e}")))?;

    if !response.status().is_success() {
        let status = response.status().as_u16();
        let body = response.text().await.unwrap_or_default();
        return Err(AppError::Message(format!("API error {status}: {body}")));
    }

    let mut stream = response.bytes_stream();

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| AppError::Message(format!("Stream error: {e}")))?;
        let text = String::from_utf8_lossy(&chunk);

        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line == "data: [DONE]" {
                continue;
            }

            let data = match line.strip_prefix("data: ") {
                Some(d) => d,
                None => continue,
            };

            if let Ok(json) = serde_json::from_str::<serde_json::Value>(data) {
                let event_type = json.get("type").and_then(|t| t.as_str());

                if event_type == Some("content_block_delta") {
                    if let Some(delta_text) = json
                        .pointer("/delta/text")
                        .and_then(|t| t.as_str())
                    {
                        let _ = app.emit(
                            "chat-chunk",
                            ChatChunkEvent {
                                session_id: session_id.clone(),
                                message_id: message_id.clone(),
                                delta: delta_text.to_string(),
                            },
                        );
                    }
                }

                if event_type == Some("message_stop") {
                    break;
                }
            }
        }
    }

    let _ = app.emit(
        "chat-done",
        ChatDoneEvent {
            session_id,
            message_id,
        },
    );

    Ok(())
}

/// 流式 OpenAI-compatible Chat API (Codex, Gemini, OpenCode, OpenClaw, Copilot)
async fn stream_openai_chat(
    app: &AppHandle,
    client: &reqwest::Client,
    base_url: &str,
    auth: &AuthInfo,
    model: &str,
    messages: Vec<serde_json::Value>,
    session_id: String,
    message_id: String,
) -> Result<(), AppError> {
    let base = base_url.trim_end_matches('/');
    let url = if base.ends_with("/v1") {
        format!("{base}/chat/completions")
    } else {
        format!("{base}/v1/chat/completions")
    };

    let body = serde_json::json!({
        "model": model,
        "stream": true,
        "messages": messages
    });

    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", auth.api_key))
        .header("Content-Type", "application/json")
        .header("Accept", "text/event-stream")
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::Message(format!("Request failed: {e}")))?;

    if !response.status().is_success() {
        let status = response.status().as_u16();
        let body = response.text().await.unwrap_or_default();
        return Err(AppError::Message(format!("API error {status}: {body}")));
    }

    let mut stream = response.bytes_stream();

    'outer: while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| AppError::Message(format!("Stream error: {e}")))?;
        let text = String::from_utf8_lossy(&chunk);

        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            if line == "data: [DONE]" {
                break 'outer;
            }

            let data = match line.strip_prefix("data: ") {
                Some(d) => d,
                None => continue,
            };

            if let Ok(json) = serde_json::from_str::<serde_json::Value>(data) {
                if let Some(delta_content) = json
                    .pointer("/choices/0/delta/content")
                    .and_then(|c| c.as_str())
                {
                    if !delta_content.is_empty() {
                        let _ = app.emit(
                            "chat-chunk",
                            ChatChunkEvent {
                                session_id: session_id.clone(),
                                message_id: message_id.clone(),
                                delta: delta_content.to_string(),
                            },
                        );
                    }
                }

                let finish_reason = json
                    .pointer("/choices/0/finish_reason")
                    .and_then(|r| r.as_str());
                if matches!(finish_reason, Some("stop") | Some("length") | Some("content_filter")) {
                    break 'outer;
                }
            }
        }
    }

    let _ = app.emit(
        "chat-done",
        ChatDoneEvent {
            session_id,
            message_id,
        },
    );

    Ok(())
}
