/**
 * JourneyHelpers - Helper functions for end-to-end journey tests
 *
 * Provides reusable utilities for complex user flows that span multiple
 * pages and interactions.
 */

/// <reference types="@wdio/globals/types" />

export class JourneyHelpers {
  /**
   * Wait for Toast message to appear and get text
   */
  static async waitForToast(timeout = 5000): Promise<string | null> {
    try {
      const toast = await $('[data-sonner-toast], [role="status"], [class*="toast"]');
      await toast.waitForExist({ timeout });
      return toast.getText();
    } catch {
      return null;
    }
  }

  /**
   * Click button by text content
   */
  static async clickButtonByText(text: string): Promise<boolean> {
    const clicked = await browser.execute((searchText) => {
      const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
      for (const btn of buttons) {
        const btnText = btn.textContent?.trim() || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        if (btnText.includes(searchText) || ariaLabel.includes(searchText)) {
          (btn as HTMLElement).click();
          return true;
        }
      }
      return false;
    }, text);

    if (clicked) {
      await browser.pause(300);
    }
    return clicked;
  }

  /**
   * Fill form field by selector
   */
  static async fillFormField(selector: string, value: string): Promise<void> {
    const field = await $(selector);
    if (await field.isExisting()) {
      await field.clearValue();
      await field.addValue(value);
    }
  }

  /**
   * Wait for element to disappear
   */
  static async waitForElementGone(selector: string, timeout = 10000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const el = await $(selector);
        return !(await el.isExisting());
      },
      { timeout, timeoutMsg: `Element ${selector} did not disappear` }
    );
  }

  /**
   * Check if page contains text
   */
  static async pageContainsText(text: string): Promise<boolean> {
    return browser.execute((searchText) => {
      const body = document.body;
      const content = body.textContent || '';
      const inner = (body as HTMLElement).innerText || '';
      return content.includes(searchText) || inner.includes(searchText);
    }, text);
  }

  /**
   * Generate random test name
   */
  static generateTestName(prefix = 'Test'): string {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  }

  /**
   * Generate random test API key
   */
  static generateTestApiKey(): string {
    return `test_key_${Math.random().toString(36).substring(2, 15)}`;
  }

  /**
   * Generate random URL
   */
  static generateTestUrl(): string {
    return `https://api.test${Math.random().toString(36).substring(2, 6)}.example.com/v1`;
  }

  /**
   * Wait for loading to complete
   */
  static async waitForLoading(timeout = 10000): Promise<void> {
    await browser.waitUntil(
      async () => {
        const spinners = await $$('[class*="animate-spin"], [class*="loading"], [data-testid="loading"]');
        return spinners.length === 0;
      },
      { timeout, timeoutMsg: 'Loading did not complete' }
    );
  }

  /**
   * Check if element is visible
   */
  static async isElementVisible(selector: string): Promise<boolean> {
    const el = await $(selector);
    if (!(await el.isExisting())) return false;
    return el.isDisplayed();
  }

  /**
   * Get element text by selector
   */
  static async getElementText(selector: string): Promise<string | null> {
    const el = await $(selector);
    if (!(await el.isExisting())) return null;
    return el.getText();
  }

  /**
   * Clear all test data (for cleanup)
   */
  static async clearTestData(prefix: string): Promise<void> {
    // Find and delete all items with test prefix
    const items = await $$(`[data-name^="${prefix}"]`);
    for (const item of items) {
      try {
        const deleteBtn = await item.$('button[aria-label*="删除"], button[aria-label*="Delete"]');
        if (await deleteBtn.isExisting()) {
          await deleteBtn.click();
          await browser.pause(200);
          // Confirm deletion
          const confirmBtn = await $('button:has-text("确认"), button:has-text("Confirm")');
          if (await confirmBtn.isExisting()) {
            await confirmBtn.click();
            await browser.pause(300);
          }
        }
      } catch {
        // Continue to next item
      }
    }
  }

  /**
   * Take screenshot with timestamp
   */
  static async takeScreenshot(name: string): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    await browser.saveScreenshot(`./ai-loop-logs/screenshots/journey-${name}-${timestamp}.png`);
  }

  /**
   * Wait for navigation to complete
   */
  static async waitForNavigation(timeout = 5000): Promise<void> {
    await browser.pause(500);
    await this.waitForLoading(timeout);
  }

  /**
   * Get all visible list items
   */
  static async getVisibleItems(selector: string): Promise<string[]> {
    const items = await $$(selector);
    const texts: string[] = [];
    for (const item of items) {
      try {
        const text = await item.getText();
        if (text.trim()) {
          texts.push(text.trim());
        }
      } catch {
        // Skip if element is stale
      }
    }
    return texts;
  }

  /**
   * Check if modal is open
   */
  static async isModalOpen(): Promise<boolean> {
    const modal = await $('[role="dialog"], [class*="modal"], [class*="dialog"]');
    return modal.isExisting();
  }

  /**
   * Close modal by clicking backdrop or close button
   */
  static async closeModal(): Promise<void> {
    // Try close button first
    const closeBtn = await $('button[aria-label*="close"], button[aria-label*="关闭"]');
    if (await closeBtn.isExisting()) {
      await closeBtn.click();
      await browser.pause(300);
      return;
    }

    // Try clicking backdrop
    const backdrop = await $('[class*="overlay"], [class*="backdrop"]');
    if (await backdrop.isExisting()) {
      await backdrop.click();
      await browser.pause(300);
    }

    // Try pressing Escape
    await browser.keys(['Escape']);
    await browser.pause(300);
  }

  /**
   * Get form validation error
   */
  static async getFormError(): Promise<string | null> {
    const errorEl = await $('[class*="error"], [data-testid="form-error"], [role="alert"]');
    if (await errorEl.isExisting()) {
      return errorEl.getText();
    }
    return null;
  }

  /**
   * Check if form has validation error
   */
  static async hasFormError(): Promise<boolean> {
    const error = await this.getFormError();
    return error !== null;
  }

  /**
   * Retry an action until successful or max retries
   */
  static async retry<T>(
    action: () => Promise<T>,
    maxRetries = 3,
    delayMs = 500
  ): Promise<T> {
    let lastError: Error | undefined;
    for (let i = 0; i < maxRetries; i++) {
      try {
        return await action();
      } catch (error) {
        lastError = error as Error;
        if (i < maxRetries - 1) {
          await browser.pause(delayMs);
        }
      }
    }
    throw lastError;
  }
}