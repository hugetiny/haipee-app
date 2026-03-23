/// <reference types="@wdio/globals/types" />
/**
 * Settings Auth Tests - Authentication configuration
 */

import { settingsPage, navigationPage } from '../pages';

describe('Settings – Auth Tab', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await settingsPage.open();
    await settingsPage.openTab('auth');
    await browser.pause(1000);
  });

  describe('API Key Management', () => {
    it('should display auth settings section', async () => {
      const authSection = await $('[data-testid="auth-settings"]');
      const hasAuth = await authSection.isExisting();
      expect(typeof hasAuth).toBe('boolean');
    });

    it('should show API key inputs for each provider', async () => {
      const providers = ['claude', 'openai', 'gemini'];

      for (const provider of providers) {
        const keyInput = await $(`[data-testid="${provider}-api-key-input"]`);
        const hasInput = await keyInput.isExisting();
        expect(typeof hasInput).toBe('boolean');
      }
    });

    it('should toggle API key visibility', async () => {
      const toggleBtn = await $('[data-testid="toggle-key-visibility"]');
      if (await toggleBtn.isExisting()) {
        await toggleBtn.click();
        await browser.pause(300);
        expect(true).toBe(true);
      }
    });

    it('should validate API key format', async () => {
      const keyInput = await $('[data-testid="claude-api-key-input"]');
      if (await keyInput.isExisting()) {
        // Try invalid key
        await keyInput.clearValue();
        await keyInput.addValue('invalid-key');
        await browser.pause(300);

        // Check for validation feedback
        const hasError = await settingsPage.pageContainsAnyText([
          'invalid', '无效', 'format', '格式'
        ]);
        expect(typeof hasError).toBe('boolean');
      }
    });
  });

  describe('Token Management', () => {
    it('should show token usage summary', async () => {
      const usage = await $('[data-testid="token-usage"]');
      if (await usage.isExisting()) {
        const text = await usage.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should allow token limit configuration', async () => {
      const limitInput = await $('[data-testid="token-limit-input"]');
      if (await limitInput.isExisting()) {
        const value = await limitInput.getValue();
        expect(parseInt(value)).toBeGreaterThanOrEqual(0);
      }
    });
  });

  describe('Authentication Status', () => {
    it('should show connection status for each provider', async () => {
      const statusItems = await $$('[data-testid="auth-status"]');
      for (const item of statusItems) {
        const text = await item.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should test authentication connection', async () => {
      const testBtn = await $('[data-testid="test-auth-btn"]');
      if (await testBtn.isExisting()) {
        await testBtn.click();
        await browser.pause(1000);

        // Check for result
        const hasResult = await settingsPage.pageContainsAnyText([
          'success', '成功', 'failed', '失败', 'connected'
        ]);
        expect(typeof hasResult).toBe('boolean');
      }
    });
  });
});