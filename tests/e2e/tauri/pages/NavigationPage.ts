/**
 * NavigationPage - Page object for app navigation
 *
 * Handles:
 * - App switching (Claude, Codex, Gemini, OpenCode, OpenClaw)
 * - View navigation (Providers, Sessions, Settings)
 * - Sidebar interactions
 * - Keyboard shortcuts
 */

import { TauriBasePage } from './TauriBasePage.ts';

export type AppSection = 'Dashboard' | 'Settings' | 'Sessions' | 'MCP' | 'Proxy';
export type AppType = 'claude' | 'codex' | 'gemini' | 'opencode' | 'openclaw';
export type ViewType = 'providers' | 'sessions' | 'settings' | 'prompts' | 'skills' | 'mcp' | 'agents' | 'universal';

// App display names for finding elements
const APP_DISPLAY_NAMES: Record<AppType, string[]> = {
  claude: ['Claude', 'claude'],
  codex: ['Codex', 'codex', 'OpenAI'],
  gemini: ['Gemini', 'gemini'],
  opencode: ['OpenCode', 'opencode'],
  openclaw: ['OpenClaw', 'openclaw'],
};

export class NavigationPage extends TauriBasePage {
  /**
   * Navigate to a section
   */
  async navigateToSection(section: AppSection): Promise<void> {
    await this.navigateTo(section);
    await this.waitForReactReady();
  }

  /**
   * Switch to a specific app (Claude, Codex, Gemini, OpenCode, OpenClaw)
   */
  async switchToApp(app: AppType): Promise<void> {
    await this.waitForReactReady();

    // Find app button by text content
    const appNames = APP_DISPLAY_NAMES[app];
    const clicked = await browser.execute((names) => {
      const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
      for (const btn of buttons) {
        const text = btn.textContent?.trim() || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        for (const name of names) {
          if (text.includes(name) || ariaLabel.includes(name)) {
            (btn as HTMLElement).click();
            return true;
          }
        }
      }
      return false;
    }, appNames);

    if (clicked) {
      await browser.pause(500);
    }
  }

  /**
   * Get currently active app
   */
  async getActiveApp(): Promise<AppType | null> {
    const activeApp = await browser.execute(() => {
      // Look for active app indicator in sidebar
      const activeBtn = document.querySelector('button[data-active="true"], button[aria-current="page"]');
      if (activeBtn) {
        const text = activeBtn.textContent?.trim().toLowerCase() || '';
        if (text.includes('claude')) return 'claude';
        if (text.includes('codex') || text.includes('openai')) return 'codex';
        if (text.includes('gemini')) return 'gemini';
        if (text.includes('opencode')) return 'opencode';
        if (text.includes('openclaw')) return 'openclaw';
      }

      // Check for highlighted button in sidebar
      const buttons = Array.from(document.querySelectorAll('button'));
      for (const btn of buttons) {
        const classes = btn.className;
        if (classes.includes('bg-primary') || classes.includes('active')) {
          const text = btn.textContent?.trim().toLowerCase() || '';
          if (text.includes('claude')) return 'claude';
          if (text.includes('codex') || text.includes('openai')) return 'codex';
          if (text.includes('gemini')) return 'gemini';
          if (text.includes('opencode')) return 'opencode';
          if (text.includes('openclaw')) return 'openclaw';
        }
      }

      return null;
    });

    return activeApp as AppType | null;
  }

  /**
   * Navigate to a specific view
   */
  async navigateToView(view: ViewType): Promise<void> {
    await this.waitForReactReady();

    // Map view to button text
    const viewTexts: Record<ViewType, string[]> = {
      providers: ['供应商', 'Provider', 'Dashboard'],
      sessions: ['会话', 'Session', 'History'],
      settings: ['设置', 'Settings'],
      prompts: ['提示词', 'Prompt'],
      skills: ['技能', 'Skill', 'Skills'],
      mcp: ['MCP', 'MCP Server'],
      agents: ['代理', 'Agent'],
      universal: ['Universal', '通用'],
    };

    const texts = viewTexts[view];
    const clicked = await browser.execute((searchTexts) => {
      const buttons = Array.from(document.querySelectorAll('button, [role="tab"], nav a'));
      for (const btn of buttons) {
        const text = btn.textContent?.trim() || '';
        const ariaLabel = btn.getAttribute('aria-label') || '';
        for (const search of searchTexts) {
          if (text.includes(search) || ariaLabel.includes(search)) {
            (btn as HTMLElement).click();
            return true;
          }
        }
      }
      return false;
    }, texts);

    if (clicked) {
      await browser.pause(500);
    }
  }

  /**
   * Open settings via keyboard shortcut (Cmd/Ctrl+,)
   */
  async openSettingsViaShortcut(): Promise<void> {
    const isMac = await browser.execute(() => navigator.platform.toUpperCase().includes('MAC'));
    const modifier = isMac ? 'Meta' : 'Control';

    await browser.execute((mod) => {
      const event = new KeyboardEvent('keydown', {
        key: ',',
        [mod.toLowerCase()]: true,
        bubbles: true,
      });
      document.dispatchEvent(event);
    }, modifier);

    await browser.pause(500);
  }

  /**
   * Press Escape to return to providers view
   */
  async pressEscape(): Promise<void> {
    await browser.keys(['Escape']);
    await browser.pause(300);
  }

  /**
   * Get current active section
   */
  async getActiveSection(): Promise<string | null> {
    const activeNav = await $('[aria-current="page"], .active, [data-active="true"]');
    if (await activeNav.isExisting()) {
      return activeNav.getText();
    }
    return null;
  }

  /**
   * Check if sidebar is visible
   */
  async isSidebarVisible(): Promise<boolean> {
    const sidebar = await $('nav, aside, [role="navigation"], [data-testid="sidebar"]');
    return sidebar.isExisting();
  }

  /**
   * Get all available navigation items
   */
  async getNavigationItems(): Promise<string[]> {
    const navItems = await $$('nav button, aside button, [role="navigation"] button');
    const items: string[] = [];
    for (const item of navItems) {
      const text = await item.getText();
      if (text.trim()) {
        items.push(text.trim());
      }
    }
    return items;
  }

  /**
   * Get all app buttons (for checking installed/disabled status)
   */
  async getAppButtons(): Promise<{ app: string; disabled: boolean; hasStatus: boolean }[]> {
    const apps = await browser.execute(() => {
      const buttons = Array.from(document.querySelectorAll('button'));
      const appNames = ['Claude', 'Codex', 'Gemini', 'OpenCode', 'OpenClaw'];
      const results: { app: string; disabled: boolean; hasStatus: boolean }[] = [];

      for (const name of appNames) {
        const btn = buttons.find(b => b.textContent?.includes(name));
        if (btn) {
          results.push({
            app: name,
            disabled: btn.disabled,
            hasStatus: btn.querySelector('[class*="status"]') !== null ||
                      btn.querySelector('[data-status]') !== null,
          });
        }
      }

      return results;
    });

    return apps;
  }

  /**
   * Check if an app is installed (not disabled)
   */
  async isAppInstalled(app: AppType): Promise<boolean> {
    const apps = await this.getAppButtons();
    const appInfo = apps.find(a => a.app.toLowerCase() === app);
    return appInfo ? !appInfo.disabled : false;
  }

  /**
   * Open mobile sidebar (hamburger menu)
   */
  async openMobileSidebar(): Promise<void> {
    const hamburger = await $('button[aria-label*="menu"], button[aria-label*="Menu"], [data-testid="mobile-menu"]');
    if (await hamburger.isExisting()) {
      await hamburger.click();
      await browser.pause(300);
    }
  }

  /**
   * Close mobile sidebar
   */
  async closeMobileSidebar(): Promise<void> {
    const closeBtn = await $('button[aria-label*="close"], button[aria-label*="Close"]');
    if (await closeBtn.isExisting()) {
      await closeBtn.click();
      await browser.pause(300);
    } else {
      // Click outside to close
      await browser.execute(() => {
        const overlay = document.querySelector('.fixed.inset-0.bg-black\\/50');
        if (overlay) {
          (overlay as HTMLElement).click();
        }
      });
      await browser.pause(300);
    }
  }

  /**
   * Go back to previous section
   */
  async goBack(): Promise<void> {
    const backButton = await $('button[aria-label*="返回"], button[aria-label*="Back"]');
    if (await backButton.isExisting()) {
      await backButton.click();
      await browser.pause(300);
    }
  }

  /**
   * Check if current page has specific heading
   */
  async hasHeading(text: string): Promise<boolean> {
    const heading = await $(`h1*="${text}", h2*="${text}", h3*="${text}"`);
    return heading.isExisting();
  }

  /**
   * Get current view from localStorage
   */
  async getCurrentView(): Promise<string | null> {
    return browser.execute(() => {
      return localStorage.getItem('haipee-last-view');
    });
  }

  /**
   * Wait for page transition
   */
  async waitForPageTransition(timeout = 3000): Promise<void> {
    await browser.pause(timeout);
    await this.waitForLoadingComplete();
  }
}

export const navigationPage = new NavigationPage();
