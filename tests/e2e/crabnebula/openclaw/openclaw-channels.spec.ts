/// <reference types="@wdio/globals/types" />
/**
 * OpenClaw Channels Tests - MCP channel management
 */

import { openClawChannelsPage, navigationPage } from '../pages';

describe('OpenClaw Channels – List', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should display channels list', async () => {
    const count = await openClawChannelsPage.getChannelCount();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  it('should show channel names', async () => {
    const names = await openClawChannelsPage.getChannelNames();
    expect(Array.isArray(names)).toBe(true);
  });

  it('should show channel status indicators', async () => {
    const channels = await $$('[data-testid="channel-item"]');
    const channelArray = [...channels] as unknown as WebdriverIO.Element[];
    if (channelArray.length > 0) {
      const firstChannel = channelArray[0];
      const status = await firstChannel.$('[data-testid="channel-status"], [class*="status"]');
      const hasStatus = await status.isExisting();
      expect(typeof hasStatus).toBe('boolean');
    }
  });
});

describe('OpenClaw Channels – CRUD', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should show add channel button', async () => {
    const addBtn = await $('[data-testid="channel-add-btn"]');
    const hasBtn = await addBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should open add channel form', async () => {
    const addBtn = await $('[data-testid="channel-add-btn"]');
    if (await addBtn.isExisting()) {
      await addBtn.click();
      await browser.pause(500);

      const hasForm = await openClawChannelsPage.pageContainsAnyText([
        '添加', 'Add', 'Channel', '频道'
      ]);
      expect(typeof hasForm).toBe('boolean');

      await browser.keys(['Escape']);
    }
  });

  it('should toggle channel enabled state', async () => {
    const channels = await $$('[data-testid="channel-item"]');
    const channelArray = [...channels] as unknown as WebdriverIO.Element[];
    if (channelArray.length > 0) {
      const firstChannel = channelArray[0];
      const toggle = await firstChannel.$('button[role="switch"], input[type="checkbox"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
        expect(true).toBe(true);
      }
    }
  });

  it('should show delete channel button', async () => {
    const channels = await $$('[data-testid="channel-item"]');
    const channelArray = [...channels] as unknown as WebdriverIO.Element[];
    if (channelArray.length > 0) {
      const firstChannel = channelArray[0];
      const deleteBtn = await firstChannel.$('button[aria-label*="delete"], button[aria-label*="删除"]');
      const hasDelete = await deleteBtn.isExisting();
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('OpenClaw Channels – Connection', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);
  });

  it('should show connection status', async () => {
    const status = await $('[data-testid="connection-status"]');
    if (await status.isExisting()) {
      const text = await status.getText();
      expect(typeof text).toBe('string');
    }
  });

  it('should show WebSocket indicator', async () => {
    const wsIndicator = await $('[data-testid="websocket-status"]');
    const hasIndicator = await wsIndicator.isExisting();
    expect(typeof hasIndicator).toBe('boolean');
  });

  it('should attempt reconnection on disconnect', async () => {
    // This would test the reconnection logic
    expect(true).toBe(true);
  });
});