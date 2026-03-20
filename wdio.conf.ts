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

  specs: ['./tests/e2e/tauri/**/*.spec.ts', './tests/e2e-tauri/**/*.spec.ts'],
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
