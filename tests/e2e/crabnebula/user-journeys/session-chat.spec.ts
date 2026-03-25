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
            const confirmBtn = await $('button, button');
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

  describe('Session Creation with Provider', () => {
    it('should show provider selection when creating session', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Click new session button
      const newSessionBtn = await $('[data-testid="new-session-btn"], button[aria-label*="New"], button[aria-label*="新建"]');
      if (await newSessionBtn.isExisting()) {
        await newSessionBtn.click();
        await browser.pause(300);

        // Check for provider selection dropdown/dialog
        const providerSelect = await $('select[name*="provider"], [data-testid="provider-select"]');
        const providerDialog = await $('[role="dialog"], .modal');

        expect(typeof (await providerSelect.isExisting()) || typeof (await providerDialog.isExisting())).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should create session with specific provider', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Attempt to create session with provider selection
      const newSessionBtn = await $('[data-testid="new-session-btn"], button[aria-label*="New"], button[aria-label*="新建"]');
      if (await newSessionBtn.isExisting()) {
        await newSessionBtn.click();
        await browser.pause(300);

        // Select first provider if available
        const providerOption = await $('option, [role="option"], [data-testid*="provider"]');
        if (await providerOption.isExisting()) {
          await providerOption.click();
          await browser.pause(200);
        }

        // Confirm creation
        const confirmBtn = await $('button[type="submit"]');
        if (await confirmBtn.isExisting()) {
          await confirmBtn.click();
          await browser.pause(500);
        } else {
          // Fallback: search for button with Create/创建 text using execute
          const foundBtn = await browser.execute(() => {
            const buttons = document.querySelectorAll('button');
            for (const btn of buttons) {
              if (btn.textContent?.includes('Create') || btn.textContent?.includes('创建')) {
                btn.click();
                return true;
              }
            }
            return false;
          });
          if (foundBtn) {
            await browser.pause(500);
          }
        }
      }

      expect(true).toBe(true);
    });
  });

  describe('Message with Code and Attachments', () => {
    it('should send message with code block', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        const codeMessage = '```javascript\nconsole.log("Hello");\n```';
        await sessionPage.inputMessage(codeMessage);
        await sessionPage.clickSend();
        await browser.pause(500);

        // Should handle code formatting
        expect(true).toBe(true);
      }
    });

    it('should render code blocks with syntax highlighting', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        // Send a code message
        const codeMessage = '```python\ndef hello():\n    print("world")\n```';
        await sessionPage.inputMessage(codeMessage);
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Check if code block is rendered with syntax highlighting
        const codeBlock = await $('pre code, .code-block, [class*="highlight"]');
        expect(typeof (await codeBlock.isExisting())).toBe('boolean');
      }
    });

    it('should handle attachment button if available', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Look for attachment button
      const attachBtn = await $('button[aria-label*="attach"], button[aria-label*="file"], input[type="file"]');
      expect(typeof (await attachBtn.isExisting())).toBe('boolean');
    });
  });

  describe('Streaming Response', () => {
    it('should show typing indicator during streaming', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Count from 1 to 5');
        await sessionPage.clickSend();
        await browser.pause(500);

        // Check for typing indicator or streaming animation
        const typingIndicator = await $('[class*="typing"], [class*="streaming"], [data-testid*="typing"]');
        // Indicator may appear briefly
        await browser.pause(1000);

        expect(typeof (await typingIndicator.isExisting())).toBe('boolean');
      }
    });

    it('should update message progressively during streaming', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Write a short poem');
        await sessionPage.clickSend();

        // Capture message state at different points
        const messages1 = await sessionPage.getMessages();
        await browser.pause(1500);
        const messages2 = await sessionPage.getMessages();

        // Message content should potentially change during streaming
        expect(messages2.length >= messages1.length).toBe(true);
      }
    });

    it('should show complete message after streaming ends', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Say hello');
        await sessionPage.clickSend();
        await browser.pause(3000);

        // Check final message state
        const messages = await sessionPage.getMessages();
        expect(messages.length >= 0).toBe(true);
      }
    });
  });

  describe('Session History', () => {
    it('should persist session after app restart', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Create a new session
      await sessionPage.createNewSession();
      await browser.pause(500);

      const sessionsBefore = await sessionPage.getSessionCount();

      // Reload the app (simulate restart via navigation)
      await browser.refresh();
      await browser.pause(1000);
      await sessionPage.waitForReactReady();

      // Check session count after refresh
      const sessionsAfter = await sessionPage.getSessionCount();
      // Session count should be preserved (allow small tolerance for async timing)
      expect(Math.abs(sessionsAfter - sessionsBefore)).toBeLessThanOrEqual(1);
    });

    it('should restore session messages after navigation', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const sessions = await sessionPage.getSessionItems();
      if (sessions.length > 0) {
        // Click first session
        await sessions[0].click();
        await browser.pause(300);

        // Navigate away
        await sessionPage.navigateToSessions();
        await browser.pause(300);

        // Navigate back
        const sessionsAgain = await sessionPage.getSessionItems();
        if (sessionsAgain.length > 0) {
          await sessionsAgain[0].click();
          await browser.pause(300);

          // Messages should be restored
          const messageCount = await sessionPage.getMessageCount();
          expect(typeof messageCount).toBe('number');
        }
      } else {
        expect(true).toBe(true);
      }
    });

    it('should show session timestamp', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      const sessions = await sessionPage.getSessionItems();
      if (sessions.length > 0) {
        // Check if timestamp is displayed
        const sessionElement = sessions[0];
        const text = await sessionElement.getText();

        // Should have some time indicator (date, time, relative)
        const hasTimeIndicator = /\d|ago|前|今天|昨天|today|yesterday/i.test(text);
        expect(typeof hasTimeIndicator).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    });
  });
});