/// <reference types="@wdio/globals/types" />
/**
 * Switch Agent E2E Test
 *
 * Tests the agent switching workflow in the Tauri WebView.
 */

import { agentConfigPage } from '../pages';
import type { AgentId } from '../pages';

describe('Agent Configuration - Switch Agent', () => {
  const agents: AgentId[] = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];

  before(async () => {
    await agentConfigPage.open();
  });

  agents.forEach((agent) => {
    it(`should switch to ${agent} agent`, async () => {
      await agentConfigPage.switchAgent(agent);
      await browser.pause(300);

      // Verify agent is selected
      const isSelected = await agentConfigPage.isAgentSelected(agent);
      expect(isSelected).toBe(true);
    });
  });

  it('should maintain selected agent after tab switch', async () => {
    await agentConfigPage.switchAgent('codex');
    await agentConfigPage.switchTab('skills');
    await browser.pause(300);

    // Switch back to basic tab
    await agentConfigPage.switchTab('basic');
    await browser.pause(300);

    // Verify codex is still selected
    const isSelected = await agentConfigPage.isAgentSelected('codex');
    expect(isSelected).toBe(true);
  });
});