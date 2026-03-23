/**
 * API Provider Test Utilities
 *
 * Shared utilities for testing API providers via HTTP fetch.
 */

import { config } from 'dotenv';

// Load environment variables from .env file
config();

const LIVE_API_TEST_ENV = 'RUN_LIVE_API_TESTS';

export interface ProviderConfig {
  name: string;
  tokenEnvVar: string;
  baseUrl?: string;
  modelsEndpoint?: string;
  chatEndpoint?: string;
  testModel: string;
  testMessage: string;
  expectedResponseContains?: string;
  headers?: Record<string, string>;
}

/**
 * Provider configurations for testing
 * Tokens are loaded from environment variables (.env)
 */
export const API_PROVIDERS: ProviderConfig[] = [
  {
    name: 'NVIDIA NIM',
    tokenEnvVar: 'NVIDIA_TOKEN',
    baseUrl: 'https://integrate.api.nvidia.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'meta/llama-3.1-8b-instruct',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'OpenAI',
    tokenEnvVar: 'OPENAI_TOKEN',
    baseUrl: 'https://api.openai.com',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'gpt-4o-mini',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Google Gemini',
    tokenEnvVar: 'GEMINI_TOKEN',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'gemini-2.0-flash',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'OpenCode Zen',
    tokenEnvVar: 'OPENCODE_TOKEN',
    baseUrl: 'https://opencode.ai',
    modelsEndpoint: '',
    chatEndpoint: '/zen/v1/chat/completions',
    testModel: 'minimax-m2.5-free',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Kilo Code',
    tokenEnvVar: 'KILO_TOKEN',
    baseUrl: 'https://api.kilo.ai/api/gateway',
    modelsEndpoint: '',
    chatEndpoint: '/chat/completions',
    testModel: 'openai/gpt-4o-mini',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'XiaoMi MiNo',
    tokenEnvVar: 'XIAOMIMINO_TOKEN',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'mimo-v2-flash',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Cloudflare',
    tokenEnvVar: 'CLOUDFLARE_API_TOKEN',
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts',
    modelsEndpoint: '',
    chatEndpoint: '/ai/v1/chat/completions',
    testModel: '@cf/meta/llama-3.1-8b-instruct',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Poe',
    tokenEnvVar: 'POE_TOKEN',
    baseUrl: 'https://api.poe.com/v1',
    modelsEndpoint: '/models',
    chatEndpoint: '/chat/completions',
    testModel: 'Claude-Sonnet-4',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
  {
    name: 'Kimi Coding',
    tokenEnvVar: 'KIMI_TOKEN',
    baseUrl: 'https://api.kimi.com/coding',
    modelsEndpoint: '/v1/models',
    chatEndpoint: '/v1/chat/completions',
    testModel: 'kimi-for-coding',
    testMessage: 'Hello, this is a test message from Haipee tests.',
    headers: {
      'Content-Type': 'application/json',
    },
  },
];

/**
 * Check if a provider has a valid token configured
 */
export function hasValidToken(provider: ProviderConfig): boolean {
  const token = process.env[provider.tokenEnvVar]?.trim();
  return !!token && token.length > 10;
}

/**
 * Get the API token for a provider
 */
export function getToken(provider: ProviderConfig): string | undefined {
  return process.env[provider.tokenEnvVar]?.trim();
}

/**
 * Get active providers (those with valid tokens)
 */
export function getActiveProviders(): ProviderConfig[] {
  return API_PROVIDERS.filter(hasValidToken);
}

/**
 * Get request headers for a provider
 */
export function getRequestHeaders(provider: ProviderConfig): Record<string, string> {
  const token = getToken(provider);
  return {
    ...provider.headers,
    Authorization: `Bearer ${token}`,
  };
}

/**
 * Skip test if token not configured
 */
export function skipIfNoToken(provider: ProviderConfig): boolean {
  const shouldRunLiveApiTests =
    (process.env[LIVE_API_TEST_ENV] ?? '').toLowerCase() === '1' ||
    (process.env[LIVE_API_TEST_ENV] ?? '').toLowerCase() === 'true';

  return !shouldRunLiveApiTests || !hasValidToken(provider);
}
