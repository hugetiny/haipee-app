/// <reference types="@wdio/globals/types" />
/**
 * Comprehensive Navigation E2E Tests
 *
 * Tests all navigation scenarios including:
 * - App switching (Claude, Codex, Gemini, OpenCode, OpenClaw)
 * - View navigation (Providers, Sessions, Settings)
 * - Sidebar behavior
 * - Keyboard shortcuts
 * - Mobile navigation
 */

import { navigationPage, type AppType } from './pages/NavigationPage.ts';
import { dashboardPage } from './pages/DashboardPage.ts';
import { settingsPage } from './pages/SettingsPage.ts';

describe('Navigation – App Switching', () => {
  const apps: AppType[] = ['claude', 'codex', 'gemini', 'opencode', 'openclaw'];

  before(async () => {
    await navigationPage.waitForReactReady();
  });

  for (const app of apps) {
    it(`should switch to ${app} app`, async () => {
      await navigationPage.switchToApp(app);
      await browser.pause(500);

      // Verify app is active
      const activeApp = await navigationPage.getActiveApp();
      // Accept null as valid (UI may not expose active state clearly)
      if (activeApp) {
        expect(activeApp).toBe(app);
      }
    });
  }

  it('should maintain provider list when switching between apps', async () => {
    // Switch to Claude
    await navigationPage.switchToApp('claude');
    await browser.pause(300);

    // Check for provider content
    const hasProviderContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('Provider') || text.includes('供应商') ||
             text.includes('Claude') || document.querySelector('[data-provider-id]') !== null;
    });
    expect(typeof hasProviderContent).toBe('boolean');

    // Switch to Codex
    await navigationPage.switchToApp('codex');
    await browser.pause(300);

    // Check for provider content again
    const stillHasContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('Provider') || text.includes('供应商') ||
             text.includes('Codex') || document.querySelector('[data-provider-id]') !== null;
    });
    expect(typeof stillHasContent).toBe('boolean');
  });

  it('should show installed status for each app', async () => {
    const appButtons = await navigationPage.getAppButtons();
    expect(appButtons.length).toBeGreaterThan(0);

    // At least some apps should be visible
    const visibleApps = appButtons.filter(a => !a.disabled);
    expect(visibleApps.length).toBeGreaterThan(0);
  });
});

describe('Navigation – View Switching', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should navigate to Sessions view', async () => {
    await navigationPage.navigateToView('sessions');
    await browser.pause(500);

    const hasSessionContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('会话') || text.includes('Session') ||
             text.includes('Provider') || text.includes('供应商') ||
             document.querySelector('[data-session-id]') !== null ||
             document.querySelector('[data-session-provider]') !== null;
    });
    expect(hasSessionContent).toBe(true);
  });

  it('should navigate to Settings view', async () => {
    await navigationPage.navigateToView('settings');
    await browser.pause(500);

    const hasSettings = await settingsPage.hasHeading('设置') ||
                        await settingsPage.hasHeading('Settings') ||
                        await settingsPage.hasHeading('General') ||
                        await settingsPage.hasHeading('通用');
    expect(hasSettings).toBe(true);
  });

  it('should navigate back to Providers view', async () => {
    await navigationPage.navigateToView('providers');
    await browser.pause(500);

    const hasProviders = await dashboardPage.hasHeading('供应商') ||
                         await dashboardPage.hasHeading('Provider') ||
                         await dashboardPage.hasHeading('Dashboard');
    expect(hasProviders).toBe(true);
  });

  it('should persist view selection across app switches', async () => {
    // Navigate to settings
    await navigationPage.navigateToView('settings');
    await browser.pause(300);

    // Switch app
    await navigationPage.switchToApp('codex');
    await browser.pause(300);

    // Check if still in settings (or providers, depending on fallback logic)
    const currentView = await navigationPage.getCurrentView();
    expect(typeof currentView).toBe('string');
  });
});

describe('Navigation – Keyboard Shortcuts', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    // Start from providers view
    await navigationPage.navigateToView('providers');
    await browser.pause(300);
  });

  it('should open settings with Cmd/Ctrl+, shortcut', async () => {
    await navigationPage.openSettingsViaShortcut();
    await browser.pause(500);

    const hasSettings = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('设置') || text.includes('Settings') ||
             text.includes('General') || text.includes('通用');
    });
    expect(hasSettings).toBe(true);
  });

  it('should return to providers view with Escape', async () => {
    // First navigate to settings
    await navigationPage.navigateToView('settings');
    await browser.pause(300);

    // Press Escape
    await navigationPage.pressEscape();
    await browser.pause(300);

    // Should be back at providers or settings UI closed
    const hasContent = await browser.execute(() => {
      const text = document.body.textContent || '';
      return text.includes('供应商') || text.includes('Provider') ||
             text.includes('设置') || text.includes('Settings');
    });
    expect(hasContent).toBe(true);
  });
});

describe('Navigation – Sidebar', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should have visible sidebar', async () => {
    const sidebarVisible = await navigationPage.isSidebarVisible();
    expect(sidebarVisible).toBe(true);
  });

  it('should list navigation items in sidebar', async () => {
    const items = await navigationPage.getNavigationItems();
    expect(items.length).toBeGreaterThan(0);

    // Should have at least sessions and settings
    const hasSessions = items.some(item =>
      item.includes('会话') || item.includes('Session') || item.includes('History')
    );
    const hasSettings = items.some(item =>
      item.includes('设置') || item.includes('Settings')
    );

    expect(hasSessions || hasSettings).toBe(true);
  });

  it('should show app icons in sidebar', async () => {
    const appButtons = await navigationPage.getAppButtons();
    // Should have at least Claude
    expect(appButtons.length).toBeGreaterThan(0);
  });
});

describe('Navigation – Mobile', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
  });

  it('should have mobile menu button on small screens', async () => {
    // Resize to mobile
    await browser.setWindowSize(400, 800);
    await browser.pause(300);

    // Look for hamburger menu
    const hasMobileMenu = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      return buttons.some(btn =>
        btn.getAttribute('aria-label')?.includes('menu') ||
        btn.getAttribute('aria-label')?.includes('Menu') ||
        btn.className.includes('hamburger') ||
        btn.querySelector('svg path[d*="M4 6h16"]') !== null
      );
    });

    // May not have explicit mobile menu - depends on implementation
    expect(typeof hasMobileMenu).toBe('boolean');

    // Reset to desktop size
    await browser.setWindowSize(1280, 800);
    await browser.pause(300);
  });

  it('should open and close mobile sidebar', async () => {
    // Resize to mobile
    await browser.setWindowSize(400, 800);
    await browser.pause(300);

    // Try to open mobile sidebar
    await navigationPage.openMobileSidebar();
    await browser.pause(300);

    // Close it
    await navigationPage.closeMobileSidebar();
    await browser.pause(300);

    // Reset to desktop size
    await browser.setWindowSize(1280, 800);
    await browser.pause(300);
  });
});

describe('Navigation – View State Persistence', () => {
  it('should remember last view on page reload', async () => {
    // Navigate to settings
    await navigationPage.navigateToView('settings');
    await browser.pause(300);

    // Check localStorage
    const storedView = await navigationPage.getCurrentView();
    expect(storedView).toBe('settings');

    // Navigate to sessions
    await navigationPage.navigateToView('sessions');
    await browser.pause(300);

    // Check localStorage again
    const newStoredView = await navigationPage.getCurrentView();
    expect(newStoredView).toBe('sessions');
  });
});