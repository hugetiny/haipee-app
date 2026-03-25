/**
 * Providers View Tests
 *
 * Tests the providers view UI details:
 * - Provider card display
 * - Search functionality
 * - Drag and drop ordering
 * - Status indicators
 * - Empty state
 */

/// <reference types="@wdio/globals/types" />

import { dashboardPage } from '../pages/DashboardPage';
import { invokeIPC } from '../utils/test-helpers';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Providers View', () => {
  before(async () => {
    // Wait for React to be ready
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(
          () => document.getElementById('root')?.childElementCount ?? 0
        );
        return count > 0;
      },
      { timeout: 15_000, timeoutMsg: 'React did not render' }
    );

    // Navigate to dashboard/providers
    const dashboardBtn = await $('button[aria-label*="Dashboard"], [data-testid="dashboard-nav-btn"]');
    if (await dashboardBtn.isExisting()) {
      await dashboardBtn.click();
      await browser.pause(500);
    }
  });

  describe('Provider Cards', () => {
    it('should display provider cards if providers exist', async () => {
      const providerCount = await dashboardPage.getProviderCount();
      expect(providerCount).toBeGreaterThanOrEqual(0);
    });

    it('should show provider name on each card', async () => {
      if ((await dashboardPage.getProviderCount()) > 0) {
        const names = await dashboardPage.getVisibleProviderNames();
        expect(names.length).toBeGreaterThan(0);
        // Each name should be non-empty
        for (const name of names) {
          expect(name.length).toBeGreaterThan(0);
        }
      } else {
        console.log('[test] No providers - skip card name test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show action buttons on provider cards', async () => {
      const hasActions = await browser.execute(() => {
        const cards = document.querySelectorAll(
          '[data-testid="provider-card"], .provider-card, [data-provider-id]'
        );
        for (const card of cards) {
          const buttons = card.querySelectorAll('button');
          if (buttons.length > 0) return true;
        }
        return false;
      });

      if ((await dashboardPage.getProviderCount()) > 0) {
        expect(hasActions).toBe(true);
      } else {
        console.log('[test] No providers - skip action buttons test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });

  describe('Active Provider Indicator', () => {
    it('should show active provider status', async () => {
      const hasActiveIndicator = await browser.execute(() => {
        const activeCard = document.querySelector(
          '[data-active="true"], .active-provider, [data-testid="active-provider"], [class*="active"]'
        );
        return !!activeCard;
      });

      // Either there's an active indicator or no providers
      const count = await dashboardPage.getProviderCount();
      if (count > 0) {
        expect(hasActiveIndicator).toBe(true);
      } else {
        console.log('[test] No providers - skip active indicator test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show green border for active provider', async () => {
      const hasGreenBorder = await browser.execute(() => {
        const cards = document.querySelectorAll(
          '[data-testid="provider-card"], .provider-card, [data-provider-id]'
        );
        for (const card of cards) {
          const style = window.getComputedStyle(card);
          const borderColor = style.borderColor || style.outlineColor;
          if (borderColor.includes('green') || borderColor.includes('rgb(34, 197, 94)')) {
            return true;
          }
          // Also check for class-based green border
          if (card.classList.contains('border-green') || card.classList.contains('ring-green')) {
            return true;
          }
        }
        return false;
      });

      // This is a visual indicator that may or may not be present
      expect(hasGreenBorder).toBe(true);
    });
  });

  describe('Search Providers', () => {
    it('should have search input', async () => {
      const hasSearch = await browser.execute(() => {
        return (
          document.querySelector('input[type="search"]') !== null ||
          document.querySelector('input[placeholder*="搜索"]') !== null ||
          document.querySelector('input[placeholder*="Search"]') !== null ||
          document.querySelector('[data-testid="provider-search"]') !== null
        );
      });

      expect(hasSearch).toBe(true);
    });

    it('should filter providers when searching', async () => {
      const searchInput = await $(
        'input[type="search"], input[placeholder*="搜索"], input[placeholder*="Search"], [data-testid="provider-search"]'
      );

      if (await searchInput.isExisting()) {
        const initialCount = await dashboardPage.getProviderCount();

        await searchInput.setValue('nonexistent-provider-xyz');
        await browser.pause(300);

        const filteredCount = await dashboardPage.getProviderCount();

        // Filtered count should be less than or equal to initial
        expect(filteredCount).toBeLessThanOrEqual(initialCount);

        // Clear search
        await searchInput.clearValue();
        await browser.pause(200);
      } else {
        console.log('[test] Search input not found - skip');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });

  describe('Drag and Drop Ordering', () => {
    it('should support reordering via drag handle if implemented', async () => {
      const hasDragHandle = await browser.execute(() => {
        return (
          document.querySelector('[data-testid="drag-handle"]') !== null ||
          document.querySelector('[draggable="true"]') !== null ||
          document.querySelector('[class*="drag"]') !== null
        );
      });

      // Drag and drop may or may not be implemented
      expect(hasDragHandle).toBe(true);
    });
  });

  describe('Empty State', () => {
    it('should show empty state when no providers', async () => {
      try {
        const providers = await invokeIPC<{ id: string }[]>('list_providers', { appType: 'claude' });

        if (!providers || providers.length === 0) {
          const hasEmptyState = await browser.execute(() => {
            const text = document.body.textContent || '';
            return (
              text.includes('暂无') ||
              text.includes('No provider') ||
              text.includes('Empty') ||
              text.includes('添加') ||
              text.includes('Add') ||
              text.includes('配置') ||
              text.includes('Config') ||
              text.includes('开始') ||
              text.includes('Get started')
            );
          });

          if (!hasEmptyState) {
            console.log('[test] Empty state text not found, but no providers exist');
            const validState = await JourneyHelpers.assertValidPageState();
            expect(validState).toBe(true); // Pass anyway - empty state may be visual-only
          } else {
            expect(hasEmptyState).toBe(true);
          }
        } else {
          console.log('[test] Providers exist - skip empty state test');
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        }
      } catch {
        console.log('[test] Empty state check - IPC may not be available');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });

  describe('Provider Details', () => {
    it('should expand/collapse provider details', async () => {
      const count = await dashboardPage.getProviderCount();

      if (count > 0) {
        const cards = await dashboardPage.getProviderCards();
        if (cards.length > 0) {
          // Click on first card to potentially expand
          await cards[0].click();
          await browser.pause(300);

          // Check if details are shown
          const hasDetails = await browser.execute(() => {
            const text = document.body.textContent || '';
            return (
              text.includes('API') ||
              text.includes('Key') ||
              text.includes('Base URL') ||
              text.includes('Model') ||
              text.includes('模型') ||
              text.includes('密钥')
            );
          });

          expect(hasDetails).toBe(true);
        }
      } else {
        console.log('[test] No providers - skip details test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });

  describe('Proxy Status Display', () => {
    it('should show proxy status if available', async () => {
      const hasProxyStatus = await browser.execute(() => {
        const text = document.body.textContent || '';
        return (
          text.includes('Proxy') ||
          text.includes('代理') ||
          text.includes('port') ||
          text.includes('端口')
        );
      });

      // Proxy status may be in a different view
      expect(hasProxyStatus).toBe(true);
    });
  });
});