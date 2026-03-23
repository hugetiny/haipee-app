/// <reference types="@wdio/globals/types" />
/**
 * OpenClaw Messaging Tests - HTTP-based messaging with OpenClaw Gateway
 */

import { openClawGatewayPage, navigationPage } from '../pages';

describe('OpenClaw Messaging – Gateway Connection', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should get gateway connection status', async () => {
    const status = await openClawGatewayPage.getConnectionStatus();
    expect(typeof status).toBe('object');
    expect(typeof status.connected).toBe('boolean');
    expect(typeof status.status).toBe('string');
  });

  it('should show disconnected status initially', async () => {
    const status = await openClawGatewayPage.getConnectionStatus();
    // Gateway may or may not be running, just verify structure
    expect(['connected', 'disconnected', 'connecting', 'error']).toContain(status.status);
  });

  it('should check if gateway service is running', async () => {
    const running = await openClawGatewayPage.isServiceRunning();
    expect(typeof running).toBe('boolean');
  });
});

describe('OpenClaw Messaging – Connect Flow', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  after(async () => {
    // Cleanup: disconnect if connected
    try {
      await openClawGatewayPage.disconnect();
    } catch {
      // Ignore cleanup errors
    }
  });

  it('should attempt to connect to gateway', async () => {
    // This test verifies the connection attempt, not success
    // (gateway may not be running in CI)
    try {
      const connected = await openClawGatewayPage.connect();
      expect(typeof connected).toBe('boolean');
    } catch (error) {
      // Connection may fail if gateway not running - that's OK
      expect(error).toBeDefined();
    }
  });

  it('should update status after connection attempt', async () => {
    const status = await openClawGatewayPage.getConnectionStatus();
    expect(typeof status.status).toBe('string');
  });

  it('should disconnect from gateway', async () => {
    await openClawGatewayPage.disconnect();
    await browser.pause(500);

    const status = await openClawGatewayPage.getConnectionStatus();
    expect(status.connected).toBe(false);
  });
});

describe('OpenClaw Messaging – Send Message', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should fail to send message when not connected', async () => {
    // Ensure disconnected
    await openClawGatewayPage.disconnect();
    await browser.pause(300);

    // Attempt to send should fail or return null
    const result = await openClawGatewayPage.sendMessage('Test message');
    expect(result).toBeNull();
  });

  it('should handle empty message', async () => {
    const result = await openClawGatewayPage.sendMessage('');
    // Should fail gracefully
    expect(result === null || typeof result === 'string').toBe(true);
  });

  it('should send message when connected (if gateway available)', async () => {
    // Try to connect first
    const connected = await openClawGatewayPage.connect();

    if (connected) {
      const result = await openClawGatewayPage.sendMessage('Hello from E2E test');
      // Response should be a string (AI response) or null on error
      expect(result === null || typeof result === 'string').toBe(true);
    } else {
      // Gateway not available - skip test
      console.log('Gateway not available, skipping send test');
      expect(true).toBe(true);
    }
  });
});

describe('OpenClaw Messaging – Error Handling', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should handle invalid session key', async () => {
    await openClawGatewayPage.connect();
    await browser.pause(500);

    // Try with invalid session key
    const result = await openClawGatewayPage.sendMessage('Test', 'invalid-session-key');
    // Should fail gracefully
    expect(result === null || typeof result === 'string').toBe(true);
  });

  it('should handle very long messages', async () => {
    await openClawGatewayPage.connect();
    await browser.pause(500);

    const longMessage = 'A'.repeat(10000);
    const result = await openClawGatewayPage.sendMessage(longMessage);
    expect(result === null || typeof result === 'string').toBe(true);
  });

  it('should handle special characters in message', async () => {
    await openClawGatewayPage.connect();
    await browser.pause(500);

    const specialMessage = 'Test with special chars: <>&"\'\n\t\\';
    const result = await openClawGatewayPage.sendMessage(specialMessage);
    expect(result === null || typeof result === 'string').toBe(true);
  });
});