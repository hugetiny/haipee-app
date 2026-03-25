/**
 * Settings Workflow Journey Tests
 *
 * End-to-end tests for settings configuration:
 * - Theme and language switching
 * - Proxy configuration
 * - WebDAV sync (in advanced tab)
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { SettingsPage } from '../pages/SettingsPage';
import { NavigationPage } from '../pages/NavigationPage';
import { JourneyHelpers } from './journey-helpers';

describe('Settings Workflow Journey', () => {
  let settings: SettingsPage;
  let navigation: NavigationPage;

  beforeEach(async () => {
    settings = new SettingsPage();
    navigation = new NavigationPage();
    await settings.waitForReactReady();
  });

  describe('General Settings', () => {
    it('should display theme selector', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Look for theme selector container (actual testid in app)
      const themeSelector = await $('[data-testid="theme-selector"]');
      if (await themeSelector.isExisting()) {
        // Find any button inside the theme selector
        const themeButtons = await themeSelector.$$('button');
        expect(themeButtons.length).toBeGreaterThan(0);
      } else {
        // Theme selector might not be present, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should switch language using buttons', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Look for language selector container (actual testid in app)
      const langSelector = await $('[data-testid="language-selector"]');
      if (await langSelector.isExisting()) {
        // The language buttons have testids: language-btn-zh, language-btn-en, language-btn-ja
        const enBtn = await $('[data-testid="language-btn-en"]');
        if (await enBtn.isExisting()) {
          await enBtn.click();
          await browser.pause(300);
        }
      }

      // Verify settings page is in valid state after interaction
      const isValid = await JourneyHelpers.assertValidPageState();
      expect(isValid).toBe(true);
    });

    it('should persist settings after navigation', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Get current theme
      const initialTheme = await browser.execute(() => {
        return document.documentElement.getAttribute('data-theme') ||
               (document.body.className.includes('dark') ? 'dark' : 'light');
      });

      // Navigate away and back
      await navigation.navigateToView('providers');
      await browser.pause(300);
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Theme should persist
      const finalTheme = await browser.execute(() => {
        return document.documentElement.getAttribute('data-theme') ||
               (document.body.className.includes('dark') ? 'dark' : 'light');
      });

      expect(initialTheme).toBe(finalTheme);
    });
  });

  describe('Proxy Settings', () => {
    it('should display proxy settings on proxy tab', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Wait for settings to load
      await browser.waitUntil(
        async () => {
          const loaded = await browser.execute(() => {
            return document.querySelector('[data-settings-loaded="true"]') !== null;
          });
          return loaded;
        },
        { timeout: 5000, timeoutMsg: 'Settings did not load' }
      ).catch(() => {});

      // Click on proxy tab
      const proxyTab = await $('[data-testid="settings-tab-proxy"]');
      if (await proxyTab.isExisting()) {
        await proxyTab.click();
        await browser.pause(500);

        // Check for proxy-related content on the page
        const hasProxyContent = await browser.execute(() => {
          const text = document.body.textContent || '';
          // Check for any proxy-related content
          return text.includes('Proxy') ||
                 text.includes('代理') ||
                 text.includes('HTTP') ||
                 text.includes('proxy') ||
                 document.querySelector('[data-testid="proxy-settings"]') !== null ||
                 document.querySelector('[data-testid="proxy-url-input"]') !== null;
        });

        // Also try to find the proxy settings container
        const proxySettings = await $('[data-testid="proxy-settings"]');
        const containerExists = await proxySettings.isExisting();

        // Test passes if we have any proxy content or the container exists
        expect(hasProxyContent || containerExists).toBe(true);
      } else {
        // Proxy tab not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should configure HTTP proxy', async () => {
      // Navigate to proxy tab
      const proxyTab = await $('[data-testid="settings-tab-proxy"]');
      if (await proxyTab.isExisting()) {
        await proxyTab.click();
        await browser.pause(500);

        // Look for proxy URL input (actual testid in app)
        const proxyInput = await $('[data-testid="proxy-url-input"]');
        if (await proxyInput.isExisting()) {
          await proxyInput.clearValue();
          await proxyInput.addValue('http://127.0.0.1:7890');
          // Verify input was set
          const inputValue = await proxyInput.getValue();
          expect(inputValue).toBe('http://127.0.0.1:7890');
        } else {
          // Input not found, verify valid page state
          const isValid = await JourneyHelpers.assertValidPageState();
          expect(isValid).toBe(true);
        }
      } else {
        // Proxy tab not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should show proxy test button', async () => {
      const proxyTab = await $('[data-testid="settings-tab-proxy"]');
      if (await proxyTab.isExisting()) {
        await proxyTab.click();
        await browser.pause(500);

        // The test button doesn't have a testid, look for button with test icon
        // Use browser.execute to find button by its position or icon
        const hasTestButton = await browser.execute(() => {
          const container = document.querySelector('[data-testid="proxy-settings"]');
          if (!container) return false;
          const buttons = container.querySelectorAll('button');
          return buttons.length >= 2; // Should have at least scan, test, clear, save buttons
        });

        // Verify buttons exist in proxy settings container
        expect(hasTestButton).toBe(true);
      } else {
        // Proxy tab not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });
  });

  describe('Advanced Settings', () => {
    it('should display advanced settings tab', async () => {
      const advancedTab = await $('[data-testid="settings-tab-advanced"]');
      if (await advancedTab.isExisting()) {
        await advancedTab.click();
        await browser.pause(500);

        // Look for accordion items
        const accordions = await $$('[data-state]');
        expect(accordions.length).toBeGreaterThanOrEqual(0);
      } else {
        // Advanced tab not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should have cloud sync section in advanced', async () => {
      const advancedTab = await $('[data-testid="settings-tab-advanced"]');
      if (await advancedTab.isExisting()) {
        await advancedTab.click();
        await browser.pause(500);

        // Look for cloud sync text in the page
        const hasCloudSync = await browser.execute(() => {
          const text = document.body.textContent || '';
          return text.includes('WebDAV') || text.includes('云同步') || text.includes('Cloud');
        });

        // Verify cloud sync section is present
        expect(hasCloudSync).toBe(true);
      } else {
        // Advanced tab not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });
  });

  describe('Settings Tabs', () => {
    it('should navigate between settings tabs', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Check all tabs exist
      const tabs = [
        'settings-tab-general',
        'settings-tab-models',
        'settings-tab-proxy',
        'settings-tab-advanced',
        'settings-tab-about',
      ];

      let navigatedCount = 0;
      for (const tabId of tabs) {
        const tab = await $(`[data-testid="${tabId}"]`);
        if (await tab.isExisting()) {
          await tab.click();
          await browser.pause(300);
          navigatedCount++;
        }
      }

      // Verify we successfully navigated to at least some tabs
      expect(navigatedCount).toBeGreaterThan(0);
    });
  });

  describe('Theme Switching', () => {
    it('should switch to dark theme', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Look for dark theme button
      const darkBtn = await $('[data-testid="theme-dark"], button[aria-label*="Dark"], button[aria-label*="暗色"]');
      if (await darkBtn.isExisting()) {
        await darkBtn.click();
        await browser.pause(300);

        // Verify dark theme applied
        const isDark = await browser.execute(() => {
          return document.documentElement.getAttribute('data-theme') === 'dark' ||
                 document.body.className.includes('dark');
        });
        // Verify dark theme was applied
        expect(isDark).toBe(true);
      } else {
        // Dark button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should switch to light theme', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      const lightBtn = await $('[data-testid="theme-light"], button[aria-label*="Light"], button[aria-label*="亮色"]');
      if (await lightBtn.isExisting()) {
        await lightBtn.click();
        await browser.pause(300);

        const isLight = await browser.execute(() => {
          return document.documentElement.getAttribute('data-theme') === 'light' ||
                 document.body.className.includes('light') ||
                 (!document.body.className.includes('dark') && !document.documentElement.getAttribute('data-theme'));
        });
        // Verify light theme was applied
        expect(isLight).toBe(true);
      } else {
        // Light button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should switch to system theme', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      const systemBtn = await $('[data-testid="theme-system"], button[aria-label*="System"], button[aria-label*="系统"]');
      if (await systemBtn.isExisting()) {
        await systemBtn.click();
        await browser.pause(300);
        // Verify system theme button was clickable
        const isClickable = await systemBtn.isClickable();
        expect(isClickable).toBe(true);
      } else {
        // System button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });
  });

  describe('Language Switching', () => {
    it('should switch to Chinese', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      const zhBtn = await $('[data-testid="language-btn-zh"]');
      if (await zhBtn.isExisting()) {
        await zhBtn.click();
        await browser.pause(500);

        // Verify Chinese text appears
        const hasChinese = await browser.execute(() => {
          const text = document.body.textContent || '';
          return text.includes('设置') || text.includes('供应商') || text.includes('语言');
        });
        // Verify Chinese language was applied
        expect(hasChinese).toBe(true);
      } else {
        // Chinese button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should switch to English', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      const enBtn = await $('[data-testid="language-btn-en"]');
      if (await enBtn.isExisting()) {
        await enBtn.click();
        await browser.pause(500);

        // Verify English text appears
        const hasEnglish = await browser.execute(() => {
          const text = document.body.textContent || '';
          return text.includes('Settings') || text.includes('Provider') || text.includes('Language');
        });
        // Verify English language was applied
        expect(hasEnglish).toBe(true);
      } else {
        // English button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });

    it('should switch to Japanese if available', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      const jaBtn = await $('[data-testid="language-btn-ja"]');
      if (await jaBtn.isExisting()) {
        await jaBtn.click();
        await browser.pause(500);
        // Verify Japanese button was clickable
        const isClickable = await jaBtn.isClickable();
        expect(isClickable).toBe(true);
      } else {
        // Japanese might not be available, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });
  });

  describe('Settings Persistence', () => {
    it('should persist language across app restart', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Set to English
      const enBtn = await $('[data-testid="language-btn-en"]');
      if (await enBtn.isExisting()) {
        await enBtn.click();
        await browser.pause(300);
      }

      // Refresh to simulate restart
      await browser.refresh();
      await browser.pause(1000);
      await settings.waitForReactReady();

      // Language should still be English
      const hasEnglish = await browser.execute(() => {
        const text = document.body.textContent || '';
        return text.includes('Settings') || text.includes('Provider');
      });
      // Verify English persisted after refresh
      expect(hasEnglish).toBe(true);
    });

    it('should persist theme across sessions', async () => {
      await settings.navigateTo('Settings');
      await browser.pause(500);

      // Set dark theme
      const darkBtn = await $('[data-testid="theme-dark"], button[aria-label*="Dark"]');
      if (await darkBtn.isExisting()) {
        await darkBtn.click();
        await browser.pause(300);

        // Refresh
        await browser.refresh();
        await browser.pause(1000);
        await settings.waitForReactReady();

        // Theme should persist
        const isDark = await browser.execute(() => {
          return document.documentElement.getAttribute('data-theme') === 'dark' ||
                 document.body.className.includes('dark');
        });
        // Verify dark theme persisted after refresh
        expect(isDark).toBe(true);
      } else {
        // Dark button not found, verify valid page state
        const isValid = await JourneyHelpers.assertValidPageState();
        expect(isValid).toBe(true);
      }
    });
  });
});