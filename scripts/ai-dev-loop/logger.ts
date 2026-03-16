/**
 * AI Development Loop - Logger
 */

import * as fs from 'fs';
import * as path from 'path';

const LOG_DIR = './ai-loop-logs/logs';

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

let currentLogFile: string | null = null;

export function initLogger(runId: string): void {
  currentLogFile = path.join(LOG_DIR, `run-${runId}.log`);
  log('info', `Logger initialized for run: ${runId}`);
}

export function log(level: 'debug' | 'info' | 'warn' | 'error', message: string, meta?: Record<string, unknown>): void {
  const timestamp = new Date().toISOString();
  const metaStr = meta ? ' ' + JSON.stringify(meta) : '';
  const line = `[${timestamp}] [${level.toUpperCase()}] ${message}${metaStr}\n`;

  const colors: Record<string, string> = {
    debug: '\x1b[36m',
    info: '\x1b[32m',
    warn: '\x1b[33m',
    error: '\x1b[31m',
    reset: '\x1b[0m',
  };

  console.log(`${colors[level]}${line.trim()}${colors.reset}`);

  if (currentLogFile) {
    fs.appendFileSync(currentLogFile, line);
  }
}

export function logSection(title: string): void {
  const line = '\n' + '='.repeat(60) + '\n' + `  ${title}\n` + '='.repeat(60) + '\n';
  console.log('\x1b[1m\x1b[34m' + line + '\x1b[0m');
  if (currentLogFile) {
    fs.appendFileSync(currentLogFile, line);
  }
}

export function logProgress(iteration: number, totalTests: number, passed: number, failed: number): void {
  const rate = totalTests > 0 ? ((passed / totalTests) * 100).toFixed(1) : '0.0';
  const line = `\n📊 Progress: Iteration ${iteration} | Tests: ${totalTests} | Pass: ${passed} | Fail: ${failed} | Rate: ${rate}%\n`;
  console.log('\x1b[1m' + line + '\x1b[0m');
  if (currentLogFile) {
    fs.appendFileSync(currentLogFile, line);
  }
}

export function logAlert(message: string): void {
  const line = `\n🚨 ALERT: ${message}\n`;
  console.log('\x1b[1m\x1b[41m\x1b[37m' + line + '\x1b[0m');
  if (currentLogFile) {
    fs.appendFileSync(currentLogFile, '[ALERT] ' + line);
  }
}

export function logCheckpointSaved(path: string): void {
  log('info', `💾 Checkpoint saved: ${path}`);
}

export function logFixAttempt(testName: string, attempt: number, maxAttempts: number): void {
  log('info', `🔧 Fixing ${testName} (attempt ${attempt}/${maxAttempts})`);
}

export function logFixSuccess(testName: string, description?: string): void {
  log('info', `✅ Fixed: ${testName}`, { description });
}

export function logFixFailed(testName: string, error: string): void {
  log('error', `❌ Fix failed: ${testName}`, { error });
}
