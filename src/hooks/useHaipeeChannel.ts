/**
 * React hook for Haipee channel integration.
 *
 * Provides:
 * - sendToClaudeCode: Send messages to Claude Code
 * - messages: Array of messages in the current chat
 * - isLoading: Whether waiting for a reply
 * - error: Any error that occurred
 */

import { useState, useEffect, useCallback, useRef } from "react";
import type { HaipeeMessage } from "../mcp-channel/bridge.js";

export type UseHaipeeChannelOptions = {
  chatId?: string;
  autoInit?: boolean;
};

export type UseHaipeeChannelReturn = {
  messages: HaipeeMessage[];
  sendMessage: (content: string) => Promise<void>;
  isLoading: boolean;
  error: string | null;
  clearHistory: () => void;
};

/**
 * Hook for using the Haipee channel in React components.
 */
export function useHaipeeChannel(
  options: UseHaipeeChannelOptions = {},
): UseHaipeeChannelReturn {
  const { chatId = "main", autoInit = true } = options;

  const [messages, setMessages] = useState<HaipeeMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const initializedRef = useRef(false);

  // Initialize channel on mount
  useEffect(() => {
    if (!autoInit) return;

    let unsubscribe: (() => void) | undefined;

    const init = async () => {
      if (initializedRef.current) return;
      initializedRef.current = true;

      try {
        const {
          initHaipeeChannel,
          onMessage,
          getChatHistory,
          setActiveChatId,
        } = await import("../mcp-channel/bridge.js");

        await initHaipeeChannel();
        setActiveChatId(chatId);

        // Load existing history
        setMessages(getChatHistory(chatId));

        // Subscribe to new messages
        unsubscribe = onMessage((message) => {
          if (message.chatId === chatId) {
            setMessages((prev) => [...prev, message]);
            if (message.role === "assistant") {
              setIsLoading(false);
            }
          }
        });
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      }
    };

    init();

    return () => {
      unsubscribe?.();
    };
  }, [chatId, autoInit]);

  // Send message
  const sendMessage = useCallback(
    async (content: string) => {
      if (!content.trim()) return;

      setIsLoading(true);
      setError(null);

      try {
        const { sendToClaudeCode } = await import("../mcp-channel/bridge.js");
        await sendToClaudeCode(content, chatId);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        setIsLoading(false);
      }
    },
    [chatId],
  );

  // Clear history
  const clearHistory = useCallback(async () => {
    const { clearChatHistory } = await import("../mcp-channel/bridge.js");
    clearChatHistory(chatId);
    setMessages([]);
  }, [chatId]);

  return {
    messages,
    sendMessage,
    isLoading,
    error,
    clearHistory,
  };
}
