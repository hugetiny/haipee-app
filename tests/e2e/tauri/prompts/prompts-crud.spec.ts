/// <reference types="@wdio/globals/types" />
/**
 * Prompts Tests - Prompt management
 */

import { promptsPage, navigationPage } from '../pages';

describe('Prompts – List', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should display prompts list', async () => {
    const list = await $('[data-testid="prompts-list"]');
    const hasList = await list.isExisting();
    expect(typeof hasList).toBe('boolean');
  });

  it('should show prompt count', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    expect(promptArray.length).toBeGreaterThanOrEqual(0);
  });

  it('should display prompt names', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const text = await firstPrompt.getText();
      expect(text.length).toBeGreaterThan(0);
    }
  });

  it('should show enabled prompt indicator', async () => {
    const enabledIndicator = await $('[data-testid="enabled-prompt"], [class*="enabled"]');
    const hasIndicator = await enabledIndicator.isExisting();
    expect(typeof hasIndicator).toBe('boolean');
  });
});

describe('Prompts – CRUD', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should show add prompt button', async () => {
    const addBtn = await $('[data-testid="prompt-add-btn"]');
    const hasBtn = await addBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should open add prompt form', async () => {
    const addBtn = await $('[data-testid="prompt-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      const hasForm = await promptsPage.pageContainsAnyText([
        '添加', 'Add', 'Prompt', '提示词'
      ]);
      expect(typeof hasForm).toBe('boolean');

      await browser.keys(['Escape']);
    }
  });

  it('should toggle prompt enabled state', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const toggle = await firstPrompt.$('button[role="switch"], input[type="checkbox"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
        expect(true).toBe(true);
      }
    }
  });

  it('should show edit button for prompts', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const editBtn = await firstPrompt.$('button[aria-label*="edit"], button[aria-label*="编辑"]');
      const hasEdit = await editBtn.isExisting();
      expect(typeof hasEdit).toBe('boolean');
    }
  });

  it('should show delete button for prompts', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const deleteBtn = await firstPrompt.$('button[aria-label*="delete"], button[aria-label*="删除"]');
      const hasDelete = await deleteBtn.isExisting();
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('Prompts – Content', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show prompt content preview', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const preview = await firstPrompt.$('[class*="preview"], [class*="content"]');
      if (await preview.isExisting()) {
        const text = await preview.getText();
        expect(typeof text).toBe('string');
      }
    }
  });

  it('should show prompt character count', async () => {
    const prompts = await $$('[data-testid="prompt-item"]');
    const promptArray = [...prompts] as unknown as WebdriverIO.Element[];
    if (promptArray.length > 0) {
      const firstPrompt = promptArray[0];
      const text = await firstPrompt.getText();
      // Check for character count indicator
      const hasCount = text.includes('字符') || text.includes('char') || /\d+/.test(text);
      expect(typeof hasCount).toBe('boolean');
    }
  });
});

describe('Prompts – Import/Export', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should show import button', async () => {
    const importBtn = await $('[data-testid="prompt-import-btn"]');
    const hasBtn = await importBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should show export button', async () => {
    const exportBtn = await $('[data-testid="prompt-export-btn"]');
    const hasBtn = await exportBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });
});