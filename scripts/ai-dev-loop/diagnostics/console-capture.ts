/**
 * Console Log Capture Module
 *
 * Captures browser console logs during E2E test execution using WebdriverIO.
 * Captures errors, warnings, and other relevant console output.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { ConsoleEntry } from '../types.ts';
import { log } from '../logger.ts';

const CONSOLE_LOG_DIR = './ai-loop-logs/console';

if (!fs.existsSync(CONSOLE_LOG_DIR)) {
  fs.mkdirSync(CONSOLE_LOG_DIR, { recursive: true });
}

export interface ConsoleCapture {
  startCapture(sessionId?: string): Promise<void>;
  stopCapture(): Promise<void>;
  getCapturedLogs(): ConsoleEntry[];
  getErrors(): ConsoleEntry[];
  getWarnings(): ConsoleEntry[];
  clearLogs(): void;
  saveToFile(testName: string): string | null;
  detectReactErrors(): ConsoleEntry[];
  detectUnhandledRejections(): ConsoleEntry[];
}

class ConsoleCaptureImpl implements ConsoleCapture {
  private logs: ConsoleEntry[] = [];
  private isCapturing = false;
  private webdriverBaseUrl = 'http://127.0.0.1:4444';
  private captureInterval: ReturnType<typeof setInterval> | null = null;
  private sessionId: string | null = null;

  /**
   * Start capturing console logs
   */
  async startCapture(sessionId?: string): Promise<void> {
    if (this.isCapturing) {
      log('debug', 'Console capture already active');
      return;
    }

    this.sessionId = sessionId || await this.getCurrentSessionId();
    if (!this.sessionId) {
      log('warn', 'No WebDriver session for console capture');
      return;
    }

    this.isCapturing = true;
    this.logs = [];

    // Start polling for console logs
    this.captureInterval = setInterval(async () => {
      await this.pollConsoleLogs();
    }, 1000);  // Poll every second

    log('debug', 'Console capture started');
  }

  /**
   * Stop capturing console logs
   */
  async stopCapture(): Promise<void> {
    if (this.captureInterval) {
      clearInterval(this.captureInterval);
      this.captureInterval = null;
    }

    // Final poll to get remaining logs
    await this.pollConsoleLogs();

    this.isCapturing = false;
    log('debug', `Console capture stopped. Captured ${this.logs.length} entries`);
  }

  /**
   * Get all captured console logs
   */
  getCapturedLogs(): ConsoleEntry[] {
    return [...this.logs];
  }

  /**
   * Get only error-level console logs
   */
  getErrors(): ConsoleEntry[] {
    return this.logs.filter(entry => entry.level === 'error');
  }

  /**
   * Get only warning-level console logs
   */
  getWarnings(): ConsoleEntry[] {
    return this.logs.filter(entry => entry.level === 'warn');
  }

  /**
   * Clear captured logs
   */
  clearLogs(): void {
    this.logs = [];
  }

  /**
   * Save captured logs to a file
   */
  saveToFile(testName: string): string | null {
    if (this.logs.length === 0) {
      return null;
    }

    const sanitizedName = testName
      .replace(/[^a-zA-Z0-9-_\s]/g, '')
      .replace(/\s+/g, '-')
      .toLowerCase()
      .substring(0, 100);

    const filename = `${sanitizedName}-${Date.now()}.log`;
    const filepath = path.join(CONSOLE_LOG_DIR, filename);

    const content = this.logs
      .map(entry => {
        const timestamp = new Date(entry.timestamp).toISOString();
        let line = `[${timestamp}] [${entry.level.toUpperCase()}] ${entry.message}`;
        if (entry.source) line += ` (${entry.source})`;
        if (entry.stackTrace) line += `\n${entry.stackTrace}`;
        return line;
      })
      .join('\n\n');

    fs.writeFileSync(filepath, content, 'utf-8');
    log('debug', `Console logs saved: ${filename}`);

    return filepath;
  }

  /**
   * Detect React-specific errors
   */
  detectReactErrors(): ConsoleEntry[] {
    return this.logs.filter(entry => {
      const msg = entry.message.toLowerCase();
      return (
        msg.includes('react') ||
        msg.includes('uncaught error') ||
        msg.includes('error boundary') ||
        msg.includes('component stack') ||
        msg.includes('the above error occurred') ||
        msg.includes('warning: ')
      );
    });
  }

  /**
   * Detect unhandled promise rejections
   */
  detectUnhandledRejections(): ConsoleEntry[] {
    return this.logs.filter(entry => {
      const msg = entry.message.toLowerCase();
      return (
        msg.includes('unhandled promise rejection') ||
        msg.includes('uncaught (in promise)') ||
        msg.includes('promise rejection')
      );
    });
  }

  /**
   * Poll for console logs via WebDriver
   */
  private async pollConsoleLogs(): Promise<void> {
    if (!this.sessionId) return;

    try {
      const url = `${this.webdriverBaseUrl}/session/${this.sessionId}/log`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type: 'browser' }),
      });

      if (!response.ok) {
        // Log type might not be supported, try alternative approach
        return;
      }

      const data = await response.json() as {
        value: Array<{
          level: string;
          message: string;
          timestamp: number;
          source?: string;
        }>
      };

      if (data.value && Array.isArray(data.value)) {
        for (const entry of data.value) {
          // Avoid duplicates
          const isDuplicate = this.logs.some(
            existing =>
              existing.message === entry.message &&
              Math.abs(existing.timestamp - entry.timestamp) < 100
          );

          if (!isDuplicate) {
            this.logs.push({
              level: this.mapLogLevel(entry.level),
              message: entry.message,
              timestamp: entry.timestamp || Date.now(),
              source: entry.source,
            });
          }
        }
      }
    } catch (error) {
      // Silently ignore - console log API might not be available
    }
  }

  /**
   * Map WebDriver log level to our ConsoleEntry level
   */
  private mapLogLevel(level: string): ConsoleEntry['level'] {
    const normalized = level.toLowerCase();
    switch (normalized) {
      case 'severe':
      case 'error':
        return 'error';
      case 'warning':
      case 'warn':
        return 'warn';
      case 'info':
        return 'info';
      case 'debug':
        return 'debug';
      default:
        return 'log';
    }
  }

  /**
   * Get current WebDriver session ID
   */
  private async getCurrentSessionId(): Promise<string | null> {
    try {
      const response = await fetch(`${this.webdriverBaseUrl}/status`);
      if (!response.ok) return null;

      const data = await response.json() as {
        value?: { sessions?: Array<{ id: string }> }
      };

      const sessions = data.value?.sessions;
      if (sessions && sessions.length > 0) {
        return sessions[0].id;
      }

      return null;
    } catch (error) {
      return null;
    }
  }
}

// Singleton instance
let captureInstance: ConsoleCapture | null = null;

export function getConsoleCapture(): ConsoleCapture {
  if (!captureInstance) {
    captureInstance = new ConsoleCaptureImpl();
  }
  return captureInstance;
}

/**
 * Helper: Capture console logs for a test and return structured data
 */
export async function captureTestConsole(
  testName: string,
  testFn: () => Promise<void>
): Promise<ConsoleEntry[]> {
  const capture = getConsoleCapture();

  await capture.startCapture();
  try {
    await testFn();
  } finally {
    await capture.stopCapture();
  }

  const logs = capture.getCapturedLogs();

  // Save if there are errors or warnings
  if (capture.getErrors().length > 0 || capture.getWarnings().length > 0) {
    capture.saveToFile(testName);
  }

  return logs;
}

/**
 * Helper: Format console logs for inclusion in fix prompts
 */
export function formatConsoleLogsForPrompt(logs: ConsoleEntry[]): string {
  if (logs.length === 0) {
    return 'No console errors or warnings captured.';
  }

  const errors = logs.filter(l => l.level === 'error');
  const warnings = logs.filter(l => l.level === 'warn');

  let output = '';

  if (errors.length > 0) {
    output += '### Console Errors\n';
    for (const error of errors.slice(0, 10)) {  // Limit to 10 errors
      output += `- ${error.message}\n`;
      if (error.stackTrace) {
        output += `  Stack: ${error.stackTrace.split('\n').slice(0, 3).join('\n  ')}\n`;
      }
    }
    if (errors.length > 10) {
      output += `... and ${errors.length - 10} more errors\n`;
    }
    output += '\n';
  }

  if (warnings.length > 0) {
    output += '### Console Warnings\n';
    for (const warning of warnings.slice(0, 5)) {  // Limit to 5 warnings
      output += `- ${warning.message}\n`;
    }
    if (warnings.length > 5) {
      output += `... and ${warnings.length - 5} more warnings\n`;
    }
  }

  return output;
}
