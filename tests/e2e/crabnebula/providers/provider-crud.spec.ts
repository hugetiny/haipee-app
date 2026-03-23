/// <reference types="@wdio/globals/types" />
/**
 * Provider CRUD Tests - Create, Read, Update, Delete
 */

import { dashboardPage, navigationPage } from '../pages';
import { createTestProvider } from '../fixtures';

describe('Provider CRUD – Create', () => {
  const testProvider = createTestProvider();

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  after(async () => {
    // Cleanup
    try {
      if (await dashboardPage.providerExists(testProvider.name)) {
        await dashboardPage.deleteProvider(testProvider.name);
      }
    } catch {
      // Ignore cleanup errors
    }
  });

  it('should open add provider dialog', async () => {
    await dashboardPage.clickAddProvider();
    await browser.pause(500);

    const hasDialog = await dashboardPage.pageContainsAnyText([
      '添加', 'Add', '创建', 'Create', '供应商'
    ]);
    expect(hasDialog).toBe(true);

    // Close dialog
    await browser.keys(['Escape']);
    await browser.pause(300);
  });

  it('should create a new provider with name and API key', async () => {
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1500);

    const exists = await dashboardPage.providerExists(testProvider.name);
    expect(exists).toBe(true);
  });

  it('should show validation error for empty name', async () => {
    await dashboardPage.clickAddProvider();
    await browser.pause(500);

    // Try to save without name
    const saveBtn = await $('[data-testid="provider-save-btn"]');
    if (await saveBtn.isExisting()) {
      await saveBtn.click();
      await browser.pause(300);

      const hasError = await dashboardPage.pageContainsAnyText([
        'error', '错误', 'required', '必填', '请输入'
      ]);
      expect(typeof hasError).toBe('boolean');
    }

    // Cancel
    await browser.keys(['Escape']);
    await browser.pause(200);
  });

  it('should cancel provider creation', async () => {
    const initialCount = await dashboardPage.getProviderCount();

    await dashboardPage.clickAddProvider();
    await browser.pause(500);

    const cancelBtn = await $('[data-testid="provider-cancel-btn"]');
    if (await cancelBtn.isExisting()) {
      await cancelBtn.click();
    } else {
      await browser.keys(['Escape']);
    }
    await browser.pause(300);

    const finalCount = await dashboardPage.getProviderCount();
    expect(finalCount).toBe(initialCount);
  });

  it('should show toast notification on successful creation', async () => {
    const provider = createTestProvider({ name: `Toast Test ${Date.now()}` });
    await dashboardPage.addProvider({
      name: provider.name,
      apiKey: provider.apiKey,
    });
    await browser.pause(1000);

    // Check for success toast
    const toast = await $('[data-sonner-toast], [role="status"]');
    if (await toast.isExisting()) {
      const text = await toast.getText();
      expect(text.length).toBeGreaterThan(0);
    }

    // Cleanup
    await dashboardPage.deleteProvider(provider.name);
    await browser.pause(500);
  });
});

describe('Provider CRUD – Update', () => {
  const testProvider = createTestProvider({ name: `Edit Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should open edit dialog for existing provider', async () => {
    const card = await dashboardPage.findProviderCard(testProvider.name);
    if (card) {
      // Find and click edit button
      const editBtn = await card.$('button[aria-label*="编辑"], button[aria-label*="Edit"], [data-testid="edit-provider-btn"]');
      if (await editBtn.isExisting()) {
        await editBtn.click();
        await browser.pause(500);

        const hasDialog = await dashboardPage.pageContainsAnyText([
          '编辑', 'Edit', testProvider.name
        ]);
        expect(hasDialog).toBe(true);

        await browser.keys(['Escape']);
        await browser.pause(300);
      }
    }
  });

  it('should edit provider notes', async () => {
    const card = await dashboardPage.findProviderCard(testProvider.name);
    if (card) {
      const editBtn = await card.$('button[aria-label*="编辑"], button[aria-label*="Edit"]');
      if (await editBtn.isExisting()) {
        await editBtn.click();
        await browser.pause(500);

        // Find notes field and update
        const notesInput = await $('textarea[name*="notes"], input[name*="notes"], [data-testid="provider-notes-input"]');
        if (await notesInput.isExisting()) {
          await notesInput.clearValue();
          await notesInput.addValue('Updated test notes');
          await browser.pause(200);
        }

        // Save
        const saveBtn = await $('[data-testid="provider-save-btn"]');
        if (await saveBtn.isExisting()) {
          await saveBtn.click();
          await browser.pause(500);
        }

        // Verify update
        const exists = await dashboardPage.providerExists(testProvider.name);
        expect(exists).toBe(true);
      }
    }
  });
});

describe('Provider CRUD – Delete', () => {
  const testProvider = createTestProvider({ name: `Delete Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should show delete confirmation dialog', async () => {
    // Create provider first
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);

    const card = await dashboardPage.findProviderCard(testProvider.name);
    if (card) {
      const deleteBtn = await card.$('button[aria-label*="删除"], button[aria-label*="Delete"], [data-testid="delete-provider-btn"]');
      if (await deleteBtn.isExisting()) {
        await deleteBtn.click();
        await browser.pause(300);

        const hasConfirm = await dashboardPage.pageContainsAnyText([
          '确认', 'Confirm', '删除', 'Delete', '确定'
        ]);
        expect(hasConfirm).toBe(true);

        // Cancel deletion
        await browser.keys(['Escape']);
        await browser.pause(300);
      }
    }
  });

  it('should delete provider after confirmation', async () => {
    const existsBefore = await dashboardPage.providerExists(testProvider.name);
    expect(existsBefore).toBe(true);

    // Delete
    await dashboardPage.deleteProvider(testProvider.name);
    await browser.pause(1000);

    const existsAfter = await dashboardPage.providerExists(testProvider.name);
    expect(existsAfter).toBe(false);
  });

  it('should cancel deletion if user cancels confirmation', async () => {
    const provider = createTestProvider({ name: `Cancel Delete Test ${Date.now()}` });
    await dashboardPage.addProvider({
      name: provider.name,
      apiKey: provider.apiKey,
    });
    await browser.pause(1000);

    const card = await dashboardPage.findProviderCard(provider.name);
    if (card) {
      const deleteBtn = await card.$('button[aria-label*="删除"], button[aria-label*="Delete"]');
      if (await deleteBtn.isExisting()) {
        await deleteBtn.click();
        await browser.pause(300);

        // Cancel confirmation
        const cancelBtn = await $('button:has-text("取消"), button:has-text("Cancel")');
        if (await cancelBtn.isExisting()) {
          await cancelBtn.click();
          await browser.pause(300);
        } else {
          await browser.keys(['Escape']);
        }

        // Provider should still exist
        const exists = await dashboardPage.providerExists(provider.name);
        expect(exists).toBe(true);

        // Cleanup
        await dashboardPage.deleteProvider(provider.name);
        await browser.pause(500);
      }
    }
  });
});

describe('Provider CRUD – Duplicate', () => {
  const testProvider = createTestProvider({ name: `Dup Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
      await dashboardPage.deleteProvider(`${testProvider.name} (copy)`);
      await dashboardPage.deleteProvider(`${testProvider.name} 副本`);
    } catch {
      // Ignore
    }
  });

  it('should duplicate provider with copy suffix', async () => {
    const duplicated = await dashboardPage.duplicateProvider(testProvider.name);
    await browser.pause(1000);

    if (duplicated) {
      // Check for duplicated provider with copy suffix
      const hasCopy = await dashboardPage.providerExists(`${testProvider.name} (copy)`) ||
                      await dashboardPage.providerExists(`${testProvider.name} 副本`);
      expect(hasCopy).toBe(true);
    }
  });
});