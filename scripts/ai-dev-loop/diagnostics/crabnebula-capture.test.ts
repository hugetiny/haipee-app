/**
 * CrabNebula DevTools Capture Tests
 *
 * NOTE: Full integration testing (actual DevTools connection) requires:
 *   1. bun run dev:devtools  (starts Tauri with devtools feature)
 *   2. CrabNebula UI connected at https://app.crabnebula.dev
 *
 * These tests validate offline behavior (graceful degradation).
 */

import { describe, it, expect, beforeEach } from 'vitest';
import {
  getCrabNebulaCapture,
  formatCrabNebulaDataForPrompt,
  checkCrabNebulaAvailability,
  type CrabNebulaCaptureData,
} from './crabnebula-capture.ts';

describe('CrabNebula DevTools Capture', () => {
  let capture: ReturnType<typeof getCrabNebulaCapture>;

  beforeEach(() => {
    // Reset singleton by importing fresh (each test gets new instance via force config)
    capture = getCrabNebulaCapture({ grpcPort: 3033 });
  });

  describe('when DevTools is NOT running (graceful degradation)', () => {
    it('connect() returns false', async () => {
      const connected = await capture.connect();
      expect(connected).toBe(false);
    });

    it('isConnected() returns false after failed connect', async () => {
      await capture.connect();
      expect(capture.isConnected()).toBe(false);
    });

    it('captureAll() returns empty data with connected: false', async () => {
      const data = await capture.captureAll();
      expect(data.connected).toBe(false);
      expect(data.timeline).toEqual([]);
      expect(data.performanceSnapshots).toEqual([]);
      expect(data.rustLogs).toEqual([]);
      expect(data.ipcCalls).toEqual([]);
      expect(data.capturedAt).toBeTypeOf('number');
    });

    it('captureTimeline() returns empty array', async () => {
      const events = await capture.captureTimeline();
      expect(events).toEqual([]);
    });

    it('capturePerformanceSnapshot() returns null', async () => {
      const snapshot = await capture.capturePerformanceSnapshot();
      expect(snapshot).toBeNull();
    });

    it('captureRustLogs() returns empty array', async () => {
      const logs = await capture.captureRustLogs();
      expect(logs).toEqual([]);
    });

    it('captureIpcTrace() returns empty array', async () => {
      const calls = await capture.captureIpcTrace();
      expect(calls).toEqual([]);
    });

    it('disconnect() sets connected to false', async () => {
      capture.disconnect();
      expect(capture.isConnected()).toBe(false);
    });

    it('saveToFile() creates file even when not connected', () => {
      const filepath = capture.saveToFile('test-disconnected');
      expect(filepath).toBeTruthy();
      expect(filepath).toContain('test-disconnected');
    });
  });

  describe('formatCrabNebulaDataForPrompt', () => {
    it('returns empty string when not connected', () => {
      const data: CrabNebulaCaptureData = {
        timeline: [],
        performanceSnapshots: [],
        rustLogs: [],
        ipcCalls: [],
        capturedAt: Date.now(),
        connected: false,
      };
      const output = formatCrabNebulaDataForPrompt(data);
      expect(output).toBe('');
    });

    it('formats performance data when connected', () => {
      const data: CrabNebulaCaptureData = {
        timeline: [],
        performanceSnapshots: [
          { timestamp: Date.now(), cpuUsage: 25.5, memoryUsageMB: 128, memoryTotalMB: 512 },
        ],
        rustLogs: [],
        ipcCalls: [],
        capturedAt: Date.now(),
        connected: true,
      };
      const output = formatCrabNebulaDataForPrompt(data);
      expect(output).toContain('CrabNebula DevTools Data');
      expect(output).toContain('CPU: 25.5%');
      expect(output).toContain('Memory: 128MB / 512MB');
    });

    it('formats Rust errors when present', () => {
      const data: CrabNebulaCaptureData = {
        timeline: [],
        performanceSnapshots: [],
        rustLogs: [
          {
            timestamp: Date.now(),
            level: 'ERROR',
            target: 'test_module',
            message: 'Test error message',
          },
        ],
        ipcCalls: [],
        capturedAt: Date.now(),
        connected: true,
      };
      const output = formatCrabNebulaDataForPrompt(data);
      expect(output).toContain('Rust errors:');
      expect(output).toContain('[test_module] Test error message');
    });

    it('formats timeline events', () => {
      const data: CrabNebulaCaptureData = {
        timeline: [
          {
            timestamp: Date.now(),
            type: 'ipc',
            name: 'test_command',
            data: {},
            duration: 100,
          },
        ],
        performanceSnapshots: [],
        rustLogs: [],
        ipcCalls: [],
        capturedAt: Date.now(),
        connected: true,
      };
      const output = formatCrabNebulaDataForPrompt(data);
      expect(output).toContain('Recent timeline events:');
      expect(output).toContain('ipc: test_command (100ms)');
    });
  });

  describe('checkCrabNebulaAvailability', () => {
    it('returns false when DevTools is not running', async () => {
      const available = await checkCrabNebulaAvailability();
      expect(available).toBe(false);
    });
  });
});
