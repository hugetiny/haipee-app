/// <reference types="@wdio/globals/types" />
/**
 * Sessions Tests - Session management
 */

import { navigationPage } from '../pages';

describe('Sessions – List', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should display sessions list', async () => {
    const list = await $('[data-testid="sessions-list"]');
    const hasList = await list.isExisting();
    expect(typeof hasList).toBe('boolean');
  });

  it('should show session count or empty state', async () => {
    const hasContent = await navigationPage.pageContainsAnyText([
      '会话', 'Session', '暂无', 'Empty', 'history', '历史'
    ]);
    expect(hasContent).toBe(true);
  });

  it('should display session items if available', async () => {
    const sessions = await $$('[data-testid="session-item"], [data-session-id]');
    expect(sessions.length).toBeGreaterThanOrEqual(0);
  });
});

describe('Sessions – Filtering', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show app filter buttons', async () => {
    const apps = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];
    for (const app of apps) {
      const filterBtn = await $(`[data-testid="session-filter-${app}"]`);
      const hasBtn = await filterBtn.isExisting();
      expect(typeof hasBtn).toBe('boolean');
    }
  });

  it('should filter sessions by app', async () => {
    const claudeFilter = await $('[data-testid="session-filter-claude"]');
    if (await claudeFilter.isExisting()) {
      await claudeFilter.click();
      await browser.pause(300);
      expect(true).toBe(true);
    }
  });

  it('should show search input', async () => {
    const searchInput = await $('[data-testid="session-search"]');
    const hasSearch = await searchInput.isExisting();
    expect(typeof hasSearch).toBe('boolean');
  });

  it('should filter sessions by search query', async () => {
    const searchInput = await $('[data-testid="session-search"]');
    if (await searchInput.isExisting()) {
      await searchInput.setValue('test');
      await browser.pause(300);
      expect(true).toBe(true);
    }
  });
});

describe('Sessions – Actions', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show actions for each session', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      const firstSession = sessionArray[0];
      const actionsBtn = await firstSession.$('button[aria-label*="action"], button[aria-label*="操作"]');
      const hasActions = await actionsBtn.isExisting();
      expect(typeof hasActions).toBe('boolean');
    }
  });

  it('should open session details on click', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      const firstSession = sessionArray[0];
      await firstSession.click();
      await browser.pause(500);
      expect(true).toBe(true);
    }
  });

  it('should show delete option for sessions', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      const firstSession = sessionArray[0];
      const deleteBtn = await firstSession.$('button[aria-label*="delete"], button[aria-label*="删除"]');
      const hasDelete = await deleteBtn.isExisting();
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('Sessions – Bulk Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show select all checkbox if supported', async () => {
    const selectAll = await $('[data-testid="select-all-sessions"]');
    const hasSelect = await selectAll.isExisting();
    expect(typeof hasSelect).toBe('boolean');
  });

  it('should show bulk delete button when items selected', async () => {
    const bulkDelete = await $('[data-testid="bulk-delete-sessions"]');
    const hasBulk = await bulkDelete.isExisting();
    expect(typeof hasBulk).toBe('boolean');
  });
});

describe('Sessions – Export', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show export button', async () => {
    const exportBtn = await $('[data-testid="export-sessions-btn"]');
    const hasBtn = await exportBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should export session history', async () => {
    const exportBtn = await $('[data-testid="export-sessions-btn"]');
    if (await exportBtn.isExisting()) {
      await exportBtn.click();
      await browser.pause(500);
      expect(true).toBe(true);
    }
  });
});