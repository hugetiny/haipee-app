/**
 * CrabNebula DevTools Client
 *
 * Connects to CrabNebula DevTools gRPC server and captures:
 * - IPC command traces with timeline correlation
 * - Performance metrics (CPU, memory)
 * - Rust log streaming
 * - Window/DOM state snapshots
 *
 * TRIAL PERIOD: Remove after 2026-04-01 (14-day trial ends)
 *
 * Architecture:
 *   - CrabNebula DevTools runs a gRPC server (tonic) on port 3033
 *   - The CrabNebula cloud UI (https://devtools.crabnebula.dev) connects to this server
 *   - This client checks server availability via TCP port check
 *   - Full data capture requires the CrabNebula cloud relay (not direct gRPC from Node.js)
 *
 * Usage:
 *   1. Build Tauri with devtools feature: cargo build --features devtools
 *   2. Run the app - DevTools gRPC server starts on 127.0.0.1:3033
 *   3. Connect via https://devtools.crabnebula.dev/dash/127.0.0.1/3033
 *   4. This client detects if the server is running and captures what's available
 */

import * as fs from 'fs';
import * as path from 'path';
import * as net from 'net';
import type { IpcCall } from '../types.ts';
import { log } from '../logger.ts';

const CRABNEBULA_LOG_DIR = './ai-loop-logs/crabnebula';

// Ensure log directory exists
if (!fs.existsSync(CRABNEBULA_LOG_DIR)) {
  fs.mkdirSync(CRABNEBULA_LOG_DIR, { recursive: true });
}

// ═══════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════

export interface CrabNebulaDevToolsConfig {
  enabled: boolean;
  grpcPort: number;       // Default: 3033 (gRPC server port)
  host: string;           // Default: 127.0.0.1
}

export interface TimelineEvent {
  timestamp: number;
  type: 'ipc' | 'log' | 'performance' | 'window';
  name: string;
  data: Record<string, unknown>;
  duration?: number;
}

export interface PerformanceSnapshot {
  timestamp: number;
  cpuUsage: number;       // Percentage
  memoryUsageMB: number;
  memoryTotalMB: number;
}

export interface RustLogEntry {
  timestamp: number;
  level: 'TRACE' | 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  target: string;
  message: string;
  modulePath?: string;
  file?: string;
  line?: number;
}

export interface CrabNebulaCaptureData {
  timeline: TimelineEvent[];
  performanceSnapshots: PerformanceSnapshot[];
  rustLogs: RustLogEntry[];
  ipcCalls: IpcCall[];
  capturedAt: number;
  connected: boolean;
  serverPort?: number;    // The actual port the gRPC server is on
}

export interface CrabNebulaCapture {
  connect(): Promise<boolean>;
  disconnect(): void;
  isConnected(): boolean;
  captureAll(): Promise<CrabNebulaCaptureData>;
  captureTimeline(since?: number): Promise<TimelineEvent[]>;
  capturePerformanceSnapshot(): Promise<PerformanceSnapshot | null>;
  captureRustLogs(since?: number): Promise<RustLogEntry[]>;
  captureIpcTrace(): Promise<IpcCall[]>;
  saveToFile(testName: string): string | null;
}

// ═══════════════════════════════════════════════════════════════════
// Implementation
// ═══════════════════════════════════════════════════════════════════

const DEFAULT_CONFIG: CrabNebulaDevToolsConfig = {
  enabled: true,
  grpcPort: 3033,        // Default gRPC port from tauri-plugin-devtools
  host: '127.0.0.1',
};

/**
 * Check if a TCP port is open (gRPC server is listening)
 */
function checkPortOpen(host: string, port: number, timeoutMs: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let resolved = false;

    const cleanup = () => {
      if (!resolved) {
        resolved = true;
        socket.destroy();
      }
    };

    socket.setTimeout(timeoutMs);
    socket.on('connect', () => {
      cleanup();
      resolve(true);
    });
    socket.on('timeout', () => {
      cleanup();
      resolve(false);
    });
    socket.on('error', () => {
      cleanup();
      resolve(false);
    });

    socket.connect(port, host);
  });
}

class CrabNebulaCaptureImpl implements CrabNebulaCapture {
  private config: CrabNebulaDevToolsConfig;
  private connected = false;
  private lastConnectAttempt = 0;
  private connectRetryMs = 5000;
  private detectedPort: number | null = null;

  constructor(config: Partial<CrabNebulaDevToolsConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Check if CrabNebula DevTools gRPC server is available
   *
   * Uses TCP port check to detect if the gRPC server is listening.
   * The actual port may differ from the default if 3033 is in use
   * (the plugin auto-selects a free port).
   */
  async connect(): Promise<boolean> {
    // Rate limit connection attempts
    const now = Date.now();
    if (now - this.lastConnectAttempt < this.connectRetryMs) {
      return this.connected;
    }
    this.lastConnectAttempt = now;

    try {
      // Check default gRPC port
      const isOpen = await checkPortOpen(
        this.config.host,
        this.config.grpcPort,
        2000
      );

      if (isOpen) {
        this.connected = true;
        this.detectedPort = this.config.grpcPort;
        log('info', `CrabNebula DevTools gRPC server detected on port ${this.config.grpcPort}`);
      } else {
        this.connected = false;
        this.detectedPort = null;
        log('debug', `CrabNebula DevTools gRPC server not available on port ${this.config.grpcPort}`);
      }

      return this.connected;
    } catch {
      this.connected = false;
      this.detectedPort = null;
      log('debug', 'CrabNebula DevTools connection check failed');
      return false;
    }
  }

  /**
   * Disconnect from DevTools
   */
  disconnect(): void {
    this.connected = false;
    this.detectedPort = null;
    log('debug', 'CrabNebula DevTools disconnected');
  }

  /**
   * Check if currently connected
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Capture all available data from DevTools
   *
   * NOTE: Full data capture (timeline, logs, IPC traces) requires the
   * CrabNebula cloud relay at https://devtools.crabnebula.dev.
   * Direct gRPC access from Node.js is not implemented in this trial.
   */
  async captureAll(): Promise<CrabNebulaCaptureData> {
    if (!this.connected) {
      await this.connect();
    }

    if (!this.connected) {
      return this.getEmptyCaptureData();
    }

    // In trial mode, we can detect the server but can't capture actual data
    // without implementing the full gRPC client (protobuf + tonic-web)
    // The CrabNebula cloud UI provides this functionality
    return {
      timeline: [],
      performanceSnapshots: [],
      rustLogs: [],
      ipcCalls: [],
      capturedAt: Date.now(),
      connected: true,
      serverPort: this.detectedPort ?? undefined,
    };
  }

  /**
   * Capture timeline events
   * Requires CrabNebula cloud relay - returns empty in trial mode
   */
  async captureTimeline(_since?: number): Promise<TimelineEvent[]> {
    if (!this.connected) return [];
    // TODO: Implement gRPC client for devtools_core::server::wire protocol
    return [];
  }

  /**
   * Capture current performance snapshot
   * Requires CrabNebula cloud relay - returns null in trial mode
   */
  async capturePerformanceSnapshot(): Promise<PerformanceSnapshot | null> {
    if (!this.connected) return null;
    // TODO: Implement gRPC client for devtools_core::server::wire protocol
    return null;
  }

  /**
   * Capture Rust log entries
   * Requires CrabNebula cloud relay - returns empty in trial mode
   */
  async captureRustLogs(_since?: number): Promise<RustLogEntry[]> {
    if (!this.connected) return [];
    // TODO: Implement gRPC client for devtools_core::server::wire protocol
    return [];
  }

  /**
   * Capture IPC trace from DevTools
   * Requires CrabNebula cloud relay - returns empty in trial mode
   */
  async captureIpcTrace(): Promise<IpcCall[]> {
    if (!this.connected) return [];
    // TODO: Implement gRPC client for devtools_core::server::wire protocol
    return [];
  }

  /**
   * Save captured data to file
   */
  saveToFile(testName: string): string | null {
    const sanitizedName = testName
      .replace(/[^a-zA-Z0-9-_\s]/g, '')
      .replace(/\s+/g, '-')
      .toLowerCase()
      .substring(0, 100);

    const filename = `${sanitizedName}-${Date.now()}.json`;
    const filepath = path.join(CRABNEBULA_LOG_DIR, filename);

    try {
      const data = {
        testName,
        capturedAt: Date.now(),
        connected: this.connected,
        serverPort: this.detectedPort,
        config: this.config,
        note: 'Full data capture requires CrabNebula cloud relay (https://devtools.crabnebula.dev)',
      };

      fs.writeFileSync(filepath, JSON.stringify(data, null, 2), 'utf-8');
      log('debug', `CrabNebula data saved: ${filename}`);
      return filepath;
    } catch (error) {
      log('error', 'Failed to save CrabNebula data', {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Get empty capture data structure
   */
  private getEmptyCaptureData(): CrabNebulaCaptureData {
    return {
      timeline: [],
      performanceSnapshots: [],
      rustLogs: [],
      ipcCalls: [],
      capturedAt: Date.now(),
      connected: false,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════
// Singleton & Helpers
// ═══════════════════════════════════════════════════════════════════

let captureInstance: CrabNebulaCapture | null = null;

export function getCrabNebulaCapture(config?: Partial<CrabNebulaDevToolsConfig>): CrabNebulaCapture {
  if (!captureInstance) {
    captureInstance = new CrabNebulaCaptureImpl(config);
  }
  return captureInstance;
}

/**
 * Format CrabNebula data for inclusion in fix prompts
 * TRIAL: Remove after 2026-04-01
 */
export function formatCrabNebulaDataForPrompt(data: CrabNebulaCaptureData): string {
  if (!data.connected) {
    return '';  // Don't include section if not connected
  }

  let output = '### CrabNebula DevTools Data\n';
  output += `**Server:** gRPC on port ${data.serverPort ?? 'unknown'}\n`;
  output += `**Dashboard:** https://devtools.crabnebula.dev/dash/127.0.0.1/${data.serverPort ?? 3033}\n`;

  // Performance snapshot
  if (data.performanceSnapshots.length > 0) {
    const latest = data.performanceSnapshots[data.performanceSnapshots.length - 1];
    output += '**Performance at failure:**\n';
    output += `- CPU: ${latest.cpuUsage.toFixed(1)}%\n`;
    output += `- Memory: ${latest.memoryUsageMB.toFixed(0)}MB / ${latest.memoryTotalMB.toFixed(0)}MB\n`;
  }

  // Rust errors
  const rustErrors = data.rustLogs.filter(l => l.level === 'ERROR');
  if (rustErrors.length > 0) {
    output += '**Rust errors:**\n';
    for (const err of rustErrors.slice(0, 5)) {
      output += `- [${err.target}] ${err.message}\n`;
    }
    if (rustErrors.length > 5) {
      output += `... and ${rustErrors.length - 5} more errors\n`;
    }
  }

  // Timeline events near failure time
  if (data.timeline.length > 0) {
    output += '**Recent timeline events:**\n';
    for (const event of data.timeline.slice(-5)) {
      output += `- ${event.type}: ${event.name}`;
      if (event.duration) output += ` (${event.duration}ms)`;
      output += '\n';
    }
  }

  output += '\n';
  return output;
}

/**
 * Check CrabNebula availability and log status
 */
export async function checkCrabNebulaAvailability(): Promise<boolean> {
  const capture = getCrabNebulaCapture();
  const available = await capture.connect();

  if (available) {
    log('info', 'CrabNebula DevTools gRPC server detected - enhanced diagnostics possible via cloud relay');
  } else {
    log('debug', 'CrabNebula DevTools not available - using standard diagnostics');
  }

  return available;
}
