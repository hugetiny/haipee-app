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
    await this.navigateToView('settings');
    await browser.pause(300);
  }

  /**
   * Click button by testid or text fallback (private helper)
   */
  private async clickButtonByTestIdOrText(
    testId: string,
    textVariants: string[]
  ): Promise<boolean> {
    const btn = await $(`[data-testid="${testId}"]`);
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
      return true;
    }

    const clicked = await browser.execute((variants) => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const btn = buttons.find(b =>
        variants.some(v => b.textContent?.includes(v))
      );
      if (btn) {
        (btn as HTMLElement).click();
        return true;
      }
      return false;
    }, textVariants);

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Set checkbox to desired state (private helper)
   */
  private async setCheckboxState(selector: string, desiredState: boolean): Promise<void> {
    const checkbox = await $(selector);
    if (await checkbox.isExisting()) {
      const isChecked = await checkbox.isSelected();
      if (isChecked !== desiredState) {
        await checkbox.click();
      }
    }
  }

  /**
   * Click export button
   */
  async clickExport(): Promise<boolean> {
    return this.clickButtonByTestIdOrText('export-btn', ['Export', '导出']);
  }

  /**
   * Click import button
   */
  async clickImport(): Promise<boolean> {
    return this.clickButtonByTestIdOrText('import-btn', ['Import', '导入']);
  }

  /**
   * Click backup button
   */
  async clickBackup(): Promise<boolean> {
    return this.clickButtonByTestIdOrText('backup-btn', ['Backup', '备份']);
  }

  /**
   * Click restore button
   */
  async clickRestore(): Promise<boolean> {
    return this.clickButtonByTestIdOrText('restore-btn', ['Restore', '恢复']);
  }

  /**
   * Select export options
   */
  async selectExportOptions(options: ExportOptions): Promise<void> {
    if (options.providers !== undefined) {
      await this.setCheckboxState('input[name="export-providers"]', options.providers);
    }
    if (options.sessions !== undefined) {
      await this.setCheckboxState('input[name="export-sessions"]', options.sessions);
    }
    if (options.settings !== undefined) {
      await this.setCheckboxState('input[name="export-settings"]', options.settings);
    }
    if (options.mcpServers !== undefined) {
      await this.setCheckboxState('input[name="export-mcp-servers"]', options.mcpServers);
    }
  }

  /**
   * Confirm export
   */
  async confirmExport(): Promise<void> {
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