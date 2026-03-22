/**
 * Test Fixtures - Provider Test Data
 */

import { generateTestId, generateProviderName, generateTestApiKey } from '../utils/test-helpers';

/**
 * Test Provider Data Structure
 */
export interface TestProvider {
  id: string;
  name: string;
  apiKey: string;
  baseUrl?: string;
  model?: string;
  notes?: string;
  category?: string;
}

/**
 * Create a test provider with defaults
 */
export function createTestProvider(overrides: Partial<TestProvider> = {}): TestProvider {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: generateProviderName('Test'),
    apiKey: generateTestApiKey(),
    baseUrl: undefined,
    model: undefined,
    notes: `Test provider created at ${new Date().toISOString()}`,
    category: 'test',
    ...overrides,
  };
}

/**
 * Create multiple test providers
 */
export function createTestProviders(count: number, overrides: Partial<TestProvider> = {}): TestProvider[] {
  return Array.from({ length: count }, (_, i) =>
    createTestProvider({
      ...overrides,
      name: `${overrides.name || 'Test'}-${i + 1}-${Date.now()}`,
    })
  );
}

/**
 * Predefined test providers for common scenarios
 */
export const FIXTURE_PROVIDERS = {
  openai: createTestProvider({
    name: 'OpenAI Test',
    apiKey: 'sk-test-openai-key',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4',
    category: 'openai',
  }),

  anthropic: createTestProvider({
    name: 'Anthropic Test',
    apiKey: 'sk-ant-test-key',
    baseUrl: 'https://api.anthropic.com/v1',
    model: 'claude-3-opus',
    category: 'anthropic',
  }),

  gemini: createTestProvider({
    name: 'Gemini Test',
    apiKey: 'test-gemini-key',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-pro',
    category: 'google',
  }),

  custom: createTestProvider({
    name: 'Custom Provider',
    apiKey: 'custom-api-key',
    baseUrl: 'http://localhost:8080/v1',
    model: 'custom-model',
    category: 'custom',
  }),

  invalid: createTestProvider({
    name: 'Invalid Provider',
    apiKey: 'invalid-key',
    baseUrl: 'http://invalid-url-that-does-not-exist.com/v1',
    category: 'invalid',
  }),
};

/**
 * Test Session Data Structure
 */
export interface TestSession {
  id: string;
  name: string;
  appType: string;
  providerId?: string;
}

/**
 * Create a test session
 */
export function createTestSession(overrides: Partial<TestSession> = {}): TestSession {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: `Test Session ${id}`,
    appType: 'claude',
    providerId: undefined,
    ...overrides,
  };
}

/**
 * Test MCP Server Data Structure
 */
export interface TestMcpServer {
  id: string;
  name: string;
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

/**
 * Create a test MCP server
 */
export function createTestMcpServer(overrides: Partial<TestMcpServer> = {}): TestMcpServer {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: `test-mcp-${id}`,
    command: 'node',
    args: ['test-mcp-server.js'],
    env: {},
    ...overrides,
  };
}

/**
 * Test Skill Data Structure
 */
export interface TestSkill {
  id: string;
  name: string;
  description?: string;
  content: string;
}

/**
 * Create a test skill
 */
export function createTestSkill(overrides: Partial<TestSkill> = {}): TestSkill {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: `Test Skill ${id}`,
    description: 'A test skill for E2E testing',
    content: '# Test Skill\n\nThis is a test skill content.',
    ...overrides,
  };
}

/**
 * Test Prompt Data Structure
 */
export interface TestPrompt {
  id: string;
  name: string;
  content: string;
  enabled?: boolean;
}

/**
 * Create a test prompt
 */
export function createTestPrompt(overrides: Partial<TestPrompt> = {}): TestPrompt {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: `Test Prompt ${id}`,
    content: 'You are a helpful assistant for testing.',
    enabled: false,
    ...overrides,
  };
}

/**
 * Test Channel Data Structure
 */
export interface TestChannel {
  id: string;
  name: string;
  apiKey: string;
  baseUrl?: string;
  enabled?: boolean;
}

/**
 * Create a test channel
 */
export function createTestChannel(overrides: Partial<TestChannel> = {}): TestChannel {
  const id = overrides.id || generateTestId();
  return {
    id,
    name: `Test Channel ${id}`,
    apiKey: generateTestApiKey(),
    baseUrl: 'http://localhost:3000',
    enabled: true,
    ...overrides,
  };
}