/// <reference types="@wdio/globals/types" />
/**
 * UniversalProviderPage - Page object for Universal Provider management
 */

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export interface UniversalProviderData {
  name: string;
  apiKey: string;
  baseUrl?: string;
  model?: string;
}

/**
 * UniversalProviderPage - Page object for managing universal providers
 * Used for providers that work across multiple AI CLI tools
 */
export class UniversalProviderPage extends CrabNebulaBasePage {
  /**
   * Wait for universal provider page to load
   */
  async waitForLoad(): Promise<void> {
    await browser.waitUntil(
      async () => await this.pageContainsAnyText(['Universal', '通用', 'Provider']),
      { timeout: 10_000, timeoutMsg: 'Universal provider page did not load' }
    );
  }

  /**
   * Get provider count
   */
  async getProviderCount(): Promise<number> {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    return providers.length;
  }

  /**
   * Get all provider names
   */
  async getProviderNames(): Promise<string[]> {
    return browser.execute(() => {
      const providers = document.querySelectorAll('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
      return Array.from(providers).map(p => {
        const nameEl = p.querySelector('[data-testid="provider-name"], h3, h4, [class*="name"]');
        return nameEl?.textContent?.trim() ?? '';
      }).filter(n => n);
    });
  }

  /**
   * Check if provider exists by name
   */
  async providerExists(name: string): Promise<boolean> {
    const names = await this.getProviderNames();
    return names.some(n => n.includes(name));
  }

  /**
   * Add a new universal provider
   */
  async addProvider(data: UniversalProviderData): Promise<void> {
    const addBtn = await $('[data-testid="universal-provider-add-btn"], [data-testid="add-provider-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      // Fill name
      const nameInput = await $('[data-testid="provider-name-input"]');
      if (await nameInput.isExisting()) {
        await nameInput.clearValue();
        await nameInput.setValue(data.name);
        await browser.pause(200);
      }

      // Fill API key
      const keyInput = await $('[data-testid="provider-api-key-input"]');
      if (await keyInput.isExisting()) {
        await keyInput.clearValue();
        await keyInput.setValue(data.apiKey);
        await browser.pause(200);
      }

      // Fill base URL if provided
      if (data.baseUrl) {
        const urlInput = await $('[data-testid="provider-base-url-input"]');
        if (await urlInput.isExisting()) {
          await urlInput.clearValue();
          await urlInput.setValue(data.baseUrl);
          await browser.pause(200);
        }
      }

      // Fill model if provided
      if (data.model) {
        const modelInput = await $('[data-testid="provider-model-input"]');
        if (await modelInput.isExisting()) {
          await modelInput.clearValue();
          await modelInput.setValue(data.model);
          await browser.pause(200);
        }
      }

      // Save
      const saveBtn = await $('[data-testid="provider-save-btn"]');
      if (await saveBtn.isExisting()) {
        await saveBtn.click();
        await browser.pause(500);
      }
    }
  }

  /**
   * Delete a provider by name
   */
  async deleteProvider(name: string): Promise<boolean> {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    for (const provider of providers) {
      const text = await provider.getText();
      if (text.includes(name)) {
        const deleteBtn = await provider.$('button[aria-label*="delete"], button[aria-label*="删除"], [data-testid="delete-provider-btn"]');
        if (await deleteBtn.isExisting()) {
          await deleteBtn.click();
          await browser.pause(300);

          // Confirm deletion
          const confirmBtn = await $('button:has-text("确认"), button:has-text("Confirm"), button:has-text("删除")');
          if (await confirmBtn.isExisting()) {
            await confirmBtn.click();
            await browser.pause(500);
          }
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Edit a provider by name
   */
  async editProvider(name: string, newData: Partial<UniversalProviderData>): Promise<boolean> {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    for (const provider of providers) {
      const text = await provider.getText();
      if (text.includes(name)) {
        const editBtn = await provider.$('button[aria-label*="edit"], button[aria-label*="编辑"], [data-testid="edit-provider-btn"]');
        if (await editBtn.isExisting()) {
          await editBtn.click();
          await browser.pause(500);

          // Update fields
          if (newData.name) {
            const nameInput = await $('[data-testid="provider-name-input"]');
            if (await nameInput.isExisting()) {
              await nameInput.clearValue();
              await nameInput.setValue(newData.name);
              await browser.pause(200);
            }
          }

          if (newData.apiKey) {
            const keyInput = await $('[data-testid="provider-api-key-input"]');
            if (await keyInput.isExisting()) {
              await keyInput.clearValue();
              await keyInput.setValue(newData.apiKey);
              await browser.pause(200);
            }
          }

          // Save
          const saveBtn = await $('[data-testid="provider-save-btn"]');
          if (await saveBtn.isExisting()) {
            await saveBtn.click();
            await browser.pause(500);
          }
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Sync providers with all apps
   */
  async sync(): Promise<void> {
    const syncBtn = await $('[data-testid="universal-sync-btn"]');
    if (await syncBtn.isExisting()) {
      await syncBtn.click();
      await browser.pause(1000);
    }
  }

  /**
   * Toggle provider enabled state for a specific app
   */
  async toggleProviderForApp(providerName: string, appId: string): Promise<boolean> {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    for (const provider of providers) {
      const text = await provider.getText();
      if (text.includes(providerName)) {
        const appToggle = await provider.$(`[data-testid="app-toggle-${appId}"], [data-app="${appId}"] button[role="switch"]`);
        if (await appToggle.isExisting()) {
          await appToggle.click();
          await browser.pause(300);
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Get provider details by name
   */
  async getProviderDetails(name: string): Promise<Record<string, string> | null> {
    const providers = await $$('[data-testid="universal-provider-item"], [data-testid="provider-card"]');
    for (const provider of providers) {
      const text = await provider.getText();
      if (text.includes(name)) {
        return browser.execute((el) => {
          const details: Record<string, string> = {};
          const nameEl = el.querySelector('[data-testid="provider-name"], h3, h4');
          if (nameEl) details.name = nameEl.textContent?.trim() ?? '';

          const keyEl = el.querySelector('[data-testid="provider-api-key"]');
          if (keyEl) details.apiKey = keyEl.textContent?.trim() ?? '';

          const urlEl = el.querySelector('[data-testid="provider-base-url"]');
          if (urlEl) details.baseUrl = urlEl.textContent?.trim() ?? '';

          return details;
        }, provider);
      }
    }
    return null;
  }
}

// Export singleton instance
export const universalProviderPage = new UniversalProviderPage();