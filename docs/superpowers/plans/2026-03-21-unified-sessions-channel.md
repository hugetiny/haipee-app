# Unified Sessions Channel Communication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove duplicate chat view and enable real message sending in sessions view through agent-specific channels (MCP for Claude, Gateway HTTP for OpenClaw).

**Architecture:** Delete chat components, integrate existing MCP channel, create new OpenClaw Gateway API, enhance SessionManagerPage with real channel communication.

**Tech Stack:** React, TypeScript, Tauri, WebdriverIO E2E

---

## Task 1: Delete Chat View Components

**Files:**
- Delete: `src/components/chat/ChatContainer.tsx`
- Delete: `src/components/chat/ChatMessage.tsx`
- Delete: `src/components/chat/ChatInput.tsx`
- Delete: `src/components/chat/ChatSessionList.tsx`
- Delete: `src/components/chat/useChat.ts`
- Delete: `src/components/chat/types.ts`
- Delete: `src/components/chat/index.ts`

- [ ] **Step 1: Delete chat component files**

```bash
rm -rf src/components/chat
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: May show errors about missing imports in App.tsx (will fix in next task)

---

## Task 2: Remove Chat from App.tsx

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Remove ChatContainer import**

Find and remove this line:
```typescript
import { ChatContainer } from "@/components/chat";
```

- [ ] **Step 2: Remove "chat" from View type**

Find:
```typescript
type View =
  | "providers"
  | "settings"
  | "prompts"
  | "skills"
  | "skillsDiscovery"
  | "mcp"
  | "agents"
  | "universal"
  | "sessions"
  | "chat"
  | "channels";
```

Replace with:
```typescript
type View =
  | "providers"
  | "settings"
  | "prompts"
  | "skills"
  | "skillsDiscovery"
  | "mcp"
  | "agents"
  | "universal"
  | "sessions"
  | "channels";
```

- [ ] **Step 3: Remove "chat" from VALID_VIEWS array**

Find:
```typescript
const VALID_VIEWS: View[] = [
  "providers",
  "settings",
  "prompts",
  "skills",
  "skillsDiscovery",
  "mcp",
  "agents",
  "universal",
  "sessions",
  "chat",
  "channels",
];
```

Replace with:
```typescript
const VALID_VIEWS: View[] = [
  "providers",
  "settings",
  "prompts",
  "skills",
  "skillsDiscovery",
  "mcp",
  "agents",
  "universal",
  "sessions",
  "channels",
];
```

- [ ] **Step 4: Remove chat case from renderContent**

Find and remove:
```typescript
        case "chat":
          return (
            <ChatContainer
              key={activeApp}
              providerId={currentProviderId}
              appId={activeApp}
              className="h-full"
            />
          );
```

- [ ] **Step 5: Add MCP channel initialization import**

Add after existing imports:
```typescript
import { initHaipeeChannel } from "@/mcp-channel";
```

- [ ] **Step 6: Add MCP channel initialization useEffect**

Add after the existing useEffect hooks (around line 380):
```typescript
  // Initialize MCP channel for Claude Code communication
  useEffect(() => {
    let active = true;

    const initChannels = async () => {
      try {
        await initHaipeeChannel();
        if (active) {
          console.log("[App] MCP channel initialized");
        }
      } catch (error) {
        console.error("[App] Failed to initialize MCP channel:", error);
        // Continue without MCP - will show error when trying to send
      }
    };

    void initChannels();

    return () => {
      active = false;
    };
  }, []);
```

- [ ] **Step 7: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add src/App.tsx src/components/chat
git commit -m "refactor: remove duplicate chat view, add MCP channel init"
```

---

## Task 3: Remove Chat from Navigation Menu

**Files:**
- Modify: `src/components/layout/MainLayout.tsx`

- [ ] **Step 1: Remove chat from MAIN_MENU_ITEMS**

Find:
```typescript
const MAIN_MENU_ITEMS = [
  {
    id: "chat",
    icon: MessageSquare,
    labelKey: "chat.title",
    labelFallback: "对话",
  },
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "channels",
    icon: Radio,
    labelKey: "channels.title",
    labelFallback: "Channel",
  },
] as const;
```

Replace with:
```typescript
const MAIN_MENU_ITEMS = [
  {
    id: "sessions",
    icon: History,
    labelKey: "sessionManager.title",
    labelFallback: "会话管理",
  },
  {
    id: "channels",
    icon: Radio,
    labelKey: "channels.title",
    labelFallback: "Channel",
  },
] as const;
```

Note: `MessageSquare` import will become unused but keep it as it may be used elsewhere.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/MainLayout.tsx
git commit -m "refactor: remove chat from navigation menu"
```

---

## Task 4: Create OpenClaw Channel API

**Files:**
- Create: `src/lib/api/openclawChannel.ts`

- [ ] **Step 1: Create openclawChannel.ts**

```typescript
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
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/lib/api/openclawChannel.ts
git commit -m "feat: add OpenClaw Gateway channel API"
```

---

## Task 5: Add Browser Mock for Gateway Config

**Files:**
- Modify: `src/lib/browser-mock.ts`

- [ ] **Step 1: Add get_openclaw_json_section mock**

Find after the `read_openclaw_json_raw` handler (around line 27):
```typescript
      if (cmd === "read_openclaw_json_raw")
        return '{\n  "agents": {},\n  "env": {},\n  "tools": {}\n}';
```

Add after it:
```typescript
      if (cmd === "get_openclaw_json_section") {
        if (args?.section === "gateway") {
          return { url: "http://127.0.0.1:18789" };
        }
        return {};
      }
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/lib/browser-mock.ts
git commit -m "feat: add gateway config mock for browser tests"
```

---

## Task 6: Add i18n Translation Keys

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`

- [ ] **Step 1: Add Chinese translation key**

Find the `sessionManager` section in `src/i18n/locales/zh.json` and add:
```json
"channelUnderDevelopment": "{{agent}} 的消息功能正在开发中"
```

- [ ] **Step 2: Add English translation key**

Find the `sessionManager` section in `src/i18n/locales/en.json` and add:
```json
"channelUnderDevelopment": "{{agent}} messaging is under development"
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json
git commit -m "feat: add channel under development i18n keys"
```

---

## Task 7: Enhance SessionManagerPage with Real Channel Sending

**Files:**
- Modify: `src/components/sessions/SessionManagerPage.tsx`

- [ ] **Step 1: Add channel imports**

Add after existing imports (around line 25):
```typescript
import { sendToClaudeCode, onMessage } from '@/mcp-channel';
import { sendToOpenClaw } from '@/lib/api/openclawChannel';
```

- [ ] **Step 2: Add isSending state**

Find the state declarations (around line 80) and add:
```typescript
  const [isSending, setIsSending] = useState(false);
```

- [ ] **Step 3: Create handleSendMessage function**

Add before the `return` statement (around line 280):
```typescript
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

- [ ] **Step 4: Update form onSubmit to use handleSendMessage**

Find the form onSubmit (around line 873):
```typescript
                      onSubmit={(e) => {
                        e.preventDefault();
                        if (inputMessage.trim()) {
                          // 消息功能开发中，显示选择对话框
                          setShowTuiChoice(true);
                          setInputMessage("");
                        }
                      }}
```

Replace with:
```typescript
                      onSubmit={handleSendMessage}
```

- [ ] **Step 5: Update send button to show loading state**

Find the submit button (around line 889):
```typescript
                      <Button type="submit" size="icon" disabled={!inputMessage.trim()}>
                        <Send className="size-4" />
                      </Button>
```

Replace with:
```typescript
                      <Button type="submit" size="icon" disabled={!inputMessage.trim() || isSending}>
                        {isSending ? (
                          <RefreshCw className="size-4 animate-spin" />
                        ) : (
                          <Send className="size-4" />
                        )}
                      </Button>
```

- [ ] **Step 6: Add channel message subscription useEffect**

Add after other useEffect hooks (around line 160):
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

    // OpenClaw polling is handled by onOpenClawMessage, but for now we rely on refetch after send
    // Future: subscribe to SSE or polling when available

  }, [selectedSession, refetch]);
```

- [ ] **Step 7: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add src/components/sessions/SessionManagerPage.tsx
git commit -m "feat: implement real channel sending in sessions view"
```

---

## Task 8: Add data-session-provider attribute to SessionItem

**Files:**
- Modify: `src/components/sessions/SessionItem.tsx`

- [ ] **Step 1: Add data-session-provider attribute to button element**

Find the button element (line 29-38):
```typescript
    <button
      type="button"
      onClick={() => onSelect(sessionKey)}
      className={cn(
```

Replace with:
```typescript
    <button
      type="button"
      onClick={() => onSelect(sessionKey)}
      data-session-provider={session.providerId}
      className={cn(
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/components/sessions/SessionItem.tsx
git commit -m "feat: add data-session-provider for E2E tests"
```

---

## Task 9: Create SessionManagerPage E2E Page Object

**Files:**
- Create: `tests/e2e/tauri/pages/SessionManagerPage.ts`
- Modify: `tests/e2e/tauri/pages/index.ts`

- [ ] **Step 1: Create SessionManagerPage.ts**

```typescript
/**
 * SessionManagerPage - Page object for sessions view in Tauri E2E tests
 */

/// <reference types="@wdio/globals/types" />

import { TauriBasePage } from './TauriBasePage';

export class SessionManagerPage extends TauriBasePage {
  /**
   * Navigate to sessions view
   */
  async navigateToSessions(): Promise<void> {
    await this.waitForReactReady();

    // Click sessions nav button
    const sessionsBtn = await $('button[aria-label*="会话"], [data-testid="sessions"]');
    if (await sessionsBtn.isExisting()) {
      await sessionsBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Select a session by provider ID
   */
  async selectSessionByProvider(providerId: string): Promise<void> {
    await this.waitForReactReady();

    // Find session item with provider data attribute
    const sessionItems = await $$('[data-session-provider]');
    for (const item of sessionItems) {
      const provider = await item.getAttribute('data-session-provider');
      if (provider === providerId) {
        await item.click();
        await browser.pause(300);
        return;
      }
    }

    // Fallback: click first session in list
    const firstSession = await $('.space-y-1 > button:first-child');
    if (await firstSession.isExisting()) {
      await firstSession.click();
      await browser.pause(300);
    }
  }

  /**
   * Input message in the text field
   */
  async inputMessage(text: string): Promise<void> {
    const input = await $('input[placeholder*="消息"], input[placeholder*="message"]');
    await input.waitForExist({ timeout: 5000 });
    await input.clearValue();
    await input.addValue(text);
  }

  /**
   * Click send button
   */
  async clickSend(): Promise<void> {
    const sendBtn = await $('button[type="submit"]');
    await sendBtn.waitForClickable({ timeout: 5000 });
    await sendBtn.click();
  }

  /**
   * Get all visible messages
   */
  async getMessages(): Promise<string[]> {
    const messageElements = await $$('[data-message-role]');
    const messages: string[] = [];
    for (const el of messageElements) {
      const text = await el.getText();
      messages.push(text);
    }
    return messages;
  }

  /**
   * Wait for toast notification and get text
   */
  async getToast(timeout = 5000): Promise<string | null> {
    return this.waitForToast(timeout);
  }

  /**
   * Check if send button is disabled
   */
  async isSendDisabled(): Promise<boolean> {
    const sendBtn = await $('button[type="submit"]');
    return sendBtn.isDisabled();
  }

  /**
   * Wait for message to appear in list
   */
  async waitForMessage(content: string, timeout = 10000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const messages = await this.getMessages();
        return messages.some(m => m.includes(content));
      },
      { timeout, timeoutMsg: `Message "${content}" did not appear` }
    );
  }
}
```

- [ ] **Step 2: Export from index.ts**

Add to `tests/e2e/tauri/pages/index.ts`:
```typescript
export { SessionManagerPage } from './SessionManagerPage';
```

- [ ] **Step 3: Commit**

```bash
git add tests/e2e/tauri/pages/SessionManagerPage.ts tests/e2e/tauri/pages/index.ts
git commit -m "feat: add SessionManagerPage E2E page object"
```

---

## Task 10: Create Channel Communication E2E Tests

**Files:**
- Create: `tests/e2e/tauri/channel-communication.spec.ts`

- [ ] **Step 1: Create test spec file**

```typescript
/**
 * Channel Communication E2E Tests
 *
 * Tests for real message sending through agent-specific channels.
 */

import { expect } from '@wdio/globals';
import { SessionManagerPage } from './pages/SessionManagerPage';

describe('Channel Communication', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
  });

  it('should show "under development" toast for Codex sessions', async () => {
    // 1. Navigate to sessions view
    await sessionPage.navigateToSessions();

    // 2. Wait for sessions to load
    await browser.pause(1000);

    // 3. Try to find and select a Codex session (if exists)
    // If no Codex session, skip test
    const codexSession = await $('[data-session-provider="codex"]');
    if (!(await codexSession.isExisting())) {
      console.log('No Codex session found, skipping test');
      return;
    }

    await codexSession.click();
    await browser.pause(500);

    // 4. Type message and send
    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    // 5. Verify toast shows "开发中" or "development"
    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
    // Accept either Chinese or English
    const hasDevelopmentText =
      toastText?.includes('开发中') ||
      toastText?.includes('development') ||
      toastText?.includes('Codex');
    expect(hasDevelopmentText).toBe(true);
  });

  it('should show "under development" toast for Gemini sessions', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const geminiSession = await $('[data-session-provider="gemini"]');
    if (!(await geminiSession.isExisting())) {
      console.log('No Gemini session found, skipping test');
      return;
    }

    await geminiSession.click();
    await browser.pause(500);

    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
  });

  it('should show "under development" toast for OpenCode sessions', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const opencodeSession = await $('[data-session-provider="opencode"]');
    if (!(await opencodeSession.isExisting())) {
      console.log('No OpenCode session found, skipping test');
      return;
    }

    await opencodeSession.click();
    await browser.pause(500);

    await sessionPage.inputMessage('Test message');
    await sessionPage.clickSend();

    await browser.pause(1000);
    const toastText = await sessionPage.getToast();
    expect(toastText).toBeTruthy();
  });

  // Note: Real Claude/OpenClaw channel tests require actual backend
  // These are skipped by default and can be enabled manually

  it.skip('should send message via Claude Code MCP channel', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const claudeSession = await $('[data-session-provider="claude"]');
    if (!(await claudeSession.isExisting())) {
      console.log('No Claude session found, skipping test');
      return;
    }

    await claudeSession.click();
    await browser.pause(500);

    const testMessage = `E2E test ${Date.now()}`;
    await sessionPage.inputMessage(testMessage);
    await sessionPage.clickSend();

    // Wait for response or message to appear
    await browser.pause(2000);

    // Verify message was sent (check for no error toast)
    const errorToast = await sessionPage.getToast(2000);
    expect(errorToast).toBeNull();
  });

  it.skip('should send message via OpenClaw Gateway', async () => {
    await sessionPage.navigateToSessions();
    await browser.pause(1000);

    const openclawSession = await $('[data-session-provider="openclaw"]');
    if (!(await openclawSession.isExisting())) {
      console.log('No OpenClaw session found, skipping test');
      return;
    }

    await openclawSession.click();
    await browser.pause(500);

    const testMessage = `E2E test ${Date.now()}`;
    await sessionPage.inputMessage(testMessage);
    await sessionPage.clickSend();

    await browser.pause(2000);

    const errorToast = await sessionPage.getToast(2000);
    expect(errorToast).toBeNull();
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add tests/e2e/tauri/channel-communication.spec.ts
git commit -m "test: add channel communication E2E tests"
```

---

## Task 11: Final Verification

- [ ] **Step 1: Run TypeScript check**

Run: `bun run typecheck`
Expected: No errors

- [ ] **Step 2: Run unit tests**

Run: `bun run test:unit`
Expected: All tests pass

- [ ] **Step 3: Run Tauri E2E tests**

Run: `bun run test:e2e:tauri`
Expected: Tests pass (may need to skip Claude/OpenClaw tests if no real sessions)

- [ ] **Step 4: Manual test - unsupported agent toast**

1. Build and run the app: `bun run dev`
2. Navigate to Sessions view
3. Select a Codex/Gemini/OpenCode session
4. Type a message and click send
5. Verify toast shows "正在开发中"

- [ ] **Step 5: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: final cleanup for channel communication"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Delete chat components | `src/components/chat/*` |
| 2 | Remove chat from App.tsx | `src/App.tsx` |
| 3 | Remove chat from nav | `src/components/layout/MainLayout.tsx` |
| 4 | Create OpenClaw channel API | `src/lib/api/openclawChannel.ts` |
| 5 | Add browser mock | `src/lib/browser-mock.ts` |
| 6 | Add i18n keys | `src/i18n/locales/*.json` |
| 7 | Enhance SessionManagerPage | `src/components/sessions/SessionManagerPage.tsx` |
| 8 | Add test data attribute | `src/components/sessions/SessionItem.tsx` |
| 9 | Create E2E page object | `tests/e2e/tauri/pages/SessionManagerPage.ts` |
| 10 | Create E2E tests | `tests/e2e/tauri/channel-communication.spec.ts` |
| 11 | Final verification | - |

## Notes

- **OpenClaw polling TODO**: The `onOpenClawMessage` polling interval is intentionally a placeholder. It will be implemented when OpenClaw Gateway adds SSE or polling endpoint support. For now, messages are refreshed via the `refetch()` call after sending.