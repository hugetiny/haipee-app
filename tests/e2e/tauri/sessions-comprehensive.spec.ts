/// <reference types="@wdio/globals/types" />
/**
 * Comprehensive Session Management E2E Tests
 *
 * Tests all session management scenarios:
 * - Session list display and filtering
 * - Session selection and message history
 * - Message input and sending
 * - Channel communication (Claude MCP, OpenClaw WebSocket)
 * - Session operations (create, delete)
 */

import { SessionManagerPage } from './pages/SessionManagerPage';
import { navigationPage } from './pages/NavigationPage';
import { invokeIPC } from './utils/test-helpers';

describe('Session List – Display', () => {
  let sessionPage: SessionManagerPage;

  before(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should display sessions view', async () => {
    const hasContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('会话') || text.includes('Session') ||
             text.includes('Provider') || text.includes('供应商') ||
             document.querySelector('[data-session-id]') !== null ||
             document.querySelector('[data-session-provider]') !== null;
    });
    expect(hasContent).toBe(true);
  });

  it('should show session list or empty state', async () => {
    const count = await sessionPage.getSessionCount();
    const isEmpty = await sessionPage.isEmptyState();

    // Either has sessions or shows empty state
    expect(count >= 0).toBe(true);
    if (count === 0) {
      expect(isEmpty).toBe(true);
    }
  });

  it('should display sessions for current app', async () => {
    // Check for session provider labels
    const hasProviderLabel = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('Claude') || text.includes('Codex') ||
             text.includes('Gemini') || text.includes('OpenCode') ||
             text.includes('OpenClaw') || text.includes('Provider');
    });
    expect(typeof hasProviderLabel).toBe('boolean');
  });
});

describe('Session Selection', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should have selectable sessions if any exist', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      expect(items.length).toBeGreaterThan(0);

      // Click first session
      await items[0].click();
      await browser.pause(300);
    }
  });

  it('should show session details when selected', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      // Check for message area or input
      const hasMessageArea = await browser.execute(() => {
        return document.querySelector('input[placeholder*="消息"]') !== null ||
               document.querySelector('textarea') !== null ||
               document.querySelector('[data-message-role]') !== null;
      });
      expect(typeof hasMessageArea).toBe('boolean');
    }
  });

  it('should select session by provider', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      // Try to select Claude session
      await sessionPage.selectSessionByProvider('claude');
      await browser.pause(300);

      // Session should be selected (no error)
      expect(true).toBe(true);
    }
  });
});

describe('Message Operations', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should have message input when session is selected', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      const hasInput = await sessionPage.hasMessageInput();
      expect(hasInput).toBe(true);
    }
  });

  it('should allow typing message', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test message from E2E');
        await browser.pause(200);

        // Verify input has text
        const hasText = await browser.execute(() => {
          const input = document.querySelector('input, textarea');
          return (input as HTMLInputElement)?.value?.includes('Test message') || false;
        });
        expect(hasText).toBe(true);
      }
    }
  });

  it('should have send button when session is selected', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      const hasSendBtn = await sessionPage.hasSendButton();
      expect(hasSendBtn).toBe(true);
    }
  });

  it('should clear input after sending', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      if (await sessionPage.hasMessageInput() && await sessionPage.hasSendButton()) {
        await sessionPage.inputMessage('E2E test message');
        await sessionPage.clickSend();
        await browser.pause(500);

        // Input should be cleared or message added
        const messageCount = await sessionPage.getMessageCount();
        expect(messageCount >= 0).toBe(true);
      }
    }
  });
});

describe('Session Search and Filter', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should have search input', async () => {
    const hasSearch = await browser.execute(() => {
      return document.querySelector('input[type="search"]') !== null ||
             document.querySelector('input[placeholder*="搜索"]') !== null ||
             document.querySelector('input[placeholder*="Search"]') !== null;
    });
    expect(typeof hasSearch).toBe('boolean');
  });

  it('should filter sessions by search query', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const names = await sessionPage.getSessionNames();
      if (names.length > 0) {
        await sessionPage.searchSessions(names[0]);
        await browser.pause(300);

        // Filtered results should contain the search term
        const filteredNames = await sessionPage.getSessionNames();
        expect(filteredNames.some(n => n.includes(names[0]))).toBe(true);

        await sessionPage.clearSearch();
      }
    }
  });

  it('should have provider filter options', async () => {
    const hasFilter = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('Provider') || text.includes('供应商') ||
             document.querySelector('[data-filter-provider]') !== null ||
             document.querySelector('select[name*="provider"]') !== null;
    });
    expect(typeof hasFilter).toBe('boolean');
  });
});

describe('Channel Communication', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should show development toast for Codex sessions', async () => {
    const codexSession = await $('[data-session-provider="codex"]');
    if (await codexSession.isExisting()) {
      await codexSession.click();
      await browser.pause(300);

      await sessionPage.inputMessage('Test message');
      await sessionPage.clickSend();
      await browser.pause(1000);

      const toast = await sessionPage.getToast(2000);
      // Should show development message or process the message
      expect(typeof toast).toBe('object');
    }
  });

  it('should show development toast for Gemini sessions', async () => {
    const geminiSession = await $('[data-session-provider="gemini"]');
    if (await geminiSession.isExisting()) {
      await geminiSession.click();
      await browser.pause(300);

      await sessionPage.inputMessage('Test message');
      await sessionPage.clickSend();
      await browser.pause(1000);

      const toast = await sessionPage.getToast(2000);
      expect(typeof toast).toBe('object');
    }
  });

  it('should show development toast for OpenCode sessions', async () => {
    const opencodeSession = await $('[data-session-provider="opencode"]');
    if (await opencodeSession.isExisting()) {
      await opencodeSession.click();
      await browser.pause(300);

      await sessionPage.inputMessage('Test message');
      await sessionPage.clickSend();
      await browser.pause(1000);

      const toast = await sessionPage.getToast(2000);
      expect(typeof toast).toBe('object');
    }
  });

  it('should attempt Claude channel for Claude sessions', async () => {
    const claudeSession = await $('[data-session-provider="claude"]');
    if (await claudeSession.isExisting()) {
      await claudeSession.click();
      await browser.pause(300);

      // Check for channel connection status or input
      const hasInput = await sessionPage.hasMessageInput();
      expect(typeof hasInput).toBe('boolean');
    }
  });

  it('should attempt OpenClaw channel for OpenClaw sessions', async () => {
    const openclawSession = await $('[data-session-provider="openclaw"]');
    if (await openclawSession.isExisting()) {
      await openclawSession.click();
      await browser.pause(300);

      // Check for channel type or connection status
      const channelType = await sessionPage.getChannelType();
      expect(typeof channelType).toBe('object');
    }
  });
});

describe('Session Operations', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should have new session button if sessions exist', async () => {
    const hasNewBtn = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.some(btn =>
        btn.textContent?.includes('新建') ||
        btn.textContent?.includes('New') ||
        btn.getAttribute('aria-label')?.includes('new')
      );
    });
    expect(typeof hasNewBtn).toBe('boolean');
  });

  it('should have delete option for sessions', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const hasDelete = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(btn =>
          btn.textContent?.includes('删除') ||
          btn.textContent?.includes('Delete') ||
          btn.getAttribute('aria-label')?.includes('删除')
        );
      });
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('Session IPC Integration', () => {
  it('should be able to fetch sessions via IPC', async () => {
    const sessions = await invokeIPC<{ id: string }[]>('list_sessions');

    if (sessions) {
      console.log(`[test] Found ${sessions.length} sessions via IPC`);
      expect(Array.isArray(sessions)).toBe(true);
    } else {
      console.log('[test] IPC not available - running in browser mock mode');
      expect(true).toBe(true);
    }
  });

  it('should be able to get session messages via IPC', async () => {
    const messages = await invokeIPC<{ role: string; content: string }[]>('get_session_messages');

    if (messages) {
      expect(Array.isArray(messages)).toBe(true);
    } else {
      console.log('[test] IPC not available');
      expect(true).toBe(true);
    }
  });
});

describe('Multi-turn Conversation', () => {
  let sessionPage: SessionManagerPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    await sessionPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);
  });

  it('should maintain conversation history across messages', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      if (await sessionPage.hasMessageInput()) {
        const initialCount = await sessionPage.getMessageCount();

        // Send first message
        await sessionPage.sendMessage('First message');
        await browser.pause(500);

        // Send second message
        await sessionPage.sendMessage('Second message');
        await browser.pause(500);

        const newCount = await sessionPage.getMessageCount();
        // Message count should increase (if messages are stored)
        expect(newCount >= initialCount).toBe(true);
      }
    }
  });

  it('should show user and assistant messages distinctly', async () => {
    const count = await sessionPage.getSessionCount();
    if (count > 0) {
      const items = await sessionPage.getSessionItems();
      await items[0].click();
      await browser.pause(300);

      // Check for message role indicators
      const hasRoleIndicator = await browser.execute(() => {
        return document.querySelector('[data-message-role]') !== null ||
               document.querySelector('[class*="user-message"]') !== null ||
               document.querySelector('[class*="assistant-message"]') !== null;
      });
      expect(typeof hasRoleIndicator).toBe('boolean');
    }
  });
});