/**
 * Tauri WebDriver Teardown
 *
 * Kills the Tauri process that was started by tauri-setup.ts.
 * Call this from the wdio.conf.ts `onComplete` hook.
 *
 * Uses graceful shutdown: SIGTERM → wait 5s → SIGKILL
 */

import { existsSync, readFileSync, unlinkSync } from 'fs';
import { execSync } from 'child_process';
import { join } from 'path';

const PID_FILE = join(process.cwd(), '.tauri-webdriver.pid');
const SHUTDOWN_TIMEOUT_MS = 5000;

/**
 * Check if a process is still running
 */
function isProcessAlive(pid: number): boolean {
  try {
    // Sending signal 0 checks if process exists without actually sending a signal
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

/**
 * Wait for a process to exit
 */
async function waitForExit(pid: number, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isProcessAlive(pid)) {
      return true;
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  return false;
}

/**
 * Kill any remaining haipee processes (safety net)
 */
function forceKillAll(): void {
  try {
    execSync('pkill -9 -f "haipee" 2>/dev/null || true', { timeout: 5000 });
  } catch {
    // ignore
  }
}

export async function killTauriProcess(): Promise<void> {
  if (!existsSync(PID_FILE)) {
    console.log('[tauri-teardown] No PID file found, nothing to kill.');
    // Safety net: kill any orphaned haipee processes
    forceKillAll();
    return;
  }

  let pid: number | null = null;

  try {
    const raw = readFileSync(PID_FILE, 'utf-8').trim();
    pid = parseInt(raw, 10);
  } catch (err) {
    console.warn('[tauri-teardown] Could not read PID file:', err);
  }

  if (pid && !isNaN(pid)) {
    if (isProcessAlive(pid)) {
      console.log(`[tauri-teardown] Sending SIGTERM to Tauri process (PID ${pid})...`);
      try {
        process.kill(pid, 'SIGTERM');
      } catch (err) {
        console.warn('[tauri-teardown] SIGTERM failed:', err);
      }

      // Wait for graceful shutdown
      const exited = await waitForExit(pid, SHUTDOWN_TIMEOUT_MS);

      if (exited) {
        console.log(`[tauri-teardown] Process ${pid} exited gracefully.`);
      } else {
        console.log(`[tauri-teardown] Process ${pid} did not exit, sending SIGKILL...`);
        try {
          process.kill(pid, 'SIGKILL');
        } catch (err) {
          console.warn('[tauri-teardown] SIGKILL failed:', err);
        }
      }
    } else {
      console.log(`[tauri-teardown] Process ${pid} already exited.`);
    }
  }

  // Clean up PID file
  try {
    unlinkSync(PID_FILE);
  } catch {
    // ignore
  }

  // Safety net: kill any orphaned haipee processes
  forceKillAll();
  console.log('[tauri-teardown] Cleanup complete.');
}

export default killTauriProcess;
