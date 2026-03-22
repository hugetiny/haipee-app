/**
 * SessionManagerPage - Page object for sessions view in Tauri E2E tests
 *
 * Handles:
 * - Session list display and filtering
 * - Session selection and messages
 * - Message input and sending
 * - Channel communication
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
   * Get all session items
   */
  async getSessionItems(): Promise<WebdriverIO.Element[]> {
    const items = await $$('[data-session-id], [data-session-provider]');
    return [...items] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get session count
   */
  async getSessionCount(): Promise<number> {
    const count = await browser.execute(() => {
      return document.querySelectorAll('[data-session-id], [data-session-provider]').length;
    });
    return count;
  }

  /**
   * Check if empty state is shown
   */
  async isEmptyState(): Promise<boolean> {
    const hasEmpty = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('暂无会话') || text.includes('No session') ||
             text.includes('Empty') || text.includes('没有会话');
    });
    return hasEmpty;
  }

  /**
   * Search sessions by query
   */
  async searchSessions(query: string): Promise<void> {
    const searchInput = await $('input[type="search"], input[placeholder*="搜索"], input[placeholder*="Search"]');
    if (await searchInput.isExisting()) {
      await searchInput.clearValue();
      await searchInput.setValue(query);
      await browser.pause(300);
    }
  }

  /**
   * Clear session search
   */
  async clearSearch(): Promise<void> {
    const clearBtn = await $('button[aria-label*="clear"], button[aria-label*="清除"]');
    if (await clearBtn.isExisting()) {
      await clearBtn.click();
      await browser.pause(200);
    }
  }

  /**
   * Filter sessions by provider
   */
  async filterByProvider(provider: string): Promise<void> {
    const filterBtn = await $(`[data-filter-provider="${provider}"], button:has-text("${provider}")`);
    if (await filterBtn.isExisting()) {
      await filterBtn.click();
      await browser.pause(300);
    }
  }

  /**
   * Get session names
   */
  async getSessionNames(): Promise<string[]> {
    const names = await browser.execute(() => {
      const items = document.querySelectorAll('[data-session-id] [class*="name"], [data-session-provider] [class*="name"]');
      return Array.from(items).map(el => el.textContent?.trim() || '');
    });
    return names.filter(n => n);
  }

  /**
   * Select session by name
   */
  async selectSessionByName(name: string): Promise<boolean> {
    const items = await this.getSessionItems();
    for (const item of items) {
      const text = await item.getText();
      if (text.includes(name)) {
        await item.click();
        await browser.pause(300);
        return true;
      }
    }
    return false;
  }

  /**
   * Input message in the text field
   */
  async inputMessage(text: string): Promise<void> {
    const input = await $('input[placeholder*="消息"], input[placeholder*="message"], textarea[placeholder*="消息"], [data-testid="message-input"]');
    await input.waitForExist({ timeout: 5000 });
    await input.clearValue();
    await input.addValue(text);
  }

  /**
   * Click send button
   */
  async clickSend(): Promise<void> {
    const sendBtn = await $('button[type="submit"], button:has-text("发送"), button:has-text("Send")');
    await sendBtn.waitForClickable({ timeout: 5000 });
    await sendBtn.click();
  }

  /**
   * Send a message
   */
  async sendMessage(text: string): Promise<void> {
    await this.inputMessage(text);
    await this.clickSend();
    await browser.pause(500);
  }

  /**
   * Get all visible messages
   */
  async getMessages(): Promise<string[]> {
    const messageElements = await $$('[data-message-role], [class*="message"]');
    const messages: string[] = [];
    for (const el of messageElements) {
      const text = await el.getText();
      messages.push(text);
    }
    return messages;
  }

  /**
   * Get message count
   */
  async getMessageCount(): Promise<number> {
    const count = await browser.execute(() => {
      return document.querySelectorAll('[data-message-role], [class*="message"]').length;
    });
    return count;
  }

  /**
   * Check if message input exists
   */
  async hasMessageInput(): Promise<boolean> {
    const input = await $('input[placeholder*="消息"], input[placeholder*="message"], textarea');
    return input.isExisting();
  }

  /**
   * Check if send button exists
   */
  async hasSendButton(): Promise<boolean> {
    const btn = await $('button[type="submit"], button:has-text("发送"), button:has-text("Send")');
    return btn.isExisting();
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
    const disabledAttr = await sendBtn.getAttribute('disabled');
    return disabledAttr !== null;
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

  /**
   * Create new session
   */
  async createNewSession(): Promise<void> {
    const newBtn = await $('button:has-text("新建"), button:has-text("New"), button[aria-label*="new"]');
    if (await newBtn.isExisting()) {
      await newBtn.click();
      await browser.pause(300);
    }
  }

  /**
   * Delete session by name
   */
  async deleteSession(name: string): Promise<boolean> {
    const items = await this.getSessionItems();
    for (const item of items) {
      const text = await item.getText();
      if (text.includes(name)) {
        // Look for delete button
        const deleteBtn = await item.$('button[aria-label*="删除"], button[aria-label*="Delete"]');
        if (await deleteBtn.isExisting()) {
          await deleteBtn.click();
          await browser.pause(300);

          // Confirm deletion
          const confirmBtn = await $('button:has-text("确认"), button:has-text("Confirm")');
          if (await confirmBtn.isExisting()) {
            await confirmBtn.click();
            await browser.pause(500);
          }
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Get current session name
   */
  async getCurrentSessionName(): Promise<string | null> {
    const name = await browser.execute(() => {
      const active = document.querySelector('[data-active="true"], [class*="active"]');
      if (active) {
        const nameEl = active.querySelector('[class*="name"]');
        return nameEl?.textContent?.trim() || null;
      }
      return null;
    });
    return name;
  }

  /**
   * Check connection status for channel
   */
  async getConnectionStatus(): Promise<string | null> {
    const status = await browser.execute(() => {
      const statusEl = document.querySelector('[data-testid="connection-status"], [class*="connection-status"]');
      return statusEl?.textContent?.trim() || null;
    });
    return status;
  }

  /**
   * Check if channel is connected
   */
  async isChannelConnected(): Promise<boolean> {
    const status = await this.getConnectionStatus();
    if (status) {
      return status.toLowerCase().includes('connect') && !status.toLowerCase().includes('disconnect');
    }
    return false;
  }

  /**
   * Stop generation (for streaming responses)
   */
  async stopGeneration(): Promise<void> {
    const stopBtn = await $('button:has-text("停止"), button:has-text("Stop"), button[aria-label*="stop"]');
    if (await stopBtn.isExisting()) {
      await stopBtn.click();
      await browser.pause(300);
    }
  }

  /**
   * Check if generation is in progress
   */
  async isGenerating(): Promise<boolean> {
    const hasSpinner = await browser.execute(() => {
      return document.querySelector('[class*="animate-spin"], [class*="loading"]') !== null;
    });
    return hasSpinner;
  }

  /**
   * Get channel type for current session
   */
  async getChannelType(): Promise<string | null> {
    const type = await browser.execute(() => {
      // Check for channel type indicator
      const indicator = document.querySelector('[data-channel-type], [class*="channel-type"]');
      if (indicator) {
        return indicator.getAttribute('data-channel-type') || indicator.textContent?.trim() || null;
      }

      // Infer from session provider
      const session = document.querySelector('[data-session-provider][data-active="true"]');
      if (session) {
        return session.getAttribute('data-session-provider');
      }

      return null;
    });
    return type;
  }
}