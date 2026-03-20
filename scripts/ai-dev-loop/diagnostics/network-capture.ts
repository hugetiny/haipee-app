/**
 * Network Request Capture Module
 *
 * Captures network requests during E2E test execution using WebdriverIO performance logs.
 * Tracks API calls, detects failures, and monitors request timing.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { NetworkRequest } from '../types.ts';
import { log } from '../logger.ts';

const NETWORK_LOG_DIR = './ai-loop-logs/network';

if (!fs.existsSync(NETWORK_LOG_DIR)) {
  fs.mkdirSync(NETWORK_LOG_DIR, { recursive: true });
}

export interface NetworkCapture {
  startCapture(sessionId?: string): Promise<void>;
  stopCapture(): Promise<void>;
  getCapturedRequests(): NetworkRequest[];
  getFailedRequests(): NetworkRequest[];
  getSlowRequests(thresholdMs?: number): NetworkRequest[];
  getRequestsByUrlPattern(pattern: RegExp): NetworkRequest[];
  clearRequests(): void;
  saveToFile(testName: string): string | null;
  detectApiErrors(): NetworkRequest[];
  getRequestSummary(): NetworkSummary;
}

export interface NetworkSummary {
  totalRequests: number;
  failedRequests: number;
  slowRequests: number;
  avgDuration: number;
  maxDuration: number;
  requestsByMethod: Record<string, number>;
  requestsByStatus: Record<number, number>;
}

class NetworkCaptureImpl implements NetworkCapture {
  private requests: NetworkRequest[] = [];
  private isCapturing = false;
  private webdriverBaseUrl = 'http://127.0.0.1:4444';
  private captureInterval: ReturnType<typeof setInterval> | null = null;
  private sessionId: string | null = null;
  private lastCaptureTime = 0;

  /**
   * Start capturing network requests
   */
  async startCapture(sessionId?: string): Promise<void> {
    if (this.isCapturing) {
      log('debug', 'Network capture already active');
      return;
    }

    this.sessionId = sessionId || await this.getCurrentSessionId();
    if (!this.sessionId) {
      log('warn', 'No WebDriver session for network capture');
      return;
    }

    this.isCapturing = true;
    this.requests = [];
    this.lastCaptureTime = Date.now();

    // Start polling for network performance logs
    this.captureInterval = setInterval(async () => {
      await this.pollNetworkLogs();
    }, 2000);  // Poll every 2 seconds

    log('debug', 'Network capture started');
  }

  /**
   * Stop capturing network requests
   */
  async stopCapture(): Promise<void> {
    if (this.captureInterval) {
      clearInterval(this.captureInterval);
      this.captureInterval = null;
    }

    // Final poll
    await this.pollNetworkLogs();

    this.isCapturing = false;
    log('debug', `Network capture stopped. Captured ${this.requests.length} requests`);
  }

  /**
   * Get all captured network requests
   */
  getCapturedRequests(): NetworkRequest[] {
    return [...this.requests];
  }

  /**
   * Get failed network requests (4xx, 5xx, or errors)
   */
  getFailedRequests(): NetworkRequest[] {
    return this.requests.filter(req =>
      (req.status && req.status >= 400) ||
      req.error !== undefined
    );
  }

  /**
   * Get slow network requests
   */
  getSlowRequests(thresholdMs: number = 3000): NetworkRequest[] {
    return this.requests.filter(req => req.duration > thresholdMs);
  }

  /**
   * Get requests matching a URL pattern
   */
  getRequestsByUrlPattern(pattern: RegExp): NetworkRequest[] {
    return this.requests.filter(req => pattern.test(req.url));
  }

  /**
   * Clear captured requests
   */
  clearRequests(): void {
    this.requests = [];
  }

  /**
   * Save captured requests to a file
   */
  saveToFile(testName: string): string | null {
    if (this.requests.length === 0) {
      return null;
    }

    const sanitizedName = testName
      .replace(/[^a-zA-Z0-9-_\s]/g, '')
      .replace(/\s+/g, '-')
      .toLowerCase()
      .substring(0, 100);

    const filename = `${sanitizedName}-${Date.now()}.log`;
    const filepath = path.join(NETWORK_LOG_DIR, filename);

    const content = this.requests
      .map(req => {
        const timestamp = new Date(req.timestamp).toISOString();
        let line = `[${timestamp}] ${req.method} ${req.url}`;
        if (req.status) line += ` -> ${req.status} ${req.statusText || ''}`;
        line += ` (${req.duration}ms)`;
        if (req.error) line += ` ERROR: ${req.error}`;
        return line;
      })
      .join('\n');

    fs.writeFileSync(filepath, content, 'utf-8');
    log('debug', `Network logs saved: ${filename}`);

    return filepath;
  }

  /**
   * Detect API errors
   */
  detectApiErrors(): NetworkRequest[] {
    return this.requests.filter(req => {
      // Filter for API endpoints (typically contain /api/ or specific patterns)
      const isApiCall = req.url.includes('/api/') ||
                        req.url.includes('/v1/') ||
                        req.url.includes('/graphql');

      const hasError = (req.status && req.status >= 400) || req.error !== undefined;

      return isApiCall && hasError;
    });
  }

  /**
   * Get request summary statistics
   */
  getRequestSummary(): NetworkSummary {
    const failed = this.getFailedRequests();
    const slow = this.getSlowRequests();

    // Calculate average duration
    const totalDuration = this.requests.reduce((sum, req) => sum + req.duration, 0);
    const avgDuration = this.requests.length > 0 ? totalDuration / this.requests.length : 0;

    // Calculate max duration
    const maxDuration = this.requests.length > 0
      ? Math.max(...this.requests.map(req => req.duration))
      : 0;

    // Count by method
    const requestsByMethod: Record<string, number> = {};
    for (const req of this.requests) {
      requestsByMethod[req.method] = (requestsByMethod[req.method] || 0) + 1;
    }

    // Count by status
    const requestsByStatus: Record<number, number> = {};
    for (const req of this.requests) {
      if (req.status) {
        requestsByStatus[req.status] = (requestsByStatus[req.status] || 0) + 1;
      }
    }

    return {
      totalRequests: this.requests.length,
      failedRequests: failed.length,
      slowRequests: slow.length,
      avgDuration: Math.round(avgDuration),
      maxDuration,
      requestsByMethod,
      requestsByStatus,
    };
  }

  /**
   * Poll for network performance logs via WebDriver
   */
  private async pollNetworkLogs(): Promise<void> {
    if (!this.sessionId) return;

    try {
      const url = `${this.webdriverBaseUrl}/session/${this.sessionId}/log`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type: 'performance' }),
      });

      if (!response.ok) {
        // Performance log type might not be supported
        return;
      }

      const data = await response.json() as {
        value: Array<{
          level: string;
          message: string;
          timestamp: number;
        }>
      };

      if (data.value && Array.isArray(data.value)) {
        for (const entry of data.value) {
          try {
            const messageData = JSON.parse(entry.message);
            const networkEvent = messageData.message;

            if (networkEvent && networkEvent.method === 'Network.responseReceived') {
              const response = networkEvent.params?.response;
              if (response) {
                const networkRequest: NetworkRequest = {
                  url: response.url || '',
                  method: networkEvent.params?.request?.method || 'GET',
                  status: response.status,
                  statusText: response.statusText,
                  duration: 0,  // Will be updated when request finishes
                  timestamp: entry.timestamp || Date.now(),
                  requestHeaders: networkEvent.params?.request?.headers,
                  responseHeaders: response.headers,
                };

                // Avoid duplicates
                const exists = this.requests.some(
                  r => r.url === networkRequest.url && r.timestamp === networkRequest.timestamp
                );

                if (!exists) {
                  this.requests.push(networkRequest);
                }
              }
            }

            if (networkEvent && networkEvent.method === 'Network.loadingFinished') {
              // Update duration for matching request
              const requestId = networkEvent.params?.requestId;
              if (requestId) {
                const matchingReq = this.requests.find(r =>
                  (r as any)._requestId === requestId
                );
                if (matchingReq) {
                  matchingReq.duration = networkEvent.params.timestamp
                    ? Math.round((networkEvent.params.timestamp - matchingReq.timestamp / 1000) * 1000)
                    : 0;
                }
              }
            }

            if (networkEvent && networkEvent.method === 'Network.loadingFailed') {
              // Mark request as failed
              const requestId = networkEvent.params?.requestId;
              if (requestId) {
                const matchingReq = this.requests.find(r =>
                  (r as any)._requestId === requestId
                );
                if (matchingReq) {
                  matchingReq.error = networkEvent.params?.errorText || 'Unknown network error';
                }
              }
            }
          } catch (parseError) {
            // Skip entries that can't be parsed
          }
        }
      }
    } catch (error) {
      // Silently ignore - performance log API might not be available
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
let captureInstance: NetworkCapture | null = null;

export function getNetworkCapture(): NetworkCapture {
  if (!captureInstance) {
    captureInstance = new NetworkCaptureImpl();
  }
  return captureInstance;
}

/**
 * Helper: Capture network requests for a test
 */
export async function captureTestNetwork(
  testName: string,
  testFn: () => Promise<void>
): Promise<NetworkRequest[]> {
  const capture = getNetworkCapture();

  await capture.startCapture();
  try {
    await testFn();
  } finally {
    await capture.stopCapture();
  }

  const requests = capture.getCapturedRequests();

  // Save if there are failures
  const failed = capture.getFailedRequests();
  if (failed.length > 0) {
    capture.saveToFile(testName);
  }

  return requests;
}

/**
 * Helper: Format network logs for inclusion in fix prompts
 */
export function formatNetworkLogsForPrompt(requests: NetworkRequest[]): string {
  if (requests.length === 0) {
    return 'No network requests captured.';
  }

  const failed = requests.filter(r => (r.status && r.status >= 400) || r.error);
  const slow = requests.filter(r => r.duration > 3000);

  let output = '';

  if (failed.length > 0) {
    output += '### Failed Network Requests\n';
    for (const req of failed.slice(0, 10)) {
      output += `- ${req.method} ${req.url}\n`;
      output += `  Status: ${req.status || 'N/A'} ${req.statusText || ''}\n`;
      if (req.error) output += `  Error: ${req.error}\n`;
    }
    if (failed.length > 10) {
      output += `... and ${failed.length - 10} more failed requests\n`;
    }
    output += '\n';
  }

  if (slow.length > 0) {
    output += '### Slow Network Requests (>3s)\n';
    for (const req of slow.slice(0, 5)) {
      output += `- ${req.method} ${req.url} (${req.duration}ms)\n`;
    }
    if (slow.length > 5) {
      output += `... and ${slow.length - 5} more slow requests\n`;
    }
    output += '\n';
  }

  // Summary
  const summary = {
    total: requests.length,
    failed: failed.length,
    slow: slow.length,
  };

  output += `### Network Summary\n`;
  output += `- Total requests: ${summary.total}\n`;
  output += `- Failed: ${summary.failed}\n`;
  output += `- Slow (>3s): ${summary.slow}\n`;

  return output;
}
