/**
 * SettingsPage - Page object for settings management
 */

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export class SettingsPage extends CrabNebulaBasePage {
  /**
   * Open settings by clicking the settings button in the sidebar
   */
  async open(): Promise<void> {
    await this.waitForReactReady();

    // Try native WebDriver click first (most reliable in WKWebView)
    let navigated = false;
    try {
      const btn = await $('[data-testid="settings-nav-btn"]');
      if (await btn.isExisting()) {
        await btn.click();
        navigated = true;
      }
    } catch { /* fall through */ }

    if (!navigated) {
      navigated = await browser.execute(() => {
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
    }

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
   * Uses native WebDriver click for WKWebView reliability, then verifies the tab actually switched.
   */
  async openTab(tabKey: string): Promise<void> {
    // Strategy 1: Use data-testid (most reliable)
    let clicked = false;
    try {
      const tab = await $(`[data-testid="settings-tab-${tabKey}"]`);
      if (await tab.isExisting()) {
        await tab.click();
        clicked = true;
      }
    } catch { /* fall through */ }

    // Strategy 2: Native WebDriver click by Radix ID pattern
    if (!clicked) {
      try {
        const tab = await $(`[role="tab"][id$="-trigger-${tabKey}"]`);
        if (await tab.isExisting()) {
          await tab.click();
          clicked = true;
        }
      } catch { /* fall through */ }
    }

    // Strategy 3: JavaScript click fallback
    if (!clicked) {
      clicked = await browser.execute((key) => {
        // Try data-testid first
        const testIdTab = document.querySelector(`[data-testid="settings-tab-${key}"]`);
        if (testIdTab) {
          (testIdTab as HTMLElement).click();
          return true;
        }
        // Then try role="tab" with ID pattern
        const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
        for (const tab of tabs) {
          const id = tab.getAttribute('id') || '';
          if (id.endsWith('-trigger-' + key)) {
            (tab as HTMLElement).click();
            return true;
          }
          const val = tab.getAttribute('data-value') || tab.getAttribute('value') || '';
          if (val === key) {
            (tab as HTMLElement).click();
            return true;
          }
        }
        return false;
      }, tabKey);
    }

    if (!clicked) {
      console.log(`[SettingsPage] Tab "${tabKey}" not found`);
      return;
    }

    // Wait for the SPECIFIC tab to actually become active (not just any tab)
    try {
      await browser.waitUntil(
        async () => {
          const isActive = await browser.execute((key) => {
            const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
            for (const tab of tabs) {
              const id = tab.getAttribute('id') || '';
              const val = tab.getAttribute('data-value') || tab.getAttribute('value') || '';
              if (id.endsWith('-trigger-' + key) || val === key) {
                return (
                  tab.getAttribute('data-state') === 'active' ||
                  tab.getAttribute('aria-selected') === 'true'
                );
              }
            }
            return false;
          }, tabKey);
          return !!isActive;
        },
        { timeout: 8_000, timeoutMsg: `Tab "${tabKey}" did not become active within 8s` }
      );
    } catch (e) {
      console.log(`[SettingsPage] Tab "${tabKey}" state check timed out: ${e}`);
    }

    // Extra wait for framer-motion animation + React render
    await browser.pause(400);
  }

  /**
   * Click an accordion trigger by text content using native WebDriver click.
   * Returns true if the accordion was found and clicked.
   */
  async openAccordion(textHints: string[]): Promise<boolean> {
    // Try native WebDriver click via attribute-based approach
    for (const hint of textHints) {
      // Find the element via JS, mark it with a temp attribute, then native-click it
      const uid = `wdio-acc-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      const found = await browser.execute((text, attrKey) => {
        const triggers = Array.from(document.querySelectorAll('[data-radix-accordion-trigger], button[data-state]'));
        const allClickable = Array.from(document.querySelectorAll('[role="button"], button'));
        const combined = [...new Set([...triggers, ...allClickable])];
        const el = combined.find(
          (el) => (el as HTMLElement).innerText?.includes(text) || el.textContent?.includes(text)
        );
        if (el) {
          el.setAttribute(attrKey, 'true');
          return true;
        }
        return false;
      }, hint, uid);

      if (found) {
        try {
          const el = await $(`[${uid}]`);
          if (await el.isExisting()) {
            await el.click();
            await browser.pause(600);
            return true;
          }
        } catch { /* fall through */ }
      }
    }

    // Fallback: JavaScript click
    const clicked = await browser.execute((hints) => {
      const triggers = Array.from(document.querySelectorAll('[role="button"], button'));
      for (const hint of hints) {
        const el = triggers.find(
          (b) => (b as HTMLElement).innerText?.includes(hint) || b.textContent?.includes(hint)
        );
        if (el) {
          (el as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, textHints);

    if (clicked) {
      await browser.pause(600);
    }
    return !!clicked;
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
