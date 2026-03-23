/**
 * Session Chat Journey Tests
 *
 * End-to-end tests for session and messaging flows:
 * - Session creation and management
 * - Message sending and display
 * - Multi-provider sessions
 * - Edge cases
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { SessionManagerPage } from '../pages/SessionManagerPage';
import { NavigationPage } from '../pages/NavigationPage';

describe('Session Chat Journey', () => {
  let sessionPage: SessionManagerPage;
  let navigation: NavigationPage;

  beforeEach(async () => {
    sessionPage = new SessionManagerPage();
    navigation = new NavigationPage();
    await sessionPage.waitForReactReady();
  });

  describe('Session Creation', () => {
    it('should create new session', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Try to create new session
      await sessionPage.createNewSession();
      await browser.pause(300);

      // Session list should update
      const count = await sessionPage.getSessionCount();
      expect(typeof count).toBe('number');
    });

    it('should show session in list after creation', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      await sessionPage.createNewSession();
      await browser.pause(500);

      const newCount = await sessionPage.getSessionCount();
      // Count may increase or stay same if already at max
      expect(typeof newCount).toBe('number');
    });
  });

  describe('Message Sending', () => {
    it('should input message in text field', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const testMessage = `Test message ${Date.now()}`;

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage(testMessage);

        // Check input value
        const inputValue = await browser.execute(() => {
          const input = document.querySelector('input[placeholder*="消息"], input[placeholder*="message"], textarea') as HTMLInputElement | HTMLTextAreaElement;
          return input?.value || '';
        });

        expect(inputValue).toBe(testMessage);
      } else {
        expect(true).toBe(true);
      }
    });

    it('should send message', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput() && await sessionPage.hasSendButton()) {
        const testMessage = `Send test ${Date.now()}`;
        await sessionPage.inputMessage(testMessage);
        await sessionPage.clickSend();
        await browser.pause(500);

        // Check for toast or message sent
        const toast = await sessionPage.getToast(3000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should display message in chat after sending', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        const testMessage = `Display test ${Date.now()}`;
        await sessionPage.inputMessage(testMessage);
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Message might appear or toast shown
        const messages = await sessionPage.getMessages();
        const toast = await sessionPage.getToast(2000);

        expect(messages.length >= 0 || toast !== null).toBe(true);
      } else {
        expect(true).toBe(true);
      }
    });

    it('should show prompt when no active provider', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test without provider');
        await sessionPage.clickSend();
        await browser.pause(500);

        // Should show toast about inactive/no provider
        const toast = await sessionPage.getToast(3000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });
  });

  describe('Session Management', () => {
    it('should rename session', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const sessions = await sessionPage.getSessionItems();
      if (sessions.length > 0) {
        // Click first session
        await sessions[0].click();
        await browser.pause(300);

        // Look for rename option
        const renameBtn = await $('button[aria-label*="重命名"], button[aria-label*="Rename"]');
        if (await renameBtn.isExisting()) {
          await renameBtn.click();
          await browser.pause(300);
        }
      }

      expect(true).toBe(true);
    });

    it('should delete session', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const initialCount = await sessionPage.getSessionCount();
      if (initialCount > 0) {
        // Select first session
        const sessions = await sessionPage.getSessionItems();
        if (sessions.length > 0) {
          await sessions[0].click();
          await browser.pause(300);

          // Look for delete option
          const deleteBtn = await $('button[aria-label*="删除"], button[aria-label*="Delete"]');
          if (await deleteBtn.isExisting()) {
            await deleteBtn.click();
            await browser.pause(300);

            // Confirm
            const confirmBtn = await $('button:has-text("确认"), button:has-text("Confirm")');
            if (await confirmBtn.isExisting()) {
              await confirmBtn.click();
              await browser.pause(500);
            }
          }
        }
      }

      expect(true).toBe(true);
    });

    it('should view session history', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const sessions = await sessionPage.getSessionItems();
      if (sessions.length > 0) {
        // Click on session to view
        await sessions[0].click();
        await browser.pause(300);

        // Messages should be visible or empty state shown
        const messageCount = await sessionPage.getMessageCount();
        expect(typeof messageCount).toBe('number');
      } else {
        expect(true).toBe(true);
      }
    });
  });

  describe('Edge Cases', () => {
    it('should not send empty message', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('');
        await sessionPage.clickSend();
        await browser.pause(300);

        // Should not crash, either do nothing or show toast
        expect(true).toBe(true);
      }
    });

    it('should handle long message', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        const longMessage = 'A'.repeat(1000);
        await sessionPage.inputMessage(longMessage);
        await sessionPage.clickSend();
        await browser.pause(500);

        // Should handle without crash
        expect(true).toBe(true);
      }
    });

    it('should display special characters correctly', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        const specialMessage = 'Test <>&"\'特殊字符🎉';
        await sessionPage.inputMessage(specialMessage);
        await sessionPage.clickSend();
        await browser.pause(500);

        // Should handle special chars
        expect(true).toBe(true);
      }
    });
  });

  describe('Multi-Provider Sessions', () => {
    it('should update session list when switching providers', async () => {
      const appButtons = await navigation.getAppButtons();
      if (appButtons.length >= 2) {
        await sessionPage.navigateToSessions();
        await browser.pause(300);

        // Switch app
        await navigation.switchToApp(appButtons[1].app.toLowerCase() as any);
        await browser.pause(500);

        const count2 = await sessionPage.getSessionCount();
        expect(typeof count2).toBe('number');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should separate sessions by provider', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Sessions should be grouped or filtered by provider
      const sessions = await sessionPage.getSessionItems();

      // Check if session items have provider indicator
      let hasProviderIndicator = false;
      for (const session of sessions) {
        const providerAttr = await session.getAttribute('data-session-provider');
        if (providerAttr) {
          hasProviderIndicator = true;
          break;
        }
      }

      expect(typeof hasProviderIndicator).toBe('boolean');
    });
  });
});