use crate::database::Database;
use crate::services::openclaw_gateway::OpenClawGatewayClient;
use crate::services::ProxyService;
use parking_lot::RwLock;
use std::sync::Arc;

/// 全局应用状态
pub struct AppState {
    pub db: Arc<Database>,
    pub proxy_service: ProxyService,
    /// OpenClaw Gateway HTTP 客户端
    pub openclaw_gateway: Arc<RwLock<Option<Arc<OpenClawGatewayClient>>>>,
}

impl AppState {
    /// 创建新的应用状态
    pub fn new(db: Arc<Database>) -> Self {
        let proxy_service = ProxyService::new(db.clone());

        Self {
            db,
            proxy_service,
            openclaw_gateway: Arc::new(RwLock::new(None)),
        }
    }
}
