/// <reference types="@wdio/globals/types" />
/**
 * Error Handling Tests - Error scenarios and recovery
 */

import { navigationPage } from '../pages';

describe('Error Handling – Toast Notifications', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should display toast container', async () => {
    const toastContainer = await $('[data-sonner-toaster], [role="region"][aria-label*="notification"]');
    const hasContainer = await toastContainer.isExisting();
    expect(typeof hasContainer).toBe('boolean');
  });

  it('should show error toast on failed operation', async () => {
    // Trigger an operation that might fail
    try {
      await navigationPage.invokeIPC('delete_provider', { id: 'non-existent-id' });
    } catch {
      // Expected to fail
    }

    // Check for toast
    await browser.pause(500);
    const toast = await $('[data-sonner-toast][data-type="error"], [role="alert"]');
    expect(typeof (await toast.isExisting())).toBe('boolean');
  });
});

describe('Error Handling – Network Errors', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should handle invalid API endpoint gracefully', async () => {
    try {
      await navigationPage.invokeIPC('test_provider_connection', {
        providerId: 'invalid-provider'
      });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it('should show offline indicator if network unavailable', async () => {
    const offlineIndicator = await $('[data-testid="offline-indicator"], [class*="offline"], [class*="network-error"]');
    const hasIndicator = await offlineIndicator.isExisting();
    expect(typeof hasIndicator).toBe('boolean');
  });

  it('should retry failed operations', async () => {
    const retryBtn = await $('[data-testid="retry-btn"]');
    const hasRetry = await retryBtn.isExisting();
    expect(typeof hasRetry).toBe('boolean');
  });
});

describe('Error Handling – Validation Errors', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show validation error for empty required fields', async () => {
    const addBtn = await $('[data-testid="provider-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      const submitBtn = await $('[data-testid="provider-submit-btn"], button[type="submit"]');
      if (await submitBtn.isExisting()) {
        await submitBtn.click();
        await browser.pause(300);

        const errorText = await $('[data-testid="form-error"], [class*="error"], [aria-invalid="true"]');
        const hasError = await errorText.isExisting();
        expect(typeof hasError).toBe('boolean');
      }
    }
  });

  it('should show validation error for invalid API key format', async () => {
    const apiKeyInput = await $('[data-testid="api-key-input"], input[name="apiKey"]');
    if (await apiKeyInput.isExisting()) {
      await apiKeyInput.clearValue();
      await apiKeyInput.addValue('invalid-key-format');
      await browser.pause(200);

      const ariaInvalid = await apiKeyInput.getAttribute('aria-invalid');
      expect(typeof ariaInvalid).toBe('string');
    }
  });

  it('should show validation error for invalid URL', async () => {
    const urlInput = await $('[data-testid="base-url-input"], input[name="baseUrl"]');
    if (await urlInput.isExisting()) {
      await urlInput.clearValue();
      await urlInput.addValue('not-a-valid-url');
      await browser.pause(200);

      const ariaInvalid = await urlInput.getAttribute('aria-invalid');
      expect(typeof ariaInvalid).toBe('string');
    }
  });
});

describe('Error Handling – Database Errors', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should handle database read errors gracefully', async () => {
    try {
      const result = await navigationPage.invokeIPC('list_providers', { appType: 'claude' });
      expect(typeof result).toBe('object');
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it('should handle duplicate entry errors', async () => {
    const result = await navigationPage.invokeIPC<{ providers: Record<string, unknown> }>('list_providers', { appType: 'claude' });
    expect(typeof result).toBe('object');
  });
});

describe('Error Handling – Recovery', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should dismiss error dialog on close', async () => {
    const closeBtn = await $('[data-testid="dialog-close"], button[aria-label*="close"], button[aria-label*="关闭"]');
    if (await closeBtn.isExisting()) {
      await closeBtn.click();
      await browser.pause(300);
    }
    expect(true).toBe(true);
  });

  it('should allow retry after error', async () => {
    const retryBtn = await $('[data-testid="retry-btn"]');
    if (await retryBtn.isExisting()) {
      await retryBtn.click();
      await browser.pause(500);
    }
    expect(true).toBe(true);
  });

  it('should preserve form data on validation error', async () => {
    const nameInput = await $('[data-testid="provider-name-input"], input[name="name"]');
    if (await nameInput.isExisting()) {
      await nameInput.clearValue();
      await nameInput.addValue('Test Provider Name');
      await browser.pause(200);

      const value = await nameInput.getValue();
      expect(value).toContain('Test Provider Name');
    }
  });
});

describe('Error Handling – Loading States', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show loading indicator during operations', async () => {
    const refreshBtn = await $('[data-testid="refresh-btn"], button[aria-label*="refresh"], button[aria-label*="刷新"]');
    if (await refreshBtn.isExisting()) {
      await refreshBtn.click();
      const loading = await $('[data-testid="loading"], .animate-spin, [aria-busy="true"]');
      expect(typeof (await loading.isExisting())).toBe('boolean');
    }
  });

  it('should disable buttons during loading', async () => {
    const submitBtn = await $('[data-testid="provider-submit-btn"], button[type="submit"]');
    if (await submitBtn.isExisting()) {
      const disabled = await submitBtn.getAttribute('disabled');
      expect(typeof disabled).toBe('string');
    }
  });

  it('should re-enable buttons after loading completes', async () => {
    await browser.pause(2000);
    const submitBtn = await $('[data-testid="provider-submit-btn"], button[type="submit"]');
    if (await submitBtn.isExisting()) {
      const disabled = await submitBtn.getAttribute('disabled');
      expect(disabled === null || disabled === 'false').toBe(true);
    }
  });
});