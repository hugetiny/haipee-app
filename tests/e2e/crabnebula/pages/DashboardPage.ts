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

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export interface ProviderFormData {
  name: string;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  notes?: string;
  category?: string;
}

export class DashboardPage extends CrabNebulaBasePage {
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
    // Wait for cards to exist first
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(() => {
          return document.querySelectorAll('[data-provider-id], [data-testid="provider-card"], .provider-card, [class*="provider"]').length;
        });
        return count > 0;
      },
      { timeout: 5000, timeoutMsg: 'No provider cards found' }
    ).catch(() => {});

    const cards = await $$('[data-provider-id], [data-testid="provider-card"], .provider-card, [class*="ProviderCard"]');
    return [...cards] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get provider count
   */
  async getProviderCount(): Promise<number> {
    const count = await browser.execute(() => {
      // Count provider-related elements
      const selectors = ['[data-provider-id]', '[data-testid="provider-card"]', '.provider-card'];
      let maxCount = 0;
      for (const sel of selectors) {
        const n = document.querySelectorAll(sel).length;
        if (n > maxCount) maxCount = n;
      }
      return maxCount;
    });
    return count;
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
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      for (const btn of buttons) {
        const text = btn.textContent?.trim() || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (text.includes('添加') || text.includes('Add') ||
            ariaLabel.includes('添加') || ariaLabel.includes('Add')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (clicked) {
      await browser.pause(300);
    }
  }

  /**
   * Fill provider form
   */
  async fillProviderForm(data: ProviderFormData): Promise<void> {
    await browser.pause(500); // Wait for form animation

    // Fill name
    if (data.name) {
      // Try data-testid first, then fallback to other selectors
      const nameInput = await $('[data-testid="provider-name-input"], input[name*="name"], input[placeholder*="名称"], input[placeholder*="Name"]');
      if (await nameInput.isExisting()) {
        await nameInput.clearValue();
        await nameInput.setValue(data.name);
      }
    }

    // Fill API key
    if (data.apiKey) {
      // Try data-testid first, then fallback to other selectors
      const apiKeyInput = await $('[data-testid="provider-api-key-input"], input[id="apiKey"], input[name*="apiKey"], input[name*="api_key"], input[placeholder*="API"], input[placeholder*="Token"], input[placeholder*="Key"]');
      if (await apiKeyInput.isExisting()) {
        await apiKeyInput.clearValue();
        await apiKeyInput.setValue(data.apiKey);
      }
    }

    // Fill base URL
    if (data.baseUrl) {
      const urlInput = await $('input[name*="baseUrl"], input[name*="base_url"], input[name*="endpoint"], input[placeholder*="URL"], input[placeholder*="Endpoint"]');
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
      const notesInput = await $('textarea[name*="notes"], input[name*="notes"], textarea[placeholder*="Notes"], textarea[placeholder*="备注"]');
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
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      for (const btn of buttons) {
        if (btn.type === 'submit' ||
            btn.textContent?.includes('保存') ||
            btn.textContent?.includes('Save') ||
            btn.textContent?.includes('创建') ||
            btn.textContent?.includes('Create')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (clicked) {
      await browser.pause(500);
    }
  }

  /**
   * Cancel provider form
   */
  async cancelProviderForm(): Promise<void> {
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      for (const btn of buttons) {
        if (btn.textContent?.includes('取消') || btn.textContent?.includes('Cancel')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    });

    if (clicked) {
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
      // Look for actions button (three dots or menu icon)
      const actionsBtn = await card.$('button[aria-label*="action"], button[aria-label*="menu"], button[aria-label*="更多"], [class*="dropdown"]');
      if (await actionsBtn.isExisting()) {
        await actionsBtn.click();
        await browser.pause(300);
      }
    }
  }

  /**
   * Edit provider by name
   */
  async editProvider(name: string, newData: Partial<ProviderFormData>): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    // Find edit button using browser.execute for compatibility
    const clicked = await browser.execute((cardEl) => {
      const buttons = cardEl.querySelectorAll('button');
      for (const btn of buttons) {
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (ariaLabel.includes('编辑') || ariaLabel.toLowerCase().includes('edit')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, card);

    if (clicked) {
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

    // Find delete button using browser.execute for compatibility
    const clicked = await browser.execute((cardEl) => {
      const buttons = cardEl.querySelectorAll('button');
      for (const btn of buttons) {
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (ariaLabel.includes('删除') || ariaLabel.toLowerCase().includes('delete')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, card);

    if (clicked) {
      await browser.pause(300);

      // Confirm deletion using browser.execute
      const confirmed = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        const confirmBtn = buttons.find(btn =>
          btn.textContent?.includes('确认') ||
          btn.textContent?.includes('Confirm') ||
          btn.textContent?.includes('删除') ||
          btn.textContent?.includes('Delete')
        );
        if (confirmBtn) {
          (confirmBtn as HTMLElement).click();
          return true;
        }
        return false;
      });

      if (confirmed) {
        await browser.pause(500);
      }
      return true;
    }
    return false;
  }

  /**
   * Duplicate provider by name
   */
  async duplicateProvider(name: string): Promise<boolean> {
    const card = await this.findProviderCard(name);
    if (!card) return false;

    // Open actions menu first if needed
    await this.openProviderActions(name);

    // Find duplicate button using browser.execute
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const duplicateBtn = buttons.find(btn => {
        const text = btn.textContent || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        return text.includes('复制') || text.includes('Duplicate') ||
               ariaLabel.includes('复制') || ariaLabel.includes('Duplicate');
      });
      if (duplicateBtn) {
        (duplicateBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
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
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const clearBtn = buttons.find(btn => {
        const text = btn.textContent || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        return text.includes('Clear') || text.includes('清除') || ariaLabel.includes('clear');
      });
      if (clearBtn) {
        (clearBtn as HTMLElement).click();
        return true;
      }
      return false;
    });
    if (clicked) {
      await browser.pause(200);
    }
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
      const cards = document.querySelectorAll('[data-provider-id], [data-testid="provider-card"], .provider-card, [class*="ProviderCard"]');
      return Array.from(cards).map(card => {
        const nameEl = card.querySelector('h3, h4, [class*="name"]');
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
    return names.some(n => n.includes(name));
  }

  /**
   * Get current provider (highlighted/selected)
   */
  async getCurrentProvider(): Promise<string | null> {
    const current = await browser.execute(() => {
      const activeCard = document.querySelector('[data-current="true"], [data-active="true"], [class*="current"], [class*="active"]');
      if (activeCard) {
        const nameEl = activeCard.querySelector('h3, h4, [class*="name"]');
        return nameEl?.textContent?.trim() || null;
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

    const toggle = await card.$('[role="switch"], input[type="checkbox"]');
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

    const clicked = await browser.execute((cardEl) => {
      const buttons = cardEl.querySelectorAll('button');
      for (const btn of buttons) {
        const text = btn.textContent || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (text.includes('测试') || text.includes('Test') || ariaLabel.toLowerCase().includes('test')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, card);

    if (clicked) {
      await browser.pause(1000); // Wait for test to complete
    }
  }

  /**
   * Open provider website
   */
  async openProviderWebsite(name: string): Promise<void> {
    const card = await this.findProviderCard(name);
    if (!card) return;

    const clicked = await browser.execute((cardEl) => {
      const links = cardEl.querySelectorAll('a[href*="http"]');
      if (links.length > 0) {
        (links[0] as HTMLElement).click();
        return true;
      }
      const buttons = cardEl.querySelectorAll('button');
      for (const btn of buttons) {
        const text = btn.textContent || '';
        if (text.includes('网站') || text.includes('Website')) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, card);

    if (clicked) {
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
}

export const dashboardPage = new DashboardPage();
