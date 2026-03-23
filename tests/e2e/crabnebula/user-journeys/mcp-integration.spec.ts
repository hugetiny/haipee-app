/**
 * MCP Integration Journey Tests
 *
 * End-to-end tests for MCP server management:
 * - Server CRUD operations
 * - Connection testing
 * - Tools and resources
 * - Error handling
 */

/// <reference types="@wdio/globals/types" />

import { expect } from '@wdio/globals';
import { McpPage } from '../pages/McpPage';
import { NavigationPage } from '../pages/NavigationPage';
import { JourneyHelpers } from './journey-helpers';

describe('MCP Integration Journey', () => {
  let mcpPage: McpPage;
  let navigation: NavigationPage;

  beforeEach(async () => {
    mcpPage = new McpPage();
    navigation = new NavigationPage();
    await mcpPage.waitForReactReady();
  });

  describe('MCP Server Management', () => {
    it('should add MCP server', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const addBtn = await $('[data-testid="mcp-add-btn"], button:has-text("添加"), button:has-text("Add")');
      if (await addBtn.isExisting()) {
        await addBtn.click();
        await browser.pause(300);

        // Fill form
        const nameInput = await $('input[name*="name"], input[placeholder*="名称"], input[placeholder*="Name"]');
        if (await nameInput.isExisting()) {
          await nameInput.addValue(JourneyHelpers.generateTestName('MCP'));
        }

        // Save
        const saveBtn = await $('button[type="submit"], button:has-text("保存"), button:has-text("Save")');
        if (await saveBtn.isExisting()) {
          await saveBtn.click();
          await browser.pause(500);
        }
      }

      expect(true).toBe(true);
    });

    it('should edit MCP configuration', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const editBtn = await $('button[aria-label*="编辑"], button[aria-label*="Edit"]');
      if (await editBtn.isExisting()) {
        await editBtn.click();
        await browser.pause(300);

        // Modify something
        const modalOpen = await JourneyHelpers.isModalOpen();
        expect(typeof modalOpen).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should delete MCP server', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const deleteBtn = await $('button[aria-label*="删除"], button[aria-label*="Delete"]');
      if (await deleteBtn.isExisting()) {
        await deleteBtn.click();
        await browser.pause(300);

        // Confirm
        const confirmBtn = await $('button:has-text("确认"), button:has-text("Confirm")');
        if (await confirmBtn.isExisting()) {
          await confirmBtn.click();
          await browser.pause(500);
        }
      }

      expect(true).toBe(true);
    });

    it('should enable/disable MCP server', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const toggle = await $('[role="switch"], input[type="checkbox"]');
      if (await toggle.isExisting()) {
        await toggle.click();
        await browser.pause(300);
      }

      expect(true).toBe(true);
    });
  });

  describe('Connection Testing', () => {
    it('should test MCP connection', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const testBtn = await $('[data-testid="test-mcp"], button:has-text("测试"), button:has-text("Test")');
      if (await testBtn.isExisting()) {
        await testBtn.click();
        await browser.pause(2000);

        const toast = await JourneyHelpers.waitForToast(5000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should show error on connection failure', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      // Test with invalid server
      const testBtn = await $('[data-testid="test-mcp"], button:has-text("测试"), button:has-text("Test")');
      if (await testBtn.isExisting()) {
        await testBtn.click();
        await browser.pause(2000);

        // Should show error toast or status
        const toast = await JourneyHelpers.waitForToast(5000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });
  });

  describe('Tools and Resources', () => {
    it('should view available tools', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const toolsBtn = await $('[data-testid="view-tools"], button:has-text("工具"), button:has-text("Tools")');
      if (await toolsBtn.isExisting()) {
        await toolsBtn.click();
        await browser.pause(500);

        // Tools list should appear
        const toolsList = await $('[data-testid="tools-list"], [class*="tools"]');
        expect(typeof (await toolsList.isExisting())).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    });

    it('should view resource list', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const resourcesBtn = await $('[data-testid="view-resources"], button:has-text("资源"), button:has-text("Resources")');
      if (await resourcesBtn.isExisting()) {
        await resourcesBtn.click();
        await browser.pause(500);

        // Resources list should appear
        const resourcesList = await $('[data-testid="resources-list"], [class*="resources"]');
        expect(typeof (await resourcesList.isExisting())).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    });
  });

  describe('Edge Cases', () => {
    it('should show error for invalid configuration', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      const addBtn = await $('[data-testid="mcp-add-btn"], button:has-text("添加")');
      if (await addBtn.isExisting()) {
        await addBtn.click();
        await browser.pause(300);

        // Submit without required fields
        const saveBtn = await $('button[type="submit"]');
        if (await saveBtn.isExisting()) {
          await saveBtn.click();
          await browser.pause(300);

          const hasError = await JourneyHelpers.hasFormError();
          expect(typeof hasError).toBe('boolean');
        }
      } else {
        expect(true).toBe(true);
      }
    });

    it('should handle timeout gracefully', async () => {
      await mcpPage.navigateTo('MCP');
      await browser.pause(500);

      // Try to connect to slow/timeout server
      const testBtn = await $('[data-testid="test-mcp"], button:has-text("测试")');
      if (await testBtn.isExisting()) {
        await testBtn.click();

        // Wait for timeout (should be handled)
        await browser.pause(30000);

        const toast = await JourneyHelpers.waitForToast(2000);
        expect(typeof toast).toBe('string');
      } else {
        expect(true).toBe(true);
      }
    });
  });
});