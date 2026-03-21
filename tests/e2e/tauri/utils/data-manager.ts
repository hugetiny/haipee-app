/**
 * Data Manager for Tauri E2E Tests
 *
 * Manages test data lifecycle: backup before tests, restore after tests.
 * Uses Tauri IPC for database operations.
 */

/// <reference types="@wdio/globals/types" />

import { invokeIPC } from './test-helpers';

export interface Provider {
  id: string;
  name: string;
  app_type: string;
  api_key?: string;
  base_url?: string;
  model?: string;
  is_active: boolean;
  order_index: number;
}

export interface McpServer {
  id: string;
  name: string;
  command: string;
  args?: string[];
  env?: Record<string, string>;
  enabled: boolean;
}

export interface Skill {
  id: string;
  name: string;
  description?: string;
  enabled: boolean;
}

export interface Prompt {
  id: string;
  name: string;
  content: string;
  enabled: boolean;
}

/**
 * DataManager class for managing test data lifecycle
 */
export class DataManager {
  private backupPath: string | null = null;
  private suiteId: string;

  constructor(suiteId: string) {
    this.suiteId = suiteId;
  }

  /**
   * Backup the current database
   */
  async backup(): Promise<string> {
    const timestamp = Date.now();
    const backupPath = `~/.haipee/test-backups/${this.suiteId}-${timestamp}.db`;

    // Create backup directory if needed
    await invokeIPC('create_directory', {
      path: '~/.haipee/test-backups'
    });

    // Backup via IPC
    const result = await invokeIPC<string>('backup_database', { path: backupPath });
    if (result) {
      this.backupPath = backupPath;
    }

    return backupPath;
  }

  /**
   * Restore database from backup
   */
  async restore(): Promise<void> {
    if (!this.backupPath) return;

    await invokeIPC('restore_database', { path: this.backupPath });

    // Clean up backup file
    await invokeIPC('delete_file', { path: this.backupPath });
    this.backupPath = null;
  }

  /**
   * Clean up all test data
   */
  async cleanup(): Promise<void> {
    if (this.backupPath) {
      await invokeIPC('delete_file', { path: this.backupPath });
      this.backupPath = null;
    }
  }

  /**
   * Clear all providers for an app
   */
  async clearProviders(appType: string): Promise<void> {
    const providers = await this.getProviders(appType);
    for (const provider of providers) {
      await invokeIPC('delete_provider', { id: provider.id });
    }
  }

  /**
   * Get all providers for an app
   */
  async getProviders(appType: string): Promise<Provider[]> {
    const result = await invokeIPC<Provider[]>('list_providers', { appType });
    return result || [];
  }

  /**
   * Create a test provider
   */
  async createProvider(appType: string, data: Partial<Provider>): Promise<Provider | null> {
    return invokeIPC<Provider>('create_provider', {
      provider: {
        app_type: appType,
        name: data.name || `Test-${Date.now()}`,
        api_key: data.api_key,
        base_url: data.base_url,
        model: data.model,
        is_active: data.is_active ?? false,
      }
    });
  }

  /**
   * Delete a provider by ID
   */
  async deleteProvider(id: string): Promise<void> {
    await invokeIPC('delete_provider', { id });
  }

  /**
   * Get all MCP servers
   */
  async getMcpServers(): Promise<McpServer[]> {
    const result = await invokeIPC<McpServer[]>('list_mcp_servers');
    return result || [];
  }

  /**
   * Create a test MCP server
   */
  async createMcpServer(data: Partial<McpServer>): Promise<McpServer | null> {
    return invokeIPC<McpServer>('create_mcp_server', {
      server: {
        name: data.name || `Test-MCP-${Date.now()}`,
        command: data.command || 'echo',
        args: data.args || [],
        env: data.env || {},
        enabled: data.enabled ?? true,
      }
    });
  }

  /**
   * Delete an MCP server by ID
   */
  async deleteMcpServer(id: string): Promise<void> {
    await invokeIPC('delete_mcp_server', { id });
  }

  /**
   * Get all skills
   */
  async getSkills(): Promise<Skill[]> {
    const result = await invokeIPC<Skill[]>('list_skills');
    return result || [];
  }

  /**
   * Create a test skill
   */
  async createSkill(data: Partial<Skill>): Promise<Skill | null> {
    return invokeIPC<Skill>('create_skill', {
      skill: {
        name: data.name || `Test-Skill-${Date.now()}`,
        description: data.description || 'Test skill',
        enabled: data.enabled ?? true,
      }
    });
  }

  /**
   * Delete a skill by ID
   */
  async deleteSkill(id: string): Promise<void> {
    await invokeIPC('delete_skill', { id });
  }

  /**
   * Get all prompts
   */
  async getPrompts(): Promise<Prompt[]> {
    const result = await invokeIPC<Prompt[]>('list_prompts');
    return result || [];
  }

  /**
   * Create a test prompt
   */
  async createPrompt(data: Partial<Prompt>): Promise<Prompt | null> {
    return invokeIPC<Prompt>('create_prompt', {
      prompt: {
        name: data.name || `Test-Prompt-${Date.now()}`,
        content: data.content || 'Test prompt content',
        enabled: data.enabled ?? true,
      }
    });
  }

  /**
   * Delete a prompt by ID
   */
  async deletePrompt(id: string): Promise<void> {
    await invokeIPC('delete_prompt', { id });
  }

  /**
   * Inject test providers for an app
   */
  async injectTestProviders(
    appType: string,
    count: number
  ): Promise<Provider[]> {
    const providers: Provider[] = [];
    for (let i = 0; i < count; i++) {
      const provider = await this.createProvider(appType, {
        name: `Test-${appType}-${i + 1}-${Date.now()}`,
        api_key: `sk-test-${Math.random().toString(36).slice(2, 10)}`,
      });
      if (provider) {
        providers.push(provider);
      }
    }
    return providers;
  }
}

/**
 * Create a data manager for a test suite
 */
export function createDataManager(suiteId: string): DataManager {
  return new DataManager(suiteId);
}