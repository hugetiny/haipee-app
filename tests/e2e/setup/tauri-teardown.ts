/**
 * Tauri WebDriver Teardown
 *
 * Kills the Tauri process that was started by tauri-setup.ts.
 * Call this from the wdio.conf.ts `onComplete` hook.
 */

import { existsSync, readFileSync, unlinkSync } from 'fs';
import { join } from 'path';

const PID_FILE = join(process.cwd(), '.tauri-webdriver.pid');

export function killTauriProcess(): void {
  if (!existsSync(PID_FILE)) {
    console.log('[tauri-teardown] No PID file found, nothing to kill.');
    return;
  }

  try {
    const raw = readFileSync(PID_FILE, 'utf-8').trim();
    const pid = parseInt(raw, 10);
    if (!isNaN(pid)) {
      process.kill(pid, 'SIGTERM');
      console.log(`[tauri-teardown] Sent SIGTERM to Tauri process (PID ${pid}).`);
    }
  } catch (err) {
    // Process may have already exited
    console.warn('[tauri-teardown] Could not kill Tauri process:', err instanceof Error ? err.message : err);
  }

  try {
    unlinkSync(PID_FILE);
  } catch {
    // ignore
  }
}

export default killTauriProcess;
