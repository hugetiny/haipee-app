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
import { existsSync, writeFileSync, mkdirSync, appendFileSync } from 'fs';
import { join, dirname } from 'path';

const ROOT = process.cwd();
const BINARY_PATH = join(ROOT, 'src-tauri/target/debug/haipee');
const PID_FILE = join(ROOT, '.tauri-webdriver.pid');
const LOG_FILE = join(ROOT, 'wdio-logs/tauri-binary.log');
const MANIFEST = join(ROOT, 'src-tauri/Cargo.toml');
const WEBDRIVER_PORT = 4444;

// Track the spawned process for health checks and teardown
let tauriProcess: ChildProcess | null = null;

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
async function waitForWebDriver(port: number, timeoutMs = 60_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let lastError: Error | null = null;

  while (Date.now() < deadline) {
    // Check if process is still alive
    if (tauriProcess && tauriProcess.exitCode !== null) {
      throw new Error(`Tauri process exited with code ${tauriProcess.exitCode} during startup`);
    }

    try {
      const res = await fetch(`http://127.0.0.1:${port}/status`);
      if (res.ok) return;
    } catch (e) {
      lastError = e as Error;
    }
    await new Promise((r) => setTimeout(r, 500));
  }

  const exitInfo = tauriProcess?.exitCode !== null
    ? ` (process exited with code ${tauriProcess?.exitCode})`
    : ' (process still running)';

  throw new Error(
    `Tauri WebDriver not ready on port ${port} after ${timeoutMs}ms${exitInfo}. ` +
    `Last error: ${lastError?.message ?? 'unknown'}`
  );
}

/**
 * Check if the Tauri process is still alive
 */
export function isTauriAlive(): boolean {
  if (!tauriProcess) return false;
  return tauriProcess.exitCode === null && tauriProcess.signalCode === null;
}

/**
 * Health check - verifies WebDriver endpoint is responsive
 */
export async function healthCheck(): Promise<boolean> {
  if (!isTauriAlive()) return false;

  try {
    const res = await fetch(`http://127.0.0.1:${WEBDRIVER_PORT}/status`);
    return res.ok;
  } catch {
    return false;
  }
}

/**
 * Builds (if needed) and launches the Tauri binary with the webdriver feature.
 * Call this from the wdio.conf.ts `onPrepare` hook.
 */
export async function launchTauriForWebDriver(): Promise<void> {
  // Ensure log directory exists
  mkdirSync(dirname(LOG_FILE), { recursive: true });

  if (needsRebuild()) {
    console.log('[tauri-setup] Building with --features webdriver (this may take a few minutes)...');
    execSync(`cargo build --manifest-path "${MANIFEST}" --features webdriver`, {
      stdio: 'inherit',
      timeout: 300_000,
      cwd: ROOT,
    });
    console.log('[tauri-setup] Build complete.');
  } else {
    console.log('[tauri-setup] Binary is up-to-date, skipping build.');
  }

  console.log(`[tauri-setup] Launching ${BINARY_PATH}...`);

  // Clear previous log
  writeFileSync(LOG_FILE, `[${new Date().toISOString()}] Starting Tauri binary\n`);

  tauriProcess = spawn(BINARY_PATH, [], {
    // Do NOT detach - we need to monitor the process
    detached: false,
    // Capture stdout/stderr for debugging
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...process.env,
      // Enable E2E test mode (skips interactive dialogs)
      HAIPEE_E2E_MODE: '1',
      // Allow WKWebView file-access in tests
      WEBKIT_WEBVIEW_ALLOW_FILE_ACCESS_FROM_FILE_URLS: '1',
      // Enable debug logging
      RUST_LOG: 'debug',
    },
  });

  const pid = tauriProcess.pid;
  if (!pid) throw new Error('[tauri-setup] Failed to get PID for launched Tauri process');

  // Capture stdout/stderr to log file
  tauriProcess.stdout?.on('data', (data) => {
    appendFileSync(LOG_FILE, data);
  });

  tauriProcess.stderr?.on('data', (data) => {
    appendFileSync(LOG_FILE, `[STDERR] ${data}`);
  });

  // Handle process exit
  tauriProcess.on('exit', (code, signal) => {
    const msg = `[${new Date().toISOString()}] Tauri process exited: code=${code}, signal=${signal}\n`;
    appendFileSync(LOG_FILE, msg);
    console.error(`[tauri-setup] Tauri process exited unexpectedly: code=${code}, signal=${signal}`);
  });

  // Persist PID so teardown can kill it
  mkdirSync(dirname(PID_FILE), { recursive: true });
  writeFileSync(PID_FILE, String(pid), 'utf-8');
  console.log(`[tauri-setup] Tauri launched (PID ${pid}), waiting for WebDriver on :${WEBDRIVER_PORT}...`);

  await waitForWebDriver(WEBDRIVER_PORT);
  console.log(`[tauri-setup] WebDriver ready on port ${WEBDRIVER_PORT}.`);
  console.log(`[tauri-setup] Binary logs: ${LOG_FILE}`);
}

export { BINARY_PATH, PID_FILE, WEBDRIVER_PORT, LOG_FILE };
