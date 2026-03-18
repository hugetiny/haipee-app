/**
 * NavigationPage - Page object for app navigation
 */

import { TauriBasePage } from './TauriBasePage.ts';

export type AppSection = 'Dashboard' | 'Settings' | 'Sessions' | 'MCP' | 'Proxy';

export class NavigationPage extends TauriBasePage {
  /**
   * Navigate to a section
   */
  async navigateToSection(section: AppSection): Promise<void> {
    await this.navigateTo(section);
    await this.waitForReactReady();
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
   * Wait for page transition
   */
  async waitForPageTransition(timeout = 3000): Promise<void> {
    await browser.pause(timeout);
    await this.waitForLoadingComplete();
  }
}

export const navigationPage = new NavigationPage();
