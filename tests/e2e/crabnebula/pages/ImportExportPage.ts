/**
 * ImportExportPage - Page object for data portability
 *
 * Handles:
 * - Export configuration
 * - Import configuration
 * - Backup and restore
 */

/// <reference types="@wdio/globals/types" />

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export interface ExportOptions {
  providers?: boolean;
  sessions?: boolean;
  settings?: boolean;
  mcpServers?: boolean;
}

export class ImportExportPage extends CrabNebulaBasePage {
  /**
   * Navigate to export/import section
   */
  async open(): Promise<void> {
    await this.waitForReactReady();
    // Navigate to settings then import/export tab
    await this.navigateToView('settings');
    await browser.pause(300);
  }

  /**
   * Click export button
   */
  async clickExport(): Promise<boolean> {
    // Use data-testid first, then fallback to text matching
    const btn = await $('[data-testid="export-btn"]');
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
      return true;
    }

    // Fallback: find by text using WebKit2GTK-compatible method
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const exportBtn = buttons.find(b => b.textContent?.includes('Export') || b.textContent?.includes('导出'));
      if (exportBtn) {
        (exportBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Click import button
   */
  async clickImport(): Promise<boolean> {
    const btn = await $('[data-testid="import-btn"]');
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
      return true;
    }

    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const importBtn = buttons.find(b => b.textContent?.includes('Import') || b.textContent?.includes('导入'));
      if (importBtn) {
        (importBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Click backup button
   */
  async clickBackup(): Promise<boolean> {
    const btn = await $('[data-testid="backup-btn"]');
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
      return true;
    }

    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const backupBtn = buttons.find(b => b.textContent?.includes('Backup') || b.textContent?.includes('备份'));
      if (backupBtn) {
        (backupBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Click restore button
   */
  async clickRestore(): Promise<boolean> {
    const btn = await $('[data-testid="restore-btn"]');
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
      return true;
    }

    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const restoreBtn = buttons.find(b => b.textContent?.includes('Restore') || b.textContent?.includes('恢复'));
      if (restoreBtn) {
        (restoreBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Select export options
   */
  async selectExportOptions(options: ExportOptions): Promise<void> {
    if (options.providers !== undefined) {
      const checkbox = await $('input[name="export-providers"]');
      if (await checkbox.isExisting()) {
        const isChecked = await checkbox.isSelected();
        if (isChecked !== options.providers) {
          await checkbox.click();
        }
      }
    }

    if (options.sessions !== undefined) {
      const checkbox = await $('input[name="export-sessions"]');
      if (await checkbox.isExisting()) {
        const isChecked = await checkbox.isSelected();
        if (isChecked !== options.sessions) {
          await checkbox.click();
        }
      }
    }

    if (options.settings !== undefined) {
      const checkbox = await $('input[name="export-settings"]');
      if (await checkbox.isExisting()) {
        const isChecked = await checkbox.isSelected();
        if (isChecked !== options.settings) {
          await checkbox.click();
        }
      }
    }

    if (options.mcpServers !== undefined) {
      const checkbox = await $('input[name="export-mcp-servers"]');
      if (await checkbox.isExisting()) {
        const isChecked = await checkbox.isSelected();
        if (isChecked !== options.mcpServers) {
          await checkbox.click();
        }
      }
    }
  }

  /**
   * Confirm export
   */
  async confirmExport(): Promise<void> {
    // Use WebKit2GTK-compatible method to find confirm button
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const confirmBtn = buttons.find(b =>
        b.type === 'submit' ||
        b.textContent?.includes('确认') ||
        b.textContent?.includes('Confirm')
      );
      if (confirmBtn) {
        (confirmBtn as HTMLElement).click();
        return true;
      }
      return false;
    });

    if (clicked) {
      await browser.pause(500);
    }
  }

  /**
   * Check if export was successful
   */
  async isExportSuccessful(): Promise<boolean> {
    // Check for success toast or message
    const toast = await this.waitForToast(5000);
    return toast !== null && (
      toast.includes('成功') ||
      toast.includes('Success') ||
      toast.includes('exported')
    );
  }

  /**
   * Get available backups
   */
  async getAvailableBackups(): Promise<string[]> {
    const backups: string[] = [];
    const items = await $$('[data-testid="backup-item"]');
    for (const item of items) {
      const text = await item.getText();
      backups.push(text.trim());
    }
    return backups;
  }

  /**
   * Select backup to restore
   */
  async selectBackup(index: number): Promise<boolean> {
    const items = await $$('[data-testid="backup-item"]');
    if (items[index]) {
      await items[index].click();
      await browser.pause(300);
      return true;
    }
    return false;
  }
}

export const importExportPage = new ImportExportPage();