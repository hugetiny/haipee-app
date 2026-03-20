/// <reference types="@wdio/globals/types" />
/**
 * OpenClawChatPage - Page object for OpenClaw chat interface
 */

import { TauriBasePage } from './TauriBasePage';

export class OpenClawChatPage extends TauriBasePage {
  // Selectors
  private readonly chatInput = 'textarea[placeholder*="输入"], textarea[placeholder*="message"], textarea';
  private readonly sendButton = 'button[aria-label*="发送"], button[aria-label*="Send"], button[type="submit"]';
  private readonly stopButton = 'button[aria-label*="停止"], button[aria-label*="Stop"]';
  private readonly messageContainer = '[data-testid="message"], .message, [class*="message"]';
  private readonly newSessionButton = 'button[aria-label*="新建"], button[aria-label*="New"]';

  /**
   * Navigate to OpenClaw chat
   */
  async openChat(): Promise<void> {
    // Switch to openclaw agent
    const agentButton = await $('button:has-text("OpenClaw")');
    if (await agentButton.isExisting()) {
      await agentButton.click();
      await browser.pause(500);
    }
    await this.waitForReactReady();
  }

  /**
   * Send a message and wait for response
   */
  async sendMessageAndWait(text: string, timeout = 60_000): Promise<string> {
    // Type message
    const input = await this.waitForElement(this.chatInput);
    await input.clearValue();
    await input.addValue(text);

    // Click send
    const send = await this.waitForClickable(this.sendButton);
    await send.click();

    // Wait for response
    return this.waitForResponse(timeout);
  }

  /**
   * Wait for AI response to complete
   */
  async waitForResponse(timeout = 60_000): Promise<string> {
    // Wait for response to start
    await browser.pause(1000);

    // Wait for stop button to disappear (generation complete)
    await browser.waitUntil(
      async () => {
        const stopBtn = await $(this.stopButton);
        const exists = await stopBtn.isExisting();
        return !exists;
      },
      { timeout, timeoutMsg: 'Response did not complete within timeout' }
    );

    // Get the last message
    return this.getLastMessage();
  }

  /**
   * Get the last message content
   */
  async getLastMessage(): Promise<string> {
    const messages = (await $$(this.messageContainer)) as unknown as WebdriverIO.Element[];
    if (messages.length === 0) {
      throw new Error('No messages found');
    }
    const lastMessage = messages[messages.length - 1];
    return lastMessage.getText();
  }

  /**
   * Stop generation
   */
  async stopGeneration(): Promise<void> {
    const stopBtn = await $(this.stopButton);
    if (await stopBtn.isExisting()) {
      await stopBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Start new session
   */
  async newSession(): Promise<void> {
    const newBtn = await $(this.newSessionButton);
    if (await newBtn.isExisting()) {
      await newBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Check if chat is ready for input
   */
  async isReadyForInput(): Promise<boolean> {
    const input = $(this.chatInput);
    return (await input.isExisting()) && (await input.isDisplayed());
  }

  /**
   * Get all messages
   */
  async getAllMessages(): Promise<string[]> {
    const messages = await $$(this.messageContainer);
    const texts: string[] = [];
    for (const msg of messages) {
      texts.push(await msg.getText());
    }
    return texts;
  }
}

export const openClawChatPage = new OpenClawChatPage();