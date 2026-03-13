use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ProxyError {
    #[error("服务器已在运行")]
    AlreadyRunning,

    #[error("服务器未运行")]
    NotRunning,

    #[error("地址绑定失败: {0}")]
    BindFailed(String),

    #[error("停止超时")]
    StopTimeout,

    #[error("停止失败: {0}")]
    StopFailed(String),

    #[error("请求转发失败: {0}")]
    ForwardFailed(String),

    #[error("无可用的Provider")]
    NoAvailableProvider,

    #[error("所有供应商已熔断，无可用渠道")]
    AllProvidersCircuitOpen,

    #[error("未配置供应商")]
    NoProvidersConfigured,

    #[allow(dead_code)]
    #[error("Provider不健康: {0}")]
    ProviderUnhealthy(String),

    #[error("上游错误 (状态码 {status}): {body:?}")]
    UpstreamError { status: u16, body: Option<String> },

    #[error("超过最大重试次数")]
    MaxRetriesExceeded,

    #[error("数据库错误: {0}")]
    DatabaseError(String),

    #[error("配置错误: {0}")]
    ConfigError(String),

    #[allow(dead_code)]
    #[error("格式转换错误: {0}")]
    TransformError(String),

    #[allow(dead_code)]
    #[error("无效的请求: {0}")]
    InvalidRequest(String),

    #[error("超时: {0}")]
    Timeout(String),

    /// 流式响应空闲超时
    #[allow(dead_code)]
    #[error("流式响应空闲超时: {0}秒无数据")]
    StreamIdleTimeout(u64),

    /// 认证错误
    #[allow(dead_code)]
    #[error("认证失败: {0}")]
    AuthError(String),

    #[allow(dead_code)]
    #[error("内部错误: {0}")]
    Internal(String),
}

impl IntoResponse for ProxyError {
    fn into_response(self) -> Response {
        let (status, body) = match &self {
            ProxyError::UpstreamError {
                status: upstream_status,
                body: upstream_body,
            } => {
                let http_status =
                    StatusCode::from_u16(*upstream_status).unwrap_or(StatusCode::BAD_GATEWAY);

                // 尝试解析上游响应体为 JSON，如果失败则包装为字符串
                let error_body = if let Some(body_str) = upstream_body {
                    if let Ok(json_body) = serde_json::from_str::<serde_json::Value>(body_str) {
                        // 上游返回的是 JSON，直接透传
                        json_body
                    } else {
                        // 上游返回的不是 JSON，包装为错误消息
                        json!({
                            "error": {
                                "message": body_str,
                                "type": "upstream_error",
                            }
                        })
                    }
                } else {
                    json!({
                        "error": {
                            "message": format!("Upstream error (status {})", upstream_status),
                            "type": "upstream_error",
                        }
                    })
                };

                (http_status, error_body)
            }
            _ => {
                let (http_status, message) = match &self {
                    ProxyError::AlreadyRunning => (StatusCode::CONFLICT, self.to_string()),
                    ProxyError::NotRunning => (StatusCode::SERVICE_UNAVAILABLE, self.to_string()),
                    ProxyError::BindFailed(_) => {
                        (StatusCode::INTERNAL_SERVER_ERROR, self.to_string())
                    }
                    ProxyError::StopTimeout => {
                        (StatusCode::INTERNAL_SERVER_ERROR, self.to_string())
                    }
                    ProxyError::StopFailed(_) => {
                        (StatusCode::INTERNAL_SERVER_ERROR, self.to_string())
                    }
                    ProxyError::ForwardFailed(_) => (StatusCode::BAD_GATEWAY, self.to_string()),
                    ProxyError::NoAvailableProvider => {
                        (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
                    }
                    ProxyError::AllProvidersCircuitOpen => {
                        (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
                    }
                    ProxyError::NoProvidersConfigured => {
                        (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
                    }
                    ProxyError::ProviderUnhealthy(_) => {
                        (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
                    }
                    ProxyError::MaxRetriesExceeded => {
                        (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
                    }
                    ProxyError::DatabaseError(_) => {
                        (StatusCode::INTERNAL_SERVER_ERROR, self.to_string())
                    }
                    ProxyError::ConfigError(_) => (StatusCode::BAD_REQUEST, self.to_string()),
                    ProxyError::TransformError(_) => {
                        (StatusCode::UNPROCESSABLE_ENTITY, self.to_string())
                    }
                    ProxyError::InvalidRequest(_) => (StatusCode::BAD_REQUEST, self.to_string()),
                    ProxyError::Timeout(_) => (StatusCode::GATEWAY_TIMEOUT, self.to_string()),
                    ProxyError::StreamIdleTimeout(_) => {
                        (StatusCode::GATEWAY_TIMEOUT, self.to_string())
                    }
                    ProxyError::AuthError(_) => (StatusCode::UNAUTHORIZED, self.to_string()),
                    ProxyError::Internal(_) => {
                        (StatusCode::INTERNAL_SERVER_ERROR, self.to_string())
                    }
                    ProxyError::UpstreamError { .. } => unreachable!(),
                };

                let error_body = json!({
                    "error": {
                        "message": message,
                        "type": "proxy_error",
                    }
                });

                (http_status, error_body)
            }
        };

        (status, Json(body)).into_response()
    }
}

/// 错误分类
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCategory {
    /// 可重试错误（网络问题、5xx）
    Retryable, // 网络超时、5xx 错误
    /// 不可重试错误（4xx、认证失败）
    NonRetryable, // 认证失败、参数错误、4xx 错误
    #[allow(dead_code)]
    ClientAbort, // 客户端主动中断
}

/// 判断错误是否可重试
#[allow(dead_code)]
pub fn categorize_error(error: &reqwest::Error) -> ErrorCategory {
    if error.is_timeout() || error.is_connect() {
        return ErrorCategory::Retryable;
    }

    if let Some(status) = error.status() {
        if status.is_server_error() {
            ErrorCategory::Retryable
        } else if status.is_client_error() {
            ErrorCategory::NonRetryable
        } else {
            ErrorCategory::Retryable
        }
    } else {
        ErrorCategory::Retryable
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::StatusCode;
    use axum::response::IntoResponse;

    #[test]
    fn test_proxy_error_display_messages() {
        assert_eq!(ProxyError::AlreadyRunning.to_string(), "服务器已在运行");
        assert_eq!(ProxyError::NotRunning.to_string(), "服务器未运行");
        assert_eq!(
            ProxyError::BindFailed("127.0.0.1:8080".to_string()).to_string(),
            "地址绑定失败: 127.0.0.1:8080"
        );
        assert_eq!(
            ProxyError::ForwardFailed("timeout".to_string()).to_string(),
            "请求转发失败: timeout"
        );
        assert_eq!(
            ProxyError::NoAvailableProvider.to_string(),
            "无可用的Provider"
        );
        assert_eq!(
            ProxyError::AllProvidersCircuitOpen.to_string(),
            "所有供应商已熔断，无可用渠道"
        );
        assert_eq!(
            ProxyError::NoProvidersConfigured.to_string(),
            "未配置供应商"
        );
    }

    #[test]
    fn test_proxy_error_into_response_already_running() {
        let error = ProxyError::AlreadyRunning;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::CONFLICT);
    }

    #[test]
    fn test_proxy_error_into_response_not_running() {
        let error = ProxyError::NotRunning;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_proxy_error_into_response_bind_failed() {
        let error = ProxyError::BindFailed("127.0.0.1:8080".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[test]
    fn test_proxy_error_into_response_forward_failed() {
        let error = ProxyError::ForwardFailed("timeout".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::BAD_GATEWAY);
    }

    #[test]
    fn test_proxy_error_into_response_no_available_provider() {
        let error = ProxyError::NoAvailableProvider;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_proxy_error_into_response_all_providers_circuit_open() {
        let error = ProxyError::AllProvidersCircuitOpen;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_proxy_error_into_response_no_providers_configured() {
        let error = ProxyError::NoProvidersConfigured;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_proxy_error_into_response_max_retries_exceeded() {
        let error = ProxyError::MaxRetriesExceeded;
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_proxy_error_into_response_database_error() {
        let error = ProxyError::DatabaseError("connection failed".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[test]
    fn test_proxy_error_into_response_config_error() {
        let error = ProxyError::ConfigError("invalid port".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[test]
    fn test_proxy_error_into_response_transform_error() {
        let error = ProxyError::TransformError("parse failed".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[test]
    fn test_proxy_error_into_response_invalid_request() {
        let error = ProxyError::InvalidRequest("missing field".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[test]
    fn test_proxy_error_into_response_timeout() {
        let error = ProxyError::Timeout("30s".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::GATEWAY_TIMEOUT);
    }

    #[test]
    fn test_proxy_error_into_response_stream_idle_timeout() {
        let error = ProxyError::StreamIdleTimeout(120);
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::GATEWAY_TIMEOUT);
    }

    #[test]
    fn test_proxy_error_into_response_auth_error() {
        let error = ProxyError::AuthError("invalid token".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[test]
    fn test_proxy_error_into_response_internal() {
        let error = ProxyError::Internal("unexpected".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[test]
    fn test_proxy_error_into_response_upstream_error_json() {
        // Test with JSON body
        let error = ProxyError::UpstreamError {
            status: 500,
            body: Some(r#"{"error": "internal server error"}"#.to_string()),
        };
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::from_u16(500).unwrap());
    }

    #[test]
    fn test_proxy_error_into_response_upstream_error_non_json() {
        // Test with non-JSON body
        let error = ProxyError::UpstreamError {
            status: 502,
            body: Some("Bad Gateway".to_string()),
        };
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::from_u16(502).unwrap());
    }

    #[test]
    fn test_proxy_error_into_response_upstream_error_no_body() {
        // Test with no body
        let error = ProxyError::UpstreamError {
            status: 503,
            body: None,
        };
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::from_u16(503).unwrap());
    }

    #[test]
    fn test_proxy_error_into_response_provider_unhealthy() {
        let error = ProxyError::ProviderUnhealthy("provider-a".to_string());
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    }

    #[test]
    fn test_error_category_debug() {
        assert_eq!(format!("{:?}", ErrorCategory::Retryable), "Retryable");
        assert_eq!(format!("{:?}", ErrorCategory::NonRetryable), "NonRetryable");
    }

    #[test]
    fn test_error_category_clone_and_eq() {
        let retryable1 = ErrorCategory::Retryable;
        let retryable2 = ErrorCategory::Retryable;
        let non_retryable = ErrorCategory::NonRetryable;

        assert_eq!(retryable1, retryable2);
        assert_ne!(retryable1, non_retryable);
        assert_eq!(retryable1.clone(), retryable2);
    }

    #[test]
    fn test_proxy_error_clone() {
        let error1 = ProxyError::AlreadyRunning;
        let error2 = error1.clone();
        assert_eq!(error1.to_string(), error2.to_string());

        let error3 = ProxyError::BindFailed("test".to_string());
        let error4 = error3.clone();
        assert_eq!(error3.to_string(), error4.to_string());
    }

    #[test]
    fn test_proxy_error_debug() {
        let error = ProxyError::AlreadyRunning;
        let debug_str = format!("{:?}", error);
        assert!(debug_str.contains("AlreadyRunning"));
    }

    #[test]
    fn test_proxy_error_partial_eq() {
        // Note: ProxyError doesn't derive PartialEq, but we can test via match
        let error1 = ProxyError::AlreadyRunning;
        let error2 = ProxyError::AlreadyRunning;

        match (&error1, &error2) {
            (ProxyError::AlreadyRunning, ProxyError::AlreadyRunning) => {}
            _ => panic!("Expected both to be AlreadyRunning"),
        }
    }
}
