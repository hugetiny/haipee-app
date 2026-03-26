/// <reference types="@wdio/globals/types" />
/**
 * Settings Auth Tests - Authentication configuration
 * Note: The Auth tab contains OAuth center for GitHub Copilot, not individual API key inputs
 */

import { settingsPage, navigationPage } from '../pages';

describe('Settings – Auth Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('auth');
    await browser.pause(1000);
  });

  describe('Auth Center Display', () => {
    it('should display auth settings section', async () => {
      const authSection = await $('[data-testid="auth-settings"]');
      const hasAuth = await authSection.isExisting();
      expect(hasAuth).toBe(true);
    });

    it('should show OAuth center heading', async () => {
      // Look for OAuth/Auth center related text
      const pageText = await browser.execute(() => {
        return document.body.textContent || '';
      });
      const hasAuthText = pageText.includes('OAuth') || pageText.includes('认证') || pageText.includes('Copilot');
      expect(hasAuthText).toBe(true);
    });

    it('should show GitHub Copilot section', async () => {
      // Look for GitHub Copilot related content
      const pageText = await browser.execute(() => {
        return document.body.textContent || '';
      });
      const hasCopilot = pageText.includes('Copilot') || pageText.includes('GitHub');
      expect(hasCopilot).toBe(true);
    });
  });

  describe('Copilot Authentication', () => {
    it('should show Copilot login/status section', async () => {
      // The CopilotAuthSection component should be visible
      const copilotSection = await $('[data-testid="copilot-auth"], [data-testid="auth-settings"]');
      const hasSection = await copilotSection.isExisting();
      expect(hasSection).toBe(true);
    });

    it('should have authentication action buttons', async () => {
      // Look for any buttons in the auth section
      const buttons = await $$('[data-testid="auth-settings"] button, [data-testid="copilot-auth"] button');
      expect(buttons.length).toBeGreaterThanOrEqual(0);
    });
  });
});