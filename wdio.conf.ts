/**
 * WebdriverIO Configuration – Tauri WebView E2E
 *
 * Connects to the tauri-plugin-webdriver endpoint (default port 4444) that is
 * started when the Tauri binary is built with `--features webdriver`.
 *
 * Platform note (macOS):
 *   Tauri uses WKWebView (WebKit). tauri-plugin-webdriver proxies commands via
 *   Safari's remote debugging protocol. SafariDriver must be enabled:
 *     sudo safaridriver --enable
 *
 * The `onPrepare` hook builds the binary if out-of-date and launches it.
 * The `onComplete` hook kills the process.
 */

import { defineConfig } from '@wdio/config';
import { launchTauriForWebDriver, healthCheck, isTauriAlive, LOG_FILE } from './tests/e2e/setup/tauri-setup.js';
import { killTauriProcess } from './tests/e2e/setup/tauri-teardown.js';
import { readFileSync } from 'fs';

export const config = defineConfig({
  runner: 'local',

  specs: ['./tests/e2e/tauri/**/*.spec.ts'],
  exclude: [],
  maxInstances: 1, // Only one Tauri window at a time

  // ── Connect to tauri-plugin-webdriver endpoint ───────────────────────────
  hostname: '127.0.0.1',
  port: 4444,
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
    await launchTauriForWebDriver();
  },

  // ── Health checks between specs ──────────────────────────────────────────
  before: async () => {
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
  },

  // After each test - check if Tauri is still alive
  afterTest: async (test, _context, { error }) => {
    if (error) {
      // Check if failure is due to process crash
      if (!isTauriAlive()) {
        console.error(`[wdio] Test "${test.title}" failed - Tauri process crashed!`);
        console.error('[wdio] Check crash log:', LOG_FILE);
      }
    }
  },

  onComplete: async () => {
    await killTauriProcess();
  },
});
