/**
 * SkillsPage - Page object for skills management
 */

/// <reference types="@wdio/globals/types" />

import { TauriBasePage } from './TauriBasePage';

export type AppId = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';

export interface SkillFormData {
  name: string;
  description?: string;
  enabled?: boolean;
}

export class SkillsPage extends TauriBasePage {
  /**
   * Navigate to skills view
   */
  async open(): Promise<void> {
    await this.waitForReactReady();

    // Click skills nav button
    const skillsBtn = await $('button[aria-label*="Skills"], button[aria-label*="技能"], [data-testid="skills-nav"]');
    if (await skillsBtn.isExisting()) {
      await skillsBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Get all skill cards
   */
  async getSkillCards(): Promise<WebdriverIO.Element[]> {
    const cards = await $$('[data-testid="skill-card"], .skill-card, [data-skill-id]');
    return [...cards] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get skill count
   */
  async getSkillCount(): Promise<number> {
    const cards = await this.getSkillCards();
    return cards.length;
  }

  /**
   * Install a skill by ID or name
   */
  async installSkill(skillId: string): Promise<void> {
    // Look for install button for the skill
    const installButton = await $(`button[data-skill="${skillId}"], button[aria-label*="Install ${skillId}"], button*="Install"]`);
    if (await installButton.isExisting()) {
      await installButton.click();
      await browser.pause(500);
    }
  }

  /**
   * Uninstall a skill by name
   */
  async uninstallSkill(name: string): Promise<void> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const uninstallButton = await card.$(
          'button[aria-label*="卸载"], button[aria-label*="Uninstall"], button*="卸载"], button*="Uninstall"]'
        );
        if (await uninstallButton.isExisting()) {
          await uninstallButton.click();
          await browser.pause(300);

          // Confirm uninstallation
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
   * Toggle skill for specific app
   */
  async toggleSkillApp(skillName: string, app: AppId): Promise<void> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(skillName)) {
        // Find app toggle within the card
        const appToggle = await card.$(`[data-app="${app}"], button[aria-label*="${app}"], [data-testid="toggle-${app}"]`);
        if (await appToggle.isExisting()) {
          await appToggle.click();
          await browser.pause(300);
        }
        return;
      }
    }
  }

  /**
   * Backup a skill
   */
  async backupSkill(name: string): Promise<void> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const backupButton = await card.$(
          'button[aria-label*="备份"], button[aria-label*="Backup"], button*="备份"]'
        );
        if (await backupButton.isExisting()) {
          await backupButton.click();
          await browser.pause(500);
        }
        return;
      }
    }
  }

  /**
   * Restore a skill
   */
  async restoreSkill(name: string): Promise<void> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const restoreButton = await card.$(
          'button[aria-label*="恢复"], button[aria-label*="Restore"], button*="恢复"]'
        );
        if (await restoreButton.isExisting()) {
          await restoreButton.click();
          await browser.pause(500);
        }
        return;
      }
    }
  }

  /**
   * Import skill from zip file
   */
  async importFromZip(_filePath: string): Promise<void> {
    const importButton = await $('button[aria-label*="导入"], button*="Import"], button*="导入"]');
    if (await importButton.isExisting()) {
      await importButton.click();
      await browser.pause(300);
      // File dialog handling would be platform-specific
    }
  }

  /**
   * Import skill from another app
   */
  async importFromApp(app: AppId): Promise<void> {
    const importButton = await $(`button[aria-label*="Import from ${app}"], button*="从${app}导入"]`);
    if (await importButton.isExisting()) {
      await importButton.click();
      await browser.pause(500);
    }
  }

  /**
   * Check if skill exists
   */
  async skillExists(name: string): Promise<boolean> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Get visible skill names
   */
  async getVisibleSkillNames(): Promise<string[]> {
    const cards = await this.getSkillCards();
    const names: string[] = [];
    for (const card of cards) {
      const nameEl = await card.$('[data-testid="skill-name"], h3, h4, .skill-name');
      if (await nameEl.isExisting()) {
        names.push(await nameEl.getText());
      }
    }
    return names;
  }

  /**
   * Search skills
   */
  async searchSkills(query: string): Promise<void> {
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
   * Get skill details by name
   */
  async getSkillDetails(name: string): Promise<Record<string, string> | null> {
    const cards = await this.getSkillCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const details: Record<string, string> = {};

        // Get description
        const descEl = await card.$('[data-testid="skill-description"], .skill-description, p');
        if (await descEl.isExisting()) {
          details.description = await descEl.getText();
        }

        // Get enabled apps
        const enabledApps = await card.$$('[data-app-enabled="true"]');
        const appNames: string[] = [];
        for (const el of enabledApps) {
          const app = await el.getAttribute('data-app');
          if (app) appNames.push(app);
        }
        details.enabledApps = appNames.join(', ');

        return details;
      }
    }
    return null;
  }
}

export const skillsPage = new SkillsPage();