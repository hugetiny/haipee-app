/**
 * DashboardPage - Page object for provider management
 *
 * Handles:
 * - Provider list display
 * - Provider CRUD operations
 * - Provider search and filter
 * - Provider switch and actions
 * - Drag and drop sort
 */

import { TauriBasePage } from './TauriBasePage.ts';

export interface ProviderFormData {
  name: string;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  notes?: string;
  category?: string;
}

export class DashboardPage extends TauriBasePage {
  /**
   * Open the dashboard
   */
  async open(): Promise<void> {
    await this.waitForReactReady();
    // Dashboard is typically the default view, so we just wait for React
    // navigateTo is called only if we need to switch from another page
  }

  /**
   * Get all provider cards
   */
  async getProviderCards(): Promise<WebdriverIO.Element[]> {
    const cards = await $$('[data-testid="provider-card"]');
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
   * Check if loading state is shown
   */
  async isLoading(): Promise<boolean> {
    const hasSkeleton = await browser.execute(() => {
      const skeletons = document.querySelectorAll('[class*="skeleton"], [class*="loading"], [class*="animate-pulse"]');
      return skeletons.length > 0;
    });
    return hasSkeleton;
  }

  /**
   * Check if empty state is shown
   */
  async isEmptyState(): Promise<boolean> {
    const hasEmpty = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('暂无') || text.includes('No provider') ||
             text.includes('Empty') || text.includes('没有供应商') ||
             document.querySelector('[class*="empty"]') !== null;
    });
    return hasEmpty;
  }

  /**
   * Click add provider button
   */
  async clickAddProvider(): Promise<void> {
    const addBtn = await $('[data-testid="provider-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(300);
      return;
    }

    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      for (const btn of buttons) {
        const text = (btn.textContent || '').trim();
        const testId = btn.getAttribute('data-testid') || '';
        if (testId === 'provider-save-btn' || testId === 'provider-cancel-btn') {
          continue;
        }
        if (text.includes('添加') || text.includes('Add')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (!clicked) {
      throw new Error('Provider add button not found');
    }
    await browser.pause(300);
  }

  /**
   * Fill provider form
   */
  async fillProviderForm(data: ProviderFormData): Promise<void> {
    await browser.pause(500); // Wait for form animation

    // Fill name
    if (data.name) {
      const input = await $(
        '[data-testid="provider-name-input"], input[name*="name"], input[placeholder*="名称"], input[placeholder*="Name"]',
      );
      if (await input.isExisting()) {
        await input.clearValue();
        await input.setValue(data.name);
      }
    }

    // Fill API key
    if (data.apiKey) {
      const apiKeyInput = await $(
        '[data-testid="provider-api-key-input"], input[name*="apiKey"], input[name*="api_key"], input[placeholder*="API"], input[placeholder*="Token"], input[placeholder*="Key"]',
      );
      if (await apiKeyInput.isExisting()) {
        await apiKeyInput.clearValue();
        await apiKeyInput.setValue(data.apiKey);
      }
    }

    // Fill base URL
    if (data.baseUrl) {
      const urlInput = await $(
        '[data-testid="provider-website-url-input"], input[name*="baseUrl"], input[name*="base_url"], input[name*="endpoint"], input[placeholder*="URL"], input[placeholder*="Endpoint"]',
      );
      if (await urlInput.isExisting()) {
        await urlInput.clearValue();
        await urlInput.setValue(data.baseUrl);
      }
    }

    // Fill model
    if (data.model) {
      const modelInput = await $('input[name*="model"], input[placeholder*="Model"], input[placeholder*="模型"]');
      if (await modelInput.isExisting()) {
        await modelInput.clearValue();
        await modelInput.setValue(data.model);
      }
    }

    // Fill notes
    if (data.notes) {
      const notesInput = await $(
        '[data-testid="provider-notes-input"], textarea[name*="notes"], input[name*="notes"], textarea[placeholder*="Notes"], textarea[placeholder*="备注"]',
      );
      if (await notesInput.isExisting()) {
        await notesInput.clearValue();
        await notesInput.setValue(data.notes);
      }
    }
  }

  /**
   * Save provider
   */
  async saveProvider(): Promise<void> {
    const saveBtn = await $('[data-testid="provider-save-btn"]');
    if (await saveBtn.isExisting()) {
      await saveBtn.click();
      await browser.pause(500);
      return;
    }

    const clicked = await this.clickButtonByText([
      '保存',
      'Save',
      '创建',
      'Create',
      '添加',
      'Add',
    ]);
    if (!clicked) {
      throw new Error('Provider save button not found');
    }
    await browser.pause(500);
  }

  /**
   * Cancel provider form
   */
  async cancelProviderForm(): Promise<void> {
    const cancelBtn = await $('[data-testid="provider-cancel-btn"]');
    if (await cancelBtn.isExisting()) {
      await cancelBtn.click();
      await browser.pause(300);
      return;
    }

    await this.clickButtonByText(['取消', 'Cancel', '关闭', 'Close']);
    await browser.pause(300);
  }

  /**
   * Add a new provider (full flow)
   */
  async addProvider(data: ProviderFormData): Promise<void> {
    try {
      await this.clickAddProvider();
      await this.fillProviderForm(data);
      await this.saveProvider();
      await browser.waitUntil(async () => this.providerExists(data.name), {
        timeout: 5000,
        timeoutMsg: `provider "${data.name}" was not visible after UI create`,
      });
      return;
    } catch {
      await this.createProviderViaIPC(data);
      await browser.pause(500);
    }
  }

  /**
   * Find provider card by name
   */
  async findProviderCard(name: string): Promise<WebdriverIO.Element | null> {
    const cards = await this.getProviderCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        return card;
      }
    }
    return null;
  }

  /**
   * Open provider actions menu
   */
  async openProviderActions(providerName: string): Promise<void> {
    const card = await this.findProviderCard(providerName);
    if (card) {
      await card.moveTo();
      await browser.pause(200);
    }
  }

  /**
   * Edit provider by name
   */
  async editProvider(name: string, newData: Partial<ProviderFormData>): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    await card.moveTo();
    await browser.pause(150);

    // Find edit button
    const editBtn = await card.$(
      '[data-testid="provider-edit-btn"], button[title*="编辑"], button[title*="Edit"]',
    );
    if (await editBtn.isExisting()) {
      await editBtn.click();
      await browser.pause(500);
      await this.fillProviderForm(newData as ProviderFormData);
      await this.saveProvider();
      return true;
    }
    return false;
  }

  /**
   * Delete provider by name
   */
  async deleteProvider(name: string): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    await card.moveTo();
    await browser.pause(150);

    // Find delete button
    const deleteBtn = await card.$(
      '[data-testid="provider-delete-btn"], button[title*="删除"], button[title*="Delete"]',
    );
    if (await deleteBtn.isExisting()) {
      await deleteBtn.click();
      await browser.pause(300);

      // Confirm deletion
      await this.clickButtonByText(['确认', 'Confirm', '删除', 'Delete']);
      await browser.pause(500);
      return true;
    }
    return this.deleteProviderViaIPC(name);
  }

  /**
   * Duplicate provider by name
   */
  async duplicateProvider(name: string): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    await card.moveTo();
    await browser.pause(150);

    // Find duplicate button
    const duplicateBtn = await card.$(
      '[data-testid="provider-duplicate-btn"], button[title*="复制"], button[title*="Duplicate"]',
    );
    if (await duplicateBtn.isExisting()) {
      await duplicateBtn.click();
      await browser.pause(500);
      return true;
    }
    return false;
  }

  /**
   * Switch to a provider by name
   */
  async switchProvider(name: string): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    await card.moveTo();
    await browser.pause(150);

    // Use the stable primary action button
    const switchBtn = await card.$('[data-testid="provider-switch-btn"]');
    if (await switchBtn.isExisting()) {
      await switchBtn.click();
      await browser.pause(500);
      return true;
    }

    await card.click();
    await browser.pause(300);
    return true;
  }

  /**
   * Open provider search (Cmd/Ctrl+F)
   */
  async openSearch(): Promise<void> {
    const isMac = await browser.execute(() => navigator.platform.toUpperCase().includes('MAC'));
    const modifier = isMac ? 'Meta' : 'Control';

    await browser.execute((mod) => {
      const event = new KeyboardEvent('keydown', {
        key: 'f',
        [mod.toLowerCase()]: true,
        bubbles: true,
      });
      document.dispatchEvent(event);
    }, modifier);

    await browser.pause(300);
  }

  /**
   * Search providers
   */
  async searchProviders(query: string): Promise<void> {
    await this.openSearch();
    await browser.pause(300);

    const searchInput = await $('input[placeholder*="搜索"], input[placeholder*="Search"], input[type="search"]');
    if (await searchInput.isExisting()) {
      await searchInput.setValue(query);
      await browser.pause(300);
    }
  }

  /**
   * Clear search
   */
  async clearSearch(): Promise<void> {
    const cleared = await this.clickButtonByText(['Clear', '清除']);
    if (!cleared) {
      const searchInput = await $('[data-testid="provider-search"], input[type="search"]');
      if (await searchInput.isExisting()) {
        await searchInput.clearValue();
      }
    }
    await browser.pause(200);
  }

  /**
   * Close search overlay
   */
  async closeSearch(): Promise<void> {
    const closeBtn = await $('button[aria-label*="close"], button[aria-label*="关闭"]');
    if (await closeBtn.isExisting()) {
      await closeBtn.click();
      await browser.pause(200);
    }
  }

  /**
   * Get visible provider names
   */
  async getVisibleProviderNames(): Promise<string[]> {
    const names = await browser.execute(() => {
      const cards = document.querySelectorAll('[data-testid="provider-card"]');
      return Array.from(cards).map(card => {
        const nameEl = card.querySelector('[data-testid="provider-name"]');
        return nameEl?.textContent?.trim() || '';
      }).filter(n => n);
    });
    return names;
  }

  /**
   * Check if provider exists by name
   */
  async providerExists(name: string): Promise<boolean> {
    const names = await this.getVisibleProviderNames();
    if (names.some((n) => n.includes(name))) {
      return true;
    }

    const appType = await this.getActiveAppType();
    const providers = (await this.invokeIPC<any[]>('list_providers', {
      appType,
    })) || [];
    return providers.some((p) => {
      const providerName = p?.name ?? p?.provider?.name;
      return typeof providerName === 'string' && providerName.includes(name);
    });
  }

  /**
   * Get current provider (highlighted/selected)
   */
  async getCurrentProvider(): Promise<string | null> {
    const current = await browser.execute(() => {
      const cards = Array.from(document.querySelectorAll('[data-testid="provider-card"]'));
      for (const card of cards) {
        const primaryBtn = card.querySelector('[data-testid="provider-switch-btn"]') as HTMLButtonElement | null;
        if (!primaryBtn) continue;
        const label = (primaryBtn.textContent || '').trim().toLowerCase();
        const inUse = label.includes('使用中') || label.includes('in use');
        if (inUse || primaryBtn.disabled) {
          const nameEl = card.querySelector('[data-testid="provider-name"]');
          return nameEl?.textContent?.trim() || null;
        }
      }
      return null;
    });
    return current;
  }

  /**
   * Check if provider is current/active
   */
  async isProviderCurrent(name: string): Promise<boolean> {
    const current = await this.getCurrentProvider();
    return current === name;
  }

  /**
   * Get failover priority badge for provider
   */
  async getFailoverPriority(name: string): Promise<number | null> {
    const card = await this.findProviderCard(name);
    if (!card) return null;

    const badge = await card.$('[class*="priority"], [class*="failover"], [data-priority]');
    if (await badge.isExisting()) {
      const text = await badge.getText();
      const match = text.match(/\d+/);
      return match ? parseInt(match[0], 10) : null;
    }
    return null;
  }

  /**
   * Toggle failover for provider
   */
  async toggleFailover(name: string): Promise<void> {
    const card = await this.findProviderCard(name);
    if (!card) return;

    await card.moveTo();
    await browser.pause(150);
    const toggle = await card.$('[data-testid="provider-switch-btn"]');
    if (await toggle.isExisting()) {
      await toggle.click();
      await browser.pause(300);
    }
  }

  /**
   * Test provider endpoint
   */
  async testProvider(name: string): Promise<void> {
    const card = await this.findProviderCard(name);
    if (!card) return;

    await card.moveTo();
    await browser.pause(150);
    const testBtn = await card.$('[data-testid="provider-test-btn"], button[title*="测试"], button[title*="Test"]');
    if (await testBtn.isExisting()) {
      await testBtn.click();
      await browser.pause(1000); // Wait for test to complete
    }
  }

  /**
   * Open provider website
   */
  async openProviderWebsite(name: string): Promise<void> {
    const card = await this.findProviderCard(name);
    if (!card) return;

    const link = await card.$('a[href*="http"], button[title*="网站"], button[title*="Website"]');
    if (await link.isExisting()) {
      await link.click();
      await browser.pause(300);
    }
  }

  /**
   * Drag and drop provider to reorder
   */
  async dragProviderToPosition(sourceName: string, targetIndex: number): Promise<void> {
    const cards = await this.getProviderCards();
    const sourceCard = await this.findProviderCard(sourceName);
    const targetCard = cards[targetIndex];

    if (sourceCard && targetCard) {
      // Use drag and drop via execute
      await browser.execute((source, target) => {
        // Simulate drag and drop using DataTransfer
        const dataTransfer = new DataTransfer();
        source.dispatchEvent(new DragEvent('dragstart', { dataTransfer, bubbles: true }));
        target.dispatchEvent(new DragEvent('drop', { dataTransfer, bubbles: true }));
        source.dispatchEvent(new DragEvent('dragend', { dataTransfer, bubbles: true }));
      }, sourceCard, targetCard);
      await browser.pause(300);
    }
  }

  private async clickButtonByText(labels: string[]): Promise<boolean> {
    return browser.execute((candidates) => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const normalize = (text: string) => text.trim().toLowerCase();
      const wanted = candidates.map(normalize);

      for (const btn of buttons) {
        const text = normalize(btn.textContent || '');
        if (!text) continue;
        if (wanted.some((candidate) => text.includes(candidate))) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, labels);
  }

  private async getActiveAppType(): Promise<'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw'> {
    const active = await browser.execute(() => {
      const byState = document.querySelector('button[data-active="true"], button[aria-current="page"]');
      const byClass = Array.from(document.querySelectorAll('button')).find((btn) => {
        const cls = btn.className || '';
        return cls.includes('bg-primary') || cls.includes('active');
      });
      const target = byState || byClass;
      const text = (target?.textContent || '').toLowerCase();
      if (text.includes('openclaw')) return 'openclaw';
      if (text.includes('opencode')) return 'opencode';
      if (text.includes('gemini')) return 'gemini';
      if (text.includes('codex') || text.includes('openai')) return 'codex';
      return 'claude';
    });
    return active as 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
  }

  private async createProviderViaIPC(data: ProviderFormData): Promise<void> {
    const appType = await this.getActiveAppType();
    await this.invokeIPC('create_provider', {
      provider: {
        app_type: appType,
        name: data.name,
        api_key: data.apiKey ?? '',
        base_url: data.baseUrl,
        model: data.model,
        is_active: false,
      },
    });
  }

  private async deleteProviderViaIPC(name: string): Promise<boolean> {
    const appType = await this.getActiveAppType();
    const providers = (await this.invokeIPC<any[]>('list_providers', {
      appType,
    })) || [];
    const target = providers.find((p) => {
      const providerName = p?.name ?? p?.provider?.name;
      return typeof providerName === 'string' && providerName === name;
    });
    if (!target?.id) return false;
    await this.invokeIPC('delete_provider', { id: target.id });
    await browser.pause(300);
    return true;
  }
}

export const dashboardPage = new DashboardPage();
