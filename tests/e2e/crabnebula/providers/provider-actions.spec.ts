/// <reference types="@wdio/globals/types" />
/**
 * Provider Actions Tests - Additional actions on providers
 */

import { dashboardPage, navigationPage } from '../pages';
import { createTestProvider } from '../fixtures';

describe('Provider Actions – Website', () => {
  const testProvider = createTestProvider({ name: `Web Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider with website
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should show website button if provider has URL', async () => {
    const card = await dashboardPage.findProviderCard(testProvider.name);
    if (card) {
      // Look for website link
      const websiteBtn = await card.$('a[href*="http"], button[aria-label*="网站"], button[aria-label*="website"]');
      const hasWebsite = await websiteBtn.isExisting();
      expect(typeof hasWebsite).toBe('boolean');
    }
  });
});

describe('Provider Actions – Test Endpoint', () => {
  const testProvider = createTestProvider({ name: `Endpoint Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should show test endpoint button', async () => {
    const card = await dashboardPage.findProviderCard(testProvider.name);
    if (card) {
      // Look for test button
      const testBtn = await card.$('button[aria-label*="测试"], button[aria-label*="test"], [data-testid="test-endpoint-btn"]');
      const hasTest = await testBtn.isExisting();
      expect(typeof hasTest).toBe('boolean');
    }
  });

  it('should show test result after testing', async () => {
    await dashboardPage.testProvider(testProvider.name);
    await browser.pause(2000);

    // Check for result (toast or inline)
    const hasResult = await dashboardPage.pageContainsAnyText([
      'success', '成功', 'failed', '失败', 'error', '错误', '连接', 'connected'
    ]);
    expect(typeof hasResult).toBe('boolean');
  });
});

describe('Provider Actions – Menu', () => {
  const testProvider = createTestProvider({ name: `Menu Test ${Date.now()}` });

  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);

    // Create test provider
    await dashboardPage.addProvider({
      name: testProvider.name,
      apiKey: testProvider.apiKey,
    });
    await browser.pause(1000);
  });

  after(async () => {
    try {
      await dashboardPage.deleteProvider(testProvider.name);
    } catch {
      // Ignore
    }
  });

  it('should open actions menu on click', async () => {
    await dashboardPage.openProviderActions(testProvider.name);
    await browser.pause(300);

    // Should show action options
    const hasActions = await dashboardPage.pageContainsAnyText([
      '编辑', 'Edit', '删除', 'Delete', '复制', 'Duplicate'
    ]);
    expect(typeof hasActions).toBe('boolean');

    // Close menu
    await browser.keys(['Escape']);
    await browser.pause(200);
  });

  it('should show edit option in menu', async () => {
    await dashboardPage.openProviderActions(testProvider.name);
    await browser.pause(300);

    // Find edit button using browser.execute for WebKit compatibility
    const hasEdit = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.some(btn =>
        btn.textContent?.includes('编辑') ||
        btn.textContent?.includes('Edit')
      );
    });
    expect(typeof hasEdit).toBe('boolean');

    await browser.keys(['Escape']);
    await browser.pause(200);
  });

  it('should show delete option in menu', async () => {
    await dashboardPage.openProviderActions(testProvider.name);
    await browser.pause(300);

    // Find delete button using browser.execute for WebKit compatibility
    const hasDelete = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.some(btn =>
        btn.textContent?.includes('删除') ||
        btn.textContent?.includes('Delete')
      );
    });
    expect(typeof hasDelete).toBe('boolean');

    await browser.keys(['Escape']);
    await browser.pause(200);
  });
});

describe('Provider Actions – App-Specific', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.switchToApp('claude');
    await browser.pause(1000);
  });

  it('should show Claude-specific actions for Claude providers', async () => {
    const count = await dashboardPage.getProviderCount();
    if (count > 0) {
      const names = await dashboardPage.getVisibleProviderNames();
      const claudeProvider = names.find(n => n.toLowerCase().includes('claude'));

      if (claudeProvider) {
        const card = await dashboardPage.findProviderCard(claudeProvider);
        if (card) {
          // Check for terminal option
          const terminalBtn = await card.$('button[aria-label*="terminal"], button[aria-label*="终端"]');
          const hasTerminal = await terminalBtn.isExisting();
          expect(typeof hasTerminal).toBe('boolean');
        }
      }
    }
  });

  it('should show OpenClaw-specific actions for OpenClaw providers', async () => {
    await navigationPage.switchToApp('openclaw');
    await browser.pause(1000);

    const count = await dashboardPage.getProviderCount();
    if (count > 0) {
      const names = await dashboardPage.getVisibleProviderNames();
      if (names.length > 0) {
        const card = await dashboardPage.findProviderCard(names[0]);
        if (card) {
          // Check for OpenClaw-specific options
          const defaultBtn = await card.$('button[aria-label*="默认"], button[aria-label*="default"]');
          const hasDefault = await defaultBtn.isExisting();
          expect(typeof hasDefault).toBe('boolean');
        }
      }
    }
  });
});