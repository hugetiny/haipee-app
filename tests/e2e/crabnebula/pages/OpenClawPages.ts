/// <reference types="@wdio/globals/types" />
/**
 * OpenClawPages - Page objects for OpenClaw functionality
 */

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

/**
 * OpenClawGatewayPage - Page object for OpenClaw Gateway management
 */
export class OpenClawGatewayPage extends CrabNebulaBasePage {
  /**
   * Wait for gateway page to load
   */
  async waitForLoad(): Promise<void> {
    await browser.waitUntil(
      async () => await this.pageContainsAnyText(['Gateway', '网关', 'OpenClaw']),
      { timeout: 10_000, timeoutMsg: 'Gateway page did not load' }
    );
  }

  /**
   * Get gateway status
   */
  async getStatus(): Promise<string | null> {
    const status = await $('[data-testid="gateway-status"]');
    if (await status.isExisting()) {
      return status.getText();
    }
    // Fallback: find status by text
    return browser.execute(() => {
      const statusEl = document.querySelector('[class*="status"], [data-status]');
      return statusEl?.textContent?.trim() ?? null;
    });
  }

  /**
   * Toggle gateway on/off
   */
  async toggle(): Promise<void> {
    const toggle = await $('[data-testid="gateway-toggle"]');
    if (await toggle.isExisting()) {
      await toggle.click();
      await browser.pause(300);
      return;
    }
    // Fallback: find switch by role
    const switchEl = await $('button[role="switch"]');
    if (await switchEl.isExisting()) {
      await switchEl.click();
      await browser.pause(300);
    }
  }

  /**
   * Check if gateway is running
   */
  async isRunning(): Promise<boolean> {
    const status = await this.getStatus();
    if (!status) return false;
    return status.includes('running') || status.includes('运行') || status.includes('active');
  }

  /**
   * Get gateway port
   */
  async getPort(): Promise<string | null> {
    const portInput = await $('[data-testid="gateway-port-input"]');
    if (await portInput.isExisting()) {
      return portInput.getValue();
    }
    return browser.execute(() => {
      const portEl = document.querySelector('[data-port], [class*="port"]');
      return portEl?.textContent?.trim() ?? null;
    });
  }

  /**
   * Set gateway port
   */
  async setPort(port: number): Promise<void> {
    const portInput = await $('[data-testid="gateway-port-input"]');
    if (await portInput.isExisting()) {
      await portInput.clearValue();
      await portInput.addValue(String(port));
      await browser.pause(200);
    }
  }

  /**
   * Start gateway
   */
  async start(): Promise<void> {
    if (await this.isRunning()) return;
    await this.toggle();
    await browser.pause(1000);
  }

  /**
   * Stop gateway
   */
  async stop(): Promise<void> {
    if (!(await this.isRunning())) return;
    await this.toggle();
    await browser.pause(500);
  }

  /**
   * Connect to OpenClaw Gateway via HTTP
   */
  async connect(): Promise<boolean> {
    try {
      const result = await this.invokeIPC<{ connected: boolean; status: string }>(
        'connect_openclaw_gateway'
      );
      return result.connected;
    } catch (error) {
      console.error('[OpenClawGateway] Connect failed:', error);
      return false;
    }
  }

  /**
   * Send a message to OpenClaw agent
   */
  async sendMessage(message: string, sessionKey = 'agent:main:main'): Promise<string | null> {
    try {
      const result = await this.invokeIPC<{ content: string }>(
        'send_openclaw_message',
        { sessionKey, message }
      );
      return result.content;
    } catch (error) {
      console.error('[OpenClawGateway] Send message failed:', error);
      return null;
    }
  }

  /**
   * Get gateway connection status
   */
  async getConnectionStatus(): Promise<{ connected: boolean; status: string; error?: string }> {
    try {
      return await this.invokeIPC<{ connected: boolean; status: string; error?: string }>(
        'get_openclaw_gateway_status'
      );
    } catch {
      return { connected: false, status: 'error', error: 'IPC not available' };
    }
  }

  /**
   * Disconnect from gateway
   */
  async disconnect(): Promise<void> {
    try {
      await this.invokeIPC('disconnect_openclaw_gateway');
    } catch {
      // Ignore errors
    }
  }

  /**
   * Check if gateway service is running
   */
  async isServiceRunning(): Promise<boolean> {
    try {
      const result = await this.invokeIPC<{ running: boolean }>(
        'get_openclaw_gateway_service_status'
      );
      return result.running ?? false;
    } catch {
      return false;
    }
  }
}

/**
 * OpenClawChannelsPage - Page object for OpenClaw Channels management
 */
export class OpenClawChannelsPage extends CrabNebulaBasePage {
  /**
   * Wait for channels page to load
   */
  async waitForLoad(): Promise<void> {
    await browser.waitUntil(
      async () => await this.pageContainsAnyText(['Channel', '频道', 'Channels']),
      { timeout: 10_000, timeoutMsg: 'Channels page did not load' }
    );
  }

  /**
   * Get channel count
   */
  async getChannelCount(): Promise<number> {
    const channels = await $$('[data-testid="channel-item"]');
    return channels.length;
  }

  /**
   * Get all channel names
   */
  async getChannelNames(): Promise<string[]> {
    return browser.execute(() => {
      const channels = document.querySelectorAll('[data-testid="channel-item"]');
      return Array.from(channels).map(ch => {
        const nameEl = ch.querySelector('[data-testid="channel-name"], h3, h4, [class*="name"]');
        return nameEl?.textContent?.trim() ?? '';
      }).filter(n => n);
    });
  }

  /**
   * Add a new channel
   */
  async addChannel(name: string, apiKey?: string): Promise<void> {
    const addBtn = await $('[data-testid="channel-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      // Fill name
      const nameInput = await $('[data-testid="channel-name-input"]');
      if (await nameInput.isExisting()) {
        await nameInput.setValue(name);
        await browser.pause(200);
      }

      // Fill API key if provided
      if (apiKey) {
        const keyInput = await $('[data-testid="channel-api-key-input"]');
        if (await keyInput.isExisting()) {
          await keyInput.setValue(apiKey);
          await browser.pause(200);
        }
      }

      // Save
      const saveBtn = await $('[data-testid="channel-save-btn"]');
      if (await saveBtn.isExisting()) {
        await saveBtn.click();
        await browser.pause(500);
      }
    }
  }

  /**
   * Delete a channel by name
   */
  async deleteChannel(name: string): Promise<boolean> {
    const channels = await $$('[data-testid="channel-item"]');
    for (const channel of channels) {
      const text = await channel.getText();
      if (text.includes(name)) {
        const deleteBtn = await channel.$('button[aria-label*="delete"], button[aria-label*="删除"]');
        if (await deleteBtn.isExisting()) {
          await deleteBtn.click();
          await browser.pause(300);

          // Confirm deletion using browser.execute for WebKit compatibility
          const confirmed = await browser.execute(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const confirmBtn = buttons.find(btn =>
              btn.textContent?.includes('确认') ||
              btn.textContent?.includes('Confirm')
            );
            if (confirmBtn) {
              (confirmBtn as HTMLElement).click();
              return true;
            }
            return false;
          });
          if (confirmed) {
            await browser.pause(500);
          }
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Toggle channel enabled state
   */
  async toggleChannel(name: string): Promise<boolean> {
    const channels = await $$('[data-testid="channel-item"]');
    for (const channel of channels) {
      const text = await channel.getText();
      if (text.includes(name)) {
        const toggle = await channel.$('button[role="switch"], input[type="checkbox"]');
        if (await toggle.isExisting()) {
          await toggle.click();
          await browser.pause(300);
          return true;
        }
      }
    }
    return false;
  }
}

/**
 * OpenClawSkillsMcpPage - Page object for OpenClaw Skills/MCP panel
 */
export class OpenClawSkillsMcpPage extends CrabNebulaBasePage {
  /**
   * Wait for Skills/MCP panel to load
   */
  async waitForLoad(): Promise<void> {
    await browser.waitUntil(
      async () => await this.elementExists('[data-testid="skills-list"], [data-testid="mcp-servers-list"]'),
      { timeout: 10_000, timeoutMsg: 'Skills/MCP panel did not load' }
    );
  }

  /**
   * Get skill count
   */
  async getSkillCount(): Promise<number> {
    const skills = await $$('[data-testid="skill-item"]');
    return skills.length;
  }

  /**
   * Get MCP server count
   */
  async getMcpServerCount(): Promise<number> {
    const servers = await $$('[data-testid="mcp-server-item"]');
    return servers.length;
  }

  /**
   * Toggle skill enabled state
   */
  async toggleSkill(skillName: string): Promise<boolean> {
    const skills = await $$('[data-testid="skill-item"]');
    for (const skill of skills) {
      const text = await skill.getText();
      if (text.includes(skillName)) {
        const toggle = await skill.$('button[role="switch"], input[type="checkbox"]');
        if (await toggle.isExisting()) {
          await toggle.click();
          await browser.pause(300);
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Toggle MCP server enabled state
   */
  async toggleMcpServer(serverName: string): Promise<boolean> {
    const servers = await $$('[data-testid="mcp-server-item"]');
    for (const server of servers) {
      const text = await server.getText();
      if (text.includes(serverName)) {
        const toggle = await server.$('button[role="switch"], input[type="checkbox"]');
        if (await toggle.isExisting()) {
          await toggle.click();
          await browser.pause(300);
          return true;
        }
      }
    }
    return false;
  }
}

// Export singleton instances
export const openClawGatewayPage = new OpenClawGatewayPage();
export const openClawChannelsPage = new OpenClawChannelsPage();
export const openClawSkillsMcpPage = new OpenClawSkillsMcpPage();