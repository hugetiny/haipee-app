/// <reference types="@wdio/globals/types" />
/**
 * Add Provider E2E Test
 *
 * Tests the provider creation workflow in the Tauri WebView.
 */

import { dashboardPage } from '../pages';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Add Provider', () => {
  it('should add a new provider with valid configuration', async () => {
    const testProvider = createKimiTestProvider();

    // Get initial count
    await dashboardPage.open();
    const initialCount = await dashboardPage.getProviderCount();

    // Add provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
      model: testProvider.model,
    });

    // Wait for toast
    await browser.pause(1000);

    // Verify provider was added
    const newCount = await dashboardPage.getProviderCount();
    expect(newCount).toBe(initialCount + 1);

    // Verify provider appears in list
    const names = await dashboardPage.getVisibleProviderNames();
    expect(names.some((n: string) => n.includes(testProvider.name))).toBe(true);
  });

  it('should show validation error for empty name', async () => {
    await dashboardPage.open();
    await dashboardPage.clickAddProvider();

    // Try to save without filling required fields
    await dashboardPage.saveProvider();

    // Wait for validation
    await browser.pause(500);

    // Check for error message or form still open
    const form = $('[data-testid="provider-form"], form');
    const formVisible = await form.isExisting();
    expect(formVisible).toBe(true); // Form should still be visible
  });
});