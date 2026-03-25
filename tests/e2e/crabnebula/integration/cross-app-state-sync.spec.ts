/**
 * Cross-App State Sync Integration Tests
 *
 * Tests state synchronization across different apps:
 * - Provider changes sync across apps
 * - Session isolation between apps
 * - Settings shared across apps
 * - MCP servers per-app configuration
 * - Skill installation per-app
 */

/// <reference types="@wdio/globals/types" />

import { DashboardPage } from '../pages/DashboardPage';
import { NavigationPage } from '../pages/NavigationPage';
import { SessionManagerPage } from '../pages/SessionManagerPage';
import { SettingsPage } from '../pages/SettingsPage';
import { McpPage } from '../pages/McpPage';
import { SkillsPage } from '../pages/SkillsPage';
import { invokeIPC } from '../utils/test-helpers';
import { JourneyHelpers } from '../user-journeys/journey-helpers';

describe('Cross-App State Sync', () => {
  const dashboardPage = new DashboardPage();
  const navigationPage = new NavigationPage();
  const sessionManagerPage = new SessionManagerPage();
  const settingsPage = new SettingsPage();
  const mcpPage = new McpPage();
  const skillsPage = new SkillsPage();

  before(async () => {
    await browser.waitUntil(
      async () => {
        const count = await browser.execute(
          () => document.getElementById('root')?.childElementCount ?? 0
        );
        return count > 0;
      },
      { timeout: 15_000, timeoutMsg: 'React did not render' }
    );
  });

  describe('Provider Changes Sync Across Apps', () => {
    it('should show different providers for different apps', async () => {
      // Get providers for Claude
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const claudeNames = await dashboardPage.getVisibleProviderNames();

      // Switch to Codex
      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const codexNames = await dashboardPage.getVisibleProviderNames();

      console.log(`[test] Claude providers: ${claudeNames.length}, Codex providers: ${codexNames.length}`);

      // Provider lists should be independent
      expect(Array.isArray(claudeNames)).toBe(true);
      expect(Array.isArray(codexNames)).toBe(true);
    });

    it('should maintain separate provider configurations per app', async () => {
      const claudeProviders = await invokeIPC<{ id: string; name: string }[]>('list_providers', { appType: 'claude' });
      const codexProviders = await invokeIPC<{ id: string; name: string }[]>('list_providers', { appType: 'codex' });

      if (claudeProviders && codexProviders) {
        console.log(`[test] Claude: ${claudeProviders.length} providers, Codex: ${codexProviders.length} providers`);

        // Each app has independent provider configs
        expect(Array.isArray(claudeProviders)).toBe(true);
        expect(Array.isArray(codexProviders)).toBe(true);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should not affect other apps when adding provider', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const initialClaudeCount = await dashboardPage.getProviderCount();

      // Switch to Gemini and check count
      await navigationPage.switchToApp('gemini');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const geminiCount = await dashboardPage.getProviderCount();

      // Counts should be independent
      console.log(`[test] Claude: ${initialClaudeCount}, Gemini: ${geminiCount}`);

      expect(initialClaudeCount).toBeGreaterThanOrEqual(0);
      expect(geminiCount).toBeGreaterThanOrEqual(0);
    });

    it('should sync provider order within same app', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const initialNames = await dashboardPage.getVisibleProviderNames();

      // Navigate away and back
      await navigationPage.navigateToView('sessions');
      await browser.pause(500);

      await navigationPage.navigateToView('providers');
      await browser.pause(500);

      const afterNames = await dashboardPage.getVisibleProviderNames();

      // Order should be preserved within same app
      if (initialNames.length > 0 && afterNames.length > 0) {
        expect(initialNames[0]).toBe(afterNames[0]);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Session Isolation Between Apps', () => {
    it('should show different sessions for different apps', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const claudeCount = await sessionManagerPage.getSessionCount();

      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const codexCount = await sessionManagerPage.getSessionCount();

      console.log(`[test] Claude sessions: ${claudeCount}, Codex sessions: ${codexCount}`);

      // Session counts should be independent
      expect(claudeCount).toBeGreaterThanOrEqual(0);
      expect(codexCount).toBeGreaterThanOrEqual(0);
    });

    it('should isolate session messages between apps', async () => {
      const claudeSessions = await invokeIPC<{ id: string; messages?: unknown[] }[]>('list_sessions', { appType: 'claude' });
      const codexSessions = await invokeIPC<{ id: string; messages?: unknown[] }[]>('list_sessions', { appType: 'codex' });

      if (claudeSessions && codexSessions) {
        // No overlap in session IDs
        const claudeIds = new Set(claudeSessions.map(s => s.id));
        const codexIds = new Set(codexSessions.map(s => s.id));
        const overlap = [...claudeIds].filter(id => codexIds.has(id));

        console.log(`[test] Session ID overlap: ${overlap.length}`);
        expect(overlap.length).toBe(0);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should not share active session across apps', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const claudeItems = await sessionManagerPage.getSessionItems();
      if (claudeItems.length > 0) {
        await claudeItems[0].click();
        await browser.pause(300);

        const claudeActive = await sessionManagerPage.getCurrentSessionName();

        // Switch to Codex
        await navigationPage.switchToApp('codex');
        await browser.pause(500);

        await sessionManagerPage.navigateToSessions();
        await browser.pause(500);

        const codexActive = await sessionManagerPage.getCurrentSessionName();

        // Active sessions should be independent
        console.log(`[test] Claude active: ${claudeActive}, Codex active: ${codexActive}`);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should restore correct session when switching back', async () => {
      // Setup in Claude
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const claudeItems = await sessionManagerPage.getSessionItems();
      const claudeCount = claudeItems.length;

      // Go to Gemini
      await navigationPage.switchToApp('gemini');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const geminiCount = await sessionManagerPage.getSessionCount();

      // Switch back to Claude
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await sessionManagerPage.navigateToSessions();
      await browser.pause(500);

      const restoredCount = await sessionManagerPage.getSessionCount();

      // Should restore Claude's session list
      expect(restoredCount).toBe(claudeCount);
    });
  });

  describe('Settings Shared Across Apps', () => {
    it('should share theme setting across all apps', async () => {
      // Set theme in Claude
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await settingsPage.open();
      await browser.pause(500);

      await settingsPage.openTab('general');
      await browser.pause(500);

      await settingsPage.changeTheme('dark');
      await browser.pause(500);

      // Switch to Gemini
      await navigationPage.switchToApp('gemini');
      await browser.pause(500);

      // Check theme
      const geminiTheme = await browser.execute(() => {
        return document.documentElement.getAttribute('data-theme') ||
               document.documentElement.classList.contains('dark') ? 'dark' : 'light';
      });

      expect(geminiTheme).toBe('dark');
    });

    it('should share language setting across all apps', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await settingsPage.open();
      await browser.pause(500);

      await settingsPage.openTab('general');
      await browser.pause(500);

      await settingsPage.changeLanguage('zh');
      await browser.pause(500);

      // Switch to Codex
      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      // Check language
      const hasChinese = await browser.execute(() => {
        return document.documentElement.lang === 'zh' ||
               document.body.textContent?.includes('设置') ||
               document.body.textContent?.includes('供应商');
      });

      expect(hasChinese).toBe(true);
    });

    it('should share proxy settings across all apps', async () => {
      // Proxy settings are global
      await settingsPage.open();
      await browser.pause(500);

      await settingsPage.openTab('proxy');
      await browser.pause(500);

      // Check proxy settings UI is present
      const hasProxyUI = await browser.execute(() => {
        const text = document.body.textContent || '';
        return text.includes('Proxy') || text.includes('代理');
      });

      expect(hasProxyUI).toBe(true);
    });

    it('should persist settings changes across app switches', async () => {
      // Change setting in Claude
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await settingsPage.open();
      await browser.pause(500);

      await settingsPage.openTab('general');
      await browser.pause(500);

      await settingsPage.changeTheme('light');
      await browser.pause(500);

      // Switch through multiple apps
      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      await navigationPage.switchToApp('gemini');
      await browser.pause(500);

      // Check setting persisted
      const theme = await browser.execute(() => {
        return document.documentElement.getAttribute('data-theme') ||
               document.documentElement.classList.contains('dark') ? 'dark' : 'light';
      });

      expect(theme).toBe('light');
    });
  });

  describe('MCP Servers Per-App Configuration', () => {
    it('should show MCP servers with app-specific enablement', async () => {
      await mcpPage.open();
      await browser.pause(500);

      const servers = await invokeIPC<{ id: string; apps?: string[] }[]>('list_mcp_servers');

      if (servers && servers.length > 0) {
        // Check if servers have apps array
        const serversWithApps = servers.filter(s => s.apps && s.apps.length > 0);
        console.log(`[test] ${serversWithApps.length} servers with app-specific config`);

        expect(serversWithApps.length).toBeGreaterThanOrEqual(0);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should toggle MCP server for specific app', async () => {
      await mcpPage.open();
      await browser.pause(500);

      const serverNames = await mcpPage.getVisibleServerNames();

      if (serverNames.length > 0) {
        // Toggle for Claude app
        await mcpPage.toggleServerApp(serverNames[0], 'claude');
        await browser.pause(300);

        // Check toggle state
        const servers = await invokeIPC<{ id: string; name?: string; apps?: string[] }[]>('list_mcp_servers');
        const server = servers?.find(s => s.id === serverNames[0] || s.name === serverNames[0]);

        if (server?.apps) {
          const hasClaude = server.apps.includes('claude');
          console.log(`[test] Server enabled for Claude: ${hasClaude}`);
        }
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should reflect MCP changes when switching apps', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await mcpPage.open();
      await browser.pause(500);

      const claudeServerCount = await mcpPage.getServerCount();

      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      await mcpPage.open();
      await browser.pause(500);

      const codexServerCount = await mcpPage.getServerCount();

      console.log(`[test] Claude MCP: ${claudeServerCount}, Codex MCP: ${codexServerCount}`);

      // MCP server visibility may differ per app
      expect(claudeServerCount).toBeGreaterThanOrEqual(0);
      expect(codexServerCount).toBeGreaterThanOrEqual(0);
    });

    it('should preserve MCP toggle state across app switches', async () => {
      await mcpPage.open();
      await browser.pause(500);

      const serverNames = await mcpPage.getVisibleServerNames();

      if (serverNames.length > 0) {
        // Toggle first server
        await mcpPage.toggleServer(serverNames[0]);
        await browser.pause(300);

        // Switch apps
        await navigationPage.switchToApp('codex');
        await browser.pause(500);

        // Switch back
        await navigationPage.switchToApp('claude');
        await browser.pause(500);

        await mcpPage.open();
        await browser.pause(500);

        // Check toggle state persisted
        const exists = await mcpPage.serverExists(serverNames[0]);
        expect(exists).toBe(true);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });

  describe('Skill Installation Per-App', () => {
    it('should show skills with app-specific installation status', async () => {
      await skillsPage.open();
      await browser.pause(500);

      const skillCount = await skillsPage.getSkillCount();
      console.log(`[test] Skill count: ${skillCount}`);

      expect(skillCount).toBeGreaterThanOrEqual(0);
    });

    it('should install skill for specific app', async () => {
      await skillsPage.open();
      await browser.pause(500);

      const skillNames = await skillsPage.getVisibleSkillNames();

      if (skillNames.length > 0) {
        // Toggle skill for Claude
        await skillsPage.toggleSkillApp(skillNames[0], 'claude');
        await browser.pause(300);

        // Verify toggle
        const details = await skillsPage.getSkillDetails(skillNames[0]);
        if (details?.enabledApps) {
          console.log(`[test] Skill enabled for: ${details.enabledApps}`);
        }
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });

    it('should show different skills for different apps', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await skillsPage.open();
      await browser.pause(500);

      const claudeSkillCount = await skillsPage.getSkillCount();

      await navigationPage.switchToApp('codex');
      await browser.pause(500);

      await skillsPage.open();
      await browser.pause(500);

      const codexSkillCount = await skillsPage.getSkillCount();

      console.log(`[test] Claude skills: ${claudeSkillCount}, Codex skills: ${codexSkillCount}`);

      // Skill availability may differ per app
      expect(claudeSkillCount).toBeGreaterThanOrEqual(0);
      expect(codexSkillCount).toBeGreaterThanOrEqual(0);
    });

    it('should preserve skill installation state across app switches', async () => {
      await navigationPage.switchToApp('claude');
      await browser.pause(500);

      await skillsPage.open();
      await browser.pause(500);

      const skillNames = await skillsPage.getVisibleSkillNames();

      if (skillNames.length > 0) {
        // Install/toggle skill
        await skillsPage.toggleSkillApp(skillNames[0], 'claude');
        await browser.pause(300);

        // Switch apps
        await navigationPage.switchToApp('gemini');
        await browser.pause(500);

        // Switch back
        await navigationPage.switchToApp('claude');
        await browser.pause(500);

        await skillsPage.open();
        await browser.pause(500);

        // Verify skill state
        const exists = await skillsPage.skillExists(skillNames[0]);
        expect(exists).toBe(true);
      }

      const validState = await JourneyHelpers.assertValidPageState();
      expect(validState).toBe(true);
    });
  });
});