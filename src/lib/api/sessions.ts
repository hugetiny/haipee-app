import { invoke } from "@tauri-apps/api/core";
import type { SessionMessage, SessionMeta, OpenClawInstance } from "@/types";

export interface DeleteSessionOptions {
  providerId: string;
  sessionId: string;
  sourcePath: string;
}

export const sessionsApi = {
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

  async list(instance?: OpenClawInstance): Promise<SessionMeta[]> {
    return await this.request(
      instance,
      "list_sessions",
      undefined,
      "/api/v1/sessions",
    );
  },

  async getMessages(
    providerId: string,
    sourcePath: string,
    instance?: OpenClawInstance,
  ): Promise<SessionMessage[]> {
    return await this.request(
      instance,
      "get_session_messages",
      { providerId, sourcePath },
      `/api/v1/sessions/${providerId}/${encodeURIComponent(sourcePath)}/messages`,
    );
  },

  async delete(
    options: DeleteSessionOptions,
    instance?: OpenClawInstance,
  ): Promise<boolean> {
    const { providerId, sessionId, sourcePath } = options;
    return await this.request(
      instance,
      "delete_session",
      { providerId, sessionId, sourcePath },
      `/api/v1/sessions/${providerId}/${encodeURIComponent(sourcePath)}`,
    );
  },

  async sendMessage(
    options: {
      providerId: string;
      sourcePath: string;
      message: string;
    },
    instance?: OpenClawInstance,
  ): Promise<void> {
    const { providerId, sourcePath, message } = options;
    return await this.request(
      instance,
      "send_session_message",
      { providerId, sourcePath, message },
      `/api/v1/sessions/${providerId}/${encodeURIComponent(sourcePath)}/chat`,
    );
  },

  async launchTerminal(options: {
    command: string;
    cwd?: string | null;
    customConfig?: string | null;
  }): Promise<boolean> {
    const { command, cwd, customConfig } = options;
    return await invoke("launch_session_terminal", {
      command,
      cwd,
      customConfig,
    });
  },
};
