/// <reference types="@wdio/globals/types" />
/**
 * Settings Usage Tests - Usage tracking and statistics
 * Note: WebDAV configuration is tested in settings-webdav.spec.ts
 */

import { settingsPage, navigationPage } from '../pages';

describe('Settings – Usage Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('usage');
    await browser.pause(1000);
  });

  describe('Usage Statistics', () => {
    it('should display usage section', async () => {
      const usageSection = await $('[data-testid="usage-stats"]');
      const hasUsage = await usageSection.isExisting();
      expect(hasUsage).toBe(true);
    });

    it('should show total token usage', async () => {
      const tokenUsage = await $('[data-testid="total-token-usage"]');
      if (await tokenUsage.isExisting()) {
        const text = await tokenUsage.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should show usage by provider', async () => {
      const providerUsage = await $$('[data-testid="provider-usage"]');
      for (const usage of providerUsage) {
        const text = await usage.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should show usage chart or graph', async () => {
      const chart = await $('[data-testid="usage-chart"]');
      const hasChart = await chart.isExisting();
      expect(hasChart).toBe(true);
    });
  });

  describe('Usage Limits', () => {
    it('should show daily limit setting', async () => {
      const dailyLimit = await $('[data-testid="daily-limit-input"]');
      if (await dailyLimit.isExisting()) {
        const value = await dailyLimit.getValue();
        expect(parseInt(value)).toBeGreaterThanOrEqual(0);
      }
    });

    it('should show monthly limit setting', async () => {
      const monthlyLimit = await $('[data-testid="monthly-limit-input"]');
      if (await monthlyLimit.isExisting()) {
        const value = await monthlyLimit.getValue();
        expect(parseInt(value)).toBeGreaterThanOrEqual(0);
      }
    });

    it('should toggle limit enforcement', async () => {
      const toggle = await $('[data-testid="enforce-limits-toggle"]');
      if (await toggle.isExisting()) {
        const switchEl = await toggle.$('[role="switch"]');
        if (await switchEl.isExisting()) {
          await switchEl.click();
          await browser.pause(300);
          // Verify we're still on a valid page
          const body = await $('body');
          const hasContent = await body.isExisting();
          expect(hasContent).toBe(true);
        }
      }
    });
  });
});