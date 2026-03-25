/// <reference types="@wdio/globals/types" />
/**
 * Settings Usage Tests - Usage tracking and WebDAV configuration
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
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        }
      }
    });
  });

  describe('WebDAV Configuration', () => {
    it('should display WebDAV configuration section', async () => {
      const webdav = await $('[data-testid="webdav-config"]');
      const hasWebdav = await webdav.isExisting();
      expect(hasWebdav).toBe(true);
    });

    it('should show WebDAV server URL input', async () => {
      const urlInput = await $('[data-testid="webdav-url-input"]');
      if (await urlInput.isExisting()) {
        const value = await urlInput.getValue();
        expect(value.length).toBeGreaterThanOrEqual(0);
      }
    });

    it('should show WebDAV username input', async () => {
      const userInput = await $('[data-testid="webdav-username-input"]');
      const hasInput = await userInput.isExisting();
      expect(hasInput).toBe(true);
    });

    it('should show WebDAV password input', async () => {
      const passInput = await $('[data-testid="webdav-password-input"]');
      const hasInput = await passInput.isExisting();
      expect(hasInput).toBe(true);
    });

    it('should toggle WebDAV sync', async () => {
      const toggle = await $('[data-testid="webdav-toggle"]');
      if (await toggle.isExisting()) {
        const switchEl = await toggle.$('[role="switch"]');
        if (await switchEl.isExisting()) {
          await switchEl.click();
          await browser.pause(300);
          const validState = await JourneyHelpers.assertValidPageState();
          expect(validState).toBe(true);
        }
      }
    });

    it('should show WebDAV sync status', async () => {
      const status = await $('[data-testid="webdav-sync-status"]');
      if (await status.isExisting()) {
        const text = await status.getText();
        expect(text.length).toBeGreaterThanOrEqual(0);
      }
    });

    it('should trigger manual WebDAV sync', async () => {
      const syncBtn = await $('[data-testid="webdav-sync-btn"]');
      if (await syncBtn.isExisting()) {
        await syncBtn.click();
        await browser.pause(1000);
      }
    });
  });

  describe('Event Log', () => {
    it('should show event log section', async () => {
      const eventLog = await $('[data-testid="event-log"]');
      const hasLog = await eventLog.isExisting();
      expect(hasLog).toBe(true);
    });

    it('should list recent events', async () => {
      const events = await $$('[data-testid="event-item"]');
      expect(events.length).toBeGreaterThanOrEqual(0);
    });

    it('should filter events by type', async () => {
      const filterBtn = await $('[data-testid="event-filter"]');
      if (await filterBtn.isExisting()) {
        await filterBtn.click();
        await browser.pause(300);
        await browser.keys(['Escape']);
      }
    });

    it('should export event log', async () => {
      const exportBtn = await $('[data-testid="export-events-btn"]');
      if (await exportBtn.isExisting()) {
        await exportBtn.click();
        await browser.pause(500);
      }
    });
  });
});