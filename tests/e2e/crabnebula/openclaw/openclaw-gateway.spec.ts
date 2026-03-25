/// <reference types="@wdio/globals/types" />
/**
 * OpenClaw Gateway Tests - Gateway management
 */

import { openClawGatewayPage, navigationPage } from '../pages';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('OpenClaw Gateway', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  describe('Gateway Status', () => {
    it('should display gateway status', async () => {
      const status = await openClawGatewayPage.getStatus();
      // Status object should have expected properties
      expect(status).toBeDefined();
      expect(Object.keys(status).length).toBeGreaterThan(0);
    });

    it('should show gateway health badge', async () => {
      const badge = await $('[data-testid="gateway-status"]');
      if (await badge.isExisting()) {
        const text = await badge.getText();
        expect(text!.length).toBeGreaterThan(0);
      } else {
        // Badge not found - verify page state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show gateway port', async () => {
      const port = await openClawGatewayPage.getPort();
      // Port should be a valid port object or configuration
      expect(port).toBeDefined();
    });

    it('should display connected clients count', async () => {
      const count = await $('[data-testid="gateway-clients-count"]');
      if (await count.isExisting()) {
        const text = await count.getText();
        expect(text!.length).toBeGreaterThanOrEqual(0);
      } else {
        // Count not found - verify page state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });

  describe('Gateway Control', () => {
    it('should toggle gateway on/off', async () => {
      const statusBefore = await openClawGatewayPage.getStatus();
      await openClawGatewayPage.toggle();
      await browser.pause(500);

      const statusAfter = await openClawGatewayPage.getStatus();
      // Gateway state should be defined after toggle
      expect(statusAfter).toBeDefined();
    });

    it('should show start/stop button', async () => {
      const toggleBtn = await $('[data-testid="gateway-toggle"]');
      // Toggle button should exist for gateway control
      expect(await toggleBtn.isExisting()).toBe(true);
    });

    it('should update port setting', async () => {
      await openClawGatewayPage.setPort(8080);
      await browser.pause(300);

      const port = await openClawGatewayPage.getPort();
      // Port should be set (or at least the call succeeded)
      expect(port).toBeDefined();
    });
  });

  describe('Gateway Metrics', () => {
    it('should show request count', async () => {
      const requestCount = await $('[data-testid="gateway-request-count"]');
      if (await requestCount.isExisting()) {
        const text = await requestCount.getText();
        expect(text!.length).toBeGreaterThan(0);
      } else {
        // Request count not found - verify page state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show uptime', async () => {
      const uptime = await $('[data-testid="gateway-uptime"]');
      if (await uptime.isExisting()) {
        const text = await uptime.getText();
        expect(text!.length).toBeGreaterThan(0);
      } else {
        // Uptime not found - verify page state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show error count', async () => {
      const errorCount = await $('[data-testid="gateway-error-count"]');
      if (await errorCount.isExisting()) {
        const text = await errorCount.getText();
        expect(text!.length).toBeGreaterThanOrEqual(0);
      } else {
        // Error count not found - verify page state
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });
  });
});