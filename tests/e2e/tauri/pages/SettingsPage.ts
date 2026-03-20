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

    // Navigate to settings via data-testid or aria-label
    const navigated = await browser.execute(() => {
      // Try data-testid first (most reliable)
      const testIdBtn = document.querySelector('[data-testid="settings-nav-btn"]') as HTMLElement;
      if (testIdBtn) {
        testIdBtn.click();
        return true;
      }

      // Fallback: aria-label containing "设置" or "Setting"
      const allButtons = Array.from(document.querySelectorAll('button[type="button"]'));
      for (const btn of allButtons) {
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (ariaLabel.includes('设置') || ariaLabel.toLowerCase().includes('setting')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (!navigated) {
      console.log('[SettingsPage] Could not find settings button, may already be on settings view');
    }

    await browser.pause(800);
    await this.waitForReactReady();

    // Wait for settings to be loaded (data-settings-loaded attribute)
    try {
      await browser.waitUntil(
        async () => {
          const loaded = await browser.execute(() => !!document.querySelector('[data-settings-loaded]'));
          return !!loaded;
        },
        { timeout: 10_000, timeoutMsg: 'Settings did not load within 10s' }
      );
    } catch {
      console.log('[SettingsPage] Settings load wait timed out, continuing...');
    }
  }

  /**
   * Open a specific settings tab by value (e.g. 'general', 'proxy', 'auth', etc.)
   * Uses JavaScript execution to avoid WKWebView CSS selector issues with commas.
   */
  async openTab(tabKey: string): Promise<void> {
    // Radix Tabs does not set data-value on the DOM element.
    // The tab ID is ${baseId}-trigger-${value}. We find the tab by checking
    // if the id ENDS WITH "-trigger-${tabKey}".
    const clicked = await browser.execute((key) => {
      const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
      for (const tab of tabs) {
        const id = tab.getAttribute('id') || '';
        if (id.endsWith('-trigger-' + key)) {
          (tab as HTMLElement).click();
          return true;
        }
        // Also check data-value and value as fallbacks
        const val = tab.getAttribute('data-value') || tab.getAttribute('value') || '';
        if (val === key) {
          (tab as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, tabKey);

    if (!clicked) {
      console.log(`[SettingsPage] Tab "${tabKey}" not found via JS, trying CSS...`);
      try {
        const tab = await $(`[role="tab"][id$="-trigger-${tabKey}"]`);
        if (await tab.isExisting()) {
          await tab.waitForClickable({ timeout: 5000 });
          await tab.click();
        }
      } catch {
        console.log(`[SettingsPage] Tab "${tabKey}" not found`);
      }
    }

    await browser.pause(500);
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
