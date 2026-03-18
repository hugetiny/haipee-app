/**
 * SettingsPage - Page object for settings management
 */

import { TauriBasePage } from './TauriBasePage.ts';

export class SettingsPage extends TauriBasePage {
  /**
   * Open settings
   */
  async open(): Promise<void> {
    await this.navigateTo('Settings');
    await this.waitForReactReady();
  }

  /**
   * Open a specific settings tab
   */
  async openTab(tabName: string): Promise<void> {
    const tab = await $(`[role="tab"]*="${tabName}", button*="${tabName}"`);
    await tab.waitForClickable({ timeout: 5000 });
    await tab.click();
    await browser.pause(300);
  }

  /**
   * Toggle a switch by test id or label
   */
  async toggleSwitch(name: string): Promise<boolean> {
    const toggle = await $(`[data-testid="${name}-toggle"], [aria-label*="${name}"]`);
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
    const toggle = await $(`[data-testid="${name}-toggle"], [aria-label*="${name}"]`);
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
    const langSelector = await $('[data-testid="language-selector"], select[name="language"]');
    await langSelector.waitForExist({ timeout: 5000 });

    if (await langSelector.getTagName() === 'select') {
      await langSelector.selectByAttribute('value', lang);
    } else {
      await langSelector.click();
      await browser.pause(300);
      const option = await $(`[data-value="${lang}"], button*="${lang === 'zh' ? '中文' : 'English'}"`);
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
    const themeSelector = await $('[data-testid="theme-selector"], [data-theme-selector]');
    if (!await themeSelector.isExisting()) {
      // Try finding theme options directly
      const themeOption = await $(`[data-theme="${theme}"], button*="${theme}"`);
      if (await themeOption.isExisting()) {
        await themeOption.click();
        await browser.pause(500);
      }
      return;
    }

    await themeSelector.click();
    await browser.pause(300);

    const option = await $(`[data-value="${theme}"], [role="option"]*="${theme}"`);
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
      const el = await $(`[data-testid="setting-${key}"], [data-setting="${key}"]`);
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
    const saveButton = await $('button*="保存", button*="Save"');
    if (await saveButton.isExisting()) {
      await saveButton.click();
      await browser.pause(500);
    }
  }

  /**
   * Reset settings to defaults
   */
  async resetToDefaults(): Promise<void> {
    const resetButton = await $('button*="重置", button*="Reset"');
    if (await resetButton.isExisting()) {
      await resetButton.click();
      await browser.pause(300);

      // Confirm reset
      const confirmButton = await $('button*="确认", button*="Confirm"');
      if (await confirmButton.isExisting()) {
        await confirmButton.click();
        await browser.pause(500);
      }
    }
  }
}

export const settingsPage = new SettingsPage();
