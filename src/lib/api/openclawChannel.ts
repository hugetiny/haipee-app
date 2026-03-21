/**
 * OpenClaw Gateway Channel API
 *
 * Provides HTTP-based communication with OpenClaw Gateway
 * for sending and receiving messages in sessions.
 */

import { openclawApi } from './openclaw';
import type { OpenClawInstance } from '@/types';

export interface OpenClawMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  sessionId: string;
}

export interface OpenClawGatewayConfig {
  url: string;
  authToken?: string;
}

// Cache for gateway config
let gatewayConfig: OpenClawGatewayConfig | null = null;

/**
 * Get Gateway config from OpenClaw config file
 * Uses existing openclawApi.getJsonSection("gateway")
 */
export async function getOpenClawGatewayConfig(): Promise<OpenClawGatewayConfig | null> {
  if (gatewayConfig) return gatewayConfig;

  try {
    const config = await openclawApi.getJsonSection('gateway');
    if (config?.url) {
      gatewayConfig = {
        url: config.url,
        authToken: config.auth?.token,
      };
    }
    return gatewayConfig;
  } catch {
    return null;
  }
}

/**
 * Clear the cached gateway config (useful when config changes)
 */
export function clearGatewayConfigCache(): void {
  gatewayConfig = null;
}

/**
 * Send message to OpenClaw Gateway HTTP API
 * Gateway endpoint: POST /api/v1/chat/{sessionId}/message
 */
export async function sendToOpenClaw(
  sessionId: string,
  content: string,
  _instance?: OpenClawInstance,
): Promise<string> {
  const config = await getOpenClawGatewayConfig();
  if (!config?.url) {
    throw new Error('OpenClaw Gateway not configured');
  }

  const messageId = crypto.randomUUID();
  const url = `${config.url}/api/v1/chat/${sessionId}/message`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(config.authToken ? { Authorization: `Bearer ${config.authToken}` } : {}),
    },
    body: JSON.stringify({
      message_id: messageId,
      content,
      role: 'user',
    }),
  });

  if (!response.ok) {
    throw new Error(`Gateway error: ${response.statusText}`);
  }

  return messageId;
}

// Message listeners for polling-based updates
const messageListeners = new Set<(msg: OpenClawMessage) => void>();
let pollInterval: ReturnType<typeof setInterval> | null = null;

/**
 * Subscribe to OpenClaw messages (polling-based)
 * Polls the Gateway for new messages every 2 seconds
 */
export function onOpenClawMessage(
  callback: (msg: OpenClawMessage) => void,
): () => void {
  messageListeners.add(callback);

  // Start polling if not already
  if (!pollInterval) {
    pollInterval = setInterval(async () => {
      // TODO: Implement polling endpoint check when Gateway supports it
      // For now, rely on manual refresh or SSE if supported
    }, 2000);
  }

  return () => {
    messageListeners.delete(callback);
    if (messageListeners.size === 0 && pollInterval) {
      clearInterval(pollInterval);
      pollInterval = null;
    }
  };
}