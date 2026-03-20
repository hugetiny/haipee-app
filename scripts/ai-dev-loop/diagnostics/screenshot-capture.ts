/**
 * Screenshot Capture Module
 *
 * Captures screenshots during E2E test execution using tauri-plugin-webdriver.
 * Integrates with WebdriverIO to capture visual state at critical moments.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { ScreenshotData } from '../types.ts';
import { log } from '../logger.ts';

const SCREENSHOT_DIR = './ai-loop-logs/screenshots';

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

export interface ScreenshotCapture {
  captureOnTestStart(testName: string, sessionId?: string): Promise<ScreenshotData | null>;
  captureOnTestFailure(testName: string, sessionId?: string): Promise<ScreenshotData | null>;
  captureElement(selector: string, name: string, sessionId?: string): Promise<ScreenshotData | null>;
  compareScreenshots(baseline: string, current: string): Promise<number>;
  cleanupOldScreenshots(maxAge?: number): void;
}

class ScreenshotCaptureImpl implements ScreenshotCapture {
  private webdriverBaseUrl = 'http://127.0.0.1:4444';

  /**
   * Capture screenshot when a test starts
   */
  async captureOnTestStart(testName: string, sessionId?: string): Promise<ScreenshotData | null> {
    const sanitizedName = this.sanitizeTestName(testName);
    const filename = `${sanitizedName}-start-${Date.now()}.png`;
    const filepath = path.join(SCREENSHOT_DIR, filename);

    try {
      const screenshotBase64 = await this.captureScreenshot(sessionId);
      if (!screenshotBase64) {
        log('warn', `Failed to capture start screenshot for: ${testName}`);
        return null;
      }

      fs.writeFileSync(filepath, screenshotBase64, 'base64');
      log('debug', `📸 Start screenshot: ${filename}`);

      return {
        testName,
        path: filepath,
        timestamp: Date.now(),
      };
    } catch (error) {
      log('error', `Screenshot capture failed for ${testName}`, {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Capture screenshot when a test fails
   */
  async captureOnTestFailure(testName: string, sessionId?: string): Promise<ScreenshotData | null> {
    const sanitizedName = this.sanitizeTestName(testName);
    const filename = `${sanitizedName}-failure-${Date.now()}.png`;
    const filepath = path.join(SCREENSHOT_DIR, filename);

    try {
      const screenshotBase64 = await this.captureScreenshot(sessionId);
      if (!screenshotBase64) {
        log('warn', `Failed to capture failure screenshot for: ${testName}`);
        return null;
      }

      fs.writeFileSync(filepath, screenshotBase64, 'base64');
      log('info', `📸 Failure screenshot captured: ${filename}`);

      // Try to find baseline and compare
      const baselinePath = this.findBaseline(testName);
      let diffScore: number | undefined;

      if (baselinePath && fs.existsSync(baselinePath)) {
        diffScore = await this.compareScreenshots(baselinePath, filepath);
        log('info', `Screenshot diff score: ${(diffScore * 100).toFixed(1)}%`);
      }

      return {
        testName,
        path: filepath,
        timestamp: Date.now(),
        baseline: baselinePath ?? undefined,
        diffScore,
      };
    } catch (error) {
      log('error', `Screenshot capture failed for ${testName}`, {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Capture screenshot of a specific element
   */
  async captureElement(selector: string, name: string, sessionId?: string): Promise<ScreenshotData | null> {
    const sanitizedName = this.sanitizeTestName(name);
    const filename = `${sanitizedName}-element-${Date.now()}.png`;
    const filepath = path.join(SCREENSHOT_DIR, filename);

    try {
      // Note: Element-specific screenshots would require the element ID from WebDriver
      // For now, capture full screenshot and note the element
      const screenshotBase64 = await this.captureScreenshot(sessionId);
      if (!screenshotBase64) {
        return null;
      }

      fs.writeFileSync(filepath, screenshotBase64, 'base64');
      log('debug', `📸 Element screenshot: ${filename} (selector: ${selector})`);

      return {
        testName: name,
        path: filepath,
        timestamp: Date.now(),
      };
    } catch (error) {
      log('error', `Element screenshot failed for ${name}`, {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Compare two screenshots and return difference score (0-1)
   */
  async compareScreenshots(baseline: string, current: string): Promise<number> {
    try {
      if (!fs.existsSync(baseline) || !fs.existsSync(current)) {
        return 1.0;  // Max difference if files don't exist
      }

      const baselineBuffer = fs.readFileSync(baseline);
      const currentBuffer = fs.readFileSync(current);

      // Simple byte-level comparison
      // For production, consider using a proper image diff library like pixelmatch
      if (baselineBuffer.length !== currentBuffer.length) {
        return 0.5;  // Different sizes = significant difference
      }

      // Calculate byte-level difference
      let diffBytes = 0;
      const sampleSize = Math.min(baselineBuffer.length, 10000);  // Sample for performance
      const step = Math.floor(baselineBuffer.length / sampleSize);

      for (let i = 0; i < baselineBuffer.length; i += step) {
        if (baselineBuffer[i] !== currentBuffer[i]) {
          diffBytes++;
        }
      }

      return diffBytes / sampleSize;
    } catch (error) {
      log('warn', 'Screenshot comparison failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return 0.5;  // Unknown difference
    }
  }

  /**
   * Clean up old screenshots
   */
  cleanupOldScreenshots(maxAge: number = 24 * 60 * 60 * 1000): void {
    try {
      const now = Date.now();
      const files = fs.readdirSync(SCREENSHOT_DIR);

      for (const file of files) {
        const filepath = path.join(SCREENSHOT_DIR, file);
        const stats = fs.statSync(filepath);

        if (now - stats.mtimeMs > maxAge) {
          fs.unlinkSync(filepath);
          log('debug', `Cleaned up old screenshot: ${file}`);
        }
      }
    } catch (error) {
      log('warn', 'Screenshot cleanup failed', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * Capture screenshot via WebDriver API
   */
  private async captureScreenshot(sessionId?: string): Promise<string | null> {
    try {
      // If no session ID provided, try to get the current session
      if (!sessionId) {
        sessionId = await this.getCurrentSessionId();
        if (!sessionId) {
          log('warn', 'No active WebDriver session found');
          return null;
        }
      }

      const url = `${this.webdriverBaseUrl}/session/${sessionId}/screenshot`;
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      });

      if (!response.ok) {
        log('warn', `Screenshot API returned ${response.status}`);
        return null;
      }

      const data = await response.json() as { value: string };
      return data.value || null;
    } catch (error) {
      log('error', 'WebDriver screenshot capture failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
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

      // Try to create a new session
      return await this.createSession();
    } catch (error) {
      return null;
    }
  }

  /**
   * Create a new WebDriver session
   */
  private async createSession(): Promise<string | null> {
    try {
      const response = await fetch(`${this.webdriverBaseUrl}/session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          capabilities: {
            alwaysMatch: { browserName: 'wry' },
          },
        }),
      });

      if (!response.ok) return null;

      const data = await response.json() as { value?: { sessionId?: string } };
      return data.value?.sessionId || null;
    } catch (error) {
      return null;
    }
  }

  /**
   * Find baseline screenshot for a test
   */
  private findBaseline(testName: string): string | null {
    const sanitizedName = this.sanitizeTestName(testName);
    const baselineDir = path.join(SCREENSHOT_DIR, 'baselines');

    if (!fs.existsSync(baselineDir)) {
      return null;
    }

    // Look for baseline files matching the test name
    const files = fs.readdirSync(baselineDir);
    const baselineFile = files.find(
      f => f.startsWith(sanitizedName) && f.endsWith('.png')
    );

    return baselineFile ? path.join(baselineDir, baselineFile) : null;
  }

  /**
   * Sanitize test name for use in filenames
   */
  private sanitizeTestName(name: string): string {
    return name
      .replace(/[^a-zA-Z0-9-_\s]/g, '')
      .replace(/\s+/g, '-')
      .toLowerCase()
      .substring(0, 100);
  }
}

// Singleton instance
let captureInstance: ScreenshotCapture | null = null;

export function getScreenshotCapture(): ScreenshotCapture {
  if (!captureInstance) {
    captureInstance = new ScreenshotCaptureImpl();
  }
  return captureInstance;
}

/**
 * Helper function for use in wdio hooks
 */
export async function captureFailureScreenshot(testName: string): Promise<string | null> {
  const capture = getScreenshotCapture();
  const result = await capture.captureOnTestFailure(testName);
  return result?.path || null;
}

/**
 * Helper function to capture and save baseline screenshots
 */
export async function captureBaseline(testName: string, sessionId?: string): Promise<string | null> {
  const capture = getScreenshotCapture();
  const sanitizedName = testName
    .replace(/[^a-zA-Z0-9-_\s]/g, '')
    .replace(/\s+/g, '-')
    .toLowerCase()
    .substring(0, 100);

  const baselineDir = path.join(SCREENSHOT_DIR, 'baselines');
  fs.mkdirSync(baselineDir, { recursive: true });

  const filename = `${sanitizedName}-baseline.png`;
  const filepath = path.join(baselineDir, filename);

  try {
    // Use the internal capture method
    const impl = capture as ScreenshotCaptureImpl;
    const screenshotBase64 = await (impl as any).captureScreenshot(sessionId);

    if (!screenshotBase64) {
      return null;
    }

    fs.writeFileSync(filepath, screenshotBase64, 'base64');
    log('info', `📸 Baseline captured: ${filename}`);
    return filepath;
  } catch (error) {
    log('error', 'Baseline capture failed', {
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}
