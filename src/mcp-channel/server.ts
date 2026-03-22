/**
 * Haipee MCP Channel Server
 *
 * This is an MCP server that acts as a Claude Code channel.
 * It enables bidirectional communication between:
 * - Haipee Tauri app UI -> Claude Code (inbound messages)
 * - Claude Code -> Haipee Tauri app UI (replies via tool calls)
 *
 * The server:
 * 1. Declares `claude/channel` capability to register as a channel
 * 2. Exposes a `reply` tool for Claude to send messages back
 * 3. Communicates with the Tauri app via stdin/stdout JSON messages
 *
 * Usage:
 * - Claude Code spawns this as a subprocess
 * - The Tauri app connects to this server to send/receive messages
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// Message queue for pending inbound messages from Tauri app
const pendingMessages: Array<{
  id: string;
  content: string;
  chatId: string;
  timestamp: number;
}> = [];

// Callback for sending replies back to Tauri app
let replyCallback: ((chatId: string, text: string) => Promise<void>) | null =
  null;

/**
 * Set the callback for sending replies to the Tauri app.
 */
export function setReplyCallback(
  cb: (chatId: string, text: string) => Promise<void>,
) {
  replyCallback = cb;
}

/**
 * Push a message from the Tauri app to Claude Code.
 */
export async function pushMessage(content: string, chatId: string = "main") {
  const id = crypto.randomUUID();
  pendingMessages.push({
    id,
    content,
    chatId,
    timestamp: Date.now(),
  });

  // Emit notification to Claude Code
  if (mcp) {
    await mcp.notification({
      method: "notifications/claude/channel",
      params: {
        content,
        meta: {
          chat_id: chatId,
          message_id: id,
        },
      },
    });
  }

  return id;
}

// MCP Server instance
let mcp: Server | null = null;

/**
 * Create and start the MCP channel server.
 */
export async function startMcpChannel(): Promise<Server> {
  mcp = new Server(
    { name: "haipee", version: "1.0.0" },
    {
      capabilities: {
        experimental: { "claude/channel": {} },
        tools: {},
      },
      instructions: `Messages arrive as <channel source="haipee" chat_id="..." message_id="...">.
Reply with the haipee_reply tool, passing the chat_id from the tag.
This channel is connected to the Haipee Tauri desktop app.`,
    },
  );

  // Register tool list handler
  mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: "haipee_reply",
        description:
          "Send a message back to the Haipee Tauri app. Use this to respond to user messages.",
        inputSchema: {
          type: "object",
          properties: {
            chat_id: {
              type: "string",
              description: "The conversation to reply in (from the channel tag)",
            },
            text: {
              type: "string",
              description: "The message to send",
            },
          },
          required: ["chat_id", "text"],
        },
      },
    ],
  }));

  // Register tool call handler
  mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
    if (req.params.name === "haipee_reply") {
      const { chat_id, text } = req.params.arguments as {
        chat_id: string;
        text: string;
      };

      // Send reply to Tauri app
      if (replyCallback) {
        await replyCallback(chat_id, text);
      } else {
        // Write to stderr for logging if no callback
        console.error(`[haipee] Reply to ${chat_id}: ${text}`);
      }

      return {
        content: [{ type: "text", text: "sent" }],
      };
    }
    throw new Error(`Unknown tool: ${req.params.name}`);
  });

  // Connect over stdio
  await mcp.connect(new StdioServerTransport());

  return mcp;
}

/**
 * Stop the MCP channel server.
 */
export async function stopMcpChannel() {
  if (mcp) {
    await mcp.close();
    mcp = null;
  }
}

// Main entry point when run as standalone (Node.js only)
// Check for Node.js environment before accessing process
const isMain =
  typeof process !== "undefined" &&
  process.argv?.[1]?.includes("server.ts");
if (isMain) {
  startMcpChannel()
    .then(() => {
      console.error("[haipee] MCP channel server started");
    })
    .catch((err) => {
      console.error("[haipee] Failed to start:", err);
      process.exit(1);
    });
}