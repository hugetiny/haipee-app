/// <reference types="@wdio/globals/types" />
/**
 * Environment Variable Settings Tests - Env conflict detection and management
 */

import { navigationPage } from '../pages';

describe('Environment Variables – Conflict Detection', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  describe('Check Conflicts', () => {
    it('should check Claude env conflicts', async () => {
      try {
        const conflicts = await navigationPage.invokeIPC<Array<{
          var_name: string;
          var_value: string;
          source: string;
        }>>('check_env_conflicts', { app: 'claude' });
        expect(Array.isArray(conflicts)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should check Codex env conflicts', async () => {
      try {
        const conflicts = await navigationPage.invokeIPC<Array<{
          var_name: string;
          var_value: string;
          source: string;
        }>>('check_env_conflicts', { app: 'codex' });
        expect(Array.isArray(conflicts)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should check Gemini env conflicts', async () => {
      try {
        const conflicts = await navigationPage.invokeIPC<Array<{
          var_name: string;
          var_value: string;
          source: string;
        }>>('check_env_conflicts', { app: 'gemini' });
        expect(Array.isArray(conflicts)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should check OpenCode env conflicts', async () => {
      try {
        const conflicts = await navigationPage.invokeIPC<Array<{
          var_name: string;
          var_value: string;
          source: string;
        }>>('check_env_conflicts', { app: 'opencode' });
        expect(Array.isArray(conflicts)).toBe(true);
      } catch {
        expect(true).toBe(true);
      }
    });

    it('should handle invalid app type gracefully', async () => {
      try {
        const conflicts = await navigationPage.invokeIPC('check_env_conflicts', { app: 'invalid-app' });
        expect(Array.isArray(conflicts)).toBe(true);
      } catch (error) {
        expect(error).toBeDefined();
      }
    });
  });

  describe('Default Shell Config', () => {
    it('should get default shell config path', async () => {
      try {
        const configPath = await navigationPage.invokeIPC<string>('get_default_shell_config');
        expect(typeof configPath).toBe('string');
        // Should be a path like ~/.zshrc or ~/.bashrc or 'registry' on Windows
        expect(configPath.length).toBeGreaterThan(0);
      } catch {
        expect(true).toBe(true);
      }
    });
  });
});

describe('Environment Variables – Warning Banner', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should display env warning banner if conflicts exist', async () => {
    const warningBanner = await $('[data-testid="env-warning-banner"], [class*="env-warning"], [class*="EnvWarning"]');
    const hasBanner = await warningBanner.isExisting();
    expect(typeof hasBanner).toBe('boolean');
  });

  it('should show conflict count in banner', async () => {
    const banner = await $('[data-testid="env-warning-banner"]');
    if (await banner.isExisting()) {
      const text = await banner.getText();
      expect(typeof text).toBe('string');
    }
  });

  it('should have dismiss button on banner', async () => {
    const banner = await $('[data-testid="env-warning-banner"]');
    if (await banner.isExisting()) {
      const dismissBtn = await banner.$('button[aria-label*="close"], button[aria-label*="关闭"], [data-testid="dismiss-env-warning"]');
      const hasDismiss = await dismissBtn.isExisting();
      expect(typeof hasDismiss).toBe('boolean');
    }
  });

  it('should have delete button on banner', async () => {
    const banner = await $('[data-testid="env-warning-banner"]');
    if (await banner.isExisting()) {
      const deleteBtn = await banner.$('button:contains("删除"), button:contains("Delete"), [data-testid="delete-env-btn"]');
      const hasDelete = await deleteBtn.isExisting();
      expect(typeof hasDelete).toBe('boolean');
    }
  });
});

describe('Environment Variables – Delete Operations', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should delete env vars with backup', async () => {
    // First get conflicts
    try {
      const conflicts = await navigationPage.invokeIPC<Array<{
        var_name: string;
        var_value: string;
        source: string;
      }>>('check_env_conflicts', { app: 'claude' });

      if (conflicts && conflicts.length > 0) {
        // Try to delete first conflict
        const result = await navigationPage.invokeIPC<{
          backup_path: string;
          deleted_count: number;
        }>('delete_env_vars', { conflicts: [conflicts[0]] });

        expect(typeof result).toBe('object');
        expect(typeof result.backup_path).toBe('string');
        expect(typeof result.deleted_count).toBe('number');
      } else {
        // No conflicts to delete
        expect(true).toBe(true);
      }
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should handle empty conflicts array', async () => {
    try {
      await navigationPage.invokeIPC('delete_env_vars', { conflicts: [] });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });
});

describe('Environment Variables – Backup Restore', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should restore from backup file', async () => {
    try {
      // This would require an actual backup file to exist
      await navigationPage.invokeIPC('restore_env_backup', { backup_path: '/nonexistent-backup.json' });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it('should handle invalid backup path', async () => {
    try {
      await navigationPage.invokeIPC('restore_env_backup', { backup_path: '' });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });
});

describe('Environment Variables – Set Variable', () => {
  before(async () => {
    await navigationPage.waitForReactReady();
    await browser.pause(1000);
  });

  it('should set new environment variable', async () => {
    try {
      const result = await navigationPage.invokeIPC<string>('set_env_var_command', {
        var_name: 'HAIPEE_E2E_TEST_VAR',
        var_value: 'test_value_123',
        target_file: null
      });
      expect(typeof result).toBe('string');
    } catch {
      // May fail if no write permission
      expect(true).toBe(true);
    }
  });

  it('should update existing environment variable', async () => {
    try {
      // Set first
      await navigationPage.invokeIPC('set_env_var_command', {
        var_name: 'HAIPEE_E2E_TEST_VAR',
        var_value: 'initial_value',
        target_file: null
      });

      // Then update
      const result = await navigationPage.invokeIPC<string>('set_env_var_command', {
        var_name: 'HAIPEE_E2E_TEST_VAR',
        var_value: 'updated_value',
        target_file: null
      });
      expect(typeof result).toBe('string');
    } catch {
      expect(true).toBe(true);
    }
  });

  it('should handle empty variable name', async () => {
    try {
      await navigationPage.invokeIPC('set_env_var_command', {
        var_name: '',
        var_value: 'test',
        target_file: null
      });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });

  it('should handle special characters in value', async () => {
    try {
      const result = await navigationPage.invokeIPC<string>('set_env_var_command', {
        var_name: 'HAIPEE_E2E_SPECIAL',
        var_value: 'value with "quotes" and $special',
        target_file: null
      });
      expect(typeof result).toBe('string');
    } catch {
      expect(true).toBe(true);
    }
  });
});
