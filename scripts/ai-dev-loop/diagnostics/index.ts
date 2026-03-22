/**
 * Diagnostics Module Index
 *
 * Central export point for all diagnostic capture modules.
 */

export {
  getScreenshotCapture,
  captureFailureScreenshot,
  captureBaseline,
  type ScreenshotCapture,
} from './screenshot-capture.ts';

export {
  getConsoleCapture,
  captureTestConsole,
  formatConsoleLogsForPrompt,
  type ConsoleCapture,
} from './console-capture.ts';

export {
  getNetworkCapture,
  captureTestNetwork,
  formatNetworkLogsForPrompt,
  type NetworkCapture,
  type NetworkSummary,
} from './network-capture.ts';

import type { DiagnosticData, IpcCall } from '../types.ts';
import { getScreenshotCapture } from './screenshot-capture.ts';
import { getConsoleCapture } from './console-capture.ts';
import { getNetworkCapture } from './network-capture.ts';
import { log } from '../logger.ts';

const IPC_TRACE_URL = 'http://127.0.0.1:3000';  // Tauri app port

/**
 * Collect all diagnostic data for a test failure
 */
export async function collectDiagnostics(
  testName: string,
  options: {
    captureScreenshot?: boolean;
    captureConsole?: boolean;
    captureNetwork?: boolean;
    captureIpc?: boolean;
    captureAppState?: boolean;
  } = {}
): Promise<DiagnosticData> {
  const {
    captureScreenshot = true,
    captureConsole = true,
    captureNetwork = true,
    captureIpc = true,
    captureAppState = true,
  } = options;

  log('info', `Collecting diagnostics for: ${testName}`);

  const diagnostics: DiagnosticData = {
    screenshots: [],
    consoleLogs: [],
    networkRequests: [],
    ipcCalls: [],
    collectedAt: Date.now(),
  };

  // Capture screenshot
  if (captureScreenshot) {
    try {
      const screenshotCapture = getScreenshotCapture();
      const screenshot = await screenshotCapture.captureOnTestFailure(testName);
      if (screenshot) {
        diagnostics.screenshots.push(screenshot);
      }
    } catch (error) {
      log('warn', 'Failed to capture screenshot', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // Capture console logs
  if (captureConsole) {
    try {
      const consoleCapture = getConsoleCapture();
      const logs = consoleCapture.getCapturedLogs();
      diagnostics.consoleLogs = logs;
      consoleCapture.saveToFile(testName);
    } catch (error) {
      log('warn', 'Failed to capture console logs', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // Capture network requests
  if (captureNetwork) {
    try {
      const networkCapture = getNetworkCapture();
      const requests = networkCapture.getCapturedRequests();
      diagnostics.networkRequests = requests;
      networkCapture.saveToFile(testName);
    } catch (error) {
      log('warn', 'Failed to capture network requests', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // Capture IPC trace
  if (captureIpc) {
    try {
      const ipcCalls = await getIpcTrace();
      diagnostics.ipcCalls = ipcCalls;
    } catch (error) {
      log('warn', 'Failed to capture IPC trace', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // Capture app state
  if (captureAppState) {
    try {
      const appState = await captureAppStateFromBrowser();
      if (appState) {
        diagnostics.appState = appState;
      }
    } catch (error) {
      log('warn', 'Failed to capture app state', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return diagnostics;
}

/**
 * Get IPC trace from Tauri app
 */
async function getIpcTrace(): Promise<IpcCall[]> {
  try {
    // Try to invoke the e2e_get_ipc_trace command via Tauri IPC
    const response = await fetch(`${IPC_TRACE_URL}/__tauri__/ipc`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        cmd: 'e2e_get_ipc_trace',
        callback: 0,
        error: 1,
        payload: {},
      }),
    });

    if (response.ok) {
      const data = await response.json();
      return Array.isArray(data) ? data : [];
    }
  } catch (error) {
    // IPC trace might not be available
  }
  return [];
}

/**
 * Capture app state from browser
 */
async function captureAppStateFromBrowser(): Promise<import('../types.ts').AppState | null> {
  try {
    const webdriverBaseUrl = 'http://127.0.0.1:4444';

    // Get current session
    const statusResponse = await fetch(`${webdriverBaseUrl}/status`);
    if (!statusResponse.ok) return null;

    const statusData = await statusResponse.json() as {
      value?: { sessions?: Array<{ id: string }> }
    };

    const sessions = statusData.value?.sessions;
    if (!sessions || sessions.length === 0) return null;

    const sessionId = sessions[0].id;

    // Execute script to get app state
    const scriptResponse = await fetch(`${webdriverBaseUrl}/session/${sessionId}/execute/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        script: `
          return {
            url: window.location.href,
            title: document.title,
            domSnapshot: document.body.innerHTML.substring(0, 5000),
            localStorage: Object.fromEntries(Object.entries(localStorage)),
            sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
          };
        `,
        args: [],
      }),
    });

    if (scriptResponse.ok) {
      const result = await scriptResponse.json() as { value: import('../types.ts').AppState };
      return result.value;
    }
  } catch (error) {
    // App state capture might not be available
  }
  return null;
}

/**
 * Format diagnostics for inclusion in fix prompts
 */
export function formatDiagnosticsForPrompt(diagnostics: DiagnosticData): string {
  let output = '';

  // Screenshots
  if (diagnostics.screenshots.length > 0) {
    output += '### Screenshot\n';
    output += `Screenshot captured at failure: ${diagnostics.screenshots[0].path}\n`;
    if (diagnostics.screenshots[0].diffScore !== undefined) {
      output += `Visual difference from baseline: ${(diagnostics.screenshots[0].diffScore * 100).toFixed(1)}%\n`;
    }
    output += '\n';
  }

  // Console logs
  if (diagnostics.consoleLogs.length > 0) {
    const errors = diagnostics.consoleLogs.filter(l => l.level === 'error');
    const warnings = diagnostics.consoleLogs.filter(l => l.level === 'warn');

    if (errors.length > 0) {
      output += '### Console Errors\n';
      for (const error of errors.slice(0, 5)) {
        output += `- ${error.message}\n`;
      }
      if (errors.length > 5) output += `... and ${errors.length - 5} more errors\n`;
      output += '\n';
    }

    if (warnings.length > 0) {
      output += '### Console Warnings\n';
      for (const warning of warnings.slice(0, 3)) {
        output += `- ${warning.message}\n`;
      }
      if (warnings.length > 3) output += `... and ${warnings.length - 3} more warnings\n`;
      output += '\n';
    }
  }

  // Network requests
  if (diagnostics.networkRequests.length > 0) {
    const failed = diagnostics.networkRequests.filter(r => (r.status && r.status >= 400) || r.error);
    const slow = diagnostics.networkRequests.filter(r => r.duration > 3000);

    if (failed.length > 0) {
      output += '### Failed Network Requests\n';
      for (const req of failed.slice(0, 5)) {
        output += `- ${req.method} ${req.url} -> ${req.status || 'ERROR'}\n`;
      }
      if (failed.length > 5) output += `... and ${failed.length - 5} more failed requests\n`;
      output += '\n';
    }

    if (slow.length > 0) {
      output += '### Slow Network Requests\n';
      for (const req of slow.slice(0, 3)) {
        output += `- ${req.method} ${req.url} (${req.duration}ms)\n`;
      }
      output += '\n';
    }
  }

  // IPC calls
  if (diagnostics.ipcCalls.length > 0) {
    const failed = diagnostics.ipcCalls.filter(c => !c.success);
    if (failed.length > 0) {
      output += '### Failed IPC Calls\n';
      for (const call of failed.slice(0, 5)) {
        output += `- ${call.command}: ${call.error || 'Unknown error'}\n`;
      }
      if (failed.length > 5) output += `... and ${failed.length - 5} more failed IPC calls\n`;
      output += '\n';
    }
  }

  // App state
  if (diagnostics.appState) {
    output += '### App State\n';
    output += `- URL: ${diagnostics.appState.url}\n`;
    output += `- Title: ${diagnostics.appState.title}\n`;
    output += '\n';
  }

  return output || 'No diagnostic data collected.';
}

/**
 * Clear all diagnostic captures
 */
export function clearAllDiagnostics(): void {
  try {
    getConsoleCapture().clearLogs();
    getNetworkCapture().clearRequests();
  } catch (error) {
    // Ignore cleanup errors
  }
}