/**
 * Browser Mock for Tauri APIs
 * This file allows the application to run in a standard browser environment (like Antigravity's browser subagent)
 * by providing safe no-op or mocked versions of native Tauri IPC calls.
 */

if (typeof window !== "undefined" && !(window as any).__TAURI_INTERNALS__) {
  console.warn(
    "[Browser Mock] Native Tauri environment not detected. Injecting API mocks...",
  );

  // Mock for __TAURI_INTERNALS__ if needed by the low-level API
  (window as any).__TAURI_INTERNALS__ = {
    invoke: async (cmd: string, args?: any) => {
      console.log(`[Tauri Mock] invoke("${cmd}")`, args);
      // Return sensible defaults for common commands
      if (cmd === "get_init_error") return null;
      if (cmd === "get_settings") return {};
      if (cmd === "get_providers")
        return { providers: {}, currentProviderId: "" };
      if (cmd === "get_openclaw_env") return {};
      if (cmd === "get_openclaw_tools") return {};
      if (cmd === "get_openclaw_agents_defaults")
        return { model: null, catalog: {} };
      if (cmd === "scan_openclaw_config_health") return [];
      if (cmd === "read_openclaw_json_raw")
        return '{\n  "agents": {},\n  "env": {},\n  "tools": {}\n}';

      // Proxy & Failover commands
      if (cmd === "get_proxy_status")
        return { running: false, port: 0, address: "127.0.0.1" };
      if (cmd === "get_proxy_takeover_status")
        return { claude: false, codex: false, gemini: false };
      if (cmd === "get_failover_queue") return [];
      if (cmd === "get_available_providers_for_failover") return [];
      if (cmd === "get_circuit_breaker_config")
        return {
          failureThreshold: 3,
          successThreshold: 2,
          timeoutSeconds: 60,
        };

      // Session commands
      if (cmd === "list_sessions") return [];
      if (cmd === "get_session_messages") return [];

      // Settings commands
      if (cmd === "get_app_config_dir_override") return null;
      if (cmd === "get_config_dir") return "/mock/config";
      if (cmd === "is_portable_mode") return false;

      // Config status commands
      if (cmd === "get_all_config_statuses")
        return {
          claude: { exists: true, path: "/mock/claude" },
          codex: { exists: true, path: "/mock/codex" },
          gemini: { exists: false, path: "未登录" },
          opencode: { exists: true, path: "/mock/opencode" },
          openclaw: { exists: false, path: "/mock/openclaw" },
        };

      // Migration commands
      if (cmd === "get_migration_result") return false;
      if (cmd === "get_skills_migration_result") return null;

      // MCP commands
      if (cmd === "get_mcp_config")
        return { configPath: "/mock/mcp.json", servers: {} };
      if (cmd === "import_mcp_from_claude") return 0;
      if (cmd === "import_mcp_from_codex") return 0;

      // External operations (safe no-ops)
      if (cmd === "open_external") return true;
      if (cmd === "update_tray_menu") return true;
      if (cmd === "restart_app") return true;

      // File operations (mock)
      if (cmd === "pick_directory") return "/mock/directory";
      if (cmd === "select_config_directory") return "/mock/config";
      if (cmd === "open_file_dialog") return "/mock/file.json";
      if (cmd === "save_file_dialog") return "/mock/output.json";

      // Chat commands
      if (cmd === "get_chat_provider_info") return {
        providerId: "mock-provider",
        providerName: "Mock Provider",
        baseUrl: "https://api.anthropic.com",
        defaultModel: "claude-opus-4-6",
        appType: args?.appType ?? "claude",
      };
      if (cmd === "chat_with_provider") return null;

      console.warn(`[Tauri Mock] Unhandled command: ${cmd}`);
      return {};
    },
    transformCallback: (callback: any) => callback,
    metadata: {
      version: "2.0.0-mock",
    },
  };

  // Mock for event listening
  (window as any).__TAURI_INTERNALS__.listen = async (
    event: string,
    _handler: any,
  ) => {
    console.log(`[Tauri Mock] listen("${event}")`);
    return () => console.log(`[Tauri Mock] unlisten("${event}")`);
  };

  // Polyfill common plugin behaviors if necessary
  // Note: Modern @tauri-apps/api/core uses window.__TAURI_INTERNALS__.invoke
}

export {};
