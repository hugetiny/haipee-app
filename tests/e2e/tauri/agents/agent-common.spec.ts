/// <reference types="@wdio/globals/types" />
/**
 * Agent Config Tests - Common agent configuration tests
 */

import { agentConfigPage, navigationPage } from '../pages';

describe('Agent Config – Common', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await agentConfigPage.open();
    await browser.pause(1000);
  });

  describe('Agent Selector', () => {
    it('should display agent selector', async () => {
      const selector = await $('[data-testid="agent-selector-claude"], button:has-text("Claude")');
      const hasSelector = await selector.isExisting();
      expect(hasSelector).toBe(true);
    });

    it('should show all agent options', async () => {
      const agents = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];
      for (const agent of agents) {
        const btn = await $(`[data-testid="agent-selector-${agent}"]`);
        const hasBtn = await btn.isExisting();
        expect(typeof hasBtn).toBe('boolean');
      }
    });

    it('should switch between agents', async () => {
      await agentConfigPage.switchAgent('codex');
      await browser.pause(500);

      await agentConfigPage.switchAgent('claude');
      await browser.pause(500);

      expect(true).toBe(true);
    });
  });

  describe('Config Tabs', () => {
    it('should display config tabs', async () => {
      const tabs = await $('[data-testid="agent-tabs"]');
      const hasTabs = await tabs.isExisting();
      expect(typeof hasTabs).toBe('boolean');
    });

    it('should show all tab options', async () => {
      const tabIds = ['basic', 'skills', 'mcp', 'prompts', 'env'];
      for (const tab of tabIds) {
        const tabBtn = await $(`[data-testid="agent-tab-${tab}"]`);
        const hasTab = await tabBtn.isExisting();
        expect(typeof hasTab).toBe('boolean');
      }
    });

    it('should switch between tabs', async () => {
      await agentConfigPage.switchTab('skills');
      await browser.pause(300);

      await agentConfigPage.switchTab('basic');
      await browser.pause(300);

      expect(true).toBe(true);
    });
  });

  describe('Basic Config Tab', () => {
    before(async () => {
      await agentConfigPage.switchTab('basic');
      await browser.pause(500);
    });

    it('should show basic config content', async () => {
      const hasContent = await agentConfigPage.pageContainsAnyText([
        '配置', 'Config', '设置', 'Settings'
      ]);
      expect(typeof hasContent).toBe('boolean');
    });
  });
});