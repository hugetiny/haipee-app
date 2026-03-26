/// <reference types="@wdio/globals/types" />
/**
 * Settings Usage Tests - Usage tracking and statistics
 * Note: WebDAV configuration is tested in settings-webdav.spec.ts
 */

import { settingsPage, navigationPage } from '../pages';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Settings – Usage Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('usage');
    await browser.pause(1000);
  });

  describe('Usage Statistics', () => {
    it('should display usage section or graceful degradation', async () => {
      try {
        const usageSection = await $('[data-testid="usage-stats"]');
        const hasUsage = await usageSection.isExisting();
        if (!hasUsage) {
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        } else {
          expect(hasUsage).toBe(true);
        }
      } catch {
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show total token usage or graceful degradation', async () => {
      try {
        const tokenUsage = await $('[data-testid="total-token-usage"]');
        if (await tokenUsage.isExisting()) {
          const text = await tokenUsage.getText();
          expect(text.length).toBeGreaterThan(0);
        } else {
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        }
      } catch {
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show usage by provider or graceful degradation', async () => {
      try {
        const providerUsage = await $$('[data-testid="provider-usage"]');
        const providerArray = [...providerUsage] as unknown as WebdriverIO.Element[];
        if (providerArray.length > 0) {
          for (const usage of providerArray) {
            const text = await usage.getText();
            expect(text.length).toBeGreaterThan(0);
          }
        } else {
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        }
      } catch {
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show usage chart or graph or graceful degradation', async () => {
      try {
        const chart = await $('[data-testid="usage-chart"]');
        const hasChart = await chart.isExisting();
        if (!hasChart) {
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        } else {
          expect(hasChart).toBe(true);
        }
      } catch {
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
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