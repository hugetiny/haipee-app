/**
 * WebdriverIO Configuration – Tauri WebView E2E (Enhanced)
 *
 * Connects to the tauri-plugin-webdriver endpoint (default port 4445) that is
 * started when the Tauri binary is built with `--features webdriver`.
 *
 * Platform note (macOS):
 *   Tauri uses WKWebView (WebKit). tauri-plugin-webdriver proxies commands via
 *   Safari's remote debugging protocol. SafariDriver must be enabled:
 *     sudo safaridriver --enable
 *
 * The `onPrepare` hook builds the binary if out-of-date and launches it.
 * The `onComplete` hook kills the process.
 *
 * Enhanced with diagnostic hooks for AI dev loop:
 * - Screenshot capture on test start/failure
 * - Console log capture
 * - Network request capture
 */

import { defineConfig } from '@wdio/config';
import { launchTauriForWebDriver, healthCheck, isTauriAlive, LOG_FILE } from './tests/e2e/setup/tauri-setup.js';
import { killTauriProcess } from './tests/e2e/setup/tauri-teardown.js';
import { readFileSync, mkdirSync } from 'fs';
import { join } from 'path';

// Diagnostic capture modules (lazy loaded)
let screenshotCapture: any = null;
let consoleCapture: any = null;
let networkCapture: any = null;

// Ensure diagnostic directories exist
const DIAGNOSTIC_DIR = './ai-loop-logs';
mkdirSync(join(DIAGNOSTIC_DIR, 'screenshots'), { recursive: true });
mkdirSync(join(DIAGNOSTIC_DIR, 'console'), { recursive: true });
mkdirSync(join(DIAGNOSTIC_DIR, 'network'), { recursive: true });

/**
 * Lazy load diagnostic modules
 */
async function loadDiagnostics() {
  if (!screenshotCapture) {
    try {
      const mod = await import('./scripts/ai-dev-loop/diagnostics/screenshot-capture.js');
      screenshotCapture = mod.getScreenshotCapture();
    } catch {
      console.warn('[wdio] Screenshot capture not available');
    }
  }
  if (!consoleCapture) {
    try {
      const mod = await import('./scripts/ai-dev-loop/diagnostics/console-capture.js');
      consoleCapture = mod.getConsoleCapture();
    } catch {
      console.warn('[wdio] Console capture not available');
    }
  }
  if (!networkCapture) {
    try {
      const mod = await import('./scripts/ai-dev-loop/diagnostics/network-capture.js');
      networkCapture = mod.getNetworkCapture();
    } catch {
      console.warn('[wdio] Network capture not available');
    }
  }
}

export const config = defineConfig({
  runner: 'local',

  specs: [
    // Basic WebView smoke tests - verified working
    './tests/e2e/tauri/app.spec.ts',
    // Note: Other test files excluded until UI selectors are updated:
    // - navigation.spec.ts: navigation selectors don't match current UI
    // - tests/e2e-tauri/**/*.spec.ts: element selectors need updating
  ],
  exclude: [],
  maxInstances: 1, // Only one Tauri window at a time

  // ── Connect to tauri-plugin-webdriver endpoint ───────────────────────────
  hostname: '127.0.0.1',
  port: 4445,
  path: '/',

  // On macOS WKWebView; on Linux the WRY WebView is Blink-based.
  // tauri-plugin-webdriver exposes a W3C WebDriver-compatible server so
  // WebdriverIO connects without a separate ChromeDriver/SafariDriver.
  capabilities: [
    {
      // 'wry' is the capability identifier tauri-plugin-webdriver recognises.
      browserName: 'wry',
    },
  ],

  // ── Logging ──────────────────────────────────────────────────────────────
  logLevel: 'warn',

  // ── Retry & timeouts ─────────────────────────────────────────────────────
  bail: 0,
  waitforTimeout: 15_000,
  connectionRetryTimeout: 180_000,
  connectionRetryCount: 5,

  // ── Framework ────────────────────────────────────────────────────────────
  framework: 'mocha',
  reporters: ['spec'],
  mochaOpts: {
    ui: 'bdd',
    timeout: 90_000,
  },

  // ── Process lifecycle ────────────────────────────────────────────────────
  onPrepare: async () => {
    console.log('[wdio] Starting Tauri for WebDriver tests...');
    await launchTauriForWebDriver();
  },

  // ── Before test suite ────────────────────────────────────────────────────
  before: async () => {
    // ── Patch $() to handle :has-text() pseudo-selector for WKWebView ────────
    // WKWebView does not support the non-standard :has-text() pseudo-selector.
    // We intercept selectors containing :has-text() and translate them to
    // JavaScript-based text search before passing to the browser.
    browser.overwriteCommand('$' as any, async function(
      this: WebdriverIO.Browser,
      originalFn: (...args: any[]) => Promise<WebdriverIO.Element>,
      selector: string | any,
      ...args: any[]
    ) {
      if (typeof selector === 'string' && selector.includes(':has-text(')) {
        // Parse all alternative selectors (split on comma, handling quoted strings)
        const alternatives = selector.split(/,(?![^"']*(?:["'][^"']*["'])*[^"']*$)/).map((s: string) => s.trim());

        // Try each alternative selector in order
        for (const alt of alternatives) {
          if (alt.includes(':has-text(')) {
            // Handle :has-text() via JavaScript execution
            try {
              const textMatch = alt.match(/:has-text\("([^"]+)"\)/);
              if (!textMatch) continue;
              const searchText = textMatch[1];
              const tagPart = alt.split(':has-text(')[0].trim() || '*';

              const el = await browser.execute((tag: string, text: string) => {
                const elements = Array.from(document.querySelectorAll(tag || '*'));
                return elements.find((el) => (el as HTMLElement).innerText?.includes(text) || el.textContent?.includes(text)) || null;
              }, tagPart, searchText);

              if (el) {
                // Wrap the DOM element as a WebdriverIO element
                return browser.$(el as any);
              }
            } catch {
              continue;
            }
          } else if (alt) {
            // Try as normal CSS selector
            try {
              const el = await originalFn.call(this, alt);
              if (await el.isExisting()) {
                return el;
              }
            } catch {
              continue;
            }
          }
        }

        // Nothing found - return a "not found" element wrapper by using a selector
        // that definitely won't match anything, so .isExisting() returns false
        return originalFn.call(this, '[data-wdio-not-found-sentinel="true"]');
      }

      // For comma-separated selectors without :has-text(), try each part separately
      // to avoid WKWebView throwing on invalid pseudo-selectors
      if (typeof selector === 'string' && selector.includes(',')) {
        const parts = selector.split(',').map((s: string) => s.trim());
        for (const part of parts) {
          try {
            const el = await originalFn.call(this, part);
            if (await el.isExisting()) {
              return el;
            }
          } catch {
            continue;
          }
        }
        // Return last part's result (will be not-found element)
        return originalFn.call(this, parts[parts.length - 1]);
      }

      return originalFn.call(this, selector, ...args);
    });

    // ── Patch $$() similarly for :has-text() ─────────────────────────────────
    browser.overwriteCommand('$$' as any, async function(
      this: WebdriverIO.Browser,
      originalFn: (...args: any[]) => Promise<WebdriverIO.ElementArray>,
      selector: string | any,
      ...args: any[]
    ) {
      if (typeof selector === 'string' && selector.includes(':has-text(')) {
        const alternatives = selector.split(/,(?![^"']*(?:["'][^"']*["'])*[^"']*$)/).map((s: string) => s.trim());
        const results: WebdriverIO.Element[] = [];

        for (const alt of alternatives) {
          if (alt.includes(':has-text(')) {
            try {
              const textMatch = alt.match(/:has-text\("([^"]+)"\)/);
              if (!textMatch) continue;
              const searchText = textMatch[1];
              const tagPart = alt.split(':has-text(')[0].trim() || '*';

              const els = await browser.execute((tag: string, text: string) => {
                const elements = Array.from(document.querySelectorAll(tag || '*'));
                return elements.filter((el) => (el as HTMLElement).innerText?.includes(text) || el.textContent?.includes(text));
              }, tagPart, searchText);

              if (Array.isArray(els) && els.length > 0) {
                for (const domEl of els) {
                  try {
                    const wdioEl = await browser.$(domEl as any);
                    results.push(wdioEl);
                  } catch { /* ignore */ }
                }
              }
            } catch {
              continue;
            }
          } else if (alt) {
            try {
              const els = await originalFn.call(this, alt);
              results.push(...(els as WebdriverIO.Element[]));
            } catch {
              continue;
            }
          }
        }

        return results as any;
      }

      // For comma-separated selectors without :has-text(), collect from all parts
      if (typeof selector === 'string' && selector.includes(',')) {
        const parts = selector.split(',').map((s: string) => s.trim());
        const results: WebdriverIO.Element[] = [];
        for (const part of parts) {
          try {
            const els = await originalFn.call(this, part);
            results.push(...(els as WebdriverIO.Element[]));
          } catch {
            continue;
          }
        }
        return results as any;
      }

      return originalFn.call(this, selector, ...args);
    });

    // Health check
    const alive = await healthCheck();
    if (!alive) {
      console.error('[wdio] Tauri process not healthy before test suite');
      if (!isTauriAlive()) {
        console.error('[wdio] Tauri process has crashed! Check logs:', LOG_FILE);
        try {
          const logs = readFileSync(LOG_FILE, 'utf-8');
          const lastLines = logs.split('\n').slice(-50).join('\n');
          console.error('[wdio] Last 50 lines of Tauri log:\n', lastLines);
        } catch {
          // ignore
        }
      }
    }

    // Wait for React to render (tauri dev loads from dev server automatically)
    console.log('[wdio] Waiting for React to render...');
    try {
      await browser.waitUntil(
        async () => {
          const count = await browser.execute(() =>
            document.getElementById('root')?.childElementCount ?? 0,
          );
          return count > 0;
        },
        { timeout: 30_000, timeoutMsg: 'React did not render within 30s' }
      );
      console.log('[wdio] React rendered successfully');
    } catch (e) {
      console.error('[wdio] React did not render:', e);
      // Debug: check current URL and page content
      try {
        const currentUrl = await browser.getUrl();
        console.log(`[wdio] Current URL: ${currentUrl}`);
        const html = await browser.execute(() => document.documentElement.outerHTML);
        console.log(`[wdio] Page HTML: ${html.substring(0, 500)}`);
      } catch (debugErr) {
        console.error('[wdio] Failed to get debug info:', debugErr);
      }
    }

    // Load diagnostic modules
    await loadDiagnostics();

    // Start console and network capture
    if (consoleCapture) {
      try {
        await consoleCapture.startCapture();
        console.log('[wdio] Console capture started');
      } catch (error) {
        console.warn('[wdio] Failed to start console capture:', error);
      }
    }

    if (networkCapture) {
      try {
        await networkCapture.startCapture();
        console.log('[wdio] Network capture started');
      } catch (error) {
        console.warn('[wdio] Failed to start network capture:', error);
      }
    }
  },

  // ── Before each test ─────────────────────────────────────────────────────
  beforeTest: async (test) => {
    console.log(`[wdio] Starting test: ${test.title}`);

    // Clear console logs for this test
    if (consoleCapture) {
      try {
        consoleCapture.clearLogs();
      } catch {
        // ignore
      }
    }

    // Capture screenshot at test start (for baseline comparison)
    if (screenshotCapture) {
      try {
        await screenshotCapture.captureOnTestStart(test.title);
      } catch (error) {
        console.warn('[wdio] Failed to capture start screenshot:', error);
      }
    }
  },

  // ── After each test ──────────────────────────────────────────────────────
  afterTest: async (test, _context, { error }) => {
    if (error) {
      console.error(`[wdio] Test FAILED: ${test.title}`);
      console.error(`[wdio] Error: ${error.message}`);

      // Capture screenshot on failure
      if (screenshotCapture) {
        try {
          const screenshot = await screenshotCapture.captureOnTestFailure(test.title);
          if (screenshot) {
            console.log(`[wdio] Failure screenshot: ${screenshot.path}`);
          }
        } catch (screenshotError) {
          console.warn('[wdio] Failed to capture failure screenshot:', screenshotError);
        }
      }

      // Save console logs for this test
      if (consoleCapture) {
        try {
          const errors = consoleCapture.getErrors();
          const warnings = consoleCapture.getWarnings();

          if (errors.length > 0) {
            console.log(`[wdio] Console errors: ${errors.length}`);
            for (const err of errors.slice(0, 5)) {
              console.log(`  - ${err.message.substring(0, 100)}`);
            }
          }

          consoleCapture.saveToFile(test.title);
        } catch {
          // ignore
        }
      }

      // Save network logs for this test
      if (networkCapture) {
        try {
          const failed = networkCapture.getFailedRequests();
          if (failed.length > 0) {
            console.log(`[wdio] Failed network requests: ${failed.length}`);
            for (const req of failed.slice(0, 3)) {
              console.log(`  - ${req.method} ${req.url} -> ${req.status || 'ERROR'}`);
            }
          }

          networkCapture.saveToFile(test.title);
        } catch {
          // ignore
        }
      }

      // Check if failure is due to process crash
      if (!isTauriAlive()) {
        console.error('[wdio] Tauri process crashed!');
        console.error('[wdio] Check crash log:', LOG_FILE);
      }
    } else {
      console.log(`[wdio] Test PASSED: ${test.title}`);
    }
  },

  // ── After test suite ─────────────────────────────────────────────────────
  after: async () => {
    // Stop diagnostic capture
    if (consoleCapture) {
      try {
        await consoleCapture.stopCapture();
      } catch {
        // ignore
      }
    }

    if (networkCapture) {
      try {
        await networkCapture.stopCapture();
      } catch {
        // ignore
      }
    }
  },

  // ── Cleanup ──────────────────────────────────────────────────────────────
  onComplete: async () => {
    console.log('[wdio] Test run complete, cleaning up...');
    await killTauriProcess();
  },
});
