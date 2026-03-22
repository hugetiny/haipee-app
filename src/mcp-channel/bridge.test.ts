/**
 * Haipee Channel Bridge Tests
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

// Mock the server module before any imports
vi.mock("./server.js", () => ({
  startMcpChannel: vi.fn().mockResolvedValue(undefined),
  stopMcpChannel: vi.fn().mockResolvedValue(undefined),
  pushMessage: vi.fn().mockResolvedValue("test-message-id"),
  setReplyCallback: vi.fn(),
}));

describe("Haipee Channel Bridge", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Simulate Tauri environment by setting __TAURI_INTERNALS__
    (globalThis as Record<string, unknown>).__TAURI_INTERNALS__ = {};
  });

  afterEach(() => {
    vi.restoreAllMocks();
    // Restore original state
    delete (globalThis as Record<string, unknown>).__TAURI_INTERNALS__;
  });

  describe("Initialization", () => {
    it("should export initHaipeeChannel function", async () => {
      const { initHaipeeChannel } = await import("./bridge.js");
      expect(typeof initHaipeeChannel).toBe("function");
    });

    it("should export shutdownHaipeeChannel function", async () => {
      const { shutdownHaipeeChannel } = await import("./bridge.js");
      expect(typeof shutdownHaipeeChannel).toBe("function");
    });

    it("should call startMcpChannel on init in Tauri environment", async () => {
      // Clear module cache to force re-import with mock
      vi.resetModules();

      // Re-mock after reset
      vi.mock("./server.js", () => ({
        startMcpChannel: vi.fn().mockResolvedValue(undefined),
        stopMcpChannel: vi.fn().mockResolvedValue(undefined),
        pushMessage: vi.fn().mockResolvedValue("test-message-id"),
        setReplyCallback: vi.fn(),
      }));

      const { initHaipeeChannel } = await import("./bridge.js");
      const { startMcpChannel } = await import("./server.js");

      await initHaipeeChannel();

      expect(startMcpChannel).toHaveBeenCalled();
    });
  });

  describe("Message Sending", () => {
    it("should export sendToClaudeCode function", async () => {
      const { sendToClaudeCode } = await import("./bridge.js");
      expect(typeof sendToClaudeCode).toBe("function");
    });

    it("should return a message ID", async () => {
      // This test runs in browser mock mode since we clear module state
      const { initHaipeeChannel, sendToClaudeCode } = await import("./bridge.js");
      await initHaipeeChannel();

      const messageId = await sendToClaudeCode("Hello Claude!");
      // Message ID should be a UUID
      expect(typeof messageId).toBe("string");
      expect(messageId.length).toBeGreaterThan(0);
    });

    it("should use default chat ID 'main'", async () => {
      const { initHaipeeChannel, getActiveChatId } = await import("./bridge.js");
      await initHaipeeChannel();

      expect(getActiveChatId()).toBe("main");
    });
  });

  describe("Message Subscription", () => {
    it("should export onMessage function", async () => {
      const { onMessage } = await import("./bridge.js");
      expect(typeof onMessage).toBe("function");
    });

    it("should return unsubscribe function", async () => {
      const { onMessage } = await import("./bridge.js");
      const unsubscribe = onMessage(() => {});
      expect(typeof unsubscribe).toBe("function");
    });
  });

  describe("Chat History", () => {
    it("should export getChatHistory function", async () => {
      const { getChatHistory } = await import("./bridge.js");
      expect(typeof getChatHistory).toBe("function");
    });

    it("should return empty array for new chat", async () => {
      const { getChatHistory } = await import("./bridge.js");
      const history = getChatHistory("new-chat");
      expect(Array.isArray(history)).toBe(true);
      expect(history.length).toBe(0);
    });

    it("should export clearChatHistory function", async () => {
      const { clearChatHistory } = await import("./bridge.js");
      expect(typeof clearChatHistory).toBe("function");
    });
  });

  describe("Active Chat Management", () => {
    it("should export setActiveChatId function", async () => {
      const { setActiveChatId } = await import("./bridge.js");
      expect(typeof setActiveChatId).toBe("function");
    });

    it("should export getActiveChatId function", async () => {
      const { getActiveChatId } = await import("./bridge.js");
      expect(typeof getActiveChatId).toBe("function");
    });

    it("should update active chat ID", async () => {
      const { setActiveChatId, getActiveChatId } = await import("./bridge.js");
      setActiveChatId("chat-123");
      expect(getActiveChatId()).toBe("chat-123");
    });
  });
});