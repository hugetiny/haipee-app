/// <reference types="@wdio/globals/types" />
/**
 * WebDavPage - Page object for WebDAV sync settings
 */

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export class WebDavPage extends CrabNebulaBasePage {
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
    const webdavTab = await $('[data-testid="settings-tab-sync"], [data-testid="settings-tab-webdav"], button:contains("同步"), button:contains("Sync")');
    if (await webdavTab.isExisting()) {
      await webdavTab.click();
      await browser.pause(300);
    }
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
      return await this.invokeIPC('get_webdav_sync_status');
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
    const saveBtn = await $('[data-testid="webdav-save-btn"], button:contains("保存"), button:contains("Save")');
    if (await saveBtn.isExisting()) {
      await saveBtn.click();
      await browser.pause(500);
    }
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