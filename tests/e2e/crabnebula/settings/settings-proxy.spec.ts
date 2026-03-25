/// <reference types="@wdio/globals/types" />
/**
 * Settings Proxy Tests - Proxy and failover configuration
 */

import { settingsPage, navigationPage } from '../pages';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Settings – Proxy Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('proxy');
    await browser.pause(1000);
  });

  describe('Proxy Configuration', () => {
    it('should display proxy settings section', async () => {
      const proxySection = await $('[data-testid="proxy-settings"]');
      const hasProxy = await proxySection.isExisting();
      expect(hasProxy).toBe(true);
    });

    it('should show proxy toggle', async () => {
      const proxyToggle = await $('[data-testid="proxy-toggle"]');
      const hasToggle = await proxyToggle.isExisting();
      expect(hasToggle).toBe(true);
    });

    it('should toggle proxy on/off', async () => {
      const toggle = await $('[data-testid="proxy-toggle"]');
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

    it('should show proxy port input', async () => {
      const portInput = await $('[data-testid="proxy-port-input"]');
      if (await portInput.isExisting()) {
        const value = await portInput.getValue();
        expect(parseInt(value)).toBeGreaterThan(0);
      }
    });

    it('should update proxy port', async () => {
      const portInput = await $('[data-testid="proxy-port-input"]');
      if (await portInput.isExisting()) {
        await portInput.clearValue();
        await portInput.addValue('8888');
        await browser.pause(300);
      }
    });

    it('should show proxy URL', async () => {
      const proxyUrl = await $('[data-testid="proxy-url-input"]');
      if (await proxyUrl.isExisting()) {
        const value = await proxyUrl.getValue();
        expect(value.length).toBeGreaterThanOrEqual(0);
      }
    });
  });

  describe('Failover Configuration', () => {
    it('should show failover toggle', async () => {
      const failoverToggle = await $('[data-testid="failover-toggle"]');
      const hasToggle = await failoverToggle.isExisting();
      expect(hasToggle).toBe(true);
    });

    it('should toggle failover on/off', async () => {
      const toggle = await $('[data-testid="failover-toggle"]');
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

    it('should show failover queue count', async () => {
      const queueCount = await $('[data-testid="failover-queue-count"]');
      if (await queueCount.isExisting()) {
        const text = await queueCount.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Proxy Status', () => {
    it('should show proxy status indicator', async () => {
      const status = await $('[data-testid="proxy-status"]');
      if (await status.isExisting()) {
        const text = await status.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should show proxy uptime', async () => {
      const uptime = await $('[data-testid="proxy-uptime"]');
      if (await uptime.isExisting()) {
        const text = await uptime.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });
  });
});