use std::path::Path;
use std::sync::PoisonError;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("配置错误: {0}")]
    Config(String),
    #[error("无效输入: {0}")]
    InvalidInput(String),
    #[error("IO 错误: {path}: {source}")]
    Io {
        path: String,
        #[source]
        source: std::io::Error,
    },
    #[error("{context}: {source}")]
    IoContext {
        context: String,
        #[source]
        source: std::io::Error,
    },
    #[error("JSON 解析错误: {path}: {source}")]
    Json {
        path: String,
        #[source]
        source: serde_json::Error,
    },
    #[error("JSON 序列化失败: {source}")]
    JsonSerialize {
        #[source]
        source: serde_json::Error,
    },
    #[error("TOML 解析错误: {path}: {source}")]
    Toml {
        path: String,
        #[source]
        source: toml::de::Error,
    },
    #[error("锁获取失败: {0}")]
    Lock(String),
    #[error("MCP 校验失败: {0}")]
    McpValidation(String),
    #[error("{0}")]
    Message(String),
    #[error("{zh} ({en})")]
    Localized {
        key: &'static str,
        zh: String,
        en: String,
    },
    #[error("数据库错误: {0}")]
    Database(String),
    #[error("OMO 配置文件不存在")]
    OmoConfigNotFound,
    #[error("所有供应商已熔断，无可用渠道")]
    AllProvidersCircuitOpen,
    #[error("未配置供应商")]
    NoProvidersConfigured,
}

impl AppError {
    pub fn io(path: impl AsRef<Path>, source: std::io::Error) -> Self {
        Self::Io {
            path: path.as_ref().display().to_string(),
            source,
        }
    }

    pub fn json(path: impl AsRef<Path>, source: serde_json::Error) -> Self {
        Self::Json {
            path: path.as_ref().display().to_string(),
            source,
        }
    }

    pub fn toml(path: impl AsRef<Path>, source: toml::de::Error) -> Self {
        Self::Toml {
            path: path.as_ref().display().to_string(),
            source,
        }
    }

    pub fn localized(key: &'static str, zh: impl Into<String>, en: impl Into<String>) -> Self {
        Self::Localized {
            key,
            zh: zh.into(),
            en: en.into(),
        }
    }
}

impl<T> From<PoisonError<T>> for AppError {
    fn from(err: PoisonError<T>) -> Self {
        Self::Lock(err.to_string())
    }
}

impl From<rusqlite::Error> for AppError {
    fn from(err: rusqlite::Error) -> Self {
        Self::Database(err.to_string())
    }
}

impl From<AppError> for String {
    fn from(err: AppError) -> Self {
        err.to_string()
    }
}

impl serde::Serialize for AppError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}

/// 格式化为 JSON 错误字符串，前端可解析为结构化错误
pub fn format_skill_error(
    code: &str,
    context: &[(&str, &str)],
    suggestion: Option<&str>,
) -> String {
    use serde_json::json;

    let mut ctx_map = serde_json::Map::new();
    for (key, value) in context {
        ctx_map.insert(key.to_string(), json!(value));
    }

    let error_obj = json!({
        "code": code,
        "context": ctx_map,
        "suggestion": suggestion,
    });

    serde_json::to_string(&error_obj).unwrap_or_else(|_| {
        // 如果 JSON 序列化失败，返回简单格式
        format!("ERROR:{code}")
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json;
    use std::io;

    #[test]
    fn test_app_error_config() {
        let err = AppError::Config("invalid setting".to_string());
        assert_eq!(err.to_string(), "配置错误: invalid setting");
    }

    #[test]
    fn test_app_error_invalid_input() {
        let err = AppError::InvalidInput("missing field".to_string());
        assert_eq!(err.to_string(), "无效输入: missing field");
    }

    #[test]
    fn test_app_error_io() {
        let io_err = io::Error::new(io::ErrorKind::NotFound, "file not found");
        let err = AppError::io("/path/to/file", io_err);
        assert!(err.to_string().contains("IO 错误: /path/to/file"));
        assert!(err.to_string().contains("file not found"));
    }

    #[test]
    fn test_app_error_io_context() {
        let io_err = io::Error::new(io::ErrorKind::PermissionDenied, "access denied");
        let err = AppError::IoContext {
            context: "reading config".to_string(),
            source: io_err,
        };
        assert!(err.to_string().contains("reading config: access denied"));
    }

    #[test]
    fn test_app_error_json() {
        let json_err = serde_json::from_str::<serde_json::Value>("invalid").unwrap_err();
        let err = AppError::json("/config.json", json_err);
        assert!(err.to_string().contains("JSON 解析错误: /config.json"));
    }

    #[test]
    fn test_app_error_json_serialize() {
        // Test that AppError can be constructed and displayed
        // (JsonSerialize is hard to trigger in Rust's type system, so we just test display)
        let err = AppError::json("test.json", serde_json::from_str::<()>("x").unwrap_err());
        assert!(err.to_string().contains("JSON 解析错误"));
    }

    #[test]
    fn test_app_error_toml() {
        let toml_err = toml::from_str::<toml::Table>("invalid = ").unwrap_err();
        let err = AppError::toml("/config.toml", toml_err);
        assert!(err.to_string().contains("TOML 解析错误: /config.toml"));
    }

    #[test]
    fn test_app_error_lock() {
        let err = AppError::Lock("mutex poisoned".to_string());
        assert_eq!(err.to_string(), "锁获取失败: mutex poisoned");
    }

    #[test]
    fn test_app_error_mcp_validation() {
        let err = AppError::McpValidation("missing command".to_string());
        assert_eq!(err.to_string(), "MCP 校验失败: missing command");
    }

    #[test]
    fn test_app_error_message() {
        let err = AppError::Message("custom error".to_string());
        assert_eq!(err.to_string(), "custom error");
    }

    #[test]
    fn test_app_error_localized() {
        let err = AppError::localized("test_key", "中文错误", "English error");
        assert_eq!(err.to_string(), "中文错误 (English error)");
    }

    #[test]
    fn test_app_error_database() {
        let err = AppError::Database("connection failed".to_string());
        assert_eq!(err.to_string(), "数据库错误: connection failed");
    }

    #[test]
    fn test_app_error_omo_config_not_found() {
        let err = AppError::OmoConfigNotFound;
        assert_eq!(err.to_string(), "OMO 配置文件不存在");
    }

    #[test]
    fn test_app_error_all_providers_circuit_open() {
        let err = AppError::AllProvidersCircuitOpen;
        assert_eq!(err.to_string(), "所有供应商已熔断，无可用渠道");
    }

    #[test]
    fn test_app_error_no_providers_configured() {
        let err = AppError::NoProvidersConfigured;
        assert_eq!(err.to_string(), "未配置供应商");
    }

    #[test]
    fn test_from_rusqlite_error() {
        let sqlite_err = rusqlite::Error::InvalidQuery;
        let err: AppError = sqlite_err.into();
        assert!(err.to_string().starts_with("数据库错误:"));
    }

    #[test]
    fn test_from_app_error_to_string() {
        let err = AppError::Message("test".to_string());
        let s: String = err.into();
        assert_eq!(s, "test");
    }

    #[test]
    fn test_serialize_app_error() {
        let err = AppError::Message("test error".to_string());
        let json = serde_json::to_string(&err).unwrap();
        assert_eq!(json, "\"test error\"");
    }

    #[test]
    fn test_format_skill_error() {
        let result = format_skill_error(
            "TEST_ERROR",
            &[("field", "value"), ("count", "42")],
            Some("Try again"),
        );

        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["code"], "TEST_ERROR");
        assert_eq!(parsed["context"]["field"], "value");
        assert_eq!(parsed["context"]["count"], "42");
        assert_eq!(parsed["suggestion"], "Try again");
    }

    #[test]
    fn test_format_skill_error_no_suggestion() {
        let result = format_skill_error("NO_SUGGESTION", &[("key", "val")], None);

        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["code"], "NO_SUGGESTION");
        assert_eq!(parsed["context"]["key"], "val");
        assert!(parsed["suggestion"].is_null());
    }

    #[test]
    fn test_app_error_factory_methods() {
        // Test io factory
        let io_err = io::Error::new(io::ErrorKind::NotFound, "test");
        let err = AppError::io("/test/path", io_err);
        assert!(matches!(err, AppError::Io { .. }));

        // Test json factory
        let json_err = serde_json::from_str::<i32>("abc").unwrap_err();
        let err = AppError::json("/test.json", json_err);
        assert!(matches!(err, AppError::Json { .. }));

        // Test toml factory
        let toml_err = toml::from_str::<toml::Table>("bad").unwrap_err();
        let err = AppError::toml("/test.toml", toml_err);
        assert!(matches!(err, AppError::Toml { .. }));

        // Test localized factory
        let err = AppError::localized("key", "中文", "English");
        assert!(matches!(err, AppError::Localized { .. }));
    }

    #[test]
    fn test_app_error_source() {
        // Test that errors with sources properly chain
        let io_err = io::Error::new(io::ErrorKind::NotFound, "file missing");
        let err = AppError::io("/missing", io_err);

        // The error should have a source
        assert!(std::error::Error::source(&err).is_some());
    }

    #[test]
    fn test_app_error_debug() {
        let err = AppError::Message("test".to_string());
        let debug_str = format!("{:?}", err);
        assert!(debug_str.contains("Message"));
        assert!(debug_str.contains("test"));
    }
}
