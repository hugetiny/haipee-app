/**
 * Test Utilities for Tauri E2E Tests
 *
 * Shared helper functions for WebdriverIO Tauri tests.
 */

/// <reference types="@wdio/globals/types" />

/**
 * Check if any element on the page contains the given text.
 * Uses both innerText and textContent for WKWebView compatibility.
 * textContent includes hidden elements (e.g. collapsed accordion content).
 */
export async function pageContainsText(text: string): Promise<boolean> {
  return browser.execute((t) => {
    const inner = (document.body as HTMLElement)?.innerText || '';
    const content = document.body?.textContent || '';
    return inner.includes(t) || content.includes(t);
  }, text);
}

/**
 * Wait until any of the given texts appears on the page.
 * More reliable than a fixed pause for WKWebView tab/animation timing.
 */
export async function waitForAnyText(
  texts: string[],
  timeout = 10_000
): Promise<boolean> {
  try {
    await browser.waitUntil(
      async () => {
        for (const text of texts) {
          if (await pageContainsText(text)) return true;
        }
        return false;
      },
      { timeout, timeoutMsg: `None of [${texts.join(', ')}] appeared within ${timeout}ms` }
    );
    return true;
  } catch {
    return false;
  }
}

/**
 * Wait for specific text to appear on the page.
 */
export async function waitForText(
  text: string,
  timeout = 10_000
): Promise<boolean> {
  try {
    await browser.waitUntil(
      async () => pageContainsText(text),
      { timeout, timeoutMsg: `Text "${text}" did not appear within ${timeout}ms` }
    );
    return true;
  } catch {
    return false;
  }
}

/**
 * Count elements matching selector.
 */
export async function countElements(selector: string): Promise<number> {
  return browser.execute((sel) => {
    return document.querySelectorAll(sel).length;
  }, selector);
}

/**
 * Check if Tauri IPC is available.
 */
export async function isTauriAvailable(): Promise<boolean> {
  return browser.execute(() => typeof (window as any).__TAURI__ !== 'undefined');
}

/**
 * Call Tauri IPC if available, return null otherwise.
 */
export async function invokeIPC<T>(
  cmd: string,
  args: Record<string, unknown> = {}
): Promise<T | null> {
  const hasTauri = await isTauriAvailable();
  if (!hasTauri) return null;

  return browser.execute(async (c, a) => {
    try {
      const { invoke } = (window as any).__TAURI__.core;
      return await invoke(c, a);
    } catch (e) {
      console.error(`IPC call ${c} failed:`, e);
      return null;
    }
  }, cmd, args);
}

/**
 * Generate a unique test ID.
 */
export function generateTestId(): string {
  return `test-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Sleep for specified milliseconds.
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Wait for element to be visible.
 */
export async function waitForElement(
  selector: string,
  timeout = 10_000
) {
  const el = $(selector);
  await el.waitForExist({ timeout });
  return el;
}

/**
 * Wait for element to be clickable.
 */
export async function waitForClickable(
  selector: string,
  timeout = 10_000
) {
  const el = $(selector);
  await el.waitForClickable({ timeout });
  return el;
}

/**
 * Safe click - wait for element then click.
 */
export async function safeClick(selector: string): Promise<void> {
  const el = await waitForClickable(selector);
  await el.click();
}

/**
 * Input text - clear then type.
 */
export async function inputText(selector: string, text: string): Promise<void> {
  const el = await waitForElement(selector);
  await el.clearValue();
  await el.addValue(text);
}

/**
 * Get text content of element.
 */
export async function getText(selector: string): Promise<string> {
  const el = await $(selector);
  return el.getText();
}

/**
 * Check if element exists.
 */
export async function elementExists(selector: string): Promise<boolean> {
  const el = await $(selector);
  return el.isExisting();
}

/**
 * Click button by text content.
 */
export async function clickButtonByText(
  texts: string[]
): Promise<boolean> {
  const uid = `wdio-btn-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const found = await browser.execute((searchTexts, attrKey) => {
    const buttons = Array.from(document.querySelectorAll('button'));
    for (const btn of buttons) {
      const text = btn.textContent?.trim() || '';
      for (const search of searchTexts) {
        if (text.includes(search)) {
          btn.setAttribute(attrKey, 'true');
          return true;
        }
      }
    }
    return false;
  }, texts, uid);

  if (found) {
    try {
      const el = await $(`[${uid}]`);
      if (await el.isExisting()) {
        await el.click();
        return true;
      }
    } catch {
      // fall through
    }
  }
  return false;
}

/**
 * Select option in dropdown.
 */
export async function selectOption(
  selectSelector: string,
  value: string
): Promise<void> {
  const select = await $(selectSelector);
  await select.waitForExist({ timeout: 5000 });
  await select.selectByAttribute('value', value);
}

/**
 * Toggle a switch.
 */
export async function toggleSwitch(
  name: string
): Promise<boolean> {
  const toggle = await $(`[data-testid="${name}-toggle"], [role="switch"][aria-label*="${name}"]`);
  await toggle.waitForExist({ timeout: 5000 });

  const initialState = await toggle.getAttribute('data-checked') === 'true' ||
    await toggle.getAttribute('aria-checked') === 'true';

  await toggle.click();
  await browser.pause(300);

  return !initialState;
}

/**
 * Get switch state.
 */
export async function getSwitchState(name: string): Promise<boolean> {
  const toggle = await $(`[data-testid="${name}-toggle"], [role="switch"][aria-label*="${name}"]`);
  if (!await toggle.isExisting()) {
    throw new Error(`Toggle ${name} not found`);
  }
  const dataChecked = await toggle.getAttribute('data-checked');
  const ariaChecked = await toggle.getAttribute('aria-checked');
  return dataChecked === 'true' || ariaChecked === 'true';
}

/**
 * Open accordion by text hints.
 */
export async function openAccordion(textHints: string[]): Promise<boolean> {
  const uid = `wdio-acc-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const found = await browser.execute((hints, attrKey) => {
    const triggers = Array.from(
      document.querySelectorAll('[data-radix-accordion-trigger], button[data-state], [role="button"]')
    );
    const el = triggers.find(
      (el) => (el as HTMLElement).innerText?.match(new RegExp(hints.join('|'))) ||
               el.textContent?.match(new RegExp(hints.join('|')))
    );
    if (el) {
      el.setAttribute(attrKey, 'true');
      return true;
    }
    return false;
  }, textHints, uid);

  if (found) {
    try {
      const el = await $(`[${uid}]`);
      if (await el.isExisting()) {
        await el.click();
        await browser.pause(600);
        return true;
      }
    } catch {
      // fall through
    }
  }
  return false;
}

/**
 * Wait for loading to complete.
 */
export async function waitForLoadingComplete(timeout = 10_000): Promise<void> {
  await browser.waitUntil(
    async () => {
      const loader = await $('[data-testid="loading"], .animate-spin, [aria-busy="true"]');
      const exists = await loader.isExisting();
      return !exists;
    },
    { timeout, timeoutMsg: 'Loading did not complete' }
  );
}

/**
 * Wait for API request to complete.
 */
export async function waitForApiComplete(timeout = 30_000): Promise<void> {
  await browser.waitUntil(
    async () => {
      const count = await browser.execute(() => {
        return document.querySelectorAll('[data-testid="loading"], .animate-spin, [aria-busy="true"]').length;
      });
      return count === 0;
    },
    { timeout, timeoutMsg: 'API request did not complete' }
  );
}

/**
 * Take screenshot with timestamp.
 */
export async function takeScreenshot(name: string): Promise<void> {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  await browser.saveScreenshot(`./ai-loop-logs/screenshots/${name}-${timestamp}.png`);
}

/**
 * Generate random provider name.
 */
export function generateProviderName(prefix = 'TestProvider'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
}

/**
 * Generate test API key.
 */
export function generateTestApiKey(): string {
  return `sk-test-${Math.random().toString(36).slice(2, 10)}-${Date.now()}`;
}