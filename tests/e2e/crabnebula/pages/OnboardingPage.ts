/**
 * OnboardingPage - Page object for first launch/onboarding flow
 *
 * Handles:
 * - Welcome screen
 * - App selection
 * - Initial provider setup
 * - Onboarding completion
 */

/// <reference types="@wdio/globals/types" />

import { CrabNebulaBasePage } from './CrabNebulaBasePage';

export class OnboardingPage extends CrabNebulaBasePage {
  /**
   * Check if welcome screen is displayed
   */
  async isWelcomeScreenDisplayed(): Promise<boolean> {
    const welcomeEl = await $('[data-testid="welcome-screen"]');
    return welcomeEl.isExisting();
  }

  /**
   * Get available app selection buttons
   */
  async getAppSelectionButtons(): Promise<string[]> {
    const buttons = await $$('[data-testid="app-selection-btn"]');
    const names: string[] = [];
    for (const btn of buttons) {
      const text = await btn.getText();
      names.push(text.trim());
    }
    return names;
  }

  /**
   * Select an app by name
   */
  async selectApp(appName: string): Promise<boolean> {
    const buttons = await $$('[data-testid="app-selection-btn"]');
    for (const btn of buttons) {
      const text = await btn.getText();
      if (text.toLowerCase().includes(appName.toLowerCase())) {
        await btn.click();
        await browser.pause(300);
        return true;
      }
    }
    return false;
  }

  /**
   * Get highlighted/recommended app
   */
  async getRecommendedApp(): Promise<string | null> {
    const highlighted = await $('[data-testid="app-selection-btn"][data-highlighted="true"]');
    if (await highlighted.isExisting()) {
      return highlighted.getText();
    }
    return null;
  }

  /**
   * Check if provider setup form is displayed
   */
  async isProviderSetupFormDisplayed(): Promise<boolean> {
    const form = await $('[data-testid="provider-setup-form"]');
    return form.isExisting();
  }

  /**
   * Check if onboarding is complete
   */
  async isOnboardingComplete(): Promise<boolean> {
    const complete = await $('[data-testid="onboarding-complete"]');
    return complete.isExisting();
  }

  /**
   * Complete onboarding with a test provider
   */
  async completeWithTestProvider(name: string, apiKey: string): Promise<void> {
    await this.waitForReactReady();

    // Select first available app if welcome screen shown
    if (await this.isWelcomeScreenDisplayed()) {
      const apps = await this.getAppSelectionButtons();
      if (apps.length > 0) {
        await this.selectApp(apps[0]);
        await browser.pause(500);
      }
    }

    // Fill provider form if shown
    if (await this.isProviderSetupFormDisplayed()) {
      const nameInput = await $('input[name*="name"], input[placeholder*="Name"]');
      if (await nameInput.isExisting()) {
        await nameInput.setValue(name);
      }

      const keyInput = await $('input[name*="apiKey"], input[placeholder*="API"]');
      if (await keyInput.isExisting()) {
        await keyInput.setValue(apiKey);
      }

      // Click save/create using WebKit2GTK-compatible method
      const saveClicked = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        const saveBtn = buttons.find(b =>
          b.type === 'submit' ||
          b.textContent?.includes('Save') ||
          b.textContent?.includes('保存') ||
          b.textContent?.includes('Create') ||
          b.textContent?.includes('创建')
        );
        if (saveBtn) {
          (saveBtn as HTMLElement).click();
          return true;
        }
        return false;
      });

      if (saveClicked) {
        await browser.pause(1000);
      }
    }
  }
}

export const onboardingPage = new OnboardingPage();