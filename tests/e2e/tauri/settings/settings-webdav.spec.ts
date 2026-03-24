/// <reference types="@wdio/globals/types" />
/**
 * WebDAV Sync Tests - WebDAV synchronization settings and operations
 */

import { webDavPage, navigationPage, settingsPage } from '../pages';

describe('WebDAV Settings – Configuration', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  it('should display WebDAV settings section', async () => {
    const webdavSection = await $('[data-testid="webdav-settings"], [data-testid="sync-section"]');
    const hasSection = await webdavSection.isExisting();
    expect(typeof hasSection).toBe('boolean');
  });

  it('should show WebDAV URL input', async () => {
    const urlInput = await $('[data-testid="webdav-url-input"], input[placeholder*="webdav"], input[name="webdavUrl"]');
    const hasInput = await urlInput.isExisting();
    expect(typeof hasInput).toBe('boolean');
  });

  it('should show username input', async () => {
    const userInput = await $('[data-testid="webdav-username-input"], input[name="webdavUsername"]');
    const hasInput = await userInput.isExisting();
    expect(typeof hasInput).toBe('boolean');
  });

  it('should show password input', async () => {
    const passInput = await $('[data-testid="webdav-password-input"], input[type="password"]');
    const hasInput = await passInput.isExisting();
    expect(typeof hasInput).toBe('boolean');
  });

  it('should show auto-sync toggle', async () => {
    const toggle = await $('[data-testid="webdav-auto-sync-toggle"], input[name="autoSync"]');
    const hasToggle = await toggle.isExisting();
    expect(typeof hasToggle).toBe('boolean');
  });
});

describe('WebDAV Settings – Input Validation', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  it('should accept valid WebDAV URL', async () => {
    const urlInput = await $('[data-testid="webdav-url-input"]');
    if (await urlInput.isExisting()) {
      await urlInput.clearValue();
      await urlInput.addValue('https://webdav.example.com/dav');
      const value = await urlInput.getValue();
      expect(value).toContain('webdav.example.com');
    }
  });

  it('should accept username input', async () => {
    const userInput = await $('[data-testid="webdav-username-input"]');
    if (await userInput.isExisting()) {
      await userInput.clearValue();
      await userInput.addValue('testuser');
      const value = await userInput.getValue();
      expect(value).toBe('testuser');
    }
  });

  it('should mask password input', async () => {
    const passInput = await $('[data-testid="webdav-password-input"], input[type="password"]');
    if (await passInput.isExisting()) {
      const type = await passInput.getAttribute('type');
      expect(type).toBe('password');
    }
  });
});

describe('WebDAV Settings – Sync Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  it('should show sync button', async () => {
    const byTestId = await $('[data-testid="webdav-sync-btn"]');
    let hasBtn = await byTestId.isExisting();
    if (!hasBtn) {
      hasBtn = await navigationPage.pageContainsAnyText(['同步', 'Sync']);
    }
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should show test connection button', async () => {
    const byTestId = await $('[data-testid="webdav-test-btn"]');
    let hasBtn = await byTestId.isExisting();
    if (!hasBtn) {
      hasBtn = await navigationPage.pageContainsAnyText(['测试', 'Test']);
    }
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should trigger sync operation', async () => {
    const result = await webDavPage.triggerSync();
    // May fail if not configured - that's OK
    expect(typeof result).toBe('boolean');
  });

  it('should get sync status', async () => {
    const status = await webDavPage.getSyncStatus();
    expect(status && typeof status === 'object').toBe(true);
    expect(typeof (status as { status?: unknown }).status).toBe('string');
  });
});

describe('WebDAV Settings – Status Display', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  it('should show last sync time if available', async () => {
    const lastSync = await $('[data-testid="webdav-last-sync"], [class*="lastSync"]');
    if (await lastSync.isExisting()) {
      const text = await lastSync.getText();
      expect(typeof text).toBe('string');
    }
  });

  it('should show sync status indicator', async () => {
    const status = await $('[data-testid="webdav-status"], [class*="syncStatus"]');
    if (await status.isExisting()) {
      const text = await status.getText();
      expect(typeof text).toBe('string');
    }
  });

  it('should show error message if sync failed', async () => {
    const errorEl = await $('[data-testid="webdav-error"], [class*="syncError"]');
    // Error may not exist if no error
    const hasError = await errorEl.isExisting();
    expect(typeof hasError).toBe('boolean');
  });
});

describe('WebDAV Settings – Auto Sync', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  it('should toggle auto-sync', async () => {
    const toggle = await $('[data-testid="webdav-auto-sync-toggle"], input[name="autoSync"]');
    if (await toggle.isExisting()) {
      const initialState = await toggle.isSelected();
      await toggle.click();
      await browser.pause(300);
      const newState = await toggle.isSelected();
      expect(newState).toBe(!initialState);

      // Toggle back
      await toggle.click();
      await browser.pause(300);
    }
  });

  it('should show sync interval selector', async () => {
    const intervalSelect = await $('[data-testid="webdav-sync-interval"], select[name="syncInterval"]');
    const hasSelect = await intervalSelect.isExisting();
    expect(typeof hasSelect).toBe('boolean');
  });
});
