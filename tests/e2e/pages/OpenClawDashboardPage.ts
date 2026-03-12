import { Page, Locator, expect } from '@playwright/test';

/**
 * Page Object for OpenClaw Dashboard
 * Encapsulates all interactions with the OpenClaw configuration page
 */
export class OpenClawDashboardPage {
  readonly page: Page;
  readonly url: string;

  // Main navigation
  readonly dashboardNav: Locator;
  readonly sessionsNav: Locator;
  readonly workspaceNav: Locator;

  // Provider management
  readonly providerCards: Locator;
  readonly addProviderButton: Locator;
  readonly providerSearch: Locator;

  // Chat interface
  readonly chatInput: Locator;
  readonly sendButton: Locator;
  readonly messageList: Locator;
  readonly userMessages: Locator;
  readonly assistantMessages: Locator;

  // Configuration panels
  readonly envPanel: Locator;
  readonly toolsPanel: Locator;
  readonly agentsPanel: Locator;
  readonly gatewayPanel: Locator;

  constructor(page: Page) {
    this.page = page;
    this.url = '/'; // Default route for OpenClaw

    // Navigation
    this.dashboardNav = page.locator('[data-testid="nav-dashboard"], [aria-label*="Dashboard"]').first();
    this.sessionsNav = page.locator('[data-testid="nav-sessions"], [aria-label*="Sessions"]').first();
    this.workspaceNav = page.locator('[data-testid="nav-workspace"], [aria-label*="Workspace"]').first();

    // Provider management
    this.providerCards = page.locator('[data-testid="provider-card"], .provider-card');
    this.addProviderButton = page.locator('button:has-text("Add"), button:has-text("添加"), [data-testid="add-provider"]').first();
    this.providerSearch = page.locator('input[placeholder*="search"], input[placeholder*="搜索"]').first();

    // Chat interface
    this.chatInput = page.locator('textarea[placeholder*="Ask"], textarea[placeholder*="提问"], [data-testid="chat-input"]').first();
    this.sendButton = page.locator('button[type="submit"], button:has-text("Send"), button:has-text("发送"), [data-testid="send-button"]').first();
    this.messageList = page.locator('[data-testid="message-list"], .message-list, .chat-messages').first();
    this.userMessages = page.locator('[data-testid="user-message"], .user-message, [role="user"]');
    this.assistantMessages = page.locator('[data-testid="assistant-message"], .assistant-message, [role="assistant"]');

    // Configuration panels
    this.envPanel = page.locator('[data-testid="env-panel"], .env-panel').first();
    this.toolsPanel = page.locator('[data-testid="tools-panel"], .tools-panel').first();
    this.agentsPanel = page.locator('[data-testid="agents-panel"], .agents-panel').first();
    this.gatewayPanel = page.locator('[data-testid="gateway-panel"], .gateway-panel').first();
  }

  /**
   * Navigate to the OpenClaw Dashboard
   */
  async goto() {
    await this.page.goto(this.url);
    await this.page.waitForLoadState('networkidle');
    await this.waitForDashboard();
  }

  /**
   * Wait for dashboard to be ready
   */
  async waitForDashboard() {
    // Wait for any of the main elements to be visible
    await expect(this.providerCards.first()).toBeVisible({ timeout: 10000 }).catch(() => {
      // Provider cards might not be present if no providers configured
    });
  }

  /**
   * Get the count of configured providers
   */
  async getProviderCount(): Promise<number> {
    return await this.providerCards.count();
  }

  /**
   * Select a provider by name
   */
  async selectProvider(name: string) {
    const provider = this.page.locator(`text=${name}`).first();
    await provider.click();
    await this.page.waitForTimeout(500); // Wait for selection animation
  }

  /**
   * Send a chat message
   */
  async sendMessage(message: string) {
    // Fill the chat input
    await this.chatInput.fill(message);

    // Click send or press Enter
    if (await this.sendButton.isVisible().catch(() => false)) {
      await this.sendButton.click();
    } else {
      await this.chatInput.press('Enter');
    }

    // Wait for response
    await this.page.waitForTimeout(2000);
  }

  /**
   * Get the last assistant message
   */
  async getLastAssistantMessage(): Promise<string> {
    const count = await this.assistantMessages.count();
    if (count === 0) return '';
    return await this.assistantMessages.nth(count - 1).textContent() || '';
  }

  /**
   * Get the last user message
   */
  async getLastUserMessage(): Promise<string> {
    const count = await this.userMessages.count();
    if (count === 0) return '';
    return await this.userMessages.nth(count - 1).textContent() || '';
  }

  /**
   * Wait for assistant response
   */
  async waitForResponse(timeout = 30000) {
    const initialCount = await this.assistantMessages.count();
    await this.page.waitForFunction(
      (count) => document.querySelectorAll('[data-testid="assistant-message"], .assistant-message').length > count,
      initialCount,
      { timeout }
    );
  }

  /**
   * Check if there are any error messages
   */
  async hasError(): Promise<boolean> {
    const errorElements = this.page.locator('.error, [data-testid="error"], .toast-error, [role="alert"]');
    return await errorElements.count() > 0;
  }

  /**
   * Get error message if present
   */
  async getErrorMessage(): Promise<string | null> {
    const errorElement = this.page.locator('.error, [data-testid="error"], .toast-error').first();
    if (await errorElement.isVisible().catch(() => false)) {
      return await errorElement.textContent();
    }
    return null;
  }

  /**
   * Open the settings/add provider dialog
   */
  async openAddProvider() {
    await this.addProviderButton.click();
    await this.page.waitForTimeout(500);
  }

  /**
   * Take a screenshot with provider name
   */
  async screenshot(name: string) {
    await this.page.screenshot({
      path: `playwright-report/screenshots/${name}.png`,
      fullPage: true
    });
  }
}
