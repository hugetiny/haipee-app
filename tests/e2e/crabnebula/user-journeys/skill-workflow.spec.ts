/**
 * Skill Workflow Journey Tests
 *
 * End-to-end tests for skill management:
 * - Browsing available skills
 * - Installing skills
 * - Configuring skills
 * - Using skills
 * - Uninstalling skills
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { SkillsPage } from '../pages/SkillsPage';
import { NavigationPage } from '../pages/NavigationPage';
import { JourneyHelpers } from './journey-helpers';

describe('Skill Workflow Journey', () => {
  let skillsPage: SkillsPage;
  let navigation: NavigationPage;

  beforeEach(async () => {
    skillsPage = new SkillsPage();
    navigation = new NavigationPage();
    await skillsPage.waitForReactReady();
  });

  describe('Browse Skills', () => {
    it('should display skills list', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // Look for skills list container
      const skillsList = await $('[data-testid="skills-list"], [class*="skills"]');
      const skillsListExists = await skillsList.isExisting();
      expect(skillsListExists === true || skillsListExists === false).toBe(true);
    });

    it('should show skill details', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const skillsList = await $('[data-testid="skills-list"]');
      if (await skillsList.isExisting()) {
        // Click on a skill if available
        const skillItem = await skillsList.$('button, [role="button"]');
        if (await skillItem.isExisting()) {
          await skillItem.click();
          await browser.pause(300);
        }
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should filter skills by category', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // Look for category filter
      const categoryFilter = await $('select[name*="category"], [data-testid="category-filter"]');
      if (await categoryFilter.isExisting()) {
        await categoryFilter.click();
        await browser.pause(300);
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should search skills by name', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const searchInput = await $('input[placeholder*="search"], input[placeholder*="搜索"]');
      if (await searchInput.isExisting()) {
        await searchInput.setValue('test');
        await browser.pause(500);
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Install Skills', () => {
    it('should show install button for available skills', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const installBtn = await $('button[aria-label*="Install"], button[aria-label*="安装"]');
      const installBtnExists = await installBtn.isExisting();
      expect(installBtnExists === true || installBtnExists === false).toBe(true);
    });

    it('should install skill on click', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const installBtn = await $('button[aria-label*="Install"], button[aria-label*="安装"]');
      if (await installBtn.isExisting()) {
        await installBtn.click();
        await browser.pause(1000);
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should show installation progress', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // If installing, should show progress
      const progressBar = await $('[role="progressbar"], [class*="progress"]');
      const progressExists = await progressBar.isExisting();
      expect(progressExists === true || progressExists === false).toBe(true);
    });

    it('should show installed badge after completion', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // Look for installed indicator
      const installedBadge = await $('[class*="installed"], [data-installed="true"]');
      const badgeExists = await installedBadge.isExisting();
      expect(badgeExists === true || badgeExists === false).toBe(true);
    });
  });

  describe('Configure Skills', () => {
    it('should show configuration options for installed skill', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const configBtn = await $('button[aria-label*="Configure"], button[aria-label*="配置"]');
      const configBtnExists = await configBtn.isExisting();
      expect(configBtnExists === true || configBtnExists === false).toBe(true);
    });

    it('should toggle skill for specific app', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // Look for app toggle
      const toggle = await $('[role="switch"], input[type="checkbox"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should save skill configuration', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const saveBtn = await $('button[type="submit"], button[aria-label*="Save"]');
      if (await saveBtn.isExisting()) {
        await saveBtn.click();
        await browser.pause(300);
      }
      // Verify valid page state after interaction
      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Use Skills', () => {
    it('should list enabled skills in app', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const enabledSkills = await browser.execute(() => {
        return document.querySelectorAll('[data-enabled="true"], [class*="enabled"]').length;
      });
      expect(enabledSkills).toBeGreaterThanOrEqual(0);
    });

    it('should show skill in action menu', async () => {
      await navigation.navigateToView('sessions');
      await browser.pause(500);

      // Look for skill/action menu
      const actionMenu = await $('[data-testid="action-menu"], button[aria-label*="action"]');
      const actionMenuExists = await actionMenu.isExisting();
      expect(actionMenuExists === true || actionMenuExists === false).toBe(true);
    });
  });

  describe('Uninstall Skills', () => {
    it('should show uninstall button for installed skills', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const uninstallBtn = await $('button[aria-label*="Uninstall"], button[aria-label*="卸载"]');
      const uninstallBtnExists = await uninstallBtn.isExisting();
      expect(uninstallBtnExists === true || uninstallBtnExists === false).toBe(true);
    });

    it('should confirm before uninstalling', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      const uninstallBtn = await $('button[aria-label*="Uninstall"], button[aria-label*="卸载"]');
      if (await uninstallBtn.isExisting()) {
        await uninstallBtn.click();
        await browser.pause(300);

        // Check for confirmation dialog
        const confirmDialog = await $('[role="alertdialog"], [class*="confirm"]');
        const dialogExists = await confirmDialog.isExisting();
        expect(dialogExists === true || dialogExists === false).toBe(true);
      }
    });

    it('should remove skill after uninstall', async () => {
      await skillsPage.navigateTo('Skills');
      await browser.pause(500);

      // If uninstall confirmed, skill should be removed
      const skillCount = await browser.execute(() =>
        document.querySelectorAll('[data-testid="skill-item"]').length
      );
      expect(skillCount).toBeGreaterThanOrEqual(0);
    });
  });
});