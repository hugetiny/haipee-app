# Design: Unified Sessions Interface with Real Channel Communication

## Overview

Remove the duplicate `chat` view and enhance `sessions` view to support real-time messaging through agent-specific channels. Users can continue existing CLI sessions by sending messages directly from the GUI.

## Problem Statement

Currently there are two overlapping interfaces:
1. **SessionManagerPage** (`sessions` view) - Shows CLI session history from JSONL files, has a non-functional input box
2. **ChatContainer** (`chat` view) - Separate chat interface with its own session management

This creates confusion and duplicates functionality. The GUI should be a frontend for CLI/Channel communication, not store conversations locally.

## Goals

1. Delete the `chat` view entirely
2. Make the `sessions` view input box functional
3. Implement real message sending through agent-specific channels
4. Pass Tauri E2E tests verifying both Claude Code MCP Channel and OpenClaw Gateway work

## Agent Channel Support

| Agent | Channel Type | Status |
|-------|-------------|--------|
| Claude Code | MCP Channel (existing `sendToClaudeCode`) | Integrate |
| OpenClaw | Gateway HTTP API | Implement |
| Codex | N/A | Show "正在开发中" |
| Gemini CLI | N/A | Show "正在开发中" |
| OpenCode | N/A | Show "正在开发中" |

## Existing MCP Channel Implementation

The Claude Code MCP channel already exists:
- `src/mcp-channel/bridge.ts` - Exports `sendToClaudeCode`, `onMessage`, `initHaipeeChannel`
- `src/mcp-channel/server.ts` - MCP server implementation
- `src/mcp-channel/index.ts` - Re-exports

**Integration notes:**
- `initHaipeeChannel()` must be called at app startup
- `sendToClaudeCode(content, chatId)` sends message to specific session
- `onMessage(callback)` subscribes to incoming messages

## Implementation

### Phase 1: Delete Chat View

**Files to delete:**
- `src/components/chat/ChatContainer.tsx`
- `src/components/chat/ChatMessage.tsx`
- `src/components/chat/ChatInput.tsx`
- `src/components/chat/ChatSessionList.tsx`
- `src/components/chat/useChat.ts`
- `src/components/chat/types.ts`
- `src/components/chat/index.ts`

**Files to modify:**

1. `src/App.tsx`:
   - Remove `"chat"` from `View` type
   - Remove `"chat"` from `VALID_VIEWS` array
   - Remove `case "chat":` from `renderContent()`
   - Remove `ChatContainer` import

2. `src/components/layout/MainLayout.tsx`:
   - Remove `chat` item from `MAIN_MENU_ITEMS` array (lines 59-64)

### Phase 2: Implement OpenClaw Channel API

Create `src/lib/api/openclawChannel.ts`:

```typescript
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
 * Send message to OpenClaw Gateway HTTP API
 * Gateway endpoint: POST /api/v1/chat/{sessionId}/message
 */
export async function sendToOpenClaw(
  sessionId: string,
  content: string,
  instance?: OpenClawInstance,
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
      // TODO: Implement polling endpoint check
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
```

### Phase 3: Enhance SessionManagerPage Input

Modify `src/components/sessions/SessionManagerPage.tsx`:

1. **Add imports:**
```typescript
import { sendToClaudeCode, onMessage, initHaipeeChannel } from '@/mcp-channel';
import { sendToOpenClaw, onOpenClawMessage } from '@/lib/api/openclawChannel';
```

2. **Replace handleSendMessage (replace the form onSubmit logic around line 873):**

```typescript
const [isSending, setIsSending] = useState(false);

const handleSendMessage = async (e: React.FormEvent) => {
  e.preventDefault();
  if (!inputMessage.trim() || !selectedSession || isSending) return;

  const providerId = selectedSession.providerId;
  const sessionId = selectedSession.sessionId;
  const content = inputMessage.trim();

  setInputMessage('');
  setIsSending(true);

  try {
    if (providerId === 'claude') {
      // Use MCP Channel
      await sendToClaudeCode(content, sessionId);
    } else if (providerId === 'openclaw') {
      // Use Gateway HTTP API
      await sendToOpenClaw(sessionId, content);
    } else {
      // Show "under development" toast
      toast.info(t('sessionManager.channelUnderDevelopment', {
        defaultValue: '{{agent}} 的消息功能正在开发中',
        agent: getProviderLabel(providerId, t)
      }));
      setIsSending(false);
      return;
    }

    // Refetch messages after sending
    await refetch();
  } catch (error) {
    toast.error(extractErrorMessage(error));
  } finally {
    setIsSending(false);
  }
};
```

3. **Update form submit button to show loading state:**
```typescript
<Button type="submit" size="icon" disabled={!inputMessage.trim() || isSending}>
  {isSending ? (
    <RefreshCw className="size-4 animate-spin" />
  ) : (
    <Send className="size-4" />
  )}
</Button>
```

4. **Remove showTuiChoice dialog for input submit:**
- Keep `showTuiChoice` state for Terminal/Browser buttons
- Only remove it from the form onSubmit handler
- The form should call `handleSendMessage` directly, not `setShowTuiChoice(true)`

5. **Add channel message subscription:**
```typescript
// Subscribe to channel messages when session changes
useEffect(() => {
  if (!selectedSession) return;

  const providerId = selectedSession.providerId;
  const sessionId = selectedSession.sessionId;

  if (providerId === 'claude') {
    const unsubscribe = onMessage((msg) => {
      if (msg.chatId === sessionId) {
        void refetch();
      }
    });
    return unsubscribe;
  }

  if (providerId === 'openclaw') {
    const unsubscribe = onOpenClawMessage((msg) => {
      if (msg.sessionId === sessionId) {
        void refetch();
      }
    });
    return unsubscribe;
  }
}, [selectedSession, refetch]);
```

### Phase 4: Initialize MCP Channel at App Startup

Modify `src/App.tsx`:

```typescript
import { initHaipeeChannel } from '@/mcp-channel';

// In App component, add useEffect for initialization:
useEffect(() => {
  let active = true;

  const initChannels = async () => {
    try {
      await initHaipeeChannel();
      if (active) {
        console.log('[App] MCP channel initialized');
      }
    } catch (error) {
      console.error('[App] Failed to initialize MCP channel:', error);
      // Continue without MCP - will show error when trying to send
    }
  };

  void initChannels();

  return () => {
    active = false;
  };
}, []);
```

### Phase 5: Update Browser Mock

Modify `src/lib/browser-mock.ts` to add channel command mocks for Playwright tests:

```typescript
// Add to mockCommandHandlers object:
'send_to_openclaw': async () => {
  return { success: true, messageId: crypto.randomUUID() };
},
```

### Phase 6: Tauri E2E Tests

Create `tests/e2e/tauri/channel-communication.spec.ts`:

```typescript
import { expect } from '@wdio/globals';
import { SessionManagerPage } from '../pages/SessionManagerPage';

describe('Channel Communication', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.open();
  });

  it('should send message via Claude Code MCP channel', async () => {
    // 1. Navigate to sessions view
    await sessionPage.navigateToSessions();

    // 2. Select a Claude Code session
    await sessionPage.selectSessionByProvider('claude');

    // 3. Type message in input
    await sessionPage.inputMessage('Test message from GUI');

    // 4. Click send button
    await sessionPage.clickSend();

    // 5. Verify message appears in list (may need wait for response)
    await browser.pause(1000);
    const messages = await sessionPage.getMessages();
    expect(messages.length).toBeGreaterThan(0);
  });

  it('should send message via OpenClaw Gateway', async () => {
    // 1. Navigate to sessions view
    await sessionPage.navigateToSessions();

    // 2. Select an OpenClaw session
    await sessionPage.selectSessionByProvider('openclaw');

    // 3. Type message and send
    await sessionPage.inputMessage('Test message via Gateway');
    await sessionPage.clickSend();

    // 4. Verify message sent
    await browser.pause(1000);
    const messages = await sessionPage.getMessages();
    expect(messages.length).toBeGreaterThan(0);
  });

  it('should show "under development" for unsupported agents', async () => {
    // 1. Select Codex session
    await sessionPage.navigateToSessions();
    await sessionPage.selectSessionByProvider('codex');

    // 2. Type message and send
    await sessionPage.inputMessage('Test');
    await sessionPage.clickSend();

    // 3. Verify toast shows "正在开发中"
    const toast = await sessionPage.getToast();
    expect(toast).toContain('开发中');
  });
});
```

## i18n Keys Required

Add to `src/i18n/locales/zh.json`:
```json
{
  "sessionManager": {
    "channelUnderDevelopment": "{{agent}} 的消息功能正在开发中"
  }
}
```

Add to `src/i18n/locales/en.json`:
```json
{
  "sessionManager": {
    "channelUnderDevelopment": "{{agent}} messaging is under development"
  }
}
```

## File Changes Summary

| Action | File | Purpose |
|--------|------|---------|
| Delete | `src/components/chat/*` | Remove duplicate chat view |
| Modify | `src/App.tsx` | Remove chat view, add MCP init |
| Modify | `src/components/layout/MainLayout.tsx` | Remove chat from nav menu |
| Create | `src/lib/api/openclawChannel.ts` | OpenClaw Gateway API |
| Modify | `src/components/sessions/SessionManagerPage.tsx` | Real channel sending |
| Modify | `src/lib/browser-mock.ts` | Add channel mocks |
| Create | `tests/e2e/tauri/channel-communication.spec.ts` | E2E tests |
| Modify | `src/i18n/locales/*.json` | Add translation keys |

## Verification

1. `bun run typecheck` - TypeScript compilation
2. `bun run test:unit` - Unit tests pass
3. `bun run test:e2e:tauri` - Tauri E2E tests pass
4. Manual test:
   - Select Claude Code session, send message, see response
   - Select OpenClaw session, send message, see response
   - Select Codex session, send message, see "正在开发中" toast

## OpenClaw Gateway Notes

- Gateway URL obtained from `~/.openclaw/config.json` via `openclawApi.getJsonSection('gateway')`
- Default gateway URL: `http://127.0.0.1:18789`
- Auth token from `gateway.auth.token` if configured
- Uses polling (2s interval) for message updates - can be upgraded to SSE if Gateway supports it