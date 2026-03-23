/// <reference types="@wdio/globals/types" />
/**
 * AgentConfigPage - Page object for Agent configuration view
 */

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export type AgentId = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
export type ConfigTab = 'basic' | 'skills' | 'mcp' | 'prompts' | 'env' | 'advanced';

export class AgentConfigPage extends CrabNebulaBasePage {
  // Tab selectors - using data-value attributes
  private readonly tabValues: Record<ConfigTab, string> = {
    basic: 'basic',
    skills: 'skills',
    mcp: 'mcp',
    prompts: 'prompts',
    env: 'env',
    advanced: 'advanced',
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
    // Find Agent config button using browser.execute for WebKit compatibility
    const clicked = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const configBtn = buttons.find(btn =>
        btn.getAttribute('aria-label')?.includes('Agent配置') ||
        btn.textContent?.includes('Agent配置')
      );
      if (configBtn) {
        (configBtn as HTMLElement).click();
        return true;
      }
      return false;
    });
    if (clicked) {
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Switch to a specific agent
   */
  async switchAgent(agent: AgentId): Promise<void> {
    const agentNames: Record<AgentId, string> = {
      claude: 'Claude',
      codex: 'Codex',
      gemini: 'Gemini',
      opencode: 'OpenCode',
      openclaw: 'OpenClaw',
    };

    const clicked = await browser.execute((agentName) => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const agentBtn = buttons.find(btn => btn.textContent?.includes(agentName));
      if (agentBtn) {
        (agentBtn as HTMLElement).click();
        return true;
      }
      return false;
    }, agentNames[agent]);
    if (clicked) {
      await browser.pause(500);
    }
  }

  /**
   * Switch to a config tab
   */
  async switchTab(tab: ConfigTab): Promise<void> {
    const tabBtn = await $(`[data-value="${this.tabValues[tab]}"], [data-testid="agent-tab-${tab}"]`);
    if (await tabBtn.isExisting()) {
      await tabBtn.click();
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
    const isSelected = await browser.execute((agentName) => {
      const buttons = Array.from(document.querySelectorAll('button[aria-pressed="true"]'));
      return buttons.some(btn => btn.textContent?.toLowerCase().includes(agentName.toLowerCase()));
    }, agent);
    return isSelected;
  }
}

export const agentConfigPage = new AgentConfigPage();