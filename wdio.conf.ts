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
import { launchTauriForWebDriver } from './tests/e2e/setup/tauri-setup.js';
import { killTauriProcess } from './tests/e2e/setup/tauri-teardown.js';

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
      // Fallback: omit browserName if the server rejects 'wry'.
      browserName: 'wry',
    },
  ],

  // ── Logging ──────────────────────────────────────────────────────────────
  logLevel: 'warn',

  // ── Retry & timeouts ─────────────────────────────────────────────────────
  bail: 0,
  waitforTimeout: 10_000,
  connectionRetryTimeout: 120_000,
  connectionRetryCount: 3,

  // ── Framework ────────────────────────────────────────────────────────────
  framework: 'mocha',
  reporters: ['spec'],
  mochaOpts: {
    ui: 'bdd',
    timeout: 60_000,
  },

  // ── Process lifecycle ────────────────────────────────────────────────────
  onPrepare: async () => {
    await launchTauriForWebDriver();
  },

  onComplete: () => {
    killTauriProcess();
  },
});
