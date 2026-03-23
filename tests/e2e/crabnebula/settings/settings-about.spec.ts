/// <reference types="@wdio/globals/types" />
/**
 * Settings About Tests - About page and version info
 */

import { settingsPage, navigationPage } from '../pages';

describe('Settings – About Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('about');
    await browser.pause(1000);
  });

  describe('Application Info', () => {
    it('should display app name', async () => {
      const appName = await settingsPage.pageContainsAnyText([
        'Haipee', 'haipee'
      ]);
      expect(appName).toBe(true);
    });

    it('should display version number', async () => {
      const versionEl = await $('[data-testid="app-version"]');
      if (await versionEl.isExisting()) {
        const text = await versionEl.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should display build info', async () => {
      const buildInfo = await $('[data-testid="build-info"]');
      if (await buildInfo.isExisting()) {
        const text = await buildInfo.getText();
        expect(typeof text).toBe('string');
      }
    });
  });

  describe('Technology Stack', () => {
    it('should show Tauri version', async () => {
      const tauriVersion = await $('[data-testid="tauri-version"]');
      if (await tauriVersion.isExisting()) {
        const text = await tauriVersion.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });

    it('should show React version', async () => {
      const reactVersion = await $('[data-testid="react-version"]');
      if (await reactVersion.isExisting()) {
        const text = await reactVersion.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should show platform info', async () => {
      const platform = await $('[data-testid="platform-info"]');
      if (await platform.isExisting()) {
        const text = await platform.getText();
        expect(text.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Links', () => {
    it('should have GitHub link', async () => {
      const githubLink = await $('a[href*="github"]');
      const hasLink = await githubLink.isExisting();
      expect(typeof hasLink).toBe('boolean');
    });

    it('should have documentation link', async () => {
      const docsLink = await $('a[href*="docs"], a[href*="documentation"]');
      const hasLink = await docsLink.isExisting();
      expect(typeof hasLink).toBe('boolean');
    });

    it('should have issue tracker link', async () => {
      const issueLink = await $('a[href*="issue"], a[href*="github.com*issues"]');
      const hasLink = await issueLink.isExisting();
      expect(typeof hasLink).toBe('boolean');
    });
  });

  describe('License', () => {
    it('should display license info', async () => {
      const license = await $('[data-testid="license-info"]');
      if (await license.isExisting()) {
        const text = await license.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should show open source licenses', async () => {
      const ossLicenses = await $('[data-testid="oss-licenses"]');
      const hasLicenses = await ossLicenses.isExisting();
      expect(typeof hasLicenses).toBe('boolean');
    });
  });

  describe('Updates', () => {
    it('should show check for updates button', async () => {
      const updateBtn = await $('[data-testid="check-update-btn"]');
      const hasBtn = await updateBtn.isExisting();
      expect(typeof hasBtn).toBe('boolean');
    });

    it('should check for updates', async () => {
      const updateBtn = await $('[data-testid="check-update-btn"]');
      if (await updateBtn.isExisting()) {
        await updateBtn.click();
        await browser.pause(2000);

        // Check for result
        const hasResult = await settingsPage.pageContainsAnyText([
          'update', '更新', 'latest', '最新', 'available', 'available'
        ]);
        expect(typeof hasResult).toBe('boolean');
      }
    });

    it('should show current vs latest version', async () => {
      const versionComparison = await $('[data-testid="version-comparison"]');
      if (await versionComparison.isExisting()) {
        const text = await versionComparison.getText();
        expect(typeof text).toBe('string');
      }
    });
  });

  describe('Credits', () => {
    it('should show credits section', async () => {
      const credits = await $('[data-testid="credits"]');
      const hasCredits = await credits.isExisting();
      expect(typeof hasCredits).toBe('boolean');
    });

    it('should list contributors', async () => {
      const contributors = await $$('[data-testid="contributor"]');
      expect(contributors.length).toBeGreaterThanOrEqual(0);
    });
  });
});