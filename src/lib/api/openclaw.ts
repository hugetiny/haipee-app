import { invoke } from "@tauri-apps/api/core";
import type {
  OpenClawDefaultModel,
  OpenClawModelCatalogEntry,
  OpenClawAgentsDefaults,
  OpenClawEnvConfig,
  OpenClawToolsConfig,
  OpenClawHealthWarning,
  OpenClawWriteOutcome,
  OpenClawInstance,
} from "@/types";

/**
 * OpenClaw configuration API
 */
export const openclawApi = {
  // Helper to handle remote vs local
  async request<T>(
    instance: OpenClawInstance | undefined,
    command: string,
    args?: any,
    remotePath?: string,
  ): Promise<T> {
    if (instance?.type === "remote" && instance.baseUrl) {
      if (!remotePath)
        throw new Error(`Remote API not implemented for ${command}`);
      const response = await fetch(`${instance.baseUrl}${remotePath}`, {
        headers: {
          "Content-Type": "application/json",
          ...(instance.apiKey
            ? { Authorization: `Bearer ${instance.apiKey}` }
            : {}),
        },
        method: args ? "POST" : "GET",
        body: args ? JSON.stringify(args) : undefined,
      });
      if (!response.ok)
        throw new Error(`Remote API error: ${response.statusText}`);
      return await response.json();
    }
    return await invoke(command, args);
  },

  // ============================================================
  // Agents Configuration
  // ============================================================

  /**
   * Get default model configuration (agents.defaults.model)
   */
  async getDefaultModel(
    instance?: OpenClawInstance,
  ): Promise<OpenClawDefaultModel | null> {
    return await this.request(
      instance,
      "get_openclaw_default_model",
      undefined,
      "/api/v1/config/agents/model",
    );
  },

  /**
   * Set default model configuration (agents.defaults.model)
   */
  async setDefaultModel(
    model: OpenClawDefaultModel,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_default_model",
      { model },
      "/api/v1/config/agents/model",
    );
  },

  /**
   * Get model catalog/allowlist (agents.defaults.models)
   */
  async getModelCatalog(
    instance?: OpenClawInstance,
  ): Promise<Record<string, OpenClawModelCatalogEntry> | null> {
    return await this.request(
      instance,
      "get_openclaw_model_catalog",
      undefined,
      "/api/v1/config/agents/models",
    );
  },

  /**
   * Set model catalog/allowlist (agents.defaults.models)
   */
  async setModelCatalog(
    catalog: Record<string, OpenClawModelCatalogEntry>,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_model_catalog",
      { catalog },
      "/api/v1/config/agents/models",
    );
  },

  /**
   * Get full agents.defaults config (all fields)
   */
  async getAgentsDefaults(
    instance?: OpenClawInstance,
  ): Promise<OpenClawAgentsDefaults | null> {
    return await this.request(
      instance,
      "get_openclaw_agents_defaults",
      undefined,
      "/api/v1/config/agents/defaults",
    );
  },

  /**
   * Set full agents.defaults config (all fields)
   */
  async setAgentsDefaults(
    defaults: OpenClawAgentsDefaults,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_agents_defaults",
      { defaults },
      "/api/v1/config/agents/defaults",
    );
  },

  // ============================================================
  // Env Configuration
  // ============================================================

  /**
   * Get env config (env section of openclaw.json)
   */
  async getEnv(instance?: OpenClawInstance): Promise<OpenClawEnvConfig> {
    return await this.request(
      instance,
      "get_openclaw_env",
      undefined,
      "/api/v1/config/env",
    );
  },

  /**
   * Set env config (env section of openclaw.json)
   */
  async setEnv(
    env: OpenClawEnvConfig,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_env",
      { env },
      "/api/v1/config/env",
    );
  },

  // ============================================================
  // Tools Configuration
  // ============================================================

  /**
   * Get tools config (tools section of openclaw.json)
   */
  async getTools(instance?: OpenClawInstance): Promise<OpenClawToolsConfig> {
    return await this.request(
      instance,
      "get_openclaw_tools",
      undefined,
      "/api/v1/config/tools",
    );
  },

  /**
   * Set tools config (tools section of openclaw.json)
   */
  async setTools(
    tools: OpenClawToolsConfig,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_tools",
      { tools },
      "/api/v1/config/tools",
    );
  },

  async scanHealth(
    instance?: OpenClawInstance,
  ): Promise<OpenClawHealthWarning[]> {
    return await this.request(
      instance,
      "scan_openclaw_config_health",
      undefined,
      "/api/v1/health",
    );
  },

  async getLiveProvider(
    providerId: string,
    instance?: OpenClawInstance,
  ): Promise<Record<string, unknown> | null> {
    return await this.request(
      instance,
      "get_openclaw_live_provider",
      { providerId },
      `/api/v1/config/providers/${providerId}`,
    );
  },

  // ============================================================
  // Generic JSON Configuration
  // ============================================================

  async getJsonSection(
    section: string,
    instance?: OpenClawInstance,
  ): Promise<any> {
    return await this.request(
      instance,
      "get_openclaw_json_section",
      { section },
      `/api/v1/config/section/${section}`,
    );
  },

  async setJsonSection(
    section: string,
    value: any,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "set_openclaw_json_section",
      { section, value },
      `/api/v1/config/section/${section}`,
    );
  },

  // ============================================================
  // Raw Configuration
  // ============================================================

  async readJsonRaw(instance?: OpenClawInstance): Promise<string> {
    return await this.request(
      instance,
      "read_openclaw_json_raw",
      undefined,
      `/api/v1/config/raw`,
    );
  },

  async writeJsonRaw(
    content: string,
    instance?: OpenClawInstance,
  ): Promise<OpenClawWriteOutcome> {
    return await this.request(
      instance,
      "write_openclaw_json_raw",
      { content },
      `/api/v1/config/raw`,
    );
  },

  // ============================================================
  // Session Key Lookup
  // ============================================================

  /**
   * Find OpenClaw session key by session ID.
   * OpenClaw TUI requires session key (e.g., "agent:main:main") for --session parameter.
   */
  async findSessionKey(sessionId: string): Promise<string | null> {
    return await invoke("find_openclaw_session_key", { sessionId });
  },

  // ============================================================
  // Connection Testing
  // ============================================================

  /**
   * Ping an OpenClaw instance to check connectivity.
   * For remote instances, hits /api/v1/health.
   * For local instances, runs scan_openclaw_config_health.
   * Returns { ok, latencyMs }.
   */
  async ping(
    instance?: OpenClawInstance,
  ): Promise<{ ok: boolean; latencyMs: number }> {
    const start = performance.now();
    try {
      if (instance?.type === "remote" && instance.baseUrl) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);
        try {
          const response = await fetch(`${instance.baseUrl}/api/v1/health`, {
            signal: controller.signal,
            headers: {
              ...(instance.apiKey
                ? { Authorization: `Bearer ${instance.apiKey}` }
                : {}),
            },
          });
          clearTimeout(timeout);
          const latencyMs = Math.round(performance.now() - start);
          return { ok: response.ok, latencyMs };
        } catch {
          clearTimeout(timeout);
          return {
            ok: false,
            latencyMs: Math.round(performance.now() - start),
          };
        }
      }
      // Local instance: just run health scan
      await this.scanHealth(instance);
      return { ok: true, latencyMs: Math.round(performance.now() - start) };
    } catch {
      return { ok: false, latencyMs: Math.round(performance.now() - start) };
    }
  },

  // ============================================================
  // Skills & Providers
  // ============================================================

  /**
   * List all skills from ~/.openclaw-haipee/skills/
   */
  async listSkills(): Promise<
    Array<{
      name: string;
      path: string;
      isSymlink: boolean;
      isDirectory: boolean;
    }>
  > {
    return await invoke("list_openclaw_skills");
  },

  /**
   * List all providers from openclaw.json models.providers
   */
  async listProviders(): Promise<
    Array<{
      id: string;
      name: string;
      baseUrl: string | null;
      apiType: string | null;
      modelsCount: number;
    }>
  > {
    return await invoke("list_openclaw_providers");
  },

  /**
   * List all MCP servers from openclaw.json mcp.servers
   */
  async listMcpServers(): Promise<
    Array<{
      id: string;
      command: string | null;
      args: string[] | null;
      env: Record<string, string> | null;
      url: string | null;
    }>
  > {
    return await invoke("list_openclaw_mcp_servers");
  },

  /**
   * Check if MCP is enabled in OpenClaw config (commands.mcp: true)
   */
  async isMcpEnabled(): Promise<boolean> {
    return await invoke("is_openclaw_mcp_enabled");
  },

  // ============================================================
  // Gateway Connection
  // ============================================================

  /**
   * Connect to OpenClaw Gateway via WebSocket.
   * Initializes the profile if needed, then connects.
   */
  async connectGateway(): Promise<{ connected: boolean; status: string }> {
    return await invoke("connect_openclaw_gateway");
  },

  /**
   * Disconnect from OpenClaw Gateway.
   */
  async disconnectGateway(): Promise<void> {
    return await invoke("disconnect_openclaw_gateway");
  },

  /**
   * Get OpenClaw Gateway connection status.
   */
  async getGatewayStatus(): Promise<{
    connected: boolean;
    status: string;
    error?: string;
  }> {
    return await invoke("get_openclaw_gateway_status");
  },

  /**
   * Send a message to an OpenClaw session via WebSocket.
   * Uses the chat.send RPC method.
   */
  async sendMessage(
    sessionKey: string,
    message: string,
    thinkingLevel?: string,
  ): Promise<unknown> {
    return await invoke("send_openclaw_message", {
      sessionKey,
      message,
      thinkingLevel,
    });
  },

  /**
   * Inject a system prompt into an OpenClaw session.
   */
  async injectSystemPrompt(sessionKey: string, content: string): Promise<void> {
    return await invoke("inject_openclaw_system_prompt", {
      sessionKey,
      content,
    });
  },

  /**
   * List OpenClaw sessions for the Haipee profile.
   */
  async listSessions(): Promise<unknown> {
    return await invoke("list_openclaw_sessions");
  },

  /**
   * Start the OpenClaw Gateway for Haipee profile.
   */
  async startGateway(): Promise<void> {
    return await invoke("start_openclaw_gateway");
  },

  /**
   * Stop the OpenClaw Gateway for Haipee profile.
   */
  async stopGateway(): Promise<void> {
    return await invoke("stop_openclaw_gateway");
  },

  /**
   * Get OpenClaw Gateway service status.
   */
  async getGatewayServiceStatus(): Promise<unknown> {
    return await invoke("get_openclaw_gateway_service_status");
  },
};
