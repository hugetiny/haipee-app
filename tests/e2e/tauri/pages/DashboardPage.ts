/**
 * DashboardPage - Page object for provider management
 */

import { TauriBasePage } from './TauriBasePage.ts';

export interface ProviderFormData {
  name: string;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export class DashboardPage extends TauriBasePage {
  /**
   * Open the dashboard
   */
  async open(): Promise<void> {
    await this.navigateTo('Dashboard');
    await this.waitForReactReady();
  }

  /**
   * Get all provider cards
   */
  async getProviderCards(): Promise<WebdriverIO.Element[]> {
    const cards = await $$('[data-testid="provider-card"], .provider-card');
    return [...cards] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get provider count
   */
  async getProviderCount(): Promise<number> {
    const cards = await this.getProviderCards();
    return cards.length;
  }

  /**
   * Click add provider button
   */
  async clickAddProvider(): Promise<void> {
    const addButton = await $('button[aria-label*="添加"], button*="添加供应商", button*="Add Provider"');
    await addButton.waitForClickable({ timeout: 5000 });
    await addButton.click();
    await browser.pause(300);
  }

  /**
   * Fill provider form
   */
  async fillProviderForm(data: ProviderFormData): Promise<void> {
    const form = await $('[data-testid="provider-form"], form');
    await form.waitForExist({ timeout: 5000 });

    // Fill name
    const nameInput = await form.$('input[name="name"], input[placeholder*="名称"], input[placeholder*="Name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue(data.name);
    }

    // Fill API key
    if (data.apiKey) {
      const apiKeyInput = await form.$('input[name="apiKey"], input[name="api_key"], input[placeholder*="API"], input[placeholder*="Token"]');
      if (await apiKeyInput.isExisting()) {
        await apiKeyInput.setValue(data.apiKey);
      }
    }

    // Fill base URL
    if (data.baseUrl) {
      const urlInput = await form.$('input[name="baseUrl"], input[name="base_url"], input[placeholder*="URL"], input[placeholder*="Endpoint"]');
      if (await urlInput.isExisting()) {
        await urlInput.setValue(data.baseUrl);
      }
    }

    // Fill model
    if (data.model) {
      const modelInput = await form.$('input[name="model"], input[placeholder*="Model"]');
      if (await modelInput.isExisting()) {
        await modelInput.setValue(data.model);
      }
    }
  }

  /**
   * Save provider
   */
  async saveProvider(): Promise<void> {
    const saveButton = await $('button[type="submit"], button*="保存", button*="Save"');
    await saveButton.waitForClickable({ timeout: 5000 });
    await saveButton.click();
    await browser.pause(500);
  }

  /**
   * Cancel provider form
   */
  async cancelProviderForm(): Promise<void> {
    const cancelButton = await $('button*="取消", button*="Cancel"');
    if (await cancelButton.isExisting()) {
      await cancelButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Add a new provider (full flow)
   */
  async addProvider(data: ProviderFormData): Promise<void> {
    await this.clickAddProvider();
    await this.fillProviderForm(data);
    await this.saveProvider();
  }

  /**
   * Delete a provider by name
   */
  async deleteProvider(name: string): Promise<void> {
    // Find provider card
    const cards = await this.getProviderCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        // Find delete button
        const deleteButton = await card.$('button[aria-label*="删除"], button[aria-label*="Delete"], button*="删除"');
        if (await deleteButton.isExisting()) {
          await deleteButton.click();
          await browser.pause(300);

          // Confirm deletion
          const confirmButton = await $('button*="确认", button*="Confirm", button*="Yes"');
          if (await confirmButton.isExisting()) {
            await confirmButton.click();
            await browser.pause(500);
          }
        }
        return;
      }
    }
  }

  /**
   * Search providers
   */
  async searchProviders(query: string): Promise<void> {
    const searchInput = await $('input[placeholder*="搜索"], input[placeholder*="Search"], input[type="search"]');
    if (await searchInput.isExisting()) {
      await searchInput.setValue(query);
      await browser.pause(300);
    }
  }

  /**
   * Get visible provider names
   */
  async getVisibleProviderNames(): Promise<string[]> {
    const cards = await this.getProviderCards();
    const names: string[] = [];
    for (const card of cards) {
      const nameEl = await card.$('[data-testid="provider-name"], h3, h4');
      if (await nameEl.isExisting()) {
        names.push(await nameEl.getText());
      }
    }
    return names;
  }

  /**
   * Switch to a provider by name
   */
  async switchProvider(name: string): Promise<boolean> {
    const cards = await this.getProviderCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        // Click on the provider card to select it
        await card.click();
        await browser.pause(300);

        // Look for switch/activate button
        const switchBtn = await card.$(
          'button[aria-label*="切换"], button[aria-label*="Switch"], button[aria-label*="激活"], button[aria-label*="Activate"]'
        );
        if (await switchBtn.isExisting()) {
          await switchBtn.click();
          await browser.pause(500);
          return true;
        }

        // Alternative: check for a direct "use" or "select" action
        const useBtn = await card.$('button*="使用"], button*="Use"], button*="选择"], button*="Select"]');
        if (await useBtn.isExisting()) {
          await useBtn.click();
          await browser.pause(500);
          return true;
        }

        // If card click already activates it
        return true;
      }
    }
    return false;
  }
}

export const dashboardPage = new DashboardPage();
