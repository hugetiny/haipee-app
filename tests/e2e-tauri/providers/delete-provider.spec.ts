/// <reference types="@wdio/globals/types" />
/**
 * Delete Provider E2E Test
 *
 * Tests the provider deletion workflow in the Tauri WebView.
 */

import { dashboardPage } from '../pages';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Delete Provider', () => {
  it('should delete a provider after confirmation', async () => {
    const testProvider = createKimiTestProvider();

    // Add a provider first
    await dashboardPage.open();
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(500);

    const countBefore = await dashboardPage.getProviderCount();

    // Delete the provider
    await dashboardPage.deleteProvider(testProvider.name);
    await browser.pause(500);

    // Verify deletion
    const countAfter = await dashboardPage.getProviderCount();
    expect(countAfter).toBe(countBefore - 1);

    // Verify provider not in list
    const names = await dashboardPage.getVisibleProviderNames();
    expect(names.some((n: string) => n.includes(testProvider.name))).toBe(false);
  });
});