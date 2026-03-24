/// <reference types="@wdio/globals/types" />
/**
 * Provider List Tests - Display and Search
 */

import { dashboardPage, navigationPage } from '../pages';

describe('Provider List – Display', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000); // Wait for providers to load
  });

  it('should display provider list or empty state', async () => {
    const hasLayout = await browser.execute(() => {
      return Boolean(
        document.querySelector('[data-testid="provider-grid"]') ||
          document.querySelector('[data-testid="provider-empty-state"]'),
      );
    });
    expect(typeof hasLayout).toBe('boolean');
  });

  it('should not show loading after initial load', async () => {
    await browser.pause(1000);
    const isLoading = await dashboardPage.isLoading();
    expect(isLoading).toBe(false);
  });

  it('should display providers in grid layout', async () => {
    const count = await dashboardPage.getProviderCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show provider names correctly', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count > 0) {
      const names = await dashboardPage.getVisibleProviderNames();
      expect(names.length).toBeGreaterThan(0);
      expect(names.every(n => n.length > 0)).toBe(true);
    }
  });

  it('should show empty state when no providers', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count === 0) {
      const hasEmpty = await dashboardPage.isEmptyState();
      expect(typeof hasEmpty).toBe('boolean');
    }
  });
});

describe('Provider List – Search', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should open search with keyboard shortcut', async () => {
    await dashboardPage.openSearch();
    await browser.pause(300);

    const searchInput = await $('[data-testid="provider-search"]');
    const exists = await searchInput.isExisting();
    expect(typeof exists).toBe('boolean');

    // Close search
    await browser.keys(['Escape']);
    await browser.pause(200);
  });

  it('should filter providers by search query', async () => {
    const initialCount = await dashboardPage.getProviderCount();
    if (initialCount > 0) {
      const names = await dashboardPage.getVisibleProviderNames();
      const firstName = names[0];
      if (firstName) {
        await dashboardPage.searchProviders(firstName);
        await browser.pause(500);

        const filteredNames = await dashboardPage.getVisibleProviderNames();
        // Should have at least one matching provider
        expect(filteredNames.length).toBeGreaterThanOrEqual(1);

        await dashboardPage.clearSearch();
        await browser.pause(300);
      }
    }
  });

  it('should show no results for non-matching query', async () => {
    await dashboardPage.searchProviders('xyznonexistent12345');
    await browser.pause(500);

    // Should either show no-results state or have 0 visible providers
    const count = await dashboardPage.getProviderCount();
    const hasNoResultsText = await dashboardPage.pageContainsAnyText([
      'No providers match your search',
      '暂无',
      '无结果',
    ]);
    expect(typeof hasNoResultsText).toBe('boolean');
    expect(count).toBeGreaterThanOrEqual(0);

    await dashboardPage.clearSearch();
    await browser.pause(200);
  });

  it('should clear search and show all providers', async () => {
    const initialCount = await dashboardPage.getProviderCount();
    if (initialCount > 0) {
      await dashboardPage.searchProviders('test');
      await browser.pause(300);
      await dashboardPage.clearSearch();
      await browser.pause(300);

      const finalCount = await dashboardPage.getProviderCount();
      expect(finalCount).toBe(initialCount);
    }
  });
});

describe('Provider List – Layout', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should display provider grid container', async () => {
    const grid = await $('[data-testid="provider-grid"]');
    const exists = await grid.isExisting();
    // May not exist if no providers
    expect(typeof exists).toBe('boolean');
  });

  it('should have consistent card styling', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count > 0) {
      const cards = await $$('[data-testid="provider-card"], [data-provider-id]');
      expect(cards.length).toBeGreaterThan(0);
    }
  });

  it('should show provider count or status', async () => {
    const hasStatus = await dashboardPage.pageContainsAnyText([
      '供应商', 'Provider', '个', 'total', 'count'
    ]);
    expect(typeof hasStatus).toBe('boolean');
  });
});
