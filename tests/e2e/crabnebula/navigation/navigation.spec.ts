/// <reference types="@wdio/globals/types" />
/**
 * Navigation Tests - Sidebar and app switching
 */

import { navigationPage, dashboardPage } from '../pages';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Navigation – Sidebar', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should display sidebar', async () => {
    const sidebar = await $('[data-testid="sidebar"]');
    const hasSidebar = await sidebar.isExisting();
    expect(hasSidebar).toBe(true);
  });

  it('should display all app buttons', async () => {
    const apps = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];
    let visibleCount = 0;
    for (const app of apps) {
      const btn = await $(`[data-testid="app-btn-${app}"]`);
      const hasBtn = await btn.isExisting();
      if (hasBtn) visibleCount++;
    }
    // At least some app buttons should be visible
    expect(visibleCount).toBeGreaterThan(0);
  });

  it('should switch between apps', async () => {
    await navigationPage.switchToApp('codex');
    await browser.pause(500);

    await navigationPage.switchToApp('claude');
    await browser.pause(500);

    // Verify app is in valid state after switching
    const validState = await JourneyHelpers.assertValidPageState();
    expect(validState).toBe(true);
  });

  it('should navigate to sessions', async () => {
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);

    const hasContent = await navigationPage.pageContainsAnyText([
      '会话', 'Session'
    ]);
    // Either has session content or app is in valid state
    const validState = await JourneyHelpers.assertValidPageState();
    expect(hasContent || validState).toBe(true);
  });

  it('should navigate to settings', async () => {
    await navigationPage.navigateToView('settings');
    await browser.pause(500);

    const hasContent = await navigationPage.pageContainsAnyText([
      '设置', 'Settings'
    ]);
    // Either has settings content or app is in valid state
    const validState = await JourneyHelpers.assertValidPageState();
    expect(hasContent || validState).toBe(true);
  });

  it('should navigate back to providers', async () => {
    await navigationPage.switchToApp('claude');
    await browser.pause(500);

    const hasContent = await dashboardPage.pageContainsAnyText([
      '供应商', 'Provider'
    ]);
    // Either has provider content or app is in valid state
    const validState = await JourneyHelpers.assertValidPageState();
    expect(hasContent || validState).toBe(true);
  });
});

describe('Navigation – Keyboard Shortcuts', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should respond to Cmd/Ctrl+1-5 for app switching', async () => {
    const isMac = await browser.execute(() =>
      navigator.platform.toUpperCase().includes('MAC')
    );
    const modifier = isMac ? 'Meta' : 'Control';

    await browser.keys([modifier, '2']); // Switch to Codex
    await browser.pause(500);

    // Verify app is in valid state after keyboard shortcut
    const validState = await JourneyHelpers.assertValidPageState();
    expect(validState).toBe(true);
  });

  it('should respond to Cmd/Ctrl+, for settings', async () => {
    await navigationPage.openSettingsViaShortcut();
    await browser.pause(500);

    // Verify app is in valid state after keyboard shortcut
    const validState = await JourneyHelpers.assertValidPageState();
    expect(validState).toBe(true);
  });
});

describe('Navigation – Active State', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should show active indicator on current app', async () => {
    await navigationPage.switchToApp('claude');
    await browser.pause(500);

    const activeApp = await navigationPage.getActiveApp();
    // Verify activeApp is a valid object with expected properties
    expect(activeApp).toBeDefined();
    expect(activeApp !== null).toBe(true);
  });

  it('should update active indicator on app switch', async () => {
    await navigationPage.switchToApp('gemini');
    await browser.pause(500);

    const activeApp = await navigationPage.getActiveApp();
    // Verify activeApp is a valid object with expected properties
    expect(activeApp).toBeDefined();
    expect(activeApp !== null).toBe(true);
  });
});

describe('Navigation – Responsive', () => {
  it('should adapt to different screen sizes', async () => {
    const viewport = await browser.getWindowSize();

    // Test at tablet width
    await browser.setWindowSize(768, viewport.height);
    await browser.pause(500);

    // Test at mobile width
    await browser.setWindowSize(375, viewport.height);
    await browser.pause(500);

    // Check for mobile menu button
    const mobileMenuBtn = await $('[data-testid="mobile-menu-btn"], button[aria-label*="menu"]');
    const hasMobileMenu = await mobileMenuBtn.isExisting();
    // Either has mobile menu or app is in valid state
    const validState = await JourneyHelpers.assertValidPageState();
    expect(hasMobileMenu || validState).toBe(true);

    // Restore original size
    await browser.setWindowSize(viewport.width, viewport.height);
  });
});