/**
 * McpPage - Page object for MCP server management
 */

/// <reference types="@wdio/globals/types" />

import { TauriBasePage } from './TauriBasePage';

export interface McpServerFormData {
  name: string;
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

export type AppId = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';

export class McpPage extends TauriBasePage {
  /**
   * Navigate to MCP configuration view
   */
  async open(): Promise<void> {
    await this.waitForReactReady();

    // Click MCP nav button
    const mcpBtn = await $('button[aria-label*="MCP"], [data-testid="mcp-nav"]');
    if (await mcpBtn.isExisting()) {
      await mcpBtn.click();
      await browser.pause(500);
    }
  }

  /**
   * Get all MCP server cards
   */
  async getServerCards(): Promise<WebdriverIO.Element[]> {
    const cards = await $$('[data-testid="mcp-server-card"], .mcp-server-card');
    return [...cards] as unknown as WebdriverIO.Element[];
  }

  /**
   * Get server count
   */
  async getServerCount(): Promise<number> {
    const cards = await this.getServerCards();
    return cards.length;
  }

  /**
   * Click add server button
   */
  async clickAddServer(): Promise<void> {
    const addButton = await $('button[aria-label*="添加"], button*="Add Server", button*="添加服务器"]');
    await addButton.waitForClickable({ timeout: 5000 });
    await addButton.click();
    await browser.pause(300);
  }

  /**
   * Fill MCP server form
   */
  async fillServerForm(data: McpServerFormData): Promise<void> {
    const form = await $('[data-testid="mcp-form"], form');
    await form.waitForExist({ timeout: 5000 });

    // Fill name
    const nameInput = await form.$('input[name="name"], input[placeholder*="名称"], input[placeholder*="Name"]');
    if (await nameInput.isExisting()) {
      await nameInput.setValue(data.name);
    }

    // Fill command
    const commandInput = await form.$('input[name="command"], input[placeholder*="command"], input[placeholder*="命令"]');
    if (await commandInput.isExisting()) {
      await commandInput.setValue(data.command);
    }

    // Fill args (if applicable)
    if (data.args && data.args.length > 0) {
      const argsInput = await form.$('input[name="args"], textarea[name="args"], input[placeholder*="args"]');
      if (await argsInput.isExisting()) {
        await argsInput.setValue(data.args.join(' '));
      }
    }
  }

  /**
   * Save server
   */
  async saveServer(): Promise<void> {
    const saveButton = await $('button[type="submit"], button*="保存", button*="Save"]');
    await saveButton.waitForClickable({ timeout: 5000 });
    await saveButton.click();
    await browser.pause(500);
  }

  /**
   * Cancel server form
   */
  async cancelServerForm(): Promise<void> {
    const cancelButton = await $('button*="取消"], button*="Cancel"]');
    if (await cancelButton.isExisting()) {
      await cancelButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Add a new MCP server (full flow)
   */
  async addServer(data: McpServerFormData): Promise<void> {
    await this.clickAddServer();
    await this.fillServerForm(data);
    await this.saveServer();
  }

  /**
   * Delete a server by name
   */
  async deleteServer(name: string): Promise<void> {
    const cards = await this.getServerCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const deleteButton = await card.$('button[aria-label*="删除"], button[aria-label*="Delete"], button*="删除"]');
        if (await deleteButton.isExisting()) {
          await deleteButton.click();
          await browser.pause(300);

          // Confirm deletion
          const confirmButton = await $('button*="确认"], button*="Confirm"], button*="Yes"]');
          if (await confirmButton.isExisting()) {
            await confirmButton.click();
            await browser.pause(500);
          }
        }
        return;
      }
    }
  }

  /**
   * Toggle server enabled state
   */
  async toggleServer(name: string): Promise<void> {
    const cards = await this.getServerCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const toggle = await card.$('[role="switch"], button[aria-label*="toggle"]');
        if (await toggle.isExisting()) {
          await toggle.click();
          await browser.pause(300);
        }
        return;
      }
    }
  }

  /**
   * Toggle server for specific app
   */
  async toggleServerApp(serverName: string, app: AppId): Promise<void> {
    const cards = await this.getServerCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(serverName)) {
        // Find app toggle within the card
        const appToggle = await card.$(`[data-app="${app}"], button[aria-label*="${app}"]`);
        if (await appToggle.isExisting()) {
          await appToggle.click();
          await browser.pause(300);
        }
        return;
      }
    }
  }

  /**
   * Edit server by name
   */
  async editServer(name: string, data: Partial<McpServerFormData>): Promise<void> {
    const cards = await this.getServerCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        const editButton = await card.$('button[aria-label*="编辑"], button[aria-label*="Edit"], button*="编辑"]');
        if (await editButton.isExisting()) {
          await editButton.click();
          await browser.pause(300);

          // Fill form with new data
          if (data.name) {
            const nameInput = await $('input[name="name"]');
            if (await nameInput.isExisting()) {
              await nameInput.setValue(data.name);
            }
          }
          if (data.command) {
            const commandInput = await $('input[name="command"]');
            if (await commandInput.isExisting()) {
              await commandInput.setValue(data.command);
            }
          }

          await this.saveServer();
        }
        return;
      }
    }
  }

  /**
   * Check if server exists
   */
  async serverExists(name: string): Promise<boolean> {
    const cards = await this.getServerCards();
    for (const card of cards) {
      const text = await card.getText();
      if (text.includes(name)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Get visible server names
   */
  async getVisibleServerNames(): Promise<string[]> {
    const cards = await this.getServerCards();
    const names: string[] = [];
    for (const card of cards) {
      const nameEl = await card.$('[data-testid="server-name"], h3, h4, .server-name');
      if (await nameEl.isExisting()) {
        names.push(await nameEl.getText());
      }
    }
    return names;
  }
}

export const mcpPage = new McpPage();