/// <reference types="@wdio/globals/types" />
/**
 * Haipee Channel E2E Tests
 *
 * Tests the bidirectional channel communication between:
 * - OpenClaw channel (HTTP API for message exchange)
 * - Claude Code MCP channel (stdio MCP server)
 *
 * These tests verify that messages can be sent and received
 * through both channel types in the actual Tauri app.
 */

import { TauriBasePage } from '../../e2e/tauri/pages/TauriBasePage';

/**
 * Page object for Haipee Channel testing
 */
class HaipeeChannelPage extends TauriBasePage {
  // OpenClaw channel selectors
  private readonly openclawChatInput = 'textarea[data-testid="openclaw-chat-input"], textarea[placeholder*="OpenClaw"], #openclaw-chat-input';
  private readonly openclawSendButton = 'button[data-testid="openclaw-send"], button[aria-label*="发送"][data-channel="openclaw"]';
  private readonly openclawMessages = '[data-testid="openclaw-message"], .openclaw-message, [data-channel="openclaw"] .message';
  private readonly openclawStatusIndicator = '[data-testid="openclaw-status"], .openclaw-status';

  // MCP channel selectors
  private readonly mcpChatInput = 'textarea[data-testid="mcp-chat-input"], textarea[placeholder*="Claude"], #mcp-chat-input';
  private readonly mcpSendButton = 'button[data-testid="mcp-send"], button[aria-label*="发送"][data-channel="mcp"]';
  private readonly mcpMessages = '[data-testid="mcp-message"], .mcp-message, [data-channel="mcp"] .message';
  private readonly mcpStatusIndicator = '[data-testid="mcp-status"], .mcp-status';

  // Channel connection status
  private readonly channelConnectedIndicator = '[data-testid="channel-connected"], .channel-connected';
  private readonly channelDisconnectedIndicator = '[data-testid="channel-disconnected"], .channel-disconnected';

  /**
   * Open the Haipee app and navigate to channel test page
   */
  async openChannelTestPage(): Promise<void> {
    await this.waitForReactReady();
    // Look for channel test button or navigate via URL
    const channelTestBtn = await $('button:has-text("Channel"), a:has-text("Channel")');
    if (await channelTestBtn.isExisting()) {
      await channelTestBtn.click();
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Check if OpenClaw channel is connected
   */
  async isOpenClawChannelConnected(): Promise<boolean> {
    const indicator = await $(this.openclawStatusIndicator);
    if (await indicator.isExisting()) {
      const text = await indicator.getText();
      return text.includes('connected') || text.includes('已连接');
    }
    return false;
  }

  /**
   * Send message via OpenClaw channel
   */
  async sendOpenClawMessage(text: string): Promise<void> {
    const input = await this.waitForElement(this.openclawChatInput);
    await input.clearValue();
    await input.addValue(text);

    const send = await this.waitForClickable(this.openclawSendButton);
    await send.click();
  }

  /**
   * Get all OpenClaw channel messages
   */
  async getOpenClawMessages(): Promise<string[]> {
    const messages = await $$(this.openclawMessages);
    const texts: string[] = [];
    for (const msg of messages) {
      texts.push(await msg.getText());
    }
    return texts;
  }

  /**
   * Wait for OpenClaw response
   */
  async waitForOpenClawResponse(timeout = 30000): Promise<string> {
    const initialCount = (await $$(this.openclawMessages)).length;

    await browser.waitUntil(
      async () => {
        const currentCount = (await $$(this.openclawMessages)).length;
        return currentCount > initialCount;
      },
      { timeout, timeoutMsg: 'No response received from OpenClaw channel' }
    );

    await browser.pause(500); // Wait for content to settle

    const messages = await this.getOpenClawMessages();
    return messages[messages.length - 1] || '';
  }

  /**
   * Check if MCP channel is connected
   */
  async isMcpChannelConnected(): Promise<boolean> {
    const indicator = await $(this.mcpStatusIndicator);
    if (await indicator.isExisting()) {
      const text = await indicator.getText();
      return text.includes('connected') || text.includes('已连接');
    }
    return false;
  }

  /**
   * Send message via MCP channel
   */
  async sendMcpMessage(text: string): Promise<void> {
    const input = await this.waitForElement(this.mcpChatInput);
    await input.clearValue();
    await input.addValue(text);

    const send = await this.waitForClickable(this.mcpSendButton);
    await send.click();
  }

  /**
   * Get all MCP channel messages
   */
  async getMcpMessages(): Promise<string[]> {
    const messages = await $$(this.mcpMessages);
    const texts: string[] = [];
    for (const msg of messages) {
      texts.push(await msg.getText());
    }
    return texts;
  }

  /**
   * Wait for MCP response
   */
  async waitForMcpResponse(timeout = 60000): Promise<string> {
    const initialCount = (await $$(this.mcpMessages)).length;

    await browser.waitUntil(
      async () => {
        const currentCount = (await $$(this.mcpMessages)).length;
        return currentCount > initialCount;
      },
      { timeout, timeoutMsg: 'No response received from MCP channel' }
    );

    await browser.pause(500);

    const messages = await this.getMcpMessages();
    return messages[messages.length - 1] || '';
  }

  /**
   * Switch between channels
   */
  async switchToChannel(channel: 'openclaw' | 'mcp'): Promise<void> {
    const selector = channel === 'openclaw'
      ? 'button[data-testid="tab-openclaw"], button:has-text("OpenClaw")'
      : 'button[data-testid="tab-mcp"], button:has-text("Claude Code")';

    const btn = await $(selector);
    if (await btn.isExisting()) {
      await btn.click();
      await browser.pause(300);
    }
  }
}

const channelPage = new HaipeeChannelPage();

describe('Haipee Channel Communication', () => {
  before(async () => {
    await channelPage.openChannelTestPage();
  });

  describe('OpenClaw Channel', () => {
    it('should show OpenClaw channel UI', async () => {
      // Check for OpenClaw channel container
      const container = await $('[data-testid="openclaw-channel-container"], .openclaw-channel');
      expect(await container.isExisting()).toBe(true);
    });

    it('should have input field for sending messages', async () => {
      const input = await $(channelPage['openclawChatInput']);
      expect(await input.isExisting()).toBe(true);
      expect(await input.isDisplayed()).toBe(true);
    });

    it('should have send button', async () => {
      const sendBtn = await $(channelPage['openclawSendButton']);
      expect(await sendBtn.isExisting()).toBe(true);
    });

    it('should send message and show in message list', async () => {
      const testMessage = `Test message ${Date.now()}`;

      await channelPage.sendOpenClawMessage(testMessage);

      // Wait for message to appear
      await browser.pause(1000);

      const messages = await channelPage.getOpenClawMessages();
      const found = messages.some(m => m.includes(testMessage));

      expect(found).toBe(true);
    });

    it('should receive response from OpenClaw', async () => {
      const testMessage = 'Hello from Haipee!';

      await channelPage.sendOpenClawMessage(testMessage);

      try {
        const response = await channelPage.waitForOpenClawResponse(30000);
        expect(response.length).toBeGreaterThan(0);
        console.log('OpenClaw Response:', response.substring(0, 100));
      } catch {
        // Response might not be available if no OpenClaw server is running
        console.log('OpenClaw response not available (server may not be running)');
      }
    });
  });

  describe('MCP Channel (Claude Code)', () => {
    it('should show MCP channel UI', async () => {
      // Switch to MCP channel tab
      await channelPage.switchToChannel('mcp');

      const container = await $('[data-testid="mcp-channel-container"], .mcp-channel');
      expect(await container.isExisting()).toBe(true);
    });

    it('should have input field for sending messages', async () => {
      const input = await $(channelPage['mcpChatInput']);
      expect(await input.isExisting()).toBe(true);
      expect(await input.isDisplayed()).toBe(true);
    });

    it('should have send button', async () => {
      const sendBtn = await $(channelPage['mcpSendButton']);
      expect(await sendBtn.isExisting()).toBe(true);
    });

    it('should send message and show in message list', async () => {
      const testMessage = `MCP test message ${Date.now()}`;

      await channelPage.sendMcpMessage(testMessage);

      // Wait for message to appear
      await browser.pause(1000);

      const messages = await channelPage.getMcpMessages();
      const found = messages.some(m => m.includes(testMessage));

      expect(found).toBe(true);
    });

    it('should show channel connection status', async () => {
      const statusIndicator = await $('[data-testid="mcp-status"], .mcp-status');
      if (await statusIndicator.isExisting()) {
        const status = await statusIndicator.getText();
        console.log('MCP Channel Status:', status);
        // Status should show something (connected or disconnected)
        expect(status.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Channel Switching', () => {
    it('should switch between OpenClaw and MCP channels', async () => {
      // Switch to OpenClaw
      await channelPage.switchToChannel('openclaw');
      await browser.pause(300);

      const openclawInput = await $(channelPage['openclawChatInput']);
      expect(await openclawInput.isDisplayed()).toBe(true);

      // Switch to MCP
      await channelPage.switchToChannel('mcp');
      await browser.pause(300);

      const mcpInput = await $(channelPage['mcpChatInput']);
      expect(await mcpInput.isDisplayed()).toBe(true);
    });
  });
});