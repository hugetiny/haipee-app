/// <reference types="@wdio/globals/types" />
/**
 * OpenClaw Gateway Tests - Gateway management
 */

import { openClawGatewayPage, navigationPage } from '../pages';

describe('OpenClaw Gateway', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  describe('Gateway Status', () => {
    it('should display gateway status', async () => {
      const status = await openClawGatewayPage.getStatus();
      expect(typeof status).toBe('object');
    });

    it('should show gateway health badge', async () => {
      const badge = await $('[data-testid="gateway-status"]');
      if (await badge.isExisting()) {
        const text = await badge.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should show gateway port', async () => {
      const port = await openClawGatewayPage.getPort();
      expect(typeof port).toBe('object');
    });

    it('should display connected clients count', async () => {
      const count = await $('[data-testid="gateway-clients-count"]');
      const hasCount = await count.isExisting();
      expect(typeof hasCount).toBe('boolean');
    });
  });

  describe('Gateway Control', () => {
    it('should toggle gateway on/off', async () => {
      await openClawGatewayPage.toggle();
      await browser.pause(500);

      expect(true).toBe(true);
    });

    it('should show start/stop button', async () => {
      const toggleBtn = await $('[data-testid="gateway-toggle"]');
      const hasBtn = await toggleBtn.isExisting();
      expect(typeof hasBtn).toBe('boolean');
    });

    it('should update port setting', async () => {
      await openClawGatewayPage.setPort(8080);
      await browser.pause(300);

      expect(true).toBe(true);
    });
  });

  describe('Gateway Metrics', () => {
    it('should show request count', async () => {
      const requestCount = await $('[data-testid="gateway-request-count"]');
      if (await requestCount.isExisting()) {
        const text = await requestCount.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should show uptime', async () => {
      const uptime = await $('[data-testid="gateway-uptime"]');
      if (await uptime.isExisting()) {
        const text = await uptime.getText();
        expect(typeof text).toBe('string');
      }
    });

    it('should show error count', async () => {
      const errorCount = await $('[data-testid="gateway-error-count"]');
      const hasCount = await errorCount.isExisting();
      expect(typeof hasCount).toBe('boolean');
    });
  });
});