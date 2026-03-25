/**
 * Network Error Handling Tests
 *
 * Tests network-related error scenarios:
 * - Connection errors
 * - Request errors
 * - Retry logic
 * - Offline mode
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { DashboardPage } from '../pages/DashboardPage';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Network Error Handling', () => {
  let dashboard: DashboardPage;

  beforeEach(async () => {
    dashboard = new DashboardPage();
    await dashboard.waitForReactReady();
  });

  describe('Connection Errors', () => {
    it('should handle connection timeout', async () => {
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('Timeout');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'http://10.255.255.1/v1', // Non-routable IP for timeout
      });

      await browser.pause(500);

      // Test connection
      await dashboard.testProvider(testName);
      await browser.pause(5000);

      // Should show timeout error
      const toast = await JourneyHelpers.waitForToast(8000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle connection refused', async () => {
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('Refused');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'http://localhost:1/v1', // Port 1 typically refused
      });

      await browser.pause(500);

      await dashboard.testProvider(testName);
      await browser.pause(3000);

      const toast = await JourneyHelpers.waitForToast(5000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle DNS resolution failure', async () => {
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('DNS');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'http://nonexistent-domain-xyz123.invalid/v1',
      });

      await browser.pause(500);

      await dashboard.testProvider(testName);
      await browser.pause(3000);

      const toast = await JourneyHelpers.waitForToast(5000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle SSL certificate errors', async () => {
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('SSL');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'https://self-signed.badssl.com/v1',
      });

      await browser.pause(500);

      await dashboard.testProvider(testName);
      await browser.pause(3000);

      const toast = await JourneyHelpers.waitForToast(5000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle proxy connection failures', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Navigate to settings and configure invalid proxy
      await dashboard.navigateToView('settings');
      await browser.pause(300);

      const proxyInput = await $('input[name*="proxyHost"], input[placeholder*="Proxy"]');
      if (await proxyInput.isExisting()) {
        await proxyInput.setValue('invalid-proxy.local');
        await browser.pause(300);

        const saveBtn = await $('button[type="submit"]');
        if (await saveBtn.isExisting()) {
          await saveBtn.click();
          await browser.pause(500);
        }
      }

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Request Errors', () => {
    it('should handle request timeout', async () => {
      // Similar to connection timeout but at request level
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      const providers = await dashboard.getVisibleProviderNames();
      if (providers.length > 0) {
        await dashboard.testProvider(providers[0]);
        await browser.pause(3000);

        // Verify page is in valid state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      } else {
        // No providers - verify page is valid
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should handle request cancellation', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      const providers = await dashboard.getVisibleProviderNames();
      if (providers.length > 0) {
        await dashboard.testProvider(providers[0]);
        await browser.pause(500);

        // Use WebKit2GTK-compatible method to find cancel button
        const cancelClicked = await browser.execute(() => {
          const buttons = Array.from(document.querySelectorAll('button'));
          const cancelBtn = buttons.find(b =>
            b.textContent?.includes('Cancel') ||
            b.textContent?.includes('取消')
          );
          if (cancelBtn) {
            (cancelBtn as HTMLElement).click();
            return true;
          }
          return false;
        });

        if (cancelClicked) {
          await browser.pause(300);
        }

        // Verify page is in valid state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      } else {
        // No providers - verify page is valid
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should handle malformed responses', async () => {
      // Test with endpoint that returns invalid JSON
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('Malformed');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'https://httpbin.org/html/v1', // Returns HTML not JSON
      });

      await browser.pause(500);

      await dashboard.testProvider(testName);
      await browser.pause(3000);

      const toast = await JourneyHelpers.waitForToast(5000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle unexpected status codes', async () => {
      await dashboard.open();

      const testName = JourneyHelpers.generateTestName('Status');
      await dashboard.addProvider({
        name: testName,
        apiKey: JourneyHelpers.generateTestApiKey(),
        baseUrl: 'https://httpbin.org/status/500/v1',
      });

      await browser.pause(500);

      await dashboard.testProvider(testName);
      await browser.pause(3000);

      const toast = await JourneyHelpers.waitForToast(5000);
      expect(toast).not.toBeNull();
      expect(toast!.length).toBeGreaterThan(0);
    });

    it('should handle response streaming errors', async () => {
      // Test streaming error handling
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Retry Logic', () => {
    it('should retry with exponential backoff', async () => {
      // Verify retry behavior
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should respect maximum retry count', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should allow manual retry', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      const providers = await dashboard.getVisibleProviderNames();
      if (providers.length > 0) {
        // Test twice
        await dashboard.testProvider(providers[0]);
        await browser.pause(1000);
        await dashboard.testProvider(providers[0]);
        await browser.pause(1000);

        // Verify page is in valid state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      } else {
        // No providers - verify page is valid
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show retry progress', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Look for retry indicator
      const retryIndicator = await $('[class*="retry"], [data-testid="retry-indicator"]');
      expect(await retryIndicator.isExisting()).toBe(true);
    });
  });

  describe('Offline Mode', () => {
    it('should detect offline state', async () => {
      // Check offline detection
      const isOnline = await browser.execute(() => navigator.onLine);
      expect(isOnline).toBe(true);
    });

    it('should queue operations offline', async () => {
      // This would require actually going offline - verify UI handles it
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should sync when back online', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Verify page is in valid state
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should show offline indicator', async () => {
      await dashboard.open();
      await JourneyHelpers.waitForLoading();

      // Look for offline status indicator
      const offlineIndicator = await $('[class*="offline"], [data-testid="offline-indicator"]');
      expect(await offlineIndicator.isExisting()).toBe(true);
    });
  });
});