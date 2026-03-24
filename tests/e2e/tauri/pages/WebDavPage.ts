/// <reference types="@wdio/globals/types" />
/**
 * WebDavPage - Page object for WebDAV sync settings
 */

import { TauriBasePage } from './TauriBasePage';

export class WebDavPage extends TauriBasePage {
  /**
   * Open WebDAV settings in settings dialog
   */
  async openWebDavSettings(): Promise<void> {
    // Navigate to settings
    const settingsBtn = await $('[data-testid="settings-btn"], button[aria-label*="设置"], button[aria-label*="Settings"]');
    if (await settingsBtn.isExisting()) {
      await settingsBtn.click();
      await browser.pause(500);
    }

    // Click on sync/webdav tab
    const webdavTab = await $('[data-testid="settings-tab-sync"], [data-testid="settings-tab-webdav"]');
    if (await webdavTab.isExisting()) {
      await webdavTab.click();
      await browser.pause(300);
      return;
    }

    await browser.execute(() => {
      const tabs = Array.from(document.querySelectorAll('button, [role="tab"]'));
      const target = tabs.find((el) => {
        const text = el.textContent || '';
        const aria = el.getAttribute('aria-label') || '';
        return text.includes('同步') || text.includes('Sync') ||
          aria.includes('同步') || aria.includes('Sync');
      });
      target?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await browser.pause(300);
  }

  /**
   * Check if WebDAV is configured
   */
  async isConfigured(): Promise<boolean> {
    try {
      const settings = await this.invokeIPC<{ webdavUrl?: string }>('get_settings');
      return !!(settings.webdavUrl);
    } catch {
      return false;
    }
  }

  /**
   * Get WebDAV URL
   */
  async getUrl(): Promise<string | null> {
    try {
      const settings = await this.invokeIPC<{ webdavUrl?: string }>('get_settings');
      return settings.webdavUrl ?? null;
    } catch {
      return null;
    }
  }

  /**
   * Set WebDAV URL
   */
  async setUrl(url: string): Promise<void> {
    const urlInput = await $('[data-testid="webdav-url-input"], input[name="webdavUrl"], input[placeholder*="webdav"]');
    if (await urlInput.isExisting()) {
      await urlInput.clearValue();
      await urlInput.addValue(url);
      await browser.pause(200);
    }
  }

  /**
   * Set WebDAV username
   */
  async setUsername(username: string): Promise<void> {
    const userInput = await $('[data-testid="webdav-username-input"], input[name="webdavUsername"]');
    if (await userInput.isExisting()) {
      await userInput.clearValue();
      await userInput.addValue(username);
      await browser.pause(200);
    }
  }

  /**
   * Set WebDAV password
   */
  async setPassword(password: string): Promise<void> {
    const passInput = await $('[data-testid="webdav-password-input"], input[name="webdavPassword"], input[type="password"]');
    if (await passInput.isExisting()) {
      await passInput.clearValue();
      await passInput.addValue(password);
      await browser.pause(200);
    }
  }

  /**
   * Trigger manual sync
   */
  async triggerSync(): Promise<boolean> {
    try {
      await this.invokeIPC('trigger_webdav_sync');
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get sync status
   */
  async getSyncStatus(): Promise<{ status: string; lastSync?: string; error?: string }> {
    try {
      const result = await this.invokeIPC<{
        status?: string;
        lastSync?: string;
        error?: string;
      } | null>('get_webdav_sync_status');
      if (!result || typeof result !== 'object') {
        return { status: 'unknown' };
      }
      if (typeof result.status !== 'string') {
        return { status: 'unknown', lastSync: result.lastSync, error: result.error };
      }
      return result as { status: string; lastSync?: string; error?: string };
    } catch {
      return { status: 'unknown' };
    }
  }

  /**
   * Enable auto sync
   */
  async enableAutoSync(enabled: boolean): Promise<void> {
    const toggle = await $('[data-testid="webdav-auto-sync-toggle"], input[name="autoSync"]');
    if (await toggle.isExisting()) {
      const isChecked = await toggle.isSelected();
      if (isChecked !== enabled) {
        await toggle.click();
        await browser.pause(200);
      }
    }
  }

  /**
   * Save WebDAV settings
   */
  async saveSettings(): Promise<void> {
    const saveBtn = await $('[data-testid="webdav-save-btn"]');
    if (await saveBtn.isExisting()) {
      await saveBtn.click();
      await browser.pause(500);
      return;
    }

    await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const target = buttons.find((btn) => {
        const text = btn.textContent || '';
        const aria = btn.getAttribute('aria-label') || '';
        return text.includes('保存') || text.includes('Save') ||
          aria.includes('保存') || aria.includes('Save');
      });
      target?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await browser.pause(500);
  }

  /**
   * Test WebDAV connection
   */
  async testConnection(): Promise<boolean> {
    try {
      const result = await this.invokeIPC<{ success: boolean }>('test_webdav_connection');
      return result.success;
    } catch {
      return false;
    }
  }
}

export const webDavPage = new WebDavPage();
