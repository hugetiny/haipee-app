//! IPC Tracer for E2E Testing
//!
//! Records Tauri IPC command calls during E2E tests for debugging purposes.
//! Only active when HAIPEE_E2E_MODE=1 is set.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::sync::{LazyLock, Mutex};

/// Maximum number of IPC calls to keep in memory
#[allow(dead_code)]
const MAX_TRACE_SIZE: usize = 1000;

/// Represents a single IPC command call
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpcCall {
    pub command: String,
    pub args: Option<serde_json::Value>,
    pub result: Option<serde_json::Value>,
    pub error: Option<String>,
    pub duration_ms: u64,
    pub timestamp: DateTime<Utc>,
    pub success: bool,
}

/// Thread-safe IPC trace storage
static IPC_TRACE: LazyLock<Mutex<VecDeque<IpcCall>>> = LazyLock::new(|| Mutex::new(VecDeque::new()));

/// Record an IPC command call
#[allow(dead_code)]
pub fn record_ipc_call(
    command: &str,
    args: Option<serde_json::Value>,
    result: Option<serde_json::Value>,
    error: Option<String>,
    duration_ms: u64,
    success: bool,
) {
    // Only record if E2E mode is enabled
    if !crate::e2e_mode::is_enabled() {
        return;
    }

    let call = IpcCall {
        command: command.to_string(),
        args: redact_sensitive_args(args),
        result: redact_sensitive_result(result),
        error,
        duration_ms,
        timestamp: Utc::now(),
        success,
    };

    if let Ok(mut trace) = IPC_TRACE.lock() {
        trace.push_back(call);

        // Keep only the last MAX_TRACE_SIZE entries
        while trace.len() > MAX_TRACE_SIZE {
            trace.pop_front();
        }
    }
}

/// Get all recorded IPC calls
pub fn get_ipc_trace() -> Vec<IpcCall> {
    match IPC_TRACE.lock() {
        Ok(trace) => trace.iter().cloned().collect(),
        Err(_) => Vec::new(),
    }
}

/// Clear the IPC trace
pub fn clear_ipc_trace() {
    if let Ok(mut trace) = IPC_TRACE.lock() {
        trace.clear();
    }
}

/// Get the number of recorded IPC calls
pub fn get_trace_count() -> usize {
    match IPC_TRACE.lock() {
        Ok(trace) => trace.len(),
        Err(_) => 0,
    }
}

/// Redact sensitive information from IPC arguments
#[allow(dead_code)]
fn redact_sensitive_args(args: Option<serde_json::Value>) -> Option<serde_json::Value> {
    args.map(|v| {
        match v {
            serde_json::Value::Object(mut map) => {
                // Redact common sensitive fields
                for key in &["password", "token", "secret", "api_key", "apiKey", "auth"] {
                    if map.contains_key(*key) {
                        map.insert(key.to_string(), serde_json::Value::String("[REDACTED]".to_string()));
                    }
                }
                serde_json::Value::Object(map)
            }
            other => other,
        }
    })
}

/// Redact sensitive information from IPC results
#[allow(dead_code)]
fn redact_sensitive_result(result: Option<serde_json::Value>) -> Option<serde_json::Value> {
    result.map(|v| {
        match v {
            serde_json::Value::Object(mut map) => {
                // Redact common sensitive fields in results
                for key in &["password", "token", "secret", "api_key", "apiKey", "auth", "credentials"] {
                    if map.contains_key(*key) {
                        map.insert(key.to_string(), serde_json::Value::String("[REDACTED]".to_string()));
                    }
                }
                serde_json::Value::Object(map)
            }
            other => other,
        }
    })
}

/// Tauri command: Get IPC trace
#[tauri::command]
pub fn e2e_get_ipc_trace() -> Vec<IpcCall> {
    get_ipc_trace()
}

/// Tauri command: Clear IPC trace
#[tauri::command]
pub fn e2e_clear_ipc_trace() {
    clear_ipc_trace();
}

/// Tauri command: Get IPC trace count
#[tauri::command]
pub fn e2e_get_ipc_trace_count() -> usize {
    get_trace_count()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_record_and_get_trace() {
        // Enable E2E mode for testing
        std::env::set_var("HAIPEE_E2E_MODE", "1");

        clear_ipc_trace();

        record_ipc_call(
            "test_command",
            Some(serde_json::json!({"key": "value"})),
            Some(serde_json::json!({"result": "ok"})),
            None,
            100,
            true,
        );

        let trace = get_ipc_trace();
        assert_eq!(trace.len(), 1);
        assert_eq!(trace[0].command, "test_command");
        assert!(trace[0].success);

        // Clean up
        std::env::remove_var("HAIPEE_E2E_MODE");
        clear_ipc_trace();
    }

    #[test]
    fn test_redact_sensitive_args() {
        let args = serde_json::json!({
            "username": "test",
            "password": "secret123",
            "api_key": "key123"
        });

        let redacted = redact_sensitive_args(Some(args)).unwrap();

        assert_eq!(redacted["username"], "test");
        assert_eq!(redacted["password"], "[REDACTED]");
        assert_eq!(redacted["api_key"], "[REDACTED]");
    }

    #[test]
    fn test_trace_size_limit() {
        std::env::set_var("HAIPEE_E2E_MODE", "1");
        clear_ipc_trace();

        // Record more than MAX_TRACE_SIZE entries
        for i in 0..(MAX_TRACE_SIZE + 100) {
            record_ipc_call(
                &format!("command_{}", i),
                None,
                None,
                None,
                10,
                true,
            );
        }

        let trace = get_ipc_trace();
        assert_eq!(trace.len(), MAX_TRACE_SIZE);

        std::env::remove_var("HAIPEE_E2E_MODE");
        clear_ipc_trace();
    }
}
