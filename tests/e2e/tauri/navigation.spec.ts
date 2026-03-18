/// <reference types="@wdio/globals/types" />
/**
 * Navigation E2E Tests
 *
 * Tests app navigation between sections,
 * verifying routes and sidebar behavior.
 */

import { navigationPage } from './pages/NavigationPage.ts';
import { dashboardPage } from './pages/DashboardPage.ts';
import { settingsPage } from './pages/SettingsPage.ts';

describe('App Navigation', () => {
  describe('Section Navigation', () => {
    it('should navigate to Dashboard', async () => {
      await navigationPage.navigateToSection('Dashboard');
      const hasDashboard = await dashboardPage.hasHeading('供应商') ||
        await dashboardPage.hasHeading('Provider') ||
        await dashboardPage.hasHeading('Dashboard');
      expect(hasDashboard).toBe(true);
    });

    it('should navigate to Settings', async () => {
      await navigationPage.navigateToSection('Settings');
      const hasSettings = await settingsPage.hasHeading('设置') ||
        await settingsPage.hasHeading('Settings');
      expect(hasSettings).toBe(true);
    });

    it('should maintain navigation state', async () => {
      // Navigate back to Dashboard
      await navigationPage.navigateToSection('Dashboard');
      await browser.pause(500);
      // Should still be on Dashboard
      const stillDashboard = await dashboardPage.hasHeading('供应商') ||
        await dashboardPage.hasHeading('Provider') ||
        await dashboardPage.hasHeading('Dashboard');
      expect(stillDashboard).toBe(true);
    });
  });

  describe('Sidebar Behavior', () => {
    it('should have navigation sidebar', async () => {
      const sidebarVisible = await navigationPage.isSidebarVisible();
      expect(sidebarVisible).toBe(true);
    });

    it('should list available sections', async () => {
      const items = await navigationPage.getNavigationItems();
      expect(items.length).toBeGreaterThan(0);
    });
  });
});
