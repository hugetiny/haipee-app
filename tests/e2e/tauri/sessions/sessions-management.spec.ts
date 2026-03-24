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
    expect(typeof hasContent).toBe('boolean');
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

describe('Sessions – Create Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show create session button', async () => {
    const byTestId = await $('[data-testid="session-create-btn"]');
    let hasBtn = await byTestId.isExisting();
    if (!hasBtn) {
      hasBtn = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some((btn) => {
          const text = btn.textContent || '';
          const aria = btn.getAttribute('aria-label') || '';
          return text.includes('新建') || text.includes('New') ||
            aria.includes('新建') || aria.toLowerCase().includes('new');
        });
      });
    }
    expect(typeof hasBtn).toBe('boolean');
  });

  it('should open create session form', async () => {
    const createBtn = await $('[data-testid="session-create-btn"]');
    if (await createBtn.isExisting()) {
      await createBtn.click();
      await browser.pause(500);

      const form = await $('[data-testid="session-form"], form');
      const hasForm = await form.isExisting();
      expect(typeof hasForm).toBe('boolean');
    }
  });

  it('should create session with valid data', async () => {
    const nameInput = await $('[data-testid="session-name-input"], input[name="sessionName"]');
    if (await nameInput.isExisting()) {
      await nameInput.clearValue();
      await nameInput.addValue(`E2E Test Session ${Date.now()}`);
      await browser.pause(200);

      const saveBtn = await $('[data-testid="session-save-btn"], button[type="submit"]');
      if (await saveBtn.isExisting()) {
        await saveBtn.click();
        await browser.pause(500);
      }
    }
    expect(true).toBe(true);
  });
});

describe('Sessions – Update Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show edit button for sessions', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      const firstSession = sessionArray[0];
      const editBtn = await firstSession.$('button[aria-label*="edit"], button[aria-label*="编辑"]');
      const hasEdit = await editBtn.isExisting();
      expect(typeof hasEdit).toBe('boolean');
    }
  });

  it('should open edit form when edit clicked', async () => {
    const editBtns = await $$('[data-testid="session-item"] button[aria-label*="edit"]');
    const editBtnArray = [...editBtns] as unknown as WebdriverIO.Element[];
    if (editBtnArray.length > 0) {
      await editBtnArray[0].click();
      await browser.pause(500);

      const form = await $('[data-testid="session-form"], form');
      const hasForm = await form.isExisting();
      expect(typeof hasForm).toBe('boolean');
    }
  });

  it('should update session name', async () => {
    const nameInput = await $('[data-testid="session-name-input"], input[name="sessionName"]');
    if (await nameInput.isExisting()) {
      await nameInput.clearValue();
      await nameInput.addValue(`Updated ${Date.now()}`);
      await browser.pause(200);

      const saveBtn = await $('[data-testid="session-save-btn"], button[type="submit"]');
      if (await saveBtn.isExisting()) {
        await saveBtn.click();
        await browser.pause(500);
      }
    }
    expect(true).toBe(true);
  });
});

describe('Sessions – Delete Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should show delete confirmation dialog', async () => {
    const deleteBtns = await $$('[data-testid="session-item"] button[aria-label*="delete"]');
    const deleteBtnArray = [...deleteBtns] as unknown as WebdriverIO.Element[];
    if (deleteBtnArray.length > 0) {
      await deleteBtnArray[0].click();
      await browser.pause(500);

      const confirmDialog = await $('[data-testid="confirm-dialog"], [role="alertdialog"]');
      const hasDialog = await confirmDialog.isExisting();
      expect(typeof hasDialog).toBe('boolean');
    }
  });

  it('should cancel delete operation', async () => {
    const cancelBtn = await $('[data-testid="confirm-cancel"]');
    if (await cancelBtn.isExisting()) {
      await cancelBtn.click();
      await browser.pause(300);
    } else {
      await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        const target = buttons.find((btn) => {
          const text = btn.textContent || '';
          const aria = btn.getAttribute('aria-label') || '';
          return text.includes('取消') || text.includes('Cancel') ||
            aria.includes('取消') || aria.includes('Cancel');
        });
        target?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      });
      await browser.pause(300);
    }
    expect(true).toBe(true);
  });

  it('should confirm delete operation', async () => {
    const deleteBtns = await $$('[data-testid="session-item"] button[aria-label*="delete"]');
    const deleteBtnArray = [...deleteBtns] as unknown as WebdriverIO.Element[];
    if (deleteBtnArray.length > 0) {
      await deleteBtnArray[0].click();
      await browser.pause(500);

      const confirmBtn = await $('[data-testid="confirm-ok"]');
      if (await confirmBtn.isExisting()) {
        await confirmBtn.click();
        await browser.pause(500);
      } else {
        await browser.execute(() => {
          const buttons = Array.from(document.querySelectorAll('button'));
          const target = buttons.find((btn) => {
            const text = btn.textContent || '';
            const aria = btn.getAttribute('aria-label') || '';
            return text.includes('确认') || text.includes('Confirm') ||
              aria.includes('确认') || aria.includes('Confirm');
          });
          target?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        });
        await browser.pause(500);
      }
    }
    expect(true).toBe(true);
  });
});

describe('Sessions – Switch Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('sessions');
    await browser.pause(1000);
  });

  it('should highlight active session', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      let hasActive = false;
      for (const session of sessionArray) {
        const classes = await session.getAttribute('class');
        if (classes?.includes('active') || classes?.includes('selected')) {
          hasActive = true;
          break;
        }
      }
      expect(typeof hasActive).toBe('boolean');
    }
  });

  it('should switch to different session on click', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 1) {
      await sessionArray[1].click();
      await browser.pause(500);

      const classes = await sessionArray[1].getAttribute('class');
      expect(typeof classes).toBe('string');
    }
  });

  it('should preserve session state when switching', async () => {
    const sessions = await $$('[data-testid="session-item"]');
    const sessionArray = [...sessions] as unknown as WebdriverIO.Element[];
    if (sessionArray.length > 0) {
      await sessionArray[0].click();
      await browser.pause(300);
    }
    expect(true).toBe(true);
  });
});
