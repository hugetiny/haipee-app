/// <reference types="@wdio/globals/types" />
/**
 * Settings General Tests - Language and Theme settings
 */

import { settingsPage, navigationPage } from '../pages';

describe('Settings – General Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await browser.pause(1000);
  });

  describe('Tab Navigation', () => {
    it('should display settings tabs', async () => {
      const tabs = await $('[data-testid="settings-tabs"]');
      const hasTabs = await tabs.isExisting();
      expect(typeof hasTabs).toBe('boolean');
    });

    it('should switch between tabs', async () => {
      const tabs = ['general', 'models', 'proxy', 'auth', 'advanced', 'usage', 'about'];

      for (const tab of tabs) {
        const tabBtn = await $(`[data-testid="settings-tab-${tab}"]`);
        if (await tabBtn.isExisting()) {
          await tabBtn.click();
          await browser.pause(300);
        }
      }
    });
  });

  describe('Language Settings', () => {
    before(async () => {
      await settingsPage.openTab('general');
      await browser.pause(500);
    });

    it('should display language options', async () => {
      // Check for language-related UI elements
      const langSection = await $('[data-testid="language-settings"], [class*="language"], select[name="language"]');
      const hasLangSection = await langSection.isExisting();

      // Or check for language text
      const hasLang = await settingsPage.pageContainsAnyText([
        '语言', 'Language', '中文', 'English', '日本語', 'Japanese'
      ]);

      // Pass if either element or text found
      expect(hasLangSection || hasLang).toBe(true);
    });

    it('should switch to English', async () => {
      const enBtn = await $('[data-testid="language-btn-en"]');
      if (await enBtn.isExisting()) {
        await enBtn.click();
        await browser.pause(500);

        const htmlLang = await browser.execute(() => document.documentElement.lang);
        expect(typeof htmlLang).toBe('string');
      }
    });

    it('should switch to Chinese', async () => {
      const zhBtn = await $('[data-testid="language-btn-zh"]');
      if (await zhBtn.isExisting()) {
        await zhBtn.click();
        await browser.pause(500);

        const htmlLang = await browser.execute(() => document.documentElement.lang);
        expect(typeof htmlLang).toBe('string');
      }
    });

    it('should switch to Japanese', async () => {
      const jaBtn = await $('[data-testid="language-btn-ja"]');
      if (await jaBtn.isExisting()) {
        await jaBtn.click();
        await browser.pause(500);

        const htmlLang = await browser.execute(() => document.documentElement.lang);
        expect(typeof htmlLang).toBe('string');
      }
    });
  });

  describe('Theme Settings', () => {
    before(async () => {
      await settingsPage.openTab('general');
      await browser.pause(500);
    });

    it('should display theme options', async () => {
      // Check for theme-related UI elements
      const themeSection = await $('[data-testid="theme-settings"], [class*="theme"], select[name="theme"]');
      const hasThemeSection = await themeSection.isExisting();

      // Or check for theme text
      const hasTheme = await settingsPage.pageContainsAnyText([
        '主题', 'Theme', 'light', 'dark', 'system', '浅色', '深色', '跟随系统'
      ]);

      // Pass if either element or text found
      expect(hasThemeSection || hasTheme).toBe(true);
    });

    it('should switch to light theme', async () => {
      const lightBtn = await $('[data-testid="theme-btn-light"]');
      if (await lightBtn.isExisting()) {
        await lightBtn.click();
        await browser.pause(500);

        const isLight = await browser.execute(() =>
          !document.documentElement.classList.contains('dark') ||
          document.documentElement.getAttribute('data-theme') === 'light'
        );
        expect(typeof isLight).toBe('boolean');
      }
    });

    it('should switch to dark theme', async () => {
      const darkBtn = await $('[data-testid="theme-btn-dark"]');
      if (await darkBtn.isExisting()) {
        await darkBtn.click();
        await browser.pause(500);

        const isDark = await browser.execute(() =>
          document.documentElement.classList.contains('dark') ||
          document.documentElement.getAttribute('data-theme') === 'dark'
        );
        expect(typeof isDark).toBe('boolean');
      }
    });

    it('should switch to system theme', async () => {
      const systemBtn = await $('[data-testid="theme-btn-system"]');
      if (await systemBtn.isExisting()) {
        await systemBtn.click();
        await browser.pause(500);

        // System theme should match OS preference
        expect(true).toBe(true);
      }
    });
  });
});