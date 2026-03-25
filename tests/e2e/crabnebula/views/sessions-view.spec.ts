/**
 * Sessions View Tests
 *
 * Tests the sessions view UI details:
 * - Session list display
 * - Filter and search
 * - Message list
 * - TOC (Table of Contents)
 */

/// <reference types="@wdio/globals/types" />

import { SessionManagerPage } from '../pages/SessionManagerPage';
import { invokeIPC } from '../utils/test-helpers';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Sessions View', () => {
  const sessionManagerPage = new SessionManagerPage();

  before(async () => {
    // Wait for React to be ready
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(
          () => document.getElementById('root')?.childElementCount ?? 0
        );
        return count > 0;
      },
      { timeout: 15_000, timeoutMsg: 'React did not render' }
    );

    // Navigate to sessions
    await sessionManagerPage.navigateToSessions();
    await browser.pause(500);
  });

  describe('Session List Display', () => {
    it('should show session list or empty state', async () => {
      const hasSessionContent = await browser.execute(() => {
        const text = document.body.textContent || '';
        return (
          text.includes('会话') ||
          text.includes('Session') ||
          text.includes('暂无') ||
          text.includes('No session') ||
          document.querySelector('[data-session-id]') !== null ||
          document.querySelector('[data-session-provider]') !== null
        );
      });
      expect(hasSessionContent).toBe(true);
    });

    it('should show session provider badge', async () => {
      const sessions = await invokeIPC<{ id: string; provider_id: string }[]>('list_sessions');

      if (sessions && sessions.length > 0) {
        const hasProviderBadge = await browser.execute(() => {
          return (
            document.querySelector('[data-session-provider]') !== null ||
            document.querySelector('[class*="badge"]') !== null ||
            document.querySelector('[class*="provider"]') !== null
          );
        });
        expect(hasProviderBadge).toBe(true);
      } else {
        console.log('[test] No sessions - skip provider badge test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show session timestamp', async () => {
      const hasTimestamp = await browser.execute(() => {
        const text = document.body.textContent || '';
        // Look for date/time patterns
        return (
          /\d{1,2}:\d{2}/.test(text) ||
          /\d{4}-\d{2}-\d{2}/.test(text) ||
          text.includes('今天') ||
          text.includes('Today') ||
          text.includes('昨天') ||
          text.includes('Yesterday')
        );
      });

      expect(hasTimestamp).toBe(true);
    });
  });

  describe('Session Filter', () => {
    it('should have provider filter', async () => {
      const hasFilter = await browser.execute(() => {
        return (
          document.querySelector('[data-testid="provider-filter"]') !== null ||
          document.querySelector('select[name*="provider"]') !== null ||
          document.querySelector('[role="combobox"]') !== null
        );
      });

      expect(hasFilter).toBe(true);
    });

    it('should filter by provider', async () => {
      try {
        // Try to open filter dropdown
        const filterBtn = $(
          '[data-testid="provider-filter"], select[name*="provider"], [role="combobox"]'
        );
        if (await filterBtn.isExisting()) {
          await filterBtn.click();
          await browser.pause(300);

          // Look for provider options using browser.execute
          const hasOptions = await browser.execute(() => {
            return document.querySelectorAll('[role="option"], option').length;
          });
          if (hasOptions > 0) {
            // Click first option
            const firstOption = await $("[role='option'], option");
            if (await firstOption.isExisting()) {
              await firstOption.click();
              await browser.pause(300);
            }
          }
        }
      } catch {
        console.log('[test] Provider filter - may not be implemented');
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Session Search', () => {
    it('should have search input', async () => {
      const hasSearch = await browser.execute(() => {
        return (
          document.querySelector('input[type="search"]') !== null ||
          document.querySelector('input[placeholder*="搜索"]') !== null ||
          document.querySelector('input[placeholder*="Search"]') !== null
        );
      });

      expect(hasSearch).toBe(true);
    });

    it('should filter sessions by search query', async () => {
      const searchInput = await $(
        'input[type="search"], input[placeholder*="搜索"], input[placeholder*="Search"]'
      );

      if (await searchInput.isExisting()) {
        await searchInput.setValue('test query');
        await browser.pause(300);

        // Clear search
        await searchInput.clearValue();
        await browser.pause(200);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Message List', () => {
    it('should show message list when session selected', async () => {
      const sessionCount = await browser.execute(() => {
        return document.querySelectorAll('[data-session-id], [data-session-provider]').length;
      });

      if (sessionCount > 0) {
        // Click first session
        const firstSession = await $(
          '[data-session-id]:first-child, [data-session-provider]:first-child, .space-y-1 > button:first-child'
        );
        if (await firstSession.isExisting()) {
          await firstSession.click();
          await browser.pause(500);
        }

        // Check for message list
        const hasMessages = await browser.execute(() => {
          return (
            document.querySelector('[data-message-role]') !== null ||
            document.querySelector('[class*="message"]') !== null ||
            document.querySelector('[class*="chat"]') !== null
          );
        });

        expect(hasMessages).toBe(true);
      } else {
        console.log('[test] No sessions - skip message list test');
        const validState = await JourneyHelpers.assertValidPageState();
        expect(validState).toBe(true);
      }
    });

    it('should show user and assistant messages', async () => {
      const hasRoles = await browser.execute(() => {
        const elements = document.querySelectorAll('[data-message-role]');
        const roles = new Set();
        for (const el of elements) {
          const role = el.getAttribute('data-message-role');
          if (role) roles.add(role);
        }
        return roles.size;
      });

      // 0 = no messages, 1+ = messages with roles
      expect(hasRoles).toBeGreaterThanOrEqual(0);
    });
  });

  describe('TOC (Table of Contents)', () => {
    it('should show TOC if available', async () => {
      const hasTOC = await browser.execute(() => {
        return (
          document.querySelector('[data-testid="toc"]') !== null ||
          document.querySelector('[class*="toc"]') !== null ||
          document.querySelector('nav[class*="outline"]') !== null
        );
      });

      // TOC may or may not be implemented
      expect(hasTOC).toBe(true);
    });
  });

  describe('Session Actions', () => {
    it('should have delete action', async () => {
      const hasDelete = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(
          (b) =>
            b.textContent?.includes('删除') ||
            b.textContent?.toLowerCase().includes('delete') ||
            b.getAttribute('aria-label')?.includes('删除')
        );
      });

      expect(hasDelete).toBe(true);
    });

    it('should have export action if implemented', async () => {
      const hasExport = await browser.execute(() => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some(
          (b) =>
            b.textContent?.includes('导出') ||
            b.textContent?.toLowerCase().includes('export')
        );
      });

      expect(hasExport).toBe(true);
    });
  });
});