/// <reference types="@wdio/globals/types" />
/**
 * Settings E2E Tests
 *
 * Tests settings management workflows including
 * language switching, theme changes, and preferences.
 */

import { settingsPage } from './pages/SettingsPage.ts';

describe('Settings Management', () => {
  before(async () => {
    await settingsPage.open();
  });

  describe('Settings Page Load', () => {
    it('should display the settings page', async () => {
      const hasSettings = await settingsPage.hasHeading('设置') ||
        await settingsPage.hasHeading('Settings');
      expect(hasSettings).toBe(true);
    });

    it('should have interactive elements', async () => {
      const count = await browser.execute(
        () => document.querySelectorAll('button, input, select, [role="tab"]').length,
      );
      expect(count).toBeGreaterThan(0);
    });
  });

  describe('Language Settings', () => {
    it('should detect current language', async () => {
      const lang = await settingsPage.getCurrentLanguage();
      expect(['zh', 'en']).toContain(lang);
    });
  });

  describe('Theme Settings', () => {
    it('should detect current theme', async () => {
      const theme = await settingsPage.getCurrentTheme();
      expect(['light', 'dark', 'system']).toContain(theme);
    });
  });

  describe('Settings Persistence', () => {
    it('should show settings have been saved (no unsaved indicators)', async () => {
      const hasUnsaved = await settingsPage.elementExists('[data-unsaved="true"], .unsaved');
      expect(hasUnsaved).toBe(false);
    });
  });
});
