/**
 * Haipee Channel Bridge
 *
 * This module provides the integration between:
 * - The MCP channel server (communicates with Claude Code)
 * - The Tauri app UI (React components)
 *
 * It handles:
 * 1. Starting/stopping the MCP channel when a chat session is active
 * 2. Forwarding messages from UI to Claude Code
 * 3. Delivering replies from Claude Code to the UI
 */

export type HaipeeMessage = {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: number;
  chatId: string;
};

export type HaipeeMessageCallback = (message: HaipeeMessage) => void;

// Store for message listeners
const messageListeners = new Set<HaipeeMessageCallback>();

// Message history per chat
const chatHistory = new Map<string, HaipeeMessage[]>();

// Current active chat ID
let activeChatId = "main";

// Server module reference (loaded dynamically in Node.js/Tauri only)
let serverModule: {
  startMcpChannel: () => Promise<unknown>;
  stopMcpChannel: () => Promise<void>;
  pushMessage: (content: string, chatId: string) => Promise<string>;
  setReplyCallback: (cb: (chatId: string, text: string) => Promise<void>) => void;
} | null = null;

// Track if MCP server started successfully
let mcpServerStarted = false;

/**
 * Check if we're in a browser environment (not Node.js/Tauri)
 */
function isBrowserEnvironment(): boolean {
  return typeof window !== "undefined" && !(window as unknown as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__;
}

/**
 * Initialize the Haipee channel bridge.
 */
export async function initHaipeeChannel(): Promise<void> {
  // In browser environment, provide mock implementation
  if (isBrowserEnvironment()) {
    console.log("[Haipee Channel] Running in browser mode - using mock");
    return;
  }

  // In Node.js/Tauri, load and start the server module
  try {
    // Dynamic import - may fail in browser if Node.js APIs are not available
    // Using try-catch to handle any bundling/runtime issues
    const serverPath = "./server.js";
    const module = await import(/* @vite-ignore */ serverPath);
    serverModule = module;

    // Set up the reply callback to receive messages from Claude Code
    serverModule?.setReplyCallback(async (chatId: string, text: string) => {
      const message: HaipeeMessage = {
        id: crypto.randomUUID(),
        role: "assistant",
        content: text,
        timestamp: Date.now(),
        chatId,
      };

      // Store in history
      const history = chatHistory.get(chatId) ?? [];
      history.push(message);
      chatHistory.set(chatId, history);

      // Notify listeners
      for (const listener of messageListeners) {
        listener(message);
      }
    });

    // Start the MCP channel server
    await serverModule?.startMcpChannel();
    mcpServerStarted = true;
    console.log("[Haipee Channel] MCP server started");
  } catch (error) {
    // If import fails (e.g., in browser mode), log and continue with mock
    console.warn("[Haipee Channel] MCP server not available, using mock mode:", error);
    // Don't throw - allow the app to continue with mock functionality
  }
}

/**
 * Shutdown the Haipee channel bridge.
 */
export async function shutdownHaipeeChannel(): Promise<void> {
  if (serverModule && mcpServerStarted) {
    await serverModule.stopMcpChannel();
  }
  serverModule = null;
  mcpServerStarted = false;
  messageListeners.clear();
  chatHistory.clear();
}

/**
 * Send a message from the UI to Claude Code.
 * Returns the message ID.
 */
export async function sendToClaudeCode(
  content: string,
  chatId?: string,
): Promise<string> {
  const targetChatId = chatId ?? activeChatId;
  const messageId = crypto.randomUUID();

  // Store the user message
  const userMessage: HaipeeMessage = {
    id: messageId,
    role: "user",
    content,
    timestamp: Date.now(),
    chatId: targetChatId,
  };

  const history = chatHistory.get(targetChatId) ?? [];
  history.push(userMessage);
  chatHistory.set(targetChatId, history);

  // Notify listeners of the user message
  for (const listener of messageListeners) {
    listener(userMessage);
  }

  // In browser environment or when server not available, simulate a response
  const useMock = isBrowserEnvironment() || !mcpServerStarted;
  console.log("[Haipee Channel] sendToClaudeCode:", { useMock, isBrowser: isBrowserEnvironment(), serverStarted: mcpServerStarted, listeners: messageListeners.size });
  if (useMock) {
    // Simulate async response
    setTimeout(() => {
      console.log("[Haipee Channel] Simulated response firing, listeners:", messageListeners.size);
      const response: HaipeeMessage = {
        id: crypto.randomUUID(),
        role: "assistant",
        content: `[Browser Mock] Received: "${content}"\n\nThis is a simulated response. In Tauri, this would be sent to Claude Code via MCP channel.`,
        timestamp: Date.now(),
        chatId: targetChatId,
      };
      const currentHistory = chatHistory.get(targetChatId);
      if (currentHistory) {
        currentHistory.push(response);
      }
      for (const listener of messageListeners) {
        listener(response);
      }
    }, 500);
    return messageId;
  }

  // Push to Claude Code via MCP
  await serverModule?.pushMessage(content, targetChatId);

  return messageId;
}

/**
 * Subscribe to message updates.
 */
export function onMessage(callback: HaipeeMessageCallback): () => void {
  messageListeners.add(callback);
  return () => {
    messageListeners.delete(callback);
  };
}

/**
 * Get message history for a chat.
 */
export function getChatHistory(chatId?: string): HaipeeMessage[] {
  return chatHistory.get(chatId ?? activeChatId) ?? [];
}

/**
 * Clear message history for a chat.
 */
export function clearChatHistory(chatId?: string): void {
  chatHistory.delete(chatId ?? activeChatId);
}

/**
 * Set the active chat ID.
 */
export function setActiveChatId(chatId: string): void {
  activeChatId = chatId;
}

/**
 * Get the active chat ID.
 */
export function getActiveChatId(): string {
  return activeChatId;
}