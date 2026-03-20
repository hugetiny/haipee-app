/// <reference types="@wdio/globals/types" />
/**
 * AgentConfigPage - Page object for Agent configuration view
 */

import { TauriBasePage } from './TauriBasePage';

export type AgentId = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
export type ConfigTab = 'basic' | 'skills' | 'mcp' | 'prompts' | 'env' | 'advanced';

export class AgentConfigPage extends TauriBasePage {
  // Tab selectors
  private readonly tabButtons: Record<ConfigTab, string> = {
    basic: '[data-value="basic"], button:has-text("基础")',
    skills: '[data-value="skills"], button:has-text("Skills")',
    mcp: '[data-value="mcp"], button:has-text("MCP")',
    prompts: '[data-value="prompts"], button:has-text("提示词")',
    env: '[data-value="env"], button:has-text("环境变量")',
    advanced: '[data-value="advanced"], button:has-text("高级")',
  };

  private readonly agentSwitcher = '[data-testid="agent-switcher"], button[aria-label*="Agent"]';

  /**
   * Check if agent switcher is visible
   */
  async isAgentSwitcherVisible(): Promise<boolean> {
    const switcher = $(this.agentSwitcher);
    return switcher.isExisting();
  }

  /**
   * Navigate to Agent Config view
   */
  async open(): Promise<void> {
    const configButton = $('button[aria-label*="Agent配置"], button:has-text("Agent配置")');
    if (await configButton.isExisting()) {
      await configButton.click();
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Switch to a specific agent
   */
  async switchAgent(agent: AgentId): Promise<void> {
    const agentButtons: Record<AgentId, string> = {
      claude: 'button:has-text("Claude")',
      codex: 'button:has-text("Codex")',
      gemini: 'button:has-text("Gemini")',
      opencode: 'button:has-text("OpenCode")',
      openclaw: 'button:has-text("OpenClaw")',
    };

    const button = $(agentButtons[agent]);
    if (await button.isExisting()) {
      await button.click();
      await browser.pause(500);
    }
  }

  /**
   * Switch to a config tab
   */
  async switchTab(tab: ConfigTab): Promise<void> {
    const tabButton = $(this.tabButtons[tab]);
    if (await tabButton.isExisting()) {
      await tabButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Get current active tab
   */
  async getActiveTab(): Promise<string | null> {
    const activeTab = $('[role="tab"][data-state="active"], button[data-state="active"]');
    if (await activeTab.isExisting()) {
      return activeTab.getAttribute('data-value');
    }
    return null;
  }

  /**
   * Check if agent is selected
   */
  async isAgentSelected(agent: AgentId): Promise<boolean> {
    const button = $(`button[aria-pressed="true"]:has-text("${agent}")`);
    return button.isExisting();
  }
}

export const agentConfigPage = new AgentConfigPage();