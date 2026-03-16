/**
 * Tauri WebDriver Setup
 *
 * Builds the Tauri binary with the `webdriver` feature flag and launches it so
 * WebdriverIO can connect on the default port (4444).
 *
 * Prerequisites on macOS:
 *   safaridriver must be enabled: `sudo safaridriver --enable`
 *
 * Usage: referenced by wdio.conf.ts → onPrepare hook.
 */

import { execSync, spawn, type ChildProcess } from 'child_process';
import { existsSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';

const ROOT = process.cwd();
const BINARY_PATH = join(ROOT, 'src-tauri/target/debug/haipee');
const PID_FILE = join(ROOT, '.tauri-webdriver.pid');
const MANIFEST = join(ROOT, 'src-tauri/Cargo.toml');
const WEBDRIVER_PORT = 4444;

/** Returns true when Rust sources are newer than the debug binary. */
function needsRebuild(): boolean {
  if (!existsSync(BINARY_PATH)) return true;

  const srcDir = join(ROOT, 'src-tauri/src');
  try {
    const newer = execSync(
      `find "${srcDir}" -name "*.rs" -newer "${BINARY_PATH}" | head -1`,
      { encoding: 'utf-8' },
    ).trim();
    return newer.length > 0;
  } catch {
    return true;
  }
}

/** Polls the WebDriver /status endpoint until the server responds or timeout. */
async function waitForWebDriver(port: number, timeoutMs = 30_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/status`);
      if (res.ok) return;
    } catch {
      // not ready yet
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Tauri WebDriver not ready on port ${port} after ${timeoutMs}ms`);
}

/**
 * Builds (if needed) and launches the Tauri binary with the webdriver feature.
 * Call this from the wdio.conf.ts `onPrepare` hook.
 */
export async function launchTauriForWebDriver(): Promise<void> {
  if (needsRebuild()) {
    console.log('[tauri-setup] Building with --features webdriver (this may take a few minutes)…');
    execSync(`cargo build --manifest-path "${MANIFEST}" --features webdriver`, {
      stdio: 'inherit',
      timeout: 300_000,
      cwd: ROOT,
    });
    console.log('[tauri-setup] Build complete.');
  } else {
    console.log('[tauri-setup] Binary is up-to-date, skipping build.');
  }

  console.log(`[tauri-setup] Launching ${BINARY_PATH}…`);
  const proc: ChildProcess = spawn(BINARY_PATH, [], {
    detached: true,
    stdio: 'ignore',
    env: {
      ...process.env,
      // Allow WKWebView file-access in tests
      WEBKIT_WEBVIEW_ALLOW_FILE_ACCESS_FROM_FILE_URLS: '1',
    },
  });

  proc.unref();

  const pid = proc.pid;
  if (!pid) throw new Error('[tauri-setup] Failed to get PID for launched Tauri process');

  // Persist PID so teardown can kill it
  mkdirSync(dirname(PID_FILE), { recursive: true });
  writeFileSync(PID_FILE, String(pid), 'utf-8');
  console.log(`[tauri-setup] Tauri launched (PID ${pid}), waiting for WebDriver on :${WEBDRIVER_PORT}…`);

  await waitForWebDriver(WEBDRIVER_PORT);
  console.log(`[tauri-setup] WebDriver ready on port ${WEBDRIVER_PORT}.`);
}

export { BINARY_PATH, PID_FILE, WEBDRIVER_PORT };
