/**
 * OpenClaw Gateway Channel API
 *
 * 1:1 copy of AutoClaw's Gateway WebSocket implementation.
 * Uses WebSocket to connect to OpenClaw Gateway and send messages via `chat.send` RPC.
 */

import { invoke } from '@tauri-apps/api/core';

// ============================================================================
// Types
// ============================================================================

export interface OpenClawMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  sessionKey: string;
}

export interface OpenClawAgentResponse {
  runId: string;
  status: string;
  summary: string;
  result?: {
    payloads?: Array<{
      text: string;
      mediaUrl: string | null;
    }>;
    meta?: {
      durationMs: number;
      agentMeta?: {
        sessionId: string;
        provider: string;
        model: string;
      };
    };
  };
}

export interface OpenClawSession {
  key: string;
  sessionId: string;
  displayName?: string;
  channel?: string;
  updatedAt: number;
  model?: string;
  contextTokens?: number;
  totalTokens?: number;
}

export interface OpenClawGatewayStatus {
  connected: boolean;
  status: 'connected' | 'connecting' | 'disconnected' | 'error';
  error?: string;
}

export interface AgentStreamEvent {
  sessionKey: string;
  runId: string;
  eventType: string;
  content?: string;
  isComplete: boolean;
}

// ============================================================================
// Profile Management
// ============================================================================

/**
 * Initialize Haipee's OpenClaw profile
 * Creates ~/.openclaw-haipee/ directory with proper structure
 */
export async function initProfile(): Promise<string> {
  return invoke<string>('init_openclaw_profile');
}

/**
 * Check if OpenClaw profile exists
 */
export async function profileExists(): Promise<boolean> {
  return invoke<boolean>('openclaw_profile_exists');
}

// ============================================================================
// Gateway Connection Management
// ============================================================================

/**
 * Connect to OpenClaw Gateway via WebSocket
 * Initializes the profile if needed, then connects
 */
export async function connectGateway(): Promise<OpenClawGatewayStatus> {
  return invoke<OpenClawGatewayStatus>('connect_openclaw_gateway');
}

/**
 * Disconnect from OpenClaw Gateway
 */
export async function disconnectGateway(): Promise<void> {
  return invoke<void>('disconnect_openclaw_gateway');
}

/**
 * Get current gateway connection status
 */
export async function getGatewayStatus(): Promise<OpenClawGatewayStatus> {
  return invoke<OpenClawGatewayStatus>('get_openclaw_gateway_status');
}

/**
 * Start the OpenClaw Gateway service for Haipee profile
 */
export async function startGateway(): Promise<void> {
  return invoke<void>('start_openclaw_gateway');
}

/**
 * Stop the OpenClaw Gateway service for Haipee profile
 */
export async function stopGateway(): Promise<void> {
  return invoke<void>('stop_openclaw_gateway');
}

// ============================================================================
// Message Sending (1:1 AutoClaw implementation)
// ============================================================================

/**
 * Send a message to an OpenClaw session via WebSocket
 *
 * Uses the `chat.send` RPC method - exact same as AutoClaw's sendAgentMessage.
 *
 * @param sessionKey - Session key (e.g., "agent:main:main")
 * @param message - Message content
 * @param thinkingLevel - Optional thinking level (off, minimal, low, medium, high, xhigh)
 */
export async function sendMessage(
  sessionKey: string,
  message: string,
  thinkingLevel?: 'off' | 'minimal' | 'low' | 'medium' | 'high' | 'xhigh',
): Promise<OpenClawAgentResponse> {
  try {
    return await invoke<OpenClawAgentResponse>('send_openclaw_message', {
      sessionKey,
      message,
      thinkingLevel,
    });
  } catch (error) {
    throw new Error(`Failed to send message to OpenClaw: ${error}`);
  }
}

/**
 * Inject a system prompt into an OpenClaw session
 */
export async function injectSystemPrompt(
  sessionKey: string,
  content: string,
): Promise<void> {
  return invoke<void>('inject_openclaw_system_prompt', {
    sessionKey,
    content,
  });
}

// ============================================================================
// Session Management
// ============================================================================

/**
 * List OpenClaw sessions for the Haipee profile
 */
export async function listSessions(): Promise<{ sessions: OpenClawSession[]; count: number }> {
  return invoke<{ sessions: OpenClawSession[]; count: number }>('list_openclaw_sessions');
}

// ============================================================================
// Legacy API (backwards compatibility)
// ============================================================================

/**
 * @deprecated Use sendMessage instead
 * Send a message to an OpenClaw session via CLI
 */
export async function sendToOpenClaw(
  _sessionId: string,
  content: string,
): Promise<OpenClawAgentResponse> {
  // Try to use the new WebSocket API first
  try {
    const status = await getGatewayStatus();
    if (!status.connected) {
      await connectGateway();
    }
    // Use the default session key
    const sessionKey = `agent:main:main`;
    return await sendMessage(sessionKey, content);
  } catch {
    // Fallback: the old implementation is no longer available
    throw new Error('OpenClaw Gateway not available. Please start the gateway first.');
  }
}

// ============================================================================
// Event Handling
// ============================================================================

// Message listeners for polling-based updates
const messageListeners = new Set<(msg: OpenClawMessage) => void>();

/**
 * Subscribe to OpenClaw messages (polling-based)
 */
export function onOpenClawMessage(
  callback: (msg: OpenClawMessage) => void,
): () => void {
  messageListeners.add(callback);

  return () => {
    messageListeners.delete(callback);
  };
}

/**
 * Notify all listeners of a new message (used internally)
 */
export function notifyOpenClawMessage(msg: OpenClawMessage): void {
  for (const listener of messageListeners) {
    listener(msg);
  }
}