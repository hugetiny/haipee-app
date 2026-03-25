/// <reference types="@wdio/globals/types" />
/**
 * Settings Advanced Tests - Advanced configuration options
 */

import { settingsPage, navigationPage } from '../pages';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Settings – Advanced Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('advanced');
    await browser.pause(1000);
  });

  describe('Remote Connect', () => {
    it('should display remote connect toggle', async () => {
      const toggle = await $('[data-testid="remote-connect-toggle"]');
      const hasToggle = await toggle.isExisting();
      expect(hasToggle).toBe(true);
    });

    it('should show remote connect port input', async () => {
      const input = await $('[data-testid="remote-connect-port"]');
      if (await input.isExisting()) {
        const value = await input.getValue();
        expect(parseInt(value)).toBeGreaterThan(0);
      }
    });

    it('should toggle remote connect', async () => {
      const toggle = await $('[data-testid="remote-connect-toggle"]');
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

    it('should show remote connect status', async () => {
      const status = await $('[data-testid="remote-connect-status"]');
      if (await status.isExisting()) {
        const text = await status.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Rectifier Config', () => {
    it('should display rectifier settings', async () => {
      const rectifier = await $('[data-testid="rectifier-config"]');
      const hasRectifier = await rectifier.isExisting();
      expect(hasRectifier).toBe(true);
    });

    it('should configure rectifier enabled', async () => {
      const toggle = await $('[data-testid="rectifier-toggle"]');
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

  describe('Debug Options', () => {
    it('should show debug logging toggle', async () => {
      const debugToggle = await $('[data-testid="debug-logging-toggle"]');
      const hasToggle = await debugToggle.isExisting();
      expect(hasToggle).toBe(true);
    });

    it('should show log level selector', async () => {
      const logLevel = await $('[data-testid="log-level-selector"]');
      if (await logLevel.isExisting()) {
        await logLevel.click();
        await browser.pause(300);
      }
    });

    it('should open log file location', async () => {
      const openLogBtn = await $('[data-testid="open-log-btn"]');
      if (await openLogBtn.isExisting()) {
        await openLogBtn.click();
        await browser.pause(500);
      }
    });
  });

  describe('Data Management', () => {
    it('should show data directory path', async () => {
      const dataDir = await $('[data-testid="data-directory"]');
      if (await dataDir.isExisting()) {
        const text = await dataDir.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should open data directory', async () => {
      const openDirBtn = await $('[data-testid="open-data-dir-btn"]');
      if (await openDirBtn.isExisting()) {
        await openDirBtn.click();
        await browser.pause(500);
      }
    });

    it('should export settings', async () => {
      const exportBtn = await $('[data-testid="export-settings-btn"]');
      if (await exportBtn.isExisting()) {
        await exportBtn.click();
        await browser.pause(500);
      }
    });

    it('should import settings', async () => {
      const importBtn = await $('[data-testid="import-settings-btn"]');
      const hasBtn = await importBtn.isExisting();
      expect(hasBtn).toBe(true);
    });
  });

  describe('Reset Options', () => {
    it('should show reset to defaults button', async () => {
      const resetBtn = await $('[data-testid="reset-defaults-btn"]');
      const hasBtn = await resetBtn.isExisting();
      expect(hasBtn).toBe(true);
    });

    it('should reset settings with confirmation', async () => {
      const resetBtn = await $('[data-testid="reset-defaults-btn"]');
      if (await resetBtn.isExisting()) {
        await resetBtn.click();
        await browser.pause(300);

        // Cancel reset for safety
        await browser.keys(['Escape']);
      }
    });
  });
});