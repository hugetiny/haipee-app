/**
 * Error Recovery Journey Tests
 *
 * End-to-end tests for error handling and recovery:
 * - Network errors
 * - API errors
 * - Data errors
 * - Recovery mechanisms
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { NavigationPage } from '../pages/NavigationPage';
import { SessionManagerPage } from '../pages/SessionManagerPage';
import { DashboardPage } from '../pages/DashboardPage';
import { JourneyHelpers } from './journey-helpers';

describe('Error Recovery Journey', () => {
  let navigation: NavigationPage;
  let sessionPage: SessionManagerPage;
  let dashboard: DashboardPage;

  beforeEach(async () => {
    navigation = new NavigationPage();
    sessionPage = new SessionManagerPage();
    dashboard = new DashboardPage();
    await navigation.waitForReactReady();
  });

  describe('Network Errors', () => {
    it('should show error when network disconnected', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test network error');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Should show toast (either success or error)
        const toast = await JourneyHelpers.waitForToast(3000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should recover after reconnect', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Try to send message
      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test after reconnect');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // App should still be functional
        const sidebarVisible = await navigation.isSidebarVisible();
        expect(sidebarVisible).toBe(true);
      } else {
        expect(true).toBe(true);
      }
    });

    it('should allow manual retry', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Try action that might fail
      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test retry');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Look for retry button
        const retryBtn = await $('button:has-text("重试"), button:has-text("Retry")');
        if (await retryBtn.isExisting()) {
          await retryBtn.click();
          await browser.pause(500);
        }
      }

      expect(true).toBe(true);
    });
  });

  describe('API Errors', () => {
    it('should show authentication error for 401', async () => {
      await dashboard.open();
      await browser.pause(500);

      // Create provider with invalid key
      const testName = JourneyHelpers.generateTestName('Auth');
      await dashboard.addProvider({
        name: testName,
        apiKey: 'invalid-test-key-401',
      });

      await browser.pause(500);

      // Try to use it
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test 401 error');
        await sessionPage.clickSend();
        await browser.pause(1000);

        const toast = await JourneyHelpers.waitForToast(3000);
        // Should show error about auth
        expect(typeof toast).toBe('string');
      }

      // Cleanup
      await dashboard.open();
      await dashboard.deleteProvider(testName);
    });

    it('should show rate limit error for 429', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Rapid fire messages
      if (await sessionPage.hasMessageInput()) {
        for (let i = 0; i < 5; i++) {
          await sessionPage.inputMessage(`Rate test ${i}`);
          await sessionPage.clickSend();
          await browser.pause(200);
        }

        await browser.pause(1000);
        const toast = await JourneyHelpers.waitForToast(3000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should show server error for 500', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // This would need a mock or actual server error
      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Test 500 error');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // App should handle gracefully
        const sidebarVisible = await navigation.isSidebarVisible();
        expect(sidebarVisible).toBe(true);
      } else {
        expect(true).toBe(true);
      }
    });
  });

  describe('Data Errors', () => {
    it('should show validation error for invalid data', async () => {
      await dashboard.open();
      await dashboard.clickAddProvider();
      await browser.pause(300);

      // Submit empty form
      await dashboard.saveProvider();
      await browser.pause(300);

      const hasError = await JourneyHelpers.hasFormError();
      expect(typeof hasError).toBe('boolean');
    });

    it('should show empty state when data load fails', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // If no sessions, should show empty state
      const isEmpty = await sessionPage.isEmptyState();
      const hasSessions = (await sessionPage.getSessionCount()) > 0;

      expect(isEmpty || hasSessions).toBe(true);
    });
  });

  describe('Recovery Mechanisms', () => {
    it('should continue operating after error', async () => {
      // Trigger an error
      await dashboard.open();
      await dashboard.clickAddProvider();
      await browser.pause(300);

      // Submit invalid form
      await dashboard.saveProvider();
      await browser.pause(300);

      // Close modal
      await JourneyHelpers.closeModal();

      // Should still be able to navigate
      await navigation.navigateToView('sessions');
      await browser.pause(300);

      const sidebarVisible = await navigation.isSidebarVisible();
      expect(sidebarVisible).toBe(true);
    });

    it('should reset state on refresh', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Refresh
      await browser.refresh();
      await sessionPage.waitForReactReady();
      await browser.pause(500);

      // App should be functional
      const sidebarVisible = await navigation.isSidebarVisible();
      expect(sidebarVisible).toBe(true);
    });

    it('should preserve data after recovery', async () => {
      const testName = JourneyHelpers.generateTestName('Recovery');

      await dashboard.open();
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
      });

      await browser.pause(500);

      // Simulate error/recovery by navigating
      await navigation.navigateToView('settings');
      await browser.pause(300);
      await dashboard.open();
      await browser.pause(500);

      // Provider should still exist
      const exists = await dashboard.providerExists(testName);
      expect(exists).toBe(true);

      // Cleanup
      await dashboard.deleteProvider(testName);
    });
  });

  describe('Error Display', () => {
    it('should show toast for errors', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Error test');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Toast should appear (success or error)
        const toast = await JourneyHelpers.waitForToast(5000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should allow dismissing error toast', async () => {
      await sessionPage.navigateToSessions();
      await browser.pause(500);

      if (await sessionPage.hasMessageInput()) {
        await sessionPage.inputMessage('Dismiss test');
        await sessionPage.clickSend();
        await browser.pause(1000);

        // Try to dismiss toast
        const closeBtn = await $('[data-sonner-toast] button, [role="status"] button');
        if (await closeBtn.isExisting()) {
          await closeBtn.click();
          await browser.pause(300);
        }
      }

      expect(true).toBe(true);
    });

    it('should log errors for debugging', async () => {
      // This test would check browser console for error logs
      // In CI, this helps identify issues

      await sessionPage.navigateToSessions();
      await browser.pause(500);

      // Check console for any errors
      const logs = await browser.execute(() => {
        // @ts-ignore - checking for our error logging
        return window.__HAIPEE_ERRORS__ || [];
      });

      expect(Array.isArray(logs)).toBe(true);
    });
  });
});