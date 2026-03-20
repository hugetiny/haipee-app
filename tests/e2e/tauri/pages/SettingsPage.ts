/**
 * SettingsPage - Page object for settings management
 */

import { TauriBasePage } from './TauriBasePage.ts';

export class SettingsPage extends TauriBasePage {
  /**
   * Open settings by clicking the settings button in the sidebar
   */
  async open(): Promise<void> {
    await this.waitForReactReady();

    // Navigate to settings via JavaScript — avoids complex CSS selector issues on WKWebView
    const navigated = await browser.execute(() => {
      // Try clicking the settings gear icon button in the sidebar
      const allButtons = Array.from(document.querySelectorAll('button[type="button"]'));
      for (const btn of allButtons) {
        const svg = btn.querySelector('svg');
        if (!svg) continue;
        // Settings/gear icon uses "Settings" lucide icon
        const use = svg.querySelector('use');
        const title = svg.querySelector('title');
        const btnTitle = (btn as HTMLElement).title || '';
        const btnTitleLower = btnTitle.toLowerCase();
        if (btnTitleLower.includes('设置') || btnTitleLower.includes('setting')) {
          (btn as HTMLElement).click();
          return true;
        }
        // Check title element inside SVG
        if (title && (title.textContent || '').toLowerCase().includes('setting')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (!navigated) {
      // Fallback: try CSS selectors one at a time
      const selectors = [
        'button[title*="设置"]',
        'button[title*="Setting"]',
        'button[aria-label*="设置"]',
        'button[aria-label*="Setting"]',
      ];

      for (const sel of selectors) {
        try {
          const btn = await $(sel);
          if (await btn.isExisting()) {
            await btn.waitForClickable({ timeout: 3000 });
            await btn.click();
            await browser.pause(500);
            return;
          }
        } catch {
          // Try next
        }
      }

      console.log('[SettingsPage] Could not find settings button, may already be on settings view');
    }

    await browser.pause(800);
    await this.waitForReactReady();
  }

  /**
   * Open a specific settings tab by value (e.g. 'general', 'proxy', 'auth', etc.)
   * Uses JavaScript execution to avoid WKWebView CSS selector issues with commas.
   */
  async openTab(tabKey: string): Promise<void> {
    // Use JS to find and click the tab with matching data-value or value
    const clicked = await browser.execute((key) => {
      // Shadcn Tabs renders [role="tab"] with data-value attribute
      const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
      for (const tab of tabs) {
        const val = tab.getAttribute('data-value') || tab.getAttribute('value') || '';
        if (val === key) {
          (tab as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, tabKey);

    if (!clicked) {
      // Fallback: try CSS selector directly (no comma, no complex pattern)
      try {
        const tab = await $(`[role="tab"][data-value="${tabKey}"]`);
        if (await tab.isExisting()) {
          await tab.waitForClickable({ timeout: 5000 });
          await tab.click();
        }
      } catch {
        console.log(`[SettingsPage] Tab "${tabKey}" not found`);
      }
    }

    await browser.pause(300);
  }

  /**
   * Toggle a switch by test id or label
   */
  async toggleSwitch(name: string): Promise<boolean> {
    const toggle = await $(`[data-testid="${name}-toggle"]`);
    await toggle.waitForExist({ timeout: 5000 });

    const initialState = await toggle.getAttribute('data-checked') === 'true' ||
      await toggle.getAttribute('aria-checked') === 'true';

    await toggle.click();
    await browser.pause(300);

    return !initialState;
  }

  /**
   * Get switch state
   */
  async getSwitchState(name: string): Promise<boolean> {
    const toggle = await $(`[data-testid="${name}-toggle"]`);
    if (!await toggle.isExisting()) {
      throw new Error(`Toggle ${name} not found`);
    }
    const dataChecked = await toggle.getAttribute('data-checked');
    const ariaChecked = await toggle.getAttribute('aria-checked');
    return dataChecked === 'true' || ariaChecked === 'true';
  }

  /**
   * Change language
   */
  async changeLanguage(lang: 'zh' | 'en'): Promise<void> {
    const langSelector = await $('[data-testid="language-selector"]');
    if (!await langSelector.isExisting()) {
      const selectEl = await $('select[name="language"]');
      if (await selectEl.isExisting()) {
        await selectEl.selectByAttribute('value', lang);
        await browser.pause(500);
        return;
      }
      return;
    }
    await langSelector.waitForExist({ timeout: 5000 });

    if (await langSelector.getTagName() === 'select') {
      await langSelector.selectByAttribute('value', lang);
    } else {
      await langSelector.click();
      await browser.pause(300);
      const option = await $(`[data-value="${lang}"]`);
      await option.click();
    }
    await browser.pause(500);
  }

  /**
   * Get current language
   */
  async getCurrentLanguage(): Promise<string> {
    return browser.execute(() => {
      return document.documentElement.lang || 'en';
    });
  }

  /**
   * Change theme
   */
  async changeTheme(theme: 'light' | 'dark' | 'system'): Promise<void> {
    const themeSelector = await $('[data-testid="theme-selector"]');
    if (!await themeSelector.isExisting()) {
      const themeOption = await $(`[data-theme="${theme}"]`);
      if (await themeOption.isExisting()) {
        await themeOption.click();
        await browser.pause(500);
      }
      return;
    }

    await themeSelector.click();
    await browser.pause(300);

    const option = await $(`[data-value="${theme}"]`);
    await option.click();
    await browser.pause(500);
  }

  /**
   * Get current theme
   */
  async getCurrentTheme(): Promise<string> {
    return browser.execute(() => {
      return document.documentElement.getAttribute('data-theme') || 'light';
    });
  }

  /**
   * Get a setting value
   */
  async getSettingValue(key: string): Promise<string | null> {
    try {
      const el = await $(`[data-testid="setting-${key}"]`);
      if (await el.isExisting()) {
        return el.getText();
      }
    } catch {
      // ignore
    }
    return null;
  }

  /**
   * Save settings
   */
  async saveSettings(): Promise<void> {
    const saved = await browser.execute(() => {
      const allButtons = Array.from(document.querySelectorAll('button'));
      for (const btn of allButtons) {
        const text = btn.textContent || '';
        if (text.includes('保存') || text.includes('Save')) {
          btn.click();
          return true;
        }
      }
      return false;
    });
    if (saved) {
      await browser.pause(500);
    }
  }

  /**
   * Reset settings to defaults
   */
  async resetToDefaults(): Promise<void> {
    const reset = await browser.execute(() => {
      const allButtons = Array.from(document.querySelectorAll('button'));
      for (const btn of allButtons) {
        const text = btn.textContent || '';
        if (text.includes('重置') || text.includes('Reset')) {
          btn.click();
          return true;
        }
      }
      return false;
    });

    if (reset) {
      await browser.pause(300);
      // Confirm reset
      await browser.execute(() => {
        const allButtons = Array.from(document.querySelectorAll('button'));
        for (const btn of allButtons) {
          const text = btn.textContent || '';
          if (text.includes('确认') || text.includes('Confirm')) {
            btn.click();
            return true;
          }
        }
        return false;
      });
      await browser.pause(500);
    }
  }
}

export const settingsPage = new SettingsPage();
