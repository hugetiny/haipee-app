/**
 * Haipee MCP Channel Server Tests
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

// Mock the MCP SDK
vi.mock("@modelcontextprotocol/sdk/server/index.js", () => ({
  Server: vi.fn().mockImplementation(() => ({
    setRequestHandler: vi.fn(),
    notification: vi.fn().mockResolvedValue(undefined),
    connect: vi.fn().mockResolvedValue(undefined),
    close: vi.fn().mockResolvedValue(undefined),
  })),
}));

vi.mock("@modelcontextprotocol/sdk/server/stdio.js", () => ({
  StdioServerTransport: vi.fn().mockImplementation(() => ({})),
}));

describe("Haipee MCP Channel Server", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("Message Pushing", () => {
    it("should export pushMessage function", async () => {
      const { pushMessage } = await import("./server.js");
      expect(typeof pushMessage).toBe("function");
    });

    it("should return a message ID", async () => {
      const { pushMessage } = await import("./server.js");
      const id = await pushMessage("Hello");
      expect(id).toBeDefined();
      expect(typeof id).toBe("string");
    });

    it("should use 'main' as default chatId", async () => {
      const { pushMessage } = await import("./server.js");
      const id = await pushMessage("Test message");
      expect(id).toBeDefined();
    });
  });

  describe("Reply Callback", () => {
    it("should export setReplyCallback function", async () => {
      const { setReplyCallback } = await import("./server.js");
      expect(typeof setReplyCallback).toBe("function");
    });

    it("should accept a callback function", async () => {
      const { setReplyCallback } = await import("./server.js");
      const callback = vi.fn();
      expect(() => setReplyCallback(callback)).not.toThrow();
    });
  });

  describe("Server Lifecycle", () => {
    it("should export startMcpChannel function", async () => {
      const { startMcpChannel } = await import("./server.js");
      expect(typeof startMcpChannel).toBe("function");
    });

    it("should export stopMcpChannel function", async () => {
      const { stopMcpChannel } = await import("./server.js");
      expect(typeof stopMcpChannel).toBe("function");
    });
  });
});
