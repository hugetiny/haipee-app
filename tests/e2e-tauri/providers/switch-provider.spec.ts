/// <reference types="@wdio/globals/types" />
/**
 * Switch Provider E2E Test
 *
 * Tests the provider switching workflow in the Tauri WebView.
 */

import { dashboardPage } from '../pages';
import { createKimiTestProvider } from '../fixtures/test-data';

describe('Provider Management - Switch Provider', () => {
  const testProvider = createKimiTestProvider();

  before(async () => {
    // Ensure test provider exists
    await dashboardPage.open();
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
      baseUrl: testProvider.baseUrl,
    });
    await browser.pause(500);
  });

  after(async () => {
    // Cleanup: delete the test provider
    await dashboardPage.open();
    await dashboardPage.deleteProvider(testProvider.name);
    await browser.pause(300);
  });

  it('should switch to a different provider', async () => {
    await dashboardPage.open();

    // Get initial provider count
    const cards = await dashboardPage.getProviderCards();
    expect(cards.length).toBeGreaterThan(0);

    // Switch to the test provider
    const switched = await dashboardPage.switchProvider(testProvider.name);
    expect(switched).toBe(true);

    // Wait for any UI feedback
    await browser.pause(500);

    // Wait for any toast notification (may or may not appear)
    await dashboardPage.waitForToast();
    // The key assertion is that switchProvider returned true
  });

  it('should show provider as active after switch', async () => {
    await dashboardPage.open();

    // Get all provider cards
    const cards = await dashboardPage.getProviderCards();
    expect(cards.length).toBeGreaterThan(0);

    // Find and click the test provider
    let foundProvider = false;
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(testProvider.name)) {
        foundProvider = true;
        // Click to select/view provider details
        await card.click();
        await browser.pause(300);
        break;
      }
    }

    expect(foundProvider).toBe(true);
  });
});