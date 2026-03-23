/**
 * CrabNebulaBasePage - Base page object for CrabNebula WebDriver tests
 *
 * Simplified compared to TauriBasePage - CrabNebula WebDriver is more standard.
 * No :has-text() workarounds needed, isDisplayed() works correctly.
 */

/// <reference types="@wdio/globals/types" />

export abstract class CrabNebulaBasePage {
  /**
   * Wait for React to render
   */
  async waitForReactReady(timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const childCount = await browser.execute(() =>
          document.getElementById('root')?.childElementCount ?? 0,
        );
        return childCount > 0;
      },
      { timeout, timeoutMsg: 'React did not render within timeout' }
    );
  }

  /**
   * Call a Tauri IPC command
   */
  async invokeIPC<T = unknown>(command: string, args?: Record<string, unknown>): Promise<T> {
    return browser.execute(
      async (cmd, cmdArgs) => {
        const { invoke } = (window as any).__TAURI__.core;
        return invoke(cmd, cmdArgs);
      },
      command,
      args ?? {}
    );
  }

  /**
   * Navigate to a section by clicking sidebar
   */
  async navigateTo(section: string): Promise<void> {
    await this.waitForReactReady();

    const selectors = [
      `button[aria-label*="${section}"]`,
      `[data-testid="${section.toLowerCase()}"]`,
    ];

    for (const selector of selectors) {
      try {
        const button = await $(selector);
        if (await button.isExisting()) {
          await button.waitForClickable({ timeout: 5000 });
          await button.click();
          await browser.pause(500);
          return;
        }
      } catch {
        // Try next selector
      }
    }

    console.log(`Navigation to "${section}" - no button found, may already be on page`);
  }

  /**
   * Wait for toast notification
   */
  async waitForToast(timeout = 5000): Promise<string | null> {
    try {
      const toast = await $('[data-sonner-toast], [role="status"]');
      await toast.waitForExist({ timeout });
      return toast.getText();
    } catch {
      return null;
    }
  }

  /**
   * Take a named screenshot
   */
  async screenshot(name: string): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    await browser.saveScreenshot(`./ai-loop-logs/screenshots/crabnebula-${name}-${timestamp}.png`);
  }

  /**
   * Wait for loading to complete
   */
  async waitForLoadingComplete(timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const loader = await $('[data-testid="loading"], .animate-spin');
        const exists = await loader.isExisting();
        return !exists;
      },
      { timeout, timeoutMsg: 'Loading did not complete' }
    );
  }

  /**
   * Get page title
   */
  async getTitle(): Promise<string> {
    return browser.getTitle();
  }

  /**
   * Check if element exists
   */
  async elementExists(selector: string): Promise<boolean> {
    const el = await $(selector);
    return el.isExisting();
  }

  /**
   * Get text content of element
   */
  async getText(selector: string): Promise<string> {
    const el = await $(selector);
    return el.getText();
  }

  /**
   * Click element with retry
   */
  async clickWithRetry(selector: string, maxRetries = 3): Promise<void> {
    for (let i = 0; i < maxRetries; i++) {
      try {
        const el = await $(selector);
        await el.waitForClickable({ timeout: 5000 });
        await el.click();
        return;
      } catch (err) {
        if (i === maxRetries - 1) throw err;
        await browser.pause(500);
      }
    }
  }

  /**
   * Check if current page has specific heading
   */
  async hasHeading(text: string): Promise<boolean> {
    return browser.execute((searchText) => {
      const headings = Array.from(document.querySelectorAll('h1, h2, h3'));
      return headings.some(h => h.textContent?.includes(searchText) ?? false);
    }, text);
  }

  /**
   * Wait for element to appear with retry
   */
  async waitForElement(selector: string, timeout = 10_000) {
    const el = await $(selector);
    await el.waitForExist({ timeout });
    return el;
  }

  /**
   * Wait for element to be clickable
   */
  async waitForClickable(selector: string, timeout = 10_000) {
    const el = await $(selector);
    await el.waitForClickable({ timeout });
    return el;
  }

  /**
   * Safe click - wait for element then click
   */
  async safeClick(selector: string): Promise<void> {
    const el = await this.waitForClickable(selector);
    await el.click();
  }

  /**
   * Input text - clear then type
   */
  async inputText(selector: string, text: string): Promise<void> {
    const el = await this.waitForElement(selector);
    await el.clearValue();
    await el.addValue(text);
  }

  /**
   * Wait for API request to complete (no loading spinners)
   */
  async waitForApiComplete(timeout = 30_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const spinners = await $$('[data-testid="loading"], .animate-spin, [aria-busy="true"]');
        const count = await spinners.length;
        return count === 0;
      },
      { timeout, timeoutMsg: 'API request did not complete' }
    );
  }

  /**
   * Wait for text to appear in element
   */
  async waitForText(selector: string, text: string, timeout = 10_000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const el = await $(selector);
        const content = await el.getText();
        return content.includes(text);
      },
      { timeout, timeoutMsg: `Text "${text}" did not appear` }
    );
  }

  /**
   * Get all elements matching selector
   */
  async getElements(selector: string) {
    return $$(selector);
  }

  /**
   * Find element by data-testid attribute
   */
  async findByTestId(testId: string) {
    return $(`[data-testid="${testId}"]`);
  }

  /**
   * Check if element is visible
   * CrabNebula WebDriver properly supports isDisplayed()
   */
  async isElementVisible(selector: string): Promise<boolean> {
    const el = await $(selector);
    const exists = await el.isExisting();
    if (!exists) return false;
    return el.isDisplayed();
  }

  /**
   * Click element by tag and text content
   */
  async clickByText(tag: string, text: string): Promise<void> {
    const elements = await $$(tag);
    for (const el of elements) {
      const elText = await el.getText();
      if (elText.includes(text)) {
        await el.click();
        return;
      }
    }
    throw new Error(`Element <${tag}> containing "${text}" not found`);
  }

  /**
   * Navigate to a specific view/tab
   */
  async navigateToView(view: string): Promise<void> {
    await this.waitForReactReady();

    const viewMap: Record<string, string> = {
      providers: 'providers',
      settings: 'settings',
      sessions: 'sessions',
      prompts: 'prompts',
      skills: 'skills',
      mcp: 'mcp',
      agents: 'agents',
      openclaw: 'openclaw',
      universal: 'universal',
    };

    const testId = viewMap[view.toLowerCase()] || view.toLowerCase();
    const navItem = await $(`[data-testid="nav-${testId}"], button[aria-label*="${view}"]`);

    if (await navItem.isExisting()) {
      await navItem.click();
      await browser.pause(500);
    }
  }

  /**
   * Check if page contains any of the given texts
   */
  async pageContainsAnyText(texts: string[]): Promise<boolean> {
    return browser.execute((t) => {
      const body = document.body;
      const inner = (body as HTMLElement)?.innerText ?? '';
      const content = body?.textContent ?? '';
      return t.some(text => inner.includes(text) || content.includes(text));
    }, texts);
  }
}