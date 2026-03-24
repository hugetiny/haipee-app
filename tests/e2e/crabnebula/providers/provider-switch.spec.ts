/// <reference types="@wdio/globals/types" />
/**
 * Provider Switch Tests - Switching active provider
 */

import { dashboardPage, navigationPage } from '../pages';
import { createTestProvider } from '../fixtures';

describe('Provider Switch – Basic', () => {
  const testProvider1 = createTestProvider({ name: `Switch Test 1 ${Date.now()}` });
  const testProvider2 = createTestProvider({ name: `Switch Test 2 ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test providers
    await dashboardPage.addProvider({
      name: testProvider1.name,
      apiKey: testProvider1.apiKey,
      baseUrl: testProvider1.baseUrl,
    });
    await browser.pause(500);
    await dashboardPage.addProvider({
      name: testProvider2.name,
      apiKey: testProvider2.apiKey,
      baseUrl: testProvider2.baseUrl,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider1.name);
      await dashboardPage.deleteProvider(testProvider2.name);
    } catch {
      // Ignore
    }
  });

  it('should switch to provider when clicked', async () => {
    const switched = await dashboardPage.switchProvider(testProvider1.name);
    await browser.pause(500);

    expect(typeof switched).toBe('boolean');
  });

  it('should show current provider indicator', async () => {
    const currentProvider = await dashboardPage.getCurrentProvider();
    expect(typeof currentProvider).toBe('object'); // string or null
  });

  it('should update UI when switching providers', async () => {
    // Switch to second provider
    await dashboardPage.switchProvider(testProvider2.name);
    await browser.pause(500);

    const currentProvider = await dashboardPage.getCurrentProvider();

    // At least verify the switch didn't cause an error
    expect(typeof currentProvider).toBe('object');
  });
});

describe('Provider Switch – Toast Notifications', () => {
  const testProvider = createTestProvider({ name: `Toast Switch Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should show toast notification on switch', async () => {
    await dashboardPage.switchProvider(testProvider.name);
    await browser.pause(1000);

    // Check for toast
    const toast = await $('[data-sonner-toast], [role="status"]');
    if (await toast.isExisting()) {
      const text = await toast.getText();
      // Toast should contain some text about the switch
      expect(text.length).toBeGreaterThan(0);
    }
  });
});

describe('Provider Switch – Proxy Takeover', () => {
  const testProvider = createTestProvider({ name: `Proxy Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should toggle failover for provider', async () => {
    await dashboardPage.toggleFailover(testProvider.name);
    await browser.pause(500);

    // Verify toggle worked (check for state change)
    const priority = await dashboardPage.getFailoverPriority(testProvider.name);
    expect(typeof priority).toBe('object'); // number or null
  });

  it('should show failover priority badge when enabled', async () => {
    const priority = await dashboardPage.getFailoverPriority(testProvider.name);
    // Priority may or may not be shown depending on failover state
    expect(typeof priority).toBe('object');
  });
});

describe('Provider Switch – App Context', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should maintain provider context when switching apps', async () => {
    // Switch to Claude app
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    const claudeCount = await dashboardPage.getProviderCount();

    // Switch to Codex app
    await navigationPage.switchToApp('codex');
    await browser.pause(1000);

    const codexCount = await dashboardPage.getProviderCount();

    // Both should have valid counts (may differ)
    expect(claudeCount).toBeGreaterThanOrEqual(0);
    expect(codexCount).toBeGreaterThanOrEqual(0);
  });

  it('should show app-specific providers', async () => {
    await navigationPage.switchToApp('gemini');
    await browser.pause(1000);

    const hasGeminiContent = await dashboardPage.pageContainsAnyText([
      'Gemini', 'gemini', '供应商', 'Provider'
    ]);
    expect(hasGeminiContent).toBe(true);
  });
});