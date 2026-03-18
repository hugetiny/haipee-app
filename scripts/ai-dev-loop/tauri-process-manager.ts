/**
 * Tauri Process Manager for AI Dev Loop
 *
 * Manages the Tauri binary lifecycle during autonomous testing:
 * - Start/stop/restart the binary
 * - Health monitoring
 * - Crash detection and recovery
 * - Log collection
 */

import { spawn, execSync, type ChildProcess } from 'child_process';
import { existsSync, readFileSync, writeFileSync, appendFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import { log } from './logger.ts';

const ROOT = process.cwd();
const BINARY_PATH = join(ROOT, 'src-tauri/target/debug/haipee');
const PID_FILE = join(ROOT, '.tauri-webdriver.pid');
const LOG_DIR = join(ROOT, 'ai-loop-logs');
const BINARY_LOG = join(LOG_DIR, 'tauri-binary.log');
const WEBDRIVER_PORT = 4444;
const MAX_RESTARTS = 3;
const HEALTH_CHECK_INTERVAL_MS = 10_000;

export interface ProcessStats {
  startCount: number;
  crashCount: number;
  lastStartTime: number;
  lastCrashTime: number | null;
  totalUptime: number;
}

export class TauriProcessManager {
  private process: ChildProcess | null = null;
  private stats: ProcessStats = {
    startCount: 0,
    crashCount: 0,
    lastStartTime: 0,
    lastCrashTime: null,
    totalUptime: 0,
  };
  private healthCheckTimer: ReturnType<typeof setInterval> | null = null;
  private restartCount = 0;

  constructor() {
    mkdirSync(LOG_DIR, { recursive: true });
  }

  /**
   * Check if binary needs rebuilding
   */
  private needsRebuild(): boolean {
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

  /**
   * Build the Tauri binary with webdriver feature
   */
  private async build(): Promise<void> {
    log('info', 'Building Tauri binary with webdriver feature...');
    try {
      execSync(
        'cargo build --manifest-path src-tauri/Cargo.toml --features webdriver',
        {
          stdio: 'inherit',
          timeout: 300_000,
          cwd: ROOT,
        }
      );
      log('info', 'Build complete.');
    } catch (err) {
      log('error', 'Build failed', { error: String(err) });
      throw err;
    }
  }

  /**
   * Wait for WebDriver to be ready
   */
  private async waitForWebDriver(timeoutMs = 60_000): Promise<boolean> {
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      if (this.process?.exitCode !== null) {
        return false; // Process died
      }

      try {
        const res = await fetch(`http://127.0.0.1:${WEBDRIVER_PORT}/status`);
        if (res.ok) return true;
      } catch {
        // not ready yet
      }
      await new Promise((r) => setTimeout(r, 500));
    }

    return false;
  }

  /**
   * Start the Tauri binary
   */
  async start(): Promise<boolean> {
    // Build if needed
    if (this.needsRebuild()) {
      await this.build();
    }

    log('info', `Starting Tauri binary (attempt ${this.stats.startCount + 1})...`);

    // Clear previous log and start fresh
    writeFileSync(BINARY_LOG, `[${new Date().toISOString()}] Starting Tauri binary\n`);

    this.process = spawn(BINARY_PATH, [], {
      detached: false,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: {
        ...process.env,
        HAIPEE_E2E_MODE: '1',
        WEBKIT_WEBVIEW_ALLOW_FILE_ACCESS_FROM_FILE_URLS: '1',
        RUST_LOG: 'debug',
      },
    });

    const pid = this.process.pid;
    if (!pid) {
      log('error', 'Failed to get PID');
      return false;
    }

    // Write PID file
    writeFileSync(PID_FILE, String(pid), 'utf-8');

    // Capture logs
    this.process.stdout?.on('data', (data: Buffer) => {
      appendFileSync(BINARY_LOG, data);
    });

    this.process.stderr?.on('data', (data: Buffer) => {
      appendFileSync(BINARY_LOG, `[STDERR] ${data}`);
    });

    // Handle process exit
    this.process.on('exit', (code, signal) => {
      const msg = `Process exited: code=${code}, signal=${signal}`;
      log('warn', msg);
      appendFileSync(BINARY_LOG, `[${new Date().toISOString()}] ${msg}\n`);

      this.stats.crashCount++;
      this.stats.lastCrashTime = Date.now();

      if (this.process) {
        this.process = null;
      }
    });

    // Wait for WebDriver
    const ready = await this.waitForWebDriver();

    if (ready) {
      this.stats.startCount++;
      this.stats.lastStartTime = Date.now();
      this.restartCount = 0;
      log('info', `Tauri binary started (PID ${pid})`);

      // Start health monitoring
      this.startHealthMonitoring();
      return true;
    } else {
      log('error', 'Tauri binary failed to start');
      this.process = null;
      return false;
    }
  }

  /**
   * Stop the Tauri binary gracefully
   */
  async stop(): Promise<void> {
    this.stopHealthMonitoring();

    if (!this.process) {
      log('info', 'No process to stop');
      return;
    }

    const pid = this.process.pid;
    log('info', `Stopping Tauri binary (PID ${pid})...`);

    // Update uptime stats
    if (this.stats.lastStartTime > 0) {
      this.stats.totalUptime += Date.now() - this.stats.lastStartTime;
    }

    try {
      // SIGTERM first
      this.process.kill('SIGTERM');

      // Wait up to 5 seconds
      await new Promise((r) => setTimeout(r, 5000));

      // SIGKILL if still alive
      if (this.process && this.process.exitCode === null) {
        log('warn', 'Process did not exit, sending SIGKILL');
        this.process.kill('SIGKILL');
      }
    } catch (err) {
      log('error', 'Error stopping process', { error: String(err) });
    }

    this.process = null;

    // Clean up PID file
    try {
      if (existsSync(PID_FILE)) {
        require('fs').unlinkSync(PID_FILE);
      }
    } catch {
      // ignore
    }

    // Safety net: kill any orphaned processes
    try {
      execSync('pkill -9 -f "haipee" 2>/dev/null || true', { timeout: 5000 });
    } catch {
      // ignore
    }

    log('info', 'Tauri binary stopped');
  }

  /**
   * Restart the Tauri binary
   */
  async restart(): Promise<boolean> {
    this.restartCount++;

    if (this.restartCount > MAX_RESTARTS) {
      log('error', `Max restarts (${MAX_RESTARTS}) exceeded`);
      return false;
    }

    log('info', `Restarting Tauri binary (restart ${this.restartCount}/${MAX_RESTARTS})...`);

    await this.stop();
    await new Promise((r) => setTimeout(r, 2000)); // Brief pause
    return this.start();
  }

  /**
   * Check if process is alive
   */
  isAlive(): boolean {
    if (!this.process) return false;
    return this.process.exitCode === null && this.process.signalCode === null;
  }

  /**
   * Perform health check
   */
  async healthCheck(): Promise<boolean> {
    if (!this.isAlive()) return false;

    try {
      const res = await fetch(`http://127.0.0.1:${WEBDRIVER_PORT}/status`);
      return res.ok;
    } catch {
      return false;
    }
  }

  /**
   * Start periodic health monitoring
   */
  private startHealthMonitoring(): void {
    if (this.healthCheckTimer) return;

    this.healthCheckTimer = setInterval(async () => {
      const healthy = await this.healthCheck();
      if (!healthy && this.isAlive()) {
        log('warn', 'Health check failed but process still alive');
      }
    }, HEALTH_CHECK_INTERVAL_MS);
  }

  /**
   * Stop health monitoring
   */
  private stopHealthMonitoring(): void {
    if (this.healthCheckTimer) {
      clearInterval(this.healthCheckTimer);
      this.healthCheckTimer = null;
    }
  }

  /**
   * Get crash log from the binary
   */
  getCrashLog(): string | null {
    const crashLogPath = join(process.env.HOME || '', '.haipee/crash.log');
    if (existsSync(crashLogPath)) {
      return readFileSync(crashLogPath, 'utf-8');
    }
    return null;
  }

  /**
   * Get binary stdout/stderr log
   */
  getBinaryLog(): string {
    if (existsSync(BINARY_LOG)) {
      return readFileSync(BINARY_LOG, 'utf-8');
    }
    return '';
  }

  /**
   * Get process statistics
   */
  getStats(): ProcessStats {
    return { ...this.stats };
  }

  /**
   * Reset restart count (call after successful test iteration)
   */
  resetRestartCount(): void {
    this.restartCount = 0;
  }
}

// Singleton instance
let managerInstance: TauriProcessManager | null = null;

export function getProcessManager(): TauriProcessManager {
  if (!managerInstance) {
    managerInstance = new TauriProcessManager();
  }
  return managerInstance;
}
