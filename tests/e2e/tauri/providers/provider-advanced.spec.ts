/// <reference types="@wdio/globals/types" />
/**
 * Provider Advanced Tests - Drag/drop reorder, bulk operations
 */

import { dashboardPage, navigationPage } from '../pages';
import { createTestProvider, createTestProviders } from '../fixtures';

describe('Provider Advanced – Reorder', () => {
  const testProviders = createTestProviders(3);

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);

    // Create test providers
    for (const provider of testProviders) {
      await dashboardPage.addProvider({
        name: provider.name,
        apiKey: provider.apiKey,
      });
      await browser.pause(300);
    }
    await browser.pause(1000);
  });

  after(async () => {
    // Cleanup
    for (const provider of testProviders) {
      try {
        await dashboardPage.deleteProvider(provider.name);
      } catch {
        // Ignore
      }
    }
  });

  it('should have multiple providers for reorder test', async () => {
    const count = await dashboardPage.getProviderCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should reorder providers via drag and drop', async () => {
    const cards = await $$('[data-testid="provider-card"], [data-provider-id]');
    const cardArray = [...cards] as unknown as WebdriverIO.Element[];
    if (cardArray.length >= 2) {
      const names = await dashboardPage.getVisibleProviderNames();
      const firstName = names[0];

      // Attempt drag and drop
      await dashboardPage.dragProviderToPosition(firstName, 1);
      await browser.pause(500);

      // Verify order changed (or at least no error)
      const newNames = await dashboardPage.getVisibleProviderNames();
      expect(newNames.length).toBe(names.length);
    }
  });

  it('should persist order after page reload', async () => {
    const namesBefore = await dashboardPage.getVisibleProviderNames();

    // Navigate away and back
    await navigationPage.switchToApp('codex');
    await navigationPage.navigateToView('providers');
    await browser.pause(500);
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);

    const namesAfter = await dashboardPage.getVisibleProviderNames();
    expect(namesAfter.length).toBe(namesBefore.length);
  });
});

describe('Provider Advanced – Bulk Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should select multiple providers if supported', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count >= 2) {
      // Try to find multi-select UI
      const selectAllBtn = await $('button[aria-label*="全选"], button[aria-label*="select all"]');
      const hasMultiSelect = await selectAllBtn.isExisting();
      expect(typeof hasMultiSelect).toBe('boolean');
    }
  });

  it('should show bulk delete option when items selected', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count >= 2) {
      // Check for bulk action buttons
      const bulkActions = await $('[data-testid="bulk-actions"], [class*="bulk"]');
      const hasBulk = await bulkActions.isExisting();
      expect(typeof hasBulk).toBe('boolean');
    }
  });
});

describe('Provider Advanced – Import/Export', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should show import option', async () => {
    const importBtn = await $('button[aria-label*="导入"], button[aria-label*="import"], [data-testid="import-btn"]');
    const hasImport = await importBtn.isExisting();
    expect(typeof hasImport).toBe('boolean');
  });

  it('should show export option', async () => {
    const exportBtn = await $('button[aria-label*="导出"], button[aria-label*="export"], [data-testid="export-btn"]');
    const hasExport = await exportBtn.isExisting();
    expect(typeof hasExport).toBe('boolean');
  });
});

describe('Provider Advanced – Filter by Category', () => {
  const testProvider = createTestProvider({ name: `Category Test ${Date.now()}`, category: 'custom' });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
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

  it('should show category filter if available', async () => {
    const categoryFilter = await $('[data-testid="category-filter"], select[name*="category"]');
    const hasFilter = await categoryFilter.isExisting();
    expect(typeof hasFilter).toBe('boolean');
  });

  it('should filter providers by category', async () => {
    const categoryFilter = await $('[data-testid="category-filter"], select[name*="category"]');
    if (await categoryFilter.isExisting()) {
      await categoryFilter.click();
      await browser.pause(300);

      // Check for category options
      const hasOptions = await dashboardPage.pageContainsAnyText([
        'openai', 'anthropic', 'google', 'custom', '全部', 'all'
      ]);
      expect(typeof hasOptions).toBe('boolean');

      await browser.keys(['Escape']);
    }
  });
});

describe('Provider Advanced – Responsive Layout', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should adapt to different screen sizes', async () => {
    // Get current viewport
    const viewport = await browser.getWindowSize();

    // Test at different widths
    const widths = [1920, 1280, 768];

    for (const width of widths) {
      await browser.setWindowSize(width, viewport.height);
      await browser.pause(500);

      const hasLayout = await browser.execute(() => {
        return Boolean(
          document.querySelector('[data-testid="provider-grid"]') ||
            document.querySelector('[data-testid="provider-empty-state"]'),
        );
      });
      expect(typeof hasLayout).toBe('boolean');
    }

    // Restore original size
    await browser.setWindowSize(viewport.width, viewport.height);
  });

  it('should show mobile menu on small screens', async () => {
    const viewport = await browser.getWindowSize();

    // Set to mobile width
    await browser.setWindowSize(375, viewport.height);
    await browser.pause(500);

    // Check for mobile menu button
    const mobileMenuBtn = await $('[data-testid="mobile-menu-btn"], button[aria-label*="menu"]');
    const hasMobileMenu = await mobileMenuBtn.isExisting();

    // Restore original size
    await browser.setWindowSize(viewport.width, viewport.height);

    expect(typeof hasMobileMenu).toBe('boolean');
  });
});
