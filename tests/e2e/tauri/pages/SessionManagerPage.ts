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
}