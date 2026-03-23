/**
 * Haipee MCP Channel
 *
 * This module provides bidirectional communication between:
 * - The Haipee Tauri app UI
 * - Claude Code (via MCP channel protocol)
 *
 * Usage:
 * ```ts
 * import { initHaipeeChannel, sendToClaudeCode, onMessage } from "./mcp-channel";
 *
 * // Initialize the channel
 * await initHaipeeChannel();
 *
 * // Send a message to Claude Code
 * await sendToClaudeCode("Hello!");
 *
 * // Listen for replies
 * const unsubscribe = onMessage((message) => {
 *   console.log("Received:", message);
 * });
 * ```
 *
 * In React components, use the hook instead:
 * ```tsx
 * import { useHaipeeChannel } from "../hooks/useHaipeeChannel";
 *
 * function ChatComponent() {
 *   const { messages, sendMessage, isLoading } = useHaipeeChannel();
 *   // ...
 * }
 * ```
 */

// Server exports
export {
  startMcpChannel,
  stopMcpChannel,
  pushMessage,
  setReplyCallback,
} from "./server.js";

// Bridge exports
export {
  initHaipeeChannel,
  shutdownHaipeeChannel,
  sendToClaudeCode,
  onMessage,
  getChatHistory,
  clearChatHistory,
  setActiveChatId,
  getActiveChatId,
  type HaipeeMessage,
  type HaipeeMessageCallback,
} from "./bridge.js";
