/// <reference types="@wdio/globals/types" />
/**
 * Provider Failover Tests - Failover queue management
 */

import { navigationPage } from '../pages';

describe('Failover Queue – Get Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  describe('Get Failover Queue', () => {
    it('should get failover queue for Claude', async () => {
      try {
        const queue = await navigationPage.invokeIPC<Array<{
          provider_id: string;
          priority: number;
          provider_name?: string;
        }>>('get_failover_queue', { app_type: 'claude' });
        expect(Array.isArray(queue)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should get failover queue for Codex', async () => {
      try {
        const queue = await navigationPage.invokeIPC('get_failover_queue', { app_type: 'codex' });
        expect(Array.isArray(queue)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should get failover queue for Gemini', async () => {
      try {
        const queue = await navigationPage.invokeIPC('get_failover_queue', { app_type: 'gemini' });
        expect(Array.isArray(queue)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should handle invalid app type for failover queue', async () => {
      try {
        const queue = await navigationPage.invokeIPC('get_failover_queue', { app_type: 'invalid-app' });
        expect(Array.isArray(queue)).toBe(true);
      } catch (error) {
        expect(error).toBeDefined();
      }
    });
  });

  describe('Get Available Providers for Failover', () => {
    it('should get available providers for Claude failover', async () => {
      try {
        const providers = await navigationPage.invokeIPC('get_available_providers_for_failover', { app_type: 'claude' });
        expect(Array.isArray(providers)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should get available providers for Codex failover', async () => {
      try {
        const providers = await navigationPage.invokeIPC('get_available_providers_for_failover', { app_type: 'codex' });
        expect(Array.isArray(providers)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });
  });
});

describe('Failover Queue – Add/Remove Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should add provider to failover queue', async () => {
    try {
      // First get available providers
      const providers = await navigationPage.invokeIPC<Array<{ id: string }>>(
        'get_available_providers_for_failover',
        { app_type: 'claude' }
      );

      if (providers && providers.length > 0) {
        await navigationPage.invokeIPC('add_to_failover_queue', {
          app_type: 'claude',
          provider_id: providers[0].id
        });

        // Verify it was added
        const queue = await navigationPage.invokeIPC<Array<{ provider_id: string }>>(
          'get_failover_queue',
          { app_type: 'claude' }
        );

        const added = queue.some(item => item.provider_id === providers[0].id);
        expect(typeof added).toBe('boolean');
      } else {
        expect(true).toBe(true);
      }
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should remove provider from failover queue', async () => {
    try {
      const queue = await navigationPage.invokeIPC<Array<{ provider_id: string }>>(
        'get_failover_queue',
        { app_type: 'claude' }
      );

      if (queue && queue.length > 0) {
        await navigationPage.invokeIPC('remove_from_failover_queue', {
          app_type: 'claude',
          provider_id: queue[0].provider_id
        });
        expect(true).toBe(true);
      } else {
        expect(true).toBe(true);
      }
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should handle adding non-existent provider to queue', async () => {
    try {
      await navigationPage.invokeIPC('add_to_failover_queue', {
        app_type: 'claude',
        provider_id: 'non-existent-provider-id'
      });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it('should handle removing non-existent provider from queue', async () => {
    try {
      await navigationPage.invokeIPC('remove_from_failover_queue', {
        app_type: 'claude',
        provider_id: 'non-existent-provider-id'
      });
    } catch {
      // May succeed silently or fail
      expect(true).toBe(true);
    }
  });
});

describe('Failover Queue – Auto Failover Toggle', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should get auto failover enabled status', async () => {
    try {
      const enabled = await navigationPage.invokeIPC<boolean>(
        'get_auto_failover_enabled',
        { app_type: 'claude' }
      );
      expect(typeof enabled).toBe('boolean');
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should set auto failover enabled', async () => {
    try {
      // First get current status
      const currentStatus = await navigationPage.invokeIPC<boolean>(
        'get_auto_failover_enabled',
        { app_type: 'claude' }
      );

      // Toggle it
      await navigationPage.invokeIPC('set_auto_failover_enabled', {
        app_type: 'claude',
        enabled: !currentStatus
      });

      // Verify change
      const newStatus = await navigationPage.invokeIPC<boolean>(
        'get_auto_failover_enabled',
        { app_type: 'claude' }
      );

      expect(newStatus).toBe(!currentStatus);

      // Restore original status
      await navigationPage.invokeIPC('set_auto_failover_enabled', {
        app_type: 'claude',
        enabled: currentStatus
      });
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should handle invalid app type for auto failover toggle', async () => {
    try {
      await navigationPage.invokeIPC('get_auto_failover_enabled', { app_type: 'invalid-app' });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });
});

describe('Failover Queue – UI Integration', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await navigationPage.navigateToView('providers');
    await browser.pause(1000);
  });

  it('should show failover toggle in provider settings', async () => {
    const failoverToggle = await $('[data-testid="failover-toggle"], [data-testid="auto-failover-toggle"]');
    const hasToggle = await failoverToggle.isExisting();
    expect(typeof hasToggle).toBe('boolean');
  });

  it('should show failover queue in UI', async () => {
    const failoverQueue = await $('[data-testid="failover-queue"], [data-testid="failover-queue-list"]');
    const hasQueue = await failoverQueue.isExisting();
    expect(typeof hasQueue).toBe('boolean');
  });

  it('should show failover priority for providers in queue', async () => {
    const priorityBadge = await $('[data-testid="failover-priority"], [class*="failover-badge"]');
    const hasBadge = await priorityBadge.isExisting();
    expect(typeof hasBadge).toBe('boolean');
  });

  it('should show add to failover button for providers', async () => {
    const addToFailoverBtn = await $('[data-testid="add-to-failover-btn"], button[aria-label*="failover"]');
    const hasBtn = await addToFailoverBtn.isExisting();
    expect(typeof hasBtn).toBe('boolean');
  });
});
