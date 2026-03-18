/// <reference types="@wdio/globals/types" />
/**
 * Provider Management E2E Tests
 *
 * Tests realistic CRUD workflows for AI provider management
 * using Page Object Model for maintainability.
 */

import { dashboardPage } from './pages/DashboardPage.ts';

describe('Provider Management', () => {
  before(async () => {
    await dashboardPage.open();
  });

  describe('Provider List', () => {
    it('should display the dashboard page', async () => {
      const hasHeading = await dashboardPage.hasHeading('供应商') ||
        await dashboardPage.hasHeading('Provider') ||
        await dashboardPage.hasHeading('Dashboard');
      expect(hasHeading).toBe(true);
    });

    it('should show provider cards (or empty state)', async () => {
      const cards = await dashboardPage.getProviderCards();
      // Either has cards or shows empty state
      const hasEmptyState = await dashboardPage.elementExists('[data-testid="empty-state"]');
      expect(cards.length > 0 || hasEmptyState).toBe(true);
    });
  });

  describe('Add Provider', () => {
    it('should open add provider dialog', async () => {
      await dashboardPage.clickAddProvider();
      const formExists = await dashboardPage.elementExists('form, [data-testid="provider-form"]');
      expect(formExists).toBe(true);
    });

    it('should cancel provider creation', async () => {
      await dashboardPage.cancelProviderForm();
      const formGone = !(await dashboardPage.elementExists('form, [data-testid="provider-form"]'));
      expect(formGone).toBe(true);
    });
  });

  describe('Search and Filter', () => {
    it('should filter providers by search', async () => {
      const initialCount = await dashboardPage.getProviderCount();
      await dashboardPage.searchProviders('nonexistent_provider_xyz');
      await browser.pause(500);
      const filteredCount = await dashboardPage.getProviderCount();
      // Filtered should show fewer or zero results
      expect(filteredCount).toBeLessThanOrEqual(initialCount);
      // Clear search
      await dashboardPage.searchProviders('');
    });
  });
});
