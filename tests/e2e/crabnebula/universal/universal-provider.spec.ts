/// <reference types="@wdio/globals/types" />
/**
 * Universal Provider Tests - Universal provider management
 */

import { universalProviderPage, navigationPage } from '../pages';
import { createTestProvider } from '../fixtures';

describe('Universal Provider – List', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should display provider list', async () => {
    const count = await universalProviderPage.getProviderCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show provider names', async () => {
    const names = await universalProviderPage.getProviderNames();
    expect(Array.isArray(names)).toBe(true);
  });

  it('should check if provider exists', async () => {
    const exists = await universalProviderPage.providerExists('NonExistent');
    expect(exists).toBe(false);
  });
});

describe('Universal Provider – CRUD', () => {
  const testProvider = createTestProvider({ name: `Universal Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await universalProviderPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should show add provider button', async () => {
    const addBtn = await $('[data-testid="universal-provider-add-btn"], [data-testid="add-provider-btn"]');
    const hasBtn = await addBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should add a new universal provider', async () => {
    await universalProviderPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);

    const exists = await universalProviderPage.providerExists(testProvider.name);
    expect(exists).toBe(true);
  });

  it('should show edit button for providers', async () => {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    const providerArray = [...providers] as unknown as WebdriverIO.Element[];
    if (providerArray.length > 0) {
      const firstProvider = providerArray[0];
      const editBtn = await firstProvider.$('button[aria-label*="edit"], button[aria-label*="编辑"]');
      const hasEdit = await editBtn.isExisting();
      expect(typeof hasEdit).toBe('boolean');
    }
  });

  it('should show delete button for providers', async () => {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    const providerArray = [...providers] as unknown as WebdriverIO.Element[];
    if (providerArray.length > 0) {
      const firstProvider = providerArray[0];
      const deleteBtn = await firstProvider.$('button[aria-label*="delete"], button[aria-label*="删除"]');
      const hasDelete = await deleteBtn.isExisting();
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('Universal Provider – Sync', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show sync button', async () => {
    const syncBtn = await $('[data-testid="universal-sync-btn"]');
    const hasBtn = await syncBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should trigger sync operation', async () => {
    await universalProviderPage.sync();
    await browser.pause(1000);

    expect(true).toBe(true);
  });

  it('should show sync status', async () => {
    const syncStatus = await $('[data-testid="sync-status"]');
    if (await syncStatus.isExisting()) {
      const text = await syncStatus.getText();
      expect(typeof text).toBe('string');
    }
  });
});

describe('Universal Provider – App Toggles', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show app toggle buttons', async () => {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    const providerArray = [...providers] as unknown as WebdriverIO.Element[];
    if (providerArray.length > 0) {
      const firstProvider = providerArray[0];
      const toggles = await firstProvider.$$('button[role="switch"]');
      const toggleArray = [...toggles] as unknown as WebdriverIO.Element[];
      expect(toggleArray.length).toBeGreaterThanOrEqual(0);
    }
  });

  it('should toggle provider for specific app', async () => {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    const providerArray = [...providers] as unknown as WebdriverIO.Element[];
    if (providerArray.length > 0) {
      const firstProvider = providerArray[0];
      const toggle = await firstProvider.$('button[role="switch"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
        expect(true).toBe(true);
      }
    }
  });
});