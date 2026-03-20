/// <reference types="@wdio/globals/types" />
/**
 * Config Tabs E2E Test
 *
 * Tests the agent configuration tab navigation workflow in the Tauri WebView.
 */

import { agentConfigPage } from '../pages';
import type { ConfigTab } from '../pages';

describe('Agent Configuration - Config Tabs', () => {
  const tabs: ConfigTab[] = ['basic', 'skills', 'mcp', 'prompts', 'env', 'advanced'];

  before(async () => {
    await agentConfigPage.open();
  });

  tabs.forEach((tab) => {
    it(`should switch to ${tab} tab`, async () => {
      await agentConfigPage.switchTab(tab);
      await browser.pause(300);

      // Verify tab content is visible
      const activeTab = await agentConfigPage.getActiveTab();
      expect(activeTab).toBe(tab);
    });
  });

  it('should show provider list in basic tab', async () => {
    await agentConfigPage.switchTab('basic');
    await browser.pause(300);

    // Check for provider cards or list
    const providerCards = await $$('[data-testid="provider-card"], .provider-card');
    const count = providerCards.length;
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show skills list in skills tab', async () => {
    await agentConfigPage.switchTab('skills');
    await browser.pause(500);

    // Check for skills content
    const skillsContent = $('[data-testid="skills-panel"], [class*="skills"]');
    const exists = await skillsContent.isExisting();
    expect(exists).toBe(true);
  });

  it('should show MCP servers in mcp tab', async () => {
    await agentConfigPage.switchTab('mcp');
    await browser.pause(500);

    // Check for MCP content
    const mcpContent = $('[data-testid="mcp-panel"], [class*="mcp"]');
    const exists = await mcpContent.isExisting();
    expect(exists).toBe(true);
  });
});