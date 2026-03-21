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
| Claude Code | MCP Channel (`sendToClaudeCode`) | Implement |
| OpenClaw | Gateway HTTP API | Implement |
| Codex | N/A | Show "正在开发中" |
| Gemini CLI | N/A | Show "正在开发中" |
| OpenCode | N/A | Show "正在开发中" |

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
- `src/App.tsx` - Remove `chat` from View type and renderContent switch
- `src/components/layout/MainLayout.tsx` - Remove chat from MAIN_MENU_ITEMS

### Phase 2: Implement OpenClaw Channel API

Create `src/lib/api/openclawChannel.ts`:

```typescript
// OpenClaw Gateway HTTP API for sending messages
export interface OpenClawMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  sessionId: string;
}

export interface OpenClawChannelConfig {
  gatewayUrl: string;
  authToken?: string;
}

// Initialize channel with config from openclaw config file
export async function initOpenClawChannel(): Promise<void>

// Send message to specific session
export async function sendToOpenClaw(sessionId: string, content: string): Promise<string>

// Subscribe to incoming messages (SSE or polling)
export function onOpenClawMessage(callback: (msg: OpenClawMessage) => void): () => void

// Get config from ~/.openclaw/config.json
export async function getOpenClawChannelConfig(): Promise<OpenClawChannelConfig>
```

### Phase 3: Enhance SessionManagerPage Input

Modify `src/components/sessions/SessionManagerPage.tsx`:

1. **Replace placeholder input logic with real channel sending:**

```typescript
const handleSendMessage = async () => {
  if (!inputMessage.trim() || !selectedSession) return;

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

    // Listen for response and update messages
    // Response handling via channel callbacks
  } catch (error) {
    toast.error(extractErrorMessage(error));
  } finally {
    setIsSending(false);
  }
};
```

2. **Add message subscription on session select:**

```typescript
useEffect(() => {
  if (!selectedSession) return;

  const providerId = selectedSession.providerId;

  if (providerId === 'claude') {
    const unsubscribe = onMessage((msg) => {
      if (msg.chatId === selectedSession.sessionId) {
        // Refresh messages or append to list
        void refetchMessages();
      }
    });
    return unsubscribe;
  }

  if (providerId === 'openclaw') {
    const unsubscribe = onOpenClawMessage((msg) => {
      if (msg.sessionId === selectedSession.sessionId) {
        void refetchMessages();
      }
    });
    return unsubscribe;
  }
}, [selectedSession]);
```

3. **Add loading state during send:**

```typescript
const [isSending, setIsSending] = useState(false);
```

### Phase 4: Remove TUI Choice Dialog

Remove the `showTuiChoice` dialog logic since we're now sending messages directly. The input box should send immediately, not show a choice dialog.

### Phase 5: Tauri E2E Tests

Create `tests/e2e/tauri/channel-communication.spec.ts`:

```typescript
describe('Channel Communication', () => {
  it('should send message via Claude Code MCP channel', async () => {
    // 1. Select Claude Code session
    // 2. Type message in input
    // 3. Click send button
    // 4. Verify message appears in list
    // 5. Verify response appears (mock or real)
  });

  it('should send message via OpenClaw Gateway', async () => {
    // 1. Select OpenClaw session
    // 2. Type message in input
    // 3. Click send button
    // 4. Verify message sent to gateway
    // 5. Verify response appears
  });

  it('should show "under development" for unsupported agents', async () => {
    // 1. Select Codex session
    // 2. Type message and send
    // 3. Verify toast shows "正在开发中"
  });
});
```

## File Changes Summary

| Action | File | Purpose |
|--------|------|---------|
| Delete | `src/components/chat/*` | Remove duplicate chat view |
| Modify | `src/App.tsx` | Remove chat from routing |
| Modify | `src/components/layout/MainLayout.tsx` | Remove chat from nav menu |
| Create | `src/lib/api/openclawChannel.ts` | OpenClaw Gateway API |
| Modify | `src/components/sessions/SessionManagerPage.tsx` | Real channel sending |
| Create | `tests/e2e/tauri/channel-communication.spec.ts` | E2E tests |

## Verification

1. `bun run typecheck` - TypeScript compilation
2. `bun run test:unit` - Unit tests pass
3. `bun run test:e2e:tauri` - Tauri E2E tests pass
4. Manual test:
   - Select Claude Code session, send message, see response
   - Select OpenClaw session, send message, see response
   - Select Codex session, send message, see "正在开发中" toast

## Open Questions

1. **OpenClaw Gateway SSE vs Polling** - Should we use Server-Sent Events or polling for responses?
   - Recommendation: Check OpenClaw Gateway API documentation for streaming support
   - If SSE supported, prefer SSE for real-time updates
   - Otherwise, use polling with reasonable interval (1-2 seconds)

2. **Message persistence** - After sending via channel, do we need to refresh the JSONL file to see new messages?
   - CLI tools write to JSONL
   - We may need to re-read the file after channel sends
   - Or rely on channel callbacks to append to UI state