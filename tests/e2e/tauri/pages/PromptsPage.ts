/**
 * PromptsPage - Page object for prompts management
 */

/// <reference types="@wdio/globals/types" />

import { TauriBasePage } from './TauriBasePage';

export interface PromptFormData {
  name: string;
  content: string;
  enabled?: boolean;
}

export class PromptsPage extends TauriBasePage {
  /**
   * Navigate to prompts view
   */
  async open(): Promise<void> {
    await this.waitForReactReady();

    // Click prompts nav button
    const promptsBtn = await $('button[aria-label*="提示词"], button[aria-label*="Prompts"], [data-testid="prompts-nav"]');
    if (await promptsBtn.isExisting()) {
      await promptsBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Get all prompt cards
   */
  async getPromptCards(): Promise<WebdriverIO.Element[]> {
    const cards = await $$('[data-testid="prompt-card"], .prompt-card, [data-prompt-id]');
    return [...cards] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get prompt count
   */
  async getPromptCount(): Promise<number> {
    const cards = await this.getPromptCards();
    return cards.length;
  }

  /**
   * Click add prompt button
   */
  async clickAddPrompt(): Promise<void> {
    const addButton = await $('button[aria-label*="添加"], button*="Add Prompt", button*="添加提示词"]');
    await addButton.waitForClickable({ timeout: 5000 });
    await addButton.click();
    await browser.pause(300);
  }

  /**
   * Fill prompt form
   */
  async fillPromptForm(data: PromptFormData): Promise<void> {
    const form = await $('[data-testid="prompt-form"], form');
    await form.waitForExist({ timeout: 5000 });

    // Fill name
    const nameInput = await form.$('input[name="name"], input[placeholder*="名称"], input[placeholder*="Name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue(data.name);
    }

    // Fill content (may be a textarea or markdown editor)
    const contentInput = await form.$(
      'textarea[name="content"], [data-testid="markdown-editor"], [contenteditable="true"], textarea[placeholder*="内容"], textarea[placeholder*="Content"]'
    );
    if (await contentInput.isExisting()) {
      await contentInput.setValue(data.content);
    }
  }

  /**
   * Save prompt
   */
  async savePrompt(): Promise<void> {
    const saveButton = await $('button[type="submit"], button*="保存"], button*="Save"]');
    await saveButton.waitForClickable({ timeout: 5000 });
    await saveButton.click();
    await browser.pause(500);
  }

  /**
   * Cancel prompt form
   */
  async cancelPromptForm(): Promise<void> {
    const cancelButton = await $('button*="取消"], button*="Cancel"]');
    if (await cancelButton.isExisting()) {
      await cancelButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Add a new prompt (full flow)
   */
  async addPrompt(data: PromptFormData): Promise<void> {
    await this.clickAddPrompt();
    await this.fillPromptForm(data);
    await this.savePrompt();
  }

  /**
   * Delete a prompt by name
   */
  async deletePrompt(name: string): Promise<void> {
    const cards = await this.getPromptCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const deleteButton = await card.$('button[aria-label*="删除"], button[aria-label*="Delete"], button*="删除"]');
        if (await deleteButton.isExisting()) {
          await deleteButton.click();
          await browser.pause(300);

          // Confirm deletion
          const confirmButton = await $('button*="确认"], button*="Confirm"], button*="Yes"]');
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
   * Toggle prompt enabled state
   */
  async togglePrompt(name: string): Promise<void> {
    const cards = await this.getPromptCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const toggle = await card.$('[role="switch"], button[aria-label*="toggle"]');
        if (await toggle.isExisting()) {
          await toggle.click();
          await browser.pause(300);
        }
        return;
      }
    }
  }

  /**
   * Edit prompt by name
   */
  async editPrompt(name: string, data: Partial<PromptFormData>): Promise<void> {
    const cards = await this.getPromptCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const editButton = await card.$('button[aria-label*="编辑"], button[aria-label*="Edit"], button*="编辑"]');
        if (await editButton.isExisting()) {
          await editButton.click();
          await browser.pause(300);

          // Fill form with new data
          if (data.name) {
            const nameInput = await $('input[name="name"]');
            if (await nameInput.isExisting()) {
              await nameInput.setValue(data.name);
            }
          }
          if (data.content) {
            const contentInput = await $('textarea[name="content"], [contenteditable="true"]');
            if (await contentInput.isExisting()) {
              await contentInput.setValue(data.content);
            }
          }

          await this.savePrompt();
        }
        return;
      }
    }
  }

  /**
   * Check if prompt exists
   */
  async promptExists(name: string): Promise<boolean> {
    const cards = await this.getPromptCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Get visible prompt names
   */
  async getVisiblePromptNames(): Promise<string[]> {
    const cards = await this.getPromptCards();
    const names: string[] = [];
    for (const card of cards) {
      const nameEl = await card.$('[data-testid="prompt-name"], h3, h4, .prompt-name');
      if (await nameEl.isExisting()) {
        names.push(await nameEl.getText());
      }
    }
    return names;
  }

  /**
   * Search prompts
   */
  async searchPrompts(query: string): Promise<void> {
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
    const searchInput = await $('input[placeholder*="搜索"], input[placeholder*="Search"], input[type="search"]');
    if (await searchInput.isExisting()) {
      await searchInput.clearValue();
      await browser.pause(200);
    }
  }

  /**
   * Import prompt from file
   */
  async importPrompt(_filePath: string): Promise<void> {
    const importButton = await $('button[aria-label*="导入"], button*="Import"], button*="导入"]');
    if (await importButton.isExisting()) {
      await importButton.click();
      await browser.pause(300);

      // Handle file upload dialog (platform-specific)
      // This would typically require native file dialog handling
    }
  }
}

export const promptsPage = new PromptsPage();